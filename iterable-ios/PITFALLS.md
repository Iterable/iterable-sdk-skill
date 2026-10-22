# Iterable iOS SDK — Agent Pitfalls

Silent failures: integrations that build, and often look right in the
Simulator, but never identify the user, never register a token, never show a
notification, or fail only once signed for real devices. The hot-path rules
live in `SKILL.md`; read this file when implementing or diagnosing the matching
behavior.

Each entry was checked against the Iterable Swift SDK source (6.7.5), Apple's
documentation, or Iterable's documentation corpus in `reference/`.

Ids are stable: an entry that turned out to be one benchmark app's policy is
left as a one-line stub pointing at where it moved.

## 1. The token's push environment has no matching Iterable credential

- **Symptom:** Debug builds receive pushes but TestFlight or App Store builds
  don't, or the reverse. A dashboard Test Push reports an invalid token.
- **Cause:** A development-signed build gets a sandbox token, and the SDK
  registers it as sandbox (`pushPlatform = .auto` reads `aps-environment` from
  the embedded profile; the Simulator is always sandbox). TestFlight and App
  Store builds are signed for production. The Iterable iOS app keeps **Sandbox**
  and **Production** push credentials separately, and a send only works when
  the environment of the token has a credential.
- **Fix:** Configure the credential for every environment you ship to — a
  `.p8` key works for both. Test TestFlight against the production setup.
  Leave the entitlements file at `development`; Xcode signs distribution builds
  with `production` from their profile. Don't override `pushPlatform` to hide a
  signing problem.

## 2. Moved to eval: The active user at tap time is treated as the notification recipient

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 3. Moved to eval: A notification permission callback mutates the next user's session

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 4. A direct Test Push is used to claim logout or targeting works

- **Symptom:** A push sent to a copied device token still arrives after logout,
  so `logoutUser()` looks broken — or a direct delivery is taken as proof that
  the user is associated with the device.
- **Cause:** The dashboard's **Test Push** targets the APNs token itself and
  bypasses the user profile.
- **Fix:** Use Test Push only to prove the credential, environment, Bundle ID,
  and token. Prove identity association, logout, and account switching with a
  user-targeted send.

## 5. No safe way to distinguish APNs failure from Iterable registration failure

- **Symptom:** No device appears on the user in **Audience > Contact Lookup**,
  and nobody can tell whether iOS produced a token at all.
- **Cause:** The app forwards the token but surfaces nothing, and production
  logs rightly avoid complete tokens.
- **Fix:** Implement and log `didFailToRegisterForRemoteNotificationsWithError`.
  Check Contact Lookup for the device first. If a token is still needed, expose
  it only in a DEBUG-only diagnostic kept in memory until requested, compiled
  out of Release. Never commit, screenshot, or persist the complete token. For
  a copy action, see pitfall 6.

## 6. General pasteboard token copy is described as non-persistent

- **Symptom:** A DEBUG screen says the APNs token is memory-only or
  non-persistent, but its copy action assigns the complete value to
  `UIPasteboard.general.string`.
- **Cause:** The general pasteboard can keep the item after the app interaction
  and can sync it through Universal Clipboard.
- **Fix:** Prefer the token shown in Contact Lookup. If you offer a copy, use
  `UIPasteboard.general.setItems(_:options:)` with `.localOnly: true` and a
  short `.expirationDate`, tell the developer the clipboard is temporary, and
  clear it after use when practical.

## 7. Moved to eval: Launch or action handling bypasses recipient validation

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 8. Moved to eval: SwiftUI `onOpenURL` enters a trusted personalized route

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 9. A skipped SDK initialization leaves an Apple callback unfinished

- **Symptom:** The app builds and runs without an API key, but a notification
  tap or a silent push leaves the system completion handler pending.
- **Cause:** Before `initialize`, `IterableAppIntegration.userNotificationCenter`
  stores the response for later and does not call the completion handler, and
  `IterableAppIntegration.application(_:didReceiveRemoteNotification:…)` has no
  implementation to call. If initialization never happens, neither completes.
