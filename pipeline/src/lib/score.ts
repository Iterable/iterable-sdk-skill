/**
 * Deterministic scorer. Given a transcript and a scenario's checks, decides
 * which checks pass and rolls them into a scenario score. No model involved —
 * this is regex over text, so a given (transcript, scenario) always yields the
 * same numbers. That reproducibility is the whole point: the before/after
 * gap has to survive someone re-running it in the room.
 *
 * Scoring model:
 *   - require check: pattern present  → pass, earns `weight`.
 *   - forbid check:  pattern absent   → pass, earns `weight`.
 *   - ratio = earned / possible over all checks in the scenario.
 *   - a failed `critical` check sets brokenByCritical — the integration would
 *     silently break in production even if the weighted ratio looks healthy.
 *     The report surfaces that separately from the percentage, because "85%
 *     correct but ships with no JWT handler" is a failing integration.
 */

import type { Check, CheckResult, Scenario, ScenarioScore, Arm } from "./eval.ts";

const EVIDENCE_PAD = 48;

function evidenceFor(text: string, re: RegExp): string | undefined {
  const m = re.exec(text);
  if (!m || m.index === undefined) return undefined;
  const start = Math.max(0, m.index - EVIDENCE_PAD);
  const end = Math.min(text.length, m.index + m[0].length + EVIDENCE_PAD);
  const slice = text.slice(start, end).replace(/\s+/g, " ").trim();
  return `…${slice}…`;
}

export function scoreCheck(check: Check, transcript: string): CheckResult {
  const re = new RegExp(check.pattern, "im");
  const found = re.test(transcript);
  const passed = check.kind === "require" ? found : !found;
  // Evidence is the matched text: a require pass shows what satisfied it; a
  // forbid fail shows the offending foot-gun. The other two cases have nothing
  // useful to point at.
  const evidence =
    (check.kind === "require" && found) || (check.kind === "forbid" && found)
      ? evidenceFor(transcript, re)
      : undefined;
  return { ...check, passed, evidence };
}

export function scoreScenario(
  scenario: Scenario,
  transcript: string,
  arm: Arm,
): ScenarioScore {
  const checks = scenario.checks.map((c) => scoreCheck(c, transcript));
  const possible = checks.reduce((acc, c) => acc + c.weight, 0);
  const earned = checks.reduce((acc, c) => acc + (c.passed ? c.weight : 0), 0);
  const failedCritical = checks
    .filter((c) => c.critical && !c.passed)
    .map((c) => c.id);
  return {
    id: scenario.id,
    title: scenario.title,
    arm,
    checks,
    earned,
    possible,
    ratio: possible === 0 ? 0 : earned / possible,
    brokenByCritical: failedCritical.length > 0,
    failedCritical,
  };
}

export function pct(ratio: number): string {
  return `${Math.round(ratio * 100)}%`;
}
