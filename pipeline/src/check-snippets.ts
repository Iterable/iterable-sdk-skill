/**
 * Advisory Kotlin snippet check.
 *
 * Extracts every fenced ``` kotlin block from `*.polished.md`, writes each
 * to a temp `.kts` file, and runs `kotlinc -script -nowarn`. Reports any
 * errors as advisory output. Always exits 0; failures do not block CI.
 *
 * Why advisory only (v1):
 *   `kotlinc -script` runs full semantic analysis (name resolution, type
 *   checking) rather than parse-only. Without a classpath, every reference
 *   to `IterableApi`, Android framework symbols, AndroidX, or even local
 *   variables defined outside the snippet fragment fails as "unresolved
 *   reference". The signal-to-noise ratio at that point is too low to make
 *   this a blocking gate.
 *
 *   v2 of this script (tracked follow-up) will load the Iterable SDK aar
 *   (`iterableapi-3.7.0.aar`), `android.jar` from the API 21 platform, and
 *   the AndroidX subset onto the classpath so name resolution works. At
 *   that point the gate becomes blocking.
 *
 * What this still catches (advisory):
 *   - Pure parse errors (expecting brace, malformed string, etc.) — they
 *     show up alongside unresolved-reference errors in the output, so a
 *     reviewer skimming the lint can still spot them.
 *
 * Behaviour:
 *   - `kotlinc` on PATH        → runs the check, reports errors, exits 0.
 *   - `kotlinc` missing        → warn, exits 0. CI installs Kotlin
 *     1.9.24 so the advisory output is always produced there.
 *
 * Usage:
 *   pnpm check:snippets
 */

import { execFileSync, spawnSync } from "node:child_process";
import { mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const POLISHED_ROOT = resolve(REPO_ROOT, "polished");

interface KotlinSnippet {
  file: string;
  index: number;
  body: string;
}

function relativeToRoot(absPath: string): string {
  return absPath.startsWith(REPO_ROOT + "/")
    ? absPath.slice(REPO_ROOT.length + 1)
    : absPath;
}

function hasKotlinc(): boolean {
  const probe = spawnSync("kotlinc", ["-version"], { stdio: "ignore" });
  return probe.status === 0;
}

function* walkPolished(): Generator<string> {
  for (const platform of readdirSync(POLISHED_ROOT)) {
    const dir = resolve(POLISHED_ROOT, platform);
    if (!statSync(dir).isDirectory()) continue;
    for (const f of readdirSync(dir)) {
      if (f.endsWith(".polished.md")) yield resolve(dir, f);
    }
  }
}

function extractKotlinSnippets(path: string): KotlinSnippet[] {
  const text = readFileSync(path, "utf8");
  const lines = text.split(/\r?\n/);
  const openRe = /^ {0,3}```([a-zA-Z0-9_+-]*)\s*$/;
  const closeRe = /^ {0,3}```\s*$/;
  const out: KotlinSnippet[] = [];
  let inFence = false;
  let fenceLang = "";
  let buffer: string[] = [];
  let snippetIndex = 0;
  for (const line of lines) {
    const open = openRe.exec(line);
    if (!inFence && open) {
      inFence = true;
      fenceLang = (open[1] ?? "").toLowerCase();
      buffer = [];
      continue;
    }
    if (inFence && closeRe.test(line)) {
      if (fenceLang === "kotlin") {
        out.push({ file: path, index: snippetIndex, body: buffer.join("\n") });
      }
      snippetIndex++;
      inFence = false;
      fenceLang = "";
      buffer = [];
      continue;
    }
    if (inFence) buffer.push(line);
  }
  return out;
}

function runKotlinc(snippet: KotlinSnippet, workDir: string): { ok: boolean; stderr: string } {
  const scratchPath = join(workDir, `snippet-${snippet.index}.kts`);
  writeFileSync(scratchPath, snippet.body, "utf8");
  const result = spawnSync(
    "kotlinc",
    ["-script", "-nowarn", scratchPath],
    { encoding: "utf8", timeout: 30_000 },
  );
  if (result.status === 0) return { ok: true, stderr: "" };
  const stderr = `${result.stderr ?? ""}${result.stdout ?? ""}`.trim();
  return { ok: false, stderr };
}

function main() {
  const snippetsByFile = new Map<string, KotlinSnippet[]>();
  for (const file of walkPolished()) {
    const snippets = extractKotlinSnippets(file);
    if (snippets.length > 0) snippetsByFile.set(file, snippets);
  }

  const totalSnippets = [...snippetsByFile.values()].reduce(
    (acc, list) => acc + list.length,
    0,
  );

  if (totalSnippets === 0) {
    console.log("OK    no kotlin snippets to check");
    return;
  }

  if (!hasKotlinc()) {
    console.warn(
      `WARN  kotlinc not on PATH; skipping ${totalSnippets} kotlin snippet check(s).`,
    );
    console.warn(
      `      Install Kotlin (https://kotlinlang.org/docs/command-line.html) to enable locally.`,
    );
    console.warn(`      The check is advisory in v1 (no classpath, so most errors`);
    console.warn(`      will be 'unresolved reference' noise); v2 adds the SDK aar.`);
    return;
  }

  const versionLine = (() => {
    try {
      return execFileSync("kotlinc", ["-version"], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
    } catch {
      return "kotlinc";
    }
  })();
  console.log(`Using ${versionLine}\n`);

  const workDir = mkdtempSync(join(tmpdir(), "iterable-snippets-"));
  let failures = 0;
  const failureBlocks: string[] = [];
  try {
    for (const [file, snippets] of snippetsByFile) {
      const rel = relativeToRoot(file);
      for (const snippet of snippets) {
        const { ok, stderr } = runKotlinc(snippet, workDir);
        if (ok) {
          process.stdout.write(".");
          continue;
        }
        failures++;
        process.stdout.write("F");
        failureBlocks.push(
          `${rel}  snippet #${snippet.index}\n${stderr.split("\n").map((l) => `  ${l}`).join("\n")}`,
        );
      }
    }
    process.stdout.write("\n\n");
  } finally {
    rmSync(workDir, { recursive: true, force: true });
  }

  if (failures === 0) {
    console.log(`OK    ${totalSnippets} kotlin snippet(s) parsed cleanly`);
    return;
  }
  console.warn(`WARN  ${failures} of ${totalSnippets} kotlin snippet(s) reported errors (advisory only):`);
  for (const block of failureBlocks) {
    console.warn("");
    console.warn(block);
  }
  console.warn("");
  console.warn("Most errors here will be 'unresolved reference' for SDK / framework symbols.");
  console.warn("That is expected with no classpath; v2 of this script (tracked follow-up)");
  console.warn("will load the Iterable SDK + android.jar + AndroidX so this becomes strict.");
}

main();
