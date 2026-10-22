---
name: iterable-react-native
description: >-
  Authoritative reference for the Iterable React Native SDK (npm
  `@iterable/react-native-sdk`) and, in Expo apps, the Iterable Expo config
  plugin (`@iterable/expo-plugin`). Use when integrating, configuring,
  debugging, or extending any Iterable feature in a React Native app — Expo
  or bare workflow — including push notifications, in-app messages, mobile
  inbox, embedded messaging, JWT authentication, deep links, event tracking,
  and user identity (setEmail / setUserId). Prefer this skill over the
  model's memory of Iterable APIs and over the Android/iOS skills: the JS
  surface is narrower than the native one, and native APIs are not reachable
  from JavaScript. Ships version-pinned snippets and known foot-guns that
  silently break integrations. When a prerequisite is missing rather than
  wrong — no `google-services.json`, no Iterable mobile API key, no
  configured push integration — that is `iterable-provision`, which creates
  and proves them; never fabricate one here. To prove a push actually reaches
  a device, use `iterable-android-verify` for an Android target or
  `iterable-ios-verify` for an iOS target.
---

# Iterable React Native SDK

You are working with the **Iterable React Native SDK** —
[`@iterable/react-native-sdk`](https://www.npmjs.com/package/@iterable/react-native-sdk).
It is a JavaScript layer over Iterable's native Android and iOS SDKs.
Iterable is a cross-channel marketing platform; this SDK is the React Native
entry point for push, in-app, inbox, embedded messages, event tracking, and
JWT-authenticated APIs. Expo apps also need
[`@iterable/expo-plugin`](https://www.npmjs.com/package/@iterable/expo-plugin)
for native configuration — that plugin is part of **this** skill, not a
separate one. The plugin owns `ios/` / `android/` setup; JavaScript init
is still `Iterable.initialize` from the RN SDK.

This skill is the **agent-facing source of truth**. The public docs at
[support.iterable.com](https://support.iterable.com) cover the same surface for
human readers but omit several silent-failure traps documented in
[`PITFALLS.md`](PITFALLS.md). When in doubt, this skill wins.

**Do not answer a React Native task with native Android or iOS SDK APIs as
though they were callable from JavaScript.** Kotlin `IterableApi.getInstance()`,
Swift `IterableAPI`, Gradle `com.iterable:iterableapi` method names, and
unguessed bridge methods are wrong here. Native *configuration* (FCM, APNs,
entitlements, `POST_NOTIFICATIONS`) is still part of a React Native
integration — it lives in this skill's own `reference/` docs, not in a
separate skill the developer must ask for.

**Read and search the project with your host's file tools** (in Claude Code,
Read, Grep and Glob), not shell `cat`, `grep` or `find`: each shell command can
cost the developer a permission prompt.

---

## Step 0 — Agree on scope BEFORE writing code

Do this **first**, before Preflight and before any edits.

**Detect the workflow from the project, do not ask which docs to use.**

- **Expo** if `app.json` / `app.config.js` / `app.config.ts` has an `expo`
  key, or the app depends on `expo`. Route native setup through
  `reference/expo.md`. Do not hand-edit `ios/` or `android/` as the primary
  path. If they already configure native code by hand, do **not** add
  `@iterable/expo-plugin` — say so and use `reference/installing.md` for
  native steps (pitfall #9).
- **Bare React Native** otherwise. Route native setup through
  `reference/installing.md` and the feature slugs (especially
  `push-notifications`). Do not introduce `@iterable/expo-plugin`.

Then ask which features they want. If your host exposes an interactive
multi-select question tool (in Claude Code, `AskUserQuestion` with
`multiSelect: true`; in Cursor, `AskQuestion` with `allow_multiple: true`),
use it and offer **at most 4 options**; otherwise ask in plain text:

- Push notifications (FCM / APNs)
- Event tracking + user profiles (identifying the user is always included)
- Deep links: iOS universal links, Android App Links, and custom URL schemes
- Other (inbox, embedded) — describe in the option

Each confirmed answer maps to one entry in `iterable-provision`'s feature ids,
which the iOS phase takes as `--features` (comma-separated):

| Step 0 answer | `--features` ids |
|---|---|
| Push notifications | `push-notifications` |
| Event tracking + user profiles | `event-tracking,user-profiles` |
| Deep links | `deep-linking` |
| Other: Mobile Inbox | `mobile-inbox` |
| Other: Embedded Messages | `embedded-messaging` |
| Other: custom in-app handling | `in-app-messages` |
| None of these (initialize and identify only) | `sdk-initialization` |

**In-app messages are absent from that list on purpose.** By default the SDK
displays every in-app message it receives and tracks the interactions
(`in-app-messages`), so an initialized, identified app has them whether or not
anybody asked. Say so when you hand over — they support in-app already, and will
see nothing until an in-app campaign exists in Iterable — rather than offering it
as a feature to opt into. Customizing the default (skipping, deferring, custom
rendering) is scope; having it is not.

**First check whether this is an upgrade, not a new integration.** If the
project already depends on `@iterable/react-native-sdk` (and, on Expo,
`@iterable/expo-plugin`), ask which version they're on and what they want
out of the upgrade, then follow the upgrade row in the
[decisions table](#decisions-read-before-recommending).

**And check whether the app already sends push without Iterable.** Look for
`@react-native-firebase/messaging` or another push SDK in `package.json`, and
for `FirebaseMessagingService` / `com.google.firebase.MESSAGING_EVENT` under
`android/`. If any is present, say what you found and ask: "Keep your app's own
notifications working alongside Iterable's, or use Iterable notifications
only?" **Keep both:** forward only Iterable payloads (rule 8). **Iterable
only:** propose, in the one diff they confirm, how the old provider stops
receiving or showing pushes. Don't delete the provider's code unless they
confirm that diff.

Confirm the scope, *then* run Preflight, *then* build.

### Identity: project type first

Ask which kind of Iterable project the app sends to, per
`project-types-and-unique-identifiers`:

- **Hybrid**: `email` and `userId` are both unique identifiers.
- **UserID-based**: `userId` only.
- **Email-based**: `email` only; limited availability (some older US-hosted
  organizations).
- **I don't have a project yet / I don't know — help me.**

For an existing project, also ask which identifier their backend, CRM, or other
SDKs already send to Iterable, and reuse exactly that value: another value is
another user. Decide from what a signed-in session holds, not what sign-up asks
for: an app that asks for an email only at sign-up has none to pass later.
**Help me** means inspect, then recommend: what identifier exists after *every*
sign-in path, a session restored at launch included, and what the app's other
SDKs already identify the user with. Recommend a project type and identity mode
from that, citing the docs in the table below. With no project yet, guide
creating one and warn that its type can't be changed later.

A `userId` is the app's own stable internal account ID when it meets
`user-id-validation-in-iterable` → `### User ID best practices`, otherwise a
random UUID created once per account and stored with it (kept only on the
device, a reinstall makes a new user). Never an email, phone number, username,
or handle, nothing built from them, and nothing sequential. That doc's
128-character limit supersedes `identifying-the-user`'s "52 characters" and its
"email recommended"; that doc's snippets are native, so the JS calls are in
`managing-user-identity`.

### Decisions: read before recommending

Before recommending an option for a decision below, open the named section and
cite it in the option ("per `user-id-validation-in-iterable`"). If no shipped
doc covers a decision, offer no recommendation and say so. Slugs are
`reference/<slug>.md`; a `../iterable-*/reference/` path is the sibling skill's
doc for a native step.

| Decision | Read |
|---|---|
| New integration or upgrade | `installing` → `## Upgrading the SDK`; `migrating` |
| Project type | `project-types-and-unique-identifiers` → `### Choosing a project type`, `#### Project type availability` |
| Identity mode, and which app value supplies it | `project-types-and-unique-identifiers` → `### Comparing project types`; `user-id-validation-in-iterable` → `### User ID best practices`; `managing-user-identity` |
| An existing client's identifier | `creating-users-with-apis` → `## Understanding user identification in API requests`; `updating-a-users-email-address` |
| Unknown users | `handling-anonymous-users`. No React Native doc covers Unknown User Activation: don't recommend it |
| Data region | `installing` → `### Step 6`; `european-data-center` → `## Signing in to Iterable: region-specific URLs` |
| Key type | `api-keys` → `### Selecting a key type`, `#### Mobile` |
| JWT | `api-keys` → `#### JWT authentication`; `jwt-enabled-api-keys`; `authentication` |
| Event creation | `api-keys` → `#### Event Creation` |
| FCM type | `../iterable-android/reference/setting-up-android-push-notifications` → `#### Step 3.3` |
| Push integration name | `installing` → `#### Step 4.2`, `### Step 6` |
| APNs auth, environment, Bundle ID | `installing` → `#### Step 3.5`; `../iterable-ios/reference/setting-up-ios-push-notifications` → `### Step 3`, `### Step 4` |
| Notification permission | `../iterable-ios/reference/ios-sdk` → `#### Step 7.6`; `../iterable-android/reference/setting-up-android-push-notifications` → `## Android 13: Push notification permissions`; Expo: `expo` |
| Existing push | `../iterable-android/reference/setting-up-android-push-notifications` → `#### Handling Firebase push messages and tokens` (Android; rule 8) |
| Deep links | `deep-links-and-custom-actions` |
| Profile fields | `user-profile-data-and-subscription-preferences`; `user-profile-fields-used-by-iterable` → `## Other reserved field names` |
| Events | `tracking-events` → `## Tracking custom events` |
| Logout | `managing-user-identity` → `## Signing out` |
| Test identity | `project-types-and-unique-identifiers` → `### Checking the unique identifier for a project`; `installing` → `### Step 7` |

### Two platforms: Android first, then iOS

When the scope covers both platforms, finish one before starting the other:

1. **Android:** provision with `iterable-provision`, integrate, and prove it —
   `iterable-android-verify` green — before any iOS work starts.
2. **iOS:** `iterable-provision`'s iOS path offers to reuse what the Android
   phase recorded — both Iterable keys (Mobile and Server-side), the region,
   No JWT, and the test email. Pass the scope confirmed in Step 0 as
   `--features <ids>` from the table above, first to `ios-provision status`,
   so the import screen names it, and its recommended option carries it into
   `import-from-android`. The final scope screen shows it again before
   anything is confirmed. Pass only what the developer confirmed; without
   `--features` the scope is asked again. The path then adds the Apple/APNs
   prerequisites. Then write the iOS native push code
   ([Bare iOS](#bare-ios-native-push-code)) and prove it with
   `iterable-ios-verify`.

An app is integrated when the verifier passes for **every platform in scope**;
one green platform is half an integration.

**After any rebuild, re-run that platform's verifier before asking the developer
to act again.** Its last answer was about the build you replaced.

---

## Definition of done — finish the agreed scope, don't stub it

Within the agreed scope, an integration is finished only when:

- [ ] The SDK is **actually initialized at runtime** —
  `Iterable.initialize(apiKey, config)` is **called from the host app**, not
  just defined in a helper nothing imports.
- [ ] The user is **identified** — `Iterable.setEmail` or `Iterable.setUserId`
  runs with a real value. If identity is a per-install UUID, **write the
  UUID-generation/persistence code**.
- [ ] Native configuration required by the agreed scope is done for the
  workflow you detected (Expo plugin vs bare `ios/` + `android/`), including
  push permission on Android 13+ and on iOS when push is in scope.
- [ ] Each platform in scope passed its verifier: `iterable-android-verify`,
  then `iterable-ios-verify` against a **Release** Simulator build (a Debug
  build loads JavaScript from Metro and shows a red box without it).

Only genuinely developer-supplied inputs (API key, identity model, region,
JWT, `google-services.json` / APNs key) are legitimate pauses.

### When you hand over the diff, say what it is

You wrote it, so you are the last one who should be vouching for it. Draw the line
between what has been proved and what has not:

> An AI agent wrote this code and configuration, and it can be wrong in ways that
> still compile and still pass every check here. What is proved is what a real call or
> a real push confirmed; everything else is a draft. Read the diff, run your own
> tests, and treat it like a pull request from somebody new to your codebase.

If `iterable-provision` is installed, its `bin/agent` carries this as a `notice`
field — relay that verbatim instead, so the tool and the conversation say the same
thing. Say it once, plainly, and never soften it into "I've double-checked
everything".

---

## Preflight — STOP and gather these before writing any code

> **Prefer selectable options over prose — every time.** Offer at most 4
> options per question on hosts that reject more.

| Input | Needed when | If missing |
|---|---|---|
| **Workflow** — Expo vs bare | Always | Detect from the project (Step 0). If both signals exist, ask. |
| **Mobile API key** | Always | Never hardcode it into a tracked file. `iterable-provision` writes the copy the app reads: bare RN `.iterable/rn/iterable.local.ts`, Expo `EXPO_PUBLIC_ITERABLE_API_KEY` in a gitignored `.env.local` ([loading it](#loading-the-key)). |
| **Identity model** — `setEmail` vs `setUserId`, and where the value comes from | Always | [Project type first](#identity-project-type-first). Never guess. |
| **JWT?** — is the mobile key JWT-protected? | Always | Ask, and **assume yes until told otherwise** (it is on by default for client-side keys and is permanent). If yes, `authHandler` is mandatory (rule 1) **and the team needs a backend endpoint that mints the tokens** — if they don't have one, raise it as a blocker instead of signing in the app. |
| **Data region** — US or EU | Always | Ask if they sign in at `app.eu.iterable.com` (`european-data-center`). See pitfall #2. |
| **`google-services.json`** (Firebase) | Android push (bare **or** Expo) | **Route into `iterable-provision`**, which downloads the real one; if it isn't installed, STOP and ask. Either way you cannot generate it. Expo: path goes in `expo.android.googleServicesFile`, not a hand-edited `android/`. |
| **APNs key / capabilities** | Push on iOS | Route into `iterable-provision`'s iOS path once Android is proven. Native code: [Bare iOS](#bare-ios-native-push-code); Expo: the plugin. |
| **Development build vs Expo Go** | Expo | Expo Go cannot run this SDK (pitfall #7). If they are in Expo Go, stop and move them to a development build before debugging JS. |

**Never fabricate a prerequisite to make the build pass.** Do not invent an
API key, a placeholder `google-services.json`, or a JWT signed in the client.

**A green build is not the deliverable.** The typical failure: the Firebase project has
no app registered, so there is no real `google-services.json`, and the work carries on
anyway, makes it compile, and ends the turn without naming a way forward. Instead, a
missing prerequisite stops the push work *before* the native edit, and you say
which parts of the agreed scope you did not do and why. Then route into
`iterable-provision` and conduct it here rather than handing over a command: its wizard
offers to register the missing app, and `next.question` gives you each screen to put to
the developer — the context, the two to four answers, the commands each one runs, and a
free-text option for a value only they have. Present it, wait, run their choice, ask the
next. "I'll run it in my own terminal" is one of the answers the first screen offers, so
a relayed command and a stop answers that for them.

### If they don't have an input yet

Include **"I don't have one yet"** among the options you offer for a missing
input — plenty of developers own the Iterable dashboard and create the key and
push integration themselves.

**When that's the answer, route into `iterable-provision` rather than stopping.**
It produces the three inputs this Preflight cannot invent — a real
`google-services.json`, the service-account key that Iterable's push integration
asks you to upload, and the dashboard steps that have no API — and proves each
one with a live call. Announce the handoff in one line and route. To check it
is installed, walk up from this `SKILL.md` to the first directory containing a
`bin/agent`; if there isn't one, this Preflight stops as written above.

**Routing is not starting.** The first thing that skill does is run
`<root>/bin/agent question opening` and put it to the developer before running anything
else. Let it, and don't run `<root>/bin/agent` or `discover` yourself to save a step —
deciding provisioning is needed is not permission to begin it.

Once its `next.kind` reaches `install_app` (or `run_app`) — the Google and Iterable
halves are green and `.iterable/artifacts/google-services.json` exists — **you own
placing the file**: on bare RN copy
`.iterable/artifacts/google-services.json` to `android/app/google-services.json`;
on Expo put it where `expo.android.googleServicesFile` points, never by
hand-editing `android/`. Show it as part of your one confirmed diff.
In a monorepo whose app sits below the repository root, provisioning does not
read the Android package name from the project yet; the developer types it.

For the steps they do themselves, don't send them to support.iterable.com; open
the doc that covers making it.

| Input they need to create | Where in the dashboard | Slug |
| ------------------------- | ---------------------- | ---- |
| Mobile API key — key types, client-side key security, creating one | **Integrations > API Keys** | `api-keys` |
| Whether the key is JWT-protected, and the shared secret behind it | **Integrations > API Keys** — the JWT choice is made *at creation* and is permanent | `jwt-enabled-api-keys` |
| The mobile app itself (needed before a push integration can exist) | **Settings > Apps and Websites** | `fcm-http-v1-migration` |
| Firebase service account, FCM JSON private key, push integration | **Settings > Apps and Websites** → the app → Push | `fcm-http-v1-migration` |
| Placement IDs | **Settings > Embedded Message Placements** | `embedded-message-placements` |
| Embedded subscription channel and message type | **Settings > Message Channels and Types** | `embedded-message-subscription-channels` |

Those navigation paths are the ones to give the developer — **do not paraphrase
them from memory.** "Settings > API Keys" and "Settings > Mobile Apps" are both
plausible and both wrong, and a developer who doesn't know the dashboard has no
way to tell. If a path here disagrees with the slug's doc, the doc wins (it
carries a `source_ref`); open it and use what it says.

**Order matters, and `fcm-http-v1-migration` is the one that walks it.** The
Iterable project must exist before a mobile app can be defined in it, and the app
must be defined before a push integration can be configured and the FCM JSON key
uploaded to it. That doc is *framed* as a migration, but `### Step 2.4`–`### Step
2.7` are the first-time setup procedure, and `## Step 1` covers creating a
sandbox project to test in before touching production. It is Android/FCM only —
for APNs, follow `reference/push-notifications.md`.

**When configuring that push integration, its FCM type must be "Data
notifications", not "Notification messages".** That dropdown decides who handles
the incoming push: *Data notifications* routes it through Iterable's SDK;
*Notification messages* hands it to the Firebase SDK, which is for apps **not**
using Iterable's SDK. Pick the wrong one and the app still builds, tokens still
register, and pushes may even arrive — but the SDK's tracking and action
handling never fire, with no error anywhere. Say this explicitly; it is a
two-option dropdown the developer cannot guess right. One documented exception:
when mirroring an existing production integration into a sandbox project,
`fcm-http-v1-migration` says match the production app definition — there, the
doc wins.

These docs do **not** settle `google-services.json`: it comes from the
developer's Firebase Console and cannot be generated.

---

## Quick facts (always relevant)

- **Latest version: always fetch it — never trust a number baked into this
  file.** Before writing a dependency line, resolve the current release from
  npm with one call that a scoped private registry can't break:
  `npm view @iterable/react-native-sdk version --@iterable:registry=https://registry.npmjs.org`
  (or the SDK's
  [CHANGELOG.md](https://github.com/Iterable/react-native-sdk/blob/master/CHANGELOG.md)).
  If the network fails, use **3.2.1**, the version this skill's docs were
  checked against, and say so. If the host project already pins a version,
  match it unless they ask to upgrade. **Expo:** also resolve
  `@iterable/expo-plugin` the same way
  (`npm view @iterable/expo-plugin version --@iterable:registry=https://registry.npmjs.org`;
  offline, **1.1.0**) or from its
  [CHANGELOG](https://github.com/Iterable/iterable-expo-plugin/blob/main/CHANGELOG.md).
  State **both** package versions and check they are compatible (pitfall
  #10). Do not guess Expo SDK / RN / plugin versions independently.
- **Initialize with:** `Iterable.initialize(apiKey, config)` from
  `@iterable/react-native-sdk`. On 3.1.0+ the promise means native init
  returned, not that in-app fetch finished (pitfall #6). Identify the user
  after init, the way `example/src/hooks/useIterableApp.tsx` does.
- **Identify users with:** `Iterable.setEmail(email)` or
  `Iterable.setUserId(userId)`. Pick one mode and use it consistently.
- **EU customers** must set `config.dataRegion = IterableDataRegion.EU`
  (default is US).
- **The JS API is not the native API.** The public contract is the named
  exports of `@iterable/react-native-sdk`, which are exactly
  [`src/index.tsx`](https://github.com/Iterable/react-native-sdk/blob/master/src/index.tsx)
  in the SDK (`Iterable`, `IterableConfig`, `IterableInAppManager`,
  `IterableInbox`, `IterableEmbeddedManager`, and their types). If a method
  is not in that file and not in `reference/`, it is not a JS API (pitfall #4).
  Do not import `NativeRNIterableAPI`, `RNIterableAPI`, or the internal
  `IterableApi` class.
- **Native Android/iOS SDK versions come from this RN package, not from the
  native skills.** `@iterable/react-native-sdk` **3.2.1** pins Android
  **`3.10.1`** and iOS **`6.7.5`**; **3.1.0** pinned `3.6.2` / `6.6.7`. Use only
  native APIs the installed package ships, whatever the native skills pin
  (`iterable-android` is at 3.7.0, `iterable-ios` at 6.7.5). Confirm in the RN
  README version table or `node_modules/@iterable/react-native-sdk`
  (`android/build.gradle`, podspec) for the version they have (pitfall #5).
- **Skip 3.2.0.** Its Android module did not compile against its own native pin
  (fixed in 3.2.1). 3.2.x needs React Native **0.77+** and React **18.3.1+**,
  changes no JavaScript APIs, and turns off unknown-user activation on iOS,
  which 3.1.0's native pin left on by default. On Expo, `@iterable/expo-plugin` stays at
  **1.1.0**: npm's 1.2.0 is deprecated as published by accident.

---

## Always-on rules (read every time)

These rules apply to **every** React Native integration. Rule 7 applies
when Step 0 detected Expo. Full explanations are in
[`PITFALLS.md`](PITFALLS.md) — read it before generating any non-trivial
code. On Expo, that includes pitfalls #7–#11 and #13–#14, not only the
JS-runtime items. On **iOS with Xcode 27**, read pitfall **#12** (bare or
Expo). Rule 8 applies whenever the app already sends push of its own.

1. **If the API key is JWT-protected, `config.authHandler` is mandatory — and
   the token must come from the team's backend, never from the app.**
   Without a handler, every SDK call silently fails with no error surface. The
   shared secret behind a JWT key is a **server credential**: never sign JWTs in
   the app (`signWith`, `HMAC`, `jose`, a baked-in `jwtSecret`) and never put the
   secret in JS, `.env`, native config, or anything the bundle ships. Being
   handed the secret means "JWT is on, wire the handler" — not permission to sign
   on the device. If the team has no token-minting endpoint yet, **say so and
   stop there**: point `authHandler` at a stub that logs loudly and resolves
   `null`, and hand them the contract from `reference/jwt-enabled-api-keys.md`
   ("Generating JWTs" — HS256; payload of `email` **or** `userId`, never both;
   `iat` and `exp` no more than a year out). Signing in the app ships the secret
   where it can be extracted and used to mint a token for *any* user in the
   project. Assume JWT is **on** unless told otherwise: it is selected by default
   when a client-side key is created, and cannot be changed afterwards.

2. **EU projects need `dataRegion: IterableDataRegion.EU`.** The default is
   US; EU projects drop the data with no SDK error.

3. **Android 13+ push needs runtime `POST_NOTIFICATIONS`.** Tokens can
   register and the dashboard can send while the OS suppresses the shade.
   This is native Android setup performed as part of the React Native
   integration — read `reference/push-notifications.md` (bare) or
   `reference/expo.md` (Expo). Do not skip it, and do not wait for the
   developer to open the Android skill. The bare 0.88 template's manifest
   declares only `INTERNET`, and it doesn't apply the
   `com.google.gms.google-services` Gradle plugin — so the app builds without
   `google-services.json` and simply never gets an FCM token. A green build is
   not proof.

4. **Only call the public JS facade in `src/index.tsx`.** Import from
   `@iterable/react-native-sdk` (`Iterable`, `IterableConfig`, in-app / inbox /
   embedded modules). Do not import `NativeRNIterableAPI`, `RNIterableAPI`, or
   the internal `IterableApi` class. Do not copy Kotlin
   `IterableApi.getInstance()`, `IterableConfig.Builder()`, or Swift
   `IterableAPI` into JS. Device attributes and unread-inbox count exist
   natively but are not on that facade (pitfall #4). This
   package at 3.2.1 ships Android `3.10.1` / iOS `6.7.5` — native APIs newer
   than those are not reachable (pitfall #5).

5. **Never hardcode the API key into a tracked file.** Read it from a
   gitignored env file or the project's existing secrets pattern. An empty
   fallback is the only acceptable default.

6. **Never assume how the app identifies a user — ask** the project type
   first ([Step 0](#identity-project-type-first)). Do not wire identity to the
   first email-shaped field you find.

7. **Expo: both packages, plugin owns native configuration.** Install with
   `npx expo install @iterable/expo-plugin@<resolved> @iterable/react-native-sdk@<resolved>`
   ([Quick facts](#quick-facts-always-relevant)). Never treat Expo Go as a valid runtime (pitfall #7). Do not hand-edit
   `ios/` or `android/` as the primary path (`prebuild --clean` wipes them
   — pitfall #8). If they already configure native code by hand, do **not**
   add the plugin (pitfall #9). When stating versions, give both packages
   (pitfall #10). Trust plugin source over the support-doc options table:
   `requestPermissionsForPushNotifications` defaults to `false`, so nothing
   prompts — set it to `true` when push is in scope (pitfall #14). Run a
   development build (`expo-dev-client`): Expo Go cannot load the
   `RNIterableAPI` native module. `ios/` and `android/` are
   gitignored and regenerated, so a config or plugin change needs a fresh
   prebuild. On Xcode **27**, use CLI **20.2.0+** (bare) or Expo SDK **58**
   for Device Hub launch; bare apps also need a `Podfile` lift of Pods
   resource-bundle deployment targets, while an Expo SDK 58 prebuild normally needs
   none — check, don't assume (pitfall **#12**). Never hand-edit
   `Pods/`.

8. **If the app already sends push, forward to Iterable — never replace what's
   there.** The one exception is a Step 0 "Iterable only" answer, and only in
   the diff the developer confirmed. Check before scoping push work: grep
   `android/` for `FirebaseMessagingService` and
   `com.google.firebase.MESSAGING_EVENT`, and
   `package.json` for `@react-native-firebase/messaging`, `react-native-onesignal`,
   or another push SDK. RN apps commonly already have a transactional channel,
   and it usually matters more to the business than the marketing push being
   added. On Android, FCM delivers to **one** service; the native SDK under this
   package registers `IterableFirebaseMessagingService` at
   `android:priority="-1"`, so an app's own service keeps winning — installing
   Iterable does not hijack their push, but Iterable receives **nothing** until
   their service forwards to it. Never delete their service, repoint the manifest
   entry, or add `tools:node="remove"`. On **Expo**, do not hand-edit `android/`
   to add forwarding — `prebuild --clean` wipes it (pitfall #8); it belongs in a
   config plugin. This is thinly covered by the RN corpus: the mechanism and the
   `handleMessageReceived` / `handleTokenRefresh` contract are documented on the
   **native Android** side, so read pitfall #15 and verify against the merged
   manifest rather than reasoning it out. iOS coexistence is a different
   mechanism — don't assume the Android shape transfers.

9. **Deep links: `urlHandler` answers `true` for every URL the app owns, and
   only tracking links reach `Iterable.handleAppLink`.** A falsy return makes
   the SDK's JavaScript call `Linking.openURL(url)`; for a URL on your own
   scheme or tracking domain that comes straight back through your `Linking`
   listener — a loop (pitfall #16). Pass a URL to `handleAppLink` only when it
   is `https`, on your tracking domain, with an `/a/` path, and wire `Linking`
   only after `await Iterable.initialize(...)`. On Expo the plugin does **not**
   configure deep links (pitfall #17). See [Deep links](#deep-links).

---

## Canonical minimum integration (start here)

Adapt this; don't bolt the pieces together from scratch. Read
`reference/installing.md` (bare) or `reference/expo.md` (Expo) before
writing native project files.

### Install — Android first

With the versions resolved in [Quick facts](#quick-facts-always-relevant):

**Bare:**

```bash
npm install @iterable/react-native-sdk@<resolved>
```

**Expo** — through `npx expo install`, which the default Expo template's `AGENTS.md`
also requires:

```bash
npx expo install @iterable/expo-plugin@<resolved> @iterable/react-native-sdk@<resolved>
```

- **`E401` from `npm.pkg.github.com`:** the developer's npm config maps the
  `@iterable` scope to a private registry, and `--registry=` doesn't override a
  scope. Check with `npm config get @iterable:registry` — **never print
  `~/.npmrc` or any other credential file**, it holds their token — then add
  pitfall #18's project `.npmrc` and install again.
- **Android first.** After the install, work only in JavaScript and `android/`:
  no `pod install`, no edit under `ios/`, no `AppDelegate` change until
  `iterable-android-verify` is green.
- **New Architecture: leave it on, there is nothing to configure.** React Native
  0.82+ runs only the New Architecture: its CocoaPods scripts treat it as always
  enabled and warn on `ENV['RCT_NEW_ARCH_ENABLED'] = '0'`, and its Gradle plugin
  warns on `newArchEnabled=false`, then both run it anyway. SDK 3.2.1 is a
  codegen TurboModule (`RNIterableAPISpec`) and builds its New Architecture path
  under 0.88. So skip `reference/installing.md` → `## Configuring React Native's
  New Architecture`, and keep the template's `newArchEnabled=true` in
  `android/gradle.properties`: the SDK's Android module compiles its New
  Architecture sources only when that property reads `true`.

On Expo, add the plugin to `expo.plugins` in `app.json` / `app.config.*` —
with push in scope, as
`["@iterable/expo-plugin", { "requestPermissionsForPushNotifications": true }]`
(pitfall #14); otherwise `["@iterable/expo-plugin", {}]`. Do not skip this, and
do not treat the JS snippet as the whole Expo integration.

### Initialize and identify

```javascript
import { Linking } from 'react-native';
import { Iterable, IterableConfig, IterableDataRegion } from '@iterable/react-native-sdk';

// The Iterable link-tracking domain: Settings > Domains in Iterable.
const LINK_TRACKING_DOMAIN = 'links.example.com';

export function isIterableTrackingLink(url) {
  const match = /^https:\/\/([^/?#]+)(\/[^?#]*)?/.exec(url ?? '');
  return !!match && match[1] === LINK_TRACKING_DOMAIN && /^\/a\/[A-Za-z0-9]+/.test(match[2] ?? '');
}

// routeUrl(url) is your app's router: true for every URL on your own scheme or
// domains (unknown paths go to a fallback screen), false only for other apps' URLs.
export async function initializeIterable(apiKey, { userId, routeUrl }) {
  const config = new IterableConfig();
  // config.dataRegion = IterableDataRegion.EU; // EU projects (pitfall #2)
  // config.authHandler = () => fetchJwtForCurrentUser(); // JWT keys (pitfall #1)
  config.urlHandler = (url, context) => routeUrl(url); // rule 9
  await Iterable.initialize(apiKey, config); // native init returned, not in-app ready (pitfall #6)
  if (userId) {
    Iterable.setUserId(userId); // or setEmail(...) — pick ONE (rule 6)
  }

  // After initialize: on Android, handleAppLink before init returns false and the link is lost.
  const open = (url) => {
    if (!url) return;
    if (isIterableTrackingLink(url)) Iterable.handleAppLink(url);
    else routeUrl(url);
  };
  open(await Linking.getInitialURL());
  const subscription = Linking.addEventListener('url', ({ url }) => open(url));
  return () => subscription.remove();
}
```

**You are not done until `initialize` is actually called** from the host
app's startup path.

### Loading the key

The key file is gitignored, so a fresh clone or a CI build has no key; the app
must still build and simply skip `initialize`.

```javascript
// Bare React Native: an optional require, which Metro tolerates when the file
// is missing. A static import breaks every build without the file.
export function readIterableApiKey() {
  try {
    return require('../.iterable/rn/iterable.local').ITERABLE_API_KEY ?? '';
  } catch {
    return '';
  }
}
```

```javascript
// Expo: inlined from .env.local at build time; write it exactly like this
// (dot notation), or Expo doesn't inline it.
export const ITERABLE_API_KEY = process.env.EXPO_PUBLIC_ITERABLE_API_KEY ?? '';
```

Adjust the relative path to `.iterable/` from the importing file. On Expo,
`@iterable/expo-plugin` 1.1.0 has **no** `apiKey` option — one in `app.json` is
ignored — and a changed `.env.local` needs a restarted bundler or a rebuild.

### Bare iOS: native push code

`Iterable.initialize` sets up the native SDK, but the APNs callbacks are native
and belong in the app. The 0.88 template is scene-based: `AppDelegate.swift`
keeps the push callbacks, `SceneDelegate.swift` keeps the URL handling.

```swift
// AppDelegate.swift — add to the template's class.
import IterableSDK
import UIKit
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    return true
  }

  func application(_ application: UIApplication,
                   didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    IterableAPI.register(token: deviceToken)
  }

  func application(_ application: UIApplication,
                   didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                   fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    IterableAppIntegration.application(application,
                                       didReceiveRemoteNotification: userInfo,
                                       fetchCompletionHandler: completionHandler)
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    completionHandler([.banner, .list, .sound, .badge])
  }

  func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
    IterableAppIntegration.userNotificationCenter(center,
                                                  didReceive: response,
                                                  withCompletionHandler: completionHandler)
  }
}
```

In Objective-C the calls are `[IterableAPI registerToken:deviceToken]`,
`[IterableAppIntegration application:didReceiveRemoteNotification:fetchCompletionHandler:]`,
and `[IterableAppIntegration userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:]`.

- **Permission is asked at launch, natively** — the `requestAuthorization` line
  above; neither the SDK nor the template asks (pitfall #22). Don't add a
  permission package for it.
- **The app already has iOS push?** If the developer keeps it (Step 0), forward
  from its callbacks as `iterable-ios` rule 8 says. `ios-verify` then lists
  `existing-push-coexistence` in `verification_limitations`. After Iterable's
  proof passes, offer the optional check that the app's own notifications still
  show, and run it only if they ask. It never blocks the integration.
- **Token registration is the SDK's, after identity.** There is no
  `Iterable.registerForPush()` or any other JavaScript registration call
  (pitfall #21). With the default `autoPushRegistration`, the SDK asks for the
  token after `Iterable.setEmail` / `setUserId`, and `register(token:)` ignores
  any token that arrives before an identity.
- **Project:** the `aps-environment` entitlement (Push Notifications
  capability), `UIBackgroundModes` → `remote-notification` (silent push, which
  also delivers in-app messages), and, for images or buttons, a Notification
  Service Extension target with the `Iterable-iOS-AppExtensions` pod. The
  `iterable-ios` skill has the exact files (canonical step 1, Push
  notifications). Add the entitlements file to the app target's
  `CODE_SIGN_ENTITLEMENTS` build setting, for Debug and Release, in the
  project — not as a `CODE_SIGN_ENTITLEMENTS=` argument to one `xcodebuild`.
- **Universal links:** keep the template's `SceneDelegate` forwarding
  `scene(_:continue:)` and `scene(_:openURLContexts:)` to `RCTLinkingManager`,
  and passing `connectionOptions` to `startReactNative` — that is how a link
  that launched the app reaches `Linking.getInitialURL()`. The SDK example's
  `AppDelegate` `application(_:continue:restorationHandler:)` never fires in a
  scene-based app; React Native ignores the app-delegate linking methods once
  `UIApplicationSceneManifest` is declared.
- **Proof artifact:** the Release configuration for the Simulator. It embeds
  `main.jsbundle`; Debug loads JavaScript from Metro and shows a red box
  without it. Build it with exactly this, from the app root:

  ```bash
  cd ios && xcodebuild -workspace <App>.xcworkspace -scheme <App> -configuration Release -sdk iphonesimulator -derivedDataPath build build
  ```

  The app is `ios/build/Build/Products/Release-iphonesimulator/<App>.app`.
  Install that path with `xcrun simctl install <udid> <path>`, and record it
  with `<root>/bin/ios-prepare-proof start --confirm --app-path <path>`, or
  `restart --confirm --app-path <path>` when a run already exists. Never install a `.app` found with `find` or from another DerivedData
  folder — it can be a stale build (pitfall #19). Never add
  `CODE_SIGNING_ALLOWED=NO`, `CODE_SIGNING_REQUIRED=NO` or `CODE_SIGN_IDENTITY=""`:
  an unsigned app carries no `aps-environment` and never gets a token
  (pitfall #20).
- **Proof identity marker (temporary):** when push is in scope, add this to
  `AppDelegate.swift` and call it as the last line of
  `application(_:didFinishLaunchingWithOptions:)`, before `return true`. At
  proof time the verifier relaunches the app with `-iterableProofIdentity YES`
  and reads the identity from the Simulator's log, as in `iterable-ios`
  (*The proof identity marker*). It reads the native SDK, not JavaScript: the
  identity is stored natively once `Iterable.initialize` and `setEmail` /
  `setUserId` have run, and the app delegate starts before the JavaScript
  bundle does, so it checks once a second until the SDK holds an identity. The
  launch argument gates it, because the proved build is Release.

  ```swift
  // AppDelegate.swift — temporary: remove once the push is proved.
  import os

  private func logIterableProofIdentity(attempt: Int = 0) {
    guard UserDefaults.standard.bool(forKey: "iterableProofIdentity") else { return }
    if let identity = IterableAPI.userId ?? IterableAPI.email {
      os_log("ITBL_PROOF identity=%{public}@", identity)
    } else if attempt < 30 {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self.logIterableProofIdentity(attempt: attempt + 1)
      }
    }
  }
  ```

  Remove it once the push is proved, as the last step of the handoff;
  `ios-verify inspect` warns `proof_identity_marker_present` while it remains.

Native push / APNs / FCM / `POST_NOTIFICATIONS` steps are in the installing
and push (or expo) reference docs — do them as part of this skill when push
is in scope. If a React Native article defers to Android-native detail that
is already shipped in the sibling `iterable-android` skill, you may open
`../iterable-android/reference/<slug>.md` for that native step. Likewise, for
an iOS-native step the article defers (APNs setup, entitlements, the
Notification Service Extension) you may open
`../iterable-ios/reference/<slug>.md`. Do not copy `iterable-ios`'s Swift
initialization into an RN app: this package initializes the native SDK, and the
iOS SDK version it ships (above) wins over the iOS skill's pin.

### Deep links

Only when deep links are in scope.

- **What `urlHandler`'s answer does.** With a JS `urlHandler` set, the native
  side always reports the URL as handled and hands it to JavaScript; on Android
  the SDK waits `config.androidWakeDelayMs` (default **1000 ms**) before calling
  it, so a cold-start link routes a second later. If the handler returns
  anything falsy, the SDK's JavaScript calls `Linking.openURL(url)` — for your
  own scheme or domains, straight back into your app (rule 9, pitfall #16).
- **A tracking link is resolved asynchronously.** `handleAppLink` records the
  click and follows the redirect; `urlHandler` then receives the destination —
  or the original `/a/` URL when the request fails (offline), which it must also
  answer `true` for.
- **Keep tracking links out of your navigation library.** React Navigation's
  `linking` prop takes `filter: (url) => !isIterableTrackingLink(url)`. With
  Expo Router, export `redirectSystemPath` from `app/+native-intent.tsx` and
  return `null` for a tracking link — no redirection occurs — letting the
  listener above hand it to Iterable.
- **Native entry points.** Bare iOS forwards links to `RCTLinkingManager`
  (`reference/deep-links-and-custom-actions.md` → Step 1). That snippet starts
  with `#import <React/RCTLinkingManager.h>`, which is Objective-C and does not
  compile in a Swift `AppDelegate` — use `import React`. Its `urlHandler`
  example calls `this.navigate(match[1])` without ever binding `match`; capture
  the result of `url.match(...)` first.
- **Expo:** the plugin (1.1.0) only sets the main activity's
  `android:launchMode` to `singleTask`. It adds no intent filters and no
  associated domains, whatever `reference/expo.md` says — add them yourself in
  `app.json` (pitfall #17):

  ```json
  {
    "expo": {
      "ios": { "associatedDomains": ["applinks:links.example.com"] },
      "android": {
        "intentFilters": [
          {
            "action": "VIEW",
            "autoVerify": true,
            "data": [{ "scheme": "https", "host": "links.example.com", "pathPrefix": "/a/" }],
            "category": ["BROWSABLE", "DEFAULT"]
          }
        ]
      }
    }
  }
  ```

  Use your own tracking domain. The `reference/expo.md` examples list
  `applinks:expo.dev` and `applinks:iterable.com` — domains the app cannot
  claim — and its intent-filter JSON has a `//` comment and a trailing comma,
  which `app.json` rejects.
- **Iterable prerequisites** for either platform: a custom HTTPS link-tracking
  domain (not `links.iterable.com`), the `apple-app-site-association` and
  `assetlinks.json` uploads under **Settings > Domains** → the tracking domain →
  **New Destination Path**, and on Android 12+ a verified App Link — an
  unverified one opens in the browser. The native skills have the detail:
  `iterable-ios` (Deep links and universal links) and `iterable-android` (Deep
  links and App Links).

---

## How to use this skill (fetching task-specific docs)

> **Say what you're about to read and why — before you read it.** One line
> per lookup.

### Read task docs from `reference/`

[`reference/`](reference/) is Iterable's published documentation, transformed
deterministically and shipped with this skill. Match the task to a slug
(table below) and open `reference/<slug>.md`. **This is the authoritative
source — it is already on disk.**

**One doc per task — don't bulk-load.** Two or three slugs is a normal task.

### Slug routing

| If the user is asking about… | Slug |
| ---------------------------- | ---- |
| What the RN SDK covers, architecture, JS vs native | `overview` |
| First-time setup, npm install, iOS + Android native project setup, `Iterable.initialize` | `installing` (bare; skip `## Upgrading the SDK` unless they are upgrading, and on React Native 0.82+ skip `## Configuring React Native's New Architecture` — see [Install](#install--android-first)). Expo: `expo` |
| Expo / `expo prebuild` / config plugin | `expo` |
| JWT, `authHandler`, JWT-enabled API keys | `authentication` |
| `setEmail`, `setUserId`, login / logout | `managing-user-identity`; the rules behind it are in [Decisions](#decisions-read-before-recommending) |
| `updateUser`, profile fields, subscription preferences | `user-profile-data-and-subscription-preferences` |
| FCM / APNs push, notification permission, device registration | `push-notifications` |
| The app **already** sends push (`@react-native-firebase/messaging`, another vendor SDK, a hand-written `FirebaseMessagingService`) | No RN slug: the forwarding contract is `../iterable-android/reference/setting-up-android-push-notifications.md` → `#### Handling Firebase push messages and tokens`. Use rule 8 and [`PITFALLS.md`](PITFALLS.md) #15, and verify against the merged manifest. |
| In-app messages | `in-app-messages` |
| Mobile inbox | `mobile-inbox` |
| Deep links, custom actions, `urlHandler` | `deep-links-and-custom-actions` |
| `track`, purchases, custom events | `tracking-events` |
| Embedded messaging, placements | `embedded-messages-with-iterables-react-native-sdk` |

**Dashboard-side prerequisites** (`archetype: prerequisite`). These document
Iterable's web app, not the SDK — reach for them when the developer owns the
dashboard and needs to *create* an input, not when they just need to look one up.
See [If they don't have an input yet](#if-they-dont-have-an-input-yet).

| If the user is asking about… | Slug |
| ---------------------------- | ---- |
| Creating a Firebase service account, FCM JSON private key, defining a mobile app in Iterable, configuring the push integration, sandbox projects | `fcm-http-v1-migration` (read `## Step 1`, `### Step 2.4`–`### Step 2.7`; Android/FCM only) |
| Creating or finding a placement ID in the dashboard | `embedded-message-placements` |
| Embedded message subscription channels and message types | `embedded-message-subscription-channels` |

For "wire up the whole SDK", read `installing` or `expo` first (the workflow
you detected), then load feature slugs **as you reach each feature**.

---

## Decision flow

1. **Detect Expo vs bare. Identify the goal.** New integration, upgrade,
   single feature, or debugging.
2. **Check always-on rules** against whatever they already have. On Expo,
   that includes rule 7 (pitfalls #7–#11, #13–#14) and Xcode 27 (pitfall
   #12) when relevant.
3. **Read the matching slug** from `reference/` before writing code.
4. **For traps not in the reference doc**, consult [`PITFALLS.md`](PITFALLS.md).
5. **Version-check.** If they are on an older SDK than the doc's
   `sdk_min_version`, read the upgrading section of `installing` before
   generating code. On Expo, also check `@iterable/expo-plugin` against
   `reference/expo.md` → `## Requirements` (pitfall #10).

---

## What's NOT in this skill

- Native Android-only or iOS-only app integrations — those are
  `iterable-android` and `iterable-ios`. If this project is a native app with
  no React Native, stop and use the matching native skill.
- Iterable platform / dashboard configuration. Direct the user to
  [support.iterable.com](https://support.iterable.com).
- JWT *server-side* implementation. Assume the team has, or will build, a
  token-minting endpoint.

---

## Versioning

This skill is versioned alongside the SDK. When Iterable's docs change, a
refresh commit rewrites `reference/` from the docs at that commit; each doc
records the exact `source_ref` it came from. If you see drift between this
skill's snippets and the SDK's current `CHANGELOG.md`, **trust `CHANGELOG.md`**
and report the drift. On Expo, also trust the plugin
[CHANGELOG](https://github.com/Iterable/iterable-expo-plugin/blob/main/CHANGELOG.md)
and plugin source over a stale options table in `reference/expo.md`.
