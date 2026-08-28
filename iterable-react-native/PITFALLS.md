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
`example/src/components/App/App.tsx`). Expo config-plugin traps
(`@iterable/expo-plugin`, Expo Go, `prebuild --clean`) are SDK-704 and are
not listed here.

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
- **Fix:** This is still a React Native integration step. Copy the sample's
  two-part pattern, not Kotlin `ActivityResultContracts`:
  1. Declare `<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />`
     in the Android manifest (`example/android/app/src/main/AndroidManifest.xml`).
  2. Request it from JS on API 33+ with `PermissionsAndroid.request`
     (`example/src/components/App/App.tsx` `requestNotificationPermission`).
     Call it from a user-facing screen, not at module load.

  For Expo, follow `reference/expo.md` instead of hand-editing `android/`.
  See `reference/push-notifications.md`.

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
