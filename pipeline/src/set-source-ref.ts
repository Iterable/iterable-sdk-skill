/**
 * Writes a resolved source ref back into pipeline/config/<platform>.yml.
 *
 * The auto-refresh workflow fetches docs at a moving ref (the dispatched docs
 * commit, or `master`), then calls this to advance the config's pinned
 * `source.ref` + `ref_label` to that commit — so the pin stays an honest record
 * of "last refreshed at" and future diffs reflect only new upstream changes.
 * Comments in the YAML are preserved (parseDocument, not parse+stringify).
 *
 * Usage:
 *   tsx src/set-source-ref.ts <platform> <sha> [label]
 *   pnpm set:source-ref -- android <sha> "master @ 2026-07-28"
 *
 * No-ops (exit 0, prints "unchanged") when the config already pins <sha>, so
 * the workflow can call it unconditionally.
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parseDocument } from "yaml";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");

const SHA_RE = /^[0-9a-f]{40}$/;

function main(): void {
  const [platform, sha, label] = process.argv.slice(2);
  if (!platform || !sha) {
    console.error("Usage: set-source-ref.ts <platform> <sha> [label]");
    process.exit(1);
  }
  if (!SHA_RE.test(sha)) {
    console.error(`Refusing to pin a non-40-hex ref: "${sha}". Resolve the branch to a full commit sha first.`);
    process.exit(1);
  }

  const configPath = resolve(CONFIG_DIR, `${platform}.yml`);
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }

  const doc = parseDocument(readFileSync(configPath, "utf8"));
  const current = doc.getIn(["source", "ref"]);
  if (current === sha) {
    console.log(`source.ref already ${sha.slice(0, 7)} — unchanged.`);
    return;
  }

  doc.setIn(["source", "ref"], sha);
  if (label) doc.setIn(["source", "ref_label"], label);

  writeFileSync(configPath, doc.toString(), "utf8");
  console.log(
    `Pinned source.ref ${String(current).slice(0, 7)} → ${sha.slice(0, 7)}` +
      (label ? ` (${label})` : ""),
  );
}

main();
