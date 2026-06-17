/**
 * Validates frontmatter of every `polished/<platform>/<slug>.polished.md`
 * file against `pipeline/schema/polished.schema.json`. Also runs a small set
 * of structural invariants that JSON Schema can't express directly:
 *
 *   - `snippets[].index` values are contiguous and start at 0.
 *   - `layer` is `a` — the corpus is deterministic Layer A output only; there
 *     is no LLM rewrite stage. The `.polished.md` suffix is
 *     retained for filename stability, but the content is Layer A.
 *   - Snippet manifest length equals the count of `^```` opening fences in
 *     the body, so the manifest never drifts away from the file content.
 *
 * Exit code is non-zero on any failure. Designed to be wired into a
 * `pnpm validate:polished` script and a GH Actions check.
 */

import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import Ajv2020, { type ErrorObject } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { splitFrontmatter } from "./lib/frontmatter.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const SCHEMA_PATH = resolve(REPO_ROOT, "pipeline/schema/polished.schema.json");
const POLISHED_ROOT = resolve(REPO_ROOT, "polished");

interface Issue {
  file: string;
  message: string;
}

function loadSchema(): object {
  return JSON.parse(readFileSync(SCHEMA_PATH, "utf8"));
}

function listPolishedFiles(): string[] {
  if (!existsSync(POLISHED_ROOT)) return [];
  const out: string[] = [];
  for (const platform of readdirSync(POLISHED_ROOT)) {
    const platformDir = resolve(POLISHED_ROOT, platform);
    if (!statSync(platformDir).isDirectory()) continue;
    for (const file of readdirSync(platformDir)) {
      if (file.endsWith(".polished.md")) {
        out.push(resolve(platformDir, file));
      }
    }
  }
  return out.sort();
}

function countOpeningFences(body: string): number {
  // CommonMark allows code fences to be indented by 0–3 spaces. Stays in
  // lockstep with `collectSnippets` in `pipeline/src/lib/layer-a.ts` so the
  // manifest never disagrees with what the validator sees.
  const fenceRe = /^ {0,3}```/;
  let count = 0;
  let inside = false;
  for (const line of body.split(/\r?\n/)) {
    if (fenceRe.test(line)) {
      if (!inside) count++;
      inside = !inside;
    }
  }
  return count;
}

function formatAjvErrors(errors: readonly ErrorObject[] | null | undefined): string[] {
  if (!errors) return [];
  return errors.map((e) => {
    const where = e.instancePath || "(root)";
    return `${where} ${e.message ?? "is invalid"}`;
  });
}

function checkSnippetIndexContiguity(
  snippets: Array<{ index: unknown }>,
): string | undefined {
  for (let i = 0; i < snippets.length; i++) {
    if (snippets[i]?.index !== i) {
      return `snippets[${i}].index is ${JSON.stringify(snippets[i]?.index)}, expected ${i} (must be contiguous starting at 0)`;
    }
  }
  return undefined;
}

function relativeToRoot(absPath: string): string {
  return absPath.startsWith(REPO_ROOT + "/")
    ? absPath.slice(REPO_ROOT.length + 1)
    : absPath;
}

function main() {
  const schema = loadSchema();
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const validate = ajv.compile(schema);

  const files = listPolishedFiles();
  if (files.length === 0) {
    console.error(`No polished files found under ${POLISHED_ROOT}`);
    process.exit(1);
  }

  const issues: Issue[] = [];
  let ok = 0;

  for (const file of files) {
    const rel = relativeToRoot(file);
    const raw = readFileSync(file, "utf8");
    const { frontmatter, body } = splitFrontmatter(raw);

    const before = issues.length;

    if (!validate(frontmatter)) {
      for (const msg of formatAjvErrors(validate.errors)) {
        issues.push({ file: rel, message: msg });
      }
    }

    if (frontmatter.layer !== "a") {
      issues.push({
        file: rel,
        message: `frontmatter \`layer\` is ${JSON.stringify(frontmatter.layer)}, expected \`a\` (corpus is deterministic Layer A only; no LLM stage)`,
      });
    }

    const snippets = Array.isArray(frontmatter.snippets)
      ? (frontmatter.snippets as Array<{ index: unknown }>)
      : [];
    const contiguity = checkSnippetIndexContiguity(snippets);
    if (contiguity) issues.push({ file: rel, message: contiguity });

    const bodyFences = countOpeningFences(body);
    if (bodyFences !== snippets.length) {
      issues.push({
        file: rel,
        message: `snippet manifest length ${snippets.length} does not match body opening-fence count ${bodyFences}`,
      });
    }

    if (issues.length === before) ok++;
  }

  if (issues.length > 0) {
    console.error(`FAIL  ${issues.length} issue(s) across ${files.length - ok} of ${files.length} file(s):\n`);
    let lastFile = "";
    for (const issue of issues) {
      if (issue.file !== lastFile) {
        console.error(`  ${issue.file}`);
        lastFile = issue.file;
      }
      console.error(`    - ${issue.message}`);
    }
    process.exit(1);
  }

  console.log(`OK    ${files.length} polished file(s) validate against ${relativeToRoot(SCHEMA_PATH)}`);
}

main();
