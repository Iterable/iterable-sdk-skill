---
name: iterable-ios-verify
description: >-
  Independently proves Iterable behavior on native iOS and the native iOS side
  of React Native apps. Use when a developer wants proof the integration works,
  when push is not arriving, or after an iOS integration is written. It
  combines live Iterable reads, Simulator or CoreDevice installed state, and
  separately observed device evidence. Verification never provisions, edits
  the app, operates its UI, or re-sends to manufacture a pass.
---

# Proving Iterable on iOS

## Finding the scripts

Start in the directory containing this `SKILL.md` and walk up to the first
directory containing `bin/ios-verify`; call that `<root>`. If you reach the
filesystem root without finding it, the install is incomplete—say so and stop.
Never reimplement a gate by hand: a check you improvise is one nobody has
tested.

Run the verifier first:

```text
<root>/bin/ios-verify status
```

When no proof run exists, `next.kind` is `prepare_proof` and `next.question`
already carries the proof screen: the detected bundle, the prefilled device
(a single eligible booted Simulator is selected for you; the developer still
sees and confirms it), and one free-text answer for the identity the app is
signed in with. Running the screen's command records the run. On a Simulator
its `next.command` is `ios-prove --confirm`; run it, then run
`ios-verify status` again. For an integrated, signed-in app on a booted
Simulator that is the whole path: four tool calls and one developer answer.

If the verifier says the workspace has no context at all, `ios-verify inspect`
reads the project without needing `.iterable/ios/`; a missing verification
workspace is not evidence that Iterable is missing from the app.

Do not run these from the plugin directory. `ios-verify` never edits the
project or workspace. `ios-prepare-proof` writes only ignored,
mode-restricted proof metadata; it does not enter Apple, APNs, Iterable app
provisioning, or application integration.

If inspection cannot find both the Iterable dependency and initialization,
report that boundary. Do not automatically replay the new-integration flow or
edit the app merely because the developer asked to verify it. Repair requires
an explicit request.

## Verification level

Normal integration and verification automatically use behavioral proof. Do
not ask the developer how the verifier should work or whether it may edit the
app. Behavioral proof treats the existing app as the product under test and
proves the existing identity, live Iterable device registration, the installed
application, and one API-targeted push that APNs delivered to the selected
device. On a Simulator it also proves that Iterable holds that Simulator's
current APNs token. It does not require a second user, a special build, app
edits, a relaunch, tap routing, logout, profile mutations, event mutations, or
callback journals.

Use instrumented proof only when the developer explicitly asks for a benchmark,
evaluation run, or callback-level diagnostics. Record that internal override
with:

```text
<root>/bin/ios-prepare-proof answer --field proof-mode --value instrumented
```

Instrumented proof requires the debug-only runtime-proof harness and can prove
callback ordering, exact APNs token correlation, identity restoration
internals, and logout callback ordering. Never add that harness during a normal
verification. If an explicitly instrumented artifact lacks it, rebuild the
evaluation artifact or restart as behavioral proof instead of repeatedly
launching the app.

## Reading the result

Each gate reports one of five statuses:

- **green**—proved by a read that would have failed if the state were wrong.
- **red**—a real defect. Something is broken.
- **pending**—the gate ran and the state has not happened yet. This is not a
  defect and must never be reported as the developer's mistake.
- **blocked**—a prerequisite is red, so this gate can say nothing true. Do not
  run it or comment on it.
- **unverifiable** (`~`)—no available read can honestly prove this state
  directly. It may still be proved indirectly by later runtime evidence.

Treat these as field values for branching, not labels to repeat to the
developer. Relay the gate's `detail` and the tool-authored `next` action. Act on
`next` and nothing else, one action at a time.

The verifier spends the Server-side Iterable credential live on every run with
an invalid control. It does not need or revalidate the app's Mobile key.
Provisioning owns Mobile-key validation before integration. A local
Server-side validation receipt is historical metadata only; it cannot make a
credential gate green after the key is revoked, replaced, or aimed at another
region.

When `next.kind` is:

