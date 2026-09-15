/**
 * The plugin version is what makes a refresh reach installed users.
 *
 * Claude Code (and Cursor/Codex) decide whether to update by comparing the
 * version string in the manifest against the one already installed. If it
 * matches, `/plugin update` and auto-update skip the plugin — so a corpus
 * refresh that does not move this string never reaches anybody, however many
 * commits land on main.
 *
 * Scheme is CalVer, `YY.M.PATCH`: patch counts releases within the month and
 * resets when the month rolls over. Note `26.9.0`, never `26.09.0` — semver
 * forbids leading zeros in numeric identifiers.
 */

import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { REPO_ROOT } from "./platforms.ts";

/** MAJOR.MINOR.PATCH, no leading zeros, no prerelease/build suffix. */
export const SEMVER_RE = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

/**
 * Every manifest carrying a version, and the key path it lives under.
 *
 * `.claude-plugin/marketplace.json` is deliberately absent: Claude Code takes
 * the `plugin.json` value and silently ignores a marketplace one, so a version
 * there could only ever be a second source of truth that goes stale.
 */
export const VERSION_FILES: ReadonlyArray<{ file: string; path: string[] }> = [
  { file: ".claude-plugin/plugin.json", path: ["version"] },
  { file: ".cursor-plugin/plugin.json", path: ["version"] },
  { file: ".cursor-plugin/marketplace.json", path: ["metadata", "version"] },
];

/** The manifest treated as authoritative when reading the current version. */
export const PRIMARY_VERSION_FILE = VERSION_FILES[0]!.file;

function getIn(value: unknown, path: string[]): unknown {
  let cursor: unknown = value;
  for (const key of path) {
    if (typeof cursor !== "object" || cursor === null || Array.isArray(cursor)) return undefined;
    cursor = (cursor as Record<string, unknown>)[key];
  }
  return cursor;
}

export function readVersion(file: string, path: string[]): unknown {
  const parsed: unknown = JSON.parse(readFileSync(resolve(REPO_ROOT, file), "utf8"));
  return getIn(parsed, path);
}

/**
 * Rewrites one version in place. Edits the raw text rather than
 * JSON.parse/stringify so key order and formatting survive untouched — these
 * manifests are hand-maintained and a reformatting diff would bury the change.
 */
export function writeVersion(file: string, path: string[], version: string): void {
  const absolute = resolve(REPO_ROOT, file);
  const source = readFileSync(absolute, "utf8");
  const key = path[path.length - 1]!;
  const pattern = new RegExp(`("${key}"\\s*:\\s*")[^"]*(")`);

  if (!pattern.test(source)) {
    throw new Error(`${file}: no "${key}" string field to rewrite`);
  }

  const updated = source.replace(pattern, `$1${version}$2`);
  if (updated !== source) writeFileSync(absolute, updated, "utf8");
}

/**
 * Next version for `now`: increments the patch when `current` is already in
 * this month, otherwise starts the month at 0.
 */
export function nextCalVer(current: unknown, now: Date = new Date()): string {
  const prefix = `${now.getUTCFullYear() % 100}.${now.getUTCMonth() + 1}`;

  // The trailing dot is load-bearing: without it prefix "26.1" would also
  // match "26.10.0" and October would reuse January's counter.
  if (typeof current === "string" && current.startsWith(`${prefix}.`)) {
    const patch = Number(current.slice(prefix.length + 1));
    if (Number.isInteger(patch) && patch >= 0) return `${prefix}.${patch + 1}`;
  }

  return `${prefix}.0`;
}
