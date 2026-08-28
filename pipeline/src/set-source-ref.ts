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
 *   tsx src/set-source-ref.ts <sha> [label]
 *     Pin every top-level platform config.
 *   tsx src/set-source-ref.ts <platform> <sha> [label]
 *     Pin one config.
 *   pnpm set:source-ref -- android <sha> "master @ 2026-07-28"
 *
 * No-ops (exit 0, prints "unchanged") when the config already pins <sha>, so
 * the workflow can call it unconditionally for the platforms that changed.
 */

import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { basename } from "node:path";
import { parseDocument } from "yaml";
import {
  listPlatformConfigFiles,
  resolvePlatformConfigPath,
} from "./lib/platforms.ts";

const SHA_RE = /^[0-9a-f]{40}$/;

function pinConfig(configPath: string, sha: string, label: string | undefined): void {
  if (!existsSync(configPath)) {
    console.error(`Config not found: ${configPath}`);
    process.exit(1);
  }

  const name = basename(configPath);
  const doc = parseDocument(readFileSync(configPath, "utf8"));
  const current = doc.getIn(["source", "ref"]);
  if (current === sha) {
    console.log(`${name}: source.ref already ${sha.slice(0, 7)} — unchanged.`);
    return;
  }

  doc.setIn(["source", "ref"], sha);
  if (label) doc.setIn(["source", "ref_label"], label);

  writeFileSync(configPath, doc.toString(), "utf8");
  console.log(
    `${name}: pinned source.ref ${String(current).slice(0, 7)} → ${sha.slice(0, 7)}` +
      (label ? ` (${label})` : ""),
  );
}

function main(): void {
  // pnpm may forward the `--` separator through to the script, so drop it.
  const args = process.argv.slice(2).filter((a) => a !== "--");

  let configPaths: string[];
  let sha: string;
  let label: string | undefined;

  if (args[0] && SHA_RE.test(args[0])) {
    sha = args[0];
    label = args[1];
    configPaths = listPlatformConfigFiles();
  } else {
    const [platform, shaArg, labelArg] = args;
    if (!platform || !shaArg) {
      console.error("Usage: set-source-ref.ts [<platform>] <sha> [label]");
      process.exit(1);
    }
    sha = shaArg;
    label = labelArg;
    configPaths = [resolvePlatformConfigPath(platform)];
  }

  if (!SHA_RE.test(sha)) {
    console.error(
      `Refusing to pin a non-40-hex ref: "${sha}". Resolve the branch to a full commit sha first.`,
    );
    process.exit(1);
  }

  for (const configPath of configPaths) {
    pinConfig(configPath, sha, label);
  }
}

main();
