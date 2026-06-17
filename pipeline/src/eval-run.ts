/**
 * Eval runner. Two subcommands:
 *
 *   pnpm eval:prompts [platform]
 *     Writes one prompt file per scenario to eval/prompts/<platform>/.
 *     A human (or an agent harness) feeds each prompt to both arms:
 *       - baseline: a stock coding agent, NO Iterable skill loaded
 *       - skill:    the same agent with iterable-android/ active
 *     and saves each reply to
 *       eval/transcripts/<platform>/<scenario-id>.<arm>.md
 *
 *   pnpm eval:run [platform]
 *     Scores every scenario × arm against its transcript and writes
 *     eval/results/<platform>.json. Missing transcripts are reported, not
 *     fatal — a partial run still scores what's present (sample transcripts
 *     ship with the repo so this works with no API key out of the box).
 *
 * Generation is deliberately manual, mirroring how Layer B is run by hand
 * today: the harness stays model-agnostic and needs no API key checked in.
 * Wiring a real client (Anthropic SDK / a Claude Code subagent loop) is a
 * drop-in follow-up — it would just fill the transcripts/ dir automatically.
 */

import { existsSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { EVAL_ROOT, findTranscript, loadScenarioSet } from "./lib/eval.ts";
import type { Arm, ArmSummary, EvalResults, ScenarioScore } from "./lib/eval.ts";
import { scoreScenario } from "./lib/score.ts";

const ARMS: Arm[] = ["baseline", "skill"];

const SKILL_PREAMBLE = `> Run this prompt with the **iterable-android** skill active
> (symlinked into your assistant's skills folder). Save the full reply to
> \`eval/transcripts/<platform>/<scenario>.skill.md\`.`;

const BASELINE_PREAMBLE = `> Run this prompt with a **stock** coding agent — NO Iterable skill,
> no Context7, no extra context. Save the full reply to
> \`eval/transcripts/<platform>/<scenario>.baseline.md\`.`;

function ensureDir(path: string): void {
  if (!existsSync(path)) mkdirSync(path, { recursive: true });
}

function cmdPrompts(platform: string): void {
  const set = loadScenarioSet(platform);
  const outDir = resolve(EVAL_ROOT, "prompts", platform);
  ensureDir(outDir);
  for (const s of set.scenarios) {
    for (const arm of ARMS) {
      const preamble = arm === "skill" ? SKILL_PREAMBLE : BASELINE_PREAMBLE;
      const body = [
        `# Eval prompt — ${s.id} (${arm} arm)`,
        "",
        `**Scenario:** ${s.title}`,
        "",
        preamble,
        "",
        "---",
        "",
        s.prompt.trim(),
        "",
      ].join("\n");
      const file = resolve(outDir, `${s.id}.${arm}.md`);
      writeFileSync(file, body, "utf8");
    }
  }
  console.log(
    `Wrote ${set.scenarios.length * ARMS.length} prompt files to eval/prompts/${platform}/`,
  );
  console.log(`Feed each to its arm, save replies to eval/transcripts/${platform}/,`);
  console.log(`then run: pnpm eval:run ${platform}`);
}

function summarize(arm: Arm, scenarios: ScenarioScore[]): ArmSummary {
  const earned = scenarios.reduce((a, s) => a + s.earned, 0);
  const possible = scenarios.reduce((a, s) => a + s.possible, 0);
  return {
    arm,
    scenarios,
    earned,
    possible,
    ratio: possible === 0 ? 0 : earned / possible,
    // A scenario "passes" only if it is not broken by a critical failure AND
    // clears 80% of weighted checks. Both conditions matter: critical guards
    // catch silent breakage, the threshold catches death-by-a-thousand-misses.
    scenariosPassed: scenarios.filter((s) => !s.brokenByCritical && s.ratio >= 0.8).length,
    scenariosBrokenByCritical: scenarios.filter((s) => s.brokenByCritical).length,
  };
}

function cmdRun(platform: string): void {
  const set = loadScenarioSet(platform);
  const arms = {} as Record<Arm, ArmSummary>;
  let missing = 0;
  let sampled = 0;

  for (const arm of ARMS) {
    const scores: ScenarioScore[] = [];
    for (const s of set.scenarios) {
      const t = findTranscript(platform, s.id, arm);
      if (!t) {
        missing++;
        console.warn(`WARN  no transcript for ${s.id}.${arm} — scenario skipped for this arm`);
        continue;
      }
      if (t.isSample) sampled++;
      scores.push(scoreScenario(s, t.text, arm));
    }
    arms[arm] = summarize(arm, scores);
  }

  const results: EvalResults = {
    platform,
    skill: set.skill,
    expectations_version: set.expectations_version,
    generated_at: new Date().toISOString(),
    arms,
  };

  const outDir = resolve(EVAL_ROOT, "results");
  ensureDir(outDir);
  const outFile = resolve(outDir, `${platform}.json`);
  writeFileSync(outFile, JSON.stringify(results, null, 2) + "\n", "utf8");

  const b = arms.baseline;
  const k = arms.skill;
  console.log("");
  console.log(`Eval results — ${platform} (skill: ${set.skill})`);
  console.log(`  baseline : ${pctStr(b.ratio)} weighted · ${b.scenariosPassed}/${b.scenarios.length} scenarios pass · ${b.scenariosBrokenByCritical} silently broken`);
  console.log(`  skill    : ${pctStr(k.ratio)} weighted · ${k.scenariosPassed}/${k.scenarios.length} scenarios pass · ${k.scenariosBrokenByCritical} silently broken`);
  console.log("");
  if (sampled > 0) {
    console.log(`NOTE  ${sampled} sample transcript(s) used (illustrative, shipped with the repo).`);
    console.log(`      Replace with real runs to make these numbers load-bearing.`);
  }
  if (missing > 0) {
    console.log(`NOTE  ${missing} transcript(s) missing; those scenarios were skipped.`);
  }
  console.log(`Wrote eval/results/${platform}.json — render it with: pnpm eval:report ${platform}`);
}

function pctStr(ratio: number): string {
  return `${Math.round(ratio * 100)}%`;
}

function main(): void {
  const [cmd, platformArg] = process.argv.slice(2);
  const platform = platformArg || "android";
  if (cmd === "prompts") return cmdPrompts(platform);
  if (cmd === "run") return cmdRun(platform);
  console.error("usage: tsx src/eval-run.ts <prompts|run> [platform]");
  process.exit(2);
}

main();
