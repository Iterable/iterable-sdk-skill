# Iterable React Native SDK — Agent Pitfalls

Silent failures, foot-guns, and "looks fine but is broken" patterns the agent
will hit if it relies on generic SDK intuition or copies native Android/iOS
APIs into JavaScript. The hot-path subset is in `SKILL.md`; the full list
lives here and is loaded on demand.

> Format: each pitfall has **Symptom** (what the developer sees), **Cause**
> (what's actually happening), **Fix** (what to do instead). Skim them when
> the user reports any unexplained failure.

Sourced from `@iterable/react-native-sdk` **3.2.1** (first written against
3.1.0): public exports in
`src/index.tsx`, the TurboModule spec in `src/api/NativeRNIterableAPI.ts`,
CHANGELOG 3.1.0–3.2.1, the README native-version table, and the working sample in
`example/` (`example/src/hooks/useIterableApp.tsx`,
`example/src/components/App/App.tsx`). Expo items also come from
`@iterable/expo-plugin` 1.1.0 (`plugin/src/withIterable.ts`) and
`reference/expo.md`.

**How to read this list.** #1–6 are JavaScript / runtime traps. They apply
to **every** React Native app, including Expo. #7–11 and #13–#14 are Expo
config-plugin traps (build-time and configuration-time). Use them only
after Step 0 classified the project as Expo. **#12** is Xcode **27** on
iOS (bare **and** Expo): Device Hub launch and resource-bundle compile
floors — not an Iterable API change. **#15** is native Android and applies
to **both** workflows, but only when the app already sends push. #3 is
both workflows, and both request the permission at runtime with
`PermissionsAndroid`; only its **bare** manifest edit is wrong on Expo, where
the plugin declares it — branch first. **#16** applies to every
app with deep links; **#17** is Expo only. **#18** is the install, both
workflows. **#19–#20** are the iOS Release Simulator build (bare, and Expo when
built with `xcodebuild`); **#21** is JavaScript, both workflows; **#22** is bare
iOS (on Expo, #14).

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
- **Note:** assume JWT is on unless the developer says otherwise. It is
  selected **by default** when a client-side key is created, and the choice
  cannot be changed afterwards — a new key is the only way to switch. If they
  have a JWT key but no token endpoint yet, that is a blocker to raise, not
  something to work around by signing locally.

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
    #7–#11, #13–#14). Point `expo.android.googleServicesFile` at the
    developer-supplied
    `google-services.json`. The plugin declares `POST_NOTIFICATIONS` in the
    manifest but never requests it, so the app still asks at runtime —
    `PermissionsAndroid.request(PermissionsAndroid.PERMISSIONS.POST_NOTIFICATIONS)`
    from a user-facing screen, as in the bare step 2 below.
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

  Concrete gaps still open on 3.2.1:

  - **Unread inbox count:** `getUnreadInboxMessagesCount` is on the TurboModule spec and
    implemented natively. `IterableInAppManager` exposes `getMessages` /
    `getInboxMessages` / `showMessage` / `setReadForMessage` and **no**
    unread-count wrapper.
  - **Device attributes:** `setDeviceAttribute` is used internally to stamp
    `reactNativeSDKVersion` at init. It is not on the TurboModule spec and
    not on `Iterable`.
  - `logout` is **not** a Spec method. The public call is `Iterable.logout()`
    (the sample also clears identity; `logout()` already calls
    `setEmail(null)` and `setUserId(null)`).
- **Fix:** Only import from `@iterable/react-native-sdk`. Do not import
  `NativeRNIterableAPI`, `RNIterableAPI`, or `IterableApi`. Do not invent
  wrappers for spec-only methods. Until the SDK adds an unread-count
  wrapper, derive an unread count from
  `Iterable.inAppManager.getInboxMessages()` (filter unread) rather than
  calling the native module. Native configuration (FCM, APNs,
  `POST_NOTIFICATIONS`) is still required; it is not a JS method call. See
  `reference/overview.md` and the feature slug for the task.

## 5. Native Android/iOS APIs taken from a newer SDK than this RN package pins

- **Symptom:** The agent copies Kotlin/Swift from the Android skill (or
  "latest Android SDK") into a React Native project, or tells the developer
  to bump `com.iterable:iterableapi` independently of `@iterable/react-native-sdk`.
- **Cause:** Each RN release **pins** the native SDKs. They are not "whatever
  the native skills currently document." At 3.2.1, `android/build.gradle` is
  `com.iterable:iterableapi:3.10.1` and the podspec depends on
  `Iterable-iOS-SDK` **6.7.5**. APIs that exist only on a newer native SDK are
  not reachable through this RN package, and the native skills' pins can be
  older or newer than the package's.
- **Fix:** Use the RN package's version table (README "Version mapping"), not
  the Android skill. Confirm the installed pin in
  `node_modules/@iterable/react-native-sdk` (`android/build.gradle`,
  podspec). Recent rows:

  | RN SDK | Android SDK | iOS SDK |
  |---|---|---|
  | 3.2.1 / 3.2.0 | 3.10.1 | 6.7.5 |
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

Pitfalls 7–11, 13, 14 and 17 apply only when Step 0 detected Expo; #12 is
Xcode 27 on both workflows. Skip the Expo ones on a bare React Native
project. Do not introduce `@iterable/expo-plugin` there.

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
  **3.2.1**), `@iterable/expo-plugin` **1.1.0** (npm's 1.2.0 is deprecated as
  published by accident). Install with
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

