/**
 * Stage 1 — Fetch.
 *
 * Reads pipeline/config/<platform>.yml, pulls each listed article from the
 * pinned commit of `source.repo` via `gh api`, and writes
 * <paths.sources_dir>/<slug>.md with the original VuePress frontmatter
 * preserved plus a fetch stamp appended.
 *
 * Idempotent: if a source file already exists with the same `source_sha`,
 * the fetch is skipped.
 *
 * Usage:
 *   pnpm fetch:sources              # picks the single config in pipeline/config
 *   pnpm fetch:sources -- android   # explicit platform when several configs exist
 */

import { execFileSync } from "node:child_process";
import { mkdirSync, readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";
import { splitFrontmatter, joinFrontmatter } from "./lib/frontmatter.ts";

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
  paths: { sources_dir: string; polished_dir: string; skill_dir: string };
  publish: { enabled: boolean; context7?: { library_name: string; version_from: string } };
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

function ghApiJson<T>(path: string): T {
  const stdout = execFileSync("gh", ["api", path], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  return JSON.parse(stdout) as T;
}

function fetchArticle(repo: string, ref: string, sourcePath: string) {
  const apiPath = `repos/${repo}/contents/${sourcePath}?ref=${ref}`;
  const res = ghApiJson<ContentApiResponse>(apiPath);
  const body = Buffer.from(res.content, res.encoding).toString("utf8");
  return { sha: res.sha, body };
}

function existingSourceSha(filePath: string): string | undefined {
  if (!existsSync(filePath)) return undefined;
  const raw = readFileSync(filePath, "utf8");
  const { frontmatter } = splitFrontmatter(raw);
  const sha = frontmatter.source_sha;
  return typeof sha === "string" ? sha : undefined;
}

function stampedSource(
  raw: string,
  ctx: { sourceRepo: string; sourcePath: string; sourceRef: string; sourceSha: string },
): string {
  const { frontmatter, body } = splitFrontmatter(raw);
  const stamped = {
    ...frontmatter,
    source_repo: ctx.sourceRepo,
    source_path: ctx.sourcePath,
    source_ref: ctx.sourceRef,
    source_sha: ctx.sourceSha,
    fetched_at: new Date().toISOString(),
  };
  return joinFrontmatter(stamped, body);
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
  const configPath = resolveConfigPath(process.argv[2]);
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }

  const config = parseYaml(readFileSync(configPath, "utf8")) as PlatformConfig;
  const outDir = resolve(REPO_ROOT, config.paths.sources_dir);
  mkdirSync(outDir, { recursive: true });

  const refDisplay = config.source.ref_label
    ? `${config.source.ref.slice(0, 7)} (${config.source.ref_label})`
    : config.source.ref.slice(0, 7);
  console.log(
    `Fetching ${config.articles.length} ${config.platform} articles from ${config.source.repo}@${refDisplay}`,
  );
  console.log(`  → ${config.paths.sources_dir}\n`);

  let fetched = 0;
  let skipped = 0;
  for (const article of config.articles) {
    const outPath = resolve(outDir, `${article.slug}.md`);
    const previous = existingSourceSha(outPath);
    const { sha, body } = fetchArticle(config.source.repo, config.source.ref, article.source_path);

    if (previous === sha) {
      console.log(`  skip   ${article.slug}  (unchanged)`);
      skipped++;
      continue;
    }
    const stamped = stampedSource(body, {
      sourceRepo: config.source.repo,
      sourcePath: article.source_path,
      sourceRef: config.source.ref,
      sourceSha: sha,
    });
    writeFileSync(outPath, stamped, "utf8");
    console.log(`  write  ${article.slug}  (${sha.slice(0, 7)})`);
    fetched++;
  }

  console.log(`\nDone. ${fetched} written, ${skipped} unchanged.`);
}

main();
