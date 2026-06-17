# Eval — does the skill actually help?

This harness answers the one question a checklist can't: **does a coding agent
armed with the `iterable-android` skill produce better integration code than the
same agent without it?** It runs each realistic integration ask twice — once
with no skill (*baseline*), once with the skill active (*skill*) — and scores
both replies deterministically against the documented foot-guns in
[`PITFALLS.md`](../iterable-android/PITFALLS.md).

**Scoring never calls a model.** Each scenario carries regex `require`/`forbid`
checks; the scorer just runs them over the transcript. Same transcript in → same
score out. That reproducibility is the point: the before/after gap has to
survive someone re-running it live in the room.

## What's here

```
eval/
├── scenarios/android.yml      # the 8 asks + their checks (committed)
├── transcripts/android/       # agent replies, one per scenario × arm
│   └── *.sample.md            # illustrative samples shipped so this runs today
├── prompts/                   # generated: prompt files to feed each arm (gitignored)
├── results/android.json       # generated: scored output (gitignored)
└── report/android.md          # generated: the before/after slide (gitignored)
```

## Run it (works today, no API key)

From `pipeline/`:

```bash
pnpm eval:run android      # score transcripts → eval/results/android.json
pnpm eval:report android   # render → eval/report/android.md  ← the slide
```

Out of the box this scores the shipped `*.sample.md` transcripts and prints a
headline gap. Those samples are **illustrative** — realistic but hand-authored,
clearly marked, and only there so the pipeline runs end-to-end before any real
runs exist. The runner labels every sample it uses; don't present sample numbers
as measured ones.

## Make the numbers load-bearing

Replace the samples with real agent runs:

```bash
pnpm eval:prompts android        # writes eval/prompts/android/<scenario>.<arm>.md
```

For each generated prompt:

1. **baseline arm** — paste it into a stock coding agent (Claude, Cursor, Copilot)
   with **no** Iterable skill, no Context7, no extra context.
2. **skill arm** — same agent, same prompt, with `iterable-android/` symlinked
   into the assistant's skills folder.
3. Save each full reply to
   `eval/transcripts/android/<scenario>.<arm>.md` — **drop the `.sample` infix.**
   A real transcript shadows the sample automatically.

Then re-run `pnpm eval:run android && pnpm eval:report android`. The report
header stamps `expectations_version`; bump it in `android.yml` whenever the
corpus or `PITFALLS.md` changes what "correct" means.

## Scoring model

- **require** check: pattern should appear → present = pass, earns `weight`.
- **forbid** check: pattern is a known foot-gun → absent = pass, earns `weight`.
- **ratio** = earned / possible across a scenario's checks.
- **critical** check: a failed one marks the scenario *silently broken* — the
  integration compiles but fails in production (no JWT handler, EU data dropped,
  push suppressed). Reported separately from the percentage, because "85% correct
  but ships with no auth handler" is still a failing integration.

A scenario **passes** only if it clears 80% weighted **and** no critical check
failed.

## Adding a scenario

Append to `scenarios/android.yml`: a unique `id`, the `prompt`, and `checks`.
Every check needs `id`, `kind`, `weight`, `pattern`, `rationale`; add `pitfall`
(an id from [`config/pitfalls/android.yml`](../pipeline/config/pitfalls/android.yml))
when it guards a documented trap, and `critical: true` when failing it means a
silently-broken integration. Keep patterns specific — prefer an API name
(`setAllowedProtocols`) over a vague word — so the skill earns credit for the
right reason. `pnpm eval:run` validates the file (unique ids, valid regex,
positive weights) before scoring.

## Limitations (v1, explicit)

- **Sample transcripts are illustrative, not measured.** They demonstrate the
  scoring and the expected gap; real runs replace them.
- **Regex is a proxy for correctness.** A check rewards the presence of the
  right API call, not that the surrounding code compiles. The advisory
  `kotlinc` gate in the main pipeline is the compile-level signal; this harness
  is about *integration correctness and trap-avoidance*, which is what actually
  breaks silently in production.
- **Generation is manual in v1**, mirroring how Layer B is run by hand today.
  Auto-filling `transcripts/` from a real client (Anthropic SDK or a Claude Code
  subagent loop) is a drop-in follow-up.