- **Fix:** Track whether initialization ran. When it didn't, call the original
  completion handler directly, as the canonical app delegate does.

## 10. Privacy copy lists only app-selected fields as all Iterable data

- **Symptom:** The app says Iterable receives only the profile fields and events
  it chose to send.
- **Cause:** The copy omits the identity itself, SDK-managed device
  registration (token plus device, app, OS, and notification-state metadata),
  and standard push and in-app engagement events.
- **Fix:** Describe app-supplied fields separately from SDK-managed data, and
  keep local logout distinct from server-side deletion.

## 11. XcodeGen writes Push capability metadata as a string

- **Symptom:** In an XcodeGen project, entitlements are present but the
  generated `project.pbxproj` has a quoted `SystemCapabilities` value or no Push
  capability marker.
- **Cause:** Some XcodeGen versions stringify nested target attributes instead
  of emitting the PBX dictionary Xcode expects.
- **Fix:** Inspect the generated `project.pbxproj`. Prefer a generator
  representation that emits the dictionary; otherwise run
  [`assets/normalize-xcodegen-push-capability.rb`](assets/normalize-xcodegen-push-capability.rb)
  after generation — it rewrites only the known malformed shape and fails on
  anything else. The entitlement and background mode stay the functional
  inputs; the marker does not prove signing.

## 12. The notification-center delegate is never assigned, or assigned late

- **Symptom:** Tapping a push opens the app but no push open is tracked and
  no deep link runs — always, or only when the app was not running. Foreground
  pushes never show a banner.
- **Cause:** `IterableAppIntegration.userNotificationCenter(_:didReceive:…)`
  only runs if the app's `UNUserNotificationCenterDelegate` calls it. Apple
  requires the delegate to be set before
  `application(_:didFinishLaunchingWithOptions:)` returns; set later (from
  SwiftUI `onAppear`, after login, from a lazily created object), the response
  that launched the app is never delivered. Without `willPresent`, iOS shows
  nothing while the app is in the foreground.
- **Fix:** Assign `UNUserNotificationCenter.current().delegate` in
  `didFinishLaunching`, from an object that already exists, and implement both
  `willPresent` and `didReceive`. Anything the response path needs must exist
  before launch returns.

## 13. Moved to eval: Restored profile fields are dropped before SDK initialization

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 14. Moved to eval: Notification permission exists only in a settings screen

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 15. Moved to eval: URL routing reads observable session state off the main actor

Benchmark-app policy, not a general rule: [`eval/scenarios/ios-benchmark.md`](../eval/scenarios/ios-benchmark.md).

## 16. Simulator support is confused with local notification injection

- **Symptom:** The integration demands a physical iPhone for every development
  test, or claims Iterable or APNs delivery after `xcrun simctl push`.
- **Cause:** Older guidance treats every Simulator notification as local. Since
  Xcode 14, an iOS 16+ Simulator on macOS 13+ on an Apple silicon or T2 Mac
  registers with the APNs **sandbox** and receives real remote notifications.
  `simctl push` and `.apns` files are a separate local injection path: they
  reach the same app callbacks but never touch APNs or Iterable, and don't run
  service extensions.
- **Fix:** Name the proof target and transport explicitly. Development proof can
  use an eligible Simulator or a physical iPhone; production and TestFlight
  need a physical iPhone. Use `iterable-ios-verify` for delivery proof, and
  never relabel local injection as remote delivery.

## 17. A JWT-enabled key with no `IterableAuthDelegate`

- **Symptom:** The app initializes and identifies the user, but nothing appears
  in Iterable: no profile updates, no events, no device. Requests fail with
  401.
- **Cause:** JWT is selected by default when a client-side key is created and
  cannot be turned off afterwards. With no `config.authDelegate`, the SDK sends
  requests without a JWT and Iterable rejects them.
