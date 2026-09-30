# Contributing to the Iterable SDK skills

This guide is for Iterable contributors working on the skills, their prompts, and the
onboarding program. The commands below are maintainer tools; they are not part of the
workflow installed users follow.

## Reviewing user-facing copy

From the repository root:

```bash
make screens
```

This renders every onboarding question as a developer sees it, using sample projects and
devices. Each screen is headed by its scenario name and the file and line where its words
live. It does not use Google or Iterable credentials, make network requests, or require a
connected device.

To review one screen:

```bash
make screens KIND=opening
make screens KIND=pick_device
make screens KIND="iterable_step 3"
```

Run `make screens` once to see every available scenario name.

### Editing a screen

1. Run `make screens KIND=<scenario>`.
2. Edit the source named above the rendered screen.
3. Render that scenario again.
4. Run `make test` before opening or updating the pull request.

Question copy currently lives with its behavior in `bin/questions.sh`. Labels and
descriptions may be reworded, but commands, option effects, consent boundaries, and state
transitions are behavior changes rather than copy changes. Pair with an engineer when an
edit needs to change those.

### Other text surfaces

`make screens` covers questions and their options. Other developer-facing text lives in:

| Text | Source |
|---|---|
| Gate names and verdicts | `bin/gates`, `bin/gates-device.sh`, `bin/gates-iterable.sh` |
| Banners, summaries, and ladder headings | `bin/config.sh` |
| Iterable dashboard instructions | `bin/iterable-keys` |
| Instructions read by the coding agent | each skill's `SKILL.md`, `PITFALLS.md`, and `reference/` files |

The shell program's deeper maintainer map is in
[`bin/README.md`](bin/README.md#where-the-words-are).

## Writing skill and prompt instructions

Follow Iterable's
[System Prompt Design Guide](https://github.com/Iterable/Iterable/blob/master/iterable-agents/src/mastra/prompts/PROMPT_GUIDE.md)
when changing model-facing instructions:

- Include Iterable-specific knowledge and behavior the model cannot infer.
- State the behavior to follow directly and positively.
- Keep each rule concise enough to retain attention.
- Put a rule in one authoritative place and link to it instead of duplicating it.
- Keep tool mechanics in scripts and descriptions; use skill instructions for routing,
  policy, and boundaries.
- Add or update a test when a rule addresses a concrete failure mode.

Copy for a person and instructions for a model are different surfaces. `make screens`
previews what the developer reads; it does not preview the full `SKILL.md` context supplied
to an agent.

## Validation

For a copy-only change:

```bash
make screens KIND=<scenario>
make test
```

Use `make test-all` only when the network-backed published-spec check is intentionally in
scope.

In the pull request, state:

- which developer-facing or model-facing surface changed;
- which scenario or failure mode motivated it;
- what command you used to preview it;
- which tests you ran.
