---
slug: configure-the-ios-sdk
feature: unknown-user-activation
archetype: identity
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Configure the iOS SDK
source_url: https://support.iterable.com/hc/articles/40078945603860
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/unknown-user-activation-dev/configure-the-ios-sdk/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: ae94e81e53578889fb998e1744f3ee857f8da3e8
fetched_at: 2026-10-02T13:52:10.952Z
summary: Follow these instructions to set up Iterable's iOS SDK for Unknown User
  Activation. For general guidance about setting up Iterable's iOS SDK, see
  [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152).
---
# Configure the iOS SDK

Follow these instructions to set up Iterable's iOS SDK for
Unknown User Activation. For general guidance about setting up Iterable's
iOS SDK, see [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152).

> [!NOTE]
> Sample code shown in the following sections is for demonstration purposes only —
> it's not exhaustive, and it's not meant to be used directly in your iOS app.
> Instead, use it as a guide to understand the various ways you'll interact with
> the SDK when setting up and using Unknown User Activation.

## Step 1: Import SDK methods

To use Iterable's SDK in a given file, you'll need to import it:

```swift
import IterableSDK
```

## Step 2: Initialize the SDK and set up callbacks

Initialize the SDK and, if necessary, set up some JWT and unknown user
callbacks.

```swift
//
// This example creates the IterableConfig in the app delegate, but you can create it in 
// another place that's convenient for your app's architecture, if necessary.
//
func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    // ...

    let config = IterableConfig()
    config.authDelegate = self
    config.enableUnknownUserActivation = true
    config.unknownUserHandler = self
    config.eventThresholdLimit = 100
    config.identityResolution = IterableIdentityResolution(
        replayOnVisitorToKnown: true, 
        mergeOnUnknownUserToKnown: true
    )
    IterableAPI.initialize(apiKey: <YOUR_API_KEY>, config: config)

    // ...
    
    return true
}

//
// JWT-handling methods.
//
extension AppDelegate: IterableAuthDelegate {

    //
    // Fetch a new JWT token for the current or unknown user, from your server. 
    // Then, pass it to the provided completion.
    //
    func onAuthTokenRequested(completion: @escaping AuthTokenRetrievalHandler) {
        // Fetch a JWT token for the signed-in user, from your server...
        // ...

        // Return it to the SDK.
        completion("<JWT_TOKEN_FOR_THE_CURRENT_USER>")
    }

    //
    // Handle failures that occur when fetching JWT tokens.
    //     
    func onAuthFailure(_ authFailure: AuthFailure) {
         // Inspect the authFailure enum case and take any necessary action. For 
         // example, you might pause auth retries.
    }
}

//
// Delegate for unknown user callbacks
//
private var didHandleCriteriaThisSession = false

extension AppDelegate : IterableUnknownUserHandler {
    //
    // Callback for the SDK to invoke after it creates a userId for an unknown user.
    // If necessary, use this method to pass the new userId to your server.
    //
    func onUnknownUserCreated(userId: String) {
        print("UserId Created from unknownsession: \(userId)")
    }

    //
    // Optional. Called after a successful criteria fetch has been persisted.
    // Fires on every fetch (init, foreground, visitor usage tracking), so
    // guard if you only want to act once per session.
    //
    func onCriteriaReceived(criteria: [AnyHashable: Any]) {
        guard !didHandleCriteriaThisSession else { return }
        didHandleCriteriaThisSession = true
        // Safe to track / updateUser — criteria are already persisted.
        IterableAPI.updateUser(["plan": "trial"], mergeNestedObjects: true)
    }

    //
    // Optional. Called when a criteria fetch fails. The SDK retries on the
    // next foreground (if enableForegroundCriteriaFetch is true) or when
    // visitor usage tracking is toggled, so most apps can just log the reason.
    //
    func onCriteriaFetchFailed(reason: String) {
        print("Criteria fetch failed: \(reason)")
    }
}
```

Create an `IterableConfig` object, and set the following options:

1. Only if your iOS app uses a JWT-enabled API key, set the `authDelegate`
   field to an object that conforms to the `IterableAuthDelegate`
   protocol. In the previous example, the app delegate itself conforms to
   `IterableAuthDelegate`.
   
   :::warning IMPORTANT
   If you don't use a JWT-enabled API key in your iOS app, do not set this
   field. Setting up auth delegates when they're not needed could lead to unexpected 
   behavior or errors in the SDK initialization process.
   :::
  
   This object should provide implementations for two methods:
   
   - `onAuthTokenRequested` – The SDK calls `onAuthTokenRequested` when it
     needs a new JWT token for the current unknown or known user. This method
     should fetch (from your server) a new JWT token for a user, and then pass 
     that token to the completion that `onAuthTokenRequested` received as a 
     parameter. `onAuthTokenRequested` is called when:
     
       - The SDK needs a JWT token for a new unknown user.
       - You identify a user by calling `setEmail` or `setUserId`.
       - You update a user's email address by calling `updateEmail`.
       - The current JWT token has expired, or is about to expire.
       - The SDK receives a JWT-related 401 response from Iterable's API.

     `onAuthTokenRequested` can be called to fetch and return a JWT
         token for:
       - An unknown user - `IterableAPI.userId` (since, for unknown users, the
         SDK always generates a `userId` — a UUID).
       - A known user - `IterableAPI.userId` or `IterableAPI.email`, whichever value
         you used to identify the user.
         
   - `onAuthFailure` – The SDK calls `onAuthFailure` after failing to fetch a
     JWT token. The `AuthFailure` object passed to this method describes the
     reason for the failure, along with other information.

2. To enable Unknown User Activation, set `enableUnknownUserActivation` to `true`.
   This property defaults to `false`.

