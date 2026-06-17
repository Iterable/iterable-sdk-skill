/**
 * Stage 2 — Polish, Layer A CLI.
 *
 * Reads sources/<platform>/<slug>.md, applies the Layer A deterministic
 * transforms, and writes the intermediate result to
 * <paths.polished_dir>/<slug>.layer-a.md. The `.layer-a.md` suffix marks
 * the file as Layer A only — Layer B (LLM polish) overwrites without the
 * suffix when it lands.
 *
 * Usage:
 *   pnpm polish:a                                # all articles in the config
 *   pnpm polish:a -- in-app-messages-on-android  # one article by slug
 *   pnpm polish:a -- --platform=ios <slug>       # explicit platform
 */

import { mkdirSync, readdirSync, readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";
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
  paths: { sources_dir: string; polished_dir: string; skill_dir: string };
  publish: { enabled: boolean };
  articles: ArticleConfig[];
}

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");
const SDK_ARTIFACT = "iterableapi";

function parseArgs(argv: string[]): { platform: string | undefined; slug: string | undefined } {
  let platform: string | undefined;
  let slug: string | undefined;
  for (const arg of argv) {
    const m = /^--platform=(.+)$/.exec(arg);
    if (m) platform = m[1];
    else if (!arg.startsWith("--")) slug = arg;
  }
  return { platform, slug };
}

function resolveConfigPath(platformArg: string | undefined): string {
  if (platformArg) return resolve(CONFIG_DIR, `${platformArg}.yml`);
  const ymls = readdirSync(CONFIG_DIR).filter((f) => f.endsWith(".yml"));
  if (ymls.length === 1) return resolve(CONFIG_DIR, ymls[0]!);
  throw new Error(
    `Multiple configs in ${CONFIG_DIR} (${ymls.join(", ")}). Pass --platform=<name>.`,
  );
}

function main() {
  const { platform, slug } = parseArgs(process.argv.slice(2));
  const configPath = resolveConfigPath(platform);
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }

  const config = parseYaml(readFileSync(configPath, "utf8")) as PlatformConfig;
  const sourcesDir = resolve(REPO_ROOT, config.paths.sources_dir);
  const outDir = resolve(REPO_ROOT, config.paths.polished_dir);
  mkdirSync(outDir, { recursive: true });

  const articles = slug
    ? config.articles.filter((a) => a.slug === slug)
    : config.articles;

  if (articles.length === 0) {
    console.error(`No article with slug "${slug}" in ${configPath}`);
    process.exit(1);
  }

  console.log(
    `Layer A on ${articles.length}/${config.articles.length} ${config.platform} article(s)`,
  );
  console.log(`  ${config.paths.sources_dir} → ${config.paths.polished_dir}\n`);

  for (const article of articles) {
    const inPath = resolve(sourcesDir, `${article.slug}.md`);
    if (!existsSync(inPath)) {
      console.log(`  skip   ${article.slug}  (not fetched yet — run pnpm fetch:sources)`);
      continue;
    }
    const raw = readFileSync(inPath, "utf8");
    const ctx: LayerAContext = {
      slug: article.slug,
      feature: article.feature,
      archetype: article.archetype,
      sdkVersion: config.sdk.tag,
      sdkArtifact: SDK_ARTIFACT,
    };
    const { output, snippets } = applyLayerA(raw, ctx);
    const outPath = resolve(outDir, `${article.slug}.layer-a.md`);
    writeFileSync(outPath, output, "utf8");
    console.log(`  write  ${article.slug}  (${snippets.length} snippet${snippets.length === 1 ? "" : "s"})`);
  }
}

main();
