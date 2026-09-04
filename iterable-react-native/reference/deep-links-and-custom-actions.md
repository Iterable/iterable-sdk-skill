---
slug: deep-links-and-custom-actions
feature: deep-linking
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Deep Links and Custom Actions with Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/360046134911
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/deep-links-and-custom-actions/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: ee16919f6cfe9bcf16e04aee34b06b8f41be523e
fetched_at: 2026-08-28T14:44:26.844Z
summary: It's often useful to link directly from your marketing campaigns to
  specific content in your mobile apps. To make this possible, Iterable supports
  _deep links_ and _custom actions_. Deep links can open a particular screen in
  an app, and custom actions can have the app take a specific action of some
  kind.
---
# Deep Links and Custom Actions with Iterable's React Native SDK

It's often useful to link directly from your marketing campaigns to specific
content in your mobile apps. To make this possible, Iterable supports _deep links_
and _custom actions_. Deep links can open a particular screen in an app, and
custom actions can have the app take a specific action of some kind.

Iterable's React Native SDK supports deep links and custom actions, as described
in this document.

## Prerequisites

Before following the instructions in this guide:

- Configure the native code for your iOS and Android apps, as described in
  [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132).
- Configure your Iterable project to support deep links, as described in
  [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

## Deep links

This section describes the methods Iterable's React Native SDK provides to support
deep linking, and how to set it up.

### Deep Links vs. App Links vs. Universal Links

When it comes to deep links, there are a few related terms to understand:

- **Deep links** - URLs that link to particular content that your app can
  open if it's installed, and a web browser can open otherwise. For example:
  `https://myapp.com/products/widget`.

  Iterable can include deep links in email, in-app message and push notification
  campaigns.

  When they're included in an email campaign, Iterable rewrites deep links so
  that they point to your tracking domain (for example, `https://links.myapp.com/a/...`).
  When a user clicks this rewritten link in an email on their mobile device, your
  app (if installed) opens it. The app then calls back to the tracking domain,
  asking it to track the click and respond with the originally intended link
  destination (along with identifying information about the campaign and template
  that caused the user to click the link in the first place). The SDK then hands
  the link's final destination URL to your app's [URL handler](#url-handler),
  which can deal with it as necessary.

  Iterable does not rewrite deep links for push notifications or in-app
  messages. In these cases, the SDK makes API calls to track link clicks
  after they're clicked, and the messages themselves contain information about
  the campaign and template they're associated with.

- **App links** - [Android's implementation of deep links](https://developer.android.com/training/app-links),
  which allows you to use an Android app to handle a link click (for example,
  opening an app by clicking a link in an email).

- **Universal links** - [The iOS implementation of deep links](https://developer.apple.com/ios/universal-links),
  which allows you to open an iOS app from a link clicked somewhere outside
  of it (for example, opening the app by clicking a link in an email).

### SDK methods for deep links

This section describes the methods provided by Iterable's React Native SDK to
support deep linking.

#### URL handler

To handle deep links (and other URLs), Iterable calls the function stored in the
`IterableConfig` object's `urlHandler`. Set this property on the `IterableConfig`
you provide to the SDK's `initialize` method.

- **Property declaration**:

  ```typescript
  urlHandler?: (url: string, context: IterableActionContext) => boolean
  ```

  |Parameter Name|Description|
  |:-------------|:----------------------------------------------------|
  |`url`         |The clicked URL.                                     |
  |`context`     |Describes the source of the URL (push, in-app, or universal link) and information about any associated custom actions.|

- **Description:**

  Use this method to determine whether or not the app can handle the clicked
  URL. If it can, the method should navigate the user to the right content in
  the app and return `true`. Otherwise, it should return `false` to have the
  web browser open the URL.

- **Example:**

  ```javascript
  const config = new IterableConfig()
  config.urlHandler = (url, context) => {
    if (url.match(/product\/([^\/]+)/i)) {
      this.navigate(match[1]);
      return true; // handled
    }
    return false; // not handled
  }
  Iterable.initialize('<YOUR_API_KEY>', config);
  ```

  This example searches for URLs that contain `product/`, followed by more
  text. Upon finding this sequence of text, the code displays the appropriate
  screen and returns `true`. When it's not found, the app returns `false`.

#### Deep link attribution

When the SDK resolves a deep link to determine its final destination (as
described [above](#url-handler)), Iterable also provides _attribution_
information: the campaign ID, template ID and message ID (specific send of a
specific campaign to a specific user) that prompted the user to click the link.
The React Native SDK stores this information, and you can access it later when
you need to attach attribution information to various method calls (event
tracking, purchases, etc.).

##### Getting attribution info

To get the current attribution information (based on a recent deep link click),
call the static `getAttributionInfo` method on the `Iterable` class.

- **Method declaration:**

  ```typescript
  static getAttributionInfo(): Promise<IterableAttributionInfo | undefined>
  ```

  This method returns a `Promise`. Use `then` to get the `IterableAttributionInfo`
  object that contains the relevant results.

- **Description:**

  This method gets the attribution data for a recent deep link click.

- **Example:**

  ```javascript
  Iterable.getAttributionInfo().then((attributionInfo) => {
    Iterable.updateSubscriptions(
      null,
      [33015, 33016, 33018],
      null,
      null,
      attributionInfo.campaignId,
      attributionInfo.templateId
    );
  });
  ```

  This example fetches the current attribution information (an
  `IterableAttributionInfo` object) and uses it to update the user's
  subscription preferences. The call to `updateSubscriptions` sets the user's
  unsubscribed channel IDs to `[33015,33016,33018]` and attributes this change
  to the `campaignId` and `templateId` stored in the `attributionInfo` info
  object.

##### Setting attribution info

To manually set the current attribution information so that it can later be used
when tracking events, call the `setAttributionInfo` method on the `Iterable`
class.

- **Method declaration:**

  ```typescript
  static setAttributionInfo(attributionInfo?: IterableAttributionInfo)
  ```

  |Parameter Name   |Description|
  |:----------------|:----------------------------------------------------------|
  |`attributionInfo`|Information about the campaign ID, template ID and message ID to use for attribution.|

- **Description**:

  For deep link clicks, Iterable sets attribution information automatically. However,
  use this method to set it manually if you ever need to do so.

- **Example:**

  ```javascript
  const campaignId = 123;
  const templateId = 456;
  const messageId = "0fc6657517c64014868ea2d15f23082b";
  const attributionInfo = new IterableAttributionInfo(campaignId, templateId, messageId);
  Iterable.setAttributionInfo(attributionInfo);
  ```

 This example creates an `IterableAttributionInfo` object that stores the `campaignId`,
 `templateId`, and `messageId` that represents the current attribution
 information. Then, this object is passed into the `setAttributionInfo` method to
 save this information for future use.

### Configuring your app to support deep links

> [!NOTE]
> - For these instructions to work, you'll need to use [version 1.1.3+](https://support.iterable.com/hc/articles/360045714352#_1-1-3)
>   of Iterable's React Native SDK.
>
> - If you've already set up support for deep links in an iOS app that uses a version
>   of Iterable's React Native SDK prior to 1.1.3, that implementation should continue
>   to work (even if you use the instructions below for your Android app). However,
>   we recommend using the instructions described below for both iOS and Android.
>
> - When incorporating a new version of Iterable's React Native SDK into your app,
>   always test before releasing (including deep links), to make sure everying
>   works as expected.
>
> - These instructions are also described in the [Enabling Deep Links](https://reactnative.dev/docs/linking#enabling-deep-links)
>   section of the React Native documentation.

To set up deep linking with Iterable's React Native SDK, you'll need to use React
Native's built-in [`Linking`](https://reactnative.dev/docs/linking) class, which
is intended for this purpose. Follow these instructions:

#### Step 1: Update native code for iOS

In your iOS project, add the following code to the app delegate:

```swift
#import <React/RCTLinkingManager.h>

func application(_ application: UIApplication,
                continue userActivity: NSUserActivity,
                restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
{
   return RCTLinkingManager.application(
     application,
     continue: userActivity,
     restorationHandler: restorationHandler
   )
}

func application(_ app: UIApplication,
                open url: URL,
                options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
{
   RCTLinkingManager.application(app, open: url, options: options)
}
```

#### Step 2: Update native code for Android

To set up your Android project, update its `AndroidManifest.xml`:

1. For your app's main activity, add intent filters for each URL scheme you'd
   like the app to recognize. For more information about this process, see
   Android's guide, [Add intent filters for incoming links](https://developer.android.com/training/app-links/deep-linking#adding-filters).

2. Deep links coming from Iterable are prefixed by `/a/`, so include this as
   the `pathPrefix`.

3. To prevent multiple deep links from opening multliple copies of the same
   activity in the same app, set `launchMode` to `singleTask`.

For example:

```xml
<!-- NOTE: In the activity node, launchMode is set to singleTask -->
<activity
 android:name="com.company.MainActivity"
 android:label="@string/app_name"
 android:launchMode="singleTask"
 android:configChanges="keyboard|keyboardHidden|orientation|screenSize"
 android:windowSoftInputMode="adjustResize">
 <intent-filter>
     <action android:name="android.intent.action.MAIN" />
     <category android:name="android.intent.category.LAUNCHER" />
 </intent-filter>
 <intent-filter>
     <action android:name="android.intent.action.VIEW" />
         <category android:name="android.intent.category.DEFAULT" />
         <category android:name="android.intent.category.BROWSABLE" />
         <!-- NOTE: Deep links from Iterable will have your link tracking domain, followed by /a/ -->
         <!-- NOTE: for pathPrefix, the leading "/" is required -->
         <data
             android:host="links.example.com"
             android:pathPrefix="/a/"
             android:scheme="https" />
   </intent-filter>
</activity>
```

#### Step 3: Update your React Native project

To implement deep links in your React Native code, follow these steps:

1. In the React Native component where you set up `IterableConfig`, import React
   Native's `Linking` class. For example:

  ```javascript
  import {
    Linking
  } from 'react-native'
  ```

2. To handle deep links clicked when the app is not running, implement
   `Linking.getInitialURL`. In this method, call `Iterable.handleAppLink`. For
   example:

   ```javascript
   Linking.getInitialURL().then(url => {
     if (url != null) {
        Iterable.handleAppLink(url)
     }
   });
   ```

3. To handle deep links clicked when the app is already open (even if it's in the
   background), implement `Linking.addEventListener('url', callback)`, and call
  `Iterable.handleAppLink`. For example:

   ```javascript
   Linking.addEventListener('url', event => {
     if (event.url != null) {
        Iterable.handleAppLink(event.url)
     }
   });
   ```

4. When you call `Iterable.handleAppLink`, you'll pass a URL—the tracking URL
   generated by Iterable for the link you included in your message content.
   `handleAppLink` will fetch the original URL (the one you added to your message)
   from Iterable and hand it to `IterableConfig.urlHandler`, where you can
   analyze it and decide what to do (for example, you might navigate the user to
   a particular screen in your app that has content related to the link).

   For example:

   ```javascript
   const config = new IterableConfig()
   config.urlHandler = (url: string, context: IterableActionContext) => {
     console.log("urlHandler: url: " + url)
     if (url.search(/coffee/i) == -1) {
       return false
     } else {
       console.log('Navigate to coffee page')
       return true
     }
   }
   ```

## Custom actions

Push notifications and in-app messages can include links (or action buttons) that
make use of _custom actions_. These URLs describe particular actions your app can
take (but a browser cannot open).

For example, a user might tap a push notification action button to acknowledge
some sort of achievement, and the custom action associated with the URL might
change the app's styling to reflect this.

### Defining custom actions

A custom action URL has format `action://customActionName`: an `action://`
prefix, followed by a custom action name. Decide with your marketing team on a
set of known custom actions your app should support.

> [!WARNING]
> Earlier versions of the SDK used the `itbl://` prefix for custom action URLs.
> The SDK still supports these custom actions, but they are deprecated and will not
> be supported forever. Migrate to `action://` as it's possible to do so.

### SDK methods for custom actions

This section describes the methods provided by Iterable's React Native SDK to
support custom actions.

#### Custom action handler

To handle custom action URLs with Iterable's React Native SDK, provide a function
to the `customActionHandler` property on the `IterableConfig` object passed to
the SDK's `initialize` method. Iterable calls this method when a user clicks a
URL, passing in the URL and other contextual information.

- **Property declaration**:

  ```typescript
  customActionHandler?: (action: IterableAction, context: IterableActionContext) => boolean
  ```

  |Parameter Name|Description|
  |:-------------|:----------------------------------------------|
  |`action`      |The action to handle.                          |
  |`context`     |Information about where the action was invoked.|

- **Description:**

Use this method to determine whether or not the app can handle the clicked
custom action URL. If it can, it should handle the action and return `true`.
Otherwise, it should return `false`.

- **Example:**

  ```javascript
  const config = new IterableConfig()
  config.customActionHandler = (action, context) => {
    if (action.type == "achievedPremierStatus") {
      // For this action, update the app's styles
      this.updateAppStyles("premier");
      return true;
    }
    return false;
  }
  Iterable.initialize('<YOUR_API_KEY>', config);
  ```

  This example responds to the `action://achievedPremierStatus` custom action
  URL by updating the app's styles and return `true`. Since this is the only
  custom action handled by the method, it returns `false` for anything else.
