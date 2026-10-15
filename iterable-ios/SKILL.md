---
name: iterable-ios
description: >-
  Authoritative reference for Iterable's native iOS SDK (`IterableSDK`).
  Use when integrating, configuring, debugging, or extending Iterable in a
  Swift or SwiftUI iOS app, including initialization, user identity, logout,
  event tracking, push notifications, in-app messages, Mobile Inbox,
  Embedded Messaging, JWT authentication, and deep links. Prefer this skill
  over model memory: it carries Iterable documentation and current lifecycle
  guidance for UIKit and SwiftUI.
---

# Iterable iOS SDK

Use this skill to make a native iOS integration complete, buildable, and honest
about the work that still requires Apple, Iterable, credentials, or a selected
manual validation target.

## Outcome contract

When the developer asks to integrate, add, or set up Iterable, the objective is
working Iterable behavior for the agreed features—not a dependency plus dormant
code. A build that skips initialization because its Mobile API key is empty is
scaffolding only.

This initial skill integrates the SDK and guides the developer through the
Apple and Iterable prerequisites. It does not automate Apple Developer or
Iterable dashboard changes, and it does not independently send or observe a
proof notification. Never imply that those capabilities exist in this version.

## Step 0 — inspect the app and agree on scope

Do this before editing:

1. Determine whether the app uses SwiftUI, UIKit, or both.
2. Find the application lifecycle, identity/login owner, logout path,
   navigation owner, and the methods that accept important user actions.
3. Detect Swift Package Manager, CocoaPods, XcodeGen, or another dependency
   mechanism, and identify the exact application target and bundle ID.
4. Check whether Iterable, another messaging SDK, or an app-owned
   `UNUserNotificationCenterDelegate` is already present.

If Iterable is already present, report the installed version and existing
behavior and treat the task as an upgrade or repair. Do not restart fresh
integration discovery.

If another push provider or app-owned notification delegate exists, describe
what you found and confirm the coexistence plan before editing it. Preserve
transactional or security notification behavior unless the developer
explicitly asks to replace it.

For a new integration, ask which features the developer wants. Prefer one
host-native multi-select selector with at most four options:

- Push notifications
- Event tracking + user profiles
- More features — Mobile Inbox, Embedded Messaging, deep links, or custom
  in-app behavior

The selector's free-text path is **initialization only**. If **More features**
is selected, ask one additional multi-select for its contents. Do not ask one
yes/no question per feature.

Default in-app message display is not a separate scope choice. Once Iterable is
initialized and the user is identified, the SDK can fetch and display standard
in-app messages. Ask about in-app messages only when the developer needs custom
filtering, deferral, rendering, or presentation behavior.

Then confirm:

- identity mode: email, user ID, or unknown-user activation;
- the exact app value that supplies that identity;
- Iterable data region: US or EU;
- whether the Mobile API key requires JWT;
- the product actions, profile fields, event names, permission timing, and
  routing behavior needed by the selected features.

Never infer these choices merely because one option is easier to implement.
When the host has no selector UI, present the same grouped options clearly in
plain text.

## Preflight — gather real prerequisites

Do not fabricate an input to make the app compile. Gather the inputs needed by
the agreed scope before claiming a working integration:

| Input | Needed when | Required behavior |
| --- | --- | --- |
| Mobile API key | Always | Use a client-side Mobile key for the correct project and region. Never embed a server-side key or commit a real key. |
| Identity | Always | Confirm `setEmail`, `setUserId`, or unknown-user activation and the app-owned value that supplies it. |
| JWT setting | Always | If JWT is enabled, require an app backend that returns a user-specific Iterable JWT. Never sign it in the app. |
| Data region | Always | Confirm US or EU. Set `config.dataRegion = IterableDataRegion.EU` for an EU project. |
| Apple team and explicit bundle ID | Push | Required for signing and a real APNs device token. |
| Push capability and APNs credential | Push | The Apple App ID needs Push Notifications and Iterable needs an APNs credential for the same team and bundle ID. |
| Iterable iOS mobile app | Push | The saved mobile app and APNs credential must use the exact application bundle ID. |
| URL schemes or universal-link domains | Deep links | Add every custom scheme to app configuration and `config.allowedProtocols`. |
| Placement IDs | Embedded Messaging | Use the placement IDs assigned in Iterable. |

If the developer does not yet have a Mobile API key, guide them rather than
asking them to paste a secret into chat:

1. Open the project's API Keys page:
   - US: https://app.iterable.com/settings/apiKeys
   - EU: https://app.eu.iterable.com/settings/apiKeys
