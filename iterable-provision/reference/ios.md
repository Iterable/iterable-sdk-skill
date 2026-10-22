# Provisioning Iterable push for native iOS

Use this path when the app is missing Apple, APNs, or Iterable prerequisites.
The app integration remains owned by `iterable-ios`; this path owns only the
external setup and the evidence about it.

## What the tool does and does not do

`<root>/bin/ios-provision` provides read-only status, tool-authored screens,
the recorded Apple setup handoff, APNs-key import and validation, an optional
App Store Connect Team-key path, and secure Iterable key capture and
validation. It needs only `node`, `curl`, `xcodebuild`, `openssl`, and
`plutil`.

The tool never signs in to an Apple account. On the existing and guided
paths, an Account Holder or Admin completes the Apple Developer steps in their
own browser and the tool records what they read back as developer-confirmed.
With an App Store Connect Team API key, the tool calls the App Store Connect
API itself, after showing the exact plan. Every imported APNs key is checked
with one probe to the APNs sandbox. The developer also performs the Iterable
dashboard clicks in their own browser, following one exact tool-authored step
at a time. The native iOS path does not use Playwright, a browser agent, or
`web-operator`.

Think of Apple push readiness as separate layers:

| Layer | What must match | Who or what completes it |
| --- | --- | --- |
| Account access | Apple team, role, and Certificates, Identifiers & Profiles access | Account Holder or Admin grants access |
| App identity | Explicit Bundle ID | `ios-provision` reads it from the app's build settings; the account owner confirms the App ID exists |
| App service | Push Notifications enabled for that Bundle ID | Account Holder or Admin enables it in Apple Developer and reads it back |
| App artifact | Simulator: Xcode simulated `application-identifier` and development `aps-environment`; physical device: selected team, provisioning profile, and code-signature `aps-environment` | Xcode and the app's existing signing workflow |
| Provider credential | Team-scoped APNs authentication key, Key ID, Team ID, and retained `.p8` | Account Holder or Admin creates/reuses it; the tool imports its path |
| Iterable configuration | Matching iOS mobile app, exact Bundle ID, and APNs credential | Developer follows the guided Iterable dashboard step |
| Runtime proof | APNs token, Iterable device registration, direct delivery, and user-targeted delivery | Eligible Simulator or physical device plus the verifier |

An app that already receives push may already have the app identity, app
service, signing, and provider credential layers. Inspect and reuse those
resources; adding Iterable does not inherently require a new Bundle ID,
capability, APNs key, certificate, or provisioning profile. A new APNs key is
needed only when the organization cannot or should not reuse a retained,
suitable key.

Apple exposes no public API for creating or downloading an APNs authentication
key, so creating one is a one-time human step in Apple Developer. The `.p8`
download is a one-time secret and must not enter chat, logs, traces,
screenshots, or Git; only its file path moves through the conversation.

## Find the program

Starting in the directory containing this file, walk up to the first directory
containing `bin/ios-provision`; call it `<root>`. Run every command from the
developer's iOS app directory. The ignored workspace is
`.iterable/ios/` in that app.

## Conduct the flow

### 1. Record the integration scope before editing

Run the local-only status from the app:

```text
<root>/bin/ios-provision status
```

It inspects local tools, the app's build settings, and the ignored local
workspace. It makes no Apple or Iterable request. Do not pass a guessed
`--bundle-id`: when push is selected, the `choose_bundle` screen reads the
Bundle ID and product name from the app target and records them only when the
developer confirms. Passing `--bundle-id` does not skip that screen; the
target is complete only once `.iterable/ios/target.json` records it.

Fresh status starts with the same grouped scope shape as Android:
**Push notifications**, **Events + user profiles**, **Deep links** (universal
links and custom URL schemes, including links opened from push and in-app),
and **More features**. Use the selector's `initialization only` free-text path
for basic initialization and identification without optional capabilities.
Selecting **More features** opens one additional multi-select for custom in-app
behavior, Mobile Inbox, and Embedded Messages. Initialization,
identification, and the default Iterable in-app message display are included
automatically. Identity, region, JWT policy, and final confirmation follow.

