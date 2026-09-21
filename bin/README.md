# iterable-onboard

Takes an Android developer from nothing to a push notification arriving on a device.

Reads your Firebase project, downloads `google-services.json`, creates a least-privilege service
account and its JSON key, walks you through the three Iterable dashboard steps that have no API,
and then **proves every one of them worked** — ending with a real push arriving on a device.

Companion to the `iterable-android` skill. That skill stops and asks for `google-services.json`,
a mobile API key, and a configured push integration — because it cannot invent them. This tool
produces them.

**Where it is going:** this repo merges into `iterable-sdk-skill` as two new skills, so a client
installs one plugin and the whole path is agent-guided. `skills/iterable-provision/SKILL.md` and
`skills/iterable-verify/SKILL.md` are written and travel with the merge; the plan is
`docs/plans/2026-09-21-one-plugin.md` in the skill repo.

**Plan and design rationale:** [`docs/plans/2026-09-18-iterable-onboard.md`](docs/plans/2026-09-18-iterable-onboard.md)

## Status

**The whole ladder has run green, live** — 2026-09-21, 15 of 15 verifiable gates, exit `0`, against
a real Firebase project, a real Iterable project and a real emulator. G16 matched the proof send's
own marker on the device 2 seconds after `bin/proof-push` sent it.

That is one run, on one app, by the person who wrote the tool. What it establishes is that the
ladder can reach its own definition of done; it is not yet evidence that a stranger's project can.

**Not built:** the recorded-browser tier (deferred on purpose, see the plan), the negative-fixture
suite for the Google half, and the daily canary.

## How it works

Three tiers, in strict preference order. Nothing drives a browser.

1. **Deterministic** — `gcloud`, REST, and Iterable's public API. Everything Google-side, and the
   entire verification loop.
2. **Human, by design** — three Iterable dashboard steps have no API at all, so you do them and
   the tool proves the result: `bin/iterable-keys` tells you exactly what to click, takes the two
   keys with echo off, and hands straight to the verifier.
3. **Human, because it must be** — Google Cloud ToS, Google sign-in, Iterable sign-in, CAPTCHAs,
   org-policy blocks. The tool writes what it needs to `workspace/ASK.md` and exits `10`.

A recorded-Playwright tier for tier 2 is designed and deferred; see the plan. It would be a
convenience layer over a path that already works, and Iterable's key-creation screen is mid-rewrite.

**The tool never handles your passwords.** You sign in yourself, in your own browser; the
agent attaches to that session.

## Getting started

```bash
./bin/onboard
```

That's it. At a terminal you get a wizard: it signs you in, lists your Firebase projects for you
to pick from, then the Android apps registered in the one you chose, shows exactly what it would
change, and asks before changing it. It never picks the project for you, and a remembered choice
is offered back as a default you can decline — not reused silently.

Three front ends over one engine. `bin/onboard` dispatches the first two on whether stdin is a TTY;
`bin/agent` is asked for by name.

| You are | You get | Why |
|---|---|---|
| A human at a terminal | `bin/onboard` → `bin/wizard` — menus, inline `gcloud auth login`, one confirm before any change | It can host interactive sub-processes, so you never leave and come back |
| A script or CI job | `bin/onboard` report-and-exit: prints the ladder, names the single next action, exits `0`/`10`/`20`/`40` | No prompt can ever block it; safe to drive from a loop |
| An agent | `bin/agent` — one JSON object on stdout, the ladder on stderr, the same exit codes | A model can branch on `next.kind` instead of parsing a table it might read wrong |

The three share one verdict and one set of actions. What differs is the conversation, and only that:
`bin/wizard` asks with menus, `bin/agent` hands the same questions to the host's own question UI.
Neither invents a gate, and neither decides anything the other wouldn't.

```
bin/agent                 run the ladder, report where things stand
bin/agent discover        your Firebase projects and Android apps, as JSON
bin/agent set PID=… PACKAGE=…   record a choice
bin/agent approve firebase      record the developer's yes to changing their project
```

`next` is the whole protocol: `{owner, kind, gate, step, command, summary}`. `owner` is `human`,
`tool`, `agent` or `none`; `kind` is the branch to take (`authenticate`, `choose_target`,
`approve_firebase`, `provision`, `iterable_keys`, `install_app`, `run_app`, `send_proof`, `done`, …);
`step` is the same step in the developer's words, because `G13` is our vocabulary and not theirs;
`command` is what to run when there is something to run. It is derived from `state.tsv`, never from
the exit code — rc `40` says something is pending and never which thing, and rc `10` says a human is
needed and never which step.

**The Google setup is not the agent's to run by default.** `next.kind` comes back as
`run_in_terminal` with `bin/handoff`, the block that sends the developer to the wizard, because the
wizard does three things a chat cannot: host the Google sign-in, offer to register an Android app
when the project has none, and take the Iterable keys with the echo off. That middle one is why the
default exists — a project with no app has no `google-services.json` to download, and an agent that
misses `CREATE_APP=1` is one improvisation away from faking the file to keep a build green. `bin/agent
set DRIVER=agent` is the developer choosing otherwise; nothing else may set it.

