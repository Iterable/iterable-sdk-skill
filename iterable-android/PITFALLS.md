# Iterable Android SDK — Agent Pitfalls

Silent failures, foot-guns, and "looks fine but is broken" patterns the agent
will hit if it relies on generic SDK intuition. The five in `SKILL.md` are the
hot-path subset; the full list lives here and is loaded on demand.

> Format: each pitfall has **Symptom** (what the developer sees), **Cause**
> (what's actually happening), **Fix** (what to do instead). Skim them when
> the user reports any unexplained failure.

---

## 1. JWT-required API key with no `AuthHandler`

- **Symptom:** Every API call succeeds locally (200 OK from the SDK's
  perspective) but nothing reaches Iterable. No errors, no logs.
- **Cause:** Mobile API keys can be configured server-side to require a JWT.
  When this is on, the SDK silently drops every request that lacks an
  `Authorization: Bearer <jwt>` header. The SDK does not log this.
- **Fix:** Wire up `IterableConfig.Builder().setAuthHandler(...)`. The
  handler must return a freshly minted JWT (see pitfall #3). If the user
  provides an API key **and** a JWT secret, treat the secret as a signal
  that JWT is on and never skip the handler. See
  `features/jwt-authentication.md`.

## 2. `setEmail` inside the init callback

- **Symptom:** First app session works, then every subsequent call fails with
  `AUTH_TOKEN_MISSING`. Reinstalling the app fixes it for one session.
- **Cause:** `IterableApi.initializeInBackground`'s callback runs **before**
  the internal `IterableAuthManager` is ready to accept auth requests.
  Calling `setEmail` there triggers an immediate token request that fails
  and consumes the manager's retry budget. The retry budget never resets
  within the process.
- **Fix:** Call `setEmail` from the login / session-restore flow, wrapped in
  `IterableApi.onSDKInitialized { }`. The init callback should log
  initialization and nothing else.

## 3. Stale email captured in the auth handler lambda

- **Symptom:** After login, JWT auth works. After app restart with a saved
  user, auth fails with `AUTH_TOKEN_NULL`.
- **Cause:** The auth handler closure captured `currentEmail` (or similar)
  at app startup when it was `null`. The SDK calls
  `onAuthTokenRequested()` at unpredictable times — token refresh, retry,
  app foreground — and the captured value is empty or stale.
- **Fix:** Read the email from the source of truth (DataStore /
  SharedPreferences / DB) **inside** the lambda body, every call. Do not
  cache.

## 4. Sequencing with `Handler.postDelayed` / `Thread.sleep`

- **Symptom:** Works on the dev's WiFi, fails on cellular. Or works for
  the first user but fails on slower devices.
- **Cause:** The dev guessed how long JWT authentication takes after
  `setEmail` and used a delay before calling `updateUser` / `track`. Real
  network latency varies by 10x.
- **Fix:** Use the callback-flavored overload:
  `setEmail(email, onSuccess, onFailure)`. Chain dependent calls inside
  `onSuccess`. The SDK always provides a proper callback for ordering.

## 5. Custom deep-link scheme dropped silently

- **Symptom:** Iterable push opens the app, but the URL never reaches the
  app's `UrlHandler`.
- **Cause:** The SDK's default allowed-protocols list is `https` and
  `http`. A custom scheme like `myapp://` is rejected before the handler
  fires.
- **Fix:**
  `IterableConfig.Builder().setAllowedProtocols(arrayOf("myapp"))`. The list
  is additive — `http`/`https` stay allowed automatically.

## 6. `registerForPush()` called explicitly with auto-registration on

- **Symptom:** Token registered twice, dashboard shows duplicate device
  records, or registration race conditions cause some pushes to misroute.
- **Cause:** `IterableConfig.Builder().setAutoPushRegistration(true)` (the
  default) already registers the token on every `setEmail` / `setUserId`.
  Calling `registerForPush()` manually duplicates the work.
- **Fix:** Remove the explicit call. Trust `setAutoPushRegistration(true)`.
  Only call `registerForPush()` manually if auto-registration is explicitly
  disabled and the app handles the lifecycle itself.

## 7. POST_NOTIFICATIONS permission not requested on Android 13+

- **Symptom:** Tokens register, dashboard sends pushes, but nothing appears
  on Android 13+ devices. Older devices work.
- **Cause:** Android 13 (API 33) introduced runtime `POST_NOTIFICATIONS`
  permission. Without a granted permission, the OS silently suppresses
  every notification — including Iterable's. No error in the SDK.
- **Fix:** Request `Manifest.permission.POST_NOTIFICATIONS` from a
  user-facing screen (onboarding, the first push-relevant feature). Don't
  request it from `Application.onCreate` — it's a no-op without an
  Activity context.
- **Minimum viable flow** (when the app has no permission framework of its
  own): declare `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>`
  in the manifest, then from the first relevant Activity, on API 33+, launch a
  `registerForActivityResult(ActivityResultContracts.RequestPermission())` for
  that permission — ideally after onboarding, not cold on first launch. If the
  app already has a permission helper (e.g. a `PermissionHelper`), wire into it
  rather than adding a parallel one.

## 8. EU customer hitting US endpoint

- **Symptom:** Calls succeed but data never appears in the customer's
  Iterable dashboard. Customer is in the EU project.
- **Cause:** SDK defaults to US data region. EU projects refuse the data
  but the SDK doesn't know that and doesn't error.
- **Fix:** `IterableConfig.Builder().setDataRegion(IterableDataRegion.EU)`.
  Always confirm region with the developer during integration if their
  Iterable URL is `app.eu.iterable.com`.

## 9. Push integration name mismatch

- **Symptom:** Token registers (visible in `setEmail` logs) but Iterable
  dashboard shows "no push tokens for this user."
- **Cause:** `IterableConfig.Builder().setPushIntegrationName("...")` must
  match the Push Integration record in the Iterable dashboard **exactly**,
  including casing. Defaults to `context.getPackageName()` if unset — fine
  if that matches the dashboard, broken if not.
- **Common cause — `applicationIdSuffix`:** debug builds very often use
  `applicationIdSuffix ".debug"`, so the debug variant's package is
  `com.example.app.debug` while release is `com.example.app`. Since the
  default integration name *is* the package name, debug and release resolve to
  **different** integration names — which means they need either separate
  Iterable push integrations (and separate `package_name` entries in
  `google-services.json`) or an explicit `setPushIntegrationName(...)` per
  build type. A token registered under `...app.debug` won't show up against the
  release integration.
- **Fix:** Ask the developer what the integration is called in the Iterable
  dashboard. Don't assume it's the package name. If the project has an
  `applicationIdSuffix`, decide explicitly: separate integrations per variant,
  or a fixed `setPushIntegrationName` shared across them.

## 10. Embedded placements not loading

- **Symptom:** `IterableEmbeddedView` renders empty. No errors.
- **Cause:** Placement IDs are auto-generated by Iterable when the dashboard
  user creates a placement. The agent cannot guess them; using a sample ID
  or a string the developer "made up" will fetch nothing.
- **Fix:** Ask the developer for the placement IDs (they're 6-digit
  numbers in the dashboard). Also confirm
  `IterableConfig.Builder().setEnableEmbeddedMessaging(true)` is set.

## 11. Logout not clearing the SDK

- **Symptom:** After logout, the previous user's push tokens still receive
  notifications targeted at the new (logged-out) state.
- **Cause:** App cleared its own session but never told the SDK.
- **Fix:** `IterableApi.getInstance().setEmail(null)` (or `setUserId(null)`)
  **before** clearing app-side auth state. Order matters — if app session
  is gone first, your auth handler can't generate a token to deregister
  cleanly.

## 12. Mixing `setEmail` and `setUserId` on the same user

- **Symptom:** Same human shows up as two different users in Iterable.
- **Cause:** Identifying the same person sometimes with `setEmail` and
  sometimes with `setUserId` creates two separate records unless the
  Iterable project is configured for cross-channel identity resolution.
- **Fix:** Pick one identification mode per app and stick with it. If the
  project requires both, set both on the same user atomically and confirm
  the Iterable project has identity resolution enabled.

## 13. Calling SDK before `onSDKInitialized` when using
`initializeInBackground`

- **Symptom:** Sporadic `IllegalStateException` or no-op calls on cold start.
- **Cause:** `initializeInBackground` returns immediately; the SDK isn't
  ready yet.
- **Fix:** Wrap every SDK call that may run during cold start in
  `IterableApi.onSDKInitialized { ... }`. The block runs immediately if the
  SDK is already initialized, otherwise queues until init completes.

## 14. Treating `IterableConfig` as a singleton you can mutate

- **Symptom:** `setDataRegion` / `setAllowedProtocols` "doesn't take effect"
  after init.
- **Cause:** `IterableConfig` is consumed at init time. Mutating the builder
  later has no effect. The SDK does not pick up changes.
- **Fix:** Build the full config before calling `initializeInBackground`.
  Configuration is immutable post-init.

## 15. Multi-module Android project: SDK in the wrong module

- **Symptom:** Build succeeds, but `IterableApi` symbol is missing at
  runtime, or the `google-services` plugin reports "no google-services.json
  found."
- **Cause:** Dependencies and the `com.google.gms.google-services` plugin
  were added to a library module (or the root project) instead of the
  module with `com.android.application`.
- **Fix:** Find the `app` module (check `settings.gradle(.kts)` — it may not
  be named `app/`). Add Iterable + Firebase dependencies and the
  `google-services` plugin there. Place `google-services.json` in the same
  module's directory.

## 16. API key hardcoded into a tracked file

- **Symptom:** Two flavors. (a) The key gets committed and pushed — on a
  public repo it's now leaked. (b) The key injection looks wired up but
  doesn't work: a `buildConfigField` reads a Gradle property, yet the build
  still uses a baked-in literal.
- **Cause:** The integration wrote the literal key as the default of a
  property lookup — `getPropertyIfDefined('ITERABLE_API_KEY', '<literal>')` —
  and/or the property name doesn't match the one in `local.properties`, so the
  lookup silently falls through to the literal. A *mobile* key in the compiled
  app is fine; a key in **source control** is the defect.
- **Fix:** Keep the real key only in a gitignored file (`local.properties`) and
  load that file **explicitly** — this is the part that's easy to miss:
  **`local.properties` is NOT exposed as Gradle project properties.** A
  project's existing `getPropertyIfDefined`/`hasProperty`-style helper (or the
  `OPEN_EXCHANGE_RATES_API_KEY` pattern many repos already have) *looks* like
  it reads `local.properties` but does not — it only sees `gradle.properties` /
  `-P` flags, so it silently yields an empty key. Read the file yourself with
  `Properties()`:
  ```groovy
  def getSecret(property, defaultValue) {
      def f = rootProject.file("local.properties")
      if (f.exists()) {
          def props = new Properties()
          f.withInputStream { props.load(it) }
          def v = props.getProperty(property)
          if (v != null) return v
      }
      return defaultValue   // empty string — NEVER a literal key
  }
  // ...
  buildConfigField "String", "ITERABLE_API_KEY", "\"" + getSecret('ITERABLE_API_KEY', "") + "\""
  ```
  (Groovy scoping gotcha: a `def` script variable is not in scope inside a
  `def` method — read the file *inside* the method, as above.)
- **Secondary flavor — literal fallback:** never leave the key as the default
  of the lookup (`getSecret('ITERABLE_API_KEY', '<literal>')`). On a public
  repo that commits the key; an **empty** fallback is the only acceptable
  default. Match the property name to what the project already uses. Verify the
  key is a **mobile** key (Iterable dashboard → API keys); a server-side key in
  an app exposes all project data. Confirm the file holding the key is
  gitignored before building.

## 17. Guessing the user identifier (e.g. a license/account email)

- **Symptom:** Code compiles and runs, the SDK initializes, but users never
  appear in Iterable — or only a tiny fraction do. No in-app messages display;
  push targeting matches no one.
- **Cause:** The integration assumed an identifier by grabbing the first
  email-shaped field in the app (a license email, account email, etc.). For
  most users that field is `null`, so `setEmail(null)` runs and the user is
  never identified. Identity source cannot be inferred from the codebase.
- **Fix:** Ask the developer two things: which identifier (`setEmail` vs
  `setUserId`) and where its value comes from. If there's no real account
  system, a stable per-install `userId` (a persisted UUID) is a common answer.
  Identify from the login/restore flow inside `IterableApi.onSDKInitialized { }`,
  never in the init callback (pitfall #2). Use one mode consistently (pitfall
  #12).

## 18. `initializeInBackground` overload — config in the callback slot

- **Symptom:** Build fails with a type mismatch on the `config` argument, or
  (worse) the project compiles but the config is silently ignored. Kotlin
  trailing-lambda syntax can mask which overload you actually hit.
- **Cause:** There are **two** `initializeInBackground` overloads, and the
  3-arg one's third parameter is a **callback, not config** (verified against
  the 3.7.0 AAR):
  ```
  initializeInBackground(Context, String, IterableInitializationCallback)
  initializeInBackground(Context, String, IterableConfig, IterableInitializationCallback)
  ```
  The synchronous `initialize(context, key, config)` is 3-arg with config
  third, which primes you to write `initializeInBackground(context, key, config)`
  — but that binds `config` to the callback slot.
- **Fix:** Always pass config to the **4-arg** overload, with the callback
  last:
  ```kotlin
  IterableApi.initializeInBackground(context, apiKey, config) {
      // init complete (this trailing lambda is the 4th arg)
  }
  ```
  If you have no init work, still use the 4-arg form with an empty lambda —
  do not drop to the 3-arg overload, which has no config parameter at all.

## 19. Faking a missing prerequisite to keep the build green

- **Symptom:** The integration "compiles" but ships a broken or misleading
  state: a placeholder `google-services.json`, the `google-services` plugin
  commented out, a hardcoded/empty API key, identity wired to a guessed field,
  or an unresolved call silently deleted. Push never arrives; the developer
  believes the work is done.
- **Cause:** The agent treated "make it compile" as the goal and worked around
  a missing developer-supplied input instead of asking for it. The
  `com.google.gms.google-services` plugin in particular **fails the build
  without a valid `google-services.json`** ("Missing project_info"), so the
  tempting workarounds are a fake JSON or disabling the plugin — both leave a
  non-functional push setup that looks complete.
- **Fix:** Treat the inputs in the skill's **Preflight** section as
  prerequisites, not blockers to route around. `google-services.json` is
  project-specific and comes from the developer's Firebase Console — you cannot
  generate it. When it (or any preflight input) is missing: **stop that part of
  the work, tell the developer exactly what you need and why, and leave the
  rest of the integration in a clean, un-faked state.** An honest "push is
  wired but needs your `google-services.json` to build" beats a green build
  that silently does nothing. Never commit a placeholder; never disable a
  required plugin to compile.

## 20. Link tap routed to a handler that isn't set (silently dropped)

- **Symptom:** A push notification (or in-app / embedded message) opens the
  app but never navigates — the deep link silently does nothing. A registered
  `urlHandler` is never called for these taps.
- **Cause:** Iterable routes an action by its **type / URL scheme**, not
  through one catch-all handler. Plain `http`/`https` links (and push actions
  of type `openUrl`) go to `IterableConfig.urlHandler` → `handleIterableURL()`.
  Links whose scheme is `action://` or `itbl://`, **and push actions whose
  type is a custom action**, go to `IterableConfig.customActionHandler` →
  `handleIterableCustomAction()`. (`iterable://` URLs are SDK-reserved and
  handled internally.) If the handler an action routes to has **not** been set,
  the action is silently dropped — no crash, no log. So an integration that
  registers only `urlHandler` looks complete but loses every custom-action
  link; "opens the app but doesn't navigate" is the only symptom.
- **Fix:** Register **both** `urlHandler` and `customActionHandler` on
  `IterableConfig`, unless you've confirmed the dashboard only ever sends
  `openUrl` / plain-URL actions. Don't assume one handler catches everything.
  When a link opens the app but doesn't navigate, suspect a missing
  `customActionHandler` first — the dashboard template likely carries the link
  in the action *type* rather than as an `openUrl`.