The app's skill asks the scope once, in its Step 0: `iterable-ios` for a
native app, `iterable-react-native` for React Native or Expo. It passes the
confirmed answers to the first `status` call, and the tool does not ask them
again:

- `--features` takes comma-separated ids, exactly the ones `choose_features`
  and `choose_more_features` record: `push-notifications`, `event-tracking`,
  `user-profiles`, `deep-linking`, `in-app-messages`, `mobile-inbox`,
  `embedded-messaging`, or `sdk-initialization` alone for initialization only.
- `--identity` takes `email`, `user-id`, or `unknown-user`, the values
  `choose_identity` records.

Any other value exits 2 before anything is written, and `status` itself only
reads the flags. With no Android setup to import, `next` is one `carry_scope`
screen, for example "Confirmed in the iOS skill: features push-notifications,
sdk-initialization; identity user-id."

- **Use these answers** runs `carry-scope --confirm` with exactly the answers
  shown. It records them as proposed answers, with `scope_source` (features)
  and `identity_source` (identity) set to `ios-step0`, or `react-native-step0`
  for a React Native or Expo app. The `choose_features`,
  `choose_more_features`, and `choose_identity` screens are then skipped.
- **Change the answers** records the decline, and those screens are asked as
  usual.

Region, JWT, and `confirm_scope` follow. `confirm_scope` marks each carried
line with its origin, and `record-scope` keeps both sources in `scope.json`.
A later `answer` to a carried field drops that field's source. Without the
flags nothing changes.

When the Android program already ran for this app (its `.iterable/.env` holds
a Mobile key), fresh status first asks `import_android`. Its recommended
option runs `import-from-android --confirm`. One Mobile key and one
Server-side key serve both platforms, so it reuses them with the Android
region and No JWT (the Android flow requires Require JWT off). It never prints
them, and both keys are still validated again for iOS. The Android setup
records no feature scope, so the Step 0 flags go with the import instead of a
`carry_scope` screen. The `import_android` screen names them, and its
recommended option passes the same `--features` and `--identity` to
`import-from-android`, which records them as `carry-scope` would. A carried
identity takes precedence over the Android test email. Without the flags the
feature questions follow as usual. **Set up iOS separately** asks everything
again. In a monorepo the Android workspace sits
at the repository root, so the search walks up from the app root to the git
toplevel, takes the nearest `.iterable/.env`, and records that path as
`iterable.imported_from`. Android package auto-detection does not support
monorepos yet: there the developer types the package name.

Each question has the same core fields as the Android conducted workflow:

- `context`, `header`, and `prompt` are developer-facing words;
- `selection` is `multiple` for feature scope and `single` for independent
  choices such as identity, region, and JWT policy;
- `before_commands` run once before recording the current selection;
- each option supplies `label`, `description`, `effect`, `commands`, and
  `relay`;
- `free_text`, when present, is the validated escape hatch for a value the
  listed options cannot express. Its `command` already single-quotes
  `'{{answer}}'`: replace the placeholder with the developer's text and write
  any single quote in it as `'\''`, so a multi-word answer such as
  `initialization only` stays one argument. Never use it for a secret.

Every screen that asks for something the developer may not have yet — a
Mobile or Server-side key, the JWT setting, the Bundle ID, the App ID, Push
Notifications, the APNs `.p8`, the Iterable app or its push credential, the
region, or a test user — offers an answer from the developer's side ("I don't
have … yet", "I'm not sure …", "Help me …"). It runs a command: it records the
safe default (for JWT, No JWT) or opens a `question --kind help_…` guide with
the common blockers, the URLs, and answers that record the result or return to
`status`. The Mobile- and Server-side key screens also offer **I already have
a … key — show me how to copy it** next to creating one. A relay option always
carries its own steps or command, and every "Show …" option shows something. Render a screen printed by an option command
like any other.

