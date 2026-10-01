# Onboarding program architecture

This document is for engineers maintaining the onboarding program under
`bin/`. For installation and product usage, see the
[repository README](../README.md). For copy review, see
[`CONTRIBUTING.md`](../CONTRIBUTING.md).

[`INTENDED-FLOW.md`](../INTENDED-FLOW.md) is the authoritative description of
the expected onboarding sequence. Change that contract and its tests before
changing the sequence implemented here.

Paths and commands in this document are relative to the repo root.
Installed users normally interact with generated `.iterable/` entry points
rather than these `bin/` paths.

## Core invariants

The central verification rule is:

> The component that performs an action does not verify its own result.

`bin/provision`, `bin/proof-push`, and `bin/launch-app` perform actions.
`bin/gates` independently reads the resulting state and does not provision
resources, edit the application, launch it, or send a notification.

Other invariants:

- Missing prerequisites are reported rather than fabricated.
- A developer's answer is required before reading or changing scoped cloud
  resources.
- Secrets are passed by protected file, environment variable, or the local
  clipboard workflow, not printed into chat or command arguments.
- Non-interactive entry points never wait on a prompt.
- The terminal wizard and coding-agent path use the same question objects and
  option behavior.
- Device verification gates only read the selected Android device.
- The launch actor can start the selected package's launcher activity, but
  cannot tap, type, sign in, or grant permissions.

## Automation tiers

The program prefers the most deterministic available interface:

1. **Command or API:** `gcloud`, REST APIs, and Iterable's public API.
2. **Developer dashboard action:** used when Iterable has no public API for the
   operation.
3. **Developer authentication or policy action:** Google and Iterable sign-in,
   terms acceptance, CAPTCHA, or organization-policy resolution.

The shell program does not drive a browser. Agent-level browser access, where
available, is separately restricted by the `web-operator` definition.

## Entry points

`bin/onboard` selects the terminal or non-interactive path based on whether
stdin is a TTY. `bin/agent` is invoked explicitly by a coding agent.

| Caller | Entry point | Behavior |
|---|---|---|
| Developer in a terminal | `bin/wizard` | Interactive menus, in-session authentication, and confirmation before changes |
| Script or CI | `bin/onboard` | Prints the ladder and next action, then exits without prompting |
| Coding agent | `bin/agent` | Emits one JSON object on stdout and the human-readable ladder on stderr |

All three paths use the same state, actions, and gate results. Conversation
presentation differs, but selecting an option must have the same effect in each
front end.

## Component map

| Command | Responsibility |
|---|---|
| `bin/onboard` | Selects an interactive or report-and-exit front end |
| `bin/wizard` | Renders shared questions as terminal menus |
| `bin/agent` | Reports state and serializes the next action for a coding agent |
| `bin/gates` | Runs the read-only verifier and writes gate state |
| `bin/provision` | Creates or updates the approved Google and Firebase resources |
| `bin/proof-push` | Sends one marked proof notification |
| `bin/launch-app` | Opens the selected package's launcher activity on the selected device |
| `bin/discover` | Lists visible Firebase projects and their Android apps after approval |
| `bin/iterable-keys` | Guides the four-step Iterable dashboard workflow and captures API keys |
| `bin/handoff` | Prints the terminal handoff when the developer chooses that path |
| `bin/teardown` | Removes resources created by the onboarding program |

Shared helpers and presentation logic live in `bin/config.sh`. Device-specific
checks live in `bin/gates-device.sh`; Iterable checks live in
`bin/gates-iterable.sh`.

## State and the `next` protocol

`state.tsv` is the source for the current ladder state. Exit codes describe the
overall result, but do not identify the next action.

`bin/agent` derives a `next` object with these primary fields:

```text
owner, kind, gate, step, command, summary
```

- `owner` identifies who acts next: `human`, `tool`, `agent`, or `none`.
- `kind` identifies the branch, such as `authenticate`, `choose_target`,
  `approve_firebase`, `provision`, `iterable_keys`, `install_app`, `run_app`,
  `send_proof`, or `done`.
- `gate` identifies the blocking or pending verification gate.
- `step` explains the action in developer-facing language.
- `command` names the command to run when the repository can perform the
  action.
- `summary` provides concise context for the caller.

Reports contain paths and presence indicators for sensitive artifacts, never
credential values. The reporter identifies commands but does not execute
provisioning or send a proof notification.

## Consent and ownership

The program enforces consent in state rather than relying only on prompt text.
Approvals are scoped independently:

- `list`: inspect projects visible to the current Google account;
- `firebase`: change the selected project;
- `create-app`: register an Android app in that project.

The coding-agent path records the selected driver in `resolved.env`.
`DRIVER=agent` or `DRIVER=developer` exported only in the caller's environment
does not replace that recorded choice.

For project discovery, the rendered question creates a one-time token under
`.iterable/asked/`. `bin/agent approve list` accepts the approval only when it
references the current token and the question has had time to be displayed.
The token is consumed after use.

In a TTY, the wizard collects the answer directly. `APPROVED=1` is reserved for
approved automation with no interactive developer and must not be set by a
coding agent.

## Developer-facing text

The authoritative copy-review workflow is in
[`CONTRIBUTING.md`](../CONTRIBUTING.md). In summary:

| Surface | Source |
|---|---|
| Migrated question copy | `copy/screens/*.md` |
| Unmigrated question copy and all option behavior | `bin/questions.sh` |
| Gate names and verdicts | `bin/gates`, `bin/gates-device.sh`, `bin/gates-iterable.sh` |
| Banners, summaries, endings, and ladder headings | `bin/config.sh` |
| Iterable dashboard instructions | `bin/iterable-keys` |
| Terminal-only text | `bin/wizard` |
| Coding-agent-only protocol text | `bin/agent` |

