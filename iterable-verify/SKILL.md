---
name: iterable-verify
description: >-
  Proves an Iterable Android push integration by landing a real push on a real
  device and reading the device's own notification service to confirm it arrived.
  Use when a push is not arriving, when a developer wants proof the integration
  works, or right after `iterable-android` / `iterable-react-native` writes the
  integration — including "why isn't my push arriving?", "is the token registered?",
  "prove this works", "test push notifications". Reads only; it never provisions,
  never edits the app, and never re-sends to manufacture a pass.
---

# Proving Iterable push on a device

Eighteen checks, of which the last five are the device half. One of them is the one
that matters — *push arrives on device*: an Iterable push, sent on purpose and
carrying a marker, found in the device's own notification records.

**This skill writes nothing and sends nothing on its own.** The verifier does not
trigger the thing it verifies — a checker that sends its own push can only ever
agree with itself. Sending is `<root>/bin/proof-push`, run as a separate, announced step.

## Finding the scripts

Start in the directory containing this `SKILL.md` and walk up to the first directory
containing a `bin/agent`; call that `<root>`. If you reach the filesystem root without
finding it, the install is incomplete — say so and stop. Never reimplement a gate by
hand: a check you improvise is one nobody has tested.

## The loop

Run it **from the developer's project directory**, by absolute path:

```
<root>/bin/agent
```

**Never `cd` into `<root>` first.** The workspace lives in their repo as `.iterable/`
and is resolved from the working directory; the plugin cache may be read-only and is
erased on the next update, so the tool exits `30` rather than write there.

JSON on stdout, the ladder table on stderr. `gates[]` gives every gate its `status`
(`green`, `red`, `pending`, `blocked`, `unverifiable`), the `owner` who can clear it,
and `detail` — the verdict in the tool's own words. Relay `detail`; do not paraphrase
it, and do not soften it.

The five statuses are five different claims, and collapsing any two of them is how
this goes wrong:

- **green** — proved, by a read that would have failed if the state were wrong.
- **red** — a real defect. Something is broken.
- **pending** — the gate ran, reached the service, and the state simply has not
  happened yet. Nobody has launched the app; nothing has been sent. This is *not* a
  defect and must never be reported as the developer's mistake.
- **blocked** — a prerequisite is red, so this gate can say nothing true. Do not run
  it, do not comment on it.
- **unverifiable** (`~`) — no public API reads this back, so nothing here can honestly
  claim to have checked it. The two Iterable dashboard steps are like this; they get
  proved indirectly, because a push that arrives means both were right.

Those five words are field values for you to branch on, not words to say to the
developer. Neither are the gate ids (`G0`–`G17`) — they are in the JSON because the
state file is keyed on them, and they mean nothing to somebody who has never read
this repo. `next.step` and `gates[].name` are the same steps in words: use those, and
say the true thing rather than the label — "nothing is broken, and no push has
arrived yet".

Act on `next` and nothing else. One action at a time, first red before any pending:
fixing a pending gate while something upstream is broken is work against a system
that is still wrong.

| `next.kind` | What you do |
|---|---|
| `install_app` | Their app is not on the device, or the installed APK does not carry the SDK. Build and install, then re-run. The check reads `dumpsys package` for the Iterable messaging service, so it catches "integrated the SDK, forgot to reinstall" — invisible to anything that only reads the repo. |
| `run_app` | Launch the app and sign in as the address in `target.email`. That exact address. |
| `send_proof` | Announce it, then run `<root>/bin/proof-push`. It sends one marked push and deliberately does not check whether it arrived. Then re-run `<root>/bin/agent`. |
| `campaign_send` | Server-side corroboration needs `ITBL_CAMPAIGN_ID`; without it there is nothing to read. Optional. |
| `iterable_keys`, `provision`, `choose_target`, … | Not this skill's half — hand back to `iterable-provision`. |
| `done` | The push arrived. Say which push, on which device, how long after the send. |

## When the developer says nothing arrived and the check says it did

Both can be true, and the verdict is the thing that has to explain the difference.

Android bundles a second notification from the same app with the first and marks the
children `SILENT`: it arrives, the check sees it in the notification records, and the
screen shows no banner and makes no sound. The verdict appends `— SILENT, no banner`
when that is what happened, and states how long ago every arrival was. Read those
out. The remedy is to clear the notification shade and send again, not to doubt the
check.

The other honest answers, in order of how often they are the real one: the app was
never launched after install so no token exists; the app signs in as a different
address than `target.email`, so the token is filed under one identity and the proof
went to another; the push integration is set to "Notification messages" instead of
"Data notifications", so the Firebase SDK swallows it before Iterable's SDK sees it;
notification permission was denied (the verdict tells "denied" from "never asked").

## Never do these

- Never send again to turn a failing check into a passing one. If no push has
  arrived, the answer is why, not another attempt.
- Never report pending work as a failure, and never report an old arrival as a new
  one — the verdict states the age of what it found for exactly this reason.
- Never claim a gate passed because a build succeeded. A build is a weak signal in
  both directions: fabricated integrations compile, and correct ones fail.
- Never work around `unverifiable`. There is no endpoint; that is the finding.
