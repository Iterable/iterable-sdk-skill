# iterable-sdk-skill

> **Beta.** Iterable's mobile SDK skills are currently in private beta. By signing
> up to use them during this period, you agree to our
> [Beta Terms](https://iterable.com/legal/beta-terms/).
>
> This document describes how to use the beta version of the plugin. Iterable
> reserves the right to change, update, and add or remove content. This
> documentation may contain errors and/or inaccuracies and is provided "as is,"
> without warranties of any kind.
>
> This documentation is confidential and may not be shared outside of your
> organization.
>
> Current functionality is subject to change.

Point your AI coding assistant at your Android or React Native app and this
plugin takes it from nothing to **a push notification proven to have arrived on a
real device** — creating the Firebase prerequisites, writing the integration
against version-pinned docs, and then reading the device's own notification
service to confirm delivery.

The plugin ships **skills, agents, and shell scripts only**. Everything runs on
your machine, under your assistant, with your approval. No source code, no
credential, and no key ever leaves your machine.

---

## What's in the box: four skills

The skills form a funnel — each stage hands off to the next — and any one can be
used on its own.

| # | Skill | What it does |
|---|-------|--------------|
| 1 | **iterable-provision** | Produces the prerequisites nobody can invent: a Firebase Android app and its real `google-services.json`, a service account scoped to sending push plus its JSON key, and the Iterable dashboard steps (two API keys, the mobile app, the Firebase push integration, the test identity). Then it **proves each one worked**. |
| 2 | **iterable-android** / **iterable-react-native** | Writes and debugs the integration itself, against Iterable's documentation bundled inside the skill. React Native covers both bare workflow and Expo (`@iterable/expo-plugin`). |
| 3 | **iterable-verify** | Sends a real push and reads the device's notification service to confirm it arrived. Read-only: it never provisions, never edits your app, and never re-sends to manufacture a pass. |

**The path:** `iterable-provision → iterable-android` (or `iterable-react-native`)
`→ iterable-verify`. The integration skills used to stop when Preflight reached an
input nobody had — a `google-services.json`, a mobile API key, a configured push
integration. Now they route to `iterable-provision` instead of stopping, and hand
to `iterable-verify` once the code is written.

> Skills are **model-invoked**. You don't type a command — describe what you want
> ("set up Iterable push in this app", "why isn't my push arriving?", "prove this
> works") and your assistant picks the right skill.

---

## Prerequisites

### Accounts

- An **Iterable project**, and an [API key](https://support.iterable.com/hc/en-us/articles/360043464871)
  — or let `iterable-provision` walk you through creating the keys.
- A **Google account** that can create or access a Firebase project.

You sign in to both yourself. The plugin never asks for, receives, or handles
your passwords — see [Security](#security).

### Command-line tools

`iterable-provision` and `iterable-verify` drive real tools on your machine. Check
what you have:

```bash
node --version && gcloud --version && adb --version && java -version
```

| Tool | Needed for | Install |
|------|-----------|---------|
| **`gcloud`** | the entire Google half — project, Firebase, service account, IAM, key | [Google Cloud CLI](https://cloud.google.com/sdk/docs/install), or `brew install --cask gcloud-cli` |
| **`adb`** | the device half — reading the installed app, its FCM token, and the arriving push | Android Studio's SDK Manager (platform-tools), or `brew install --cask android-platform-tools` |
| **`node`** | parsing API responses | [nodejs.org](https://nodejs.org), or `brew install node` |
| **`java`** | building your app | bundled with Android Studio, or `brew install --cask temurin` |

**If one is missing, nothing is guessed.** Gate `G0 Tooling present` goes red, every
gate below it reports `waiting on Tooling present` rather than failing, and the run
stops with exit `10` — *blocked on you*, not *broken*. You are told exactly which
binaries are absent and what each one unlocks. The plugin will not install them for
you: changing your toolchain is your decision, not your assistant's.

### A device

`iterable-verify` needs a real Android device or a running emulator **with Google
Play services** — FCM cannot deliver to an emulator image without them. A push
proven on one is the only evidence this plugin accepts that the integration works.

---

## Supported agents

Cursor, Claude Code, and Codex. Each has an install path below.

## Install

### Claude Code

```
/plugin marketplace add Iterable/iterable-sdk-skill
/plugin install iterable-sdk@iterable
```

This installs all four skills in one step. Start a new Claude Code session —
skills load at session start.

Then turn on auto-update, so corpus refreshes reach you without you asking:
`/plugin` → **Marketplaces** → **iterable** → **Enable auto-update**. Claude
Code disables auto-update by default for third-party marketplaces, so without
this you stay on the version you first installed until you update by hand. See
[Staying current](#staying-current).

### Cursor

Requires [Cursor 3.9+](https://cursor.com). Clone this repo, then symlink the
skill directories into `~/.cursor/skills/` (not `~/.cursor/plugins/local/` —
that path alone does not load the skill):

```bash
git clone --depth 1 https://github.com/Iterable/iterable-sdk-skill.git ~/iterable-skills
mkdir -p ~/.cursor/skills
for s in iterable-provision iterable-android iterable-react-native iterable-verify; do
  ln -sfn ~/iterable-skills/$s ~/.cursor/skills/$s
done
```

Reload Cursor (`Cmd+Shift+P` → **Developer: Reload Window**), then start a
**new Agent chat**. Skills load at session start — an existing chat won't pick
this up.

### Codex

```bash
codex plugin marketplace add Iterable/iterable-sdk-skill
codex plugin add iterable-sdk@iterable
```

Then start a new Codex session. To verify: `codex plugin list`.

For local development on this repo, add the checkout as the marketplace source
instead of GitHub:

```bash
codex plugin marketplace add .
codex plugin add iterable-sdk@iterable
```

If you only need the raw skill folders and do not want the plugin marketplace
flow, symlink them directly:

```bash
mkdir -p ~/.codex/skills
for s in iterable-provision iterable-android iterable-react-native iterable-verify; do
  ln -sfn ~/iterable-skills/$s ~/.codex/skills/$s
done
```

Start a new Codex session after the symlink; skills are loaded at session start.

---

## How it works

### The reference half

`iterable-android` and `iterable-react-native` each carry a copy of Iterable's
documentation inside them (`iterable-android/reference/`,
`iterable-react-native/reference/`), so your assistant has the docs on hand even
offline. That bundled copy is the authoritative source — there is nothing to fetch
at runtime. The skill routes each task to the right doc slug, pitfalls file, and
integration checklist in
[`iterable-android/SKILL.md`](iterable-android/SKILL.md) or
[`iterable-react-native/SKILL.md`](iterable-react-native/SKILL.md).

When Iterable's source documentation changes, an automated workflow refreshes the
corpus — see [Staying current](#staying-current).

### The provisioning and proof half

`iterable-provision` and `iterable-verify` drive a program in [`bin/`](bin/README.md)
built on one rule:

> **The actor never grades its own work.**

`bin/provision` and `bin/proof-push` *do* things. `bin/gates` *judges* them and can
do nothing at all — it is a read-only verifier over eighteen gates, `G0`–`G17`,
covering tooling, Google auth, the Firebase project and app, `google-services.json`,
the service account and its key, the Iterable keys and dashboard steps, the installed
APK, the FCM token, and the push itself.

Two of those gates cannot be faked:

- **`G9 Key actually works`** mints a real OAuth token from the service-account key
  and makes FCM accept it. A key file that merely parses does not pass.
- **`G16 Push arrives on device`** finds the push in the device's own
  `dumpsys notification` output, matched by the marker the send wrote. Not a log
  line claiming success — the notification itself.

**It says "unproven" rather than guessing.** Three Iterable dashboard steps have no
public API to read back — checked path by path against the published spec, not
assumed. Those gates print `~ unverifiable` instead of a tick, and exit code `40`
exists so that *"nothing is broken and nothing is proven"* is a thing the tool can
actually say. A gate that reads a local file to decide a remote step happened is
precisely the false pass this design exists to prevent.

Exit codes: `0` all green · `10` blocked on you · `20` a gate failed · `30` tool
error · `40` nothing broken, nothing proven yet.

[`INTENDED-FLOW.md`](INTENDED-FLOW.md) is the contract for the path a run takes, and
it changes before the code does.

### The agents

Four subagents carry the parts of the work that need their own narrow permissions:

| Agent | Role |
|-------|------|
| `gcp-provisioner` | the Google side — Firebase, service accounts, IAM, keys (`G1`–`G9`) |
| `iterable-api-client` | Iterable's REST API and the verification loop (`G10`, `G14`–`G17`) |
| `web-operator` | the **only** agent with browser access, origin-confined to the Firebase, Google Cloud, and Iterable consoles |
| `gate-auditor` | adversarial re-derivation of whether a gate is truly green — read-only, and never audits its own gate |

---

## What it covers

Push notifications, in-app messages, mobile inbox, embedded messaging, deep
linking, JWT authentication, event tracking, and user profiles (plus unknown-user
activation on Android). Snippets are version-pinned to the SDK release each was
validated against. Android and React Native today; iOS and Web are coming.

Provisioning and device-side proof are **Android-first**. React Native apps get the
same provisioning and, for their Android target, the same proof; iOS/APNs is not
covered yet.

---

## Security

- **The plugin never handles your passwords.** You authenticate in your own browser
  and your own `gcloud`; the assistant attaches to the session you already have. It
  will never defeat a CAPTCHA, a bot check, or a terms-of-service acceptance on your
  behalf.
- **Secrets are never pasted into chat.** Keys are referenced by file path and
  environment variable. The service-account key and API keys are written mode `0600`
  into a workspace that gitignores itself, never echoed to a log, a report, or a
  trace, and never passed as a command-line argument — argv is readable by any other
  process. Deletion of the key is offered once it has been uploaded.
- **Nothing about your app is invented.** No placeholder `google-services.json`, no
  fabricated API key, no commenting out a plugin to make a build pass. A missing
  prerequisite is reported as missing.
- **The verifier can only read.** `bin/gates` performs no provisioning, and
  `iterable-verify` never edits your app and never re-sends to turn a red gate green.
- **Least privilege.** The service account it creates is scoped to sending push.
  `roles/firebase.admin` is never used.
- **Browser access is confined.** `web-operator` is the only agent that can drive a
  browser, and only against `console.firebase.google.com`,
  `console.cloud.google.com`, and `app.iterable.com`.
- **No telemetry.** Nothing is reported anywhere. The workspace stays in your project
  and is gitignored, because it holds live session cookies and a downloaded key.

Note that plugins and marketplaces run with your privileges — install only from
sources you trust. This is a general caution, not specific to Iterable.

---

## Known limitations

- **Mobile SDK integration only.** To query campaigns or user data in your
  Iterable project, use the Nova Agent in the Iterable app.
- **Separate from [Iterable's MCP Server](https://support.iterable.com/hc/articles/42936800222612).**
  The MCP Server connects your assistant to Iterable's APIs for campaign and
  user data tasks. Use these skills when you're writing, provisioning, or
  debugging mobile app code; use the MCP Server when you need to query or act on
  data in your Iterable project.
- **Three Iterable dashboard steps are yours to click.** They have no public API.
  The plugin tells you exactly what to click and then proves the result.
- **JWT-enabled mobile keys are recognised, not supported.** The tool names the
  failure rather than guessing. Use a non-JWT key to get push working, then switch.
- **Some docs carry foreign snippets.** A few articles come from shared
  "Mobile SDKs" pages and still contain iOS/JS code an Android agent must ignore.

---

## Staying current

When Iterable's docs change, a workflow rebuilds **every** configured platform's
corpus in one pass (`pnpm refresh:docs`), validates it, and commits to `main`
naming the platforms that actually changed — so the corpus tracks the docs without
waiting on a review. A maintainer audits refreshes after the fact; see
[`REVIEW.md`](REVIEW.md).

### How a refresh reaches you

Claude Code and Codex decide whether to update by comparing the version in
`.claude-plugin/plugin.json` against the version you have installed, and skip
the plugin when they match. So every refresh that changes the corpus also bumps
that version — otherwise new docs would sit on `main` and never reach a single
installed plugin.

Versions are calendar-based, `YY.M.PATCH`: `26.9.0-beta` is the first release of
September 2026, `26.9.1-beta` the next, and the patch resets when the month rolls
over. The `-beta` suffix stays on every release while the plugin is in private
beta. The number says *when*, not how much changed — for that, read the commit
the version came from:

```bash
git log --oneline main --grep '^docs refresh:'
```

With auto-update enabled, Claude Code refreshes shortly after a session starts
(after a random delay of up to ten minutes) and prompts you to run
`/reload-plugins`; the session you are in keeps what it loaded at launch.

To update by hand, refresh the marketplace first, then the plugin:

```
/plugin marketplace update iterable
/plugin update iterable-sdk@iterable
```

`/plugin update` reads your local copy of the marketplace catalogue and does not
refresh it, so on its own it reports `already at the latest version` however far
behind you are.

Cursor's install above is a clone and symlink rather than a plugin, so there it
is `git pull` in your clone and a **Developer: Reload Window**.

Maintainers: `cd pipeline && pnpm refresh:docs` refreshes Android and React
Native together. Pass a platform name (`pnpm refresh:docs -- android`) to
limit the run. Refresh needs `gh` authenticated against private
`Iterable/iterable-docs` (`DOCS_READ_TOKEN` / `GH_TOKEN`).

---

## Repo layout

```
iterable-provision/      Provisioning skill — SKILL.md
iterable-android/        Android skill — SKILL.md + PITFALLS.md + reference/
iterable-react-native/   React Native skill — same shape
iterable-verify/         Proof skill — SKILL.md
bin/                     the program the two new skills drive — see bin/README.md
agents/                  the four subagents the skills delegate to
INTENDED-FLOW.md         the contract for the path a run takes
tests/                   offline suites over bin/ — `make test`
pipeline/                refresh tooling + validation gates, CI-run
eval/                    scenario definitions for scoring skill vs. no-skill answers
docs/onboard/            templates: inputs.yml, env.example
.claude-plugin/          Claude Code + Codex plugin + marketplace manifests
.cursor-plugin/          Cursor plugin + marketplace manifests
context7.json            Context7 indexing manifest
mcp.json / .mcp.json     Context7 MCP server config (Cursor / Claude Code discovery)
```
