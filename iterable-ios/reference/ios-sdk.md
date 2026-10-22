---
slug: ios-sdk
feature: integration
archetype: integration
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Iterable's iOS SDK
source_url: https://support.iterable.com/hc/articles/360035018152
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-ios-and-android-sdks/ios-sdk/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 72f4ba330ca899ba42a7c4c9c18fa79c4e728bd1
fetched_at: 2026-10-02T13:52:10.127Z
summary: Iterable's [iOS SDK](https://github.com/Iterable/iterable-swift-sdk)
  supports features such as push notifications, in-app messages, deep links, and
  Mobile Inbox. This article describes how to install and configure the SDK to
  work with Iterable.
---
# Iterable's iOS SDK

Iterable's [iOS SDK](https://github.com/Iterable/iterable-swift-sdk) supports features 
such as push notifications, in-app messages, deep links, and Mobile Inbox.
This article describes how to install and configure the SDK to work with
Iterable.

## In this article

To install and configure Iterable's iOS SDK, follow these steps:

[[toc]]

## Supported iOS versions

Iterable's iOS SDK supports iOS 10 and higher.

## Encrypted data

Iterable's iOS SDK encrypts some data at rest. For more information, read 
[Upgrading to 6.4.8](#upgrading-to-6-4-8).

## Installation steps

Follow these steps to install the SDK. If you're upgrading from a previous 
version, also see [Upgrading the SDK](#upgrading-the-sdk).

### Step 1: Create a Notification Service Extension (if necessary)

For an iOS app to support push notifications that contain action buttons, images, 
videos or custom sounds, its Xcode project must contain a [Notification Service Extension](https://developer.apple.com/documentation/usernotifications/unnotificationserviceextension).
It's helpful to set your app's Notification Service Extension target up before 
installing and configuring the SDK.

To add a Notification Service Extension target to your Xcode project:

1. Open your app's Xcode project.

2. Choose **File > New > Target**.

3. On the **iOS** tab, select **Notification Service Extension**:

4. Click **Next**.

5. Provide all necessary configuration information for the Notification Service
   Extension. 

6. Click **Finish**.

Next, install the SDK using one of the methods described below. Then, 
[configure the Notification Service Extension](#step-3-configure-the-notification-service-extension-if-necessary)

### Step 2: Install the SDK

To install the SDK, use the Swift Package Manager, CocoaPods, Carthage, or
install it manually.

> [!WARNING]
> Starting with version [`6.4.0`](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.0),
> Iterable's iOS SDK no longer supports iOS 9. For iOS 9 support, use version 
> [`6.3.4`](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.3.4).

#### Step 2.1: Install the SDK with the Swift Package Manager

[Swift Package Manager](https://swift.org/package-manager) is an Xcode tool that
installs project dependencies. To use it to install Iterable's iOS SDK, follow these
steps:

> [!NOTE]
> The Swift Package Manager can install versions 6.2.0 and higher of Iterable's
> iOS SDK.

1. In Xcode, click **File > Add Packages...**.

2. In the window that opens, enter `https://github.com/Iterable/iterable-swift-sdk`
   in the upper-right corner:
   
   ![Adding Iterable's iOS SDK using the Swift Package Manager](https://support.iterable.com/hc/article_attachments/6332929091732/adding-the-package.png "Adding Iterable's iOS SDK using the Swift Package Manager")

3. Use the **Dependency Rule** and **Add to Project** options to specify which
   version of the SDK you'd like to add, and the project to which you'd like to
   add it. For example, to use the latest version of the SDK found the current
   major version sequence, choose **Up to Next Major Version** for 
   **Dependency Rule** and enter `6.0.0` for the lower version number.

   For more information about these options, see the **Decide on Package Requirements**
   section of Apple's guide, [Adding Package Dependencies to Your App](https://developer.apple.com/documentation/swift_packages/adding_package_dependencies_to_your_app).

4. Click **Add Package**.

5. When prompted to choose package products:
   
   ![Choosing package products](https://support.iterable.com/hc/article_attachments/6332993770644/choose-package-products.png "Choosing package products")

   - Check **IterableSDK**, and choose the target associated with your app.

   - If you'll send push notifications with action buttons, images, videos, or 
     custom sounds, check **IterableAppExtensions**. Then, choose the target
     associated with your app's Notification Service Extension.

6. Click **Add Package**.

The packages will be added to your app.

#### Step 2.2: Install the SDK with CocoaPods 

To use [CocoaPods](https://cocoapods.org) to install Iterable's iOS SDK, follow
these steps:

1. [Install CocoaPods](https://guides.cocoapods.org/using/getting-started.html).

2. If your project does not yet have a `Podfile`, create one:

   - In the terminal, navigate to the directory containing your project's
     .xcodeproj file. 

    - Run this command: `pod init`.

3. Edit the `Podfile`:

   - In this file, add the `Iterable-iOS-SDK` pod to your project's app 
     target. 

   - If you will send push notifications that contain action buttons, images, 
     videos or custom sounds, add the `Iterable-iOS-AppExtensions` pod to your 
     project's [Notification Service Extension](#step-3-configure-the-notification-service-extension-if-necessary).

   - After these changes, your `Podfile` should look similar to this:

     ```ruby
     platform :ios, '11.0'

     target '<YOUR_APP_TARGET>' do
         pod 'Iterable-iOS-SDK'
     end

     target '<YOUR_NOTIFICATION_EXTENSION_TARGET>' do
         pod 'Iterable-iOS-AppExtensions'
     end
     ```

     :::tip NOTE
     In versions 6.3.3 and above of Iterable's iOS SDK, it's no longer necessary 
     to include `use_frameworks!` in your `Podfile`.
     :::

4. In the terminal, run `pod install` to install the pods you configured in the
   previous step. If you see errors, try `pod install --repo-update` ([docs](https://guides.cocoapods.org/terminal/commands.html#pod_install)).

5. Your project now has an .xcworkspace file. Use this file to open your project,
   instead of its `.xcodeproj` file.

For more information, read the [CocoaPods](https://cocoapods.org) documentation.

#### Step 2.3: Install the SDK with Carthage

To use [Carthage](https://github.com/Carthage/Carthage) to install Iterable's iOS 
SDK, follow these steps:

##### Step 2.3.1: Add IterableSDK.framework
 
First, add `IterableSDK.framework` to your project:

1. [Install Carthage](https://github.com/Carthage/Carthage#installing-carthage).

2. Create a `Cartfile` in the same directory as your .xcodeproj or .xcworkspace
   file.

3. Add this line to the `Cartfile`:

   ```
   github "Iterable/swift-sdk" 
   ```

4. Open a terminal window. In it, navigate to the same directory as your 
   `Cartfile`.

5. Run this command: `carthage update`.

6. From the terminal, open a Finder window: `open .`. In this window, navigate to
   the `Carthage/Build/iOS` subdirectory. Keep this window open.

7. Open your app's Xcode project.

8. From the Finder window opened above, drag `IterableSDK.framework` onto
   Xcode's Project Navigator (far left column). When prompted, add the framework 
   to your app target.

9. In Xcode's Project Navigator, select the top item, which corresponds to the
   project itself.

10. Under **Targets**, select your app.

11. Navigate to **Build Phases**.

12. Add a build phase by clicking **+** and selecting **New Run Script Phase**.
    A **Run Script** section will appear.

13. In the new **Run Script** section, add this command in the text area:

    ```
    /usr/local/bin/carthage copy-frameworks
    ```

14. In the **Input Files** section, click **+** and add:

    ```
    $(SRCROOT)/Carthage/Build/iOS/IterableSDK.framework
    ```

15. In the **Output Files** section, add the path to the copied framework:

    ```
    $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/IterableSDK.framework
    ```

##### Step 2.3.2: Add IterableAppExtensions.framework

If you will send push notifications that have action buttons, images, videos or
custom sounds, follow these steps, too:

1. Open your app's Xcode project.

2. From the Finder window opened in the previous section, drag `IterableAppExtensions.framework`
   onto Xcode's Project Navigator (far left column). When prompted, add the 
   framework to your Notification Service Extension target.

3. In Xcode's Project Navigator, select the top item, which corresponds to the
   project itself.

4. Under **Targets**, select your Notification Service Extension.

5. Navigate to **Build Phases**.

6. Add a build phase by clicking **+** and selecting **New Run Script Phase**.
   A **Run Script** section will appear.

7. In the new **Run Script** section, in the script text area, add this command:

   ```
   /usr/local/bin/carthage copy-frameworks
   ```

8. In the **Input Files** section, click **+** and add this path:

   ```
   $(SRCROOT)/Carthage/Build/iOS/IterableAppExtensions.framework
   ```

9. In the **Output Files** section, add the path to the copied framework:

   ```
   $(BUILT_PRODUCTS_DIR)/$(FRAMEWORKS_FOLDER_PATH)/IterableAppExtensions.framework
   ```

### Step 3: Configure the Notification Service Extension (if necessary)

If you added a Notification Service Extension to your project ([above](#step-1-create-a-notification-service-extension-if-necessary)),
set it up to handle media attachments and action buttons. To do this, use the 
`ITBNotificationServiceExtension` class provided by Iterable's iOS SDK:

1. Open the `NotificationService` class (auto-generated by Xcode when you added 
   the Notification Service Extension to your project).

2. For Swift-based projects:

   - Add an import: `import IterableAppExtensions`.

   - Update `NotificationService` so that it extends `ITBNotificationServiceExtension`,
     and contains no other code:
      
     ```swift
     import UserNotifications
     import IterableAppExtensions

     class NotificationService: ITBNotificationServiceExtension { }
     ```
     :::warning IMPORTANT
     If you're using React Native, you may need to install some Objective-C
     compatibility headers and use different import statements. For more information, 
     read [Installing Iterable's React Native SDK — Step 3.3: Import the SDK](https://support.iterable.com/hc/articles/360045714132#step-3-3-import-the-sdk).
     :::

3. For Objective-C projects:

   - Add an import: `@import IterableAppExtensions;`.

   - Configure the class so that it's similar to the following:

     ```objectivec
     // File: NotificationService.m
     #import "NotificationService.h"
 
     @import IterableAppExtensions;
 
     @interface NotificationService ()
 
     @property (nonatomic, strong) ITBNotificationServiceExtension *baseExtension;
     @end
 
     @implementation NotificationService
     - (void)didReceiveNotificationRequest:(UNNotificationRequest *)request withContentHandler:(void (^)(UNNotificationContent * _Nonnull))contentHandler {
         self.baseExtension = [[ITBNotificationServiceExtension alloc] init];
         [self.baseExtension didReceiveNotificationRequest:request withContentHandler:contentHandler];
     }
 
     - (void)serviceExtensionTimeWillExpire {
         [self.baseExtension serviceExtensionTimeWillExpire];
     }
     @end
     ```
   
### Step 4: Import IterableSDK wherever necessary

To use Iterable's iOS SDK in your app's code, import it at the top of any Swift 
or Objective-C files that reference it. For example:

_Swift_

```swift
// In AppDelegate.swift and any other file where you're using IterableSDK
import IterableSDK
```

_Objective-C_

```objectivec
// In AppDelegate.m and any other file where you're using IterableSDK
@import IterableSDK;
```

> [!WARNING]
> If you're using React Native, you may need to install some Objective-C
> compatibility headers and use different import statements. For more information, 
> read [Installing Iterable's React Native SDK — Step 3.3: Import the SDK](https://support.iterable.com/hc/articles/360045714132#step-3-3-import-the-sdk).

### Step 5: Create a mobile API key 

To make calls to Iterable's's API, the SDK needs a mobile [API key](https://support.iterable.com/hc/articles/360043464871). 
To learn how to create one, read [API Keys](https://support.iterable.com/hc/articles/360043464871)

> [!WARNING]
> **Never** embed server-side API keys in client-side code (whether JavaScript, a 
> mobile application or otherwise), since they can be used to access all of your
> project's data. For a mobile app, use a mobile API key (if possible, we 
> recommend using [JWT authentication](https://support.iterable.com/hc/articles/360050801231)
> for additional security).

If necessary, use different API keys for debug and production builds.

### Step 6: Initialize the SDK with your API key

Next, you'll need to make a few updates in your app delegate's 
[`application(_:didFinishLaunchingWithOptions:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622921-application)
method:

#### Step 6.1: Call `IterableAPI.initialize`

Call `initialize(apiKey:launchOptions:config:)`, passing your Iterable API key
as a parameter:

_Swift_

```swift
let config = IterableConfig()
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config: config)
```

_Objective-C_

```objectivec
IterableConfig *config = [[IterableConfig alloc] init];
[IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" config:config]
```

`IterableConfig` provides configuration and customization options for the
Iterable SDK. You'll use it later to set up push notifications and in-app 
messages.

#### Step 6.2: If necessary, configure the SDK to use Iterable's EDC

If your project is hosted on Iterable's [European data center (EDC)](https://support.iterable.com/hc/articles/17572750887444),
configure the SDK to use Iterable's EDC-based endpoints:

_Swift_

```swift
let config = IterableConfig()
config.dataRegion = IterableDataRegion.EU
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions: launchOptions, config: config)
```

_Objective-C_

```objectivec
IterableConfig *config = [[IterableConfig alloc] init];
config.dataRegion = IterableDataRegion.EU
[IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions config:config]
```

#### Step 6.3: Set the `allowedProtocols` field

Starting with version [`6.4.0`](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.0) 
of Iterable's iOS SDK, you'll need to declare the specific URL protocols that the 
SDK can expect to see on incoming links (and that it should handle as needed). This
prevents the SDK from opening links that use unexpected URL protocols.

To do this, set the `allowedProtocols` field (on the `IterableConfig` object you
pass to the SDK's `initialize` method) to an array that contains the protocols you'd
like the SDK to support.

For example, this code allows the SDK to handle `http://`, `tel://`, and `custom://`
links:

_Swift_

```swift
let config = IterableConfig()
config.allowedProtocols = ["http", "tel", "custom"]
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
```

_Objective-C_

```objectivec
IterableConfig *config = [[IterableConfig alloc] init];
config.allowedProtocols = @["http", "tel", "custom"];
[IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions, config:config]
```

> [!WARNING]
> Iterable's iOS SDK handles `https`, `action`, `itbl`, and `iterable` links,
> regardless of the contents of this array. However, you must explicitly declare any
> other types of URL protocols you'd like the SDK to handle (otherwise, the SDK
> won't open them in the web browser or as deep links).

#### Step 6.4: Set up a push integration

In Iterable, you'll create logical _mobile apps_ to store information about 
your real mobile apps—including information about the configuration parameters
Iterable needs to send push notifications to them. Iterable refers to these 
push notification configuration parameters as _push integrations_.

> [!TIP]
> Older push integrations may not yet be associated in Iterable with a mobile
> app. However, you can [assign them](https://support.iterable.com/hc/articles/115000331943#step-3-add-a-push-integration-to-the-mobile-app).

By default, the SDK expects your push integration's name to match your app's
bundle ID.  However, if your Iterable push integration was created before August
2019, it may have a custom name. To handle this, do one of the following things:

- In Iterable, [assign](https://support.iterable.com/hc/articles/115000331943#step-3-add-a-push-integration-to-the-mobile-app)
  the existing push integration to a mobile app. If you do this, the SDK will
  use the push integration that matches your mobile app's bundle ID.

- Alternatively, specify the custom push integration name when initializing 
  the SDK:

  _Swift_

  ```swift
  let config = IterableConfig()
  config.pushIntegrationName = "<PUSH_INTEGRATION_NAME>"
  IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
  ```

  _Objective-C_

  ```objectivec
  IterableConfig *config = [[IterableConfig alloc] init];
  config.pushIntegrationName = @"<PUSH_INTEGRATION_NAME>";
  [IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions, config:config]
  ```

  :::tip TIP
  To find the name of your push integration, navigate in Iterable to **Settings > Apps and websites**, 
  open the mobile app that's associated with your actual app, look at the 
  **Details** section, and find the **Package Name**.
  :::

#### Step 6.5: Choose whether or not to use in-memory storage for in-app messages

By default, Iterable's iOS SDK stores in-app messages in an unencrypted local
file. To instead store in-app messages in memory, set `useInMemoryStorageForInApps` 
to `true`:

_Swift_

```swift
let config = IterableConfig()
config.useInMemoryStorageForInApps = true
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
```

_Objective-C_

```objectivec
IterableConfig *config = [[IterableConfig alloc] init];
config.useInMemoryStorageForInApps = YES;
[IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions, config:config];
```

For more information, read [Upgrading to 6.4.9](#upgrading-to-6-4-9).

#### Step 6.6: Handle JWT-enabled API keys
    
If you're using a [JWT-enabled API Key](https://support.iterable.com/hc/articles/360050801231),
you'll need custom code to manage JWT tokens for the signed-in user.

##### Step 6.6.1: Register an auth handler

When initializing the SDK, provide an auth handler. The SDK uses the auth 
handler to:

1. Fetch new JWT tokens from your server. 
2. Report when a non-null JWT token has been retrieved.
3. Report when there have been failures fetching new JWT tokens.

The object that you pass to the SDK as an auth manager must implement the
`IterableAuthDelegate` protocol:

```swift
@objc public protocol IterableAuthDelegate: AnyObject {
    @objc func onAuthTokenRequested(completion: @escaping AuthTokenRetrievalHandler)
    @objc func onAuthFailure(_ authFailure: AuthFailure)
}
```

For example, you might use your `AppDelegate` as your `IterableAuthDelgate`:

```swift
extension AppDelegate: IterableAuthDelegate {

    // ...

    func onAuthTokenRequested(completion: @escaping AuthTokenRetrievalHandler) {
        // Fetch a JWT token for the signed-in user, from your server, and 
        // return it to the SDK.
        completion("<JWT_TOKEN_FOR_THE_CURRENT_USER>")
    }

    func onAuthFailure(_ authFailure: AuthFailure) {
        // Inspect the authFailure enum case and take any necessary action. For 
        // example, you can pause auth retries (see section 5.5.3, below).
    }

    // ...
}

// Then, when initializing the SDK...
let config = IterableConfig()
config.authDelegate = self
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
```

> [!WARNING]
> You'll need to keep a strong reference to your `IterableAuthDelegate` instance.
> `IterableConfig` only holds a weak reference to it.

**`onAuthTokenRequested`** 

The SDK calls `onAuthTokenRequested` when it needs a new JWT token for the 
signed-in user. This method should fetch a new JWT token from your server and
return it to the SDK as a string. 

This method is called when:

- You identify a user by calling `setEmail` or `setUserId`.
- You update a user's email address by calling `updateEmail`.
- The current JWT token has expired, or is about to expire.
- The SDK receives a JWT-related `401` response from Iterable's API.

**`onAuthFailure`**

The SDK calls `onAuthFailure` after it fails to fetch a new JWT token for the 
signed-in user. The `AuthFailure` object passed to this method describes the 
reason for the failure, along with other information.

This method is called when:

- `onAuthTokenRequested` returns `null`.
- `onAuthTokenRequested` throws an exception.
- The SDK receives a JWT-related `401` response from Iterable's API.
- The token returned by `onAuthTokenRequested` is invalid.

In `onAuthFailure`, to determine the reason for the failure, inspect the 
`AuthFailure` object, which has these properties:

- `userKey` - A string that identifies the user by `userId` or `email`.
- `failedAuthToken` - The JWT token that caused the failure.
- `failedRequestTime` - The timestamp of the failed request, if applicable.
- `failureReason` - An `AuthFailureReason` enum case that indicates the reason 
  for the failure. 
  
`AuthFailureReason` can be:

- `authTokenExpirationInvalid` – An auth token's expiration must be less than 
   one year from its issued-at time.
- `authTokenExpired` – The token has expired.
- `authTokenFormatInvalid` – Token has an invalid format (failed a regular 
   expression check).
- `authTokenGenerationError` – `onAuthTokenRequested` threw an exception.
- `authTokenGenericError` – Any other error not captured by another constant.
- `authTokenInvalidated` – Iterable has invalidated this token and it cannot 
   be used.
- `authTokenNull` – `onAuthTokenRequested` returned a null JWT token.
- `authTokenPayloadInvalid` – Iterable could not decode the token's payload 
   (`iat`, `exp`, `email`, or `userId`).
- `authTokenSignatureInvalid` – Iterable could not validate the token's 
   authenticity.
- `authTokenUserKeyInvalid` – The token doesn't include an `email` or a `userId`. 
   Or, one of these values is included, but it references a user that isn't in the
   Iterable project.
- `authTokenMissing` – The request to Iterable's API did not include a JWT
   authorization header.

> [!TIP]
> You can also provide a JWT token for the current user by passing it directly to 
> `setEmail` or `setUserId`.

##### Step 6.6.2: Set an expiring token refresh period

To specify how long before the expiration of the user's current JWT token 
the SDK should call your [auth token refresh handler](#step-6-6-1-register-an-auth-handler),
to fetch a new token, set `expiringAuthTokenRefreshPeriod` on `IterableConfig`:

```swift
let config = IterableConfig()
// ... other configuration options ...
config.expiringAuthTokenRefreshPeriod = 45.0
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
```

##### Step 6.6.3: Set an auth retry policy

To control how the SDK handles consecutive JWT token refresh attempts, specify
an auth retry policy. An auth retry policy allows you to control:

- The number of consecutive times the SDK should attempt to refresh a user's JWT
  token, in between successful API calls, before giving up.
- The interval between those attempts.
- A backoff strategy.

```swift
// When creating a RetryPolicy object, specify a maximum number of retries, an 
// interval between retries, and a backoff strategy: .linear or .exponential. 
// The SDK's default RetryPolicy has a maximum of 10 retries, an interval of 6 
// seconds, and a linear backoff strategy.
let config = IterableConfig()
// ... other configuration options ...
config.retryPolicy = RetryPolicy(maxRetry: 10, retryInterval: 5, retryBackoff: .linear)
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", config: config)
```

After the SDK reaches the maximum number of consecutive JWT-related request
failures, as configured by your `RetryPolicy`, it stops attempting to refresh
the JWT token.

> [!TIP]
> **Auto-retry for offline processing (6.7.0+)**
>
> In addition to the `RetryPolicy` above (which controls JWT refresh scheduling),
> the SDK supports automatic retry for offline-queued tasks that fail due to JWT
> expiration. When this feature is enabled, the offline task runner pauses
> authenticated tasks on a 401 error, refreshes the JWT, and retries
> automatically. Unauthenticated API calls continue processing while
> authentication is paused. This feature requires no code changes.
>
> This feature is not enabled by default. To turn it on for your project, ask
> your Iterable customer success manager to enable it for your account.

##### Step 6.6.4: Pause JWT token refresh

You can _manually_ pause JWT token refresh attempts. To do this, call:

```swift
IterableAPI.pauseAuthRetries(true) // or false
```

When JWT refresh attempts have been paused, they'll only resume after:

- You provide a new JWT token to the SDK, by calling `setAuthToken`.
- You identify the user by setting `setEmail` or `setUserId`.
- You update the user's email by calling `updateEmail`.
- The app restarts.
- You manually pause and unpause JWT token refresh attempts, by calling:
  ```swift
  // If you didn't manually pause JWT refresh attempts in the first place,
  // first pause the retries, and then unpause them.
  IterableAPI.pauseAuthRetries(true)
  IterableAPI.pauseAuthRetries(false)
  ```

### Step 7: Enable push notifications

> [!WARNING]
> Iterable sends push notifications to iOS apps for two reasons:
>
> - When you send push notification campaigns
> - Silently, to tell the app to download new in-app messages
>
> Because Iterable uses silent push notifications to help deliver in-app messages, 
> configure your app to support push notifications even if you do not plan to send 
> push notification campaigns.

To enable push notifications, follow the steps described below. 

#### Step 7.1: Set up iOS push notifications in Iterable

Follow the instructions in Iterable's [Setting up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806)
guide. This document describes how to configure your iOS app's App ID to use push
notifications, and how to set up a mobile app (and associated push integration)
in Iterable's web app.

#### Step 7.2: Add the Push Notifications capability to your app

Follow Apple's [instructions to add the Push Notifications capability](https://developer.apple.com/documentation/xcode/adding_capabilities_to_your_app)
to your app. 

If you'll be sending [Time Sensitive](https://developer.apple.com/design/human-interface-guidelines/ios/system-capabilities/notifications)
push notifications (introduced in iOS 15), also add the Time Sensitive 
Notifications capability. For more information about Time Sensitive 
notifications, check out [this WWDC 2021 talk](https://developer.apple.com/videos/play/wwdc2021/10091).

#### Step 7.3: Enable the Remote Notifications background mode

Follow Apple's [instructions to enable the Remote Notifications background mode](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/pushing_background_updates_to_your_app)
in your app.

#### Step 7.4: Fetch a device token from Apple and register it with Iterable

For Iterable to send push notifications to an iOS device, it must know the unique
token assigned to that device by Apple.

By default, Iterable's SDK automatically fetches this token from Apple when the
application's code sets `IterableAPI.email` or `IterableAPI.userId` (which also
disables the device token for the previous `email` or `userId`, preventing Iterable 
from sending push notifications to that user on that device). To fetch the token, 
the SDK calls [`registerForRemoteNotifications()`](https://developer.apple.com/documentation/uikit/uiapplication/1623078-registerforremotenotifications)
on `UIApplication`.

> [!NOTE]
> If you set `IterableConfig.autoPushRegistration` to `false`, the SDK does not
> automatically register for a device token. In this case:
>
> - Call [`registerForRemoteNotifications()`](https://developer.apple.com/documentation/uikit/uiapplication/1623078-registerforremotenotifications)
>   to register for a token when necessary. 
> - To manually disable push notifications for the current user, call `IterableAPI.disableDeviceForCurrentUser()`.

After fetching a device token, iOS passes it to the [`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1622958-application)
method on the app delegate. Configure this method to register the token with
Iterable's SDK, which saves it the user's Iterable profile:

_Swift_

```swift
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    IterableAPI.register(token: deviceToken)
}
```
    
_Objective-C_

```objectivec
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [IterableAPI registerToken:deviceToken];
}
```

#### Step 7.5: Handle incoming push notifications and enable push notification tracking

To handle incoming push notifications, and to allow Iterable to track events when
a user interacts with push notifications, follow these steps:

1. For some object in your app, conform to the [`UNUserNotificationCenterDelegate`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate)
   protocol (apps commonly use the app delegate for this purpose). Import the 
   `UserNotifications` framework, indicate that the class conforms to the 
   protocol, and implement these methods:

   - [`userNotificationCenter(_:willPresent:withCompletionHandler:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/1649518-usernotificationcenter)

     This method can be used to allow your app to display incoming push
     notifications when it is in the foreground.

   - [`userNotificationCenter(_:didReceive:withCompletionHandler:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenterdelegate/1649501-usernotificationcenter)

     iOS calls this method when a user interacts with a push notification.
     From here, Iterable's SDK can create events associated with these
     interactions.

2. Set this object as the delegate for the current [`UNUserNotificationCenter`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter).

For example, Iterable's [Swift](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/swift-sample-app/swift-sample-app/AppDelegate.swift)
and [Objective-C](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/objc-sample-app/objc-sample-app/AppDelegate.m)
sample projects have app delegate code similar to the following:

_Swift_

```swift
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // ...
        UNUserNotificationCenter.current().delegate = self
        // ...
    }
    // ...
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_: UNUserNotificationCenter, willPresent _: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.badge, .banner, .list, .sound])
    }

    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        IterableAppIntegration.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
    }
}

```

_Objective-C_

```objectivec
@implementation AppDelegate

// In its .h file, the AppDelegate class declares that it conforms to UNUserNotificationCenterDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // ...
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    // ...
}

##pragma mark - UNUserNotificationCenterDelegate
- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBadge | UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionList | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    [IterableAppIntegration userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:completionHandler];
}

@end
```

> [!NOTE]
> To learn more about push notifications on iOS, read Apple's documentation about 
> the [UserNotifications framework](https://developer.apple.com/documentation/usernotifications).

#### Step 7.6: (Optional) Request authorization to display push notifications

> [!WARNING]
> Complete the steps in this section if you plan to use Iterable to send push
> notification campaigns to your app. Otherwise, they are unnecessary.

iOS apps must have explicit user permission to display push notification 
alerts, play push notification sounds or update icon badges based on push 
notifications. 

To request this permission, display a prompt by calling the [`requestAuthorization(options:completionHandler:)`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter/1649527-requestauthorization)
method on [`UNUserNotificationCenter`](https://developer.apple.com/documentation/usernotifications/unusernotificationcenter).
This is usually done from somewhere in the app delegate. For example:

_Swift_

```swift
UNUserNotificationCenter.current().requestAuthorization(options:[.alert, .badge, .sound]) { (success, error) in
    if success == true {
        // ...
    }
}
```

_Objective-C_

```objectivec
[[UNUserNotificationCenter currentNotificationCenter] requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound) completionHandler:^(BOOL granted, NSError * _Nullable error) {
    if (granted) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // ...
        });
    } 
}];
```

> [!TIP]
> To learn more about asking for permission to display notifications, read Apple's 
> [Asking Permission to Use Notifications](https://developer.apple.com/documentation/usernotifications/asking_permission_to_use_notifications)
> guide.

### Step 8: Enable in-app messages

To enable in-app messages, follow these steps:

1. [Enable push notifications](#step-7-enable-push-notifications). 

   Iterable uses silent push notifications to notify an app about new in-app
   messages awaiting delivery. Because of this, enable push notifications even
   if you don't plan to send push notification campaigns.

2. Let Iterable's SDK know when the app receives a push notification. This way,
   it knows to go fetch waiting in-app messages. 
   
   To do this, implement the app delegate's [`application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application)
   method. In it, call the identically named method on `IterableAppIntegration`. 
   For example:

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

   :::tip TIP
   You can also use this method to handle silent push notifications, inspecting
   their payload and kicking off any necessary actions.
   :::

### Step 9: Verify that the SDK can communicate with Iterable

To test that your app can communicate with Iterable:

1. In your app's code, after initializing the SDK with your API key, set 
   `IterableAPI.email` to a specific email address:

    _Swift_

    ```swift
    let config = IterableConfig()
    IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
    IterableAPI.email = "user@example.com"
    ```

    _Objective-C_

    ```objectivec
    IterableConfig *config = [[IterableConfig alloc] init];
    [IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions, config:config]
    IterableAPI.email = @"user@example.com";
    ```

2. Run the app on a physical device (not the simulator).

   Registering for a push notification token from Apple can only be done on a
   physical device.

3. Check to make sure the new user is visible in Iterable:

   - Open the Iterable project associated with the API key used in your app's 
     code.

   - Navigate to **Audience > Contact Lookup**.

   - Enter the email address used above and click **Search Users**.

   - The user's profile should appear.

If you're having trouble, make sure that you have:

- [Added the push notification capability to your app](#step-7-2-add-the-push-notifications-capability-to-your-app)
- [Enabled the remote notifications background mode](#step-7-3-enable-the-remote-notifications-background-mode)

## Embedded Messaging

To learn how to use Iterable's iOS SDK with Embedded Messaging, read
[Embedded Messages with Iterable's iOS SDK](https://support.iterable.com/hc/articles/23061840746900).

## Upgrading the SDK

This section describes how to upgrade from earlier versions of Iterable's
iOS SDK.

### Upgrading to 6.7.5

[Version 6.7.5](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.7.5)
of Iterable's iOS SDK adds an availability signal for JSON-only in-app messages
(`onJsonOnlyMessageAvailable(message:)` on `IterableInAppDelegate`, the
`iterableJsonOnlyInAppMessageAvailable` notification,
`getUnhandledJsonOnlyMessages()`, and `markJsonOnlyMessageHandled(messageId:)`),
and updates `inAppConsume` so it removes messages from the local queue and posts
`iterableInboxChanged` only when the message is saved to the inbox
(`saveToInbox = true`). **No code changes are required to upgrade** if you do
not use JSON-only messages or depend on `iterableInboxChanged` for non-inbox
removals. If your app previously listened for `iterableInboxChanged` when a
popup or JSON-only message was removed, move that logic to the JSON-only
availability APIs.

This version also fixes offline-queued requests retrying forever with an expired
JWT auth token, and scopes in-app fetch and delivery to the user identity that
started them. Both fixes apply automatically after upgrading.

For more information, read
[In-App Messages on iOS](https://support.iterable.com/hc/articles/360035536791)
and the [release notes for Iterable's iOS SDK](https://support.iterable.com/hc/articles/360027798391).

### Upgrading to 6.7.4

[Version 6.7.4](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.7.4)
of Iterable's iOS SDK adds two optional unknown user criteria fetch callbacks to
`IterableUnknownUserHandler` (`onCriteriaReceived(criteria:)` and
`onCriteriaFetchFailed(reason:)`), and makes in-app HTML rendering more resilient
by logging render failures and dismissing messages if the `WKWebView` content
process terminates. **No code changes are required to upgrade**, since the new
callbacks are additive and existing handlers are unaffected.

For more information, read the [release notes for Iterable's iOS SDK](https://support.iterable.com/hc/articles/360027798391)
and [Configure the iOS SDK](https://support.iterable.com/hc/articles/40078945603860)
in the Unknown User Activation documentation.

### Upgrading to 6.7.3

[Version 6.7.3](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.7.3)
of Iterable's iOS SDK adds `async`/`await` variants for disabling the device,
completion handlers for `logoutUser`, more readable `AuthFailureReason` debug
output, automatic offline retry for `register(token:)`, and fixes for a
CocoaPods crash when displaying out-of-the-box embedded messages and an in-app
message position bug in landscape. **No code changes are required to upgrade**—the
new APIs are additive, and the existing methods are unchanged.

If your app calls `register(token:)` before setting a current user identity and
monitors `onFailure` callbacks, expect this release to report
`"register(token:) called without a current user identity"` instead of silently
sending the request.

If you integrate the SDK with CocoaPods and use out-of-the-box embedded message
views, this release fixes a crash caused by a missing `IterableEmbeddedView.xib`
resource (the podspec now bundles the UI component XIBs). Apps that use Swift
Package Manager were not affected.

If you use [Unknown User Activation](https://support.iterable.com/hc/articles/38755339847188)
(for setup details, see [Configure the iOS SDK](https://support.iterable.com/hc/articles/40078945603860)),
note the following storage change:

> [!WARNING]
> Version 6.7.3 changes how Unknown User Activation data is stored in
> `UserDefaults`. After upgrading, avoid rolling back to an earlier SDK version: an
> older SDK can't decode the new sessions blob (the unknown user session counter
> resets to zero) and skips stored unknown-user events when flushing them (it
> looks for the old `dataType` discriminator). Identified user data, push
> registration, and other SDK functionality are unaffected; only the unknown user
> session counter and pending unknown-user events are lost if you roll back after
> upgrading.

For more information, read the [release notes for Iterable's iOS SDK](https://support.iterable.com/hc/articles/360027798391).

### Upgrading to 6.7.0

[Version 6.7.0](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.7.0)
of Iterable's iOS SDK removes the deprecated `trackEmbeddedDismiss` and
`trackEmbeddedImpression` methods and their underlying API endpoints. If your app 
references them, before upgrading, remove any calls to them and then follow the steps
in [Embedded Messages with Iterable's iOS SDK](https://support.iterable.com/hc/articles/23061840746900) 
to use `EmbeddedSessionManager.shared` to track sessions and impressions. These steps are
required to track embedded message sessions and impressions once you've removed the 
deprecated methods.

This update also provides a way to enable automatic retry for JWT 401 failures 
that occur during offline event processing. The setting is disabled by default, so 
contact your Iterable customer success manager to enable it for your project. No 
code changes are required. For more information, see [auto-retry note in Step 6.6.3: Set an auth retry policy](#step-6-6-3-set-an-auth-retry-policy).

### Upgrading to 6.6.6

[Version 6.6.6](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.6.6)
makes `IterableAPI.isIterableDeepLink(_:)` public so apps can call it directly before 
handling a URL. It also includes fixes for Carthage, shared keychain access groups, 
and full-screen in-app message display. 

No code changes are required for this update.

### Upgrading to 6.6.5

If your app uses Embedded Messaging, upgrade to [Version 6.6.5](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.6.5) if you want to manage embedded message sync successes or failures in your 
own code using the optional sync callbacks that are now available through 
`IterableEmbeddedUpdateDelegate`. With this release, you can also sync messages 
for specific placements instead of all placements at once using the new 
`placementIds` parameter for `IterableEmbeddedManager.syncMessages`.

In addition, this release improves retry behavior for concurrent API requests that fail
with JWT-related 401 errors. 

No code changes are required for this update. 

### Upgrading to 6.6.0

To enable Unknown User Activation, upgrade to [Version 6.6.0](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.6.0) of Iterable's iOS SDK and set `enableUnknownUserActivation` to `true` on `IterableConfig` 
before initializing the SDK. These code changes are only required if you want to use Unknown User 
Activation; otherwise, no changes are required.

```swift
let config = IterableConfig()
config.enableUnknownUserActivation = true
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions: launchOptions, config: config)
```

> [!WARNING]
> As of [6.7.1](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.7.1),
> `enableUnknownUserActivation` defaults to `false`. In versions 6.6.0 through
> 6.7.0 it defaulted to `true`, so if your app relied on this setting, set it to `true`
> explicitly when you upgrade.

For more information, read [Unknown User Activation: Developer Docs](https://support.iterable.com/hc/sections/40078809116180).

### Upgrading to 6.5.13

[Version 6.5.13](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.5.13) of
Iterable's iOS SDK requires `allowedProtocols` be set as part of URL validation 
when handling deep links.  

### Upgrading to 6.5.5

[Version 6.5.5](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.5.5) of
Iterable's iOS SDK provides more insight into JWT refresh failures, so you can
take appropriate action in your application code. 

- When a JWT refresh fails (for any of various reasons), the SDK calls
  `onAuthFailure(_ authFailure: AuthFailure)` on the `IterableAuthDelegate`
  instance you provided to the SDK at initialization.  The `AuthFailure` object
  provides more information about the failure. 

  Note that `onAuthFailure(_ authFailure: AuthFailure)` replaces `onTokenRegistrationFailed(_ reason: String?)`. 
  If you've implemented `onTokenRegistrationFailed`, you'll need to update your 
  application code.

- To set a retry policy for JWT refreshes, you can set the `retryPolicy`
  property on `IterableConfig` to a `RetryPolicy` object. Use this object to
  specify:

  - The maximum number of consecutive JWT-related request failures the SDK
    should allow before giving up, Defaults to 10.  
  - The interval between each JWT refresh attempt. Defaults to 6 seconds.  
  - A backoff strategy: linear or exponential. Defaults to linear.

- You manually pause JWT refresh attempts by calling `IterableAPI.pauseAuthRetries(true)`

For more information, see [Step 6.6.1: Register an auth handler](#step-6-6-1-register-an-auth-handler).

### Upgrading to 6.4.9

[Version 6.4.9](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.9)
of Iterable's iOS SDK makes it possible to store in-app messages in memory,
rather than in an unencrypted local file. However, an unencrypted local file is
still the default option. 

To store in-app messages in memory, set `useInMemoryStorageForInApps` to `true`:

_Swift_

```swift
let config = IterableConfig()
config.useInMemoryStorageForInApps = true
IterableAPI.initialize(apiKey: "<YOUR_API_KEY>", launchOptions:launchOptions, config:config)
```

_Objective-C_

```objectivec
IterableConfig *config = [[IterableConfig alloc] init];
config.useInMemoryStorageForInApps = YES;
[IterableAPI initializeWithApiKey:@"<YOUR_API_KEY>" launchOptions:launchOptions, config:config];
```

When users upgrade to a version of your iOS app that uses this version of the SDK
(or higher), and you've enabled this option, the local file used for in-app
message storage (if it already exists) is deleted. However, no data is lost.

### Upgrading to 6.4.8

Starting with version [6.4.8](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.8), 
Iterable's iOS SDK, as a privacy enhancement, encrypts the following data when 
storing it at rest:

- `email` — The user's email address.
- `userId` — The user's ID.
- `authToken` — The JWT used to authenticate the user with Iterable's API.
- `lastPushPayload` — The JSON payload that came along with the last push
  notification received by the app.

Note that Iterable's iOS SDK does not store in-app messages at rest—before or 
after this update.

> [!NOTE]
> Iterable's iOS SDK does, in fact, store in-app messages in an unencrypted local 
> file. However, [version 6.4.9](#upgrading-to-6-4-9) provides an option to store 
> them in memory, instead.

When a user upgrades to a version of your app that uses this version of the SDK
(or higher), these fields are encrypted. No data that's already stored is lost.

For more information about the encryption described above, examine the SDK
source code:

- [`IterableKeychain`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/Internal/IterableKeychain.swift)
- [`KeychainWrapper`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/Internal/KeychainWrapper.swift)

### Upgrading to 6.4.0

Starting with version [`6.4.0`](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.0) 
of Iterable's iOS SDK, you'll need to declare the URL protocols that the SDK
should expect to see on incoming links (and then handle as needed). For more 
information, read [Set the `allowedProtocols` field](#step-6-3-set-the-allowedprotocols-field).

### Upgrading from a version prior to 6.1.0

- Versions 6.1.0+ of the SDK require Xcode 10.2 or higher.

- In-app messages

  - `spawnInAppNotification`

     The `spawnInAppNotification` method is no longer needed, and will fail to
     compile. The SDK now displays in-app messages automatically. There is no
     need to poll the server for new messages.

  - Handling manually

    To manually control when in-app messages display, set `IterableConfig.inAppDelegate` 
    (an `IterableInAppDelegate` object). From its `onNew` method, return `.skip`.

    To get the queue of available in-app messages, call `IterableApi.inAppManager.getMessages()`. 
    Then, call `IterableApi.inAppManager.show(message)` to show a specific message.

  - Custom actions

    The SDK now reserves the `iterable://` URL scheme for Iterable-defined actions 
    handled by the SDK, and the `action://` URL scheme for custom actions handled 
    by the mobile application's custom action handler. 

    If you are currently using the `itbl://` URL scheme for custom actions, the
    SDK will still pass these actions to the custom action handler. However,
    support for this URL scheme will eventually be removed (timeline TBD), so it
    is best to move to the `action://` URL scheme as you can.

- Consolidated deep link URL handling

  By default, the SDK handles deep links using the URL delegate assigned to
  `IterableConfig`. 

- Checking if a URL is an Iterable deep link

  To check if a URL is an Iterable deep link before handling it, use the
  `isIterableDeepLink` method:

  ```swift
  if IterableAPI.isIterableDeepLink(urlString) {
      // URL is an Iterable deep link
  }
  ```

  This method returns `true` if the URL matches the Iterable deep link pattern
  (URLs containing `/a/` in the path). For more information, read 
  [iOS Universal Links](https://support.iterable.com/hc/articles/360035496511).
