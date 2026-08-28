/**
 * Refresh the reference corpus.
 *
 * Reads every top-level `pipeline/config/<platform>.yml` (or one, if a
 * platform argument is given), pulls each listed article from the pinned
 * commit of `source.repo` via `gh api`, applies the deterministic
 * transforms, and writes <paths.reference_dir>/<slug>.md. There is no
 * intermediate directory and no LLM step — the corpus is the docs reshaped.
 *
 * Idempotent: an article whose upstream blob sha matches the `source_sha`
 * already recorded in the reference file is skipped. That's what makes
 * `git diff` after a run mean "upstream actually changed", which the refresh
 * workflow relies on to name the touched slugs.
 *
 * Usage:
 *   pnpm refresh:docs              # every configured platform, one pass
 *   pnpm refresh:docs -- android   # one platform
 *
 * Ref override: set SOURCE_REF to fetch from a specific commit/branch instead
 * of the config's pinned `source.ref`. The auto-refresh workflow passes the
 * docs commit that triggered it; `set-source-ref.ts` then writes the resolved
 * SHA back into the config(s) whose corpus actually changed.
 */

import { execFileSync } from "node:child_process";
import { mkdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";
import { splitFrontmatter, joinFrontmatter } from "./lib/frontmatter.ts";
import { applyLayerA, type LayerAContext } from "./lib/layer-a.ts";
import {
  loadPlatformConfig,
  resolveConfigPaths,
  REPO_ROOT,
  type PlatformConfig,
} from "./lib/platforms.ts";

interface ContentApiResponse {
  sha: string;
  content: string;
  encoding: "base64";
}

function ghApiJson<T>(path: string): T {
  const stdout = execFileSync("gh", ["api", path], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return JSON.parse(stdout) as T;
}

function fetchArticle(repo: string, ref: string, sourcePath: string) {
  const res = ghApiJson<ContentApiResponse>(`repos/${repo}/contents/${sourcePath}?ref=${ref}`);
  return { sha: res.sha, body: Buffer.from(res.content, res.encoding).toString("utf8") };
}

function existingSourceSha(filePath: string): string | undefined {
  if (!existsSync(filePath)) return undefined;
  const { frontmatter } = splitFrontmatter(readFileSync(filePath, "utf8"));
  return typeof frontmatter.source_sha === "string" ? frontmatter.source_sha : undefined;
}

function requireArtifact(config: PlatformConfig): string {
  const artifact = config.sdk.artifact;
  if (typeof artifact !== "string" || artifact.length === 0) {
    throw new Error(
      `pipeline/config/${config.platform}.yml: sdk.artifact is required (Maven coordinate or npm package name)`,
    );
  }
  return artifact;
}

function refreshConfig(config: PlatformConfig): { written: number; skipped: number } {
  const artifact = requireArtifact(config);
  const outDir = resolve(REPO_ROOT, config.paths.reference_dir);
  mkdirSync(outDir, { recursive: true });

  const refOverride = process.env.SOURCE_REF?.trim();
  const sourceRef = refOverride || config.source.ref;
  const refDisplay = refOverride
    ? `${sourceRef} (SOURCE_REF override)`
    : config.source.ref_label
      ? `${config.source.ref.slice(0, 7)} (${config.source.ref_label})`
      : config.source.ref.slice(0, 7);

  console.log(
    `Refreshing ${config.articles.length} ${config.platform} articles from ${config.source.repo}@${refDisplay}`,
  );
  console.log(`  → ${config.paths.reference_dir}\n`);

  let written = 0;
  let skipped = 0;
  for (const article of config.articles) {
    const outPath = resolve(outDir, `${article.slug}.md`);
    const { sha, body } = fetchArticle(config.source.repo, sourceRef, article.source_path);

    if (existingSourceSha(outPath) === sha) {
      console.log(`  skip   ${article.slug}  (unchanged)`);
      skipped++;
      continue;
    }

    const { frontmatter, body: articleBody } = splitFrontmatter(body);
    const withProvenance = joinFrontmatter(
      {
        ...frontmatter,
        source_repo: config.source.repo,
        source_path: article.source_path,
        source_ref: sourceRef,
        source_sha: sha,
        fetched_at: new Date().toISOString(),
      },
      articleBody,
    );

    const ctx: LayerAContext = {
      slug: article.slug,
      feature: article.feature,
      archetype: article.archetype,
      sdkVersion: config.sdk.tag,
      sdkArtifact: artifact,
    };
    const { output, snippetCount } = applyLayerA(withProvenance, ctx);
    writeFileSync(outPath, output, "utf8");
    console.log(
      `  write  ${article.slug}  (${sha.slice(0, 7)}, ${snippetCount} snippet${snippetCount === 1 ? "" : "s"})`,
    );
    written++;
  }

  console.log(`\nDone ${config.platform}. ${written} written, ${skipped} unchanged.\n`);
  return { written, skipped };
}

function main() {
  // pnpm may forward the `--` separator through to the script, so drop it.
  const args = process.argv.slice(2).filter((a) => a !== "--");
  let configPaths: string[];
  try {
    configPaths = resolveConfigPaths(args[0]);
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
    return;
  }

  let written = 0;
  let skipped = 0;
  for (const configPath of configPaths) {
    const config = loadPlatformConfig(configPath);
    const result = refreshConfig(config);
    written += result.written;
    skipped += result.skipped;
  }

  if (configPaths.length > 1) {
    console.log(`All platforms. ${written} written, ${skipped} unchanged.`);
  }
}

main();
