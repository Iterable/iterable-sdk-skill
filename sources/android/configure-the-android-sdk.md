---
url: https://support.iterable.com/hc/articles/40078934178836
title: Configure the Android SDK
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/unknown-user-activation-dev/configure-the-android-sdk/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: fa441fa69f35c816affd3df2d565dbfbd2727ca3
fetched_at: 2026-05-25T15:11:48.790Z
---
# Configure the Android SDK

Follow these instructions to set up Iterable's Android SDK for
Unknown User Activation. For general guidance about setting up Iterable's
Android SDK, see [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712).

:::tip NOTE 
Sample code shown in the following sections is for demonstration purposes only;
it's not exhaustive, and it's not meant to be used directly in your Android
app. Instead, use it as a guide to understand the various ways you'll interact
with the SDK when setting up and using Unknown User Activation.
:::

## In this article

[[toc]]

## Step 1: Import SDK methods

To use Iterable's SDK in a given file, you'll need to import various
classes.

```kotlin
import com.iterable.iterableapi.AuthFailure
import com.iterable.iterableapi.IterableApi
import com.iterable.iterableapi.IterableConfig
import com.iterable.iterableapi.IterableUnknownUserHandler
import com.iterable.iterableapi.IterableAuthHandler
import com.iterable.iterableapi.IterableIdentityResolution
```

## Step 2: Initialize the SDK and set up callbacks

Initialize the SDK and, if necessary, set up some JWT and unknown user
callbacks.

```kotlin
//
// This example creates the IterableConfig in the main activity, but you can create it in 
// another place that's convenient for your app's architecture, if necessary.
//
class MainActivity : AppCompatActivity(), IterableUnknownUserHandler, IterableAuthHandler {

    override fun onCreate(savedInstanceState: Bundle?) {
        config = IterableConfig.Builder()
            .setAuthHandler(this)
            .setEnableUnknownUserActivation(true)
            .setUnknownUserHandler(this)
            .setEventThresholdLimit(100)
            .setIdentityResolution(IterableIdentityResolution(true, true))
            .build()
        IterableApi.initialize(this, <YOUR_API_KEY>, config)
    }

    //
    // Fetch a new JWT token for the current or unknown user, from your server. 
    // Then, return it as a string.
    //
    override fun onAuthTokenRequested(): String {
        // ...
        return "<JWT_TOKEN_FOR_UNKNOWN_OR_KNOWN_USER>"
    }

    //
    // Handle failures that occur when fetching JWT tokens.
    //     
    override fun onAuthFailure(authFailure: AuthFailure?) {
        // ...
    }

    //
    // The SDK calls onTokenRegistrationSuccessful after onAuthTokenRequested
    // returns a non-null JWT token. However, other than a null check, the SDK does not 
    // validate the token before calling this method. You can leave this method empty.
    //
    override fun onTokenRegistrationSuccessful(authToken: String?) {
    }

    //
    // Callback for the SDK to invoke after it creates a userId for an unknown user.
    // If necessary, use this method to pass the new userId to your server. 
    //
    override fun onUnknownUserCreated(userId: String) {
        // ...
    }
}
```

Create an `IterableConfig` object, and set the following options:

1. Only if your Android app uses a JWT-enabled API key, set the `setAuthHandler`
   field to an object that implements the `IterableAuthHandler` interface. In the
   previous example, the main activity itself implements `IterableAuthHandler`. 
  
   :::warning IMPORTANT
   If you don't use a JWT-enabled API key in your Android app, do not set this
   field. Setting up auth handlers when they're not needed could lead to unexpected 
   behavior or errors in the SDK initialization process.
   :::

   The `IterableAuthHandler` object should provide implementations for two methods,
   and an empty implementation for another:
   
   - `onAuthTokenRequested` – The SDK calls this method when it needs a new JWT
     token for the current unknown or known user. This method should fetch (from
     your server) a new JWT token for a user, and then return it as a string.
     `onAuthTokenRequested` is called when:
     - The SDK needs a JWT token for a new unknown user.
     - You identify a user by calling `setEmail` or `setUserId`.
     - You update a user's email address by calling `updateEmail`.
     - The current JWT token has expired, or is about to expire.
     - The SDK receives a JWT-related 401 response from Iterable's API.
     
     `onAuthTokenRequested` can be called to fetch and return a JWT token for:
      - An unknown user - `IterableApi.getInstance().getUserId()` (since, 
       for unknown users, the SDK always generates a `userId` — a UUID).
      - A known user - `IterableAPI.getInstance().getUserId()` or
       `IterableAPI.getInstance.getEmail()`, whichever value you used to
       identify the user.

   - `onAuthFailure` – The SDK calls `onAuthFailure` after failing to fetch a
     JWT token. The `AuthFailure` object passed to this method describes the
     reason for the failure, along with other information.

   - `onTokenRegistrationSuccessful` – The SDK calls
     `onTokenRegistrationSuccessful` after `onAuthTokenRequested` returns a
     non-null JWT token. However, other than a null check, the SDK does not
     validate the token before calling this method. You can leave this method
     empty.
    