- **Fix:** Ask whether the key is JWT-enabled before writing code. If it is,
  implement `IterableAuthDelegate`, keep it strongly referenced, assign it before
  `initialize`, and fetch the current user's token from the team's backend.
  Never sign tokens in the app — the shared secret would ship in the binary. If
  no token endpoint exists, report that as a blocker.

## 18. A delegate assigned inline is deallocated

- **Symptom:** Deep links from push or in-app messages do nothing (or open in
  Safari), custom actions never fire, or a JWT key behaves as if no auth
  delegate exists.
- **Cause:** `IterableConfig.urlDelegate`, `customActionDelegate`,
  `authDelegate`, and `unknownUserHandler` are `weak`.
  `config.urlDelegate = DeepLinkHandler()` is released as soon as the statement
  ends.
- **Fix:** Store each delegate in something that lives as long as the app — the
  app delegate, or a `static let` as in the canonical integration — and assign
  that reference.

## 19. A SwiftUI app has no app-delegate adaptor

- **Symptom:** A SwiftUI app compiles with Iterable calls in `init()` or
  `onAppear`, but no device ever appears on the user in Iterable and taps are
  never tracked.
- **Cause:** Without `@UIApplicationDelegateAdaptor`, a SwiftUI app has no
  `UIApplicationDelegate`, so `didRegisterForRemoteNotificationsWithDeviceToken`
  has nowhere to land, launch options never reach `initialize`, and there is no
  place to assign the notification-center delegate in time.
- **Fix:** Declare `@UIApplicationDelegateAdaptor(AppDelegate.self)` once, in
  the `App` struct, and put initialization, token forwarding, and the
  notification-center delegate in that `AppDelegate`.

## 20. `register(token:)` runs before an identity is set

- **Symptom:** The token callback fires and calls `IterableAPI.register(token:)`,
  yet the user has no device in Iterable.
