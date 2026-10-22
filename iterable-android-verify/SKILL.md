---
name: iterable-android-verify
description: >-
  Independently proves Iterable behavior on native Android and React Native
  Android. Use when a developer wants proof the integration works, when push
  is not arriving, or after an Android integration is written. It reads
  Android notification-service state directly and never provisions, edits the
  app, operates its UI, or re-sends to manufacture a pass.
---

# Proving Iterable on Android

Eighteen checks, of which the last five are the device half. One of them is the
one that matters—*push arrives on device*: an Iterable push, sent on purpose
and carrying a marker, found in the device's own notification records.

**The verification gates write nothing and send nothing.** They do not trigger
the thing they verify—a checker that sends its own push can only ever agree
with itself. Sending is `<root>/bin/proof-push`, run as a separate, announced
step.

**The gates read the device without operating it.** `adb shell dumpsys`,
`logcat`, `pm path`—yes. One separate actor, `<root>/bin/launch-app`, may start
the selected package's launcher activity after installation. That is the
boundary: `adb shell input` (tap, text, keyevent), `monkey`, `pm grant`, or any
other way of working their app for them—no, at any point. You cannot see their
login screen, so every field is a guess; and the notification permission is a
question Android asks *the person*, so a tool that taps Allow has answered it
on their behalf and then reports the answer as evidence. Open the app, relay
the human question, and wait.

## Finding the scripts

Resolve symlinks first: use the real path of this `SKILL.md` (`cd -P` /
`pwd -P`), because a skill linked into `~/.cursor/skills` has no `bin/` above
the link.
Start in the directory containing it and walk up to the first
directory containing a `bin/agent`; call that `<root>`. If you reach the
filesystem root without finding it, the install is incomplete—say so and stop.
Never reimplement a gate by hand: a check you improvise is one nobody has
tested.

## The loop

Run it **from the developer's project directory**, by absolute path:

```text
<root>/bin/agent
```

**Never `cd` into `<root>` first.** The workspace lives in their repo as
`.iterable/` and is resolved from the working directory; the plugin cache may
be read-only and is erased on the next update, so the tool exits `30` rather
than write there.

JSON is printed on stdout and the ladder table on stderr. `gates[]` gives every
gate its `status` (`green`, `red`, `pending`, `blocked`, `unverifiable`), the
`owner` who can clear it, and `detail`—the verdict in the tool's own words.
Relay `detail`; do not paraphrase it or soften it.

The five statuses are five different claims:

- **green**—proved by a read that would have failed if the state were wrong.
- **red**—a real defect. Something is broken.
- **pending**—the gate ran, reached the service, and the state has not happened
  yet. Nobody has launched the app; nothing has been sent. This is not a
  defect and must never be reported as the developer's mistake.
- **blocked**—a prerequisite is red, so this gate can say nothing true. Do not
  run it or comment on it.
- **unverifiable** (`~`)—no public API reads this back, so nothing here can
  honestly claim to have checked it. The two Iterable dashboard steps are like
  this; they are proved indirectly because a push that arrives means both were
  right.

Those five words are field values for you to branch on, not words to say to the
developer. Neither are the gate IDs (`G0`–`G17`): they exist because the state
file is keyed on them, and they mean nothing to somebody who has never read
this repository. `next.step` and `gates[].name` express the same steps in
words. Use those and say the true thing rather than the label: "Nothing is
broken, and no push has arrived yet."

Act on `next` and nothing else. Take one action at a time, addressing the first
red gate before any pending gate. Working on a pending gate while something
upstream is broken tests a system that is still wrong.

| `next.kind` | What you do |
|---|---|
| `install_app` | Their app is not on the device, or the installed APK does not carry the SDK. Build and install it, run `<root>/bin/launch-app`, then re-run the agent. The check reads `dumpsys package` for the Iterable messaging service, so it catches "integrated the SDK, forgot to reinstall"—invisible to anything that only reads the repository. |
| `run_app` | Run `<root>/bin/launch-app` first, then relay `next.question`. It asks them to sign in as `target.email` and allow notifications, and one option re-runs the checks. Opening the launcher activity is yours; driving the UI or answering the permission dialog is never yours. |
| `send_proof` | Announce it, then run `<root>/bin/proof-push`. It sends one marked push and deliberately does not check whether it arrived. Then re-run `<root>/bin/agent`. |
| `investigate` | A device-half check is red: no FCM token, the token not registered in Iterable, or a sent push that did not arrive. It has no command. Relay `next.summary` verbatim; it is the diagnosis of a defect, not pending work. Find the cause (the platform skill's `PITFALLS.md`) before changing anything, never re-send to get a pass, and re-run `<root>/bin/agent` once it is fixed. |
| `campaign_send` | Server-side corroboration needs `ITBL_CAMPAIGN_ID`; without it there is nothing to read. Optional. |
| `iterable_keys`, `provision`, `choose_target`, … | Not this skill's half—hand back to `iterable-provision`. |
| `done` | The push arrived. Say which push, on which device, and how long after the send. If `next.summary` also says the app has its own push path, relay that line and offer the optional after-integration check: the developer triggers one of the app's own notifications and confirms it shows. Run it only if they ask. It never changes the verdict. |

## When the developer says nothing arrived and the check says it did

Both can be true, and the verdict must explain the difference.

Android bundles a second notification from the same app with the first and
marks the children `SILENT`: it arrives, the check sees it in the notification
records, and the screen shows no banner or sound. The verdict appends
`— SILENT, no banner` when that happened and states how long ago every arrival
was. Read those details out. The remedy is to clear the notification shade and
send again, not to doubt the check.

The other honest answers, in order of how often they are the real one: the app
was never launched after install, so no token exists; the app signs in as a
different address than `target.email`, so the token is filed under one identity
and the proof went to another; the push integration is set to **Notification
messages** instead of **Data notifications**, so the Firebase SDK swallows it
before Iterable's SDK sees it; notification permission was denied (the verdict
distinguishes "denied" from "never asked").

## Handing back a proven push

A green ladder is the moment somebody is most likely to read "it works" as "it
has been reviewed." When `next.kind` is `done`, relay the JSON's `notice` field
**verbatim**, as a quote, alongside the proof. Do not paraphrase it or soften it
into reassurance: the push proof is evidence read back from the operating
system; the code and configuration around it is a draft, written by an agent,
for them to review like a pull request from somebody new to their codebase.

Say which half is which if they ask. `gates[].status` is the map: `green` was
proved by a call that would have failed otherwise, `unverifiable` was never
checked by anything, and the diff in their repository was checked by nobody.

## Saying what is outstanding

Lead with whose turn it is—`next.owner`, `human` or `tool`—then the step name
(`next.step`), `next.summary`, and `next.command` if there is one. Give the next
action a heading or quote block of its own; it does not belong as the fourth
bullet of a status list.

Keep the strong words for `verdict: defect`. A red step owned by `human` is
their turn. "No device attached" is not a broken integration.

## Never do these

- Never send again to turn a failing check into a passing one. If no push has
  arrived, the answer is why, not another attempt.
- Never report pending work as a failure, and never report an old arrival as a
  new one—the verdict states the age of what it found for exactly this reason.
- Never claim a gate passed because a build succeeded. A build is a weak signal
  in both directions: fabricated integrations compile, and correct ones fail.
- Never work around `unverifiable`. There is no endpoint; that is the finding.