That routing is advice to whoever reads it, and twice an agent ran the setup anyway — so the actor
asks the same question and answers it from disk. `bin/provision` and `bin/onboard --apply` exit `10`
with the handoff block unless a terminal is attached, or `DRIVER=agent` is *recorded* in
`resolved.env`. Recorded, not exported: `DRIVER=agent bin/onboard --apply` is a caller authorising
itself, so the environment loses here on purpose. A tty is the one thing a chat cannot fake, which
is what lets the wizard through the same gate without an exception written for it.

Consent is a mechanism here, not a paragraph. Nothing reaches somebody's Google project until a yes
is recorded against *that project*: `next` routes to `approve_firebase` ahead of any mutation, and
`bin/provision` exits `10` without making a single call if the record is missing — so an agent that
skips the question is stopped by the program rather than by prose. `approval.plan` is generated from
the ladder, so the banner, the dry run and the JSON cannot describe different work. `APPROVED=1` is
the same answer for a job with no human in it.

Two rules the JSON keeps: **paths, never values** — a credential in a report is a credential in a
log, so `artifacts` carries `path` and `present` and nothing else — and **the reporter never acts**,
so `bin/agent` provisions nothing and sends nothing. It names the script; the caller runs it.

Without a terminal, `bin/iterable-keys` prints the same four dashboard steps and writes
`workspace/.env.template` at mode `0600` with three empty names. The developer fills it in; nobody
pastes a key into a conversation, and the gates prove the keys by spending them.

Underneath, both use the same pieces, and the split is structural rather than conventional:

| Command | Role |
|---|---|
| `bin/gates` | **Verifier.** Read-only. Never provisions anything |
| `bin/agent` | **Reporter.** Runs the verifier and serialises its state; provisions nothing, sends nothing |
| `bin/provision` | **Actor.** Idempotent; ends by handing off to `bin/gates` to be judged |
| `bin/discover` | Read-only list of your Firebase projects and their Android apps |
| `bin/iterable-keys` | Walks the four Iterable dashboard steps that have no API, captures the keys, then hands off to `bin/gates`. Offers the identity the app already registered, read from the device |
| `bin/proof-push` | **Actor.** Sends the one push the ladder exists to prove, and records the marker it sent. Never checks whether it arrived |
| `bin/handoff` | Prints the block that sends a developer to their own terminal, for an agent to relay verbatim. Changes nothing |
| `bin/teardown` | Removes only what the tool added |
| `tests/wizard-decline.exp` | Drives the wizard through a pty and asserts that declining changes nothing |
| `tests/agent-next-action.sh` | Every ladder state → one owner and one action, against fixture state files. The agent path has no human to notice a mis-route |
| `tests/key-propagation.sh` | Proves G9 tells "key hasn't propagated yet" apart from "key is broken" |
| `tests/fcm-classify.sh` | Pins the FCM verdict against recorded bodies — the two 403s that mean opposite things |
| `tests/itbl-classify.sh` | Pins the Iterable verdict: a wrong key stays distinguishable from a wrong request |
| `tests/key-types-match-spec.sh` | Checks the key type each gate sends against Iterable's published spec |
| `tests/itbl-transport.sh` | Proves the HTTP status survives the call — the bug that broke G10 live |
| `tests/no-raw-http.sh` | Offline lint: every API call goes through a wrapper, and no credential reaches `resolved.env` |
| `tests/device-token-log.sh` | Pins G14 against recorded logcat: which absences mean something, and which mean nothing |
| `tests/device-notify.sh` | Pins G16 against recorded `dumpsys notification`: nothing but the push we sent reads as the push we sent |
| `tests/device-pick.sh` | Pins which device the gates read, with a stubbed `adb` and `emulator` — the serial that isn't there, and the AVD that never boots |

### The Iterable half is deliberately hand-driven

Three steps have no public API at all — creating an API key, creating a mobile app,
and configuring the push integration. That is verified, not assumed: none of the 131
paths in <https://api.iterable.com/api-docs> can do any of them.

So you click those three, and the tool proves the result with a real call. It does
**not** drive your browser and does **not** mint keys in your project. The ladder
marks G11 and G12 with `~` rather than a tick, because no endpoint can read them
back and a gate that reads a local file to decide a remote step happened is the
false pass this tool exists to prevent. They are proved indirectly: if G16 lands a
push, both were right.

The actor never grades its own work — that's the property the whole design rests on.

`bin/onboard` is idempotent: it skips gates that are already green. When it needs you, it writes
`workspace/ASK.md`, exits `10`, and picks up where it left off next time. Safe to drive from a
loop or a cron tick.

| Exit code | Meaning |
|---|---|
| `0` | All gates green — a push reached the device |
| `10` | Blocked on you — read `workspace/ASK.md` |
| `20` | A gate failed — a real defect; see the run report |
| `30` | Tool error |
| `40` | Nothing is broken and nothing is proven — a gate ran and found the state simply hasn't happened yet |

