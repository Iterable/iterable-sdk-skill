/**
 * Shared types + loaders for the before/after eval harness.
 *
 * The eval answers the one question a checklist can't: does an agent armed
 * with the iterable-android skill actually produce better integration code
 * than the same agent without it? We measure it deterministically — no model
 * scores the output. Each scenario carries regex `require`/`forbid` checks
 * tied to documented PITFALLS.md traps; the scorer (eval-score.ts) just runs
 * those patterns over a transcript. Same transcript in = same score out.
 *
 * Data lives at the repo root under eval/ (scenarios, transcripts, results,
 * report) so a reviewer or presenter finds it where they'd look; the tools
 * that read/write it live here under pipeline/src like every other stage.
 */

import { readFileSync, readdirSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { parse as parseYaml } from "yaml";

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "../../..");
export const EVAL_ROOT = resolve(REPO_ROOT, "eval");

export type CheckKind = "require" | "forbid";
export type Arm = "baseline" | "skill";

export interface Check {
  id: string;
  kind: CheckKind;
  weight: number;
  pattern: string;
  rationale: string;
  /** Pitfall id from config/pitfalls/android.yml, when this check guards a known trap. */
  pitfall?: number;
  /** A failed critical check fails the whole scenario regardless of weighted score. */
  critical?: boolean;
}

export interface Scenario {
  id: string;
  title: string;
  prompt: string;
  checks: Check[];
}

export interface ScenarioSet {
  platform: string;
  skill: string;
  expectations_version: string;
  scenarios: Scenario[];
}

export interface CheckResult extends Check {
  /** require: pattern found. forbid: pattern absent. */
  passed: boolean;
  /** Snippet of the matched text (for forbid fails / require passes), for the report. */
  evidence?: string;
}

export interface ScenarioScore {
  id: string;
  title: string;
  arm: Arm;
  checks: CheckResult[];
  earned: number;
  possible: number;
  /** earned / possible, 0..1. */
  ratio: number;
  /** A critical check failed → the integration is silently broken. */
  brokenByCritical: boolean;
  failedCritical: string[];
}

export interface ArmSummary {
  arm: Arm;
  scenarios: ScenarioScore[];
  earned: number;
  possible: number;
  ratio: number;
  scenariosPassed: number;
  scenariosBrokenByCritical: number;
}

export interface EvalResults {
  platform: string;
  skill: string;
  expectations_version: string;
  /** Stamped by the caller (scripts can't call Date.now mid-run elsewhere; here it's fine). */
  generated_at: string;
  arms: Record<Arm, ArmSummary>;
}

export function loadScenarioSet(platform: string): ScenarioSet {
  const path = resolve(EVAL_ROOT, "scenarios", `${platform}.yml`);
  const parsed = parseYaml(readFileSync(path, "utf8")) as ScenarioSet;
  validateScenarioSet(parsed, path);
  return parsed;
}

function validateScenarioSet(set: ScenarioSet, path: string): void {
  if (!set?.scenarios?.length) {
    throw new Error(`${path}: no scenarios found`);
  }
  const seen = new Set<string>();
  for (const s of set.scenarios) {
    if (seen.has(s.id)) throw new Error(`${path}: duplicate scenario id "${s.id}"`);
    seen.add(s.id);
    if (!s.checks?.length) throw new Error(`${path}: scenario "${s.id}" has no checks`);
    const checkIds = new Set<string>();
    for (const c of s.checks) {
      if (checkIds.has(c.id)) {
        throw new Error(`${path}: scenario "${s.id}" has duplicate check id "${c.id}"`);
      }
      checkIds.add(c.id);
      if (c.kind !== "require" && c.kind !== "forbid") {
        throw new Error(`${path}: check "${s.id}/${c.id}" has invalid kind "${c.kind}"`);
      }
      if (typeof c.weight !== "number" || c.weight <= 0) {
        throw new Error(`${path}: check "${s.id}/${c.id}" needs a positive weight`);
      }
      try {
        new RegExp(c.pattern, "im");
      } catch (err) {
        throw new Error(`${path}: check "${s.id}/${c.id}" has invalid regex: ${(err as Error).message}`);
      }
    }
  }
}

/**
 * Locate a transcript file for a given scenario + arm. Convention:
 *   eval/transcripts/<platform>/<scenario-id>.<arm>.md
 * The `.sample.` infix marks an illustrative transcript shipped with the repo
 * so the demo runs with no API key; a real run drops the infix.
 */
export function findTranscript(
  platform: string,
  scenarioId: string,
  arm: Arm,
): { path: string; text: string; isSample: boolean } | null {
  const dir = resolve(EVAL_ROOT, "transcripts", platform);
  let entries: string[];
  try {
    entries = readdirSync(dir);
  } catch {
    return null;
  }
  const real = `${scenarioId}.${arm}.md`;
  const sample = `${scenarioId}.${arm}.sample.md`;
  if (entries.includes(real)) {
    return { path: resolve(dir, real), text: readFileSync(resolve(dir, real), "utf8"), isSample: false };
  }
  if (entries.includes(sample)) {
    return { path: resolve(dir, sample), text: readFileSync(resolve(dir, sample), "utf8"), isSample: true };
  }
  return null;
}