- **Cause:** `IterableAPI.register(token:onSuccess:onFailure:)` begins with
  `guard let implementation, implementation.isSDKInitialized() else { return }`,
  and `isSDKInitialized()` is `!apiKey.isEmpty && isEitherUserIdOrEmailSet()`
  — a non-empty API key **and** a non-empty email or user ID
  ([IterableAPI.swift#L321](https://github.com/Iterable/iterable-swift-sdk/blob/6.7.5/swift-sdk/SDK/IterableAPI.swift#L321),
  [InternalIterableAPI.swift#L887-L899](https://github.com/Iterable/iterable-swift-sdk/blob/6.7.5/swift-sdk/Internal/InternalIterableAPI.swift#L887-L899)).
  Before that, the call returns with only an info-level log, neither callback
  runs, and the token is not kept. This bites apps that set
  `autoPushRegistration = false` and call `registerForRemoteNotifications()` at
  launch, before sign-in. `track(event:)` and `updateUser` before an identity
  also fail (their `onFailure` runs) unless Unknown User Activation is on.
- **Fix:** Keep the default `autoPushRegistration = true`: the SDK calls
  `registerForRemoteNotifications()` after `setEmail` / `setUserId` completes
  its login, and at launch when an identity is stored. With manual
  registration, call `registerForRemoteNotifications()` again after
  identifying the user.

## 21. The `aps-environment` entitlement is missing

- **Symptom:** `didFailToRegisterForRemoteNotificationsWithError` fires, or no
  token callback arrives at all; no device appears in Iterable.
- **Cause:** The Push Notifications capability was never added, the
  `.entitlements` file exists but `CODE_SIGN_ENTITLEMENTS` does not point at it
  for the configuration being built, the App ID lacks Push Notifications, or the
  build is unsigned (`CODE_SIGNING_ALLOWED = NO`).
- **Fix:** Add the capability (or the file plus `CODE_SIGN_ENTITLEMENTS` for
  Debug and Release), enable Push Notifications on the App ID, and let signing
  regenerate the profile. Read what was actually signed: for a device build,
  `codesign -d --entitlements - App.app`; for a Simulator build that output is
  empty by design — read the executable's `__TEXT,__entitlements` section
  instead. Always implement the failure callback so this is visible.

## 22. The Bundle ID differs across Xcode, Apple, and Iterable

- **Symptom:** The token registers but sends fail or never arrive; or the device
  appears under an unexpected app in Iterable.
- **Cause:** APNs tokens are per app. The SDK registers the token against a push
  integration named after `Bundle.main.bundleIdentifier` unless
  `pushIntegrationName` is set. A Debug suffix (`com.example.app.debug`), a
  renamed target, or an Iterable app created for a different identifier breaks
  that chain.
- **Fix:** Make `PRODUCT_BUNDLE_IDENTIFIER`, the Apple App ID, and the Bundle ID
  of the Iterable iOS app (and its APNs credential) identical, for every
  configuration you test. Use `pushIntegrationName` only for a legacy
  integration with a custom name.

## 23. Another SDK owns or swizzles the notification callbacks

- **Symptom:** After adding Iterable, an existing provider's pushes stop
  routing, Iterable opens aren't tracked, or a completion handler runs twice.
- **Cause:** There is one notification-center delegate. Firebase Messaging
  swizzles the app delegate's remote-notification callbacks and the
  notification-center delegate unless `FirebaseAppDelegateProxyEnabled` is `NO`
  in Info.plist; OneSignal swizzles `setDelegate:` and wraps `willPresent` and
  `didReceive` on whatever delegate you assign. Both call the original methods
  too. Iterable's two integration methods call the completion handler even for
  payloads that aren't Iterable's.
- **Fix:** Keep the delegate the app already has and branch inside it: forward
  to `IterableAppIntegration` when `userInfo["itbl"]` is present, otherwise to
  the existing handler, so exactly one path completes. Never assign a second
  delegate over the first. Give `IterableAPI.register(token:)` the raw APNs
  token `Data` from `didRegisterForRemoteNotificationsWithDeviceToken`, never
  an FCM registration token.

## 24. No Notification Service Extension, so no images or buttons

- **Symptom:** Pushes arrive with title and body, but the campaign's image,
  video, or action buttons are missing.
- **Cause:** Rich content and action buttons are added on the device by a
  Notification Service Extension. Iterable's `ITBNotificationServiceExtension`
  downloads the attachment and builds a `UNNotificationCategory` from the
  payload's buttons. Without the extension, nothing does. Apple also never runs
  an extension for `simctl push` or for a payload without `mutable-content: 1`.
- **Fix:** Add a Notification Service Extension target with
  `IterableAppExtensions` and subclass `ITBNotificationServiceExtension` (see
  `SKILL.md` → Push notifications). Don't register categories in the app for
  Iterable's buttons. Match the extension's deployment target to the app's.

## 25. A URL scheme is missing from `allowedProtocols`

- **Symptom:** A push, in-app, or Embedded link such as `myapp://item/42`,
  `tel:`, or `http://` does nothing, and the `IterableURLDelegate` is never
  called for it.
- **Cause:** The SDK checks the scheme before it calls the delegate or opens
  anything. Only `https` and the schemes in `config.allowedProtocols` pass, and
  the comparison is case-sensitive (`MyApp` ≠ `myapp`). The gate also applies to
  the destination an `/a/` tracking link resolves to. `action://`, `itbl://`,
  and `iterable://` are custom actions in in-app and Embedded messages only; as
  a push "Open URL" they hit the same gate and are dropped.
- **Fix:** List every scheme links may use — `http`, `tel`, `mailto`, `sms`,
  your own — in lowercase in `config.allowedProtocols` before `initialize`, and
  register your own scheme under `CFBundleURLTypes`. Use a custom action, not an
  `action://` URL, for push.

## 26. Iterable accepts the send, but APNs refuses it with TopicDisallowed

- **Symptom:** Iterable answers the proof or campaign send with HTTP 200, the
  device is registered with a current token, and no notification ever arrives.
  On a Simulator the verifier reports that no push reached it.
- **Cause:** The App ID does not have Push Notifications enabled on the team
  (or the APNs key is restricted to other Bundle IDs). APNs then refuses every
  push for the app with `400 TopicDisallowed`, whichever key signs it, and
  Iterable does not surface that refusal. Proven live: two different keys on the
  same team both got `TopicDisallowed` before Push was enabled on the App ID,
  and both got `200` after.
- **Fix:** Run `ios-verify check-apple`, which asks Apple directly with one
  silent push and names the cause. In Apple Developer → Identifiers, check the
  team selector, open the App ID, tick Push Notifications, Save, and Confirm;
  in Keys, make sure the key is not restricted to other Bundle IDs. Then run
  the check again before sending.

## 27. A link bounces between the SDK and the app

- **Symptom:** Tapping a link loops — the app reopens, the screen flickers, or
  the same URL arrives in `onOpenURL` again and again — or a valid link silently
  goes nowhere.
- **Cause:** `IterableAPI.isIterableDeepLink` only looks for `/a/` followed by
  a letter or digit anywhere in the string, so `myapp://shop/a/42` passes it.
  Sent to `handle(universalLink:)`, that URL's tracking request fails, the SDK
  falls back to the original URL, and if the `IterableURLDelegate` returns
  `false` the SDK calls `UIApplication.shared.open`, which hands a URL on the
  app's own scheme straight back to `onOpenURL`.
- **Fix:** Send a URL to `handle(universalLink:)` only when its scheme is
  `https`, its host is your link-tracking domain, and `isIterableDeepLink`
  agrees — never a custom-scheme URL. Make the delegate return `true` for every
  URL on your own scheme or domains, sending unknown paths to a fallback screen;
  return `false` only for other apps' URLs.

## 28. A universal-link method "nearly matches" and is never called

- **Symptom:** Universal links open the app but never route, in a UIKit app
  without scenes, and nothing is logged.
- **Cause:** `reference/ios-universal-links.md` declares
  `application(_:continue:restorationHandler:)` with
  `restorationHandler: @escaping ([Any]?) -> Void`. The requirement takes
  `([UIUserActivityRestoring]?) -> Void`, so Swift treats the method as an
  unrelated one — it only warns that it "nearly matches" (and is silent if the
  method sits in an extension) — and UIKit never calls it.
- **Fix:** Use the signatures in `SKILL.md` → canonical step 4 — or better, the
  scene lifecycle: the iOS 26 SDK deprecates both app-delegate URL methods.
  Treat a "nearly matches optional requirement" warning as an error.

## 29. No `registerToken` line in the log is read as no registration

- **Symptom:** After sign-in, the log shows `apsd` handing the app its APNs
  token and no Iterable `registerToken` line, so the agent decides the device
  never registered and starts changing working code.
- **Cause:** SDK 6.7.5 logs a successful registration only at debug level
  (`ITBDebug("Device registration succeeded…")`,
  [InternalIterableAPI.swift#L455](https://github.com/Iterable/iterable-swift-sdk/blob/6.7.5/swift-sdk/Internal/InternalIterableAPI.swift#L455)).
  The default `IterableConfig.logDelegate` is
  `DefaultLogDelegate(minLogLevel: .info)`, which drops debug
  ([IterableLogging.swift#L12](https://github.com/Iterable/iterable-swift-sdk/blob/6.7.5/swift-sdk/SDK/IterableLogging.swift#L12)).
  The generic `registerToken succeeded` info line never runs for this call,
  because `register(token:)` passes its own success handler
  ([RequestProcessorUtil.swift#L82-L86](https://github.com/Iterable/iterable-swift-sdk/blob/6.7.5/swift-sdk/Internal/RequestProcessorUtil.swift#L82-L86)).
  A failure is logged at error level, but as the server's reason, without the
  word `registerToken`.
- **Fix:** Read registration from Iterable, not from the log. Run
  `ios-verify status` and act on gate I12, which reads the device record, or
  look for the device in **Audience > Contact Lookup**. Don't add a workaround
  to make a log line appear.