| `next.kind` | What you do |
|---|---|
| `prepare_proof` | Show `next.question` (or run `ios-prepare-proof status` if it is null) and conduct it. The developer types the identity; the device is shown prefilled. If you built and installed the app in this session, append `--app-path <the .app you installed>` to the start command so the proof is tied to that build. Behavioral proof is automatic; do not add a proof-mode question. |
| `prove_push` | Run `ios-prove --confirm` exactly once, then re-run the verifier. It checks the device and Iterable first and sends nothing if a precondition fails, and it never sends twice for a run. On a Simulator it moves the app out of the foreground and reads the Simulator's own store and log. On a physical iPhone, first relay the summary: the developer leaves the app (Home Screen or Lock Screen) before the send. |
| `readback_code` | Physical iPhone only. Show `next.question`: the developer reads the six-character code from the Iterable iOS proof notification on the phone and types it; run its command with exactly what they typed (the command pipes the code in on stdin), or the "I do not see it" option. Never guess, derive, or retype a code yourself; the tool never shows it to you. Three wrong codes close the run. If the notification shows the literal text `{{proofCode}}`, Iterable did not merge the code: report that instead of a code. |
| `fix_apple_push` | Apple refused pushes for this app on this device (I13). Relay `next.summary`: it names the cause (App ID not enabled for Push on the team or a key restricted to other Bundle IDs, a Bundle ID mismatch, or a sandbox/production mismatch) with the Apple Developer pages and steps. After the developer fixes it, run `next.command` (`ios-verify check-apple`) to ask Apple again. Nothing was sent through Iterable. |
| `replace_apns_key` | APNs rejected the provider token signed with the imported key (wrong Key ID or Team ID, or a revoked key). Run `next.command` to open provisioning's replace-key screen. |
| `retry_apple_check` | Apple's APNs gave no usable answer (429, 5xx, or no network). Run `next.command` once to ask again; it is never retried automatically. |
| `review_delivery` | Stop and relay `next.summary`: it names what the Simulator's log shows (never reached the Simulator, suppressed by the app in the foreground, notifications not authorized, missing `aps-environment`, local injection, duplicate delivery). Nothing is resent. `next.command` restarts the run; offer it only after the developer has fixed the named cause and chooses to. |
| `restart_proof` | Run the exact `ios-prepare-proof restart --confirm` command. It archives the previous run and starts a fresh one with the same identity and device. Used for runs older than 24 hours and older payload contracts. |
| `review_rejected_send` | Iterable rejected the proof send (4xx), so nothing was sent. Relay the reported cause; the developer fixes it and decides whether to run `next.command` to start a fresh run. |
| `inspect_integration` | Run `ios-verify inspect`. Missing proof metadata is not a missing integration. |
| `server_key` | A fallback for an existing integration that did not run the current provisioning ladder. Hand back to `iterable-provision`; it captures and validates a Server-side key that never enters the app. |
| `validate_server` | Run the exact `ios-provision validate-server` command; the live Server-key check failed or the local receipt does not match. |
| `inspect_app` / `inspect_identity_logs` | Run the exact purpose-scoped `ios-observe inspect` command from `next.command`. It returns current accessibility or log state without writing proof. Binding the app may foreground it, but the actor never taps, types, grants permission, or navigates. |
| `run_app` | Relay the exact missing product action from `next.summary` (for example: open the app signed in on this Simulator so the SDK registers the current token). Do not repeat actions already visible or present in Iterable. |
| `review_app_error` / `review_identity_state` | Stop and relay the inspected error or identity state. Do not repeat login or consent. |
| `boot_device` | Run the exact `ios-device boot` command. A known Simulator that is shut down is pending tool work, not a defect. |
| `choose_device` | The recorded device cannot come back by retrying (runtime changed, deleted, unavailable). The developer boots or picks an eligible device; then run `ios-prepare-proof restart --confirm --device <udid>`. |
| `unsupported_host` | Relay the summary: this Mac cannot receive real APNs pushes in a Simulator. Retrying will not change it. |
| `repair_device_connection` / `retry_device_read` | The device inventory was unreadable. Repair the connection as the summary says; `retry_device_read` re-runs the verifier once. |
| `build_app` | Build first and record the resulting exact `.app` path. `ios-install` never builds. |
| `install_app` | Run `ios-install` for the already-built exact `.app`, then re-run. |
| `prepare_delivery` / `prepare_delivery_b` | Physical iPhone or instrumented run only. Run the exact purpose-scoped SpringBoard inspection from `next.command`. |
| `deliver_user_a` / `deliver_user_b` | Physical iPhone or instrumented run only. Announce the exact identity and marker, then run the exact confirmed `ios-deliver target` command. |
| `observe_user_targeted` / `retry_delivery_observation` / `observe_user_b` | Physical iPhone or instrumented run only. Run the exact `ios-observe delivery` command without resending. |
| `inspect_delivery` / `inspect_delivery_logs` | Physical iPhone or instrumented run only. Run the exact diagnostic command; these never authorize another send. |
| `review_send_manifest` | Stop: the send manifest is invalid or incomplete. Do not send again until the run is reviewed or restarted. |
| `launch_app` / `restore_app` | Instrumented run only. Run the exact `ios-launch` command, then re-run. |
| `observe_tap` / `observe_logout` / `review_instrumentation` | Instrumented run only. The developer performs the recorded tap or logout; `review_instrumentation` reports missing journal evidence without repeating a UI action. |
| `done` | Relay `proof_mode`, environment, `verified_features`, `feature_evidence_required`, `verification_limitations`, `integration_complete`, and every green proof boundary. If `integration_complete` is false, say “core verification complete; selected feature proof remains,” not “integration complete.” A development result does not claim TestFlight or production proof. Relay the JSON's `notice` field verbatim alongside the proof. |