Render the question with the host's selector UI. In Claude Code,
`AskUserQuestion` has no field for `context`: in the same turn, first print
the `context` as a normal Markdown message, preserving every line, blank line,
numbered step, and URL, then call `AskUserQuestion`. Never call it for a
screen whose `context` you have not printed. Every link, numbered step, value,
summary, and list of what is being approved that a screen needs is in its
`prompt`, steps first and the question last, so the selector alone still says
what to do; pass the whole `prompt`, line breaks included. `context` holds only
background notes. Map
`header`, `prompt`, and each option's `label` and `description` directly into
the selector. Do not add, remove, reword, or reorder options, pick a
recommendation for the developer, collapse the content into one paragraph, or
replace the options with an open-ended request for a reply. If the host has no
compatible selector, preserve the context as Markdown and list each option on
its own line.

For credential screens, show the complete context before the selector. Explain
what component is being configured and what the credential enables before
listing the required values. Keep similarly named credentials distinct: the
Mobile key, the Server-side key, and the APNs authentication key are three
different secrets.

The final `confirm_scope` question records the proposed choices:

```text
<root>/bin/ios-provision record-scope --from-answers --confirm
```

Do not compose that command with guessed values. Until its option is selected,
the partial answers in `.iterable/ios/discovery.json` are proposed rather than
confirmed. The confirmation replaces them with `.iterable/ios/scope.json`.

App inspection still needs to resolve the exact identity source, permitted
profile fields and event names, local personalized-data ownership on logout,
notification permission timing, and routing policy. Prefer selectors for
bounded product decisions and free text only for custom values.

The confirmed scope contains only non-secret decisions and is mode `0600`.
Re-run status and follow its next state.

The commands are not independent escape hatches. Run only the current
`next.command` or commands attached to the option the developer selected.
`capture-mobile` and `validate-mobile` deliberately refuse while an earlier
Apple or APNs gate is next. Do not begin app wiring in parallel while the
provisioning sequence is incomplete.

`choose_bundle` reads `xcodebuild -showBuildSettings -json` for the app's
single `.xcodeproj`, keeps only iOS application targets (extensions and tests
are ignored), and offers the one it finds with its `PRODUCT_NAME`. Without a
readable Xcode project it falls back to `project.yml` or `project.pbxproj`.
If the app has multiple application targets, build configurations, or
white-label bundle identifiers, no target is offered: the developer names the
exact Bundle ID in the free-text answer and `record-target` reads that
target's product name. There is no placeholder app name; if none can be read,
`record-target` refuses and asks for `--name`. Do not provision every
identifier and do not silently choose the Debug value.

Required tools:

- Xcode command-line tools (`xcodebuild`);
- Node;
- `curl`.

When one is missing, status returns `install_tools`. Its screen names each
missing tool and how to install it, relays the installation to the developer,
and offers **Check again**, which re-runs status. Do not install missing tools
without the developer's request.

### Provisioning order

Follow the same dependency order as Android. For a push-selected scope,
`ios-provision status` completes the platform provider first:

1. confirm the exact Bundle ID and product name read from the app target;
2. choose existing or guided-manual Apple setup;
3. the account owner confirms the App ID, Push Notifications capability, and
   signing refresh in Apple Developer;
4. create or reuse the APNs authentication key and import its `.p8` path;
5. capture and validate the Iterable Mobile API key;
6. capture and validate the separate Server-side verification key;
7. configure the matching Iterable iOS app and upload the APNs credential;
8. return to application integration and independent delivery proof.

This order prevents an Iterable project from being configured against an
unknown or incomplete Apple push identity. A non-push scope skips Apple and
APNs and goes directly to the Mobile API key.

The sections below document each gate in detail. Their section number is not
the runtime order; always follow the single `next` action returned by
`ios-provision status`.

### 2. Configure the core Iterable project and Mobile API key

Every Iterable integration requires a real client-side Mobile API key, not only
push integrations. For push, this gate appears only after Apple and APNs are
ready. At `configure_iterable`, the developer chooses whether the
guided dashboard navigation, the terminal handoff, or an already copied key
supplies this prerequisite. The guided path matches Android: the coding agent
shows one tool-authored step, the developer performs the browser clicks, and
the selected option advances or captures the result. No browser agent operates
the Iterable project.