2. Select **New API Key**, create a **Mobile** key, choose the agreed JWT
   setting, and copy the value.
3. Store it through the app's existing local-secret mechanism. If none exists,
   create an ignored local `.xcconfig` as described below and have the
   developer place the key there without printing it.

For push, complete the provider prerequisites before the Iterable mobile-app
configuration:

1. In Xcode, add the **Push Notifications** capability to the exact application
   target. Add **Remote notifications** background mode only when silent push
   or in-app message refresh requires it.
2. In Apple Developer, confirm the explicit App ID for the exact bundle ID has
   Push Notifications enabled.
3. Reuse a suitable APNs authentication key, or have an Apple Account Holder or
   Admin create one and securely provide its `.p8` file, Key ID, and Team ID.
   Do not tell a Developer-role user that a Team App Store Connect API key is
   required; it is unrelated to the SDK integration.
4. Open the Iterable mobile apps page:
   - US: https://app.iterable.com/integrations/mobileApps
   - EU: https://app.eu.iterable.com/integrations/mobileApps
5. Create or open the iOS app with the exact bundle ID, then add the `.p8` APNs
   credential and read the saved Bundle ID, Key ID, and Team ID back before
   continuing.

These are guided, developer-performed dashboard steps. Do not operate the
browser, claim the pages were changed, or skip read-back confirmation. A
locally parsed `.p8` proves only its key format; it does not prove that Apple
issued it for APNs or that Iterable can deliver with it.

If an external prerequisite is unavailable, finish only genuinely independent
work and name the exact boundary. Label a build that cannot initialize with a
real key as **scaffolding only: Iterable did not initialize or communicate with
the project**. Do not call it integrated, working, or complete.

## Definition of done

For the agreed scope:

- The SDK dependency is attached to the application target.
- A real Mobile API key is supplied through an ignored local-secret mechanism,
  and the app initializes with the correct region and JWT policy.
- Iterable initializes from the real app lifecycle.
- The accepted or restored user is identified after initialization.
- Logout clears app-owned personalized state and calls
  `IterableAPI.logoutUser()`.
- Requested profile updates and business events are emitted from accepted
  actions or domain mutations, not repeatedly evaluated SwiftUI view bodies.
- Push callbacks, permission UX, background handling, and deep-link routing are
  connected when selected.
- Default in-app behavior remains enabled unless the product requested custom
  handling.
- The app builds and its existing tests pass without committed credentials.
- The configured app was launched. Any remote behavior claimed in the handoff
  was manually observed in Iterable or on the selected target.
- Setup documentation reflects what the app now does and names every remaining
  Apple, Iterable, campaign, or target-specific manual step.

For push, a build alone is not proof. The strongest manual validation available
to this initial skill is:

1. run a signed development build on an eligible iOS 16+ Simulator or a
   physical iPhone;
2. identify a fresh test user and grant notification permission;
3. confirm the device appears for that user in **Audience > Contact Lookup**;
4. send an Iterable **Test Push** and observe it on that target;
5. send a user-targeted test message to validate identity, logout, and
   account-switch behavior.

An eligible Simulator can receive real APNs sandbox pushes. Local
`simctl push` injection exercises app callbacks only and is not evidence of
Iterable or APNs delivery. Production and TestFlight validation require a
physical iPhone.

When handing over, distinguish source/build checks from manually observed
remote behavior. Never claim that this skill independently verified delivery.

## Install the SDK

Prefer Swift Package Manager unless the existing app uses another dependency
system.

Use:

```text
https://github.com/Iterable/iterable-swift-sdk
```

Attach the `IterableSDK` product to the application target. Notification
service extensions that use Iterable's extension helpers attach
`IterableAppExtensions` to the extension target.

For XcodeGen, follow the project's existing package-version policy and attach
the product to the application target:

```yaml
targets:
  App:
    dependencies:
      - package: IterableSDK
        product: IterableSDK
```

For a new integration, resolve the current stable release from the official
`Iterable/iterable-swift-sdk` repository instead of copying a version from this
skill. Preserve an existing app's selected version unless the developer asks
for an upgrade.

## Keep credentials out of source control

Reuse the app's existing secret-loading system. If none exists, create an
ignored mode-`0600` file such as
`Configs/Local.xcconfig`. Have the developer place the copied
Mobile API key there without pasting it into chat or printing it. Include it
from a committed base configuration using the correct relative path:

```text
#include? "Local.xcconfig"
```

