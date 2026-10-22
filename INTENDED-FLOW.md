# The intended flow

One path, written down once, so that changes can be checked against it instead of against
whoever last remembered it. Every patch in this tool's history has defended a path that
existed only in conversation — which is why the same failure has been fixed three times and
come back three times.

This file is the contract. Four suites hold the tool to it — `agent-questions.sh`,
`agent-next-action.sh` and `agent-transitions.sh` for the conducted path, and
`no-bare-commands.sh` for the handover it replaced. When the intended path genuinely
changes, this file changes *first* and those suites change with it; a change that
contradicts this file without editing it is a regression by definition, no matter how
reasonable it looked in isolation.

## The shape, in one sentence

**The agent conducts the wizard inside the conversation.** It is not a router that hands the
developer a command, and it is not an author that invents its own version of the wizard's
questions. Every screen the terminal can show, the chat can show; the tool supplies the
words, the developer supplies the answers, the agent carries them in both directions.

## The waypoints

Numbered because the auditor reports divergence by waypoint.

**W1 — Scope.** First prompt, the agent establishes what the developer wants integrated and
confirms it. *Verified working; do not redesign it.*

**W2 — The Android work.** The agent writes config, init and identity, guided by the skill
and `PITFALLS.md`. It never fakes an input to make a build pass: no placeholder
`google-services.json`, no invented API key, no commenting out the `google-services` plugin.

**W3 — The discovery.** The agent finds that some combination of these is missing: a real
`google-services.json`, the Firebase app registration, the Iterable API keys, the push
integration. **This is the divergence point.** Every observed failure of this tool has
happened here and nowhere else.

**W4 — The offer.** The agent puts the Google/Iterable half to the developer as a question
it asks *in the conversation*: here is what is missing, here is the tool that can do it,
here is what it will read and change, may I run it? Running it in their terminal is **one of
the options that question offers**, not the recommendation and not the default. The words
come from the tool (`agent question opening`), not from the agent.

**W5 — The consent.** The developer answers. Only the developer's answer is consent. Not a
signed-in `gcloud`, not an obvious next step, not a previous yes to something adjacent, not
the agent's own reading of what they'd probably want.

**W6 — The conduct.** On yes, the agent drives the scripts and relays each screen: it asks
the tool for the next question, shows the options to the developer, takes their choice, and
feeds it back to the tool. Project selection is the canonical example — the tool ranks and
words the options, the developer picks one, the agent records the pick. The agent never
composes a menu, never picks on the developer's behalf, and never reports a step as done
that it has not run.

**W7 — The proof.** A real push lands on a real device, verified by something that did not
perform the step it is verifying. The tool never grades its own work.

## Native iOS provider path

Native iOS keeps the same conducted, provider-first contract without pretending
Apple and Firebase have identical control planes:

1. Record the feature scope. For push, confirm the exact application target:
   status reads the Bundle ID and product name from the app's build settings
   and `choose_bundle` offers them as one runnable `record-target`.
2. For push, ask the developer to choose one Apple setup strategy: reuse an
   existing ready setup, follow a guided Account Holder or Admin handoff, or,
   only when they hold one, use an App Store Connect Team API key.
   The guided handoff walks one Apple Developer step per screen (App ID, Push
   Notifications, APNs key), and each screen's `prompt` names its action so a
   selector shown without its `context` still says what to do. The Team-key
   path reads App Store Connect, shows the exact plan, and writes the App ID
   and Push Notifications only after the developer approves it.
3. Record existing and guided read-back as developer-confirmed
   (`developer_observed`, `tool_verified: false`); only the Team-key read-back
   is `tool_verified`. The tool never signs in to an Apple account.
4. Import the deliberately retained APNs key from the `.p8` path the developer
   answers with (Key ID from the file name, Team ID from `DEVELOPMENT_TEAM`).
   `validate-apns` then proves the key, Key ID, and Team ID with one APNs
   sandbox probe; it does not prove the App ID. Then
   move to the Iterable Mobile key, the Server-side key, and the iOS
   app/APNs dashboard configuration. A rejected key routes to its replace
   screen rather than to the same validation again.
