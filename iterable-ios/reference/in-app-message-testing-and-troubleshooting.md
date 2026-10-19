---
slug: in-app-message-testing-and-troubleshooting
feature: in-app-messages
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Testing and Troubleshooting In-App Messages
source_url: https://support.iterable.com/hc/articles/360035623391
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/testing-and-troubleshooting-in-app-messages/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 06a269ab86faf48d695f70c43d7e331973ba4d06
fetched_at: 2026-10-06T10:29:04.505Z
summary: By default, when an in-app message is sent, it sits on server queue. It
  gets pulled by SDK when App is in the foreground. You can see which in-app
  messages are in the queue by sending a test campaign and then calling [`GET
  /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages).
---
# Testing and Troubleshooting In-App Messages

## Troubleshooting 

By default, when an in-app message is sent, it sits on server queue. It gets
pulled by SDK when App is in the foreground. You can see which in-app
messages are in the queue by sending a test campaign and then calling 
[`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages).

The `GET` request will then return all the messages in the queue and you can
determine if you sent the message to the right location.

## iOS in-app message is not shown

Make sure you call `IterableAppIntegration` from `didReceiveRemoteNotification`:

```swift
// In AppDelegate.swift
func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    IterableAppIntegration.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
}
```

## Android in-app message is not shown

If you are implementing your own `onMessageReceived()` and `onNewToken()`
methods, make sure you forward `onMessageReceived()` and `onNewToken()` calls
to `IterableFirebaseMessagingService.handleMessageReceived` and
`IterableFirebaseMessagingService.handleTokenRefresh` respectively.

```java
@Override
public void onMessageReceived(RemoteMessage remoteMessage) {
    IterableFirebaseMessagingService.handleMessageReceived(this, remoteMessage);
}
```

## No messages received

If you do not see messages received during troubleshooting, verify your
notification setup. Iterable uses silent push to alert the app when in-app
is available. Follow [this guide](https://support.iterable.com/hc/articles/360035112332) 
to see if you have push notifications set up correctly.

In iOS, make sure you have Background Fetch enabled for your app:
