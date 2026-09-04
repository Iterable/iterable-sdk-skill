---
slug: installing
feature: integration
archetype: integration
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Installing Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/360045714132
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/installing/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: 82f9ffcb2c66f522515f9e4a561cd9b88adc0dec
fetched_at: 2026-08-28T14:44:26.810Z
summary: This article describes how to install Iterable's React Native SDK in
  your React Native apps, and how to configure your iOS and Android apps to
  support Iterable features like push notifications and in-app messages.
---
# Installing Iterable's React Native SDK

This article describes how to install Iterable's React Native SDK in your React
Native apps, and how to configure your iOS and Android apps to support Iterable
features like push notifications and in-app messages.

## Requirements

Iterable's React Native SDK depends on the following:

**React Native**

- [React Native 0.79.3+](https://github.com/facebook/react-native)
- [React 19.0.0+](https://github.com/facebook/react)

> [!TIP]
> **New Architecture Compatibility**
>
> As of SDK version `2.1.0`, Iterable's React Native SDK is fully compatible with
> [React Native's New Architecture](https://reactnative.dev/architecture/landing-page).
>
> This release provides stable support for React Native's New Architecture,
> including Fabric, TurboModules, and Codegen. You can now use the SDK with
> confidence in production applications that have enabled the New Architecture.

**iOS**

- Xcode 15+
- Swift 5+
- [Deployment target 13.4+](https://help.apple.com/xcode/mac/current/#/deve69552ee5)
- [Iterable's iOS SDK](https://github.com/Iterable/iterable-swift-sdk)
  (the instructions below will install this SDK for you)

**Android**

- [`minSdkVersion` 23+, `compileSdkVersion` 34+](https://medium.com/androiddevelopers/picking-your-compilesdkversion-minsdkversion-targetsdkversion-a098a0341ebd)
- [Iterable's Android SDK](https://github.com/Iterable/iterable-android-sdk)
  (the instructions below will install this SDK for you).

## Configuring React Native's New Architecture

Iterable's React Native SDK version [2.1.0 or later](https://github.com/Iterable/react-native-sdk/releases/tag/2.1.0)
is fully compatible with [React Native's New Architecture](https://reactnative.dev/architecture/landing-page). 
You can enable the New Architecture in your project, and you can disable it only 
in React Native versions earlier than 0.83.

### Enabling the New Architecture

**For Android:**

1. Open the `android/gradle.properties` file in your project.
2. Add or update the following line:

   ```properties
   newArchEnabled=true
   ```

**For iOS:**

1. Open the `ios/Podfile` file in your project.
2. Add or update the following line (it should be the first line of the `Podfile`):

   ```properties
   ENV['RCT_NEW_ARCH_ENABLED'] = '1'
   ```

### Disabling the New Architecture

> [!WARNING]
> React Native 0.83 requires New Architecture. The following steps apply only to
> React Native versions earlier than 0.83—in React Native 0.83 and later, opting 
> out is no longer supported.

**For Android:**

1. Open the `android/gradle.properties` file in your project.
2. Add or update the following line:

   ```properties
   newArchEnabled=false
   ```

**For iOS:**

1. Open the `ios/Podfile` file in your project.
2. Add or update the following line (it should be the first line of the `Podfile`):

   ```properties
   ENV['RCT_NEW_ARCH_ENABLED'] = '0'
   ```

**⚠️ WARNING**

After making these configuration changes, you must clean and rebuild your 
project to apply the new settings.

**Cleaning Android**
```bash
cd android
rm -rf .gradle build app/build app/.cxx
./gradlew clean
```

**Cleaning iOS**

```bash
cd ios
bundle exec pod deintegrate
rm -rf ~/Library/Developer/Xcode/DerivedData Pods Podfile.lock build ../Gemfile.lock
bundle install
bundle exec pod install
```

## Example application

The repository for Iterable's React Native SDK contains a 
[example application](https://github.com/Iterable/react-native-sdk/tree/master/example)
that has been configured to use the SDK.

## Encrypted data

Starting with version [1.3.7](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.7),
Iterable’s React Native SDK, as a privacy enhancement, includes support for
encrypting some data stored at rest.

Which data gets encrypted depends on mobile platform, since Iterable's React
Native SDK relies on Iterable's underlying iOS and Android SDKs. For more
information, read about:

- [Encrypted data in Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152#encrypted-data)
- [Encrypted data in Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712#encrypted-data)

## Instructions

To set up Iterable's React Native SDK, follow these instructions:

### Step 1: Install the SDK package

Run one of these commands in your project's directory (depending on the
package manager you use):

```bash
yarn add @iterable/react-native-sdk
```
or:
```bash
npm install @iterable/react-native-sdk
```

> [!NOTE]
> The latest version of Iterable's React Native SDK (`2.1.0` and later) provides
> full compatibility with React Native's New Architecture.

If your app will use a mobile inbox, install the [React Native Webview](https://www.npmjs.com/package/react-native-webview) 
package with one of these commands:

```bash
yarn add react-native-webview
```
or: 
```bash
npm install react-native-webview
```

### Step 2: Install other dependencies

Next, install some other necessary dependencies:

- For iOS, navigate to the `ios` folder and run `bundle exec pod install`. If you see
  errors, try [`bundle exec pod install --repo-update`](https://guides.cocoapods.org/terminal/commands.html#pod_install)
  or `bundle exec pod deintegrate` and `bundle exec pod install` again.

- For Android, there are no more dependencies to install.

### Step 3: iOS app setup

After installing the Iterable's React Native SDK, you'll need to make some
updates in the Apple Developer Portal, in Iterable, and in your app's Xcode
project:

#### Step 3.1: Configure your App ID

In the [Apple Developer Portal](https://developer.apple.com), configure your
App ID to support push notifications, and export an auth token or push certificate.
To learn more, read [Setting up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806).

#### Step 3.2: In Iterable, set up a mobile app

In Iterable, create a mobile app and give it a push integration. For more details,
read [Setting up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806).

#### Step 3.3: Import the SDK

To use Iterable's SDK in your code (for example, in your app delegate), add
import statements wherever necessary:

_Objective-C_

```objectivec
@import IterableSDK;
```

_Swift_

```swift
import IterableSDK
```

> [!WARNING]
> If your SDK version is **2.2.0 or below**, you will need to enable dynamic linkage
> (`use_frameworks! :linkage => :dynamic`) for Iterable's React Native SDK to ensure 
> Swift/Objective-C++ compatibility.  
>
> You can enable dynamic linkage for your whole project, individual targets, or 
> just for the iOS Iterable modules.
>
> See the instructions below.

**Enabling dynamic linkage for your whole project**

1. Open the `ios/Podfile` file in your project.
2. Make sure the following line is included: `use_frameworks! :linkage => :dynamic`. 
   The block of code will likely look similar to this:
    ```ruby
    linkage = ENV['USE_FRAMEWORKS']
    if linkage != nil
      Pod::UI.puts "Configuring Pod with #{linkage}ally linked Frameworks".green
      use_frameworks! :linkage => :dynamic # <-- Your framework linkage configuration.
    end
    ```

**Enabling dynamic linkage only for specific targets**
1. Open the `ios/Podfile` file in your project.
2. In the target in which you are using `Iterable-iOS-SDK`, set the linkage to `:dynamic`:
    ```ruby
    target '<YOUR_NOTIFICATION_APP_TARGET>' do
      use_frameworks! :linkage => :dynamic
      pod 'Iterable-iOS-SDK'
    end
    ```
3. If using the notification extension, set the linkage for the notification
   target to `:dynamic`:
   ```ruby
    target '<YOUR_NOTIFICATION_EXTENSION_TARGET>' do
      use_frameworks! :linkage => :dynamic
      pod 'Iterable-iOS-AppExtensions'
    end
    ```

**Enabling dynamic linkage only for iOS Iterable modules**

1. Open the `ios/Podfile` file in your project.
2. Add the
   [`cocoapods-pod-linkage`](https://github.com/microsoft/cocoapods-pod-linkage) 
   gem.
3. Set the linkage to dynamic when you specify the `Iterable-iOS-SDK` and
   `Iterable-iOS-AppExtensions` pods:
   ```ruby
    pod 'Iterable-iOS-SDK', :linkage => :dynamic
    pod 'Iterable-iOS-AppExtensions', :linkage => :dynamic
    ```

[Learn more about dynamic vs static linking](https://medium.com/@agung1991putra/cocoapods-static-framework-vs-dynamic-framework-pod-revisited-is-it-true-that-static-linkage-2cccb4827082)

#### Step 3.4: Update your project's build settings

If you've created your iOS app with React Native 0.63+, you'll need to make some
configuration changes to ensure that archiving works as expected:

1. Open your app's workspace in Xcode.

2. In the **Project Navigator**, select your project's icon.

3. In **Targets**, select the target you'll need to archive.

4. On the **Build Settings** tab, enable the **All** and **Levels** filters.

5. In the search box, enter `Library Search Paths`.

6. Select the top-level entry that includes the `Debug` and the `Release` build
   configuration.

7. Remove `"$(TOOLCHAIN_DIR)/usr/lib/swift-5.0/$(PLATFORM_NAME)"` (but not the
   `.../lib/swift/...` entry, which is still necessary).

Test these changes as early as possible in your development cycle, to help you
avoid any problems when you're trying to release. If you have any trouble,
contact Iterable Support. See [Working with Iterable Support](https://support.iterable.com/hc/articles/5432399749652).

**💡 TIP**

If you see this error when distributing your build to Apple:

```
The bundle at <EXTENSION_BUNDLE_ID> contains disallowed file 'Frameworks'.
```

Try navigating to the build settings for your extension's target, and setting
**Always Embed Swift Standard Libraries** to **No**.

#### Step 3.5: Set up support for push notifications

To add support for push notifications to your app:

1. Add the [Push Notifications capability](https://developer.apple.com/documentation/xcode/adding_capabilities_to_your_app).

2. Add the [Remote Notifications background mode](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_background_updates_to_your_app)
   to your app.

3. If you'll be sending [Time Sensitive](https://developer.apple.com/videos/play/wwdc2021/10091)
   push notifications (introduced in iOS 15), add the Time Sensitive Notifications
   capability to your app.

4. In your code, [register the device token](https://support.iterable.com/hc/articles/360035018152#step-7-4-fetch-a-device-token-from-apple-and-register-it-with-iterable)
   with Iterable. To do this, implement [`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622958-application).

5. If needed, have your code [request permission to display push notifications](https://support.iterable.com/hc/articles/360035018152#step-7-6-optional-request-authorization-to-display-push-notifications).

6. Handle incoming push notifications and enable push notification tracking, as
   described [here](https://support.iterable.com/hc/articles/360035018152#step-7-5-handle-incoming-push-notifications-and-enable-push-notification-tracking).

7. Set up support for rich push notifications, which can include media attachments
   and action buttons:

   - Create a [Notification Service Extension](https://support.iterable.com/hc/articles/360035018152#step-1-create-a-notification-service-extension-if-necessary).

   - Install the `Iterable-iOS-AppExtensions` pod:

     - Open the `Podfile` that's found in your React Native project's `ios` folder.

     - Specify a `platform` of `13.4` or higher (as required by your app), or
       use `min_ios_version_supported`:

       ```ruby
       platform :ios, '13.4'
       # or
       platform :ios, min_ios_version_supported
       ```

     - Add the `Iterable-iOS-AppExtensions` pod:

       ```ruby
       target '<YOUR_NOTIFICATION_EXTENSION_TARGET>' do
         pod 'Iterable-iOS-AppExtensions'
       end
       ```

     - Save the `Podfile`.

     - Run `bundle exec pod install` to install the new pod. If you see errors,
       try `bundle exec pod install --repo-update` ([docs](https://guides.cocoapods.org/terminal/commands.html#pod_install))
       or `bundle exec pod deintegrate` ([docs](https://guides.cocoapods.org/terminal/commands.html#pod_deintegrate))
       and then `bundle exec pod install`.

       :::warning IMPORTANT
       you'll need to import it in your code. Be sure to read [Step 3.3: Import the SDK](#step-3-3-import-the-sdk) 
       for important instructions about how to do this with React Native versions 
       0.68 and higher.
       :::

   - [Configure](https://support.iterable.com/hc/articles/360035018152#step-3-configure-the-notification-service-extension-if-necessary)
     the Notification Service Extension to use a base class provided by Iterable's 
     iOS SDK.

#### Step 3.6: Add support for in-app messages

To add support for in-app messages to your app, follow [these instructions](https://support.iterable.com/hc/articles/360035018152#step-8-enable-in-app-messages).

#### Step 3.7: Add support for deep links

To support deep links in your React Native mobile apps:

1. [Configure your Iterable project](https://support.iterable.com/hc/articles/115002651226)
   to support deep links.

2. Configure the associated domains in your Xcode projects. See step 5 of Iterable's
   [iOS Universal Links](https://support.iterable.com/hc/articles/360035496511)
   instructions.

3. Follow the instructions in [Configuring your app to support deep links](https://support.iterable.com/hc/articles/360046134911#configuring-your-app-to-support-deep-links).

> [!TIP]
> For an implementation of some of the above steps, take a look at this
> [example app delegate](https://github.com/Iterable/react-native-sdk/blob/master/example/ios/ReactNativeSdkExample/AppDelegate.swift).

### Step 4: Android app setup

To use Iterable's features with your React Native Android application, follow
these steps:

#### Step 4.1: Set up Firebase

To set up Firebase for your Android app:

1. Follow steps 1-3 of [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943#step-1-set-up-firebase-for-your-android-app).

2. Follow the steps for [adding Firebase with the Firebase console](https://firebase.google.com/docs/android/setup#console).

3. When [adding the Firebase SDKs to your app](https://firebase.google.com/docs/android/setup#add-sdks), 
   make sure to also include `firebase-messaging`.  Your app's `build.gradle` 
   file should look something like this:

   ```gradle
    dependencies {
      // ...

      // Import the Firebase BoM
      implementation(platform("com.google.firebase:firebase-bom:32.8.1"))

      // When using the BoM, you don't specify versions in Firebase library dependencies
      implementation("com.google.firebase:firebase-messaging")
    }
   ```

#### Step 4.2: In Iterable, set up a mobile app

In Iterable, [create a mobile app](https://support.iterable.com/hc/articles/115000331943#step-2-create-a-mobile-app-in-iterable)
and give it a [push integration](https://support.iterable.com/hc/articles/115000331943#step-3-add-a-push-integration-to-the-mobile-app).

By default, the React Native SDK looks for a push integration that has the same
package name as your app (to change this, set `IterableConfig.pushIntegrationName`).

#### Step 4.3: Update your ProGuard configuration

If you're [using ProGuard](https://reactnative.dev/docs/signed-apk-android#enabling-proguard-to-reduce-the-size-of-the-apk-optional),
[update its configuration](https://support.iterable.com/hc/articles/360035019712#step-4-configure-proguard)
for Iterable's Android SDK.

#### Step 4.4: Add support for deep links

To support deep links in your React Native mobile apps:

1. [Configure your Iterable project](https://support.iterable.com/hc/articles/115002651226)
   to support deep links.

2. Follow the instructions in [Configuring your app to support deep links](https://support.iterable.com/hc/articles/360046134911#configuring-your-app-to-support-deep-links).

#### Step 4.5: Add Iterable's Android SDK as a dependency

In your project's `settings.gradle` file, add `':react-native-iterable',
':iterableapi'` to the `include` statement.  EG:

```gradle
include ':app', ':react-native-iterable', ':iterableapi'
```

#### Step 4.6: Update your app's `Application` class

Starting with version [1.1.0+](https://github.com/Iterable/react-native-sdk/releases/tag/1.1.0)
of Iterable's React Native SDK, you'll need to update your Android application's
`Application` class:

1. Add this import:

   ```java
   import com.iterable.iterableapi.IterableApi;
   ```

2. At the end of the `onCreate` method, add this line of code:

   ```java
   IterableApi.setContext(this);
   ``` 

### Step 5: Import Iterable SDK classes wherever needed

In your JavaScript or TypeScript code, import classes from Iterable's React
Native SDK whenever you need to reference them. For example, to reference the
`Iterable` and `IterableConfig` classes in a particular file in your app's
source code, include this `import` statement:

```javascript
import { Iterable, IterableConfig } from '@iterable/react-native-sdk';
```

To see the various classes you may need to import, take a look at
[the core classes](https://github.com/Iterable/react-native-sdk/blob/master/src/core/classes)
and [the in-app classes](https://github.com/Iterable/react-native-sdk/tree/master/src/inApp/classes),
in Iterable's React Native SDK GitHub repository.

### Step 6: Initialize Iterable's React Native SDK

To initialize Iterable's React Native SDK in your app's JavaScript or TypeScript
code, call the static `initialize` method on the `Iterable` class and pass the
following parameters:

- A mobile API key from Iterable. To learn how to create one, read
  [API keys](https://support.iterable.com/hc/articles/360043464871).

  :::danger WARNING
  Never use server-side API keys with Iterable's mobile SDKs. Since API keys
  are, by necessity, distributed with the mobile apps that contain them, bad
  actors can potentially access them. For this reason, Iterable provides mobile
  API keys, which have minimal access.
  :::

- An [`IterableConfig`](https://github.com/Iterable/react-native-sdk/blob/master/src/core/classes/IterableConfig.ts)
  object with various properties set:

  - `dataRegion` - If your Iterable project is hosted on [Iterable's European data center (EDC)](https://support.iterable.com/hc/articles/17572750887444),
    set this value to `IterableDataRegion.EU` (a constant provided in the SDK). This
    configures the SDK to interact with Iterable's EDC-based endpoints.

  - `pushIntegrationName` - The name of the Iterable push integration that
    will send push notifications to your app. Defaults to your app's application
    ID or bundle ID (iOS). Don't specify this value unless you're
    using an older Iterable push integration that has a custom name.

  - `autoPushRegistration` - When `true` (the default value), causes the SDK to
    automatically register and deregister for push tokens when you provide
    `email` or `userId` values to the SDK.

  - `inAppDisplayInterval` - When displaying multiple in-app messages in
    sequence, the number of seconds to wait between each. Defaults to 30
    seconds.

  - `urlHandler` - A function expression used to handle deep link URLs and
    in-app message button and link URLs.

  - `authHandler` - A function expression that provides a valid JWT for the
    app's current user to Iterable's React Native SDK. Provide an implementation
    for this method only if your app uses a [JWT-enabled API key](https://support.iterable.com/hc/articles/360050801231).

  - `expiringAuthTokenRefreshPeriod` - The number of seconds before the current
    JWT's expiration that the SDK should call the `authHandler` to get an
    updated JWT.

  - `onJwtError` - **Available in SDK version 2.2.0 or later** - A callback function that
    is called when the SDK encounters an error while validating a JWT. The callback
    receives an object with the following properties:
    - `userKey` - The `userId` or `email` of the signed-in user
    - `failedAuthToken` - The JWT token that caused the failure
    - `failedRequestTime` - The timestamp of the failed request
    - `failureReason` - The reason for the failure (see `IterableAuthFailureReason` enum)

    This is useful for logging and monitoring authentication issues in production.

  - `retryPolicy` - **Available in SDK version 2.2.0 or later** - Configuration for JWT
    token refresh retry behavior. An object with the following properties:
    - `maxRetries` - Maximum number of retry attempts (default: 5)
    - `retryBackoff` - Backoff strategy: `IterableRetryBackoff.LINEAR` or
      `IterableRetryBackoff.EXPONENTIAL` (default)
    - `retryInterval` - Initial retry interval in seconds (default: 2.0)

  - `customActionHandler` - A function expression used to handle `action://`
    URLs for in-app message buttons and links.

  - `allowedProtocols` - Use this array to declare the specific URL protocols
    that the SDK can expect to see on incoming links from Iterable, so it knows
    that it can safely handle them as needed. This array helps prevent the SDK
    from opening links that use unexpected URL protocols.

    For example, to allow the SDK to handle `http`, `tel`, and `custom` links,
    use code similar to this:

    _JavaScript_

    ```javascript
    const config = new IterableConfig()
    config.allowedProtocols = ["http", "tel", "custom"]
    ```

    :::warning IMPORTANT
    Iterable's React Native SDK handles `https`, `action`, `itbl`, and
    `iterable` links, regardless of the contents of this array. However, you
    must explicitly declare any other types of URL protocols you'd like the SDK
    to handle (otherwise, the SDK won't open them in the web browser or as deep
    links).
    :::

  - `useInMemoryStorageForInApps` - Determines whether Android and iOS
    apps should store in-app messages in memory, rather than in an unencrypted
    local file (defaults to `false`).

    :::tip NOTE
    For more information about this option, and the deprecated-but-related
    `androidSdkUseInMemoryStorageForInApps` available in version 1.3.7 of
    Iterable's React Native SDK, read the [release notes for version 1.3.9](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.9)
    :::
  
  - `enableEmbeddedMessaging` - **Available in SDK version 2.3.0 or later** - Determines 
    whether [embedded messaging](https://support.iterable.com/hc/articles/23060529977364)
    is enabled for a user (defaults to `false`). For more information about
    embedded messaging, see [Embedded Messages with Iterable's React Native SDK](https://support.iterable.com/hc/articles/49144129810324).

  - `onEmbeddedMessageUpdate` - **Available in SDK version 2.3.0 or later** - A callback 
    function that is called when embedded messages are updated. This callback is 
    triggered when the local cache of embedded messages changes, such as when new 
    messages arrive or existing messages are removed.
  
  - `onEmbeddedMessagingDisabled` - **Available in SDK version 2.3.0 or later** - A 
    callback function that is called when embedded messaging is disabled. This 
    callback is triggered when embedded messaging becomes unavailable, which can 
    happen due to configuration issues or API errors.

  - `androidWakeDelayMs` - **Available in SDK version 3.1.0or later** - On Android, the
    number of milliseconds the SDK waits after a deep link wakes the app, before
    it invokes `urlHandler` (defaults to `1000`). Set this to `0` to dispatch
    synchronously.

  - `authCallbackTimeoutMs` - **Available in SDK version 3.1.0or later** - The number of
    milliseconds the SDK waits on the auth callback before it gives up on your
    `authHandler` (defaults to `6000`). This is a safety-net fallback only: the
    SDK resolves as soon as the native auth success or failure event arrives, and
    this timeout applies only when no such event arrives within the configured
    window. The default comfortably exceeds a typical mobile auth round-trip while
    staying below the native 30-second auth latch on both iOS and Android.

#### Example SDK configuration

_JavaScript_

```javascript
import { IterableConfig } from '@iterable/react-native-sdk';

const config = new IterableConfig();
config.authHandler = () => {
    // ... Fetch a JWT from your server, or locate one you've already retrieved
    return new Promise(function (resolve, reject) {
        // Resolve the promise with a valid auth token for the current user
        resolve("<AUTH_TOKEN>")
    });
};
config.autoPushRegistration = false;

Iterable.initialize('<YOUR_API_KEY>', config);
```

This example demonstrates how an app that uses a JWT-enabled API key might
initialize the SDK. To make requests to Iterable's API using a JWT-enabled API
key, you should first fetch a valid JWT for your app's current user from your
own server, which must generate it. The `authHandler` provides this JWT to
Iterable's React Native SDK, which can then append the JWT to subsequent API
requests. The SDK automatically calls `authHandler` at various times:

- When your app sets the user's email or user ID.

- When your app updates the user's email.

- Before the current JWT expires (at a configurable interval set by
  `expiringAuthTokenRefreshPeriod`)

- When your app receives a 401 response from Iterable's API with a
  `InvalidJwtPayload` error code. However, if the SDK receives a second
  consecutive 401 with an `InvalidJwtPayload` error when it makes a request with
  the new token, it won't call the `authHandler` again until you call `setEmail`
  or `setUserId` without passing in an auth token.

  :::tip TIP
  The `setEmail` and `setUserId` mobile SDK methods accept an optional,
  prefetched auth token. If you encounter SDK errors related to auth token
  requests, try using this parameter.
  :::

For more information about JWT-enabled API keys, read [JWT Authentication with
Iterable's React Native SDK](https://support.iterable.com/hc/articles/43901001355412)
and [JWT-Enabled API Keys](https://support.iterable.com/hc/articles/360050801231).

### Step 7: Test your apps

To test that you've successfully set up Iterable's React Native SDK in your iOS
and Android apps, follow these instructions once for each platform:

1. At some point in your app's React Native code, call `Iterable.setEmail`,
   passing in a test email address that does not yet exist in your Iterable
   project. For example:

   ```javascript
   Iterable.setEmail("user@example.com");
   ```

2. Run the app until it calls `setEmail`, which creates an Iterable user
   profile.

   - Test your iOS app on a physical device. When prompted, allow the
     app to display push notifications.

   - Test your Android app on a physical device or an emulator.

3. To verify that Iterable now has a user profile for the new email address,
   navigate to **Audience > Contact Lookup** and search it.

4. Send a push notification:

   - For iOS, move the app to the background (since some iOS apps do not display
     push notifications for apps that are in the foreground).

   - In Iterable, create a push notification campaign. While creating the
     campaign, send a test message to the email address configured above. The
     push notification should appear on the device.

If the above steps don't work, make sure that you're using a valid mobile API
key in your React Native code, and that you've correctly configured your iOS and
Android projects, as described in this article. If you're still having trouble,
contact Iterable Support.

## Upgrading the SDK

Here are some instructions that describe how to upgrade from earlier versions of
Iterable's React Native SDK.

### Upgrading to version 3.1.0

Version 3.1.0 of Iterable's React Native SDK adds `Iterable.registerDeviceToken`
to re-enable push for the current device, along with two new `IterableConfig`
options: `androidWakeDelayMs` and `authCallbackTimeoutMs` (see
[Step 6: Initialize Iterable's React Native SDK](#step-6-initialize-iterable-s-react-native-sdk)).
The new APIs are additive, so no code changes are required to upgrade.

This version also changes the iOS `Iterable.initialize` promise contract to match
Android: the promise now resolves as soon as the native SDK is initialized,
instead of waiting for the first in-app messages fetch to settle. If your app
relies on `await Iterable.initialize(...)` gating on that fetch, note that it no
longer does (initialization was already synchronous and non-failable on iOS).

To learn more, read the
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/3.1.0).

### Upgrading to version 3.0.1

Version 3.0.1 of Iterable's React Native SDK updates the React Native version it
is based on to 0.85. No code changes are required to upgrade.

To learn more, read the
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/3.0.1).

### Upgrading to version 3.0.0

Version 3.0.0 of Iterable's React Native SDK provides support for [Embedded Messaging](https://support.iterable.com/hc/articles/23060529977364).

To learn more about using Embedded Messaging with React Native, see [Embedded Messages with Iterable's React Native SDK](https://support.iterable.com/hc/articles/49144129810324).

### Upgrading to version 2.2.0

Version 2.2.0 of Iterable's React Native SDK provides support for [JWT authentication](https://support.iterable.com/hc/articles/43901001355412).

This version also updates the underlying native SDKs to:
- **iOS SDK**: [6.6.3](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.6.3)
- **Android SDK**: [3.6.2](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.2)

To learn more about upgrading to this version of the SDK, read the
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/2.2.0).

**As of version 2.2.1**, you no longer need to configure dynamic pods
(`use_frameworks! :linkage => :dynamic`) in your iOS Podfile for the Iterable
SDK. You can remove that configuration if you added it for earlier SDK versions.

### Upgrading to version 2.1.0

Version 2.1.0 of Iterable's React Native SDK is compatible with
[React Native's New Architecture](https://reactnative.dev/architecture/landing-page).
See [Configuring React Native's New Architecture](#configuring-react-native-s-new-architecture)
for setup details, including guidance about React Native 0.83 or later requiring 
New Architecture.

### Upgrading to version 2.0.0

Version 2.0.0 of Iterable's React Native SDK upgrades the
React Native dependency to version 0.75.3, and updates any dependencies.

There is also a new example app that demonstrates how to use the SDK.

To learn more about upgrading to this version of the SDK, read the 
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/2.0.0).

### Upgrading to version 1.3.9

Version 1.3.9 of Iterable's React Native SDK allows iOS apps to store in-app
messages in memory, rather than in an unencrypted local file.

To learn more about upgrading to this version of the SDK, read the 
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.9).

### Upgrading to version 1.3.7

Version 1.3.7 of Iterable's React Native SDK, as a privacy enhancement, includes
support for encrypting some data stored at rest. Additionally, it allows Android
apps to store in-app messages in memory, rather than in an unencrypted local
file.

To learn more about upgrading to this version of the SDK, read the 
[release notes](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.7).

### Upgrading to version 1.2.0

When upgrading to version 1.2.0 of Iterable's React Native SDK, you'll need
to provide a value for the `allowedProtocols` array on `IterableConfig`. This
array tells the SDK what types of links it can expect to find in the campaigns
you send from Iterable, so that it knows it's safe to handle them.  For more
details, read [Initializing Iterable's React Native SDK](#step-6-initialize-iterable-s-react-native-sdk).
