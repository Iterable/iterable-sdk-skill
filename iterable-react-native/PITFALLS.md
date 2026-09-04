# Iterable React Native SDK — Agent Pitfalls

Silent failures, foot-guns, and "looks fine but is broken" patterns the agent
will hit if it relies on generic SDK intuition or copies native Android/iOS
APIs into JavaScript. The hot-path subset is in `SKILL.md`; the full list
lives here and is loaded on demand.

> Format: each pitfall has **Symptom** (what the developer sees), **Cause**
> (what's actually happening), **Fix** (what to do instead). Skim them when
> the user reports any unexplained failure.

Sourced from `@iterable/react-native-sdk` **3.1.0** master: public exports in
`src/index.tsx`, the TurboModule spec in `src/api/NativeRNIterableAPI.ts`,
CHANGELOG 3.1.0, the README native-version table, and the working sample in
`example/` (`example/src/hooks/useIterableApp.tsx`,
`example/src/components/App/App.tsx`). Expo items also come from
`@iterable/expo-plugin` 1.1.0 (`plugin/src/withIterable.ts`) and
`reference/expo.md`.

**How to read this list.** #1–6 are JavaScript / runtime traps. They apply
to **every** React Native app, including Expo. #7–13 are Expo
config-plugin traps (build-time and configuration-time). Use them only
after Step 0 classified the project as Expo. #3's *symptom* is both
workflows; its **bare** native fix (manifest + `PermissionsAndroid`) is
wrong on Expo — branch first.

---

## 1. JWT-required API key with no `authHandler`

- **Symptom:** Every API call succeeds locally (the SDK reports no error) but
  nothing reaches Iterable. No errors, no logs.
- **Cause:** Mobile API keys can be configured server-side to require a JWT.
  When this is on, the SDK silently drops every request that lacks a JWT. The
  SDK does not log this.
- **Fix:** Follow the sample in `example/src/hooks/useIterableApp.tsx`.
  When JWT is on, set `config.authHandler` **before**
  `Iterable.initialize`, and optionally pass the current token as the second
  argument to `Iterable.setEmail` / `Iterable.setUserId` on login:

  ```javascript
  config.authHandler = async () => {
    return await fetchJwtForCurrentUser(); // server-minted
  };
  await Iterable.initialize(apiKey, config);
  Iterable.setUserId(userId, token); // or setEmail(email, token) — pick ONE
  ```

  Wire `config.onJwtError` (the sample does) so a bad token is visible. Never
  sign JWTs in the host app (`signWith`, `HMAC`, a baked-in `jwtSecret`).
  The sample mints tokens via `NativeJwtTokenModule` + `ITBL_JWT_SECRET`
  **because it is Iterable's sandbox** — do not copy that module or the
  secret into a production app. See `reference/authentication.md`.

## 2. EU customer hitting US endpoint

- **Symptom:** Calls succeed but data never appears in the customer's
  Iterable dashboard. Customer is in the EU project.
- **Cause:** `IterableConfig.dataRegion` defaults to
  `IterableDataRegion.US`. The sample app does not set it. EU projects refuse
  the data but the SDK doesn't error.
- **Fix:** Set `config.dataRegion = IterableDataRegion.EU` before
  `Iterable.initialize`. Always confirm region with the developer if their
  Iterable URL is `app.eu.iterable.com`. See `reference/installing.md`.

## 3. POST_NOTIFICATIONS permission not requested on Android 13+

- **Symptom:** Tokens register, dashboard sends pushes, but nothing appears
  on Android 13+ devices. Older devices and iOS work.
- **Cause:** Android 13 (API 33) introduced runtime `POST_NOTIFICATIONS`.
  Without a granted permission, the OS silently suppresses every notification —
  including Iterable's. No error in the JS SDK.
- **Fix:** Branch on the workflow from Step 0. Do not apply the bare
  recipe to an Expo app.

  - **Expo:** Do not edit `AndroidManifest.xml` or `android/`. Configure
    push through `@iterable/expo-plugin` and `reference/expo.md` (pitfalls
    #7–#13). Point `expo.android.googleServicesFile` at the developer-supplied
    `google-services.json`.
  - **Bare:** Copy the sample's two-part pattern, not Kotlin
    `ActivityResultContracts`:
    1. Declare `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`
       in the Android manifest (`example/android/app/src/main/AndroidManifest.xml`).
    2. Request it from JS on API 33+ with `PermissionsAndroid.request`
       (`example/src/components/App/App.tsx` `requestNotificationPermission`).
       Call it from a user-facing screen, not at module load.

  See `reference/push-notifications.md` (bare) or `reference/expo.md` (Expo).

## 4. Native or bridge APIs used as if they were the public JS SDK

- **Symptom:** TypeScript does not compile, a plausible method name is called
  and does nothing, or the agent writes `IterableApi.getInstance()`, Kotlin,
  Swift, `NativeRNIterableAPI.*`, or a deep import of `IterableApi` into a
  `.ts` / `.tsx` file.
- **Cause:** The React Native SDK is a thinner JavaScript layer over native
  Android and iOS. Three layers exist; only the package root is the public
  contract. On master (`src/index.tsx` vs `src/api/NativeRNIterableAPI.ts`):

  | Layer | Examples | Call from the host app? |
  |---|---|---|
  | Public package (`@iterable/react-native-sdk`) | `Iterable`, `IterableConfig`, `IterableInAppManager`, `IterableInbox`, `IterableEmbeddedManager` | Yes |
  | Internal JS (`IterableApi`, `initialize2`) | `IterableApi.initializeWithApiKey`, `Iterable.initialize2` | No — not in `src/index.tsx` |
  | TurboModule spec (`NativeRNIterableAPI`) | `RNIterableAPI.getUnreadInboxMessagesCount`, `passAlongAuthToken` | No |
  | Native Android / iOS SDK | Kotlin `IterableApi.getInstance()`, Swift `IterableAPI`, `setDeviceAttribute` | Native *configuration* only (FCM, APNs, entitlements). Not JS. |

  Concrete gaps still open on 3.1.0:

  - **SDK-594:** `getUnreadInboxMessagesCount` is on the TurboModule spec and
    implemented natively. `IterableInAppManager` exposes `getMessages` /
    `getInboxMessages` / `showMessage` / `setReadForMessage` and **no**
    unread-count wrapper.
  - **SDK-593:** `setDeviceAttribute` is used internally to stamp
    `reactNativeSDKVersion` at init. It is not on the TurboModule spec and
    not on `Iterable`.
  - `logout` is **not** a Spec method. The public call is `Iterable.logout()`
    (the sample also clears identity; `logout()` already calls
    `setEmail(null)` and `setUserId(null)`).
- **Fix:** Only import from `@iterable/react-native-sdk`. Do not import
  `NativeRNIterableAPI`, `RNIterableAPI`, or `IterableApi`. Do not invent
  wrappers for spec-only methods. Until SDK-594 ships, derive an unread
  count from `Iterable.inAppManager.getInboxMessages()` (filter unread)
  rather than calling the native module. Native configuration (FCM, APNs,
  `POST_NOTIFICATIONS`) is still required; it is not a JS method call. See
  `reference/overview.md` and the feature slug for the task.

## 5. Native Android/iOS APIs taken from a newer SDK than this RN package pins

- **Symptom:** The agent copies Kotlin/Swift from the Android skill (or
  "latest Android SDK") into a React Native project, or tells the developer
  to bump `com.iterable:iterableapi` independently of `@iterable/react-native-sdk`.
- **Cause:** Each RN release **pins** the native SDKs. They are not "whatever
  the Android skill currently documents." On master, `android/build.gradle`
  is `com.iterable:iterableapi:3.6.2`. The Android skill's pin may already
  be **3.7.0**. APIs that exist only on a newer native SDK are not reachable
  through this RN package.
- **Fix:** Use the RN package's version table (README "Version mapping"), not
  the Android skill. Confirm the installed pin in
  `node_modules/@iterable/react-native-sdk` (`android/build.gradle`,
  podspec). Recent rows:

  | RN SDK | Android SDK | iOS SDK |
  |---|---|---|
  | 3.1.0 | 3.6.2 | 6.6.7 |
  | 3.0.x / 2.2.x | 3.6.2 | 6.6.3 |
  | 2.1.0 – 2.0.0 | 3.5.2 | 6.5.4 |

  Do not add a second `com.iterable:iterableapi` dependency in the host app
  to "get a newer native API." Upgrade `@iterable/react-native-sdk` instead.

## 6. Treating `await Iterable.initialize` as "SDK failed" or "in-app ready" (iOS, pre-3.1.0)

- **Symptom:** On iOS, `Iterable.initialize` hangs for seconds to minutes
  under JWT or slow network, or the promise rejects and the agent reports
  init failure. Android is fine. In-app / JWT retries look like the cause.
  The sample still has a `.catch` that, on iOS, marks the SDK initialized and
  continues login anyway (`example/src/hooks/useIterableApp.tsx`).
- **Cause:** Before **3.1.0**, the iOS bridge wired the JS promise to
  `initialize2(callback:)`, whose callback fires when the **first in-app
  fetch** settles — not when `IterableAPI.initialize` returns. Native init on
  iOS is synchronous, non-failable, and already done. The hang was the
  in-app retry budget, not init. CHANGELOG 3.1.0 fixed the bridge to match
  Android: the promise resolves as soon as the synchronous native initializer
  returns. `await Iterable.initialize(...)` is API symmetry; it does **not**
  mean in-app messages are loaded.
- **Fix:** If they are on **3.1.0+**, trust the promise as "native init
  returned" and do not treat a later in-app/JWT issue as an init failure.
  Identify the user after init the way the sample does (`login()` →
  `setEmail` / `setUserId`), not inside a guessed timeout. If they are on a
  version older than 3.1.0 and iOS `initialize` hangs or rejects, upgrade;
  do not keep the sample's iOS `.catch` as the long-term fix, and do not call
  `Iterable.initialize2` (internal / staging). See
  `reference/installing.md` → `## Upgrading the SDK`.

---

Pitfalls 7–13 apply only when Step 0 detected Expo. Skip them on a bare
React Native project. Do not introduce `@iterable/expo-plugin` there.

## 7. Expo: SDK and plugin do not work in Expo Go

- **Symptom:** `Iterable.initialize` appears to run, or the app errors with
  a missing native module. Push, in-app, and inbox never appear. The agent
  debugs JavaScript for a cycle whose cause is the runtime.
- **Cause:** Both `@iterable/expo-plugin` and `@iterable/react-native-sdk`
  rely on native code. Expo Go [does not ship arbitrary native
  modules](https://expo.dev/blog/expo-go-vs-development-builds#expo-go-limitations).
- **Fix:** Run a [development
  build](https://docs.expo.dev/develop/development-builds/introduction/) —
  `npx expo run:ios` / `npx expo run:android`, or an EAS development
  build. Do not keep iterating on JS while they are in Expo Go. See
  `reference/expo.md` → `### Expo Go`.

## 8. Expo: `expo prebuild --clean` wipes `ios/` and `android/`

- **Symptom:** Hand-edits to native projects (FCM, APNs, entitlements,
  Iterable native init) disappear after the next prebuild. Or the agent
  followed `reference/installing.md` in an Expo app and that work vanished
  on rebuild.
- **Cause:** The plugin configures native projects during `expo prebuild`.
  `npx expo prebuild --clean` deletes `ios/` and `android/` and regenerates
  them. Any file the agent wrote there is gone.
- **Fix:** Native setup belongs in `app.json` / `app.config.*` and the
  plugin options, not in `ios/` or `android/` as the source of truth. If
  those directories must stay hand-maintained, do **not** use the plugin
  (pitfall #9). See `reference/expo.md` → `### Native code`.

## 9. Expo: do not use the plugin when native is configured by hand

- **Symptom:** Adding `@iterable/expo-plugin` to a project that already
  customizes `ios/` / `android/` overwrites that work on the next
  `prebuild --clean`. Or the project is half plugin, half hand-edit, and
  neither path is stable.
- **Cause:** The plugin is for managed / continuous-native-generation
  workflows. Docs state a hard do-not: if they manually configure native
  code instead of other Expo config plugins, **do not use this plugin**.
- **Fix:** Ask before adding it. If they maintain native projects by
  hand, skip `@iterable/expo-plugin` and follow `reference/installing.md`
  for native steps. If they are on the Expo plugin path, do not hand-edit
  `ios/` or `android/` (pitfall #8). See `reference/expo.md` →
  `### Native code`.

## 10. Expo: two packages, versions move in lockstep

- **Symptom:** The build fails after the agent guessed an Expo SDK, React
  Native, React, Node, `@iterable/react-native-sdk`, or
  `@iterable/expo-plugin` version. Or it stated only the RN SDK version
  for an Expo project.
- **Cause:** Expo apps depend on a **second** published package,
  `@iterable/expo-plugin` (`Iterable/iterable-expo-plugin`), on its own
  cadence. It is a peer of the RN SDK, not part of it. Refresh stamps
  `reference/expo.md` with the RN `sdk.tag` only, so the corpus does not
  record the plugin pin.
- **Fix:** When stating versions, give **both** packages and confirm they
  are compatible. Resolve current releases from npm (or each CHANGELOG);
  do not bake a "latest" number into the skill. The tested floor in
  `reference/expo.md` → `## Requirements` is Expo SDK **55+**, React
  Native **0.83.2+**, React **19.2+**, Node **20.19.4+**,
  `@iterable/react-native-sdk` **3.0.0+** (this skill is validated against
  **3.1.0**), `@iterable/expo-plugin` **1.1.0+**. Install with
  `npx expo install @iterable/expo-plugin @iterable/react-native-sdk`.

## 11. Expo: fighting the plugin (New Architecture / `{fmt}`)

- **Symptom:** The agent sets `newArchEnabled: false` on Expo SDK 55 (no
  effect, or a broken build), or hand-patches Pods / Xcode settings for a
  `{fmt}` C++ error on Xcode 26.4+.
- **Cause:** Expo SDK 55 requires React Native's New Architecture.
  `@iterable/expo-plugin` **1.1.0+** applies an iOS `{fmt}` C++17
  workaround during `expo prebuild` (`withIosFmtWorkaround`). Hand-editing
  either is working against the plugin.
- **Fix:** Leave `newArchEnabled` **true** on Expo 55+. Do not patch Pods
  for `{fmt}`. If the workaround is missing, upgrade the plugin to 1.1.0+
  rather than copying a native fix. See `reference/expo.md` →
  `### React Native's New Architecture` and `### Xcode 26.4 compatibility`.

## 12. Expo: EAS signing for `IterableExpoRichPush`

- **Symptom:** EAS iOS build fails with "Signing for 'IterableExpoRichPush'
  requires a development team" (or the NSE target is missing from the
  EAS profile).
- **Cause:** The plugin creates a notification-service-extension target
  named `IterableExpoRichPush`. EAS will not sign it unless it is listed
  under `expo.extra.eas.build.experimental.ios.appExtensions`.
- **Fix:** Add that block as in `reference/expo.md` → `### Configuring EAS
  Builds`. The extension bundle id is
  `<main-bundle-id>.IterableExpoRichPush`. Do not "fix" this by deleting
  the extension or hand-editing the Xcode project (pitfall #8).

## 13. Expo: `requestPermissionsForPushNotifications` defaults to `false`

- **Symptom:** The agent omits the plugin option, expecting iOS to prompt
  for notification permission because the support-doc table says the
  default is `true`. No prompt. Push looks "set up" and never appears.
- **Cause:** Plugin source (`plugin/src/withIterable.ts`) defaults
  `requestPermissionsForPushNotifications` to **`false`**. Bundled
  `reference/expo.md` (and the upstream article) currently list the
  default as `true`. That table is wrong. The option is **iOS-only**.
- **Fix:** Trust the plugin, not the table. Set the option **explicitly**
  if they want iOS permission prompting. Do not hand-edit
  `reference/expo.md` to "fix" the table — the next docs refresh will
  overwrite it. Report the drift against `Iterable/iterable-docs`.
