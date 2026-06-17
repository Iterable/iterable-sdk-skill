/**
 * Non-blocking chunking lint for polished markdown.
 *
 * Surfaces warnings that hurt agent / Context7 retrieval quality but do
 * not invalidate the corpus. Always exits 0; the warnings are advisory.
 *
 * Checks:
 *   - Oversize fenced code block (>{MAX_FENCE_LINES} lines). Long fences
 *     get sliced into chunks by retrievers and break mid-statement.
 *   - Fenced code block with no language tag. Chunkers and renderers
 *     can't highlight or filter by language; agents have to guess.
 *   - Deep heading (h5/h6). Retrievers struggle to anchor on these and
 *     prefer to break them into separate chunks, fragmenting context.
 *
 * Usage: `pnpm lint:chunking`
 */

import { readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const POLISHED_ROOT = resolve(REPO_ROOT, "polished");

const MAX_FENCE_LINES = 60;
// Markdown supports h1–h6. Real-world technical docs occasionally need h5
// for legitimate sub-sub-sub-sections (e.g. `Step 5.6.1: Register an auth
// handler` nested under `Step 5.6: Handle JWT-enabled API keys`). Anchoring
// gets noticeably worse at h6, so the lint floor sits there.
const MAX_HEADING_DEPTH = 5;

interface Warning {
  file: string;
  line: number;
  message: string;
}

function relativeToRoot(absPath: string): string {
  return absPath.startsWith(REPO_ROOT + "/")
    ? absPath.slice(REPO_ROOT.length + 1)
    : absPath;
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

function lintFile(file: string): Warning[] {
  const out: Warning[] = [];
  const rel = relativeToRoot(file);
  const lines = readFileSync(file, "utf8").split(/\r?\n/);

  const openRe = /^ {0,3}```([a-zA-Z0-9_+-]*)\s*$/;
  const closeRe = /^ {0,3}```\s*$/;
  let inFence = false;
  let fenceLang = "";
  let fenceStart = -1;
  let fenceLineCount = 0;

  let inFrontmatter = false;
  let frontmatterClosed = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i] ?? "";
    const lineNum = i + 1;

    if (i === 0 && line === "---") {
      inFrontmatter = true;
      continue;
    }
    if (inFrontmatter && !frontmatterClosed) {
      if (line === "---") {
        inFrontmatter = false;
        frontmatterClosed = true;
      }
      continue;
    }

    const open = openRe.exec(line);
    if (!inFence && open) {
      inFence = true;
      fenceLang = open[1] ?? "";
      fenceStart = lineNum;
      fenceLineCount = 0;
      if (fenceLang === "") {
        out.push({
          file: rel,
          line: lineNum,
          message: "fenced code block has no language tag (chunkers and renderers cannot filter by language)",
        });
      }
      continue;
    }
    if (inFence && closeRe.test(line)) {
      if (fenceLineCount > MAX_FENCE_LINES) {
        out.push({
          file: rel,
          line: fenceStart,
          message: `${fenceLang || "no-lang"} code block is ${fenceLineCount} lines (>${MAX_FENCE_LINES}); retrievers will slice it and may break mid-statement`,
        });
      }
      inFence = false;
      fenceLang = "";
      fenceStart = -1;
      fenceLineCount = 0;
      continue;
    }
    if (inFence) {
      fenceLineCount++;
      continue;
    }

    const headingMatch = /^(#{1,6})\s+\S/.exec(line);
    if (headingMatch) {
      const depth = headingMatch[1]!.length;
      if (depth > MAX_HEADING_DEPTH) {
        out.push({
          file: rel,
          line: lineNum,
          message: `heading depth ${depth} (>${MAX_HEADING_DEPTH}); retrievers struggle to anchor on h${depth} and fragment surrounding context`,
        });
      }
    }
  }
  return out;
}

function main() {
  const warnings: Warning[] = [];
  let files = 0;
  for (const file of walkPolished()) {
    files++;
    warnings.push(...lintFile(file));
  }

  if (warnings.length === 0) {
    console.log(`OK    ${files} polished file(s) clean (no chunking warnings)`);
    return;
  }

  console.log(`WARN  ${warnings.length} chunking warning(s) across ${files} file(s) — advisory only, does not fail CI:\n`);
  let last = "";
  for (const w of warnings) {
    if (w.file !== last) {
      console.log(`  ${w.file}`);
      last = w.file;
    }
    console.log(`    L${w.line}  ${w.message}`);
  }
}

main();