If the developer does not know the project region, render **Show me where to
check** and guide them to inspect the dashboard domain.

`choose_jwt` comes before any Mobile key exists: the key is created or picked
in the later Mobile-key step, and its Require JWT setting must match this
answer. Its recommended option is **No JWT**, because JWT is only for an app
that already runs a backend issuing user-specific Iterable JWTs. A developer
who already has a Mobile key selects **I already have a Mobile key — check its
setting**, which opens `check_jwt`: the region's API Keys URL, where to read
Require JWT, and an answer for on or off. It can be shown again or left to
return to `choose_jwt`. These paths resolve missing knowledge without asking
the developer to invent it.

The Mobile-key step includes the exact project host, key type, recorded JWT
choice, and copy action. After the developer copies the key, its capture option
runs:

```text
<root>/bin/ios-provision capture-mobile \
  --region US|EU \
  --jwt-enabled true|false \
  --confirm
```

The command requires values matching `scope.json`, moves the key from the
clipboard into `.iterable/ios/.env`, generates
`.iterable/ios/IterableSecrets.xcconfig`, restricts both files to mode `0600`,
and clears the clipboard. It never prints the key.

Where the key goes follows the app's framework, read from `package.json` and
`app.json` at the app root. Bare React Native gets
`.iterable/rn/iterable.local.ts` instead of the xcconfig: it exports
`ITERABLE_API_KEY` inside the self-ignoring workspace, and the app loads it
with an optional `require` in `try`/`catch`, because a static import breaks
fresh clones and CI. Expo gets `EXPO_PUBLIC_ITERABLE_API_KEY` in `.env.local`,
written only when git ignores that file; otherwise status returns
`fix_expo_gitignore` before any key is written. If the delivered file goes
missing, status returns `deliver_mobile_key`, which rewrites it from the
workspace.

Next, prove that the value is a Mobile key for the recorded region:

```text
<root>/bin/ios-provision validate-mobile
```

The probe sends an empty body to the device-registration endpoint, so an
authenticated key is rejected as an invalid request without registering a
device. It repeats the request with a deliberately invalid control key. For a
JWT-protected key, the real key must produce the JWT-specific rejection that
the invalid control does not. A Server-side key can pass that probe too, so a
third request reads `GET /api/channels` with the captured key. A Mobile key
gets HTTP 401 with `API key has insufficient privileges`; HTTP 200 means a
Server-side key was pasted into the Mobile slot; any other answer leaves the
key unvalidated. The receipt stores only a SHA-256 fingerprint, region,
JWT policy, and classification. The same key in both slots invalidates both.

A rejected key writes a rejection receipt for that fingerprint, and status
returns `replace_mobile_key`. Its recommended option copies the correct key
and runs `capture-mobile --replace --region US|EU --jwt-enabled true|false
--confirm`, which keeps the Server-side key and regenerates the xcconfig. Do
not loop on `validate-mobile`.

Immediately afterward, the state machine presents a second guided API-key
screen. Create and copy a dedicated Server-side key, then run the option's
commands:

```text
<root>/bin/ios-provision capture-server --confirm
<root>/bin/ios-provision validate-server
```

This key remains only in the ignored mode-`0600` provisioning workspace. It
never enters the iOS app or Xcode configuration. The verifier uses it for
remote profile and device reads, and the sender uses it only for announced
proof sends. Capturing it here means the later verification flow can start
without sending the developer back through Iterable credential setup.

`validate-server` may run at any point once a key is captured, including after
setup when the verifier finds it no longer works. A rejected or rotated key
routes to `replace_server_key`, whose option runs
`capture-server --replace --confirm`; plain `capture-server` never overwrites
an existing key.

If JWT is enabled, the backend endpoint that returns a user-specific JWT must
exist before the app can be described as working. Never generate that JWT in
the iOS app.

A dependency, an empty build setting, and code that skips initialization are
scaffolding. If the developer cannot access Iterable or chooses to stop, say
that Iterable did not initialize or communicate with the project.

### 3. Take the non-push branch when Apple is not needed

