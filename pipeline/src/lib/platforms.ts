/**
 * Platform refresh configs live as top-level `pipeline/config/*.yml`.
 * Nested files (`pipeline/config/pitfalls/`) are not platform configs.
 */

import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const HERE = dirname(fileURLToPath(import.meta.url));
export const REPO_ROOT = resolve(HERE, "../../..");
export const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");

export const SHA_RE = /^[0-9a-f]{40}$/;

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

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value;
}

/**
 * Parse and check one platform YAML. The filename stem must equal `platform`
 * so detect-corpus-changes and set-source-ref look up the same file.
 */
export function loadPlatformConfig(configPath: string): PlatformConfig {
  const file = basename(configPath);
  const stem = basename(configPath, ".yml");
  const parsed: unknown = parseYaml(readFileSync(configPath, "utf8"));
  if (!isRecord(parsed)) {
    throw new Error(`${file}: config must be a mapping`);
  }

  const platform = requireString(parsed.platform, `${file}: platform`);
  if (platform !== stem) {
    throw new Error(`${file}: platform "${platform}" must match filename stem "${stem}"`);
  }

  if (!isRecord(parsed.source)) {
    throw new Error(`${file}: source must be a mapping`);
  }
  const sourceRepo = requireString(parsed.source.repo, `${file}: source.repo`);
  const sourceRef = requireString(parsed.source.ref, `${file}: source.ref`);
  const refLabel =
    parsed.source.ref_label === undefined
      ? undefined
      : requireString(parsed.source.ref_label, `${file}: source.ref_label`);

  if (!isRecord(parsed.sdk)) {
    throw new Error(`${file}: sdk must be a mapping`);
  }
  const sdkRepo = requireString(parsed.sdk.repo, `${file}: sdk.repo`);
  const sdkTag = requireString(parsed.sdk.tag, `${file}: sdk.tag`);
  const sdkArtifact = requireString(parsed.sdk.artifact, `${file}: sdk.artifact`);
  const changelogPath = requireString(parsed.sdk.changelog_path, `${file}: sdk.changelog_path`);

  if (!isRecord(parsed.paths)) {
    throw new Error(`${file}: paths must be a mapping`);
  }
  const referenceDir = requireString(parsed.paths.reference_dir, `${file}: paths.reference_dir`);

  if (!Array.isArray(parsed.articles)) {
    throw new Error(`${file}: articles must be a list`);
  }

  const slugs = new Set<string>();
  const articles: ArticleConfig[] = parsed.articles.map((raw, i) => {
    if (!isRecord(raw)) {
      throw new Error(`${file}: articles[${i}] must be a mapping`);
    }
    const slug = requireString(raw.slug, `${file}: articles[${i}].slug`);
    if (slugs.has(slug)) {
      throw new Error(`${file}: duplicate article slug "${slug}"`);
    }
    slugs.add(slug);
    const archetype = requireString(raw.archetype, `${file}: articles[${i}].archetype`);
    if (archetype !== "integration" && archetype !== "feature" && archetype !== "identity") {
      throw new Error(`${file}: articles[${i}].archetype must be integration, feature, or identity`);
    }
    return {
      slug,
      source_path: requireString(raw.source_path, `${file}: articles[${i}].source_path`),
      feature: requireString(raw.feature, `${file}: articles[${i}].feature`),
      archetype,
    };
  });

  return {
    platform,
    source: { repo: sourceRepo, ref: sourceRef, ref_label: refLabel },
    sdk: { repo: sdkRepo, tag: sdkTag, artifact: sdkArtifact, changelog_path: changelogPath },
    paths: { reference_dir: referenceDir },
    articles,
  };
}

function assertUniqueAcrossConfigs(configs: Array<{ path: string; config: PlatformConfig }>): void {
  const platforms = new Map<string, string>();
  const dirs = new Map<string, string>();
  for (const { path, config } of configs) {
    const file = basename(path);
    const prevPlatform = platforms.get(config.platform);
    if (prevPlatform) {
      throw new Error(`platform "${config.platform}" is defined in both ${prevPlatform} and ${file}`);
    }
    platforms.set(config.platform, file);
    const prevDir = dirs.get(config.paths.reference_dir);
    if (prevDir) {
      throw new Error(
        `paths.reference_dir "${config.paths.reference_dir}" is defined in both ${prevDir} and ${file}`,
      );
    }
    dirs.set(config.paths.reference_dir, file);
  }
}

export function loadAllPlatformConfigs(): Array<{ path: string; config: PlatformConfig }> {
  const loaded = listPlatformConfigFiles().map((path) => ({
    path,
    config: loadPlatformConfig(path),
  }));
  if (loaded.length === 0) {
    throw new Error(`No platform configs in ${CONFIG_DIR}`);
  }
  assertUniqueAcrossConfigs(loaded);
  return loaded;
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
  return loadAllPlatformConfigs().map((c) => c.path);
}