`ios-verify inspect` may also return `review_integration` when the project does
not show both the Iterable dependency and initialization; report that boundary.

On a Simulator, `ios-prove` is the one actor that sends. It records the send
intent before the request, sends once through Iterable's proof API with a
payload carrying the run's marker and a fresh nonce (never the user's
identity), and waits for the Simulator to record it. It requires the Simulator
`apsd` line that received the payload with this run's nonce, the very next
SpringBoard request for the exact bundle, iOS saving that notification, and the
stored record whose identifier digests to that request. Lines count only from
the operating system's own `apsd` and SpringBoard images and only for the exact
bundle. It rejects a record that was added locally (`simctl push` or an
app-scheduled notification), a marker that arrives with any other nonce, and a
redacted payload, which is unverifiable rather than matched by time. Only nonce
and token hashes are written, in mode-`0600` files. `ios-verify` does not trust
that receipt: it re-reads the same Simulator store and log itself, and after the
developer clears Notification Center it accepts only the full log chain
(received with this nonce, requested, saved, delivered).

On a physical iPhone and in instrumented runs, `ios-launch`, `ios-send`, and
`ios-observe` stay separate actors and `ios-deliver` sequences them: it waits
for a secure observer arm receipt before invoking the sender once.
`ios-observe inspect` non-interactively reads accessibility state and a
bounded, redacted relevant log tail, then caches a mode-`0600`, short-lived
summary scoped to the exact run and purpose. Binding a target may foreground it
and trigger normal lifecycle callbacks. The cache helps the verifier choose the
next action but is not proof. Observation never presses, clicks, fills, types,
accepts permission, navigates, or sends. A missing, stale, copied, wrong-device,
or wrong-environment receipt cannot pass.

The standard delivery proof matches Android: create a proof template through
Iterable's API, target the exact recorded identity, and independently observe
its generated marker on the selected device. Iterable's dashboard direct Test
Push is an optional troubleshooting control for separating APNs setup from
identity-to-device association. It never blocks normal proof and the agent must
not send the developer to the dashboard merely because verification started.

Before requesting any manual app action, use the exact purpose-scoped
non-interactive inspection command emitted by the verifier, for example:

```text
<root>/bin/ios-observe inspect --kind app --purpose identity
<root>/bin/ios-observe inspect --kind app --purpose registration
```

Do not reuse an identity inspection for notification registration. These
caches expire quickly and are deliberately purpose-specific.

Accessibility and logs are evidence, not permission to guess. If the app's
visible state is ambiguous, state what was observed and ask only for the one
missing product action. Never ask the developer to log in when the exact user
already exists remotely and the app is visibly past its identification screen.

An event count above the recorded expectation is a contaminated run, not an
immediate integration defect. The verifier cannot distinguish repeated manual
actions from duplicate SDK tracking after both have reached Iterable. Restart
the proof with fresh identities before reviewing app code.

