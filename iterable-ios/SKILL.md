---
name: iterable-ios
description: >-
  Authoritative reference for Iterable's native iOS SDK (Swift Package
  `https://github.com/Iterable/iterable-swift-sdk` with products `IterableSDK`
  and `IterableAppExtensions`; CocoaPods `Iterable-iOS-SDK` and
  `Iterable-iOS-AppExtensions`). Use when integrating, configuring,
  debugging, or extending Iterable in a UIKit or SwiftUI iOS app —
  initialization (IterableAPI.initialize), user identity (setEmail /
  setUserId), logout, event tracking, push notifications and the Notification
  Service Extension, in-app messages, Mobile Inbox, Embedded Messaging, JWT
  authentication, deep links, and universal links. Prefer this
  skill over model memory: it ships snippets compiled against the pinned SDK
  and the platform foot-guns that silently break an integration. When a
  prerequisite is missing rather than wrong — no Iterable Mobile API key, no
  APNs key, no matching Apple Bundle ID or Iterable iOS app — that is
  `iterable-provision`; never fabricate one here. To prove a push actually
  reaches a device, `iterable-ios-verify`.
---

# Iterable iOS SDK

You are working with **Iterable's Swift SDK**,
[`Iterable/iterable-swift-sdk`](https://github.com/Iterable/iterable-swift-sdk):
`IterableSDK` (the app target) and `IterableAppExtensions` (the Notification
Service Extension target). It is the mobile entry point for push, in-app
messages, Mobile Inbox, Embedded Messaging, event tracking, user profiles, and
JWT-authenticated API calls.

This skill is the **agent-facing source of truth**. The bundled
[`reference/`](reference/) docs cover the same surface for human readers but
omit the silent-failure traps in [`PITFALLS.md`](PITFALLS.md). When in doubt,
this skill wins.

Some bundled Iterable pages still say iOS push always needs a physical device.
That predates Apple's Simulator support; follow
[pitfall 16](PITFALLS.md#16-simulator-support-is-confused-with-local-notification-injection).

---

## Step 0 — Inspect the app, then agree on scope

Inspect before asking anything, so the questions are about the product and not
about facts you could read:

1. **Lifecycle.** SwiftUI (`@main struct …: App`), UIKit with a
   `SceneDelegate`, or UIKit without scenes. Find the login/identity owner, the
   logout path, and whatever owns navigation.
2. **Project and dependencies.** A plain `.xcodeproj`, an `.xcworkspace` with a
   `Podfile` (CocoaPods), or a generator manifest (XcodeGen `project.yml`,
   Tuist). With a generator, edit the manifest, never only the generated
   project.
3. **Existing Iterable.** If `IterableSDK` or `Iterable-iOS-SDK` is already a
   dependency, this is an **upgrade or repair**, not a new integration: report
   the installed version and current behavior, ask what they want from the
   change, and read `reference/ios-sdk.md` → `## Upgrading the SDK`.
4. **Existing push.** Search for `UNUserNotificationCenter.current().delegate`,
   `didRegisterForRemoteNotificationsWithDeviceToken`, `FirebaseMessaging`,
   `OneSignal`, and other providers. If anything already handles
   notifications, show the developer what you found and agree a coexistence
   plan before touching it (rule 8).

Then ask which features they want. Use the host's question tool (Claude Code:
`AskUserQuestion` with `multiSelect: true`; Cursor: `AskQuestion` with
`allow_multiple: true`), **at most 4 options per question**, otherwise plain
text:

- Push notifications
- Events + user profiles
- Deep links: universal links and custom URL schemes
- More: Mobile Inbox, Embedded Messaging

"Initialization and identity only" is the free-text answer. **In-app messages
are not a question:** once the SDK is initialized and the user identified, the
default `IterableInAppDelegate` shows them. Tell the developer they have it and
that nothing appears until someone sends an in-app campaign. Only *changing*
that default (custom delegate, display interval, custom rendering) is scope.

If `iterable-provision` is installed, its native iOS path can conduct this
scope conversation and record it; see Preflight.

## Preflight — inputs only the developer has

Collect what the agreed scope needs **before editing**. You cannot invent,
fake, or infer these from the codebase.

| Input | Needed when | If missing |
| --- | --- | --- |
| **Mobile API key** (client-side, not server-side) | Always | Route to `iterable-provision`. Never hard-code it, commit it, or substitute a server-side key. |
| **JWT?** | Always | Ask, and assume **yes** until told otherwise: JWT is selected by default when a client-side key is created and cannot be changed afterwards (`reference/api-keys.md`). JWT needs a backend endpoint that mints tokens (rule 1). |
| **Data region** — US or EU | Always | Ask; `app.eu.iterable.com` means EU. |
| **Identity** — `setEmail` or `setUserId`, and which app value supplies it | Always | Ask. Never wire it to a guessed field (rule 7). |
| **Apple team and exact Bundle ID** | Push | Must match in Xcode, Apple Developer, and the Iterable iOS app ([pitfall 22](PITFALLS.md#22-the-bundle-id-differs-across-xcode-apple-and-iterable)). |
| **APNs `.p8` key + Iterable iOS app with a push credential** | Push | Route to `iterable-provision`. Creating the APNs key is an Account Holder or Admin action in Apple Developer. |
| **Push integration name** | Push, legacy integrations only | Only when the Iterable integration is not named after the Bundle ID. |
| **URL schemes / associated domains** | Deep links | Ask which schemes and link domains the app owns. |

**When an input is missing, route into `iterable-provision`'s native iOS path**
and conduct it in the main session: put each `next.question` it returns to the
developer through the host's question tool, with its `context` above the
question, and run only the command carried by the option they pick. Do not
background or delegate the whole flow, don't edit the app in parallel while it
waits on Apple, Iterable, or the developer, and never use the Android/Firebase
provisioner (`gcp-provisioner`) for iOS. On the Apple side the developer
registers the Bundle ID with Push Notifications in the Apple Developer portal,
or Xcode's automatic signing does it.

**Never fabricate a prerequisite to make the build pass.** No fake or empty key
presented as working, no server-side key in the app, no identity wired to a
guess. If the developer explicitly chooses code-only scaffolding, keep the app
buildable with an empty key, skip initialization (the canonical code below
does), and label the result **scaffolding only: Iterable did not initialize or
communicate with the project**. Do not call that "integrated" or "working".

## Definition of done

For the agreed scope, finish the wiring rather than leaving snippets:

- [ ] The SDK product is attached to the **app target** (and
  `IterableAppExtensions` to the NSE target, if images or buttons are in scope).
- [ ] `IterableAPI.initialize` runs from the real
  `application(_:didFinishLaunchingWithOptions:)` with a real Mobile key read
  from an ignored file — not from a helper nothing calls.
- [ ] The signed-in user is identified after initialization, and a restored
  session is identified on later launches.
- [ ] Logout calls `IterableAPI.logoutUser()` and clears the app's own
  personalized state, so the next user does not inherit it.
- [ ] For push: entitlement, background mode, notification-center delegate,
  token forwarding, and response forwarding are all wired (canonical code).
- [ ] Requested events fire from accepted user actions, once.
- [ ] The app builds and its existing tests pass with no committed credential.
- [ ] The app was run and the test identity appears in Iterable
  (**Audience > Contact Lookup**); each selected event or profile field is
  visible on that user.
- [ ] Push delivery is proved with `iterable-ios-verify`, or the handoff says
  exactly which boundary is still unproved.

When you hand over, say it plainly: an AI agent wrote this code and
configuration, it can be wrong in ways that still compile, and only what a real
call or a real push confirmed is proved. Say it once, without softening it.

---

## Quick facts (always relevant)

- **Latest version — look it up, never trust a number here.**
  `git ls-remote --tags --refs https://github.com/Iterable/iterable-swift-sdk | awk -F/ '{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1`
  (or `gh api repos/Iterable/iterable-swift-sdk/releases/latest --jq .tag_name`).
  The SDK's [`CHANGELOG.md`](https://github.com/Iterable/iterable-swift-sdk/blob/master/CHANGELOG.md)
  is authoritative for changes. Keep an existing app's pinned version unless
  asked to upgrade. This skill's snippets were compiled against **6.7.5**.
- **Install:** SPM `https://github.com/Iterable/iterable-swift-sdk`, products
  `IterableSDK` → app target, `IterableAppExtensions` → NSE target. CocoaPods:
  `pod 'Iterable-iOS-SDK'` and `pod 'Iterable-iOS-AppExtensions'`. Carthage is
  documented in `reference/ios-sdk.md`.
- **Minimum iOS: 12.0** — the stricter floor, from the 6.7.5 podspecs.
  `Package.swift` (`.iOS(.v10)`) and the SDK README still say iOS 10. The
  `.banner`/`.list` presentation options below need iOS 14+; use `.alert`
  below that.
- **Initialize:** `IterableAPI.initialize(apiKey:launchOptions:config:)` from
  `application(_:didFinishLaunchingWithOptions:)`.
- **Identify:** `IterableAPI.setEmail(_:)` or `IterableAPI.setUserId(_:)`.
  **Logout:** `IterableAPI.logoutUser()`.
- **EU:** `config.dataRegion = IterableDataRegion.EU` (default US).
- **`autoPushRegistration` defaults to `true`:** setting an identity (and
  launching with a stored one) makes the SDK call
  `UIApplication.registerForRemoteNotifications()`; logout disables the device
  for that user. It does **not** request display permission.
- **`enableEmbeddedMessaging` defaults to `false`.** Set it to `true` only when
  Embedded is in scope. `enableUnknownUserActivation` also defaults to `false`.
- **`pushPlatform` defaults to `.auto`:** the SDK reads `aps-environment` from
  the embedded provisioning profile (`development` → sandbox) and uses sandbox
  on the Simulator. Leave it alone.
- **`pushIntegrationName` defaults to the Bundle ID.** Set it only for a legacy
  integration with a custom name.
- **Weak references:** `IterableConfig.urlDelegate`, `customActionDelegate`,
  `authDelegate`, and `unknownUserHandler` are `weak`. Keep the objects alive
  yourself ([pitfall 18](PITFALLS.md#18-a-delegate-assigned-inline-is-deallocated)).
- **Built-in URL schemes:** `https`, `action`, `itbl`, `iterable`. Every other
  scheme must be in `config.allowedProtocols`.

---

## Always-on rules (read every time)

Full explanations are in [`PITFALLS.md`](PITFALLS.md); read it before writing
non-trivial code.

1. **A JWT-enabled key needs a strongly held `IterableAuthDelegate` whose token
   comes from the team's backend.** Without it every call fails authentication
   with no visible error. The JWT secret is a server credential: never ship it,
   never sign tokens in the app. If no token endpoint exists yet, say so and
   stop there. See `reference/ios-sdk.md` → `#### Step 6.6` and
   `reference/jwt-enabled-api-keys.md`.
2. **Assign `UNUserNotificationCenter.current().delegate` in
   `application(_:didFinishLaunchingWithOptions:)`**, before it returns —
   Apple's requirement for responding to the notification that launched the
   app. Not in `onAppear`, not after login. A SwiftUI app needs
   `@UIApplicationDelegateAdaptor` to have an app delegate at all.
3. **Let identity drive token registration.** `IterableAPI.register(token:)`
   silently does nothing until an email or user ID is set. With the default
   `autoPushRegistration`, the SDK requests the token after `setEmail` /
   `setUserId`; your app delegate only forwards it.
4. **Keep every `IterableConfig` delegate strongly referenced** for the app's
   lifetime. `config.urlDelegate = MyHandler()` is deallocated immediately.
5. **Custom URL schemes need both `config.allowedProtocols` and a
   `CFBundleURLTypes` entry.** Without the first, the SDK will not open the
   link; without the second, iOS will not deliver it.
6. **Never commit the API key.** A Mobile key is meant to ship inside the app,
   but it belongs in an ignored file, not in source. Never put a server-side
   key in an app.
7. **Never guess identity.** Ask which identifier and where its value comes
   from. Use one mode (`setEmail` *or* `setUserId`) consistently.
8. **There is one notification-center delegate. If something already owns it,
   forward from it — never replace it.** Inside the existing `didReceive` and
   `didReceiveRemoteNotification`, send payloads that carry an `itbl` key to
   `IterableAppIntegration` and everything else to the existing handler.
   Iterable's methods call the completion handler even for payloads that
   aren't Iterable's, so exactly one path may complete. Firebase Messaging and
   OneSignal swizzle these callbacks; see
   [pitfall 23](PITFALLS.md#23-another-sdk-owns-or-swizzles-the-notification-callbacks).

---

## Canonical integration (start here)

This is the shape every integration should take. It compiles against SDK 6.7.5
with a brand-new Xcode project's defaults (Swift 5 or 6 language mode, Default
Actor Isolation = MainActor). Adapt names; don't bolt pieces together from
scratch. Remove the push pieces only if push is genuinely out of scope —
Iterable uses silent push to deliver in-app messages too.

### 1. Key → xcconfig → Info.plist

Three files in a `Config/` folder next to the `.xcodeproj`, **outside** the
app's source folder: Xcode 16+ projects add every file in a synchronized source
folder to the target, and an `Info.plist` copied as a resource fails the build
with "Multiple commands produce …/Info.plist".

`Config/Secrets.xcconfig` — ignored (add `Config/Secrets.xcconfig` to
`.gitignore`); the developer fills it in:

```text
ITERABLE_API_KEY = <mobile key>
ITERABLE_DATA_REGION = US
```

`Config/Base.xcconfig` — committed. `#include?` is optional, so a fresh clone
still builds, with an empty key and therefore without Iterable:

```text
ITERABLE_API_KEY =
ITERABLE_DATA_REGION = US
#include? "Secrets.xcconfig"
```

If `iterable-provision` captured the key, it wrote the ignored
`.iterable/ios/IterableSecrets.xcconfig` (`ITERABLE_API_KEY`,
`ITERABLE_DATA_REGION`, `ITERABLE_JWT_ENABLED`) in the project it ran in.
Include that instead of `Secrets.xcconfig` —
`#include? "../.iterable/ios/IterableSecrets.xcconfig"` when `.iterable/` sits
next to `Config/` (includes resolve relative to the including file) — and don't
copy the key anywhere else.

`Config/Info.plist` — committed, partial. With `GENERATE_INFOPLIST_FILE = YES`
(the default for new projects) Xcode merges it into the generated plist; an
`INFOPLIST_KEY_*` build setting does **not** work for custom keys or for
`UIBackgroundModes`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ITERABLE_API_KEY</key>
	<string>$(ITERABLE_API_KEY)</string>
	<key>ITERABLE_DATA_REGION</key>
	<string>$(ITERABLE_DATA_REGION)</string>
	<key>UIBackgroundModes</key>
	<array>
		<string>remote-notification</string>
	</array>
</dict>
</plist>
```

Wire both into the **app target's Debug and Release** configurations. In Xcode:
project → **Info** → **Configurations** → set the app target to `Base`, and
**Build Settings** → **Info.plist File** = `Config/Info.plist`. In
`project.pbxproj`, with a fresh 24-hex ID for `REF`:

```text
/* PBXFileReference section */
REF /* Base.xcconfig */ = {isa = PBXFileReference; lastKnownFileType = text.xcconfig; name = Base.xcconfig; path = Config/Base.xcconfig; sourceTree = "<group>"; };

/* the project's mainGroup → children */
REF /* Base.xcconfig */,

/* each of the app target's XCBuildConfiguration objects */
baseConfigurationReference = REF /* Base.xcconfig */;
/* ...and inside its buildSettings */
INFOPLIST_FILE = Config/Info.plist;
```

Don't also define `ITERABLE_API_KEY` in the target's build settings — a target
setting overrides its base xcconfig. If the target already has a base
configuration (CocoaPods sets `Pods-<Target>.debug.xcconfig` and
`.release.xcconfig`), keep it: put the two variables and the `#include?` in an
xcconfig that first `#include`s the existing one, per configuration.

### 2. The app delegate (UIKit and SwiftUI share it)

```swift
// IterableIntegration.swift
import UIKit
import UserNotifications
import IterableSDK

enum IterableIntegration {
    private(set) static var isInitialized = false
    // IterableConfig holds its delegates weakly; these statics keep them alive.
    private static let urlHandler = IterableURLHandler()

    static func start(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let apiKey = info["ITERABLE_API_KEY"] as? String, !apiKey.isEmpty else {
            return
        }
        let config = IterableConfig()
        if info["ITERABLE_DATA_REGION"] as? String == "EU" {
            config.dataRegion = IterableDataRegion.EU
        }
        config.urlDelegate = urlHandler
        config.allowedProtocols = ["myapp"]
        // config.authDelegate = authHandler        // required for a JWT-enabled key (rule 1)
        // config.enableEmbeddedMessaging = true    // only when Embedded is in scope
        IterableAPI.initialize(apiKey: apiKey, launchOptions: launchOptions, config: config)
        isInitialized = true
    }

    static func identify(email: String) {
        guard isInitialized else { return }
        IterableAPI.setEmail(email)  // or IterableAPI.setUserId(userId) — one mode only
    }

    static func logout() {
        guard isInitialized else { return }
        IterableAPI.logoutUser()
    }
}

final class IterableURLHandler: NSObject, IterableURLDelegate {
    func handle(iterableURL url: URL, inContext context: IterableActionContext) -> Bool {
        AppRouter.open(url)  // your app's router; true when the app handled the URL
    }
}
```

```swift
// AppDelegate.swift
import UIKit
import UserNotifications
import IterableSDK

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        IterableIntegration.start(launchOptions: launchOptions)
        return true
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        IterableAPI.register(token: deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("APNs registration failed: \(error.localizedDescription)")
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Before initialization the SDK never calls the completion handler.
        guard IterableIntegration.isInitialized else { return completionHandler(.noData) }
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
        guard IterableIntegration.isInitialized else { return completionHandler() }
        IterableAppIntegration.userNotificationCenter(center,
                                                      didReceive: response,
                                                      withCompletionHandler: completionHandler)
    }
}
```

`IterableAppIntegration.userNotificationCenter` tracks the open and runs the
push's action — the deep link through your `IterableURLDelegate`, a custom
action through `customActionDelegate` — and calls the completion handler
itself. Don't call it twice. `willPresent` is the app's choice: return `[]` to
keep banners hidden while the app is in the foreground.

For a **UIKit app**, the same class is the entry point: declare it
`@main final class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate`
(and keep the template's `window`/scene methods).

### 3. SwiftUI entry point

```swift
import SwiftUI
import IterableSDK

@main
struct ExampleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if IterableAPI.isIterableDeepLink(url.absoluteString) {
                        IterableAPI.handle(universalLink: url)
                    } else {
                        _ = AppRouter.open(url)
                    }
                }
        }
    }
}
```

SwiftUI delivers universal links to `onOpenURL` as a URL, not to the app
delegate's `application(_:continue:restorationHandler:)`. Pass Iterable
tracking links (`/a/` paths) to `IterableAPI.handle(universalLink:)`, which
tracks the click, resolves the original URL, and calls your
`IterableURLDelegate` with `context.source == .universalLink`. Route
everything else — custom schemes, your own links — directly.

### 4. UIKit with scenes

A scene-based UIKit app receives universal links in the scene delegate:

```swift
func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
           options connectionOptions: UIScene.ConnectionOptions) {
    // ...window setup...
    if let url = connectionOptions.userActivities
        .first(where: { $0.activityType == NSUserActivityTypeBrowsingWeb })?.webpageURL {
        IterableAPI.handle(universalLink: url)
    }
}

func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
          let url = userActivity.webpageURL else { return }
    IterableAPI.handle(universalLink: url)
}
```

Custom-scheme URLs arrive in `connectionOptions.urlContexts` and
`scene(_:openURLContexts:)`. Only a UIKit app **without** scenes uses
`application(_:continue:restorationHandler:)`, as in
`reference/ios-universal-links.md`. `handle(universalLink:)` called before
initialization is held and replayed once the SDK starts.

### 5. Identity and logout

Call `IterableIntegration.identify(email:)` (or the `userId` variant) where the
app accepts a sign-in **and** where it restores a session at launch — after
`start`. Call `IterableIntegration.logout()` from the app's sign-out, and clear
the app's own personalized caches and navigation in the same place.

An email entry screen without real authentication is identification, not
sign-in, and is not marketing or notification consent.

### 6. Ask for notification permission in context

`autoPushRegistration` gets a device token; only the user can allow alerts.
Ask after a moment that explains the value, not at first launch unless the
product wants that:

```swift
@MainActor
func requestNotificationPermission() async {
    let center = UNUserNotificationCenter.current()
    guard await center.notificationSettings().authorizationStatus == .notDetermined else { return }
    do {
        if try await center.requestAuthorization(options: [.alert, .badge, .sound]) {
            // Refreshes the registration so Iterable sees notifications as enabled.
            UIApplication.shared.registerForRemoteNotifications()
        }
    } catch {
        // Surface this; don't swallow it.
        print("Notification authorization failed: \(error.localizedDescription)")
    }
}
```

`.denied` means stop asking; offer the app's page in system Settings instead.
`.authorized`, `.provisional`, and `.ephemeral` mean don't prompt again.

---

## Project setup (plain `.xcodeproj`)

### Add the SDK

**In Xcode:** **File > Add Package Dependencies…**, enter
`https://github.com/Iterable/iterable-swift-sdk`, rule **Up to Next Major
Version** from the version you looked up, then add **IterableSDK** to the app
target (and **IterableAppExtensions** to the NSE target, below).

**Editing `project.pbxproj` directly** (when you cannot drive Xcode), add these
objects with fresh unique 24-character hex IDs
(`openssl rand -hex 12 | tr a-f A-F`), then run
`plutil -lint App.xcodeproj/project.pbxproj` and
`xcodebuild -resolvePackageDependencies -project App.xcodeproj`:

```text
/* PBXBuildFile */
BF /* IterableSDK in Frameworks */ = {isa = PBXBuildFile; productRef = DEP /* IterableSDK */; };

/* the app target's PBXFrameworksBuildPhase → files */
BF /* IterableSDK in Frameworks */,

/* the app target's PBXNativeTarget */
packageProductDependencies = ( DEP /* IterableSDK */, );

/* PBXProject */
packageReferences = ( PKG /* XCRemoteSwiftPackageReference "iterable-swift-sdk" */, );

/* Begin XCRemoteSwiftPackageReference section */
PKG /* XCRemoteSwiftPackageReference "iterable-swift-sdk" */ = {
    isa = XCRemoteSwiftPackageReference;
    repositoryURL = "https://github.com/Iterable/iterable-swift-sdk";
    requirement = { kind = upToNextMajorVersion; minimumVersion = <latest>; };
};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
DEP /* IterableSDK */ = {
    isa = XCSwiftPackageProductDependency;
    package = PKG /* XCRemoteSwiftPackageReference "iterable-swift-sdk" */;
    productName = IterableSDK;
};
/* End XCSwiftPackageProductDependency section */
```

Add to an existing list rather than creating a second one; create the
Frameworks build phase only if the target has none. The NSE gets its own
`BF`/`DEP` pair with `productName = IterableAppExtensions` against the same
`PKG`.

**CocoaPods:**

```ruby
target 'App' do
  pod 'Iterable-iOS-SDK'
end

target 'NotificationService' do
  pod 'Iterable-iOS-AppExtensions'
end
```

Then `pod install` and open the `.xcworkspace` from then on. If it reports only
pre-release versions of `Iterable-iOS-AppExtensions`, see
`reference/sdk-testing-and-troubleshooting.md` → `### CocoaPods troubleshooting`.

### Push Notifications capability → entitlement

In Xcode: target → **Signing & Capabilities** → **+ Capability** → **Push
Notifications**. Without Xcode, create `App/App.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>aps-environment</key>
	<string>development</string>
</dict>
</plist>
```

and set `CODE_SIGN_ENTITLEMENTS = App/App.entitlements;` in **both** the Debug
and Release build configurations of the app target. One file with
`development` is Apple's default: Xcode sets the signed value from the
provisioning profile, so an App Store or TestFlight export is re-signed with
`production`. The Apple App ID must also have Push Notifications enabled and
the provisioning profile regenerated afterwards — Xcode's automatic signing does
both when the capability is added in Xcode; otherwise the developer enables it
on the App ID in the Apple Developer portal (`iterable-provision` walks them
through it).

### Background Modes → Remote notifications

In Xcode: **+ Capability** → **Background Modes** → **Remote notifications**
(Xcode writes it into the target's `INFOPLIST_FILE`). Without Xcode, it is the
`UIBackgroundModes` entry already in `Config/Info.plist` from canonical step 1.
Iterable needs it for silent push, which is how it tells the app about new
in-app messages.

### Generated projects (XcodeGen, Tuist)

Put the package, entitlements path, Info.plist properties, and base xcconfig in
the manifest. For XcodeGen's known malformed Push capability output, see
[pitfall 11](PITFALLS.md#11-xcodegen-writes-push-capability-metadata-as-a-string);
the entitlement and background mode remain the functional inputs.

---

## Push notifications

Three separate layers, each with its own failure:

1. **APNs registration** produces a device token. Needs the entitlement and a
   signed build; the SDK starts it when an identity is set.
2. **`IterableAPI.register(token:)`** stores that token on the current Iterable
   user. Needs an identity.
3. **Authorization** decides whether iOS may show alerts, sounds, and badges.
   Only the user can grant it.

### Notification Service Extension (images, video, action buttons)

Without an NSE, an Iterable push shows its title and body only: **no image, no
video, no action buttons**. To add one:

1. **File > New > Target… > Notification Service Extension.** Xcode gives it
   a bundle ID under the app's (`<app bundle ID>.NotificationService`) and
   embeds it in the app. Set its iOS deployment target to the app's — Xcode
   defaults new targets to the latest SDK, and an extension above the device's
   iOS never runs. Creating a target by hand-editing `project.pbxproj` is
   error-prone; if you cannot drive Xcode, ask the developer to do this one
   step and continue with the rest.
2. Attach `IterableAppExtensions` to the extension target (SPM product or the
   `Iterable-iOS-AppExtensions` pod).
3. Replace the generated `NotificationService.swift` with:

   ```swift
   import UserNotifications
   import IterableAppExtensions

   class NotificationService: ITBNotificationServiceExtension {}
   ```

   If that target's Default Actor Isolation is `MainActor`, this fails with
   "main actor-isolated initializer 'init()' has different actor isolation";
   declare it `nonisolated class NotificationService: ITBNotificationServiceExtension {}`.

The extension builds each message's action buttons itself: it reads the
buttons from the push payload, registers a `UNNotificationCategory` named after
the message ID, and assigns it. **Do not register `UNNotificationCategory`
objects in the app for Iterable's buttons.** A button tap reaches your
`didReceive` forwarding like any other response. Apple runs a service extension
only for alert pushes with `mutable-content: 1`, and never for `simctl push`
injection — test rich push with a real send.

### Silent push and in-app messages

The `didReceiveRemoteNotification` forwarding in the canonical app delegate is
required for in-app messages, not just for push campaigns, and needs the
Remote notifications background mode.

**On a Simulator that silent push never arrives.** Observed in the iOS 26.2
Simulator's log, not documented by Apple: SpringBoard rejects it with
"Content-available push notifications are only supported on-device for iOS,
watchOS, and tvOS". The SDK also syncs in-app messages on its own — at
`initialize`, after `setEmail` / `setUserId`, and on a return to the foreground
once `inAppDisplayInterval` (default 30 s) has passed since the last sync (SDK
6.7.5 source). So to test an in-app message on a Simulator, send it, then
relaunch the app, or background and reopen it at least 30 s after its last
sync.

### Payload data and recipient-bound routing

Custom data goes in the template's custom raw JSON
(`reference/creating-push-notification-templates.md`). **Never put raw email
or other direct personal data in a push payload.** Iterable's standard push
metadata identifies campaign, template, and message — not the recipient. If a
product needs routing bound to the intended recipient (one shared device,
several accounts), carry a backend-issued opaque recipient identifier in the
custom payload and validate it before forwarding the response; that is a
product decision to raise, not a default.

---

## In-app messages, Mobile Inbox, Embedded

- **In-app:** default display needs no code beyond initialization, identity,
  and the silent-push forwarding. Keep the default storage;
  `useInMemoryStorageForInApps = true` changes persistence and is not a setup
  step. See `reference/in-app-messages-on-ios.md`.
- **Mobile Inbox:** `reference/setting-up-mobile-inbox-on-ios.md`, then
  `reference/customizing-mobile-inbox-on-ios.md`.
- **Embedded:** set `config.enableEmbeddedMessaging = true` (off by default)
  and use placement IDs from the dashboard. See
  `reference/embedded-messages-with-iterables-ios-sdk.md`.

## Deep links and universal links

- One app-owned router for push, in-app, Embedded, custom-scheme, and
  universal-link URLs. `IterableActionContext.source` says which one
  (`.push`, `.inApp`, `.embedded`, `.universalLink`).
- In the `IterableURLDelegate`: validate scheme, host, path, and identifiers;
  return `true` when the app handled the URL, `false` to let the SDK open it.
  Treat a repeated URL idempotently and navigate on the main actor.
- Universal links need the **Associated Domains** entitlement with the
  Iterable link-tracking domain (`applinks:links.example.com`) plus the
  dashboard setup in `reference/ios-universal-links.md`, and the entry points in
  canonical steps 3–4.
- Any URL from `onOpenURL` or a universal link can come from outside the app.
  Validate it before it reaches personalized content (Apple's universal-link
  guidance says the same).
- Push deep links: `reference/deep-links-in-push-notifications.md`.

## Events and user profiles

```swift
IterableAPI.track(event: "productViewed", dataFields: ["productId": product.id])
IterableAPI.updateUser(["plan": "pro"], mergeNestedObjects: true)
```

Use stable event names without spaces. Track beside the accepted action or
state change, once — not in a SwiftUI `body` or a repeatable `onAppear`. The SDK
already tracks push opens and default in-app engagement; don't add duplicates.
See `reference/tracking-events-with-iterables-mobile-sdks.md` and
`reference/updating-user-profiles.md`.

## JWT

Implement `IterableAuthDelegate`
(`onAuthTokenRequested(completion:)` / `onAuthFailure(_:)`), keep it strongly
referenced, and assign `config.authDelegate` before `initialize`. Fetch the
current user's token from the team's backend; the JWT carries the same email or
user ID you pass to `setEmail` / `setUserId`. Read
`reference/ios-sdk.md` → `#### Step 6.6: Handle JWT-enabled API keys` and
`reference/jwt-enabled-api-keys.md`.

## Describe data use precisely

When writing privacy copy or a handoff, separate what the app sends (identity,
chosen profile fields, event fields) from what the SDK manages (device token
with device, app, OS, and notification-state metadata; push and in-app
engagement). SDK logout is local; deleting server-side Iterable data needs a
backend or privacy workflow.

---

## Proving it works

1. Build and run the existing tests after every change. For push, inspect the
   app target's Debug **and** Release settings (`CODE_SIGN_ENTITLEMENTS`,
   `INFOPLIST_FILE`, bundle ID).
2. Run the app, sign in, and confirm the exact identity in **Audience > Contact
   Lookup**, with a device entry for this app when push is in scope. Check
   selected events and profile fields on that user.
3. **To prove a push actually arrives, hand over to `iterable-ios-verify`.** It
   reads Iterable and the device independently and never edits the app. Don't
   replace it with a hand-written checklist or treat a green build, a
   successful API call, or `simctl push` as delivery.

An iOS 16+ Simulator on macOS 13+ (Apple silicon or T2 Mac) receives real APNs
**sandbox** pushes; production and TestFlight need a physical iPhone. When a
push is missing, find the first failed boundary — signing/token, Iterable
registration, user-targeted send, device presentation, open handling — with
`reference/push-notification-testing-and-troubleshooting.md` and
[`PITFALLS.md`](PITFALLS.md) before changing working code. For a missing in-app
message, `reference/in-app-message-testing-and-troubleshooting.md`.

---

## How to use `reference/`

[`reference/`](reference/) is Iterable's published documentation, transformed
and shipped with the skill — it is already on disk, so there is nothing to
fetch. Say which doc you are opening and why, in one line, before you open it.
Open only what the agreed scope needs, one at a time, and only the section you
need: most of `ios-sdk.md` is installation alternatives and upgrade history.
Each doc's frontmatter has `source_url`, `source_ref`, and `sdk_min_version`;
cite `source_url` when asked where guidance came from.

| Need | Read |
| --- | --- |
| Installation, configuration, upgrades | `ios-sdk` (install steps; `## Upgrading the SDK` only for upgrades), `configure-the-ios-sdk`, `sdk-testing-and-troubleshooting` |
| Identity and profiles | `identifying-the-user`, `updating-user-profiles`, `user-profile-testing-and-troubleshooting` |
| Events | `tracking-events-with-iterables-mobile-sdks`, `event-tracking-testing-and-troubleshooting` |
| Push and APNs setup | `setting-up-ios-push-notifications`, `push-notification-overview`, `push-notification-testing-and-troubleshooting` |
| Rich push, NSE, custom sounds | `advanced-ios-push-notifications` |
| Push templates, custom payloads, metrics | `creating-push-notification-templates`, `push-campaign-metrics` |
| In-app messages | `in-app-messages-on-ios`, `creating-in-app-templates`, `sending-in-app-messages`, `in-app-message-testing-and-troubleshooting`, `events-for-in-app-messages-and-mobile-inbox` |
| Mobile Inbox | `setting-up-mobile-inbox-on-ios`, `customizing-mobile-inbox-on-ios` |
| Deep links and universal links | `deep-links-in-push-notifications`, `ios-universal-links` |
| Embedded Messaging | `embedded-messages-with-iterables-ios-sdk` |
| Unknown User Activation | `configure-the-ios-sdk` |
| API keys and JWT (dashboard side) | `api-keys`, `jwt-enabled-api-keys` |

Each slug is `reference/<slug>.md`.

## Decision flow

1. **Identify the goal:** new integration, upgrade, one feature, debugging, or
   explanation. An existing Iterable dependency means the upgrade path.
2. **Check rules 1–8** against what the app already has; many "the SDK doesn't
   work" reports are rule violations.
3. **Read the matching reference doc** before writing code.
4. **For a symptom the doc doesn't explain**, read [`PITFALLS.md`](PITFALLS.md).
5. **Version-check:** if the app's SDK version is older than a doc's
   `sdk_min_version`, read the upgrade notes in `ios-sdk` or the SDK's
   `CHANGELOG.md` before generating code that depends on newer behavior.

## What's NOT in this skill

- React Native — `iterable-react-native`. Android — `iterable-android`.
- Creating Apple or Iterable prerequisites (Bundle ID, APNs key, Iterable app,
  API keys) — `iterable-provision`.
- Proving delivery on a device — `iterable-ios-verify`.
- Dashboard work beyond the inputs above — `support.iterable.com`.
- JWT server-side signing.

## Versioning

The `reference/` corpus is refreshed from Iterable's docs and records the
exact `source_ref`; the SDK pin lives in `pipeline/config/ios.yml`. If this
skill disagrees with the SDK's `CHANGELOG.md` or source for the version in
use, trust the SDK and report the drift.