`40` exists because the alternative is a lie in both directions. A live run had G15 go **red** —
"No user exists with email …" — when the actual cause was that nobody had launched the app yet, so
no token existed to find. That reported a defect in someone's Iterable project for work that was
merely pending. Reporting `0` instead would have been worse. No push has been proven at `40`, and
the run says so in those words.

### The device half reads the device

G13, G14 and G16 run over `adb` against the developer's own app. They read; they never build,
install, launch or send.

The wizard asks which device to use — **even when only one is attached**, because a phone left
plugged in to charge is still the wrong thing to prove a push on, and `emulator-5556` is a port
number nobody recognises as their own device. Every line names the AVD instead. AVDs that aren't
running are offered too, and the wizard boots the one you pick. The choice is remembered as the
**AVD name**, not the serial: emulator serials are handed out in boot order, so the same AVD is
`emulator-5554` today and `5556` tomorrow.

`bin/gates` never asks — it must stay safe to drive from a loop. With several devices attached it
names them all and exits; `ANDROID_SERIAL` overrides everything, and `TARGET_DEVICE=` forgets the
remembered one.

| Gate | What it reads | Why that and not the obvious thing |
|---|---|---|
| G13 | `dumpsys package` — version, install time, and whether `IterableFirebaseMessagingService` resolves | The APK on the device receives the push. A green local build proves nothing about what is installed, and "integrated, forgot to reinstall" is a real morning |
| G14 | `logcat` — `registerDeviceToken` and the code Iterable answered | The buffer rotates, so this can prove registration happened and can never prove it didn't. Silence is `pending`, forever |
| G16 | `dumpsys notification` — the record, its channel, and the proof marker | The notification service is neither the sender nor the app, so it can be fooled by neither, and it needs no code in the app under test |

`bin/proof-push` writes a marker into the message it sends; G16 requires that marker to match. Sent
some other way — a **Test Push** from the dashboard, say — there is no marker, and G16 falls back to
the SDK's own notification channel, which is as much as the OS can honestly tell you.

**If you want to watch it arrive, clear the shade first.** Android groups a second notification from
the same app with the first and marks the children `SILENT`: no banner, no sound. The push arrives,
G16 sees it, and the screen shows nothing — which looks exactly like a push that failed.

G16 says so itself, because a caveat only `bin/proof-push` prints is invisible to anyone running the
verifier:

```
✓  G16  Push arrives on device   "G16 proof itbl-onboard-1789996750" at 2:19:13 PM, 2s after send — SILENT, no banner
```

It also states how long ago every arrival landed, since re-running the ladder does not re-send and a
green can be hours old. If G16 is green and you saw nothing, those two lines tell you which it was.

The test identity is the other thing worth not guessing. `ITBL_EMAIL` has to be the value the app
passes to `setEmail()`, and the app decides that in code — so `bin/iterable-keys` reads the identity
out of the SDK's own `registerDeviceToken` request in `logcat` and offers it as the default. A wrong
answer here makes G15 report "no user yet", which is indistinguishable from a broken Iterable project.

## Done means a push arrived

Eighteen gates, each a pure read performed independently of the step that produced it. The last
real one — G16 — is a push landing on a real device. Everything before it is a stepping stone.

The gates you cannot fake are G9 (the service-account key actually authenticates against FCM)
and G16 (the message actually arrives). They are deliberately independent proofs.

G17 was meant to corroborate G16 from the server side, and on the proof-send path it cannot:
measured 2026-09-21, a proof send that demonstrably reached the device raised **no** `pushSend`
event at all. So G17 is a gate only when you set `ITBL_CAMPAIGN_ID` and send through a campaign,
and a `~` otherwise. The alternative — leaving it as a gate — parks every successful run at
"not done" forever.

## The team

Agent definitions live in [`agents/`](agents/) and are linked into `~/.claude/agents/` with
`make link-agents`. Two structural rules: `gate-auditor` never performs a provisioning action
and no agent audits its own gate; `web-operator` is the only agent with browser access, and it
is origin-confined to the three consoles.

## Workspace

`workspace/` is yours and is gitignored. It holds live Google session cookies and a downloaded
service-account key — treat it as sensitive and keep it local.

| Path | Owner |
|---|---|
| `inputs.yml` | you — package name, project ids, region, FCM type. **Reference only:** no code reads it yet. The wizard asks for these and remembers the answers in `resolved.env` |
| `.env` | you, via `bin/iterable-keys` — the Iterable keys you created, mode `0600`, never printed back. `.env.example` lists the exact names the tool reads |
| `.env.template` | the tool, on the scripted path — the same names with no values, mode `0600`. Fill it in and rename it to `.env`. Never overwritten once it holds a value: keys are shown once |
| `chrome-profile/` | you — sign in once |
| `ASK.md` | the tool — what it needs from you |
| `state.tsv` | the tool — gate results and resume point |
| `resolved.env` | the tool — choices safe to print: project, package, app id, proof marker. Never a credential |
| `artifacts/` | the tool — `google-services.json`, key (mode `0600`), apk |
| `runs/<ts>/` | the tool — report, logs, browser session trace |
