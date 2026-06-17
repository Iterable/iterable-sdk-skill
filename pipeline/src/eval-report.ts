/**
 * Renders eval/results/<platform>.json into a markdown before/after report at
 * eval/report/<platform>.md — the artifact that becomes the presentation's
 * proof slide. Headline table first (the slide), then per-scenario detail
 * (the backup for "show me where the baseline broke").
 *
 *   pnpm eval:report [platform]
 */

import { readFileSync, mkdirSync, existsSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { EVAL_ROOT } from "./lib/eval.ts";
import type { EvalResults, ScenarioScore } from "./lib/eval.ts";

function pct(ratio: number): string {
  return `${Math.round(ratio * 100)}%`;
}

function delta(baseline: number, skill: number): string {
  const d = Math.round((skill - baseline) * 100);
  if (d > 0) return `**+${d} pts**`;
  if (d < 0) return `${d} pts`;
  return "—";
}

function statusCell(s: ScenarioScore): string {
  if (s.brokenByCritical) return `🔴 broken (${s.failedCritical.join(", ")})`;
  if (s.ratio >= 0.8) return `🟢 ${pct(s.ratio)}`;
  return `🟠 ${pct(s.ratio)}`;
}

function renderHeadline(r: EvalResults): string[] {
  const b = r.arms.baseline;
  const k = r.arms.skill;
  const byId = new Map(b.scenarios.map((s) => [s.id, s]));
  const lines: string[] = [];

  lines.push(`# Before / after — ${r.platform} SDK skill`);
  lines.push("");
  lines.push(
    `Same coding agent, same prompts. **Baseline** = no Iterable skill. ` +
      `**Skill** = \`${r.skill}\` active. Scoring is deterministic regex over ` +
      `each reply (see \`eval/scenarios/${r.platform}.yml\`); no model grades the output.`,
  );
  lines.push("");
  lines.push("## Headline");
  lines.push("");
  lines.push("| Metric | Baseline | With skill | Δ |");
  lines.push("|---|---|---|---|");
  lines.push(
    `| Weighted checks passed | ${pct(b.ratio)} | ${pct(k.ratio)} | ${delta(b.ratio, k.ratio)} |`,
  );
  lines.push(
    `| Scenarios passing (≥80%, no critical fail) | ${b.scenariosPassed}/${b.scenarios.length} | ${k.scenariosPassed}/${k.scenarios.length} | — |`,
  );
  lines.push(
    `| Scenarios that silently break in prod | ${b.scenariosBrokenByCritical} | ${k.scenariosBrokenByCritical} | — |`,
  );
  lines.push("");

  lines.push("## Per scenario");
  lines.push("");
  lines.push("| Scenario | Baseline | With skill |");
  lines.push("|---|---|---|");
  for (const ks of k.scenarios) {
    const bs = byId.get(ks.id);
    const baseCell = bs ? statusCell(bs) : "—";
    lines.push(`| ${ks.title} | ${baseCell} | ${statusCell(ks)} |`);
  }
  lines.push("");
  lines.push("🟢 ≥80% checks · 🟠 partial · 🔴 a critical check failed — the");
  lines.push("integration compiles but silently breaks (no JWT handler, EU data");
  lines.push("dropped, push suppressed, etc.).");
  lines.push("");
  return lines;
}

function renderDetail(r: EvalResults): string[] {
  const lines: string[] = [];
  lines.push("## Detail — what the skill caught that the baseline missed");
  lines.push("");
  const baseById = new Map(r.arms.baseline.scenarios.map((s) => [s.id, s]));

  for (const ks of r.arms.skill.scenarios) {
    const bs = baseById.get(ks.id);
    lines.push(`### ${ks.title}  \`${ks.id}\``);
    lines.push("");
    lines.push("| Check | Guards | Baseline | Skill |");
    lines.push("|---|---|---|---|");
    for (const kc of ks.checks) {
      const bc = bs?.checks.find((c) => c.id === kc.id);
      const guard = kc.pitfall ? `pitfall #${kc.pitfall}` : kc.kind;
      const mark = (passed: boolean | undefined) =>
        passed === undefined ? "—" : passed ? "✅" : "❌";
      const crit = kc.critical ? " ⚠️" : "";
      lines.push(`| ${kc.id}${crit} | ${guard} | ${mark(bc?.passed)} | ${mark(kc.passed)} |`);
    }
    lines.push("");
    // Surface the most damning thing: a critical check the baseline failed and
    // the skill passed. That's the literal sentence for the slide's caption.
    const wins = ks.checks.filter((kc) => {
      const bc = bs?.checks.find((c) => c.id === kc.id);
      return kc.passed && bc && !bc.passed && kc.critical;
    });
    for (const w of wins) {
      lines.push(`> ⚠️ **${w.id}** — ${w.rationale.trim()}`);
      lines.push("");
    }
  }
  return lines;
}

function main(): void {
  const platform = process.argv[2] || "android";
  const resultsPath = resolve(EVAL_ROOT, "results", `${platform}.json`);
  if (!existsSync(resultsPath)) {
    console.error(`No results at ${resultsPath}. Run: pnpm eval:run ${platform}`);
    process.exit(2);
  }
  const r = JSON.parse(readFileSync(resultsPath, "utf8")) as EvalResults;

  const out = [
    ...renderHeadline(r),
    `_Generated ${r.generated_at} · expectations ${r.expectations_version}_`,
    "",
    ...renderDetail(r),
  ].join("\n");

  const outDir = resolve(EVAL_ROOT, "report");
  if (!existsSync(outDir)) mkdirSync(outDir, { recursive: true });
  const outFile = resolve(outDir, `${platform}.md`);
  writeFileSync(outFile, out, "utf8");
  console.log(`Wrote eval/report/${platform}.md`);
}

main();
