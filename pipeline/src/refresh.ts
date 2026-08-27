/**
 * Refresh the reference corpus.
 *
 * Reads pipeline/config/<platform>.yml, pulls each listed article from the
 * pinned commit of `source.repo` via `gh api`, applies the deterministic
 * transforms, and writes <paths.reference_dir>/<slug>.md. There is no
 * intermediate directory and no LLM step — the corpus is the docs reshaped.
 *
 * Idempotent: an article whose upstream blob sha matches the `source_sha`
 * already recorded in the reference file is skipped. That's what makes
 * `git diff` after a run mean "upstream actually changed", which the refresh
 * workflow relies on to name the touched slugs.
 *
 * Usage:
 *   pnpm refresh:docs              # picks the single config in pipeline/config
 *   pnpm refresh:docs -- android   # explicit platform when several configs exist
 *
 * Ref override: set SOURCE_REF to fetch from a specific commit/branch instead
 * of the config's pinned `source.ref`. The auto-refresh workflow passes the
 * docs commit that triggered it; `set-source-ref.ts` then writes the resolved
 * SHA back into the config.
 */

import { execFileSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";
import { splitFrontmatter, joinFrontmatter } from "./lib/frontmatter.ts";
import { applyLayerA, type LayerAContext } from "./lib/layer-a.ts";

interface ArticleConfig {
  slug: string;
  source_path: string;
  feature: string;
  archetype: "integration" | "feature" | "identity";
}

interface PlatformConfig {
  platform: string;
  source: { repo: string; ref: string; ref_label?: string };
  sdk: { repo: string; tag: string; changelog_path: string };
  paths: { reference_dir: string };
  articles: ArticleConfig[];
}

interface ContentApiResponse {
  sha: string;
  content: string;
  encoding: "base64";
}

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");
const SDK_ARTIFACT = "iterableapi";

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

function resolveConfigPath(platformArg: string | undefined): string {
  if (platformArg) return resolve(CONFIG_DIR, `${platformArg}.yml`);
  const ymls = readdirSync(CONFIG_DIR).filter((f) => f.endsWith(".yml"));
  if (ymls.length === 1) return resolve(CONFIG_DIR, ymls[0]!);
  throw new Error(
    `Multiple configs in ${CONFIG_DIR} (${ymls.join(", ")}). Pass a platform argument.`,
  );
}

function main() {
  // pnpm may forward the `--` separator through to the script, so drop it.
  const args = process.argv.slice(2).filter((a) => a !== "--");
  const configPath = resolveConfigPath(args[0]);
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }

  const config = parseYaml(readFileSync(configPath, "utf8")) as PlatformConfig;
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
      sdkArtifact: SDK_ARTIFACT,
    };
    const { output, snippetCount } = applyLayerA(withProvenance, ctx);
    writeFileSync(outPath, output, "utf8");
    console.log(
      `  write  ${article.slug}  (${sha.slice(0, 7)}, ${snippetCount} snippet${snippetCount === 1 ? "" : "s"})`,
    );
    written++;
  }

  console.log(`\nDone. ${written} written, ${skipped} unchanged.`);
}

main();
