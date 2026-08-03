---
url: https://support.iterable.com/hc/articles/360035019712
title: Iterable's Android SDK
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-ios-and-android-sdks/android-sdk/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: de67a132360a33146dae801ab62c3de1d6846ba9
fetched_at: 2026-08-03T20:41:28.018Z
---
​
# Iterable's Android SDK
​
This article describes how to install and configure Iterable's [Android SDK](https://github.com/Iterable/iterable-android-sdk).

## In this article

[[toc]]

## Supported Android versions

Iterable's Android SDK supports Android versions 5.0 (API level 21) and 
higher.

## Encrypted data

Depending on your `minSdkVersion`, Iterable's Android SDK can encrypt some
data at rest. For more information, read [Upgrading to 3.4.10](#upgrading-to-3-4-10).

## Installing the SDK

Follow these steps to install Iterable's Android SDK. If you're upgrading from 
a previous version, see [Upgrading the SDK](#upgrading-the-sdk).

:::warning IMPORTANT
If your app targets API level 22 or lower, read [Upgrading to 3.4.10](#upgrading-to-3-4-10)
to learn about some adjustments you'll need to make to your Android project.
:::

### Step 1: Define a mobile app and push integration in Iterable

Before installing Iterable's Android SDK in your mobile app, tell your Iterable
project about your mobile app. 

To do this, follow the instructions in [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943), which describe how to:

- Define a mobile app in your Iterable project.

- Give that app a _push integration_. A push integration stores configuration
  and authentication information Iterable can use to send push notifications to
  your app. 
  
  Even if you don't want to send push notifications, Iterable can use your app's
  push integration to send _silent_ push notifications, to tell your app that
  Iterable has new in-app and embedded messages for it to fetch and display.

### Step 2: Create a mobile API key

To make calls to Iterable's's API, the SDK needs a mobile [API key](https://support.iterable.com/hc/articles/360043464871). 
To learn how to create one, read [API Keys](https://support.iterable.com/hc/articles/360043464871)

:::danger WARNING
**Never** embed server-side API keys in client-side code (whether JavaScript, a 
mobile application or otherwise), since they can be used to access all of your
project's data.
::: 

For a mobile app, use a mobile API key. For additional security, enable 
[JWT authentication](https://support.iterable.com/hc/articles/360050801231),
if you can support it.

If necessary, you can use different API keys for debug and production builds
of your app.

### Step 3: Install the SDK

:::tip TIP
To determine the latest version of Iterable's Android SDK, see 
[search.maven.org](https://search.maven.org/artifact/com.iterable/iterableapi).
:::

To use Iterable's Android SDK in your app, add the SDK and Firebase Messaging as 
dependencies to your application's `build.gradle`:

```groovy
dependencies{
    implementation 'com.iterable:iterableapi:3.5.3'
    // Optional, contains Inbox UI components:
    implementation 'com.iterable:iterableapi-ui:3.5.3' 
    // Version 17.4.0+ is required for push notifications and in-app message features:
    implementation 'com.google.firebase:firebase-messaging:X.X.X' 
}
```

### Step 4: Configure ProGuard

If you're using ProGuard when building your Android app, add this line of
ProGuard configuration to your build:

```
-keep class org.json.** { *; }
```

To learn how to do this, check out Android's guide:
[Shrink, obfuscate, and optimize your app](https://developer.android.com/studio/build/shrink-code#add-configuration).

:::warning WARNING
If you use ProGuard but skip this step, some SDK features may not work as expected.
:::

### Step 5: Set SDK configuration options

To initialize Iterable's Android SDK, create an `IterableConfig` and set its 
various configuration options.

Do this when your application is starting up, usually in the `onCreate` method
of your `Application` class. Then, pass this `IterableConfig` to `IterableApi.initialize`, 
along with your API key.

```java
IterableConfig config = new IterableConfig.Builder().build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```
     
`IterableConfig` contains various configuration options for the SDK. For
more information, refer to the following sections of this document. Or, take
a look at the `IterableConfig` [source code](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/IterableConfig.java).
 
:::warning IMPORTANT
- Version [3.4.10](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.4.10) 
  of Iterable's Android SDK provides a configuration option to store in-app 
  messages in memory, rather than in a local file. For more information, read 
  [Encrypted data](#encrypted-data).
- Don't `initialize` the SDK in the `onCreate` method of an `Activity`. 
  Instead, do it when your app is starting up, regardless of whether it has been 
  launched to open an activity or in the background, as the result of an incoming
  push notification.  
:::

#### Step 5.1: Background Initialization

To prevent application not responding (ANR) errors during app startup when using
SDKs that need to initialize on background, initialize the SDK asynchronously
instead of using the standard `initialize()` method. For example:

```kotlin
// In Application.onCreate()
IterableApi.initializeInBackground(this,  "<YOUR_API_KEY>", config) {
   // SDK is ready - this callback is optional
}
```

To subscribe to initialization completion from multiple places:

```kotlin
IterableApi.onSDKInitialized {
    // This callback will be invoked when initialization completes
    // If already initialized, it's called immediately
}
```

Background initialization prevents ANRs by:
- Running all initialization work on a background thread.
- Automatically queuing API calls until initialization completes.
- Ensuring that no data is lost during startup.
- Providing callbacks on the main thread when ready.

:::tip IMPORTANT
Always wait for initialization to complete before you access SDK internals.
Then, to ensure that the SDK is ready for use, use the callback methods provided 
above.
:::

#### Step 5.2: If necessary, configure the SDK to use Iterable's EDC

If your Iterable project is hosted on Iterable's [European data center (EDC)](https://support.iterable.com/hc/articles/17572750887444),
update your `IterableConfig` to use Iterable's EDC-based API endpoints:

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setDataRegion(IterableDataRegion.EU).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

#### Step 5.3: Set allowed URL protocols

Starting with version [`3.4.0`](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.4.0) 
of Iterable's Android SDK, you'll need to declare the specific URL protocols
that the SDK can expect to see on incoming links (and that it should handle 
as needed). This prevents the SDK from opening links that use unexpected 
URL protocols.

 To do this, pass the protocols you'd like the SDK to support (as an array of
 strings) to the `setAllowedProtocols` method on `IterableConfig.Builder`.

 For example, this code allows the SDK to handle `http://`, `tel://`, and `mycompany://` 
 links:

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setAllowedProtocols(new String[]{"http", "tel", "mycompany"}).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

:::warning IMPORTANT
Iterable's Android SDK handles `https`, `action`, `itbl`, and `iterable` links,
regardless of the contents of this array. However, you must explicitly declare any
other types of URL protocols you'd like the SDK to handle (otherwise, the SDK
won't open them in the web browser or as deep links).
:::

#### Step 5.4: Specify whether to store in-app messages in memory

By default, Iterable's Android SDK stores in-app messages in an unencrypted local 
file. If you'd prefer to have SDK store in-app messages in memory instead, use the 
`setUseInMemoryStorageForInApps(true)` SDK configuration option (defaults to `false`):

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setUseInMemoryStorageForInApps(true).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

For more information about this option, read [Upgrading to 3.4.10](#upgrading-to-3-4-10).

#### Step 5.5: Specify a push integration name, if necessary 

In [Step 1: Define a mobile app and push integration in Iterable](#step-1-define-a-mobile-app-and-push-integration-in-iterable),
you defined a mobile app in Iterable, and you gave it a push integration. 

Every push integration in Iterable has a name, and that name almost always matches
your Android app's package name (for example, `com.example.app`). By default,
this is what the SDK expects: to find a push integration in your Iterable project
with a name that matches your app's package name.

:::tip TIP
To find the name of your app's push integration in Iterable, navigate to
**Settings > Apps and Websites**, open the mobile app associated with your app,
find the **Push** section, and look at the **Name** column in the row associated
with your push integration.
:::

However, push integrations created in Iterable before August of 2019 can have 
custom names. If this is the case for your push integration, tell the SDK the name
of your push integration by calling `setPushIntegrationName` on 
`IterableConfig`:

```java 
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
 .setPushIntegrationName(“<PUSH_INTEGRATION_NAME>“).build();
IterableApi.initialize(context, “<YOUR_API_KEY>“, config);
```
        
#### Step 5.6: Handle JWT-enabled API keys
    
If you're using a [JWT-enabled API Key](https://support.iterable.com/hc/articles/360050801231),
you'll need custom code to manage JWT tokens for the signed-in user.

##### Step 5.6.1: Register an auth handler

When initializing the SDK, provide an auth handler. The SDK uses the auth 
handler to:

1. Fetch new JWT tokens from your server. 
2. Report when a non-null JWT token has been retrieved.
3. Report when there have been failures fetching new JWT tokens.

The object that you pass to the SDK as an auth manager must implement the
`IterableAuthManager` interface:

```java
public interface IterableAuthHandler {
    String onAuthTokenRequested();
    void onTokenRegistrationSuccessful(String authToken);
    void onAuthFailure(AuthFailure authFailure);
}
```

For example:

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setAuthHandler(new IterableAuthHandler() {
    @Override
    public String onAuthTokenRequested() {
      // Fetch a JWT token for the signed-in user, from your server, and 
      // return it to the SDK.
      return "<JWT_TOKEN_FOR_THE_CURRENT_USER>";
    }

    @Override
    public void onTokenRegistrationSuccessful(String authToken) {
      // The SDK has retrieved a non-null JWT token for the signed-in user.
      // However, the SDK does not validate the token before calling this
      // method. 
    }

    @Override
    public void onAuthFailure(AuthFailure authFailure) {
      // Inspect the authFailure enum constant and take any necessary action. For 
      // example, you can pause auth retries (see section 5.5.3, below).
    }
  }).build();
 IterableApi.initialize(_context, "<YOUR_API_KEY>", config);
 ```

**`onAuthTokenRequested`** 

The SDK calls `onAuthTokenRequested` when it needs a new JWT token for the 
signed-in user. This method should fetch a new JWT token from your server and
return it to the SDK as a string. 

This method is called when:

- You identify a user by calling `setEmail` or `setUserId`.
- You update a user's email address by calling `updateEmail`.
- The current JWT token has expired, or is about to expire.
- The SDK receives a JWT-related `401` response from Iterable's API.

**`onTokenRegistrationSuccessful`** 

The SDK calls `onTokenRegistrationSuccessful` after `onAuthTokenRequested`
returns a non-null JWT token. However, other than a null check, the SDK does not
validate the token before calling this method. Generally, you won't need to 
implement this method.

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
- `failureReason` - An `AuthFailureReason` enum constant that indicates the reason 
  for the failure. 
  
`AuthFailureReason` can have these values:

- `AUTH_TOKEN_EXPIRATION_INVALID` – An auth token's expiration must be less than 
   one year from its issued-at time.
- `AUTH_TOKEN_EXPIRED` – The token has expired.
- `AUTH_TOKEN_FORMAT_INVALID` – Token has an invalid format (failed a regular 
   expression check).
- `AUTH_TOKEN_GENERATION_ERROR` – `onAuthTokenRequested` threw an exception.
- `AUTH_TOKEN_GENERIC_ERROR` – Any other error not captured by another constant.
- `AUTH_TOKEN_INVALIDATED` – Iterable has invalidated this token and it cannot 
   be used.
- `AUTH_TOKEN_NULL` – `onAuthTokenRequested` returned a null JWT token.
- `AUTH_TOKEN_PAYLOAD_INVALID` – Iterable could not decode the token's payload 
   (`iat`, `exp`, `email`, or `userId`).
- `AUTH_TOKEN_SIGNATURE_INVALID` – Iterable could not validate the token's 
   authenticity.
- `AUTH_TOKEN_USER_KEY_INVALID` – The token doesn't include an `email` or a `userId`. 
   Or, one of these values is included, but it references a user that isn't in the
   Iterable project.
- `AUTH_TOKEN_MISSING` – The request to Iterable's API did not include a JWT
   authorization header.

:::tip TIP
You can also provide a JWT token for the current user by passing it directly to 
`setEmail` or `setUserId`.
:::

##### Step 5.6.2: Set an expiring token refresh period

To specify how long before the expiration of the user's current JWT token 
the SDK should call your [auth token refresh handler](#step-5-6-1-register-an-auth-handler),
to fetch a new token, call `setExpiringAuthTokenRefreshPeriod` on `IterableConfig`:

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setExpiringAuthTokenRefreshPeriod(time_in_seconds).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

##### Step 5.6.3: Set an auth retry policy

To control how the SDK handles consecutive JWT token refresh attempts, specify
an auth retry policy. An auth retry policy allows you to control:

- The number of consecutive times the SDK should attempt to refresh a user's JWT
  token, in between successful API calls, before giving up.
- The interval between those attempts.
- A backoff strategy.

```java
// When creating a RetryPolicy object, specify a maximum number of retries, an 
// interval between retries, and a backoff strategy: RetryPolicy.Type.LINEAR or 
// RetryPolicy.Type.EXPONENTIAL. The SDK's default RetryPolicy has a maximum of 
// 10 retries, an interval of 6 seconds, and a linear backoff strategy.
RetryPolicy retryPolicy = new RetryPolicy(10, 10, RetryPolicy.Type.LINEAR);
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setAuthRetryPolicy(time_in_seconds).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

After the SDK reaches the maximum number of consecutive JWT-related request failures,
as configured by your `RetryPolicy`, it stops attempting to refresh the JWT token.

:::tip Auto-retry for offline processing (3.7.0+)
In addition to the `RetryPolicy` above (which controls JWT refresh scheduling),
the SDK supports automatic retry for offline-queued tasks that fail due to JWT
expiration. When this feature is enabled, the offline task runner pauses
authenticated tasks on a 401 error, refreshes the JWT, and retries
automatically. Unauthenticated API calls continue processing while
authentication is paused. This feature requires no code changes.

This feature is not enabled by default. To turn it on for your project, ask
your Iterable customer success manager to enable it for your account.
:::

It's also possible to _manually_ pause JWT token refresh attempts. To do this,
call:

```java
IterableApi.getInstance().pauseAuthRetries(true);
```

When JWT refresh attempts have been paused, they'll only resume after:

- You provide a new JWT token to the SDK, by calling `setAuthToken`.
- You identify the user by calling `setEmail` or `setUserId`.
- You update the user's email by calling `updateEmail`
- The app restarts.
- You manually pause and unpause JWT token refresh attempts, by calling:
  ```java
  // If you didn't manually pause JWT refresh attempts in the first place,
  // first call pauseAuthRetries(true). Then, call pauseAuthRetries(false).
  IterableApi.getInstance().pauseAuthRetries(true);
  IterableApi.getInstance().pauseAuthRetries(false);
  ```

#### Step 5.7: Disable keychain encryption if necessary

In Android apps with `minSdkVersion` 23 or higher ([Android 6.0](https://developer.android.com/studio/releases/platforms#6.0))
Iterable's Android SDK encrypts sensitive user data when storing it in the
keychain. This includes the user's `email`, `userId`, and `authToken` (JWT).

This encryption is enabled by default. However, if you need to disable it, you
can do so by setting the `keychainEncryption` option to `false` when 
initializing the SDK:

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
    .setKeychainEncryption(false).build();   // Disable encryption for keychain storage
IterableApi.initialize(context, apiKey, config);
```

#### Step 5.8: Configure WebView base URL for CORS support, if necessary

If your in-app or inbox messages load external resources (such as custom fonts or
stylesheets) and you're seeing CORS errors, configure a base URL for the WebView.

By default, the WebView sends a blank origin when requesting resources. If your
server's CORS policy rejects blank origins, set the base URL to match whatever
origin your server accepts (such as your CDN domain, app domain, or
[https://app.iterable.com](https://app.iterable.com)).

```java
IterableConfig config = new IterableConfig.Builder()
  // ... other configuration options ...
  .setWebViewBaseUrl("https://app.iterable.com")  // Use https://app.eu.iterable.com for EU
  .build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

### Step 6: Identify the signed-in user

When you know the user's `email` or `userId`, identify them by calling:

- `IterableApi.getInstance().setEmail("user@example.com");`
- `IterableApi.getInstance().setUserId("userId");`

:::tip NOTES
- Make sure to identify the user _after_ you've specified the configuration
  options on `IterableConfig`, as described in [Step 5: Set SDK configuration options](#step-5-set-sdk-configuration-options).
- Don't set an email and user ID in the same session. 
- If you've prefetched a JWT auth token, you can pass it directly to `setEmail`
  and `setUserId` (useful to work around race conditions that can sometimes
  occur).
:::

### Step 7: Handle push notifications

Next, configure the SDK to handle push notifications. 

:::tip TIP
If the name of your app's push integration, in Iterable, differs from your 
app's package name (they usually match), make sure to specify your push 
integration name on `IterableConfig`. To learn how to do this, read 
[Step 5.5: Specify a push integration name, if necessary](#step-5-5-specify-a-push-integration-name-if-necessary).
:::

#### Step 7.1: Register for remote notifications

Every user + device + app combination can be identified by a unique push _token_,
which is stored on the user's profile in Iterable. Iterable users this token to
send push notifications to the user.

The SDK _automatically_ saves a push token to the user's profile whenever you
call `setEmail` or `setUserId`. 

However, you can also handle this token registration manually:
  
- When initializing the SDK, disable automatic push token registration by 
  calling `setAutoPushRegistration(false)` on `IterableConfig`.
- Whenever it makes sense, save a device token for the signed-in user to Iterable
  by calling `registerForPush` on `IterableApi`:

  ```java
  IterableApi.getInstance().registerForPush();
  ```

:::tip NOTES
- Device registration fails when no `email` or `userId` has been set.
- If you're calling `setEmail` or `setUserId` after the app has already
  launched (for example, when a new user logs in), call `registerForPush` 
  to register the device for the current user.
:::
    
#### Step 7.2: Handle Firebase push messages and tokens

The SDK automatically adds a `FirebaseMessagingService` to the app manifest. To
handle incoming push notifications, no extra setup is necessary.

However, if your application implements its own `FirebaseMessagingService`:

- Forward `onMessageReceived` calls to `IterableFirebaseMessagingService.handleMessageReceived`.
- Forward `onNewToken` calls to `IterableFirebaseMessagingService.handleTokenRefresh`.

```java
public class MyFirebaseMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        IterableFirebaseMessagingService.handleMessageReceived(this, remoteMessage);
    }

    @Override
    public void onNewToken(String s) {
        IterableFirebaseMessagingService.handleTokenRefresh();
    }
}
```

:::tip NOTES
- This step is mandatory for working with multiple push providers.
- Firebase has [deprecated `FirebaseInstanceIdService`](https://firebase.google.com/docs/reference/android/com/google/firebase/iid/FirebaseInstanceIdService). 
  It has been replaced with `onNewToken`.
- To handle silent push notifications, use a custom `FirebaseMessagingService`.
:::

### Step 8: Enable Embedded Messaging if necessary

To learn how to use Iterable's Android SDK with Embedded Messaging, read
[Embedded Messages with Iterable's Android SDK](https://support.iterable.com/hc/articles/23061877893652).

## Upgrading the SDK

This section describes how to upgrade from earlier versions of Iterable's
Android SDK.

### Upgrading to 3.10.0

[Version 3.10.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.10.0)
of Iterable's Android SDK makes manager getters fail gracefully before
initialization, and adds a `DEFER` response for in-app handlers, a
`resumeInAppDisplay()` method, and unknown user criteria fetch callbacks.
**No action is required to upgrade**—all of these changes are backward
compatible.

#### Manager getters no longer crash before initialization

In earlier versions, calling `getInAppManager()` or `getEmbeddedManager()`
before `IterableApi.initialize()` threw a `RuntimeException`, which could crash
the host app. Starting with version 3.10.0, these methods log an error and
return a no-op manager instead—it returns empty results and ignores commands, so
a call-ordering mistake no longer crashes your app.

If you need to detect whether the SDK is initialized before using a manager, use
the new `getInAppManagerOrNull()` and `getEmbeddedManagerOrNull()` methods, which
return `null` (rather than a no-op manager) when the SDK isn't initialized yet.

```java
IterableInAppManager inAppManager = IterableApi.getInstance().getInAppManagerOrNull();
if (inAppManager != null) {
    // Safe to use; the SDK is initialized.
}
```

As always, initialize the SDK in the `onCreate` method of your `Application`
class before calling other SDK methods.

#### New: `DEFER` response and `resumeInAppDisplay()` for in-app messages

`IterableInAppHandler.InAppResponse` now includes a `DEFER` value. Unlike `SKIP`
(which permanently drops a message), `DEFER` keeps the message pending so the
SDK reconsiders it later—useful for temporary suppression, such as while a
splash screen is showing. To re-check pending messages on demand once your app
is ready, call the new `IterableInAppManager.resumeInAppDisplay()` method. For
more information, read [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231).

#### New: unknown user criteria fetch callbacks

`IterableUnknownUserHandler` now reports the results of unknown user criteria
fetches through two optional methods: `onCriteriaReceived(JSONObject criteria)`
on success and `onCriteriaFetchFailed(String reason)` on failure. Both have
default, no-op implementations, so existing handlers are unaffected.

For more information, read [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231)
and [Configure the Android SDK](https://support.iterable.com/hc/articles/40078934178836)
in the Unknown User Activation documentation.

### Upgrading to 3.9.0

[Version 3.9.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.9.0)
of Iterable's Android SDK adds in-app message support for Jetpack Compose apps,
a new opt-in toolbar for the mobile inbox, and additional context for push-open
tracking. **No action is required to upgrade**—all of these changes are
backward compatible.

#### In-app messages in Jetpack Compose apps

The SDK can now render in-app messages using a new `Dialog`-based renderer
(`IterableInAppDialogNotification`) that doesn't require a `FragmentActivity`.
Apps that host in-app messages in a `FragmentActivity` continue to use the
existing `Fragment`-based rendering; apps that don't (such as those built fully
with Jetpack Compose, using a `ComponentActivity`) automatically fall back to
the `Dialog`-based renderer. As a result, in-app messages now display correctly
in apps built fully with Jetpack Compose, with no additional setup.

#### New: `IterableInboxToolbarView` for the mobile inbox

If you use Iterable's [Mobile Inbox](https://support.iterable.com/hc/articles/360038744152),
you can now add an optional toolbar above the inbox list using the new
`IterableInboxToolbarView`. Configure it with the `InboxToolbarOption` sealed
interface:

- `None` (default) — No toolbar. The inbox behaves exactly as it did in
  previous SDK versions.
- `Default` — A title-only toolbar above the inbox list.
- `WithBackButton` — A title plus a back-navigation icon. By default, the back
  action calls `OnBackPressedDispatcher`. To override it, have your host
  `Activity` or parent `Fragment` implement `IterableInboxToolbarBackListener`.
- `Custom(layoutRes)` — Inflates your own toolbar layout. Views tagged with the
  reserved IDs `@id/iterable_reserved_inbox_toolbar_action` and
  `@id/iterable_reserved_inbox_toolbar_title` are automatically wired to the
  SDK's back handler and title binding, respectively (both are optional).

Configure the toolbar programmatically with `IterableInboxFragment.newInstance(...)`
(using the new two- or six-argument overloads), or with `IterableInboxActivity`
intent extras (`TOOLBAR_OPTION` and `TOOLBAR_TITLE`).

:::warning IMPORTANT
When the toolbar is enabled, the host activity must use a `Theme.AppCompat`
descendant.
:::

For more information about customizing the inbox, see
[Customizing Mobile Inbox on Android](https://support.iterable.com/hc/articles/360039189931).

#### New: `appAlreadyRunning` field on `trackPushOpen`

`trackPushOpen` now includes an `appAlreadyRunning` field that indicates whether
the app was already running when the push notification was received. A new
`trackPushOpen(int, int, String, boolean, JSONObject)` overload lets you pass
this value; existing overloads default it to `false`, so no changes are required
for existing code.

#### Fix: `TransactionTooLargeException` crash for large in-app messages

This release also fixes a `TransactionTooLargeException` crash that could occur
when displaying in-app messages with oversized HTML payloads. The HTML is no
longer serialized into the fragment's saved instance state—it's reloaded from
storage when the fragment is recreated. In-app messages with missing HTML now
dismiss gracefully without registering tracking events, and a warning is logged
for HTML payloads that exceed the recommended size.

For more information, read [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231)
and [Customizing Mobile Inbox on Android](https://support.iterable.com/hc/articles/360039189931).

### Upgrading to 3.8.0

[Version 3.8.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.8.0)
of Iterable's Android SDK introduces a new configuration option for controlling
how in-app messages interact with system bars, plus refinements to embedded
message views and a security cleanup. **No action is required for most apps**—upgrading 
preserves the existing in-app message behavior introduced in 3.6.1.

#### New: `IterableInAppDisplayMode` for in-app messages

Since 3.6.1, Iterable's Android SDK has always rendered in-app messages
edge-to-edge, behind the status bar and navigation bar. Starting with 3.8.0,
you can change that behavior globally by setting an `IterableInAppDisplayMode`
on `IterableConfig`:

```java
IterableConfig config = new IterableConfig.Builder()
    .setInAppDisplayMode(IterableInAppDisplayMode.FORCE_RESPECT_BOUNDS)
    .build();

IterableApi.initialize(context, apiKey, config);
```

The available modes are:

- `FORCE_EDGE_TO_EDGE` (default) — Draws in-app content behind the system
  bars, with transparent status and navigation bars. Preserves the behavior
  introduced in SDK 3.6.1.
- `FOLLOW_APP_LAYOUT` — Matches the host app's current system bar
  configuration.
- `FORCE_FULLSCREEN` — Hides the status bar entirely while in-app messages
  are displayed.
- `FORCE_RESPECT_BOUNDS` — Ensures in-app content never overlaps system bars,
  keeping UI elements like the close button always accessible.

If the close button on your fullscreen in-app messages is being obscured by
the status bar on certain devices, switch to `FOLLOW_APP_LAYOUT` or
`FORCE_RESPECT_BOUNDS`. For more information, see [Configuring how in-app messages interact with system bars](https://support.iterable.com/hc/articles/360035537231#configuring-how-in-app-messages-interact-with-system-bars-sdk-v3-8-0-and-above)
in the In-App Messages on Android documentation.

#### Other changes in 3.8.0

- **`imageScaleType` option for embedded message views**: `IterableEmbeddedViewConfig`
  exposes a new `imageScaleType` property that controls how the image is
  scaled within the 16:9 container of an out-of-the-box embedded message view.

- **Default values for `IterableEmbeddedViewConfig` parameters**: All
  `IterableEmbeddedViewConfig` constructor parameters now have default values,
  so you only need to specify the styling options you want to customize.
  Existing calls that pass every parameter continue to work unchanged.

- **Embedded message card layout fixes**: Out-of-the-box embedded message
  views render correctly again on cards. The image now displays at a 16:9
  aspect ratio instead of collapsing to zero height, the card container no
  longer expands to fill its parent, the missing end margin on the card is
  applied, bottom spacing on buttons is no longer cut off, and the image is
  properly clipped to the card's rounded corners.

- **Removed insecure `AES/CBC/PKCS5Padding` encryption**: `IterableDataEncryptor`
  now exclusively uses `AES/GCM/NoPadding`. The legacy CBC algorithm was only
  used on Android versions below KitKat (API 19), which have been unsupported
  since `minSdkVersion` was raised to 21 in SDK 3.5.12. No data migration is
  required.

### Upgrading to 3.7.0

[Version 3.7.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.7.0)
introduces two opt-in improvements: an automatic JWT-refresh-and-retry flow for the 
offline event queue, and new callbacks for tracking embedded message sync results.
No application code changes are required to upgrade—both improvements are opt-in.

#### Opt-in: Auto-retry for JWT failures in offline event processing

When offline event processing is enabled and a queued API call returns a 401
JWT error, the SDK can now automatically:

1. Pause processing of authenticated tasks in the offline queue.
2. Refresh the JWT via your registered `IterableAuthHandler`.
3. Retry the failed task with the new token.

Unauthenticated endpoints (such as `disableDevice`, `mergeUser`, and
`trackConsent`) continue to be processed while authentication is paused, so
unrelated traffic isn't blocked behind a stale token.

This behavior is disabled by default for existing customers. To enable it for your 
project, talk to your Iterable customer success manager. No application code 
changes are required once the flag is enabled—the SDK starts using the new behavior 
automatically.

#### Opt-in: Embedded messaging sync callbacks

`IterableEmbeddedUpdateHandler` now exposes two optional callbacks—
`onEmbeddedMessagingSyncSucceeded()` and `onEmbeddedMessagingSyncFailed(reason)`—
that let your app react to embedded message syncs. Use them to stop a loading
spinner on success or to show fallback content on failure. Both methods have
default empty implementations, so existing code keeps working unchanged.

For more information, read [Embedded Messages with Iterable's Android SDK](https://support.iterable.com/hc/articles/23061877893652#step-8-set-up-sdk-listeners).

### Upgrading to 3.6.6

[Version 3.6.6](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.6)
of Iterable's Android SDK is a maintenance release. No action is required to
upgrade.

### Upgrading to 3.6.5

Starting with [version 3.6.5](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.5),
the `IterableEmbeddedView` constructor is **deprecated** because it violates 
Android Fragment best practices: the system can't recreate the fragment after 
configuration changes or process death, which can cause crashes.

Use the `newInstance` factory method instead:

```kotlin
// Deprecated:
val messageView = IterableEmbeddedView(ootbType, message, config)

// Use this instead:
val messageView = IterableEmbeddedView.newInstance(ootbType, message, config)
```

The old constructor still works, but it's marked as deprecated and will be
removed in a future SDK release. Update your application code now to avoid a
breaking change later.

For more information, read [Embedded Messages with Iterable's Android SDK](https://support.iterable.com/hc/articles/23061877893652).

### Upgrading to 3.6.4

[Version 3.6.4](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.4)
makes the `isIterableDeeplink` method public so you can now check whether a URL is 
an Iterable deep link before handling it. The method returns `true` when the URL 
matches the Iterable deep link pattern (URLs containing `/a/` in the path).

`isIterableDeeplink` is a **static** method on `IterableApi`:

```java
if (IterableApi.isIterableDeeplink(urlString)) {
    // URL is an Iterable deep link
}
```

For more information about deep links in Iterable, read [Android App Links](https://support.iterable.com/hc/articles/360035127392).

### Upgrading to 3.6.3

[Version 3.6.3](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.3)
of Iterable's Android SDK is a maintenance release. No action is required to
upgrade.

### Upgrading to 3.6.2

[Version 3.6.2](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.2)
adds three opt-in capabilities. No action is required to upgrade.

- **Background initialization to prevent ANRs**: To run SDK initialization on
  a background thread (with API calls automatically queued until ready), call
  the new `IterableApi.initializeInBackground()` static method instead of
  `IterableApi.initialize()`:

  ```java
  IterableApi.initializeInBackground(context, apiKey, config, callback);
  ```

  Use this if running initialization on the main thread is contributing to
  Application Not Responding (ANR) errors during app startup. The optional
  `callback` (an `IterableInitializationCallback`) is invoked when
  initialization completes.

- **`onSDKInitialized()` callback**: A new static method on `IterableApi` lets
  you subscribe a callback to be notified when initialization completes. Use
  it when you need to defer SDK-dependent work from multiple call sites—for
  example, posting the first event only after the SDK is fully ready.

  ```java
  IterableApi.onSDKInitialized(callback);
  ```

- **`setWebViewBaseUrl()` configuration option**: A new `IterableConfig.Builder`
  method that sets the base URL used by WebView-based messages (in-app
  messages, inbox, and embedded messages). Set it when you self-host custom
  fonts or other external resources that require CORS to load successfully in
  a WebView:

  ```java
  IterableConfig config = new IterableConfig.Builder()
      .setWebViewBaseUrl("https://your-cdn.example.com")
      .build();

  IterableApi.initialize(context, apiKey, config);
  ```

  If not set, the base URL defaults to an empty string (the original behavior).

### Upgrading to 3.6.1

Starting with [version 3.6.1](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.1),
in-app messages render edge-to-edge so they display properly on devices with notches, 
cutouts, and system bars.

By default, the SDK applies white insets to fill the area behind the system
bars. In dark-themed apps, that white can contrast sharply with your in-app
message content.

If your app uses a dark theme, consider updating the [background overlay](https://support.iterable.com/hc/articles/360044425951#background-overlay)
on your in-app templates to a color that complements your app, and test
existing templates before publishing.

### Upgrading to 3.6.0

To enable Unknown User Activation, upgrade to [version 3.6.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.6.0)
of Iterable's Android SDK and call `setEnableUnknownUserActivation(true)` on
`IterableConfig.Builder` before initializing the SDK. These code changes are
only required if you want to use Unknown User Activation; otherwise, no
changes are required.

```java
IterableConfig config = new IterableConfig.Builder()
    .setEnableUnknownUserActivation(true)
    .build();

IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

The SDK also captures user consent on your behalf when this feature is enabled. For full
setup instructions, read [Configure the Android SDK](https://support.iterable.com/hc/articles/40078934178836)
in the Unknown User Activation documentation.

### Upgrading to 3.5.12

- **Supported Android versions**: Beginning with [version 3.5.12](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.5.12),
  Iterable's Android SDK supports Android versions 5.0 (API level 21) and 
  higher.

- **Disabling encryption**: By default, encryption is enabled to securely store 
  sensitive user data. To disable keychain encryption, set the 
  `setKeychainEncryption` option to `false` when initializing the SDK:

  ```java
  IterableConfig config = new IterableConfig.Builder()
      .setKeychainEncryption(false)  // Disable encryption for keychain storage
      .build();

  IterableApi.initialize(context, apiKey, config);
  ```

### Upgrading to 3.5.3

Starting with [version 3.5.3](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.5.3), 
Iterable's Android SDK provides more insight into JWT refresh failures, to help 
you take appropriate action in your application code. 

When a JWT refresh fails (for any of various reasons), the SDK calls
`onAuthFailure(AuthFailure authFailure)` on the `IterableAuthHandler` instance
you provided to the SDK at initialization. The `AuthFailure` object provides
more information about the failure.

`onAuthFailure(AuthFailure authFailure)` replaces `onTokenRegistrationFailed(Throwable object)`. 
If you've implemented that method, you'll need to update your application code.

For more information, see [Step 5.6.1: Register an auth handler](#step-5-6-1-register-an-auth-handler).

### Upgrading to 3.5.2

When upgrading to [version 3.5.2](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.5.2)
of the SDK, you can make use of the `setAuthRetryPolicy` method on `IterableConfig` 
to specify:

- The maximum number of consecutive JWT-related request failures the SDK should
  allow before giving up, Defaults to 10.
- The interval between each retry attempt. Defaults to 6 seconds.
- A backoff strategy: linear or exponential. Defaults to linear.

### Upgrading to 3.4.10

In Android apps with `minSdkVersion` 23 or higher ([Android 6.0](https://developer.android.com/studio/releases/platforms#6.0))
Iterable's Android SDK now encrypts the following fields when storing them at
rest:

- `email` — The user's email address.
- `userId` — The user's ID.
- `authToken` — The JWT used to authenticate the user with Iterable's API.

(Note that Iterable's Android SDK does not store the last push payload at
rest—before or after this update.)

For more information about this encryption in Iterable's Android SDK, examine 
the source code for [`IterableKeychain`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/IterableKeychain.kt),
a file in Iterable's Android SDK.

This release also allows you to have your Android apps (regardless of `minSdkVersion`) 
store in-app messages in memory, rather than in an unencrypted local file.
However, an unencrypted local file is still the default option.

To store in-app messages in memory, set the `setUseInMemoryStorageForInApps(true)`
SDK configuration option (defaults to `false`):

```java
IterableConfig config = new IterableConfig.Builder()
   // ... other configuration options ...
  .setUseInMemoryStorageForInApps(true).build();
IterableApi.initialize(context, "<YOUR_API_KEY>", config);
```

When users upgrade to a version of your Android app that uses this version of
the SDK (or higher), and you've set this configuration option to `true`, the 
local file used for in-app message storage (if it already exists) is deleted
However, no data is lost.

#### API level 22 and lower

If your app targets API level 23 or higher, this is a standard SDK upgrade, with
no special instructions. 

If your app targets an API level less than 23, you'll need to make the following
changes to your project (which allow your app to build, even though it won't
encrypt data):

1. In `AndroidManifest.xml`, add `<uses-sdk tools:overrideLibrary="androidx.security" />`

2. In your app's `app/build.gradle`:
   - Add `multiDexEnabled true` to the `default` object, under `android`.
   - Add `implementation androidx.multidex:multidex:2.0.1` to the `dependencies`.

### Upgrading to 3.4.0

- Starting with version [3.4.0](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.4.0) 
  of Iterable's Android SDK, you'll need to declare the URL protocols that
  the SDK should expect to see on incoming links (and then handle as needed). For 
  more information, read about [Step 5.3: Set allowed URL protocols](#step-5-3-set-allowed-url-protocols), 
  above.

- Version 3.4.0 changes two static methods on the `IterableApi` class, `handleAppLink` 
  and `getAndTrackDeepLink`, to instance methods. To call these methods, you'll
  need to first grab an instance of the `IterableApi` class by calling 
  `IterableApi.getInstance()`.  For example, `IterableApi.getInstance().handleAppLink(...)`.

### Upgrading to 3.3.1

To resolve a breaking change introduced in Firebase Cloud Messaging 
[version 22.0.0](https://firebase.google.com/support/release-notes/android#messaging_v22-0-0), 
[version 3.3.1](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.3.1) 
of Iterable's Android SDK bumps the minimum required version of its
Firebase Android dependency to [20.3.0](https://firebase.google.com/support/release-notes/android#messaging_v20-3-0).

If upgrading to version 3.3.1 causes your app to crash on launch, or your build 
to fail, add the following lines to your app's `build.gradle` file:

```groovy
android {
    ...
    compileOptions {
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
    ...
}
```

### Upgrading to 3.2.0

[Versions 3.2.0 and higher](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.2.0) 
depend on the [AndroidX](https://developer.android.com/jetpack/androidx) support 
libraries. To use these versions, you'll need to [migrate your app to use AndroidX](https://developer.android.com/jetpack/androidx/migrate).

### Upgrading from a version prior to 3.1.0

- In-app messages

  - `spawnInAppNotification`

    The `spawnInAppNotification` method is no longer needed and will fail to
    compile. The SDK now displays in-app messages automatically. There is no need
    to poll the server for new messages.

  - Handling manually

    To control when in-app messages display (rather than displaying them
    automatically), set `IterableConfig.inAppHandler` (an `IterableInAppHandler`
    object). From its `onNewInApp` method, return `InAppResponse.SKIP`.

    To get the queue of available in-app messages, call
    `IterableApi.getInstance().getInAppManager().getMessages()`. Then, call
    `IterableApi.getInstance().getInAppManager().showMessage(message)` to show a
    specific message.

  - Custom actions

    This version of the SDK reserves the `iterable://` URL scheme for
    Iterable-defined actions handled by the SDK and the `action://` URL scheme for
    custom actions handled by the mobile application's custom action handler. 

    If you are currently using the `itbl://` URL scheme for custom actions, the SDK
    will still pass these actions to the custom action handler.  However, support
    for this URL scheme will eventually be removed (timeline TBD), so it is best to
    move templates to the `action://` URL scheme as it's possible to do so.

- Deep links

  - Consolidated deep link URL handling. By default, the SDK handles deep links 
    with the the URL handler assigned to `IterableConfig`.

  - Checking if a URL is an Iterable deep link: To check if a URL is an Iterable 
    deep link before handling it, use the `isIterableDeepLink` method:

    ```java
    if (IterableApi.getInstance().isIterableDeepLink(urlString)) {
        // URL is an Iterable deep link
    }
    ```

    This method returns `true` if the URL matches the Iterable deep link pattern
    (URLs containing `/a/` in the path). For more information, read 
    [Android App Links](https://support.iterable.com/hc/articles/360035127392).

### Migrating from GCM to FCM

To migrate from GCM (Google Cloud Messaging) to Firebase (Firebase Cloud Messaging)

- Upgrade the existing Google Cloud project to Firebase.
- Update the server token in the existing GCM-based Iterable push integration,
  applying the new Firebase token.
- Update the Android app to support Firebase.

If you use the same project and integration name for Firebase Cloud Messaging, the
old tokens remain valid and you won't need to re-register existing devices. If
you're using a new project for Firebase Cloud Messaging, and have existing
devices on a GCM project with a different sender ID:

- Updating the app will generate new tokens for users, but the old tokens remain valid. 
- When migrating from one sender ID to another, when initializing Iterable's SDK,
  specify `legacyGCMSenderId` on`IterableConfig`. This disables old tokens to make 
  sure users won't receive duplicate notifications.

## Troubleshooting

If you're having trouble installing or initializing the SDK, read 
[Testing and Troubleshooting the Iterable SDK](https://support.iterable.com/hc/articles/360035392251).

## Further reading

- [Identifying the User](https://support.iterable.com/hc/articles/360035402531)
- [Updating User Profiles](https://support.iterable.com/hc/articles/360035402611)
- [Tracking Events with Iterable's Mobile SDKs](https://support.iterable.com/hc/articles/360035395671)
- [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943)
- [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231)
- [Embedded Messages with Iterable's Android SDK](https://support.iterable.com/hc/articles/23061877893652).
- [Setting up Mobile Inbox on Android](https://support.iterable.com/hc/articles/360038744152)
- [Customizing Mobile Inbox on Android](https://support.iterable.com/hc/articles/360039189931)
- [Android App Links](https://support.iterable.com/hc/articles/360035127392)
- [Deep Links in Push Notifications](https://support.iterable.com/hc/articles/360035453971)
- [Sample Apps that use Iterable's Android SDK](https://github.com/Iterable/iterable-android-sdk/tree/master/sample-apps/inbox-customization)
- [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226)
- [JWT-Enabled API Keys](https://support.iterable.com/hc/articles/360050801231)
