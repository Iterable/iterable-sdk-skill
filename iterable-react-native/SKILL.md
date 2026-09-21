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
  silently break integrations.
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
- In-app messages
- Event tracking + user identity
- Other (inbox, embedded, deep links) — describe in the option

**First check whether this is an upgrade, not a new integration.** If the
project already depends on `@iterable/react-native-sdk` (and, on Expo,
`@iterable/expo-plugin`), ask which version they're on and what they want
out of the upgrade, then follow the upgrade row in the slug table.

**And check whether the app already sends push without Iterable.** Look for
`@react-native-firebase/messaging` or another push SDK in `package.json`, and
for `FirebaseMessagingService` / `com.google.firebase.MESSAGING_EVENT` under
`android/`. If any is present, that channel is an integration constraint rather
than something to replace — rule 8 has the shape. Say what you found and confirm
the plan before touching it.

Confirm the scope, *then* run Preflight, *then* build.

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
  push permission on Android 13+ when push is in scope.

Only genuinely developer-supplied inputs (API key, identity model, region,
JWT, `google-services.json` / APNs key) are legitimate pauses.

---

## Preflight — STOP and gather these before writing any code

> **Prefer selectable options over prose — every time.** Offer at most 4
> options per question on hosts that reject more.

| Input | Needed when | If missing |
|---|---|---|
| **Workflow** — Expo vs bare | Always | Detect from the project (Step 0). If both signals exist, ask. |
| **Mobile API key** | Always | Ask where it lives; never hardcode into a tracked file. |
| **Identity model** — `setEmail` vs `setUserId`, and where the value comes from | Always | Ask. Never guess. |
| **JWT?** — is the mobile key JWT-protected? | Always | Ask, and **assume yes until told otherwise** (it is on by default for client-side keys and is permanent). If yes, `authHandler` is mandatory (rule 1) **and the team needs a backend endpoint that mints the tokens** — if they don't have one, raise it as a blocker instead of signing in the app. |
| **Data region** — US or EU | Always | Ask if their dashboard is `app.eu.iterable.com`. See pitfall #2. |
| **`google-services.json`** (Firebase) | Android push (bare **or** Expo) | **STOP and ask.** You cannot generate it. Expo: path goes in `expo.android.googleServicesFile`, not a hand-edited `android/`. |
| **APNs key / capabilities** | Bare-workflow push on iOS | Ask. Follow `reference/push-notifications.md`. |
| **Development build vs Expo Go** | Expo | Expo Go cannot run this SDK (pitfall #7). If they are in Expo Go, stop and move them to a development build before debugging JS. |

**Never fabricate a prerequisite to make the build pass.** Do not invent an
API key, a placeholder `google-services.json`, or a JWT signed in the client.

### If they don't have an input yet

Include **"I don't have one yet"** among the options you offer for a missing
input — plenty of developers own the Iterable dashboard and create the key and
push integration themselves. When that's the answer, don't send them to
support.iterable.com; open the doc that covers making it.

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
two-option dropdown the developer cannot guess right.

Two things these docs do **not** settle, so keep asking the developer:
**data region** (confirm it from their dashboard URL — `app.eu.iterable.com`
means EU; see pitfall #2) and **`google-services.json`**, which comes from their
Firebase Console and cannot be generated.

---

## Quick facts (always relevant)

- **Latest version: always fetch it — never trust a number baked into this
  file.** Before writing a dependency line, resolve the current release from
  npm (`@iterable/react-native-sdk`) or the SDK's
  [CHANGELOG.md](https://github.com/Iterable/react-native-sdk/blob/master/CHANGELOG.md).
  If the host project already pins a version, match it unless they ask to
  upgrade. **Expo:** also resolve `@iterable/expo-plugin` from npm or its
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
  Android skill.** `@iterable/react-native-sdk` **3.1.0** pins Android
  **`3.6.2`** and iOS **`6.6.7`**. Do not call Kotlin/Swift APIs that exist
  only on Android `3.7.0` (the Android skill's pin) or any newer native SDK
  than this package ships. Confirm in the RN README version table or
  `node_modules/@iterable/react-native-sdk` (`android/build.gradle`, podspec)
  for the version they have (pitfall #5).

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
   developer to open the Android skill.

4. **Only call the public JS facade in `src/index.tsx`.** Import from
   `@iterable/react-native-sdk` (`Iterable`, `IterableConfig`, in-app / inbox /
   embedded modules). Do not import `NativeRNIterableAPI`, `RNIterableAPI`, or
   the internal `IterableApi` class. Do not copy Kotlin
   `IterableApi.getInstance()`, `IterableConfig.Builder()`, or Swift
   `IterableAPI` into JS. Device attributes and unread-inbox count exist
   natively but are not on that facade (pitfall #4, SDK-593, SDK-594). This
   package at 3.1.0 ships Android `3.6.2` / iOS `6.6.7` — do not pull Android
   `3.7.0` APIs from the Android skill (pitfall #5).

5. **Never hardcode the API key into a tracked file.** Read it from a
   gitignored env file or the project's existing secrets pattern. An empty
   fallback is the only acceptable default.

6. **Never assume how the app identifies a user — ask.** Do not wire
   identity to the first email-shaped field you find.

7. **Expo: both packages, plugin owns native configuration.** Install with
   `npx expo install @iterable/expo-plugin @iterable/react-native-sdk`.
   Never treat Expo Go as a valid runtime (pitfall #7). Do not hand-edit
   `ios/` or `android/` as the primary path (`prebuild --clean` wipes them
   — pitfall #8). If they already configure native code by hand, do **not**
   add the plugin (pitfall #9). When stating versions, give both packages
   (pitfall #10). Trust plugin source over the support-doc options table
   (`requestPermissionsForPushNotifications` defaults to `false` — pitfall
   #14). On Xcode **27**, use CLI **20.2.0+** (bare) or Expo SDK **58**
   for Device Hub launch, and host Podfile / config-plugin fixes for
   resource-bundle deployment targets (pitfall **#12**) — not hand-edited
   `Pods/`.

8. **If the app already sends push, forward to Iterable — never replace what's
   there.** Check before scoping push work: grep `android/` for
   `FirebaseMessagingService` and `com.google.firebase.MESSAGING_EVENT`, and
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

---

## Canonical minimum integration (start here)

Adapt this; don't bolt the pieces together from scratch. Read
`reference/installing.md` (bare) or `reference/expo.md` (Expo) before
writing native project files.

**Expo — install both packages first** (then the JS below):

```bash
npx expo install @iterable/expo-plugin @iterable/react-native-sdk
```

Add `["@iterable/expo-plugin", {}]` to `expo.plugins` in `app.json` /
`app.config.*`. Do not skip this, and do not treat the JS snippet as the
whole Expo integration.

```javascript
import { Iterable, IterableConfig, IterableDataRegion } from '@iterable/react-native-sdk';

export async function initializeIterable(apiKey, { userId, dataRegion } = {}) {
  const config = new IterableConfig();
  // config.dataRegion = IterableDataRegion.EU; // EU projects (pitfall #2)
  // config.authHandler = () => fetchJwtForCurrentUser(); // JWT keys (pitfall #1)
  await Iterable.initialize(apiKey, config); // native init returned, not in-app ready (pitfall #6)
  if (userId) {
    Iterable.setUserId(userId); // or setEmail(...) — pick ONE (rule 6)
  }
}
```

**You are not done until `initialize` is actually called** from the host
app's startup path.

Native push / APNs / FCM / `POST_NOTIFICATIONS` steps are in the installing
and push (or expo) reference docs — do them as part of this skill when push
is in scope. If a React Native article defers to Android-native detail that
is already shipped in the sibling `iterable-android` skill, you may open
`../iterable-android/reference/<slug>.md` for that native step. There is no
iOS skill yet; iOS native setup is only what this corpus includes.

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
| First-time setup, npm install, iOS + Android native project setup, `Iterable.initialize` | `installing` (bare; skip `## Upgrading the SDK` unless they are upgrading). Expo: `expo` |
| Upgrading from an older RN SDK version | `installing` → `## Upgrading the SDK`, or `migrating` |
| Expo / `expo prebuild` / config plugin | `expo` |
| JWT, `authHandler`, JWT-enabled API keys | `authentication` |
| `setEmail`, `setUserId`, login / logout | `managing-user-identity` |
| `updateUser`, profile fields, subscription preferences | `user-profile-data-and-subscription-preferences` |
| FCM / APNs push, notification permission, device registration | `push-notifications` |
| The app **already** sends push (`@react-native-firebase/messaging`, another vendor SDK, a hand-written `FirebaseMessagingService`) | **No slug covers this** — the forwarding contract lives on the native Android side. Use rule 8 and [`PITFALLS.md`](PITFALLS.md) #15, and verify against the merged manifest. |
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
| Creating a mobile API key, key types, client-side key security, key scope | `api-keys` |
| Turning on JWT for a key, the shared secret, token claims and expiry | `jwt-enabled-api-keys` |
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
  `iterable-android` and (when authored) `iterable-ios`. If this project is
  a native Android app with no React Native, stop and use `iterable-android`.
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
