/**
 * Refresh the reference corpus.
 *
 * Reads every top-level `pipeline/config/<platform>.yml` (or one, if a
 * platform argument is given), pulls each listed article from the pinned
 * commit of `source.repo` via `gh api`, applies the deterministic
 * transforms, and writes <paths.reference_dir>/<slug>.md. There is no
 * intermediate directory and no LLM step — the corpus is the docs reshaped.
 *
 * Idempotent: an article is skipped when the upstream blob sha *and* the
 * Layer A inputs stamped into frontmatter (sdk tag/artifact, feature,
 * archetype, source_path) already match. That's what makes `git diff` after
 * a run mean "upstream or pin actually changed", which the refresh workflow
 * relies on to name the touched slugs — `fetched_at` is not part of the key.
 *
 * Usage:
 *   pnpm refresh:docs              # every configured platform, one pass
 *   pnpm refresh:docs -- android   # one platform
 *
 * Ref override: set SOURCE_REF to a commit SHA, branch, or tag. It is
 * resolved to a 40-char SHA before fetch/write so generated `source_ref`
 * stays schema-valid. The auto-refresh workflow passes the docs commit that
 * triggered it; `set-source-ref.ts` then writes the resolved SHA back into
 * the config(s) whose corpus actually changed.
 *
 * Local clone: set DOCS_ROOT to a checkout of `source.repo` (same commit as
 * SOURCE_REF / `source.ref`). Articles are read from disk and blob SHAs come
 * from `git hash-object`, which matches GitHub's contents API. CI still
 * uses `gh api`.
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
  SHA_RE,
  type ArticleConfig,
  type PlatformConfig,
} from "./lib/platforms.ts";

interface ContentApiResponse {
  sha: string;
  content: string;
  encoding: "base64";
}

interface CommitApiResponse {
  sha: string;
}

interface SkipInputs {
  sourceSha: string;
  sourcePath: string;
  sdkVersion: string;
  sdkArtifact: string;
  feature: string;
  archetype: string;
}

function localDocsRoot(): string | undefined {
  const root = process.env.DOCS_ROOT?.trim();
  return root || undefined;
}

function ghApiJson<T>(path: string): T {
  const stdout = execFileSync("gh", ["api", path], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return JSON.parse(stdout) as T;
}

function resolveCommitSha(repo: string, ref: string): string {
  if (SHA_RE.test(ref)) return ref;
  const docsRoot = localDocsRoot();
  if (docsRoot) {
    const sha = execFileSync("git", ["-C", docsRoot, "rev-parse", `${ref}^{commit}`], {
      encoding: "utf8",
    }).trim();
    if (!SHA_RE.test(sha)) {
      throw new Error(`Could not resolve ${repo}@${ref} to a 40-char commit SHA (got "${sha}")`);
    }
    return sha;
  }
  const res = ghApiJson<CommitApiResponse>(`repos/${repo}/commits/${encodeURIComponent(ref)}`);
  if (!SHA_RE.test(res.sha)) {
    throw new Error(`Could not resolve ${repo}@${ref} to a 40-char commit SHA (got "${res.sha}")`);
  }
  return res.sha;
}

function fetchArticle(repo: string, ref: string, sourcePath: string) {
  const docsRoot = localDocsRoot();
  if (docsRoot) {
    const filePath = resolve(docsRoot, sourcePath);
    if (!existsSync(filePath)) {
      throw new Error(`DOCS_ROOT article missing: ${sourcePath} (looked in ${filePath})`);
    }
    const body = readFileSync(filePath, "utf8");
    const sha = execFileSync("git", ["-C", docsRoot, "hash-object", sourcePath], {
      encoding: "utf8",
    }).trim();
    return { sha, body };
  }
  const res = ghApiJson<ContentApiResponse>(`repos/${repo}/contents/${sourcePath}?ref=${ref}`);
  return { sha: res.sha, body: Buffer.from(res.content, res.encoding).toString("utf8") };
}

function existingSkipInputs(filePath: string): SkipInputs | undefined {
  if (!existsSync(filePath)) return undefined;
  const { frontmatter } = splitFrontmatter(readFileSync(filePath, "utf8"));
  if (typeof frontmatter.source_sha !== "string") return undefined;
  if (typeof frontmatter.source_path !== "string") return undefined;
  if (typeof frontmatter.sdk_min_version !== "string") return undefined;
  if (typeof frontmatter.sdk_artifact !== "string") return undefined;
  if (typeof frontmatter.feature !== "string") return undefined;
  if (typeof frontmatter.archetype !== "string") return undefined;
  return {
    sourceSha: frontmatter.source_sha,
    sourcePath: frontmatter.source_path,
    sdkVersion: frontmatter.sdk_min_version,
    sdkArtifact: frontmatter.sdk_artifact,
    feature: frontmatter.feature,
    archetype: frontmatter.archetype,
  };
}

function shouldSkip(filePath: string, next: SkipInputs): boolean {
  const existing = existingSkipInputs(filePath);
  if (!existing) return false;
  return (
    existing.sourceSha === next.sourceSha &&
    existing.sourcePath === next.sourcePath &&
    existing.sdkVersion === next.sdkVersion &&
    existing.sdkArtifact === next.sdkArtifact &&
    existing.feature === next.feature &&
    existing.archetype === next.archetype
  );
}

function refreshConfig(config: PlatformConfig, sourceRef: string): { written: number; skipped: number } {
  const outDir = resolve(REPO_ROOT, config.paths.reference_dir);
  mkdirSync(outDir, { recursive: true });

  const refOverride = process.env.SOURCE_REF?.trim();
  const refDisplay = refOverride
    ? `${sourceRef} (SOURCE_REF override)`
    : config.source.ref_label
      ? `${sourceRef.slice(0, 7)} (${config.source.ref_label})`
      : sourceRef.slice(0, 7);

  console.log(
    `Refreshing ${config.articles.length} ${config.platform} articles from ${config.source.repo}@${refDisplay}`,
  );
  console.log(`  → ${config.paths.reference_dir}\n`);

  let written = 0;
  let skipped = 0;
  for (const article of config.articles) {
    const outPath = resolve(outDir, `${article.slug}.md`);
    const { sha, body } = fetchArticle(config.source.repo, sourceRef, article.source_path);
    const skipInputs: SkipInputs = {
      sourceSha: sha,
      sourcePath: article.source_path,
      sdkVersion: config.sdk.tag,
      sdkArtifact: config.sdk.artifact,
      feature: article.feature,
      archetype: article.archetype,
    };

    if (shouldSkip(outPath, skipInputs)) {
      console.log(`  skip   ${article.slug}  (unchanged)`);
      skipped++;
      continue;
    }

    writeArticle(outPath, article, config, sourceRef, sha, body);
    written++;
  }

  console.log(`\nDone ${config.platform}. ${written} written, ${skipped} unchanged.\n`);
  return { written, skipped };
}

function writeArticle(
  outPath: string,
  article: ArticleConfig,
  config: PlatformConfig,
  sourceRef: string,
  sha: string,
  body: string,
): void {
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
    sdkArtifact: config.sdk.artifact,
  };
  const { output, snippetCount } = applyLayerA(withProvenance, ctx);
  writeFileSync(outPath, output, "utf8");
  console.log(
    `  write  ${article.slug}  (${sha.slice(0, 7)}, ${snippetCount} snippet${snippetCount === 1 ? "" : "s"})`,
  );
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

  const refOverride = process.env.SOURCE_REF?.trim();
  const shaByRepo = new Map<string, string>();

  let written = 0;
  let skipped = 0;
  for (const configPath of configPaths) {
    let config: PlatformConfig;
    try {
      config = loadPlatformConfig(configPath);
    } catch (error) {
      console.error(error instanceof Error ? error.message : String(error));
      process.exit(1);
      return;
    }

    const requested = refOverride || config.source.ref;
    let sourceRef = shaByRepo.get(`${config.source.repo}@${requested}`);
    if (!sourceRef) {
      try {
        sourceRef = resolveCommitSha(config.source.repo, requested);
      } catch (error) {
        console.error(error instanceof Error ? error.message : String(error));
        process.exit(1);
        return;
      }
      shaByRepo.set(`${config.source.repo}@${requested}`, sourceRef);
    }

    const result = refreshConfig(config, sourceRef);
    written += result.written;
    skipped += result.skipped;
  }

  if (configPaths.length > 1) {
    console.log(`All platforms. ${written} written, ${skipped} unchanged.`);
  }
}

main();