Then expose `ITERABLE_API_KEY`, `ITERABLE_DATA_REGION`, and
`ITERABLE_JWT_ENABLED` through build settings or Info.plist, read and validate
them at runtime, and initialize only when they match the confirmed scope. Adjust
the relative include for the base configuration's actual directory.

Do not add `#error`, a fake key, or a real key to make the integration appear
complete. Add the exact local file to the app's `.gitignore` when using this
convention, and verify it is untracked before building. Do not duplicate the
key into a tracked or separately managed local file unless the app already has
an approved secret system.

## Initialize from the real lifecycle

For SwiftUI, bridge an app delegate:

```swift
@main
struct AppName: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

Initialize in
`application(_:didFinishLaunchingWithOptions:)`, not in a helper that nothing
calls:

```swift
let config = IterableConfig()
config.dataRegion = IterableDataRegion.US
IterableAPI.initialize(
    apiKey: apiKey,
    launchOptions: launchOptions,
    config: config
)
```

Set `UNUserNotificationCenter.current().delegate` before launch completion when
push is in scope. Every collaborator needed by its response path must also be
ready before `application(_:didFinishLaunchingWithOptions:)` returns. Attaching
a response handler from SwiftUI `onAppear` is too late for a terminated-app tap.
Construct shared app state early, or buffer the complete response safely until
that state is attached. Do not strip the SDK launch option and then silently
discard the only Apple response callback.

`IterableConfig` holds `urlDelegate`, `customActionDelegate`, and `authDelegate`
weakly. The app must keep strong references to any objects assigned to those
properties.

Read [`reference/ios-sdk.md`](reference/ios-sdk.md) for the complete SDK
configuration surface. If initialization cannot be proved or calls do not
appear in Iterable, use
[`reference/sdk-testing-and-troubleshooting.md`](reference/sdk-testing-and-troubleshooting.md)
before changing otherwise valid lifecycle wiring.

## Identity, profile state, and logout

Identify only after the app has accepted a valid identity:

```swift
IterableAPI.setEmail(email)
```

or:

```swift
IterableAPI.setUserId(userId)
```

If the app restores an authenticated user on launch, initialize Iterable first
and then restore that identity. Do not set both identity types for the same
integration.

Preserve initialization ordering for all restored profile state, not only
identity. If the app restores identity plus targeting fields before the SDK is
ready, queue one coherent snapshot and replay both after successful
initialization. Do not silently drop profile updates and wait for a future user
mutation to repair them.

For a JWT-enabled key, keep a strong `IterableAuthDelegate` and fetch the
current user's JWT from the app's backend. A JWT contains the same identity
passed to `setEmail` or `setUserId`.

On logout:

```swift
IterableAPI.logoutUser()
```

This clears Iterable's local identity, auth, in-app, and embedded state. With
the default `autoPushRegistration`, it also attempts to disable the current
device for that user. If using the completion-handler overload, a failure can
describe that network side effect even though the local logout completed.
Handlers are not guaranteed to run on the main thread.

Inspect the host app's own caches, saved content, inbox state, and navigation
state. Clear or key personalized data by identity according to product
requirements so the next signed-in user cannot inherit it accidentally.

Do not assign previously device-wide data to the first user who signs in unless
the product can establish that user as the owner. Choose and document an
explicit migration policy: clear the legacy data, keep it device-scoped, ask
the user to claim it, or migrate it only from an already-associated identity.

Read:

- [`reference/identifying-the-user.md`](reference/identifying-the-user.md)
- [`reference/updating-user-profiles.md`](reference/updating-user-profiles.md)
- [`reference/user-profile-testing-and-troubleshooting.md`](reference/user-profile-testing-and-troubleshooting.md)
  when the expected user or profile fields do not appear in Contact Lookup.

## Track business events once

Use:

```swift
IterableAPI.track(
    event: "productViewed",
    dataFields: [
        "productId": product.id,
        "productName": product.name
    ]
)
```

Use stable event names without spaces and fields that make the event useful for
segmentation or journeys.

Place tracking beside the accepted action or state transition. For example,
track a saved-item change inside the method that actually accepts that change,
after determining the new state. Do not emit the same event from both the view
and the model/store. Treat `onAppear` as repeatable unless the product explicitly
defines each appearance as a new event.

The SDK already tracks push and default in-app message engagement when its
integration methods and renderer are used. Do not add duplicate manual
engagement events.

Read
[`reference/tracking-events-with-iterables-mobile-sdks.md`](reference/tracking-events-with-iterables-mobile-sdks.md).
Use
[`reference/event-tracking-testing-and-troubleshooting.md`](reference/event-tracking-testing-and-troubleshooting.md)
to verify the event on the correct user's event history rather than treating a
local method call as delivery proof.

## Push notifications

Push has three separate layers:

1. APNs registration obtains a device token.
2. `IterableAPI.register(token:)` associates that token with the current
   Iterable user.
3. notification authorization controls whether iOS may display alerts, sounds,
   and badges.

The default `autoPushRegistration = true` asks APNs for a token after identity
is set. It does not replace the display-permission request.

### Project configuration

Add:

- the Push Notifications capability;
- the `aps-environment` entitlement supplied by signing;
- the Remote notifications background mode when silent push or in-app message
  updates are in scope.

Encode these settings in the project's source configuration. For XcodeGen,
do not rely on an unrecorded change made only in generated Xcode UI. When the
generation manifest records `SystemCapabilities`, inspect the generated
`project.pbxproj`: the Push capability must be a PBX dictionary, not a quoted
string. If the installed generator cannot emit it correctly, use a checked,
deterministic normalization step or fail generation. That normalizer must be
idempotent: accept exactly one already-correct Push dictionary, rewrite exactly
one known malformed shape, and fail on missing, duplicate, or unknown shapes.
Run it twice against the same generated project and require both runs to
succeed without changing the second-run bytes. When the malformed XcodeGen
shape matches, copy and reuse
[`assets/normalize-xcodegen-push-capability.rb`](assets/normalize-xcodegen-push-capability.rb)
instead of writing a custom substitution. A second successful run alone is not
enough: a permissive grep/replacement can be idempotent while still accepting
duplicate or unknown capability structures.
Entitlements and background modes remain the functional build inputs; the
capability marker alone does not prove signing or delivery.

Do not hardcode `aps-environment = development` in one entitlements file used
by both Debug and Release. The effective signed entitlement must agree with the
build's provisioning profile: development/sandbox for a development build and
production for an App Store or distribution build. If the project records
entitlements explicitly, use configuration-specific files or an equivalent
configuration-specific build setting. Inspect both Debug and Release build
settings after project generation.

Keep `IterableConfig.pushPlatform` at its default `.auto` unless the app has a
confirmed legacy/custom integration that requires an explicit override. Do not
use an SDK platform override to hide incorrect signing or entitlement setup.

### App delegate callbacks

Register the APNs token:

```swift
func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
) {
    IterableAPI.register(token: deviceToken)
}
```

Record registration failures without printing private credentials or complete
tokens.

For Iterable's direct **Test Push**, first obtain the registered token from the
matching device in **Audience > Contact Lookup**. That path also proves Iterable
registration. If no device appears and the developer must distinguish APNs
token generation from Iterable registration failure, expose the token only
through a DEBUG-only diagnostic surface. Keep it in memory until the developer
explicitly requests access. If the app offers a copy action, write a local-only
pasteboard item with a short expiration date, disclose that temporary clipboard
boundary, and clear it after use when practical. Do not describe a plain
`UIPasteboard.general.string` write as non-persistent: it may outlive the app
session or become available through Universal Clipboard. Never include the
complete token in source control, screenshots, transcripts, analytics,
persistent app storage, or normal production logs. Remove or compile out the
diagnostic for release builds.

Even a local-only expiring pasteboard item is temporary system storage. Say the
token is not stored in the app's persistence or logs; do not claim it is “never
persisted” after offering a copy action.

Implement the failure callback so signing, entitlement, and provisioning
problems are observable during device testing:

```swift
func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
) {
    // Send a redacted diagnostic to the app's normal logging surface.
}
```

Pass notification interactions to Iterable:

```swift
func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
) {
    IterableAppIntegration.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
    )
}
```

Do not invoke the completion handler a second time. This direct forwarding is
appropriate when the app does not impose an app-owned recipient policy before
tracking or routing the open. If Iterable initialization was skipped or failed,
do not call this static method. Complete the app callback directly so an
uninitialized SDK cannot leave the system completion handler pending.

### Recipient-bound notification responses

When personalized routing must be bound to the intended recipient, validate
the complete `UNNotificationResponse` before forwarding it to Iterable.
Assume forwarding can record the push open using the SDK's current identity
before app-owned URL routing runs. Blocking only the eventual URL is therefore
too late: a notification intended for User A can be attributed to User B.

For an app-owned recipient policy:

- inspect `response.actionIdentifier` before applying navigation policy. For a
  dismiss response with no product-defined dismiss action, complete without
  forwarding, navigation, or fallback;
- for default and custom actions, compare the opaque recipient value with the
  active identity and session/generation before calling
  `IterableAppIntegration.userNotificationCenter`;
- for a missing or mismatched recipient on an actionable response, apply the
  safe app fallback and call the completion handler without forwarding the
  response to Iterable;
- for a verified recipient, forward the original response once when the SDK is
  initialized and let Iterable choose the selected default or custom-button
  action. If initialization is unavailable, complete without SDK forwarding;
- keep app-owned push-routing approval active until the SDK completion handler
  runs, then clear it;
- bind that approval to the recipient and the initiating session/generation.
  Logout and every identity transition must invalidate it immediately, even if
  the same identity later signs in and reuses the same recipient identifier;
- inspect `IterableActionContext.source` in the URL delegate. A `.push` URL
  requires active recipient approval. Apply separate product policy to
  `.inApp` and `.embedded`, and treat `.universalLink` as an external entry
  point rather than implicit recipient proof;
- do not pre-route `defaultAction` and then independently let Iterable route
  the same response.

Do not let launch handling bypass the same policy. The SDK may defer a
remote-notification launch action until the app's root UI is available, so a
gate that ends immediately after `IterableAPI.initialize` may expire too soon.
If the app validates recipient-bound launch data itself, ensure the unvalidated
remote-notification launch option is not also handed to Iterable for later
automatic routing. Preserve unrelated launch options, and rely on the
notification-response callback or an equivalent validated pending-response
design for the user action.

Treat `content-available` background notifications as silent delivery, not as
evidence that the user selected a notification. They must not reset navigation.

Tests for this policy must cover the orchestration boundary, not only a helper
that accepts `userInfo`. Exercise default, dismiss, and custom action
identifiers; missing, matching, and previous-user recipients; background and
terminated activation; delayed launch routing; logout; and the public app and
URL delegate boundaries. Prove that dismiss preserves the current navigation,
the selected custom action is retained, and a `.push` URL arriving without
active approval—including after response completion—does not enter a
personalized route. Also test skipped initialization, delayed SDK completion
across logout and same-user re-login, and direct
`IterableURLDelegate.handle(iterableURL:inContext:)` source mapping.

Keep Apple delegate methods thin and dependency-inject the policy/SDK adapter
where practical. Unit-test the adapter with a protocol-backed response, then
pair it with a simulator-injected notification or another integration test that
reaches the public Apple callback. Do not claim full delegate orchestration from
a dictionary-only policy test. If custom notification buttons are a product
requirement, register the corresponding `UNNotificationCategory` in source and
exercise the selected action; do not add a category solely to manufacture proof
for a product that has no custom actions.

Add a cold-start ordering test or equivalent integration proof that the response
collaborator exists before SwiftUI view appearance. A nil-handler branch that
completes and drops a matching response is a failure, not a safe fallback.

Choose the app's desired foreground presentation in
`userNotificationCenter(_:willPresent:withCompletionHandler:)`.
When the app enforces recipient ownership, apply the same ownership check
before foreground presentation. A missing or mismatched recipient must use the
safe product fallback—normally suppressing the banner with empty presentation
options—rather than exposing the previous account's notification while another
user is active. Test matching, missing, mismatched, and logged-out foreground
states.

### Ask for permission in context

Do not prompt automatically at first launch unless the product explicitly asks
for that experience. Request authorization after a user action that explains
the value, or from a clear settings/control surface:

```swift
UNUserNotificationCenter.current().requestAuthorization(
    options: [.alert, .badge, .sound]
) { granted, error in
    // Update app UI on the main actor when needed.
}
```

Before requesting, read the current notification settings:

- `.notDetermined`: show the product explanation, then request authorization.
- `.denied`: do not keep requesting; explain how to open the app's system
  settings when the user asks to enable notifications.
- `.authorized`, `.provisional`, or `.ephemeral`: reflect the enabled state and
  avoid another prompt.

Handle and expose the `granted` result and any error instead of discarding both.
The user must answer the system prompt; code cannot grant permission.
Do not convert an authorization error into a silent status refresh. Present a
useful app-owned diagnostic and add a focused test for that branch.

When the product chooses a contextual value moment—such as completing the first
high-value action—the integration is incomplete if it only adds a notification
button to Settings. Connect the accepted domain action to the app-owned
explanation, make **Not Now** avoid the system prompt, and persist that
dismissal at the product's chosen device or identity scope. Keep a manual
control for later recovery. Test the trigger from the real action boundary
rather than calling the explanation presenter directly.

Do not add a generic sheet swipe or **Done** path that dismisses an undecided
contextual explanation without recording the chosen scope. While the
preference is undecided, every dismissal must either remain disabled or behave
as the persisted **Not Now** choice. Once a preference already exists, a plain
close action may dismiss the manual settings view without changing it.

Decide whether dismissal of the app's explanatory prompt is device-scoped or
identity-scoped. Do not use one device-global “never ask again” flag when the
product expects each account to control its own messaging preference.

Notification settings and authorization APIs complete asynchronously. Bind
each request to the identity/session that initiated it and revalidate that
identity before changing UI, registering for remote notifications, or storing
a preference. Logout or an account switch must invalidate pending work;
clearing the currently presented prompt does not cancel an in-flight callback.
When this behavior is part of the requested scope, make the notification center
and settings opener injectable enough to test denial, errors, and a callback
that arrives after logout or user switching.

## In-app messages

After initialization and identity, the SDK's default in-app delegate displays
available in-app messages and tracks their engagement. Do not build a custom
renderer unless the requested behavior requires one.

Iterable uses silent push to notify the app about new in-app messages. Forward
the background callback:

```swift
func application(
    _ application: UIApplication,
    didReceiveRemoteNotification userInfo: [AnyHashable: Any],
    fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
    guard iterableIsInitialized else {
        completionHandler(.noData)
        return
    }
    IterableAppIntegration.application(
        application,
        didReceiveRemoteNotification: userInfo,
        fetchCompletionHandler: completionHandler
    )
}
```

Keep this guard at the SDK boundary. If initialization was skipped, the static
integration method has no implementation to call and does not complete the
background fetch for the app.

Default in-app messages should remain dismissible and should not replace the
app's root flow. Read
[`reference/in-app-messages-on-ios.md`](reference/in-app-messages-on-ios.md).

Keep the SDK's default in-app storage unless the product or security
requirements choose otherwise. `useInMemoryStorageForInApps = true` changes
persistence across launches; do not enable it as a generic setup step.

## Deep links

Use one app-owned parser and navigation owner for URLs from push, in-app
messages, custom schemes, universal links, and SwiftUI's `onOpenURL`. Keep the
source and trust decision explicit when entering that router. Reusing a parser
does not make every source equally trusted.

For an Iterable URL delegate:

```swift
final class IterableURLHandler: NSObject, IterableURLDelegate {
    let route: (URL, IterableActionContext) -> Bool