3. (Optional, but strongly recommended for JWT-enabled API keys) To provide a
   callback for the SDK to call after it creates a `userId` for a new unknown
   user, set `unknownUserHandler` to an object that conforms to the
   `IterableUnknownUserHandler` protocol.
   
   In the sample code above, the app delegate itself conforms to `IterableUnknownUserHandler`.
  
   The SDK calls the `onUnknownUserCreated` method on this object after a
   visitor satisfies your project's unknown user creation criteria and the SDK
   generates a `userId` for that user's new unknown user profile — but before the
   SDK attempts to fetch a JWT token for the user. 
  
   For example, you might use this method to tell your server about the
   SDK-generated unknown `userId`, to give your server context for subsequent JWT
   token requests for that same  `userId` (however, to do this, you'll need to
   set up an authenticated web service on your server for this method to call).

   :::warning IMPORTANT
   If your app uses a JWT-enabled API key, your JWT server needs to know about
   SDK-generated unknown `userId` values before it can issue tokens for them.
   This callback is the mechanism for that — without it, your JWT server may
   fail to issue tokens for new unknown users.
   :::

   `IterableUnknownUserHandler` also has two optional methods that report the
   results of unknown user criteria fetches. Existing conformers do not need to
   implement them.

   - `onCriteriaReceived(criteria:)` – The SDK calls this method after a
     successful criteria fetch, and only after the fetched criteria have been
     persisted to local storage. That means you can safely call `track`,
     `trackPurchase`, `updateUser`, and similar methods from inside the
     callback, and the SDK will evaluate those events against the criteria that
     just arrived. A common use case is updating user data right after SDK
     initialization, without racing the asynchronous criteria fetch.

     The SDK invokes `onCriteriaReceived` on the main thread, and it may fire
     on every successful fetch: at initialization, when the app is foregrounded
     (if `enableForegroundCriteriaFetch` is `true`), and when visitor usage
     tracking is enabled. Implementations should be idempotent — for example,
     by acting only once per session, as shown in the sample above.

   - `onCriteriaFetchFailed(reason:)` – The SDK calls this method on the main
     thread when a criteria fetch fails. The `reason` string is the backend's
     `msg` value when available, or a fallback such as `"Internal Server Error"`
     on a 5xx response. The SDK retries the fetch on the next foreground (when
     `enableForegroundCriteriaFetch` is `true`) or when visitor usage tracking
     is toggled, so most apps can simply log the reason.

   :::tip NOTE
   The Android SDK exposes the same optional criteria fetch callbacks on
   `IterableUnknownUserHandler`. For details, see
   [Configure the Android SDK](https://support.iterable.com/hc/articles/40078934178836).
   :::

4. Set `eventThresholdLimit` to indicate how many of a visitor's most recent
   events the SDK should save in local storage, so that they can be synced later
   to Iterable when the user satisfies your profile creation criteria and
   receives an unknown user profile.
  
   This value defaults to `100`. If a visitor triggers more than the maximum number
   of events before converting to an unknown user, the first events that were
   saved are the first to be deleted.

5. `identityResolution` – If necessary, use this field to override the SDK's
   default `IterableIdentityResolution` object, which specifies values for
   the SDK to use when working with unknown and known users (if you don't specify
   an object here, both the following properties default to `true`).
   
   - `replayOnVisitorToKnown` – When you identify a visitor by calling
     `setEmail` or `setUserId`, this field specifies whether the SDK should
     replay locally saved visitor data to their known user profile in Iterable.
     Defaults to `true`. (When an unknown user profile is first created, the SDK
     always replays locally saved data to that profile — this setting only
     controls what happens when you identify a visitor before they receive an
     unknown user profile.)
   - `mergeOnUnknownUserToKnown` – When you identify an unknown user by calling
     `setEmail` or `setUserId`, this field specifies whether the SDK should merge
     the unknown user profile with the identified user profile. Defaults to
     `true`. (If the identified user profile does not yet exist, a merge
     operation creates it. When `mergeOnUnknownUserToKnown` is `false`,  the new
     user profile is not created until the SDK tracks a user update or an event.
     Without a merge, data on the unknown user profile is lost.)
   
   :::tip NOTE
   If you don't provide an `identityResolution` value, the SDK defaults both
   `replayOnVisitorToKnown` and `mergeOnUnknownUserToKnown` to `true`. You can
   override these fields each time you call `setEmail` and `setUserId`.
   :::

   :::tip NOTE
   The iOS SDK uses `mergeOnUnknownUserToKnown`, while the Android and Web SDKs
   use `mergeOnUnknownToKnown`.
   :::

6. `enableForegroundCriteriaFetch` – Controls whether the SDK re-fetches
   profile creation criteria when the app is foregrounded. Defaults to `true`.
   Set to `false` if you only want criteria fetched on app launch.

7. After creating `IterableConfig`, pass it to the `initialize` method on
`IterableAPI`, alongside your API key.

## Step 3: Get user consent and track local data

Before telling the SDK to track local data about the current visitor, get their
consent to do so. Then, explicitly tell the SDK to start tracking local data.

```swift
// When consent is given 
IterableAPI.setVisitorUsageTracked(isVisitorUsageTracked: true)

// When consent is revoked (clears locally stored data)
IterableAPI.setVisitorUsageTracked(isVisitorUsageTracked: false)

// Track custom events
IterableAPI.track(
   event: "myEvent", 
   dataFields: dataFields, 
   onSuccess: handleTrackEventResultSuccess, 
   onFailure: handleTrackEventResultFailure
)

// Track purchase events
IterableAPI.track(purchase: total, items: itemsToPurchase, dataFields: dataFields)

// Track cart update events
IterableAPI.updateCart(items: commerceItems)

// Update the user profile
IterableAPI.updateUser(dataFields, mergeNestedObjects: false)
```

When you have user consent, call
`setVisitorUsageTracked(isVisitorUsageTracked: true)`. This does the following:

- The SDK fetches profile creation criteria for your Iterable project (and
  refreshes them on each app launch). Criteria also refreshes
  on foregrounding if `enableForegroundCriteriaFetch` is `true` (the default).
- For subsequent calls that track cart updates, purchases, custom events,
  consent timestamps, and user updates, the SDK stores data in local storage (this
  data isn't sent to Iterable yet — it's only stored locally).

If the user revokes consent, call
`setVisitorUsageTracked(isVisitorUsageTracked: false)`. This clears any locally
saved visitor data, and it prevents local storage of visitor data until
`setVisitorUsageTracked(isVisitorUsageTracked: true)` is called again. To get
the current status, call `getVisitorUsageTracked()`.

To track events and user updates, call various methods on `IterableAPI`, as
shown above.

> [!WARNING]
> Calling `setVisitorUsageTracked(isVisitorUsageTracked: true)` clears any
> previously stored local visitor data (events, user updates, and session data)
> before starting fresh tracking. If your app calls this method on each launch,
> any visitor data stored from a previous session that was not yet synced to
> Iterable will be lost.

## Step 4: Create an unknown user profile

If and when the visitor to your app satisfies your Iterable project's profile
creation criteria, the SDK:

1. Generates a `userId` (a UUID) for the new unknown user profile.
2. Calls `POST /api/unknownuser/events/session` to create the unknown user
   profile in Iterable and adds an `unknownSession` event on the profile.
3. Calls your `onUnknownUserCreated` callback, as described above.
4. (If you're using a JWT-enabled API key) Calls the `onAuthTokenRequested`
   method you provided to fetch a JWT token for the new unknown `userId`.
5. Calls the consent endpoint to log the time of consent and user type.
6. Replays locally saved visitor data to the unknown user profile in
   Iterable, and then removes it from local storage.

> [!NOTE]
> In the iOS SDK, consent tracking is logged after the JWT token fetch. This
> differs from the Android SDK, which logs consent later during device
> registration, and from the Web SDK, which logs consent before creating the
> `unknownSession` event.

## Step 5: Identify the user

When you know the current user's `userId` or `email` (depending on your Iterable
project type), provide it to the SDK by calling `setUserId` or `setEmail` on
`IterableAPI`. 

```swift
// Identify the user by email or userId, providing an identity resolution 
// override if necessary.
IterableAPI.setEmail(email, nil, identityResolutionOverride)
IterableAPI.setUserId(userId, nil, identityResolutionOverride)
```

When you identify the user:

**If the current user is a visitor** (a user who doesn't have an unknown profile
in Iterable, because they haven't yet satisfied your Iterable project's profile
creation criteria):

- If `replayOnVisitorToKnown` is set to `true`, the SDK:
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Sends visitor data (including the consent timestamp) from the app's
    local storage (user profile data and events) to the known user profile in
    Iterable. Sending this data to Iterable creates the known user profile in
    Iterable if it doesn't already exist. 
  - Clears visitor data from local storage.
  - Sends the consent timestamp, along with future user updates and events to
    the known user profile to Iterable (not local storage).

- If `replayOnVisitorToKnown` is set to `false`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Clears visitor data from local storage, without sending it to Iterable.
  - Sends future user updates and events to the known user profile in Iterable
    (not to local storage). If the known user profile doesn't yet exist
    in your Iterable project, these updates create it.

**If the current user is unknown** (has an unknown user profile in Iterable):

- If `mergeOnUnknownUserToKnown` is set to `true`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Calls the User Merge API to merge the unknown user profile with the known
    user profile (including all data). 
  - If the known profile doesn't yet exist, the user ID or email of the source
    profile are updated. 
  - The API deletes the unknown profile, if necessary. 
    It can take a few minutes for all of the data from the unknown user profile
    to appear on the known user profile.
  - Sends future user updates and events to the known user profile in Iterable
    (not to the unknown user profile).

- If `mergeOnUnknownUserToKnown` is set to `false`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Does not call the User Merge API.
  - Sends future user updates and events to Iterable, to the known user profile
    (not to the unknown user profile). The unknown user profile remains in
    Iterable. 