Use `make screens-help` to list the shared question scenarios and `make screens`
to render them without credentials, network access, or a device. The renderer
does not cover every string in the table above.

`copy/screens/opening.md` is currently the only migrated screen. Its stable
option IDs connect writer-editable labels and descriptions to commands and
state changes in `bin/questions.sh`.

Two text constraints are enforced by `make test`:

- Gate names have a 34-column display budget.
- Developer-facing output must not instruct installed users to run a bare
  `bin/...` path that will not resolve from their project.

## Gates and exit codes

The verifier contains eighteen gates, `G0` through `G17`. Important proof
boundaries include:

- `G9`: the service-account key can authenticate with FCM.
- `G13`: the installed APK exposes the expected Iterable messaging service.
- `G14`: the SDK attempted device-token registration.
- `G16`: Android's notification service contains the marked proof
  notification.
- `G17`: server-side corroboration when a campaign-based send provides that
  evidence.

Some Iterable dashboard configuration cannot be read back through a public API.
Those checks remain unverifiable until a later observable result proves the
configuration indirectly.

| Code | Meaning |
|---|---|
| `0` | All required gates are green |
| `10` | Developer action is required |
| `20` | A gate found a defect |
| `30` | The tool itself failed |
| `40` | Nothing is broken, but a required state has not happened or cannot yet be proven |

`bin/onboard` is idempotent and resumes from the recorded workspace state.
When developer action is required, it writes `.iterable/ASK.md`.

## Iterable dashboard workflow

Iterable does not expose public API operations for creating API keys, creating
a mobile app, or configuring a Firebase push integration. The program therefore
guides the developer through four dashboard steps:

1. Create the server and mobile API keys.
2. Create the mobile app.
3. Configure the Firebase push integration.
4. Confirm the test identity used by the application.

The first three are dashboard configuration operations; the fourth connects the
application's identity to the verification flow.

In a non-interactive session, `bin/iterable-keys --take server|mobile` reads a
newly copied key from the local clipboard, writes it to `.iterable/.env` with
mode `0600`, clears the clipboard, and prints only the result status.

## Device boundary

Device gates operate through `adb` against the selected application and device:

| Gate | Evidence |
|---|---|
| G13 | `dumpsys package`: installed version, install time, and messaging-service resolution |
| G14 | `logcat`: the latest relevant device-token registration attempt and Iterable response |
| G16 | `dumpsys notification`: the notification record, channel, and proof marker |

The developer chooses the target device even when only one is connected.
Remembered emulators are identified by AVD name because emulator serials can
change between boots. `ANDROID_SERIAL` explicitly overrides device selection;
clearing `TARGET_DEVICE` forgets the recorded choice.

The verification gates never launch or operate the application. After
installation, and again when `run_app` is the next step, the workflow invokes
`bin/launch-app` to open the selected package's launcher activity. The developer
still signs in, uses the app, and responds to the Android notification
permission prompt.

`bin/proof-push` adds a marker to the sent notification. G16 requires that
marker when verifying the proof-send path, preventing an unrelated notification
from satisfying the gate.

## Workspace

The generated `.iterable/` directory belongs to the developer, gitignores
itself, and can contain live credentials.

| Path | Owner and purpose |
|---|---|
| `.env` | Iterable API keys, test identity, and related API settings, mode `0600` |
| `ASK.md` | Current developer action requested by the program |
| `state.tsv` | Gate results and resume state |
| `resolved.env` | Non-secret choices such as project, package, app ID, device, and proof marker |
| `artifacts/` | `google-services.json`, service-account key, and other generated artifacts |
| `runs/<timestamp>/` | Reports and diagnostic output |
| `onboard`, `agent`, `gates`, and related files | One-line entry-point stubs for the installed workflow |

The entry-point stubs avoid exposing a versioned plugin-cache path to the
developer. They are rewritten on each run so they follow the active plugin
installation. Internal commands such as `wizard` and `provision` do not receive
developer-facing stubs.

## Tests

`make test` runs the offline suites. `make test-all` additionally runs checks
against Iterable's published API specification.

| Suite | Contract |
|---|---|
| `tests/agent-next-action.sh` | Each ladder state produces one owner and next action |
| `tests/agent-transitions.sh` | Recommended choices advance through the intended flow |
| `tests/agent-questions.sh` | Chat and terminal paths receive the same shared questions |
| `tests/ask-question.exp` | Interactive choices return the selected option |
| `tests/approval-gate.sh` | Scoped consent and one-time question tokens |
| `tests/launch-app.sh` | App launch remains limited to the selected launcher activity |
| `tests/text-surface.sh` | Screen source discovery, Markdown validation, and text budgets |
| `tests/no-bare-commands.sh` | Installed-user output contains resolvable commands |
| `tests/key-propagation.sh` | Delayed key propagation remains distinct from invalid credentials |
| `tests/fcm-classify.sh` | FCM responses map to the correct verdict |
| `tests/itbl-classify.sh` | Iterable API failures remain distinguishable |
| `tests/device-token-log.sh` | Device-token registration evidence |
| `tests/device-notify.sh` | Notification-service proof and marker matching |
| `tests/device-pick.sh` | Device and emulator selection |

## Agent definitions

Runtime agent definitions live under `agents/`:

- `gcp-provisioner`: Google and Firebase provisioning.
- `iterable-api-client`: Iterable API interaction and verification.
- `web-operator`: browser interaction restricted to approved console origins.
- `gate-auditor`: read-only re-derivation of gate results.

Build-only roles live under `tools/agents/` so they are not discovered in every
installed client session. `make link-agents` links both sets for local
development.

## Deferred work

- Recorded-browser assistance for dashboard operations.
- Negative fixtures for more Google-side failure modes.
- A scheduled end-to-end canary.
