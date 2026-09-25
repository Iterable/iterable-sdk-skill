# `bin/` — the program behind `iterable-provision` and `iterable-verify`

Maintainer reference for the shell program the two skills drive. For the product view — what a
client installs and why — read the [repo README](../README.md). For the path a run is *supposed*
to take, [`INTENDED-FLOW.md`](../INTENDED-FLOW.md) is the contract, and it changes before the code
does.

**Paths and commands in this file are relative to the repo root**, where `bin/gates` resolves. A
developer driving the tool from their own project never types these: they get one-line stubs in
`.iterable/`, for the reason in [Why the stubs exist](#why-the-stubs-exist).

The whole design rests on one property:

> **The actor never grades its own work.**

`bin/provision` and `bin/proof-push` do things. `bin/gates` judges them and can do nothing at all.

## Three tiers, in strict preference order

Nothing here drives a browser.

1. **Deterministic** — `gcloud`, REST, and Iterable's public API. Everything Google-side, and the
   entire verification loop.
2. **Human, by design** — three Iterable dashboard steps have no API at all, so the developer does
   them and the tool proves the result. `bin/iterable-keys` says exactly what to click, takes the
   two keys off the clipboard (or off a prompt with echo off), and hands straight to the verifier.
3. **Human, because it must be** — Google Cloud ToS, Google sign-in, Iterable sign-in, CAPTCHAs,
   org-policy blocks. The tool writes what it needs to `.iterable/ASK.md` and exits `10`.

Moving a step to a later tier requires evidence the earlier tier cannot do it, not a hunch. A
recorded-Playwright tier for tier 2 is designed and deferred: it would be a convenience layer over
a path that already works, and Iterable's key-creation screen is mid-rewrite.

**The tool never handles anybody's password.** The developer signs in themselves, in their own
browser or their own `gcloud`; the agent attaches to that session.

## Three front ends, one verdict

`bin/onboard` dispatches the first two on whether stdin is a TTY. `bin/agent` is asked for by name.

| Caller | Front end | Why |
|---|---|---|
| A human at a terminal | `bin/wizard` — menus, inline `gcloud auth login`, one confirm before any change | It can host interactive sub-processes, so nobody leaves and comes back |
| A script or CI job | `bin/onboard` report-and-exit: prints the ladder, names the single next action, exits `0`/`10`/`20`/`40` | No prompt can ever block it; safe to drive from a loop |
| An agent | `bin/agent` — one JSON object on stdout, the ladder on stderr, the same exit codes | A model branches on `next.kind` instead of parsing a table it might read wrong |

All three share one verdict and one set of actions. What differs is the conversation and only that:
the wizard asks with menus, `bin/agent` hands the same questions to the host's own question UI.
Neither invents a gate, and neither decides anything the other wouldn't.

## The `next` protocol

`next` is the whole contract: `{owner, kind, gate, step, command, summary}`.

- `owner` — `human`, `tool`, `agent` or `none`.
- `kind` — the branch to take (`authenticate`, `choose_target`, `approve_firebase`, `provision`,
  `iterable_keys`, `install_app`, `run_app`, `send_proof`, `install_tools`, `done`, …).
- `step` — the same step in the developer's words, because `G13` is our vocabulary and not theirs.
- `command` — what to run, when there is something to run.

It is derived from `state.tsv`, never from the exit code: rc `40` says something is pending and
never which thing, rc `10` says a human is needed and never which step.

Two rules the JSON keeps: **paths, never values** — a credential in a report is a credential in a
log, so `artifacts` carries `path` and `present` and nothing else — and **the reporter never acts**,
so `bin/agent` provisions nothing and sends nothing. It names the script; the caller runs it.

Every screen the wizard shows has a twin in `next.question`, including registering a missing
Android app and picking the device by name, so the chat is the whole walk rather than a router to
the terminal. `run_app` keeps its question even after the device is settled: signing in and
answering Android's notification dialog happen inside the developer's app, so the tool asks and
waits.

**Nothing in here ever works the developer's device.** The gates read `dumpsys` and `logcat` and
never tap, type or launch — a guessed tap is indistinguishable from a slow screen, and a permission
the tool granted itself is not evidence of anything.

### Who drives the Google setup stays open until the developer answers

`next.kind` comes back as `choose_driver` — the fork itself — rather than either of its answers.
`bin/agent set DRIVER=agent` or `DRIVER=developer` is the developer answering; nothing else may set
either. `bin/handoff` sends them to their own terminal, which is the one place that can host the
Google sign-in in the same session.

Once `DRIVER=agent` is recorded, `setup.handoff_command` and `setup.drive_it_yourself` both come
back `null`. A field an agent can see is a field an agent can reach for, and a terminal block left
on offer at every read is how a developer who asked for the chat still ended up holding a command
to type.

That routing is advice to whoever reads it, and twice an agent ran the setup anyway — so the actor
asks the same question and answers it from disk. `bin/provision` and `bin/onboard --apply` exit
`10` with the handoff block unless a terminal is attached, or `DRIVER=agent` is *recorded* in
`resolved.env`. Recorded, not exported: `DRIVER=agent bin/onboard --apply` is a caller authorising
itself, so the environment loses here on purpose. A tty is the one thing a chat cannot fake, which
is what lets the wizard through the same gate without an exception written for it.

### Consent is a mechanism, not a paragraph

Nothing reaches somebody's Google project until a yes is recorded against *that project*: `next`
routes to `approve_firebase` ahead of any mutation, and `bin/provision` exits `10` without making a
single call if the record is missing — so an agent that skips the question is stopped by the program
rather than by prose. `approval.plan` is generated from the ladder, so the banner, the dry run and
the JSON cannot describe different work. `APPROVED=1` is the same answer for a job with no human in
it.

**The read is gated the same way**, because it was the one that kept happening: three transcripts
show an agent finding `gcloud` already signed in and listing every Firebase project the account
could see, on the strength of prose asking it not to. Being able to look is not being allowed to
look, so `bin/discover` also exits `10` having read nothing until a yes is recorded — scoped to the
Google account rather than to a project, since no project is chosen yet. Three yeses, three sizes:
`list` to look, `firebase` to change, `create-app` to add.

The `list` yes goes further, because the refusal above hands an agent a motive to record it itself:
it has to have come off a screen. Rendering `choose_target` mints a one-time token into
`.iterable/asked/` and stamps the moment the screen finished printing. `agent approve list` takes
`--asked <token>` and refuses at exit `10` if there is no screen, if the token is not the one the
screen carried, or if the yes arrives sooner than `ASK_DWELL_MS` (200ms) after it — nobody reads a
consent screen in a fifth of a second. The token is spent on use, so one screen buys one yes.

What this cannot catch is a caller that renders the screen, holds the token and waits: that is
forging consent rather than drifting past prose, and no check on this side of the conversation can
tell it from a developer who agreed. A tty skips the whole thing — the wizard asks in person.

## The pieces

The split is structural rather than conventional.

| Command | Role |
|---|---|
| `bin/gates` | **Verifier.** Read-only. Never provisions anything |
| `bin/agent` | **Reporter.** Runs the verifier and serialises its state; provisions nothing, sends nothing |
| `bin/provision` | **Actor.** Idempotent; ends by handing off to `bin/gates` to be judged |
| `bin/proof-push` | **Actor.** Sends the one push the ladder exists to prove, and records the marker it sent. Never checks whether it arrived |
| `bin/discover` | Read-only list of the developer's Firebase projects and their Android apps |
| `bin/iterable-keys` | Walks the four Iterable dashboard steps that have no API, captures the keys, then hands off to `bin/gates`. Offers the identity the app already registered, read from the device |
| `bin/handoff` | Prints the block that sends a developer to their own terminal, for an agent to relay verbatim. Changes nothing |
| `bin/teardown` | Removes only what the tool added |

Without a terminal, `bin/iterable-keys` prints the same four dashboard steps and writes
`.iterable/.env` at mode `0600` with three empty names. A key gets in from there with
`bin/iterable-keys --take server|mobile`, which reads it off the clipboard — where the dashboard's
copy button just put it — writes it to that file, clears the clipboard and prints only a tick. So
nobody pastes a key into a conversation, and the gates prove the keys by spending them.

### The suites that pin all this

`make test` runs them; they are offline unless noted.

| Suite | What it holds still |
|---|---|
| `tests/agent-next-action.sh` | Every ladder state → one owner and one action, against fixture state files. The agent path has no human to notice a mis-route |
| `tests/agent-questions.sh` | The chat and the terminal show the same screens |
| `tests/key-propagation.sh` | G9 tells "key hasn't propagated yet" apart from "key is broken" |
| `tests/fcm-classify.sh` | The FCM verdict, against recorded bodies — the two 403s that mean opposite things |
| `tests/itbl-classify.sh` | The Iterable verdict: a wrong key stays distinguishable from a wrong request |
| `tests/key-types-match-spec.sh` | The key type each gate sends, against Iterable's published spec (needs the network) |
| `tests/itbl-transport.sh` | The HTTP status survives the call — the bug that broke G10 live |
| `tests/device-token-log.sh` | G14 against recorded logcat: which absences mean something, and which mean nothing |
| `tests/device-notify.sh` | G16 against recorded `dumpsys notification`: nothing but the push we sent reads as the push we sent |
| `tests/device-pick.sh` | Which device the gates read, with a stubbed `adb` and `emulator` — the serial that isn't there, and the AVD that never boots |
| `tests/no-raw-http.sh` | Lint: every API call goes through a wrapper, and no credential reaches `resolved.env` |
| `tests/no-bare-commands.sh` | Lint: nothing tells a developer to run a path that cannot resolve from their own project |
| `tests/wizard-decline.exp` | Drives the wizard through a pty and asserts that declining changes nothing |

## Exit codes

`bin/onboard` is idempotent: it skips gates that are already green. When it needs the developer it
writes `.iterable/ASK.md`, exits `10`, and picks up where it left off next time. Safe to drive from
a loop or a cron tick.

| Code | Meaning |
|---|---|
| `0` | All gates green — a push reached the device |
| `10` | Blocked on the developer — read `.iterable/ASK.md` |
| `20` | A gate failed — a real defect; see the run report |
| `30` | Tool error |
| `40` | Nothing is broken and nothing is proven — a gate ran and found the state simply hasn't happened yet |

`40` exists because the alternative is a lie in both directions. A live run had G15 go **red** —
"No user exists with email …" — when the actual cause was that nobody had launched the app yet, so
no token existed to find. That reported a defect in someone's Iterable project for work that was
merely pending. Reporting `0` instead would have been worse.

## The Iterable half is deliberately hand-driven

Three steps have no public API at all: creating an API key, creating a mobile app, and configuring
the push integration. That is verified, not assumed — none of the 131 paths in
<https://api.iterable.com/api-docs> can do any of them.

So the developer clicks those three and the tool proves the result with a real call. It does **not**
drive a browser and does **not** mint keys in their project. The ladder marks G11 and G12 with `~`
rather than a tick, because no endpoint can read them back, and a gate that reads a local file to
decide a remote step happened is the false pass this tool exists to prevent. They are proved
indirectly: if G16 lands a push, both were right.

## The device half reads the device

G13, G14 and G16 run over `adb` against the developer's own app. They read; they never build,
install, launch or send.

| Gate | What it reads | Why that and not the obvious thing |
|---|---|---|
| G13 | `dumpsys package` — version, install time, and whether `IterableFirebaseMessagingService` resolves | The APK on the device receives the push. A green local build proves nothing about what is installed, and "integrated, forgot to reinstall" is a real morning |
| G14 | `logcat` — `registerDeviceToken` and the code Iterable answered | The buffer rotates, so this can prove registration happened and can never prove it didn't. Silence is `pending`, forever |
| G16 | `dumpsys notification` — the record, its channel, and the proof marker | The notification service is neither the sender nor the app, so it can be fooled by neither, and it needs no code in the app under test |

The wizard asks which device to use **even when only one is attached**, because a phone left plugged
in to charge is still the wrong thing to prove a push on, and `emulator-5556` is a port number
nobody recognises as their own device. Every line names the AVD instead. AVDs that aren't running
are offered too, and the wizard boots the one you pick. The choice is remembered as the **AVD
name**, not the serial: emulator serials are handed out in boot order, so the same AVD is
`emulator-5554` today and `5556` tomorrow.

`bin/gates` never asks — it must stay safe to drive from a loop. With several devices attached it
names them all and exits. `ANDROID_SERIAL` overrides everything; `TARGET_DEVICE=` forgets the
remembered one.

`bin/proof-push` writes a marker into the message it sends, and G16 requires that marker to match.
Sent some other way — a **Test Push** from the dashboard, say — there is no marker, and G16 falls
back to the SDK's own notification channel, which is as much as the OS can honestly tell you.

**To watch it arrive, clear the shade first.** Android groups a second notification from the same
app with the first and marks the children `SILENT`: no banner, no sound. The push arrives, G16 sees
it, and the screen shows nothing — which looks exactly like a push that failed. G16 says so itself,
because a caveat only `bin/proof-push` prints is invisible to anyone running the verifier:

```
✓  G16  Push arrives on device   "G16 proof itbl-onboard-1789996750" at 2:19:13 PM, 2s after send — SILENT, no banner
```

It also states how long ago every arrival landed, since re-running the ladder does not re-send and
a green can be hours old. If G16 is green and nothing was seen, those two lines say which it was.

The test identity is the other thing worth not guessing. `ITBL_EMAIL` has to be the value the app
passes to `setEmail()`, and the app decides that in code — so `bin/iterable-keys` reads the identity
out of the SDK's own `registerDeviceToken` request in `logcat` and offers it as the default. A wrong
answer makes G15 report "no user yet", which is indistinguishable from a broken Iterable project.

## The two gates that cannot be faked

Eighteen gates, `G0`–`G17`, each a pure read performed independently of the step that produced it.
The last real one, G16, is a push landing on a real device; everything before it is a stepping
stone. The two that cannot be faked are **G9** (the service-account key actually authenticates
against FCM) and **G16** (the message actually arrives). They are deliberately independent proofs.

G17 was meant to corroborate G16 from the server side, and on the proof-send path it cannot:
measured 2026-09-21, a proof send that demonstrably reached the device raised **no** `pushSend`
event at all. So G17 is a gate only when `ITBL_CAMPAIGN_ID` is set and the send goes through a
campaign, and a `~` otherwise. The alternative — leaving it a gate — parks every successful run at
"not done" forever.

## Workspace

`.iterable/` belongs to the developer and gitignores itself. It holds live Google session cookies
and a downloaded service-account key: treat it as sensitive and keep it local.

| Path | Owner |
|---|---|
| `.env` | the developer, via `bin/iterable-keys` — the Iterable keys, mode `0600`, never printed back. Created with the names and no values on the scripted path, filled by `--take server\|mobile` off the clipboard or by hand. Never overwritten once it holds a value: keys are shown once. `docs/onboard/env.example` lists the exact names the tool reads |
| `chrome-profile/` | the developer — sign in once |
| `ASK.md` | the tool — what it needs from the developer |
| `state.tsv` | the tool — gate results and resume point |
| `resolved.env` | the tool — choices safe to print: project, package, app id, proof marker. Never a credential |
| `artifacts/` | the tool — `google-services.json`, key (mode `0600`), apk |
| `runs/<ts>/` | the tool — report, logs, browser session trace |
| `onboard`, `agent`, `gates`, … | the tool — one-line stubs, rewritten every run |

`docs/onboard/inputs.yml` is a template for the same values and **reference only**: no code reads
it. The wizard asks for these and remembers the answers in `resolved.env`.

### Why the stubs exist

A host installs a plugin into a version-numbered cache directory and sets no environment variable
pointing at it. That path is too long to type — and worse, hosts keep old version directories on
disk, so a path saved in a runbook keeps working while quietly running the version it was written
against.

So every entry point a developer is told to run gets a stub in their own workspace, and the messages
print `.iterable/onboard` rather than the real path. Being rewritten on every run is what makes it
safe: a stub cannot outlive the install it points at without being replaced, and one that somehow
does exits `127` saying so rather than failing at `exec`.

Internals get no stub. `wizard` and `provision` are dispatched to, never typed.

## The agents

Definitions live in [`../agents/`](../agents/) and are linked into `~/.claude/agents/` with
`make link-agents`. Two structural rules: `gate-auditor` never performs a provisioning action and no
agent audits its own gate; `web-operator` is the only agent with browser access, and it is
origin-confined to the three consoles.

Build roles live in `tools/agents/` instead, because a host discovers `agents/` by convention —
anything in there loads into every client session whether or not a client could ever use it.
`make link-agents` links both, so a build machine still gets the whole team.

## Not built

The recorded-browser tier (deferred on purpose, above), the negative-fixture suite for the Google
half, and the daily canary.