After secure Mobile- and Server-side-key capture and validation, a scope
without `push-notifications` returns
`integrate_app`. Return to `iterable-ios`, wire only the selected features, run
the app, and confirm the exact test identity and selected event/profile behavior
in Iterable.

Do not require an Apple Bundle ID change, an APNs key, or an Iterable
mobile-app push configuration for an identity/events-only integration.

### 4. Choose the Apple setup strategy for push

After the exact target is recorded, render the `choose_apple_setup` selector.
Do not infer the path from the Apple role or an existing credential:

- **Use existing setup** when the app already has the exact Bundle ID, Push
  Notifications capability, signing workflow, and ownership of a suitable
  retained APNs key. The developer reads those values back before the tool
  records them.
- **Guide manual setup** when the App ID, Push Notifications capability, or
  APNs key still has to be set up in Apple Developer. Its first screen,
  `confirm_manual_apple`, recommends **Walk me through it**
  (`record-apple-step --step start --confirm`), which shows one step per
  screen, each with the exact portal clicks:
  1. `apple_step_app_id` — register the explicit App ID under Identifiers
     (+ → App IDs → App, Explicit Bundle ID, Description = product name). A
     Simulator-only build does not make Xcode register it, so for a new app it
     is usually missing;
  2. `apple_step_push` — tick Push Notifications on that App ID, Save,
     Confirm, and read it back;
  3. `apple_step_apns_key` — reuse a team APNs key whose `.p8` is still held
     (one key covers every app on the team), or create one and download its
     `.p8` once, outside the repository.

  Each answer runs `record-apple-step --step app-id|push|apns-key --confirm`;
  progress is kept in `.iterable/ios/apple-guide.json`, so the walkthrough
  resumes where it stopped and cannot skip a step. The last answer records
  readiness and hands off to `import_apns`. **Record manual setup** stays on
  the first screen for a team whose Account Holder or Admin already did all
  three.
- **I have an App Store Connect Team API key (Admin) — set up the App ID and
  Push for me** when the developer holds a Team key with Admin or App Manager
  access. It is never recommended by default. Individual keys cannot use the
  provisioning endpoints. The flow is:
  1. `asc_key` asks for the path to the App Store Connect key's
     `AuthKey_<KEYID>.p8`. That file has the same name pattern as the APNs key,
     so the screen says which key it wants. The Key ID comes from the file
     name. The path is kept in `.iterable/ios/asc-key.json` (mode `0600`); the
     key is restricted to `0600` and never copied.
  2. `asc_issuer` asks for the Issuer ID shown above the Team Keys list at
     https://appstoreconnect.apple.com/access/integrations/api.
  3. `asc-read` (a tool step) signs an ES256 token with the key and reads
     `GET /v1/bundleIds?filter[identifier]=<bundle>` and, when the App ID
     exists, its `bundleIdCapabilities`. It changes nothing. When the App ID
     already has Push Notifications, readiness is recorded at once.
  4. `asc_plan` shows exactly what will be created: the explicit App ID
     (`POST /v1/bundleIds`, platform `IOS`) and/or Push Notifications
     (`POST /v1/bundleIdCapabilities`). **Apply this plan** runs
     `asc-apply --confirm`, which re-reads first and refuses if App Store
     Connect changed, then writes and reads the result back.
  5. The result is `apple-readiness.json` with `strategy: team-key`,
     `evidence_level: tool_verified`, and `tool_checks` for the registered
     App ID and Push Notifications. Signing and profiles are not checked.
  6. The APNs key has no public API, so `apple_step_apns_key` and
     `import_apns` follow as on the guided path.

  A 401 or 403 routes to `asc_rejected` (wrong key, Issuer ID, revoked key,
  or a key without Team Admin/App Manager access). A 409 when creating the App
  ID routes to `asc_conflict`, where another team owns the identifier. Both
  screens offer a help answer and a switch to the guided walkthrough. Network
  or other answers are inconclusive: nothing is recorded and the step can be
  retried. The token travels on curl's stdin and is never printed.

