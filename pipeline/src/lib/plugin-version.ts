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

/**
 * Prerelease suffix on every version while the skill is in private beta, so a
 * developer can see what they installed is not GA. Set to "" to ship without
 * one — `26.9.5-beta` → `26.9.6` is an upgrade under semver precedence, and
 * both the writer and the validator follow this constant.
 *
 * Prereleases do not affect update detection, which compares version strings
 * for distinctness. They are excluded from *dependency* semver ranges unless a
 * consumer opts in, which matters only if another plugin ever depends on this
 * one.
 */
// Typed as `string`, not inferred as the literal, so the `=== ""` branches that
// handle dropping the suffix stay reachable to the compiler.
export const PRERELEASE: string = "beta";

/**
 * MAJOR.MINOR.PATCH with an optional prerelease, no build metadata. Numeric
 * identifiers reject leading zeros, so `26.09.0` fails.
 */
export const SEMVER_RE =
  /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?$/;

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

/** Strips any prerelease suffix, so "26.9.3-beta" parses as "26.9.3". */
function core(version: unknown): string {
  return typeof version === "string" ? version.split("-")[0]! : "";
}

/** True when `version` carries the prerelease suffix this repo currently ships. */
export function hasExpectedPrerelease(version: string): boolean {
  return PRERELEASE === "" ? !version.includes("-") : version.endsWith(`-${PRERELEASE}`);
}

/**
 * Next version for `now`: increments the patch when `current` is already in
 * this month, otherwise starts the month at 0.
 */
export function nextCalVer(current: unknown, now: Date = new Date()): string {
  const prefix = `${now.getUTCFullYear() % 100}.${now.getUTCMonth() + 1}`;
  const suffix = PRERELEASE === "" ? "" : `-${PRERELEASE}`;
  const previous = core(current);

  // The trailing dot is load-bearing: without it prefix "26.1" would also
  // match "26.10.0" and October would reuse January's counter.
  let patch = 0;
  if (previous.startsWith(`${prefix}.`)) {
    const n = Number(previous.slice(prefix.length + 1));
    if (Number.isInteger(n) && n >= 0) patch = n + 1;
  }

  return `${prefix}.${patch}${suffix}`;
}