## Simulator and physical-device artifacts

Treat Simulator and physical-device entitlements as different artifact
formats:

- Xcode normally ad-hoc signs Simulator applications. An empty result from
  `codesign -d --entitlements` is expected and does not mean Push Notifications
  is missing.
- For an `IOSSIMULATOR` artifact, the verifier reads Xcode's simulated
  entitlements from the executable's `__TEXT,__entitlements` section. It
  requires a matching `application-identifier` and
  `aps-environment=development`.
- For an `IOS` physical-device artifact, the verifier reads the code-signature
  entitlements and requires `aps-environment` to match the recorded
  development or production environment.

Never add entitlements to a Simulator's code-signature blob, require an Apple
Development certificate for a Simulator build, or redirect a valid development
proof to a physical iPhone because the code-signature entitlement dictionary is
empty. Real APNs sandbox delivery remains available on an eligible iOS 16+
Simulator. Production and TestFlight proof require a physical iPhone.

When the workspace holds the imported APNs key, a standard Simulator run first
asks Apple directly (gate I13, `ios-verify check-apple` at any time): one silent
`content-available` push to the app's real Simulator token, signed with that
key. SpringBoard drops it on the Simulator, so nothing appears. Iterable accepts
sends that APNs later refuses without saying why, so `ios-prove` runs the same
check before sending and refuses the Iterable send on anything but Apple's 200.
The answer is recorded in `observations/apple-check.json` as a diagnostic; it is
never counted as delivery and is not repeated within one call. It is not run on
a physical iPhone, where a silent push would wake the app.

On a physical iPhone, delivery is developer-observed: the push shows a code
that only the phone displays, the developer reads it back, and only a slow hash
of it is stored locally. The proof template holds only a `{{proofCode}}`
placeholder; the code itself travels in that one send's `dataFields` (Iterable's
proof API merges them per send) and is never written to the template or the
workspace. `ios-verify` requires this run's read-back record to show a match
that is neither closed nor exhausted; a receipt alone is not enough. `ios-prove readback` then tries `log collect --device-udid`
without elevated permissions; if the host refuses, corroboration is skipped and
reported, never escalated with `sudo`. When the log is readable it must show
exactly one alert push for the app, saved and delivered, or the run does not
count. `done` reports `verification_tier: developer-observed` and states that
the physical path has not been tested by the maintainers. Production APNs is
proved this way on a physical iPhone; a Simulator only reaches the sandbox.
On a Simulator, delivery is proved only from that
Simulator's own `apsd` receipt of this run's nonce together with the stored
notification it joins to. A successful send, local `simctl push` injection, a
banner on screen alone, an APNs callback, an app log, or a manually edited
proof table is not a substitute.
In instrumented mode, a targeted send must also cross the runtime journal with
the sender-generated delivery nonce hash and matching template identity; the
nonce itself is never persisted locally. Behavioral mode proves the visible
targeted delivery and remote user/device ownership without claiming tap
routing, callback ordering, or exact-token correlation.

Existing enabled notification authorization is valid. Do not uninstall the
app merely to recreate a permission prompt, and do not disable
`autoPushRegistration` solely to satisfy a verifier sequence. The required
ordering is User A and the matching APNs callback before the corresponding
Iterable registration; permission settings may be observed before or after
token registration.

## Saying what is outstanding

Lead with whose turn it is—`next.owner`, `human` or `tool`—then the step name
(`next.step`), `next.summary`, and `next.command` if there is one. Give the next
action a heading or quote block of its own; it does not belong as the fourth
bullet of a status list.

Keep the strong words for a real defect. Missing human access, an unselected
device, or an app that has not yet been launched is pending work, not a broken
integration.

## Never do these

- Never send again to turn a failing check into a passing one. If no push has
  arrived, the answer is why, not another attempt.
- Never report pending work as a failure, and never report an old arrival as a
  new one.
- Never claim a gate passed because a build succeeded. A build is a weak signal
  in both directions: fabricated integrations compile, and correct ones fail.
- Never force physical-device signing behavior onto a Simulator artifact.
- Never work around `unverifiable`; state the boundary and continue only with
  evidence the verifier accepts.