    init(route: @escaping (URL, IterableActionContext) -> Bool) {
        self.route = route
    }

    func handle(
        iterableURL url: URL,
        inContext context: IterableActionContext
    ) -> Bool {
        route(url, context)
    }
}
```

Keep this object strongly referenced and assign it before initialization:

```swift
config.urlDelegate = urlHandler
config.allowedProtocols = ["myapp"]
```

`https`, `action`, `itbl`, and `iterable` have built-in handling. Every other
scheme must be explicitly allowed. A custom scheme must also be registered in
the app's Info.plist.

For a route such as `myapp://item/<id>`:

- validate the scheme, host, path shape, and identifier;
- perform every read and write of shared observable app state on the main
  actor, including session/identity checks made before navigation. Dispatching
  only the final mutation is insufficient if the URL callback first reads an
  `ObservableObject` or `@Published` property off-main;
- make repeated delivery of the same URL idempotent rather than stacking
  duplicate destinations;
- return `true` when the app handled the URL;
- use the product's defined fallback for a missing or stale destination;
- return `false` only when the URL should fall through to system handling.

Define what happens when a message URL arrives while logged out or after an
account switch. A public destination may be safe to open, defer, or discard
according to the product decision, but an old notification must not expose the
previous user's private or personalized state to the next user.