Apple documents App ID registration, capability changes, and APNs key creation
as Account Holder or Admin operations. Enabling a capability can invalidate
provisioning profiles that use the App ID; let Xcode automatic signing refresh
the profile, or follow the application's existing manual-signing process.

The selected strategy is stored in `.iterable/ios/apple-setup.json`. The
read-back is stored in `.iterable/ios/apple-readiness.json` with
`evidence_level: developer_observed`, `tool_verified: false`, and
`developer_confirmed` fields for the explicit Bundle ID, Push Notifications
capability, signing refresh, and APNs-key owner. These are the developer's
statements, not tool checks. Changing the recorded Bundle ID removes
incompatible target-bound local Apple, APNs, Iterable push, and proof state. It
does not change Apple or delete the retained `.p8`.

### 5. Create or reuse the APNs authentication key

An Account Holder or Admin performs the one-time Apple Developer portal step:

1. Open **Certificates, Identifiers & Profiles > Keys**.
2. Prefer an existing suitable team-scoped APNs key when organizational policy
   allows it **and the organization retained its one-time `.p8` download**.
3. If creating one, enable Apple Push Notification service and select the
   intended scope/environment.
4. Record its Key ID and Team ID.
5. Download its `.p8` once and place it outside the repository.

Apple limits active APNs keys. Creating or revoking one is a separate,
explicit decision for the account owner.

The `import_apns` screen asks for the absolute path to the downloaded
`AuthKey_<KEYID>.p8` as its free-text answer and runs:

```text
<root>/bin/ios-provision import-apns --file '<path>' [--team-id <team-id>] --confirm
```

The Key ID comes from the `AuthKey_<KEYID>.p8` file name and the Team ID from
the app target's `DEVELOPMENT_TEAM`; the screen shows the Team ID it will use.
Only the path enters the conversation, never the file contents. When the file
was renamed, `DEVELOPMENT_TEAM` is unreadable, or the key belongs to a
different team, the terminal option relays the full command with explicit
`--key-id` and `--team-id`.

The importer validates the EC P-256 private-key shape, restricts the source
file to mode `0600`, and records its path and public metadata in the ignored
workspace. It does not duplicate the team-wide private key. It refuses to
replace a different recorded path unless the replace step runs it with
`--replace`.

Next comes `validate_apns`, a tool step:

```text
<root>/bin/ios-provision validate-apns
```

It signs an ES256 provider token with the key (header `kid` = Key ID, claim
`iss` = Team ID) and sends one alert to a random, never-issued device token in
the APNs sandbox over HTTP/2, with `apns-topic` set to the Bundle ID. The
token travels on curl's stdin and is never printed.

- `400 BadDeviceToken` means APNs accepted the provider token. That proves
  the key, Key ID, and Team ID, and writes `.iterable/ios/apns-validation.json`.
  Apple answers this way even for a Bundle ID that was never registered, so it
  says nothing about the App ID or its Push Notifications capability.
- `403 InvalidProviderToken` means the Key ID or Team ID is wrong, or the key
  was revoked. Status returns `replace_apns_key`, which re-imports the right
  `.p8` with `import-apns --replace`.
- `TopicDisallowed` or `BadTopic` means Apple accepted the key, Key ID, and
  Team ID but the key may not send to this Bundle ID, usually because it is a
  topic-restricted key without it. The receipt records `credentials_valid:
  true` with classification `apns-key-topic-not-allowed`, but the step is not
  done: `replace_apns_key` explains how to add the Bundle ID to the key's
  topics in Apple Developer → Keys and validate again, or how to re-import a
  Team Scoped key.
- Anything else, including a network failure, is inconclusive. Nothing is
  recorded, and `validate-apns` can be run again.

Only real delivery proves the credential works for this app.

### 6. Create the Iterable iOS app and configure APNs

Iterable has no public API for creating API keys, creating a mobile app, or
uploading an APNs credential. Guide the developer through the tool-authored
dashboard questions while they perform these operations in their own browser.
Do not assume the matching mobile app already exists and do not combine app
creation with credential configuration.

The first question is **Step 1 of 2 — Create the iOS mobile app**:

