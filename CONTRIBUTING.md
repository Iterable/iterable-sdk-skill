# Contributing to the Iterable SDK skills

This guide is for Iterable engineers and Docs team members reviewing the
plugin's developer-facing and model-facing content.

The commands in this file are repository-maintenance tools. Developers who
install the plugin do not run them.

## Copy-review quick start

From the repository root:

```bash
make screens-help
make screens
```

`make screens-help` lists the available scenarios and their source files.
`make screens` renders every shared onboarding question with sample Firebase
projects and Android devices.

The preview requires Node.js. It does not require credentials, network access,
an Iterable or Firebase project, or a connected device.

For a more comfortable full review:

```bash
make screens | less -R
```

To review one scenario:

```bash
make screens KIND=opening
make screens KIND=pick_device
make screens KIND="iterable_step 3"
```

The heading above each rendered question identifies the source responsible for
its words and the shell function responsible for its behavior.

## Where screen copy lives

Screen copy is being moved from shell into writer-facing Markdown one screen at
a time:

- `copy/screens/*.md` contains the words for migrated screens.
- `bin/questions.sh` contains behavior for every screen and the words for
  screens that have not yet moved.
- Stable option IDs connect a Markdown label and description to the relevant
  shell behavior.

Only `copy/screens/opening.md` has moved so far. See
[`copy/screens/README.md`](copy/screens/README.md) for its format, supported
sections, and placeholders.

### Editing a migrated screen

1. Run `make screens KIND=<scenario>`.
2. Edit the `copy/screens/*.md` file listed above the preview.
3. Do not rename or remove an `Option:` ID.
4. Render the scenario again.
5. Run `make test`.

Labels, descriptions, paragraph structure, and option order are copy. Option
IDs, commands, consent records, state changes, and the effect of selecting an
option are behavior.

### Editing an unmigrated screen

Unmigrated copy still lives inside `bin/questions.sh`. Docs reviewers can
propose wording there, but should pair with an engineer before changing the
shell source. The engineer should confirm that the edit does not change option
effects, commands, consent boundaries, or state transitions.

When practical, move the screen into `copy/screens/` as a separate engineering
change instead of expanding the mixture of prose and behavior in shell.

## Other developer-facing text

`make screens` covers the shared questions and options supplied to the terminal
wizard and coding-agent conversation. It does not render every user-facing
string in the onboarding program.

| Surface | Source |
|---|---|
| Shared onboarding questions | `copy/screens/*.md` and `bin/questions.sh` |
| Gate names and verdicts | `bin/gates`, `bin/gates-device.sh`, `bin/gates-iterable.sh` |
| Banners, summaries, endings, and ladder headings | `bin/config.sh` |
| Iterable dashboard instructions | `bin/iterable-keys` |
| Terminal-only interaction text | `bin/wizard` |
| Coding-agent protocol and refusals | `bin/agent` |
| Installed-user documentation | `README.md` |
| Model-facing skill instructions | each skill's `SKILL.md`, `PITFALLS.md`, and `reference/` files |

The engineering map for these surfaces is in
[`bin/README.md`](bin/README.md).

## Model-facing instructions

Human-facing copy and model-facing instructions are separate review surfaces.
`make screens` previews what a developer reads; it does not preview the complete
context supplied to a coding agent.

When changing a `SKILL.md`, agent definition, or other model-facing instruction,
follow Iterable's
[System Prompt Design Guide](https://github.com/Iterable/Iterable/blob/master/iterable-agents/src/mastra/prompts/PROMPT_GUIDE.md).
Keep the guide authoritative instead of reproducing its rules here.

Local instructions should explain Iterable-specific routing, policy, and
boundaries. Executable mechanics belong in scripts and tool descriptions.
Update or add a test when an instruction addresses a concrete failure mode.

## Validation

For a copy-only screen change:

```bash
make screens KIND=<scenario>
make test
```

For onboarding behavior or shell changes:

```bash
make test
```

Use `make test-all` only when the network-backed published-spec check is
intentionally in scope.

For generated SDK reference or pipeline changes, follow [`REVIEW.md`](REVIEW.md)
and run:

```bash
cd pipeline
pnpm check:all
```

## Pull-request handoff

In the pull request, state:

- which developer-facing or model-facing surface changed;
- which scenario, reader problem, or failure mode motivated the change;
- whether the change affects words, behavior, or both;
- which command you used to preview it;
- which tests you ran.

For a Docs review, include the relevant `make screens KIND=...` commands so the
reviewer can reproduce the rendered questions without setting up Firebase,
Iterable, or an Android device.
