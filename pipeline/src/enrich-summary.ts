/**
 * Populates the `summary` frontmatter field on polished/layer-a markdown
 * files using `extractSummary`. Idempotent: skips files whose existing
 * summary already matches what the extractor would produce.
 *
 * Usage:
 *   pnpm enrich:summary <path...>
 *   pnpm enrich:summary ../polished/android/*.md
 *
 * Pass `--overwrite` to replace hand-edited summaries with the extractor's
 * output. By default, files with an existing summary are left alone.
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { splitFrontmatter, joinFrontmatter } from "./lib/frontmatter.ts";
import { extractSummary } from "./lib/summary.ts";

function main() {
  const args = process.argv.slice(2);
  const overwrite = args.includes("--overwrite");
  const paths = args.filter((a) => !a.startsWith("--"));
  if (paths.length === 0) {
    console.error("usage: pnpm enrich:summary [--overwrite] <path...>");
    process.exit(2);
  }

  let written = 0;
  let preserved = 0;
  let skipped = 0;
  let unsummarisable = 0;

  for (const arg of paths) {
    const filePath = resolve(process.cwd(), arg);
    if (!existsSync(filePath)) {
      console.error(`skip   ${arg}  (not found)`);
      skipped++;
      continue;
    }
    const raw = readFileSync(filePath, "utf8");
    const { frontmatter, body } = splitFrontmatter(raw);

    const existing = typeof frontmatter.summary === "string" ? frontmatter.summary : undefined;
    const extracted = extractSummary(body);

    if (!extracted) {
      console.warn(`warn   ${arg}  (no extractable prose; leaving summary as ${existing ? "is" : "unset"})`);
      unsummarisable++;
      continue;
    }

    if (existing && !overwrite) {
      console.log(`keep   ${arg}  (existing summary preserved; pass --overwrite to replace)`);
      preserved++;
      continue;
    }

    if (existing === extracted) {
      console.log(`ok     ${arg}  (summary already current)`);
      preserved++;
      continue;
    }

    const updated = { ...frontmatter, summary: extracted };
    writeFileSync(filePath, joinFrontmatter(updated, body), "utf8");
    console.log(`write  ${arg}  (${extracted.length} chars)`);
    written++;
  }

  console.log(`\n${written} written, ${preserved} preserved, ${unsummarisable} unsummarisable, ${skipped} skipped.`);
}

main();