1. open the region-specific `/integrations/mobileApps/create` link;
2. check whether an iOS app with the exact Bundle ID already exists;
3. otherwise create it with the recorded product name, platform **iOS**, exact
   Bundle ID, and optional Store URL;
4. record whether it was `created` or `existing`.

The next question is **Step 2 of 2 — Add the APNs credential**:

1. open the region-specific `/integrations/mobileApps` link and select that
   exact app;
2. select **Add new credential**, choose **.p8 Auth Key**, and continue;
3. upload the absolute secure key path from `.iterable/ios/apns.json`;
4. enter the recorded Key ID, Team ID, and Bundle ID;
5. select **Update**, read the displayed values back, and then select
   **Configured and read back** in the tool-authored question.

If the app already uses a `.p12` certificate, use **Upload & Replace** instead
of deleting the existing credential.

Both completion records are dashboard observations, not delivery proof. The
later verifier still requires real Iterable-to-APNs delivery.

### 7. Return to the integration and prove the selected behavior

Once both API keys and any selected push prerequisites are available, return
to `iterable-ios` for application wiring and proof.

The generated `.iterable/ios/IterableSecrets.xcconfig` is the secure handoff to
Xcode. Include it from the app's committed base configuration using the correct
relative path; do not copy or print its value.
For React Native or Expo, the delivered module or `.env.local` is the handoff
instead.

Keep proof levels distinct:

- simulator build, launch, permission UI, and `simctl push` are local
  injection proof only;
- a signed eligible iOS 16+ Simulator or physical iPhone can prove APNs
  sandbox token generation, Iterable device registration, and development
  delivery;
- an API-targeted proof push proves Iterable identity association, device
  registration, credential, environment, bundle, token, and APNs delivery;
- the dashboard's direct Test Push is optional diagnosis when identity
  association needs to be separated from the APNs path.

Simulator pitfalls seen in live runs:

- A Simulator needs the registered App ID too, with Push Notifications
  enabled. For a never-registered Bundle ID, or one without Push, APNs answers
  `400 TopicDisallowed` for every key on the team; Iterable still returns HTTP
  200 for the send, so nothing arrives and nothing says why (proven live: two
  keys both refused before Push was ticked, both accepted after).
  `ios-verify check-apple` asks Apple directly and names this.
  `DeviceTokenNotForTopic` instead means the push targeted a different Bundle
  ID than the app that registered the token.
- On a freshly booted Simulator, an app that calls
  `registerForRemoteNotifications` before `apsd` has connected can wait
  forever without a token. Relaunching does not help; uninstall and reinstall
  the app.
- Without notification authorization, `apsd` marks the app topic as ignored
  and nothing is shown. Provisional authorization grants it without a prompt.

No successful Apple or Iterable setup call proves that a notification arrived.
No successful build proves that the app initialized or contacted Iterable.
For every scope, confirm the test identity in Iterable. Confirm selected
events/profile fields remotely. Push additionally requires the eligible
Simulator or physical-device proof below.

Start the independent proof. Provisioning has already kept the Server-side key
out of the app and validated it:

```text
<root>/bin/ios-verify inspect
<root>/bin/ios-prepare-proof status
```

`ios-verify inspect` reads the existing app without replaying integration.
`ios-prepare-proof` automatically selects behavioral proof, then conducts one
tool-authored question at a time for Iterable region when it is not already
known, environment, identity type when it cannot be inferred, the app's
existing test identity, and the selected device. When the workspace knows a
build of the app — one an earlier run recorded, or a product under the app's
own `-derivedDataPath` — that carries the Iterable SDK, it asks which copy the
run tests and recommends binding that exact `.app` unless the installed copy
was built later; the installed app stays an option. Otherwise it reuses the
installed app and generates one targeted marker. The identity is typed: the
SDK keeps it in the Keychain and never logs it, and Iterable has no lookup by
device token, so the screen says where to read it, including a Simulator
debugger read of the running app.
For a new integration completed in the current flow, it also requires the
exact built `.app`, so installation and proof are linked to that artifact. Its
confirmation runs through the preparation actor; do not reconstruct the
underlying provisioning command from memory or add a proof-method question.