2. To enable Unknown User Activation, set `setEnableUnknownUserActivation` to `true`.
   This property defaults to `false`.

3. (Optional, but strongly recommended for JWT-enabled API keys) To provide a
   callback for the SDK to call after it creates a `userId` for a new unknown
   user, set `setUnknownUserHandler` to an object that implements the
   `IterableUnknownUserHandler` interface.
     
   The SDK calls the `onUnknownUserCreated` method on this object after a
   visitor satisfies your project's unknown user creation criteria and the SDK
   generates a `userId` for that user's new unknown user profile — but before the
   SDK attempts to fetch a JWT token for the user. 
  
   For example, you might use this method to tell your server about the
   SDK-generated unknown userId, to give your server context for subsequent JWT
   token requests for that same  `userId` (however, to do this, you'll need to
   set up an authenticated web service on your server for this method to call).

   :::warning IMPORTANT
   If your app uses a JWT-enabled API key, your JWT server needs to know about
   SDK-generated unknown `userId` values before it can issue tokens for them.
   This callback is the mechanism for that — without it, your JWT server may
   fail to issue tokens for new unknown users.
   :::

4. Set `setEventThresholdLimit` to indicate how many of a visitor's most recent
   events the SDK should save in local storage, so that they can be synced later
   to Iterable when the user satisfies your profile creation criteria and
   receives an unknown user profile. 
  
   This value defaults to `100`. If a visitor triggers more than the maximum number
   of events before converting to an unknown user, the first events that were
   saved are the first to be deleted.

5. `setIdentityResolution` – If necessary, use this setter to override the
   SDK's default `IterableIdentityResolution` object, which specifies values for
   the SDK to use when working with unknown and known users (if you don't specify
   an object here, both the following properties default to `true`).

   - `replayOnVisitorToKnown` – When you identify a visitor by calling
    `setEmail` or `setUserId`, this field specifies whether the SDK should
    replay locally saved visitor data to their known user profile in Iterable.
    Defaults to `true`. (When an unknown user profile is first created, the SDK
    always replays locally saved data to that profile — this setting only
    controls what happens when you identify a visitor before they receive an
    unknown user profile.)
   - `mergeOnUnknownToKnown` – When you identify an unknown user by calling
     `setEmail` or `setUserId`, this field specifies whether the SDK should merge
     the unknown user profile with the identified user profile. Defaults to
     `true`. (If the identified user profile does not yet exist, a merge
     operation creates it. When `mergeOnUnknownToKnown` is `false`,  the new user
     profile is not created until the SDK tracks a user update or an event.
     Without a merge, data on the unknown user profile is lost.)
  
     :::tip NOTE
     If you don't provide an `identityResolution` value, the SDK defaults both
     `replayOnVisitorToKnown` and `mergeOnUnknownToKnown` to `true`. You can
     override these fields each time you call `setEmail` and `setUserId`.
     :::

     :::tip NOTE
     The Android and Web SDKs use `mergeOnUnknownToKnown`, while the iOS SDK
     uses `mergeOnUnknownUserToKnown`.
     :::

6. `setEnableForegroundCriteriaFetch` – Controls whether the SDK re-fetches
   profile creation criteria when the app is foregrounded. Defaults to `true`.
   Set to `false` if you only want criteria fetched on app launch.

7. After creating `IterableConfig`, pass it to the `initialize` method on
`IterableApi`, alongside your API key.

## Step 3: Get user consent and track local data

Before telling the SDK to track local data about the current visitor, get their
consent to do so. Then, explicitly tell the SDK to start tracking local data.

```kotlin
// When consent is given 
IterableApi.getInstance().setVisitorUsageTracked(true)

// When consent is revoked (clears locally stored data)
IterableApi.getInstance().setVisitorUsageTracked(false)

// Track custom events
IterableApi.getInstance().track(eventName, dataFields)

// Track purchase events
IterableApi.getInstance().trackPurchase(total, items)

// Track cart update events
IterableApi.getInstance().updateCart(items)

// Update the user profile
IterableApi.getInstance().updateUser(dataFields)
```