## 12. Xcode 27: Device Hub launch and resource-bundle deployment targets

iOS only (bare **and** Expo); Android is unaffected. This is the single home of
the Xcode 27 guidance — the generated `reference/` corpus does not carry it.

- **Symptom (launch):** On Xcode 27, `npx react-native run-ios` or Expo
  `run:ios` fails before or during simulator launch, often with a missing
  `Simulator.app` / simulator launch error. `open -a Simulator`, AppleScript
  `id of app "Simulator"`, or paths under
  `…/Xcode.app/Contents/Developer/Applications/Simulator.app` do not work.
  Pointing `xcode-select` at Xcode 27 is not enough when the CLI still targets
  the old Simulator app.
- **Cause (launch):** Xcode 27 ships the simulator UI as **Device Hub**
  (`DeviceHub.app`, bundle id `com.apple.dt.Devices`), not
  `Developer/Applications/Simulator.app`. Older `@react-native-community/cli`
  versions still open the removed app.
- **Fix (launch):**
  - **Bare:** Use `@react-native-community/cli` **≥ 20.2.0** (and matching
    `@react-native-community/cli-platform-ios`). Iterable's RN SDK **example**
    app may still pin **20.1.0** until its repo updates — consumer apps need
    **20.2.0+** for Xcode 27. See [cli#2806](https://github.com/react-native-community/cli/pull/2806).
  - **Expo:** Use **Expo SDK 58**, whose CLI knows Device Hub. Apps still on
    SDK **55** may fail at launch on Xcode 27; short-term,
    `npx expo@latest run:ios`, or upgrade the Expo SDK — do not hand-edit
    `ios/` for this (pitfall #8).
  - Run `xcode-select -p` and confirm it points at the Xcode you build with
    when several are installed.

- **Symptom (build):** `xcodebuild` fails on Xcode 27 with deployment-target
  errors on CocoaPods **resource bundle** targets — for example
  `Iterable-iOS-SDK-IterableSDKResources` at **12.0**, or `*_resources` pods
  such as async-storage at **13.4**. The message says
  `IPHONEOS_DEPLOYMENT_TARGET` is outside the range the iOS 27 SDK allows
  (**15.0** through the current SDK version).
- **Cause (build):** The Xcode 27 iOS SDK rejects a deployment target below
  **15.0** on **every** target, including generated Pods resource bundles, and
  `pod install` regenerates those values from each podspec. `Iterable-iOS-SDK`
  **6.7.5** — what `@iterable/react-native-sdk` **3.2.1** pins — still declares
  iOS **12.0** in its podspec, and its resource bundle inherits that.
  React Native **0.88**'s `react_native_post_install` lifts every pod's own
  target to at least **15.1** (`updateOSDeploymentTarget`), but not the pods'
  resource-bundle targets, so the bundle stays at 12.0 — the RN SDK 3.2.1
  README says the same. This is a host
  compile-time workaround, not a reason to change Iterable's published iOS
  minimum.
- **Fix (build):** Do **not** hand-edit files under `Pods/`, and don't raise
  `Iterable-iOS-SDK` in the Podfile as the fix.
  - **Bare:** in the host `Podfile`, after `react_native_post_install`, raise
    every Pods target — resource bundles included — that is unset or below
    **15.1**, then re-run `pod install`. **15.0** is the Xcode 27 floor;
    **15.1** matches React Native's own minimum, so nothing is left at exactly
    15.0:

    ```ruby
    post_install do |installer|
      react_native_post_install(installer, config[:reactNativePath], :mac_catalyst_enabled => false)
      installer.pods_project.targets.each do |target|
        target.build_configurations.each do |build_config|
          current = build_config.build_settings['IPHONEOS_DEPLOYMENT_TARGET']
          build_config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.1' if current.nil? || current.to_f < 15.1
        end
      end
    end
    ```

    Keep any existing `{fmt}` C++17 workaround (pitfall #11); this lift is
    separate.
  - **Expo SDK 58:** a fresh `prebuild` normally leaves no Pods target below
    15.0, so no lift is needed. Check rather than assume:
    `grep -h IPHONEOS_DEPLOYMENT_TARGET ios/Pods/Pods.xcodeproj/project.pbxproj | sort -u`.
  - **Older Expo SDKs:** if that check shows a target below 15.0, lift it in an
    **Expo config plugin** at `prebuild` — never by committing `ios/Podfile` or
    patching `Pods/` in a continuous-native-generation workflow. The `{fmt}` fix
    stays with `@iterable/expo-plugin` **1.1.0+** (`withIosFmtWorkaround`,
    pitfall #11); the resource-bundle lift is a host concern until Iterable
    ships a first-party plugin option.

## 13. Expo: EAS signing for `IterableExpoRichPush`

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

## 14. Expo: `requestPermissionsForPushNotifications` defaults to `false`

- **Symptom:** The agent omits the plugin option, expecting iOS to prompt
  for notification permission because the support-doc table says the
  default is `true`. No prompt. Push looks "set up" and never appears.
- **Cause:** Plugin source (`plugin/src/withIterable.ts`) defaults
  `requestPermissionsForPushNotifications` to **`false`**. Bundled
  `reference/expo.md` (and the upstream article) currently list the
  default as `true`. That table is wrong. The option is **iOS-only**.
- **Fix:** Trust the plugin, not the table. Nothing prompts unless the app
  asks. Set `"requestPermissionsForPushNotifications": true` in the plugin
  options whenever push is in scope — the recommended setting; the plugin's app
  delegate then asks at launch until authorized. Don't add a permission package
  for it. If the app already uses `expo-notifications`, it makes itself the
  notification-center delegate and chains the one set before it; confirm
  Iterable push taps still track afterwards. Android 13+ is separate
  (pitfall #3). Do not hand-edit `reference/expo.md` to "fix" the table — the
  next docs refresh will overwrite it. Report the drift against
  `Iterable/iterable-docs`.

---

Pitfall 15 applies to **both** workflows — any app that already sends push.

## 15. Replacing push the app already had

- **Symptom:** After the integration the app's own pushes (order status,
  shipping, security codes) stop arriving, or the developer reports that the
  Iterable work "removed our push implementation." Or the inverse: their pushes
  are fine and nothing from Iterable ever arrives, with no error.
- **Cause:** Many RN apps already have a push channel — `@react-native-firebase/messaging`,
  another vendor SDK, or a hand-written `FirebaseMessagingService` under
  `android/`. On Android, FCM dispatches `com.google.firebase.MESSAGING_EVENT`
  to **one** service. The native Android SDK under this package registers
  `IterableFirebaseMessagingService` at `android:priority="-1"`, *below* an app's
  own service (default 0). Two consequences:
  - Installing the SDK does **not** hijack their service. That part of the fear
    is unfounded.
  - Iterable therefore receives **nothing** until their service forwards to it.
    Registration looks fine, the dashboard reports a send, nothing arrives.

  The damaging failure is an agent "resolving the conflict" to make Iterable
  work — deleting their service, repointing the manifest entry, or adding
  `tools:node="remove"` — which trades a silent Iterable failure for a broken
  transactional channel. That is nearly always the worse trade.

  **The RN corpus does not cover this.** The forwarding contract
  (`IterableFirebaseMessagingService.handleMessageReceived` /
  `handleTokenRefresh`) is documented on the native Android side, not in
  `reference/push-notifications.md`. Don't infer a JS-level API for it — there
  isn't one; it is native Android configuration performed as part of the RN
  integration, like `POST_NOTIFICATIONS` (rule 3).
- **Fix:** Treat the existing service as the integration point.
  - **Bare:** add the two forwarding calls to the Kotlin/Java service already in
    `android/app/src/main/`. `handleMessageReceived` returns `false` for payloads
    that aren't Iterable's, so their existing routing is unaffected. Leave their
    notification channels, grouping and importance alone — product decisions,
    not defects — and verify in the merged manifest under
    `android/app/build/intermediates/merged_manifests/` that their service is
    still the priority-0 entry.
  - **Expo:** do **not** hand-edit `android/` to add it — `prebuild --clean`
    wipes that (pitfall #8). It belongs in a config plugin. If they hand-maintain
    native code, pitfall #9 already says not to add `@iterable/expo-plugin`.
  - If **they** own the receiving service and forward to every provider, that is
    the correct design. Don't invert it to put Iterable on top.
- **Note:** iOS coexistence is a different mechanism entirely — do not assume
  this Android shape transfers. And a missing runtime `POST_NOTIFICATIONS`
  (pitfall #3) breaks *their* push as well as Iterable's on Android 13+, which
  looks exactly like "the Iterable change broke our push." Check the grant
  before accepting that diagnosis, and don't accept a culprit inside your own
  diff without evidence.

## 16. A link bounces between the SDK and the app

- **Symptom:** Tapping a link reopens the app or re-runs the same navigation
  over and over — sometimes only offline.
- **Cause:** With a JS `urlHandler` set, the native side reports every URL as
  handled and passes it to JavaScript (`handleIterableURL` returns `true` on
  Android; the iOS bridge does the same). If the handler then returns anything
  falsy, the SDK's `callUrlHandler` calls `Linking.openURL(url)`. A URL on the
  app's own scheme or tracking domain comes back through the app's `Linking`
  listener, which hands it to `Iterable.handleAppLink`, and round it goes. A
  tracking-link redirect that fails hands the handler the original `/a/` URL,
  so it loops offline too. On both platforms `handleAppLink`'s native check
  only looks for `/a/` followed by letters or digits anywhere in the URL, so a
  custom-scheme URL such as `myapp://shop/a/42` is treated as a tracking link.
- **Fix:** Make `urlHandler` return `true` for every URL on your own scheme or
  domains, the tracking domain included, sending unknown paths to a fallback
  screen; return `false` only for other apps' URLs. Pass a URL to
  `handleAppLink` only when it is `https`, on your tracking domain, with an
  `/a/` path (`isIterableTrackingLink` in `SKILL.md`), and register the
  `Linking` listener only after `await Iterable.initialize(...)`.

## 17. Expo: the plugin does not configure deep links

- **Symptom:** Universal links and App Links open the browser, never the app,
  even though the Expo plugin is installed.
- **Cause:** `reference/expo.md` says the plugin "sets up Universal Links and
  configures associated domains" and "configures App Links and sets up intent
  filters". In 1.1.0 its deep-link step (`plugin/src/withDeepLinks.ts`) only
  sets the main activity's `android:launchMode` to `singleTask`. The article's
  own examples don't help: `applinks:expo.dev` and `applinks:iterable.com` are
  domains the app can't claim, and its intent-filter JSON contains a `//`
  comment and a trailing comma.
- **Fix:** Add `expo.ios.associatedDomains` with `applinks:<your tracking
  domain>` and an `expo.android.intentFilters` entry for `https`, your tracking
  domain, and `pathPrefix` `/a/` with `autoVerify: true` (the JSON in
  `SKILL.md` → Deep links), then re-run prebuild.

## 18. `npm install` returns 401 for `@iterable/*`

- **Symptom:** `npm install @iterable/react-native-sdk` (or
  `npx expo install @iterable/expo-plugin`) fails with `E401 Unauthorized`
  against `npm.pkg.github.com` or another private registry, while every other
  package installs.
- **Cause:** A user-level `~/.npmrc` maps the `@iterable` scope to another
  registry (`@iterable:registry=https://npm.pkg.github.com/`, common on
  machines that also build Iterable's own packages). A scoped mapping beats
  `--registry`, so passing the public registry on the command line doesn't help.
- **Fix:** Confirm the mapping with `npm config get @iterable:registry`. Never
  `cat` `~/.npmrc` or any other credential file to look — it holds the token,
  and printing it puts the token in the transcript. Add a project `.npmrc` with
  `@iterable:registry=https://registry.npmjs.org/`; the project file overrides
  the user one. The public packages need no token. Don't edit the developer's
  `~/.npmrc`.

## 19. iOS: a stale `.app` installed for proof

- **Symptom:** The Simulator runs an app without the latest change — no
  permission prompt, an old bundle — and the verifier judges a build nobody
  meant to test.
- **Cause:** `xcodebuild` without `-derivedDataPath` builds into
  `~/Library/Developer/Xcode/DerivedData`; a `.app` then picked with `find`
  (say, from an old `ios/build`) is whatever was built there last.
- **Fix:** Build with the exact command in `SKILL.md` → Bare iOS
  (`-derivedDataPath build`), install
  `ios/build/Build/Products/Release-iphonesimulator/<App>.app`, and bind it
  through the verifier's **App build** screen, or with
  `ios-prepare-proof restart --confirm --app-path <path>` when a run already
  exists.

## 20. iOS: code signing disabled strips `aps-environment`

- **Symptom:** The Release Simulator build succeeds, the app runs, and no APNs
  token ever registers.
- **Cause:** `CODE_SIGNING_ALLOWED=NO` (with `CODE_SIGNING_REQUIRED=NO`,
  `CODE_SIGN_IDENTITY=""`) skips signing, and a Simulator build gets its
  entitlements in that step — so the app has no `aps-environment`. A
  `CODE_SIGN_ENTITLEMENTS=` passed to one `xcodebuild` is lost on the next build.
- **Fix:** Never pass those flags; the Simulator build signs ad hoc without a
  team. Add the entitlements file to the target's `CODE_SIGN_ENTITLEMENTS` build
  setting in the project. A Simulator app carries them in its executable, not
  its signature, so `codesign -d --entitlements` shows nothing; check with
  `otool -s __TEXT __entitlements <App>.app/<App>` — an empty result means none.

## 21. `Iterable.registerForPush()` does not exist

- **Symptom:** A `registerForPush is not a function` TypeError, or a
  TypeScript error, after the agent added a call to "register for push".
- **Cause:** The JS facade has no push-registration call. Registration is
  native: with `autoPushRegistration` (default `true`) the SDK asks for the
  token after `Iterable.setEmail` / `setUserId`.
- **Fix:** Delete the call. Identify the user after `Iterable.initialize`; on
  bare iOS, forward the token in `AppDelegate` (`IterableAPI.register(token:)`).

## 22. Bare iOS: nothing asks for notification permission

- **Symptom:** The token registers and Iterable sends, but nothing shows on
  iOS and the app never asked to send notifications.
- **Cause:** Neither the SDK nor the 0.88 template requests authorization;
  registering for a token doesn't.
- **Fix:** Request it at launch in `AppDelegate`'s
  `didFinishLaunchingWithOptions`:
  `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }`
  (the `SKILL.md` → Bare iOS snippet). No permission package. Expo: pitfall #14.