Behavioral proof requires no app edits. Instrumented proof is available only
when the developer explicitly requests an evaluation or callback-level
diagnostic run. It adds callback ordering, exact APNs-token correlation,
identity restoration internals, and logout callback ordering.

Standard proof uses the identity already active in the app. It does not create
fresh users or test logout/account switching. Development push can use a
booted, available iOS 16+ Simulator when the Mac meets Apple's host
requirements. Production/TestFlight requires a physical iPhone. When an exact
artifact is supplied for a new integration or instrumented benchmark, the signed physical-device
`.app`, or the ad-hoc-signed Simulator `.app`, must target the recorded device
type. The verifier reads `aps-environment` from code-signature entitlements for
a physical device and from Xcode's embedded simulated entitlements for a
Simulator.

`record-proof` generates one targeted marker and starts a fresh proof window;
it does not mark anything passed. Instrumented evaluation additionally uses
fresh User A/User B identities, an exact artifact, selected profile/event
expectations, tap and logout expectations, and a second targeted marker.

Only for an instrumented evaluation, copy
`iterable-ios/assets/IterableRuntimeProof.swift` into the evaluation target and
follow `iterable-ios/guides/runtime-proof.md`. Launch the installed app whose
bundle, version, and build match the recorded artifact:

```text
<root>/bin/ios-launch --phase initial
# Instrumented identity-restoration proof only:
<root>/bin/ios-launch --phase restore
```

Then hand off to `iterable-ios-verify`:

```text
<root>/bin/ios-verify status
```

The verifier re-authenticates the Server-side key live with an invalid control
on every run, reads the exact identity and device registration, confirms the
recorded app is installed and launched, and consumes only
observations scoped to the same bundle, device, environment, and run.
Instrumented mode additionally retrieves current-run facts from the app
container and requires sender-only nonce correlation in the app response
journal. A stale validation receipt, successful send response, local
`simctl push` notification presented as APNs delivery, or manually edited
checklist cannot complete the ladder.

If a recorded event count is higher than expected, restart the proof before
reviewing app code:

```text
<root>/bin/ios-prepare-proof restart --confirm
```

The verifier cannot distinguish a repeated manual action from duplicate event
tracking after both have reached Iterable.

Use the separate sender actor for user-targeted proof:

```text
<root>/bin/ios-observe inspect --kind notifications --purpose pre-send
<root>/bin/ios-send target --recipient initial --confirm
```

The sender enforces a fresh SpringBoard preparation receipt. It writes a
non-repeatable send intent before the delivery request, then finalizes it only
after a confirmed response. If the response is uncertain, the verifier may
still prove visible arrival of the exact marker but must never resend blindly.

For an instrumented logout/account-isolation benchmark, the second-user control
is:

```text
<root>/bin/ios-send target --recipient switch --confirm
```

After the matching notification is visible, use:

```text
<root>/bin/ios-observe delivery --kind user-targeted
```

Instrumented account isolation additionally uses:

```text
<root>/bin/ios-observe delivery --kind user-targeted-switch
```

Iterable's dashboard direct Test Push is optional diagnosis only. It has no
public send API and never blocks the standard proof. If the developer
explicitly performs it to separate APNs setup from identity association, the
actor can record only that the dashboard operation occurred with
`ios-send record-direct --confirm`; delivery must still be observed
independently.

The sender never verifies delivery. The observer never sends, taps, types,
accepts permission, or navigates.

## Current unavoidable human gates

- Apple Developer Program team access and role;
- legal agreements, login, and 2FA;
- Account Holder or Admin confirmation of the App ID, Push Notifications
  capability, and signing refresh;
- Account Holder or Admin help to create an APNs key when no suitable retained
  key can be reused, plus a secure place to retain a newly downloaded key;
- notification permission in the app;
- an eligible Simulator or physical iPhone for development APNs proof;
- a physical iPhone for production/TestFlight proof.

Stop at the first unmet gate and name exactly what is already proved. Missing
account access is not a defect in the app or the skill.