Exercise the router or URL delegate from a background callback in a focused
test. The test must cover the session check and destination mutation together,
not only assert that the final append eventually uses `DispatchQueue.main`.

SwiftUI's `onOpenURL` can be invoked by another app or by the system. Do not
send that URL directly into a trusted personalized-message route merely because
its scheme and path are valid. If the destination is public, allow it
explicitly as a product decision. If it requires recipient ownership, an
external URL without that proof must use the same safe fallback as other
unverified sources.

Do not infer notification ownership from whichever user is active when the
notification is tapped. Iterable's standard iOS push metadata identifies the
campaign, template, and message, but not the intended recipient. When the
product requires recipient-bound routing, include an app-owned opaque recipient
identifier in the template's custom raw payload and compare it with the active
identity before routing. Treat a missing or mismatched identifier as unverified
and use the product's safe fallback. Avoid raw email or other direct personal
data in the payload; production apps should prefer a backend-issued stable
opaque identifier.

Do not generate a different device-local UUID on each installation and write it
to one user-level profile field. For a user with multiple devices, each update
would overwrite the previous device's value and valid pushes could be rejected
on the other devices. A local UUID is acceptable only for an explicitly
one-device benchmark whose limitation is documented. Production apps need a
backend-stable user identifier or a deliberately device-scoped recipient
design.

Read
[`reference/creating-push-notification-templates.md`](reference/creating-push-notification-templates.md)
for custom raw JSON and per-user template data.

For Iterable universal links, call `IterableAPI.handle(universalLink:)` from the
app's universal-link lifecycle entry point.

Read:

- [`reference/deep-links-in-push-notifications.md`](reference/deep-links-in-push-notifications.md)
- [`reference/ios-universal-links.md`](reference/ios-universal-links.md)

## Describe data use precisely

When writing privacy copy or a handoff, separate what the app explicitly sends
from what the SDK manages. The app may explicitly provide the normalized
identity, selected profile fields, and business-event fields. IterableSDK may
also register the push token with device/app/OS and notification-state metadata
and record standard push or in-app engagement. Avoid absolute claims such as
“Iterable receives only these fields” unless every SDK-managed field and event
is included.

Keep the disclosure proportional to the product surface, but name the
categories accurately. Distinguish local deletion and SDK logout from deletion
of server-side Iterable data, which normally requires an authenticated backend
or support/privacy workflow.

## Verify at the strongest available level

Always run the project's generation, build, and unit tests after editing.
For generated projects, also inspect the Debug and Release build settings that
control bundle identifiers, entitlements, and signing rather than validating
only the simulator configuration.

Simulator can prove:

