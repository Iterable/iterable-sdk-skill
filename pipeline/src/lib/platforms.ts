/**
 * Platform refresh configs live as top-level `pipeline/config/*.yml`.
 * Nested files (`pipeline/config/pitfalls/`) are not platform configs.
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "../../..");
export const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");

export interface ArticleConfig {
  slug: string;
  source_path: string;
  feature: string;
  archetype: "integration" | "feature" | "identity";
}

export interface PlatformConfig {
  platform: string;
  source: { repo: string; ref: string; ref_label?: string };
  sdk: { repo: string; tag: string; artifact: string; changelog_path: string };
  paths: { reference_dir: string };
  articles: ArticleConfig[];
}

export function listPlatformConfigFiles(): string[] {
  return readdirSync(CONFIG_DIR)
    .filter((f) => f.endsWith(".yml"))
    .sort()
    .map((f) => resolve(CONFIG_DIR, f));
}

export function loadPlatformConfig(configPath: string): PlatformConfig {
  return parseYaml(readFileSync(configPath, "utf8")) as PlatformConfig;
}

export function resolvePlatformConfigPath(platform: string): string {
  return resolve(CONFIG_DIR, `${platform}.yml`);
}

/**
 * No argument → every top-level platform config.
 * A platform name → that one file (must exist).
 */
export function resolveConfigPaths(platformArg: string | undefined): string[] {
  if (platformArg) {
    const path = resolvePlatformConfigPath(platformArg);
    if (!existsSync(path)) {
      throw new Error(`Config not found: ${path}`);
    }
    return [path];
  }
  const all = listPlatformConfigFiles();
  if (all.length === 0) {
    throw new Error(`No platform configs in ${CONFIG_DIR}`);
  }
  return all;
}