5. Integrate the selected SDK features and hand runtime evidence to the
   independent verifier.

Every screen on that path either carries a command to run or names the human
action and waits; `tests/ios-provision-transitions.sh` walks it with fakes and
fails on an empty command, a human step without a question, or a step that
comes back unchanged. Changing the selected Bundle ID invalidates
target-bound local state before the flow resumes.

## Native iOS verification-only path

A request to verify an app that is already integrated does not restart the
integration or Apple provisioning flow:

1. `ios-verify status` is the first call. With no proof run it hands back the
   proof screen itself: the detected bundle, a prefilled device (a single
   eligible booted Simulator is selected and shown), and one free-text answer
   for the identity the app is signed in with. A Simulator implies the APNs
   sandbox, so the environment is not asked. `ios-verify inspect` reads the
   project without requiring `.iterable/ios/` when there is no context at all.
2. The screen's command records a behavioral proof run and makes no app edits.
   An existing run is offered as keep or restart, and a run older than 24 hours
   must be restarted. Instrumented proof is used only after an explicit request
   for a benchmark, evaluation, or callback-level diagnostic run.
3. A new integration completed in the current session may record its exact
   built artifact; a standalone verification reuses the installed application
   and reports that the current source/build is not linked to that proof.
   `ios-install` never builds. Standard proof never relaunches the app.
4. The verifier checks the exact user and device registration remotely. On a
   Simulator it also checks that Iterable holds that Simulator's current APNs
   token. Before requesting one missing manual action it performs short-lived,
   purpose-scoped screen and log inspections that may foreground the app but
   never tap, type, grant permission, or navigate.
5. With an imported APNs key, the verifier asks Apple directly (I13) whether it
   accepts pushes for the app's real Simulator token, using one silent probe
   that is a diagnostic, never delivery; a refusal is named with its fix.
   On a Simulator, `ios-prove` checks the Simulator, Iterable, and that same
   Apple answer,
   moves the app out of the foreground, and sends one marked push through the
   Iterable API with a fresh nonce. It reads the Simulator's notification store
   and Unified Log: APNs delivery is the Simulator `apsd` receipt carrying this
   run's nonce, joined to the stored notification by its SpringBoard digest. A
   locally injected record, a wrong nonce, or a duplicate never passes. A miss
   is named from the log and is never resent; restarting is the developer's
   decision. `ios-verify` re-derives the same verdict from the Simulator on its
   own.
6. On a physical iPhone, `ios-prove` sends one push whose body shows a
   six-character code, sent as a per-send merge field so the template holds only
   a placeholder; only its scrypt hash is stored. The developer reads the
   code from the phone and `ios-prove readback` checks it (three wrong codes end
   the run). It then tries `log collect --device-udid` without elevation to
   corroborate exactly one alert push for the app; a refusal skips
   corroboration and is reported, never escalated. `done` says the proof is
   developer-observed and that the physical path has not been tested by the
   maintainers. Production APNs is allowed here.

So the standard Simulator path is `ios-verify status` → the proof screen's
command → `ios-prove --confirm` → `ios-verify status`: four tool calls and one
developer answer.

Profile/event mutation checks, tap routing, logout, second-user ownership, and
callback ordering belong to the explicit instrumented benchmark path.

Normal push proof uses the same API-targeted template proof as Android and
reads its arrival from the selected device's own records. Dashboard direct
Test Push remains optional troubleshooting and never blocks completion.

Only missing verification credentials return to their narrow capture command.
Missing proof metadata is not evidence that the SDK integration is missing.

## React Native path

A React Native app runs the Android path and then the iOS path, one after the
other, under the `iterable-react-native` skill:

1. Confirm the scope once, in the skill's Step 0 — features and identity mode.
   The Android ladder records none of it. The iOS path receives those answers
   as `--features` / `--identity`, marks their origin (`scope_source` /
   `identity_source` = `react-native-step0`), and shows them again before
   recording them. Region and JWT policy come from the Android setup.
