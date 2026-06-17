/**
 * Recomputes the `snippets` array in the frontmatter of one or more polished
 * markdown files by re-running Layer A's snippet collector against the body.
 *
 * Use when:
 *   - The body has been manually edited (e.g. surgical re-polish of a
 *     cross-platform article) and the existing manifest is stale.
 *   - Layer A's collector logic changed (bug fix, new feature) and the
 *     manifest needs to be regenerated without otherwise rewriting the body.
 *
 * Usage:
 *   pnpm recompute:manifest <path...>
 *   pnpm recompute:manifest polished/android/android-sdk.polished.md
 *   pnpm recompute:manifest polished/android/*.polished.md
 *
 * The body is untouched; only the `snippets` field in the frontmatter is
 * replaced and `polished_at` is refreshed.
 */

import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { splitFrontmatter, joinFrontmatter } from "./lib/frontmatter.ts";
import { collectSnippets } from "./lib/layer-a.ts";

function main() {
  const paths = process.argv.slice(2);
  if (paths.length === 0) {
    console.error("usage: pnpm recompute:manifest <path...>");
    process.exit(2);
  }

  let changed = 0;
  let unchanged = 0;
  for (const arg of paths) {
    const filePath = resolve(process.cwd(), arg);
    if (!existsSync(filePath)) {
      console.error(`skip   ${arg}  (not found)`);
      continue;
    }
    const raw = readFileSync(filePath, "utf8");
    const { frontmatter, body } = splitFrontmatter(raw);

    const newSnippets = collectSnippets(body);
    const oldSnippets = Array.isArray(frontmatter.snippets)
      ? frontmatter.snippets
      : [];

    const same =
      JSON.stringify(oldSnippets) === JSON.stringify(newSnippets);
    if (same) {
      console.log(`ok     ${arg}  (${newSnippets.length} snippet${newSnippets.length === 1 ? "" : "s"}, unchanged)`);
      unchanged++;
      continue;
    }

    const updated = {
      ...frontmatter,
      snippets: newSnippets,
      polished_at: new Date().toISOString(),
    };
    writeFileSync(filePath, joinFrontmatter(updated, body), "utf8");
    console.log(
      `write  ${arg}  (${oldSnippets.length} → ${newSnippets.length} snippet${newSnippets.length === 1 ? "" : "s"})`,
    );
    changed++;
  }
  console.log(`\n${changed} updated, ${unchanged} unchanged.`);
}

main();
