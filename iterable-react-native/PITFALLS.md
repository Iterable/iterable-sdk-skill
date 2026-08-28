# Iterable React Native SDK — Agent Pitfalls

Silent failures, foot-guns, and "looks fine but is broken" patterns the agent
will hit if it relies on generic SDK intuition or copies native Android/iOS
APIs into JavaScript. The hot-path subset is in `SKILL.md`; the full list
lives here and is loaded on demand.

> Format: each pitfall has **Symptom** (what the developer sees), **Cause**
> (what's actually happening), **Fix** (what to do instead). Skim them when
> the user reports any unexplained failure.

Starter set for this skill (SDK-425). Transfers from the Android skill plus
named JS-bridge gaps. Expo config-plugin traps (`@iterable/expo-plugin`, Expo
Go, `prebuild --clean`) are SDK-704 and are not listed here yet.

---

## 1. JWT-required API key with no `authHandler`

- **Symptom:** Every API call succeeds locally (the SDK reports no error) but
  nothing reaches Iterable. No errors, no logs.
- **Cause:** Mobile API keys can be configured server-side to require a JWT.
  When this is on, the SDK silently drops every request that lacks a JWT. The
  SDK does not log this.
- **Fix:** Set `config.authHandler` on `IterableConfig` to a function that
  returns a Promise resolving to a freshly minted JWT from the app's server.
  If the user provides an API key **and** a JWT secret, treat the secret as a
  signal that JWT is on and never skip the handler. Never sign JWTs in the
  app — mint them server-side. See `reference/authentication.md`.

## 2. EU customer hitting US endpoint

- **Symptom:** Calls succeed but data never appears in the customer's
  Iterable dashboard. Customer is in the EU project.
- **Cause:** The SDK defaults to the US data region. EU projects refuse the
  data but the SDK doesn't know that and doesn't error.
- **Fix:** Set `config.dataRegion = IterableDataRegion.EU`. Always confirm
  region with the developer during integration if their Iterable URL is
  `app.eu.iterable.com`. See `reference/installing.md`.

## 3. POST_NOTIFICATIONS permission not requested on Android 13+

- **Symptom:** Tokens register, dashboard sends pushes, but nothing appears
  on Android 13+ devices. Older devices and iOS work.
- **Cause:** Android 13 (API 33) introduced runtime `POST_NOTIFICATIONS`
  permission. Without a granted permission, the OS silently suppresses every
  notification — including Iterable's. No error in the JS SDK.
- **Fix:** This is native Android configuration, still required from a React
  Native app. Follow `reference/push-notifications.md` (and, for Expo,
  `reference/expo.md`) for the project workflow in front of you. Request the
  permission from a user-facing screen, not at module load. Do not copy
  Android `ActivityResultContracts` snippets into JavaScript — wire them in
  the Android project (bare) or via the Expo plugin (Expo).

## 4. Native Android or iOS APIs used as if they were JavaScript

- **Symptom:** TypeScript does not compile, or a plausible method name is
  called and does nothing, or the agent writes `IterableApi.getInstance()` /
  Kotlin / Swift into a `.ts` / `.tsx` file.
- **Cause:** The React Native SDK is a thinner JavaScript layer over the
  native Android and iOS SDKs. Methods that exist natively are absent from
  the bridge. Open gaps of this kind include device-attribute management
  (SDK-593) and a supported TS wrapper for `getUnreadInboxMessagesCount`
  (SDK-594). An agent reaching for the native API invents a method that
  never existed in JS, or tells the developer to call the native module
  directly.
- **Fix:** Only call APIs exported by `@iterable/react-native-sdk`. If a
  method is not in this skill's `reference/` docs, it is not a JS API —
  do not invent it, do not import it from `com.iterable:iterableapi` or
  the Swift SDK, and do not instruct the developer to call
  `NativeRNIterableAPI` directly. Native *configuration* (FCM, APNs,
  entitlements, `POST_NOTIFICATIONS`) is still required; it is not a JS
  method call. See `reference/overview.md` and the feature slug for the task.