2. **Android first.** The Android ladder provisions Firebase and Iterable,
   `ios-provision import-from-android --confirm` copies the Mobile key into the
   file the JavaScript app reads (it runs no Apple step), the skill writes the
   integration, and `iterable-android-verify` proves a push. No iOS step starts
   before that verdict is green.
3. **iOS second.** The iOS provider path already holds both Iterable keys, the
   region, No JWT, and the test email from that import, carries over the
   feature scope from step 1 (passed with `--features`, shown again for
   confirmation), and adds the Apple/APNs prerequisites. The skill writes the
   native push code (bare) or relies on the Expo plugin, and
   `iterable-ios-verify` proves a push on a Release Simulator build.
4. The app is integrated when the verifier has passed for every platform in
   scope. One green platform is not done.

The Mobile key reaches the app as a gitignored file the tool writes during the
Android phase — bare
React Native `.iterable/rn/iterable.local.ts`, Expo `EXPO_PUBLIC_ITERABLE_API_KEY`
in `.env.local` — and the app loads it so that a checkout without the file
still builds.

## What divergence looks like

The three classes, because they need different fixes and get confused constantly:

- **Class A — the text tells it to do the wrong thing.** Prose that says to relay a command
  and stop, or to hand over. Fix: edit the text.
- **Class B — the text says the right thing and nothing enforces it.** A rule that lives
  only in a sentence. Fix: put the check in the program. Consent is a mechanism, not a
  paragraph.
- **Class C — the right action exists and is more expensive than a wrong one.** The
  intended path costs more turns, more reading, or more guessing than the shortcut, so a
  model under pressure to be useful takes the shortcut. **This is the class that keeps
  regressing**, because every individual patch looks correct and the cheapest path is
  unchanged. Fix: make the intended action the cheapest one available.

A fourth thing that is *not* divergence: a not-yet state. A gate that is pending because a
human has not acted is the tool working, and reporting it as a defect is its own bug.

## Where each waypoint is pinned

A waypoint defended only by this file is defended by nothing. What holds each one:

- **W4, the offer** — `tests/agent-next-action.sh`: every ladder state routes to one owner
  and one kind, and the fork is reported while it is unanswered rather than one of its
  answers.
- **W5, the consent** — `tests/approval-gate.sh`: a yes needs the token the screen carried,
  and has to arrive slowly enough to have been read. `tests/agent-questions.sh`: the screens
  say what the terminal says.
- **W6, the conduct** — `tests/agent-transitions.sh`: the walk takes each screen's own
  recommended answer, runs what it carries, and asks again. A state that comes back
  unchanged fails. This is the one that was missing, and its absence is the whole reason
  the same failure returned three times: **the other suites pin states, and the defect
  lived in the transition between them.**
- **Every routed state names something to run** — `expect()` in
  `tests/agent-next-action.sh` fails an empty `next.command`. The exceptions are the steps
  no script of ours performs: install a toolchain, build, run the app, look, send a
  campaign. A state whose remedy cannot be named ends in a handoff, every time.
- **Delivery** — `tests/plugin-manifests.sh`: if anything a client receives differs from
  `main`, the manifest version has to differ too. A fix that does not reach the installed
  copy is indistinguishable from no fix, and that is how a season of them was spent.

## Standing constraints the flow may never trade away

- The developer's Google and Iterable passwords are never handled by the tool; they
  authenticate in their own browser or `gcloud` and the agent attaches to that session.
- Never ask anyone to paste a secret into the conversation. Keys move by file path, env
  var, or `iterable-keys --take`; the agent never reads the clipboard itself.
- `APPROVED=1` is the CI form of consent, for a run with no human in it. The agent never
  sets it.
- Three yeses, three sizes, none implying the next: `list` to look at the estate,
  `firebase` to change a project, `create-app` to add an app.
