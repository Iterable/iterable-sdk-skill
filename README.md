# iterable-sdk-skill

> **Beta.** Iterable's Android SDK skill is currently in private beta. By signing
> up to use it during this period, you agree to our
> [Beta Terms](https://iterable.com/legal/beta-terms/).
>
> This document describes how to use the beta version of the skill. Iterable
> reserves the right to change, update, and add or remove content. This
> documentation may contain errors and/or inaccuracies and is provided "as is,"
> without warranties of any kind.
>
> This documentation is confidential and may not be shared outside of your
> organization.
>
> Current functionality is subject to change.

The Iterable mobile SDK skills give your AI coding assistant reliable guidance
when integrating Iterable's SDK into an Android or React Native app — push,
in-app messages, user identity, and more. Because each skill is built for one
SDK, you get:

- **Official docs, always available.** Each skill ships Iterable's documentation
  inside it (`iterable-android/reference/`, `iterable-react-native/reference/`),
  so your assistant can reference Iterable's content even when you're offline.
- **Version-pinned examples.** Snippets target the SDK releases they were
  validated against — Kotlin-first on Android, JavaScript on React Native —
  not generic pseudocode.
- **Pitfall-aware answers.** Each skill includes Iterable-supplied guidance for
  common silent failures, so your assistant is less likely to suggest code that
  compiles but doesn't work.

The skills cover push notifications, in-app messages, mobile inbox, embedded
messaging, deep linking, JWT authentication, event tracking, and user profiles
(plus unknown-user activation on Android). Android and React Native are
available today — iOS and Web are coming soon.

## Known limitations

- **Mobile SDK integration only.** To query campaigns or user data in your
  Iterable project, use the Nova Agent in the Iterable app.
- **Separate from [Iterable's MCP Server](https://support.iterable.com/hc/articles/42936800222612).**
  The MCP Server connects your assistant to Iterable's APIs for campaign and
  user data tasks. Use this skill when you're writing or debugging mobile app
  code; use Iterable's MCP Server when you need to query or act on data in
  your Iterable project.
- **Some docs carry foreign snippets.** A few articles come from shared
  "Mobile SDKs" pages and still contain iOS/JS code an Android agent must
  ignore.

## Supported agents

Cursor, Claude Code, and Codex are supported. Each has an install path below.

## Before you begin

Set up an Iterable project with the necessary
[API key](https://support.iterable.com/hc/en-us/articles/360043464871).

## Install

### Claude Code

Install the plugin from this repo's marketplace:

```
/plugin marketplace add Iterable/iterable-sdk-skill
/plugin install iterable-sdk@iterable
```

This installs the `iterable-android` and `iterable-react-native` skills in one
step. Start a new Claude Code session — skills load at session start.

### Cursor

Requires [Cursor 3.9+](https://cursor.com). Clone this repo, then symlink the
skill directory into `~/.cursor/skills/` (not `~/.cursor/plugins/local/` —
that path alone does not load the skill):

```bash
git clone --depth 1 https://github.com/Iterable/iterable-sdk-skill.git ~/iterable-skills
mkdir -p ~/.cursor/skills
ln -sf ~/iterable-skills/iterable-android ~/.cursor/skills/iterable-android
ln -sf ~/iterable-skills/iterable-react-native ~/.cursor/skills/iterable-react-native
```

Reload Cursor (`Cmd+Shift+P` → **Developer: Reload Window**), then start a
**new Agent chat**. Skills load at session start — an existing chat won't pick
this up.

Once loaded, the matching skill activates when you work on Iterable Android or
React Native SDK tasks (see [How it works](#how-it-works)).

### Codex

Install the plugin from this repo's marketplace:

```bash
codex plugin marketplace add Iterable/iterable-sdk-skill
codex plugin add iterable-sdk@iterable
```

Then start a new Codex session. The plugin installs the `iterable-android` and
`iterable-react-native` skills. To verify:

```bash
codex plugin list
```

For local development on this repo, add the checkout as the marketplace source
instead of GitHub:

```bash
codex plugin marketplace add .
codex plugin add iterable-sdk@iterable
```

If you only need the raw skill folder and do not want the plugin marketplace
flow, symlink it directly into Codex's skills directory:

```bash
mkdir -p ~/.codex/skills
ln -sfn ~/iterable-skills/iterable-android ~/.codex/skills/iterable-android
ln -sfn ~/iterable-skills/iterable-react-native ~/.codex/skills/iterable-react-native
```

Start a new Codex session after the symlink; skills are loaded at session
start.

## How it works

Each skill carries a copy of the Iterable documentation inside it
(`iterable-android/reference/` or `iterable-react-native/reference/`), so it
always has the docs on hand — even offline. When your assistant works on an
Iterable Android or React Native SDK task, the matching skill activates and
routes it to the right doc slug, pitfalls, and integration checklist in
[`iterable-android/SKILL.md`](iterable-android/SKILL.md) or
[`iterable-react-native/SKILL.md`](iterable-react-native/SKILL.md).

That bundled copy is the authoritative doc source — there is nothing to fetch at
runtime. When Iterable's source documentation changes, an automated workflow
refreshes it (see [Staying current](#staying-current)); pick up updates by
updating your plugin or re-pulling the repo.

## What it covers

Push notifications, in-app messages, mobile inbox, embedded messaging, deep
linking, JWT authentication, event tracking, and user profiles (plus
unknown-user activation on Android). Snippets are version-pinned to the SDK
release each was validated against.

See [`iterable-android/SKILL.md`](iterable-android/SKILL.md) or
[`iterable-react-native/SKILL.md`](iterable-react-native/SKILL.md) for the
routing table.

## Staying current

When Iterable's docs change, a workflow rebuilds **every** configured
platform's corpus in one pass (`pnpm refresh:docs`) and opens a single PR
naming the platforms that actually changed. Updates are never applied
automatically. After a release lands, update your plugin install (or re-pull
if you cloned) to pick up the latest docs. See [`REVIEW.md`](REVIEW.md) for
the reviewer playbook.

Maintainers: `cd pipeline && pnpm refresh:docs` refreshes Android and React
Native together. Pass a platform name (`pnpm refresh:docs -- android`) to
limit the run. Refresh needs `gh` authenticated against private
`Iterable/iterable-docs` (`DOCS_READ_TOKEN` / `GH_TOKEN`).

## Repo layout

```
iterable-android/        Android skill — SKILL.md + PITFALLS.md + reference/
iterable-react-native/   React Native skill — same shape
pipeline/                refresh tooling + validation gates, CI-run
eval/                    scenario definitions for scoring skill vs. no-skill answers
.claude-plugin/          Claude Code + Codex plugin + marketplace manifests
.cursor-plugin/          Cursor plugin + marketplace manifests
context7.json            Context7 indexing manifest
mcp.json                 Context7 MCP server config (Cursor plugin auto-discovery)
.mcp.json                same config (Claude Code auto-discovery)
```
