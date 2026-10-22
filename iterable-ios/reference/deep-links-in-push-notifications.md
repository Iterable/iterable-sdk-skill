---
slug: deep-links-in-push-notifications
feature: deep-linking
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Deep Links in Push Notifications
source_url: https://support.iterable.com/hc/articles/360035453971
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/push-notifications/deep-links-in-push-notifications/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 5a65e78c406eba12b25566f9319d16e43e7b4966
fetched_at: 2026-10-02T13:52:10.548Z
summary: A deep link is a URI that links to a specific location within your
  mobile app. The following sections describe how to work with deep links using
  [Iterable's Mobile
  SDKs](https://support.iterable.com/hc/articles/360028925511).
---
# Deep Links in Push Notifications

A deep link is a URI that links to a specific location within your mobile 
app. The following sections describe how to work with deep links using
[Iterable's Mobile SDKs](https://support.iterable.com/hc/articles/360028925511).

> [!NOTE]
> You should be able to use the same schema (pre-defined paths for presenting
> deep linking to a user) as your email or third party deep links.

## iOS deep links

> [!WARNING]
> By default, iOS apps can open HTTPS URLs, but not HTTP. Because of this, you
> should use HTTPS whenever possible. However, it is possible to configure your iOS
> apps to work with HTTP URLs by configuring [App Transport Security](https://developer.apple.com/documentation/security/preventing_insecure_network_connections)
> exceptions in Xcode.

Push notifications and action buttons may have `openUrl` actions attached to
them. When a URL is specified, the SDK first calls the `urlDelegate` object
specified on your `IterableConfig` object. You can use this delegate to
handle `openUrl` actions the same way as you handle normal deep links. If the
delegate is not set or if it returns `false` (the default), the SDK will open
the URL with Safari. If, upon receiving a deep link, you want to navigate to
a specific view controller in your app, do so in the `urlDelegate`.

In the code below, `DeepLinkHandler` is a custom handler which is reponsible
for deep link navigation. You have to provide an implementation for deep link
navigation. Please see the [sample application](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/swift-sample-app/swift-sample-app/DeepLinkHandler.swift)
for a reference implementation for `DeeplinkHandler`.

_Swift_
```swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
    // ...
    // Initialize Iterable SDK
    let config = IterableConfig()
    // ...
    config.urlDelegate = self

    IterableAPI.initialize(apiKey: "<YOUR-API-KEY>", launchOptions: launchOptions, config: config)
}

// Iterable URL delegate. It will be called when you receive 
// an `openUrl` event from push notification.
func handle(iterableURL url: URL, inContext context: IterableActionContext) -> Bool {
    return DeeplinkHandler.handle(url: url)
}
```

_Objective-C_
```objectivec
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ...
    // Initialize Iterable SDK
    IterableConfig *config = [IterableConfig new];
    // ...
    config.urlDelegate = self;

    [IterableAPI initializeWithApiKey:@"<YOUR-API-KEY>" launchOptions:launchOptions config:config];
}

// Iterable URL delegate. It will be called when you receive 
// an `openUrl` event from push notification.
- (BOOL)handleIterableURL:(NSURL *)url context:(IterableActionContext *)context {
    return [DeeplinkHandler handleUrl:url];
}
```

## Android deep links

### Handling links from push notifications

Push notifications and action buttons may have `openUrl` actions attached to
them. When a URL is specified, the SDK first calls the `urlHandler` specified
in your `IterableConfig` object. You can use this class to handle `openUrl`
actions the same way as you handle normal deep links. If the handler is not
set or returns NO, the SDK will open a browser with that URL.

```java
// MyApplication.java

@Override
public void onCreate() {
    super.onCreate();
    // ...
    IterableConfig config = new IterableConfig.Builder()
        .setUrlHandler(this)
        .build();
    IterableApi.initialize(context, "YOUR API KEY", config);
}

@Override
public boolean handleIterableURL(Uri uri, IterableActionContext actionContext) {
    // Assuming you have a DeepLinkHandler class that handles all deep link URLs and navigates to the right place in the app
    return DeepLinkHandler.handle(this, uri);
}
```