- dependency resolution;
- compilation, installation, and launch;
- login/logout and local event-call wiring;
- permission and deep-link UI flows that do not require real APNs delivery;
- locally injected notification presentation and app-owned response routing,
  when labeled Simulator-injected rather than APNs- or Iterable-delivered.
- real APNs sandbox registration and delivery when the target is an eligible
  iOS 16+ Simulator on macOS 13+ with Xcode 14+ and supported Mac hardware.

The bundled `ios-sdk` and push-troubleshooting articles still say that push
testing requires a physical device. That platform statement predates Apple's
real APNs support for eligible Simulators. Preserve those generated references
as source material, but follow the eligibility and proof boundary in this
section and [pitfall 16](PITFALLS.md#16-simulator-support-is-confused-with-local-notification-injection).

A supported Simulator or physical iPhone plus external configuration can prove
development APNs sandbox behavior:

- signing and the Push Notifications entitlement;
- a real APNs token;
- device registration on the correct Iterable profile;
- direct Test Push delivery;
- user-targeted push delivery and tap routing.

A physical iPhone remains required for production/TestFlight and
hardware-specific behavior.

External setup and selected-target steps for end-to-end push:

1. Complete the guided Apple and Iterable prerequisites from Preflight: the
   exact App ID has Push Notifications enabled, a suitable APNs key exists, and
   the matching Iterable iOS mobile app has that credential saved.
2. In Xcode, select the app target and Apple Developer team, then confirm
   the signed bundle ID and effective `aps-environment` entitlement.
3. Supply the untracked Mobile API key and any required JWT backend.
4. Build the selected development configuration for the intended target.
   Development can use an eligible Simulator or physical iPhone; production
   uses a physical iPhone. Install and launch the exact build, identify fresh
   User A, trigger the contextual permission request, and allow notifications.
5. Confirm the user has the expected device in **Audience > Contact Lookup**.
6. Send a direct **Test Push** from Iterable with a unique visible marker.
   Observe the marker on the selected target and exercise the expected action.
7. Send a user-targeted message to User A, observe it, tap it, and record the
   expected route. Relaunch the app and confirm restored identity behavior.
8. Clear local personalized state, call Iterable logout, identify fresh User B,
   observe the expected neutral/User B state, then send and observe a distinct
   User B targeted marker. Confirm that User A's stale notification cannot
   expose or attribute personalized behavior under User B.

A direct token Test Push bypasses user association. It proves APNs credential,
environment, bundle ID, and token delivery, but it cannot prove logout or
recipient targeting. Use a user-targeted test message for identity, logout, and
account-switch checks.

Also test notification denial, logout, user switching, a stale destination, and
foreground/background/terminated message opens. Include a delayed permission
callback after logout or account switching in local tests when the permission
manager owns identity-specific UI or preferences. For recipient-bound routing,
also test missing and mismatched ownership, external custom-scheme opens,
dismiss and custom action identifiers, silent `content-available` delivery, and
the complete app-delegate-to-URL-delegate path. Logs or a successful send
request do not prove user-visible delivery.

When handing over, state exactly which of these were performed and which remain
manual or blocked.

For a missing push, follow
[`reference/push-notification-testing-and-troubleshooting.md`](reference/push-notification-testing-and-troubleshooting.md)
and identify the first failed boundary: signing and APNs token generation,
Iterable profile registration, direct Test Push, user-targeted send, device
presentation, or open handling. Read
[`reference/advanced-ios-push-notifications.md`](reference/advanced-ios-push-notifications.md)
only when rich notifications, custom sounds, advanced payload behavior, or a
notification service extension is in scope.

For an in-app message that does not appear, use
[`reference/in-app-message-testing-and-troubleshooting.md`](reference/in-app-message-testing-and-troubleshooting.md)
to distinguish an empty/wrong user queue, foreground fetch behavior, and silent
push configuration before replacing the default renderer.

Use
[`reference/sending-in-app-messages.md`](reference/sending-in-app-messages.md)
for the external send flow and
[`reference/events-for-in-app-messages-and-mobile-inbox.md`](reference/events-for-in-app-messages-and-mobile-inbox.md)
to verify which delivery, open, click, close, delete, and inbox events the SDK
captures automatically.

## Feature routing

| Need | Read |
| --- | --- |
| Installation, configuration, upgrades, lifecycle | [`reference/ios-sdk.md`](reference/ios-sdk.md), [`reference/sdk-testing-and-troubleshooting.md`](reference/sdk-testing-and-troubleshooting.md) |
| Identity and profile updates | [`reference/identifying-the-user.md`](reference/identifying-the-user.md), [`reference/updating-user-profiles.md`](reference/updating-user-profiles.md), [`reference/user-profile-testing-and-troubleshooting.md`](reference/user-profile-testing-and-troubleshooting.md) |
| Events | [`reference/tracking-events-with-iterables-mobile-sdks.md`](reference/tracking-events-with-iterables-mobile-sdks.md), [`reference/event-tracking-testing-and-troubleshooting.md`](reference/event-tracking-testing-and-troubleshooting.md) |
| Push and APNs setup | [`reference/setting-up-ios-push-notifications.md`](reference/setting-up-ios-push-notifications.md), [`reference/push-notification-overview.md`](reference/push-notification-overview.md), [`reference/push-notification-testing-and-troubleshooting.md`](reference/push-notification-testing-and-troubleshooting.md) |
| Advanced or rich iOS push | [`reference/advanced-ios-push-notifications.md`](reference/advanced-ios-push-notifications.md) |
| Push templates, custom payloads, recipient-bound routing, campaign metrics | [`reference/creating-push-notification-templates.md`](reference/creating-push-notification-templates.md), [`reference/push-campaign-metrics.md`](reference/push-campaign-metrics.md) |
| In-app messages | [`reference/in-app-messages-on-ios.md`](reference/in-app-messages-on-ios.md), [`reference/creating-in-app-templates.md`](reference/creating-in-app-templates.md), [`reference/sending-in-app-messages.md`](reference/sending-in-app-messages.md), [`reference/in-app-message-testing-and-troubleshooting.md`](reference/in-app-message-testing-and-troubleshooting.md), [`reference/events-for-in-app-messages-and-mobile-inbox.md`](reference/events-for-in-app-messages-and-mobile-inbox.md) |
| Mobile Inbox | [`reference/setting-up-mobile-inbox-on-ios.md`](reference/setting-up-mobile-inbox-on-ios.md), [`reference/customizing-mobile-inbox-on-ios.md`](reference/customizing-mobile-inbox-on-ios.md) |
| Deep links and universal links | [`reference/deep-links-in-push-notifications.md`](reference/deep-links-in-push-notifications.md), [`reference/ios-universal-links.md`](reference/ios-universal-links.md) |
| Embedded Messaging | [`reference/embedded-messages-with-iterables-ios-sdk.md`](reference/embedded-messages-with-iterables-ios-sdk.md) |
| Unknown User Activation | [`reference/configure-the-ios-sdk.md`](reference/configure-the-ios-sdk.md) |

For unexplained signing, delivery, account-switch, permission, or proof-level
failures, read [`PITFALLS.md`](PITFALLS.md) before inventing a workaround.
