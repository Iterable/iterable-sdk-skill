/**
 * Validates the frontmatter of every `iterable-android/reference/<slug>.md`
 * against `pipeline/schema/reference.schema.json`, and checks that the corpus
 * and the platform config agree on which slugs exist. That second half is what
 * catches a config edit that renames a slug without a refresh — the skill's
 * routing table points at slugs, so a missing file is a dead link.
 *
 * Exit code is non-zero on any failure.
 */

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";
import Ajv2020, { type ErrorObject } from "ajv/dist/2020.js";
import addFormats from "ajv-formats";
import { splitFrontmatter } from "./lib/frontmatter.ts";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const SCHEMA_PATH = resolve(REPO_ROOT, "pipeline/schema/reference.schema.json");
const CONFIG_DIR = resolve(REPO_ROOT, "pipeline/config");

interface PlatformConfig {
  platform: string;
  paths: { reference_dir: string };
  articles: Array<{ slug: string }>;
}

interface Issue {
  file: string;
  message: string;
}

function relativeToRoot(absPath: string): string {
  return absPath.startsWith(REPO_ROOT + "/") ? absPath.slice(REPO_ROOT.length + 1) : absPath;
}

function loadConfigs(): PlatformConfig[] {
  return readdirSync(CONFIG_DIR)
    .filter((f) => f.endsWith(".yml"))
    .map((f) => parseYaml(readFileSync(resolve(CONFIG_DIR, f), "utf8")) as PlatformConfig);
}

function formatAjvErrors(errors: readonly ErrorObject[] | null | undefined): string[] {
  if (!errors) return [];
  return errors.map((e) => `${e.instancePath || "(root)"} ${e.message ?? "is invalid"}`);
}

function main() {
  const ajv = new Ajv2020({ allErrors: true, strict: false });
  addFormats(ajv);
  const validate = ajv.compile(JSON.parse(readFileSync(SCHEMA_PATH, "utf8")));

  const issues: Issue[] = [];
  let checked = 0;

  for (const config of loadConfigs()) {
    const refDir = resolve(REPO_ROOT, config.paths.reference_dir);
    if (!existsSync(refDir)) {
      console.error(`FAIL  reference dir not found: ${config.paths.reference_dir}`);
      process.exit(1);
    }

    const present = new Set(readdirSync(refDir).filter((f) => f.endsWith(".md")));
    const expected = new Set(config.articles.map((a) => `${a.slug}.md`));

    for (const name of expected) {
      if (!present.has(name)) {
        issues.push({
          file: `${config.paths.reference_dir}/${name}`,
          message: `listed in pipeline/config/${config.platform}.yml but missing — run \`pnpm refresh:docs\``,
        });
      }
    }
    for (const name of present) {
      if (!expected.has(name)) {
        issues.push({
          file: `${config.paths.reference_dir}/${name}`,
          message: `not listed in pipeline/config/${config.platform}.yml — stale file, or a missing config entry`,
        });
      }
    }

    for (const name of [...present].sort()) {
      const file = resolve(refDir, name);
      const { frontmatter } = splitFrontmatter(readFileSync(file, "utf8"));
      checked++;
      if (!validate(frontmatter)) {
        for (const msg of formatAjvErrors(validate.errors)) {
          issues.push({ file: relativeToRoot(file), message: msg });
        }
      }
    }
  }

  if (issues.length > 0) {
    console.error(`FAIL  ${issues.length} issue(s):\n`);
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

  console.log(`OK    ${checked} reference doc(s) validate against ${relativeToRoot(SCHEMA_PATH)}`);
}

main();
