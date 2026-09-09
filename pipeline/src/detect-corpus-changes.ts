/**
 * After a refresh run, report which platform corpora git sees as changed
 * (tracked diffs and untracked files). Used by refresh-docs.yml so a first
 * corpus for a new platform is not missed by `git diff` alone, and so the PR
 * title/body can name only the platforms that actually changed.
 *
 * Writes `changed`, `platforms`, and `slugs` to GITHUB_OUTPUT when that env
 * var is set; always prints the same keys to stdout.
 *
 *   tsx src/detect-corpus-changes.ts
 */

import { appendFileSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { loadAllPlatformConfigs, REPO_ROOT } from "./lib/platforms.ts";

function git(args: string[]): string {
  return execFileSync("git", args, { cwd: REPO_ROOT, encoding: "utf8" });
}

function changedFiles(refDir: string): string[] {
  const tracked = git(["diff", "--name-only", "--", refDir])
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  const untracked = git(["ls-files", "--others", "--exclude-standard", "--", refDir])
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
  return [...new Set([...tracked, ...untracked])];
}

function slugFromPath(file: string): string | undefined {
  const base = file.split("/").pop();
  if (!base?.endsWith(".md")) return undefined;
  return base.slice(0, -".md".length);
}

function main(): void {
  const platforms: string[] = [];
  const slugs = new Set<string>();

  let loaded;
  try {
    loaded = loadAllPlatformConfigs();
  } catch (error) {
    console.error(error instanceof Error ? error.message : String(error));
    process.exit(1);
    return;
  }

  for (const { config } of loaded) {
    const files = changedFiles(config.paths.reference_dir);
    if (files.length === 0) continue;
    platforms.push(config.platform);
    for (const file of files) {
      const slug = slugFromPath(file);
      if (slug) slugs.add(slug);
    }
  }

  const out = {
    changed: platforms.length > 0 ? "true" : "false",
    platforms: platforms.join(","),
    slugs: [...slugs].sort().join(", "),
  };

  const lines = Object.entries(out).map(([key, value]) => `${key}=${value}`);
  for (const line of lines) console.log(line);

  const githubOutput = process.env.GITHUB_OUTPUT;
  if (githubOutput) {
    appendFileSync(githubOutput, lines.join("\n") + "\n");
  }
}

main();
