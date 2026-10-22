---
slug: in-app-messages-on-ios
feature: in-app-messages
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: In-App Messages on iOS
source_url: https://support.iterable.com/hc/articles/360035536791
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/in-app-messages-on-ios/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 4517a3263036a61188ea8fd70c475a4fa61f206d
fetched_at: 2026-10-02T13:52:10.684Z
summary: "In-app messages are handled via silent push messages from the server.
  When your application receives a silent push, call the Iterable iOS SDK in
  your app delegate, as follows:"
---
# In-App Messages on iOS

## In-app messages

In-app messages are handled via silent push messages from the server. When your
application receives a silent push, call the Iterable iOS SDK in your app delegate,
as follows:

_Swift_

```swift
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    IterableAppIntegration.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
}
```

_Objective-C_

```objectivec
- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [IterableAppIntegration application:application didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}
```

## Default behavior

By default, when an in-app message arrives from the server, the SDK automatically
shows it if the app is in the foreground. If an in-app message is already showing
when the new message arrives, the new in-app message will be shown 30 seconds after
the currently displayed in-app message closes (see [how to change this default value](#changing-the-display-interval-between-in-app-messages)).  
Once an in-app message is shown, it will be "consumed" from the server queue and
removed from the local queue as well. There is no need to write any code to get this
default behavior.

## Overriding whether to show or skip a particular in-app message

An incoming in-app message triggers a call to the `onNew` method of
`IterableConfig.inAppDelegate` (an object of type `IterableInAppDelegate`).  To
override the default behavior, set `IterableConfig.inAppDelegate` to a custom class
that overrides the `onNew` method. `onNew` should return `.show` to show the
incoming in-app message or `.skip` to skip showing it.

> [!TIP]
> To determine the priority of an `IterableInAppMessage` object, look at its
> `priorityLevel` property. You can use this value to help determine whether or not to
> display it.

_Swift_

```swift
class YourCustomInAppDelegate: IterableInAppDelegate {
    func onNew(message: IterableInAppMessage) -> InAppShowResponse {
        // perform custom processing

        // ...
        
        return .show // or .skip
    }
}

let config = IterableConfig()
config.inAppDelegate = YourCustomInAppDelegate()

IterableAPI.initialize(apiKey: "<YOUR-API-KEY>", launchOptions: launchOptions, config: config)
```

_Objective-C_

```objectivec
@implementation YourCustomInAppDelegate : IterableInAppDelegate {
    - (enum InAppShowResponse)onNewMessage:(IterableInAppMessage * _Nonnull)message {
        // perform custom processing
        
        // ...
        
        return InAppShowResponseShow; // or InAppShowResponseSkip
    }
}

@end

IterableConfig *config = [IterableConfig new];
config.inAppDelegate = [YourCustomInAppDelegate new];

[IterableAPI initializeWithApiKey:@"<YOUR-API-KEY>" launchOptions:launchOptions config:config];
```

## Getting the local queue of in-app messages

Until they are consumed by the app, all in-app messages that arrive from the server
are stored in a local queue. To access this local queue, use the read-only
`IterableAPI.inAppManager` property (an object which conforms to the `InAppManager`
protocol). By default, all in-app messages in the local queue will be consumed and
removed from this queue. To keep in-app messages around after they are shown,
override the default behavior (as described above).

_Swift_ 

```swift
// Get the in-app messages list
let messages = IterableAPI.inAppManager.getMessages()

if messages.isEmpty {
    print("don't present when there are 0 messages")
} else {
    print("presents the first message")

    // Show an in-app message
    IterableAPI.inAppManager.show(message: messages[0])
}

// Show an in-app message without consuming, i.e., not removing it from the queue
IterableAPI.inAppManager.show(message: messages[0], consume: false)
``` 

_Objective-C_

```objectivec
// Get the in-app messages list
NSArray *messages = [IterableAPI.inAppManager getMessages];

if (messages.count == 0) {
    NSLog(@"don't present when there are 0 messages");
} else {
    NSLog(@"presents the first message");

    // Show an in-app message
    [IterableAPI.inAppManager showMessage:messages[0]];
}

// Show an in-app message without consuming, i.e., not removing it from the queue
[IterableAPI.inAppManager showMessage:messages[0] consume:NO callbackBlock:nil];
```

## Receiving JSON-only in-app messages

A JSON-only in-app message carries a custom JSON payload and no HTML, so
nothing is displayed. The SDK consumes these messages automatically on arrival,
and they never appear in the mobile inbox. Use them to deliver data from a
campaign directly to your app.

Starting with SDK version 6.7.5, the SDK saves each JSON-only message to disk
and then tells your app it is available. Implement the optional
`onJsonOnlyMessageAvailable(message:)` method on your `IterableInAppDelegate`,
or observe the `iterableJsonOnlyInAppMessageAvailable` notification. Both fire
on the main thread and carry the full `IterableInAppMessage`, including its
`customPayload`. After your app has processed a message, acknowledge it with
`markJsonOnlyMessageHandled(messageId:)`.

_Swift_

```swift
class YourCustomInAppDelegate: IterableInAppDelegate {
    func onNew(message: IterableInAppMessage) -> InAppShowResponse {
        return .show
    }

    func onJsonOnlyMessageAvailable(message: IterableInAppMessage) {
        if let payload = message.customPayload {
            // Process the payload
        }

        IterableAPI.markJsonOnlyMessageHandled(messageId: message.messageId)
    }
}
```

_Objective-C_

```objectivec
@interface YourCustomInAppDelegate : NSObject <IterableInAppDelegate>
@end

@implementation YourCustomInAppDelegate

- (enum InAppShowResponse)onNewMessage:(IterableInAppMessage * _Nonnull)message {
    return InAppShowResponseShow;
}

- (void)onJsonOnlyMessageAvailable:(IterableInAppMessage * _Nonnull)message {
    NSDictionary *payload = message.customPayload;
    // Process the payload

    [IterableAPI markJsonOnlyMessageHandled:message.messageId];
}

@end
```

Delivery is at least once. If your app misses the callback (for example, the
message arrives during a background fetch, or before your listener is
registered after a cold start), the message replays on the next app foreground
until you acknowledge it. To process pending messages on your own schedule,
call `getUnhandledJsonOnlyMessages()`:

_Swift_

```swift
for message in IterableAPI.getUnhandledJsonOnlyMessages() {
    // Process message.customPayload

    IterableAPI.markJsonOnlyMessageHandled(messageId: message.messageId)
}
```

_Objective-C_

```objectivec
for (IterableInAppMessage *message in [IterableAPI getUnhandledJsonOnlyMessages]) {
    // Process message.customPayload

    [IterableAPI markJsonOnlyMessageHandled:message.messageId];
}
```

The `onNew` method continues to fire once for the first delivery of each
JSON-only message; replays use only `onJsonOnlyMessageAvailable`. The pending
queue is per user and cleared on logout or user switch. Messages honor their
campaign expiration; a message without an expiration is kept for up to 30 days,
and the queue holds at most 100 messages per user, dropping the oldest first.

## Handling in-app message buttons and links

> [!WARNING]
> By default, iOS apps can open HTTPS URLs, but not HTTP. Because of this, you should
> use HTTPS whenever possible. However, it is possible to configure your iOS apps to
> work with HTTP URLs by configuring [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
> exceptions in Xcode.

The SDK handles in-app message buttons and links as follows:

- If the URL of the button or link uses the `action://` URL scheme, the SDK
  passes the action to `IterableConfig.customActionDelegate.handle()`. If 
  `customActionDelegate` (an `IterableCustomActionDelegate` object) has not 
  been set, the action will not be handled.

  For the time being, the SDK will treat `itbl://` URLs the same way as
  `action://` URLs. However, this behavior will eventually be deprecated
  (timeline TBD), so it's best to migrate to the `action://` URL scheme
  as it's possible to do so.

- The `iterable://` URL scheme is reserved for action names predefined by
  the SDK. If the URL of the button or link uses an `iterable://` URL known
  to the SDK, it will be handled automatically and will not be passed to the
  custom action handler. For example, buttons or links with URL `iterable://dismiss` 
  dismiss an in-app message and create in-app click and in-app close events.

- The SDK passes all other URLs to `IterableConfig.urlDelegate.handle()`. If
  `urlDelegate` (an `IterableUrlDelegate` object) has not been set, or if it 
  returns `false` for the provided URL, the URL will be opened by the system 
  (using a web browser or other application, as applicable).

For a demonstration of how to implement and use the `IterableURLDelegate` and
`IterableCustomActionDelegate` protocols, take a look at the [Swift](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/swift-sample-app/swift-sample-app/AppDelegate.swift)
and [Objective-C](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/objc-sample-app/objc-sample-app/AppDelegate.m)
sample apps.

The following code demonstrates how to assign a `urlDelegate` and
`customActionDelegate` to an `IterableConfig` object:

_Swift_

```swift
let config = IterableConfig()
config.urlDelegate = YourCustomUrlDelegate()
config.customActionDelegate = YourCustomActionDelegate()
```

_Objective-C_

```objectivec
IterableConfig *config = [IterableConfig new];
config.urlDelegate = [YourCustomUrlDelegate new];
config.customActionDelegate = [YourCustomActionDelegate new];
```

## Changing the display interval between in-app messages

To customize the time delay between successive in-app messages (default value of 30
seconds), set `inAppDisplayInterval` to an appropriate value (in seconds).

_Swift_

```swift
let config = IterableConfig()
// 10 second delay between in-app presentations
config.inAppDisplayInterval = 10.0
```

_Objective-C_

```objectivec
IterableConfig *config = [IterableConfig new];
// 10 second delay between in-app presentations
config.inAppDisplayInterval = 10.0;
```

## Pausing the display of in-app messages

In certain areas of your app, you may want to prevent interruptions. To pause the
display of in-app messages, set the following property:

_Swift_

```swift
IterableAPI.inAppManager.isAutoDisplayPaused = true
```

_Objective-C_

```objectivec
IterableAPI.inAppManager.isAutoDisplayPaused = YES
```

With this done, the app will not automatically display new in-app messages.
However, it will keep the local queue of in-app messages in sync.

> [!TIP]
> While in-app message display has been paused, you can still call the
> `show(message:)` (Swift) or `showMessage:` (Objective-C) method on
> `IterableAPI.inAppManager` to manually display messages.

To resume the display of in-app messages from your app's queue, set
`isAutoDisplayPaused` to `false` (or `NO`). Once you do this, the app will resume
displaying any in-app messages on the queue.
