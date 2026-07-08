/**
 * Validates Cursor/Claude plugin manifests and MCP config files.
 *
 * Checks:
 *   - `.cursor-plugin/plugin.json` and `.cursor-plugin/marketplace.json` parse
 *     and have required fields.
 *   - `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` parse.
 *   - `mcp.json` and `.mcp.json` exist and have identical `mcpServers` content.
 *   - Declared skill paths exist on disk.
 *
 * Exit code is non-zero on any failure.
 */

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");

const PLUGIN_NAME_RE = /^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$/;

interface Issue {
  file: string;
  message: string;
}

const issues: Issue[] = [];

function fail(file: string, message: string): void {
  issues.push({ file, message });
}

function readJson(file: string): unknown {
  const path = resolve(REPO_ROOT, file);
  if (!existsSync(path)) {
    fail(file, "file is missing");
    return undefined;
  }
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(file, `invalid JSON: ${error instanceof Error ? error.message : String(error)}`);
    return undefined;
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function assertPluginName(file: string, name: unknown): void {
  if (typeof name !== "string" || name.length === 0) {
    fail(file, "`name` must be a non-empty string");
    return;
  }
  if (!PLUGIN_NAME_RE.test(name)) {
    fail(file, `\`name\` "${name}" must be lowercase kebab-case`);
  }
}

function assertSkillPaths(file: string, skills: unknown): void {
  if (skills === undefined) return;
  const paths = Array.isArray(skills) ? skills : [skills];
  for (const entry of paths) {
    if (typeof entry !== "string") {
      fail(file, "`skills` entries must be strings");
      continue;
    }
    const skillDir = resolve(REPO_ROOT, entry);
    const skillMd = resolve(skillDir, "SKILL.md");
    if (!existsSync(skillMd)) {
      fail(file, `skill path "${entry}" is missing SKILL.md`);
    }
  }
}

function validateCursorPlugin(): void {
  const file = ".cursor-plugin/plugin.json";
  const manifest = readJson(file);
  if (!isRecord(manifest)) return;

  assertPluginName(file, manifest.name);
  assertSkillPaths(file, manifest.skills);

  if ("mcpServers" in manifest) {
    fail(
      file,
      "omit `mcpServers` — Cursor auto-discovers `mcp.json` at the plugin root",
    );
  }
}

function validateCursorMarketplace(): void {
  const file = ".cursor-plugin/marketplace.json";
  const manifest = readJson(file);
  if (!isRecord(manifest)) return;

  assertPluginName(file, manifest.name);

  if (!isRecord(manifest.owner) || typeof manifest.owner.name !== "string") {
    fail(file, "`owner.name` is required");
  }

  if (!Array.isArray(manifest.plugins) || manifest.plugins.length === 0) {
    fail(file, "`plugins` must be a non-empty array");
    return;
  }

  for (const entry of manifest.plugins) {
    if (!isRecord(entry)) {
      fail(file, "each `plugins` entry must be an object");
      continue;
    }
    assertPluginName(file, entry.name);
    if (typeof entry.source !== "string" || entry.source.length === 0) {
      fail(file, "each `plugins` entry needs a `source` path");
    }
  }
}

function validateClaudePlugin(): void {
  const file = ".claude-plugin/plugin.json";
  const manifest = readJson(file);
  if (!isRecord(manifest)) return;

  assertPluginName(file, manifest.name);
  assertSkillPaths(file, manifest.skills);
}

function validateClaudeMarketplace(): void {
  const file = ".claude-plugin/marketplace.json";
  const manifest = readJson(file);
  if (!isRecord(manifest)) return;

  assertPluginName(file, manifest.name);

  if (!isRecord(manifest.owner) || typeof manifest.owner.name !== "string") {
    fail(file, "`owner.name` is required");
  }

  if (!Array.isArray(manifest.plugins) || manifest.plugins.length === 0) {
    fail(file, "`plugins` must be a non-empty array");
  }
}

function validateMcpConfigs(): void {
  const cursorMcp = readJson("mcp.json");
  const claudeMcp = readJson(".mcp.json");
  if (!isRecord(cursorMcp) || !isRecord(claudeMcp)) return;

  const cursorServers = cursorMcp.mcpServers;
  const claudeServers = claudeMcp.mcpServers;

  if (!isRecord(cursorServers)) {
    fail("mcp.json", "`mcpServers` must be an object");
    return;
  }
  if (!isRecord(claudeServers)) {
    fail(".mcp.json", "`mcpServers` must be an object");
    return;
  }

  const cursorJson = JSON.stringify(cursorServers);
  const claudeJson = JSON.stringify(claudeServers);
  if (cursorJson !== claudeJson) {
    fail("mcp.json", "`mcpServers` must match `.mcp.json` exactly");
  }

  const context7 = cursorServers.context7;
  if (!isRecord(context7)) {
    fail("mcp.json", "`mcpServers.context7` is required");
    return;
  }
  if (context7.url !== "https://mcp.context7.com/mcp") {
    fail("mcp.json", "`mcpServers.context7.url` must point at Context7");
  }
}

function main(): void {
  validateCursorPlugin();
  validateCursorMarketplace();
  validateClaudePlugin();
  validateClaudeMarketplace();
  validateMcpConfigs();

  if (issues.length === 0) {
    console.log("validate-plugins: OK");
    return;
  }

  console.error(`validate-plugins: ${issues.length} issue(s)\n`);
  for (const issue of issues) {
    console.error(`  ${issue.file}: ${issue.message}`);
  }
  process.exit(1);
}

main();
