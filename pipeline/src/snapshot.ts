/**
 * Snapshot tool — keeps `iterable-android/snapshot/` in lockstep with
 * `polished/android/*.polished.md`. Two modes:
 *
 *   pnpm snapshot:refresh   — overwrite the snapshot dir from polished/android/
 *   pnpm snapshot:verify    — exit 1 if any file differs; CI gate
 *
 * Why a snapshot at all?
 *
 *   The skill's primary content source is Context7. The snapshot is the
 *   offline fallback: if the Context7 fetch fails or returns thin results,
 *   the agent reads from `iterable-android/snapshot/` and keeps working.
 *   Without it, a Context7 outage = the skill is dead.
 *
 *   The snapshot must never lag merged changes to `polished/`. `verify`
 *   runs in CI; if a reviewer updates a polished doc and forgets to run
 *   `snapshot:refresh`, CI catches it before merge.
 *
 * Filename mapping:
 *
 *   polished/android/<slug>.polished.md -> iterable-android/snapshot/<slug>.md
 *
 *   The `.polished` suffix is dropped in the snapshot because the snapshot
 *   isn't part of the pipeline corpus — it's a static asset shipped with
 *   the skill. Naming it `<slug>.md` keeps the agent-facing path readable.
 */

import { existsSync, mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const REPO_ROOT = resolve(__dirname, "../..");
const POLISHED_DIR = join(REPO_ROOT, "polished", "android");
const SNAPSHOT_DIR = join(REPO_ROOT, "iterable-android", "snapshot");
const POLISHED_SUFFIX = ".polished.md";
const SNAPSHOT_SUFFIX = ".md";

interface SnapshotEntry {
  slug: string;
  polishedPath: string;
  snapshotPath: string;
  content: string;
}

function collectPolished(): SnapshotEntry[] {
  if (!existsSync(POLISHED_DIR)) {
    console.error(`FAIL  polished dir not found: ${POLISHED_DIR}`);
    process.exit(2);
  }
  return readdirSync(POLISHED_DIR)
    .filter((name) => name.endsWith(POLISHED_SUFFIX))
    .sort()
    .map((name) => {
      const slug = name.slice(0, -POLISHED_SUFFIX.length);
      const polishedPath = join(POLISHED_DIR, name);
      return {
        slug,
        polishedPath,
        snapshotPath: join(SNAPSHOT_DIR, slug + SNAPSHOT_SUFFIX),
        content: readFileSync(polishedPath, "utf8"),
      };
    });
}

function collectStaleSnapshots(expectedNames: Set<string>): string[] {
  if (!existsSync(SNAPSHOT_DIR)) return [];
  return readdirSync(SNAPSHOT_DIR)
    .filter((name) => name.endsWith(SNAPSHOT_SUFFIX))
    .filter((name) => !expectedNames.has(name))
    .map((name) => join(SNAPSHOT_DIR, name));
}

function refresh(): void {
  const entries = collectPolished();
  mkdirSync(SNAPSHOT_DIR, { recursive: true });

  const expectedNames = new Set(entries.map((e) => e.slug + SNAPSHOT_SUFFIX));
  const stale = collectStaleSnapshots(expectedNames);
  for (const path of stale) rmSync(path);

  for (const entry of entries) {
    writeFileSync(entry.snapshotPath, entry.content);
  }

  console.log(
    `OK    refreshed ${entries.length} snapshot(s) into iterable-android/snapshot/` +
      (stale.length ? ` (removed ${stale.length} stale file(s))` : ""),
  );
}

function verify(): void {
  const entries = collectPolished();
  const expectedNames = new Set(entries.map((e) => e.slug + SNAPSHOT_SUFFIX));
  const issues: string[] = [];

  for (const entry of entries) {
    if (!existsSync(entry.snapshotPath)) {
      issues.push(`missing snapshot: iterable-android/snapshot/${entry.slug}${SNAPSHOT_SUFFIX}`);
      continue;
    }
    const have = readFileSync(entry.snapshotPath, "utf8");
    if (have !== entry.content) {
      issues.push(`drift: iterable-android/snapshot/${entry.slug}${SNAPSHOT_SUFFIX} differs from polished/android/${entry.slug}${POLISHED_SUFFIX}`);
    }
  }

  for (const path of collectStaleSnapshots(expectedNames)) {
    issues.push(`stale snapshot (no matching polished source): ${path.slice(REPO_ROOT.length + 1)}`);
  }

  if (issues.length === 0) {
    console.log(`OK    ${entries.length} snapshot(s) match polished/android/`);
    return;
  }
  console.error(`FAIL  ${issues.length} snapshot drift issue(s):`);
  for (const issue of issues) console.error(`  - ${issue}`);
  console.error(`\nRun \`pnpm snapshot:refresh\` to sync the snapshot dir.`);
  process.exit(1);
}

function main(): void {
  const mode = process.argv[2];
  switch (mode) {
    case "refresh":
      refresh();
      return;
    case "verify":
      verify();
      return;
    default:
      console.error("usage: tsx src/snapshot.ts <refresh|verify>");
      process.exit(2);
  }
}

main();