When you have user consent, call `setVisitorUsageTracked(true)`. When you do
this:

- The SDK fetches profile creation criteria for your Iterable project (and
  refreshes them on each app launch). Criteria also refreshes on foregrounding
  if `enableForegroundCriteriaFetch` is `true` (the default).
- For subsequent calls that track cart updates, purchases, custom events, and
  user updates, the SDK stores data in local storage (this data isn't sent to
  Iterable yet — it's only stored locally).

If the user revokes consent, call `setVisitorUsageTracked(false)`. This clears
any locally saved visitor data, and it prevents local storage of visitor data
until `setVisitorUsageTracked(true)` is called again.

To track events and user updates, call various methods on `IterableApi`, as
shown above.

:::warning WARNING
Calling `setVisitorUsageTracked(true)` clears any previously stored local visitor
data (events, user updates, and session data) before starting fresh tracking.
If your app calls this method on each launch, any visitor data stored from a
previous session that was not yet synced to Iterable will be lost.
:::

## Step 4: Create an unknown user profile

If and when the visitor to your app satisfies your Iterable project's profile
creation criteria, the SDK creates an unknown user profile for them.

1. The SDK generates a `userId` (a UUID) to identify the new unknown user profile.
2. The SDK calls `POST /api/unknownuser/events/session` to create the unknown user
   profile in Iterable and adds an `unknownSession` event on the profile.
3. The SDK calls your `onUnknownUserCreated` callback, as described above.
4. If you're using a JWT-enabled API key, the SDK then calls the
   `onAuthTokenRequested` method you provided, to fetch (from your server) a JWT
   token for the new unknown `userId`. This is the first time the SDK will call
   this method for this user.
5. The SDK replays locally saved visitor data (cart updates, purchase, user profile
   updates, and custom events) to the unknown user profile in Iterable, and then
   removes it from local storage.

:::tip NOTE
Consent tracking occurs later, after device registration completes, rather than
as part of the `unknownSession` creation flow described above.
:::

:::tip NOTE
This differs from the iOS SDK, which logs consent after fetching a JWT token,
and from the Web SDK, which logs consent before creating the
`unknownSession` event.
:::

## Step 5: Identify the user

When you know the current user's user ID or email (depending on your Iterable
project type), provide it to the SDK by calling `setUserId` or `setEmail` on
`IterableAPI`. 

```kotlin
// Identify the user by email or userId, providing an identity resolution 
// override if necessary.
IterableApi.getInstance().setEmail(email, identityResolutionOverride)
IterableApi.getInstance().setUserId(userId, identityResolutionOverride)
```

When you identify the user:

**If the current user is a visitor** (a user who doesn't have an unknown profile
in Iterable, because they haven't yet satisfied your Iterable project's profile
creation criteria):

- If `replayOnVisitorToKnown` is set to `true`, the SDK:
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Sends visitor data from the app's local storage (user profile data and
    events) to the known user profile in Iterable. Sending this data to Iterable
    creates the known user profile in Iterable if it doesn't already exist. 
  - Clears visitor data from local storage.
  - Sends future user updates and events to the known user profile to Iterable
    (not local storage).

- If `replayOnVisitorToKnown` is set to `false`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Clears visitor data from local storage, without sending it to Iterable.
  - Sends future user updates and events to the known user profile in Iterable
    (not to local storage). If the known user profile doesn't yet exist
    in your Iterable project, these updates create it.

**If the current user is unknown** (has an unknown user profile in Iterable):

- If `mergeOnUnknownToKnown` is set to `true`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Calls the User Merge API to merge the unknown user profile with the known
    user profile (including all data). 
  - If the known profile doesn't yet exist, the user ID or email of the source
    profile are updated. 
  - The API deletes the unknown profile. 
    It can take a few minutes for all of the data from the unknown user profile
    to appear on the known user profile.

- If `mergeOnUnknownToKnown` is set to `false`, the SDK: 
  - Calls `onAuthTokenRequested` to fetch a JWT token for the known user profile
    (if you're using a JWT-enabled API key).
  - Does not call the User Merge API.
  - Sends future user updates and events to Iterable, to the known user profile
    (not to the unknown user profile). The unknown user profile remains in
    Iterable. 