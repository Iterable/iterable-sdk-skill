# Native iOS runtime proof contract

Use this contract for a full supervised verification run. It closes the gap
between “the source contains an Iterable call” and “the installed app with the
recorded bundle, version, and build executed that call during this proof.”

Copy `../assets/IterableRuntimeProof.swift` into the application target. Enable
it only in a dedicated evaluation build configuration:

```text
SWIFT_ACTIVE_COMPILATION_CONDITIONS = $(inherited) ITERABLE_RUNTIME_PROOF
```

Normal App Store builds compile the no-op branch. The active branch writes only
when the app was launched with a valid, unexpired `ITERABLE_PROOF_RUN_ID`.

## What it records

The file is append-only JSONL at:

```text
Library/Application Support/IterableProof/runs/<run-id>.jsonl
```

Every record is a fact about an invocation or callback. The journal does not
contain success conclusions such as `pushWorked` or `logoutWorked`.

It never records:

- Iterable API keys or JWTs;
- complete APNs tokens;
- email addresses or user IDs;
- arbitrary URLs, payloads, or error text.

Identity values are stored as a run-specific HMAC. APNs tokens, proof markers,
and sender-generated delivery nonces are stored as SHA-256 hashes. Error
diagnostics are restricted to a domain and numeric code.

## Required integration points

Call the typed methods beside the real application calls:

1. `applicationDidFinishLaunching(environment:)` from the app delegate.
2. `sdkInitializeReturned(...)` immediately after `IterableAPI.initialize`
   returns.
3. `identitySet(...)` immediately after `setEmail` or `setUserId`, with source
   `login` or `restore`.
4. `notificationSettingsObserved(...)` after reading current settings.
5. `notificationAuthorizationCallback(...)` after the permission callback,
   followed by another settings read.
6. `apnsRegistrationCallback(token:)` in Apple's registration callback.
7. `iterableRegisterInvoked(token:)` beside `IterableAPI.register(token:)`.
8. The three response methods around the real notification callback,
   Iterable forwarding call, and completion callback. Pass
   `userInfo["iterableProofNonce"]` as `deliveryNonce`; never persist or log the
   raw value.
9. `localPersonalizedStateCleared(...)` after the app has cleared User A state
   and pending routes, before `logoutInvoked(...)`.
10. `identitySet(...)` for User B after the new app session is accepted.

Keep the journal call next to the fact it describes. Do not create a helper
that writes all expected records without executing the corresponding app
behavior.

The numbered list is a coverage checklist, not a total runtime order.
`IterableAPI.register(token:)` must follow both User A identification and the
matching APNs token callback. Notification authorization is independent:

- an already-authorized app may observe enabled settings without receiving a
  new authorization callback;
- APNs may return a token before or after the app reads notification settings;
- the SDK's default `autoPushRegistration = true` is valid and must not be
  disabled solely to satisfy the proof harness.

Do not uninstall the app merely to recreate the notification prompt. Existing
enabled authorization is valid evidence. If permission is denied, let the
developer change it in iOS Settings or record that visible notifications are
blocked; the verifier must not manufacture a first-run permission state.

## Launch and retrieval

`bin/ios-launch` starts the selected app with a short-lived run ID:

```text
<root>/bin/ios-launch --phase initial
<root>/bin/ios-launch --phase restore
```

The first launch proves initialization and the explicit User A login. The
second terminates and relaunches the process so restored identity cannot be
confused with state left in memory.

The evaluation helper persists only the non-secret run ID, phase, and expiry in
`Library/Application Support/IterableProof/active-run.json`. This lets a later
notification-driven cold launch stay attached to the same run after the
tool-started process exits. Expired context is ignored. Normal builds compile
the no-op branch and never create this file.

For an Xcode-installed physical app, `ios-verify` retrieves the file through:

```text
xcrun devicectl device copy from \
  --device <device> \
  --domain-type appDataContainer \
  --domain-identifier <bundle-id> \
  --source "Library/Application Support/IterableProof/runs/<run-id>.jsonl"
```

For a booted Simulator, it reads the same relative path from the app data
container. On macOS 13+ with Xcode 14+, Apple silicon or a T2 Mac, and an iOS
16+ runtime, the Simulator can register with and receive from the APNs sandbox.
The verifier records this as development proof only. Production/TestFlight
still requires a physical iPhone.

Container access is expected for qualifying apps installed through Xcode. Do
not assume an ordinary TestFlight install exposes its app data container. A
development or Xcode-installed Release result does not become a TestFlight
result.

## Independent correlation

The journal and local actor receipts are evidence sources, not cryptographic
attestations against a process that can freely rewrite the developer's
filesystem. They are designed to prevent accidental, stale, wrong-run, and
wrong-device false greens. The independent remote and visible checks remain
essential:

- live Mobile-key validation and fresh remote identity creation corroborate
  initialization and identity;
- the signed artifact and installed version corroborate the recorded app
  lifecycle;
- the runtime APNs-token hash must match Iterable's documented
  `devices[].token` value for registration and User A/User B ownership checks;
- the exact sender manifest, private delivery nonce hash, matching template
  identity, and visible marker corroborate targeted push callbacks;
- remote User A disablement, User B enablement, and a marked User B send
  corroborate logout and account switching.

The verifier remains read-only. The launch, send, and observation actors
produce the state it later reads.
