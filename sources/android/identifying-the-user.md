---
url: https://support.iterable.com/hc/articles/360035402531
title: Identifying the User
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/managing-user-profiles/identifying-the-user/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: ced31ca29ce63d634a0c4691277a114ed3f0ceb9
fetched_at: 2026-05-25T15:11:46.888Z
---
# Identifying the User

The Iterable SDK can identify users by email or user ID.

## In this article

[[toc]]

## Overview

To identify a user, you'll need to do two things: specify an email address or
user ID, and then call `updateUser` to send that value to Iterable.

## Identifying the user by email

Email is typically used as the key identify within Iterable because it tracks
across devices to aggregate data between a user's phones, tablet, web-site
activity or even IoT (Internet-of-Things) device.

Iterable also allows for multi-dimensional nested data types, meaning you can
organize your data based on relevant key values.

Once you have an email address or user ID for your app's current user, set
`IterableAPI.email` or `IterableAPI.userId`. For example:

:::warning WARNING
- Don't specify both `email` and `userId` in the same call, as they will be
  treated as different users by the SDK. Only use one type of identifier, email
  or user ID, to identify the user.
- Your app will not be able to receive push notifications until you set one
  of these values
:::

Add this line of code as soon as you know the user's email:

_Swift_

```swift
IterableAPI.email = "user@example.com"
```

_Objective-C_

```objectivec
IterableAPI.email = @"user@example.com";
```

_Java_

```java
IterableApi.getInstance().setEmail("user@example.com");
```

:::tip NOTES
Please see [User Profile Fields Used by Iterable](https://support.iterable.com/hc/articles/217744303) 
to ensure you don't add data that is specific to set fields in Iterable.
:::

## Identifying the user by user ID

Iterable can also identify user by user ID. However, all things being equal, it
is recommended to use email as the key identifier.

_Swift_

```swift
IterableAPI.userId = "user123"
```

_Objective-C_

```objectivec
IterableAPI.userId = @"user123";
```

_Java_

```java
IterableApi.getInstance().setUserId("user123");
```

You can add the `userId` identifier at any point after the `IterableConfig()` 
call.


:::tip NOTES
- When creating a user by `userId` in an email-based project, Iterable automatically
  assigns the user a `@placeholder.email` email address (a user identifier, not
  a way to message the user). For example, if you create a user with a `userId`
  of `user123`, their user profile will also receive an `email` such as
  `user123+147178873@placeholder.email`. To learn more, read [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956).
- A user ID can be up to 52 characters long.

:::

## Identifying the device of the user

For Iterable to send push notifications to an iOS device, it must know the
unique token assigned to that device by Apple or Android.

Iterable uses silent push notifications to tell iOS apps when to fetch new
in-app messages from the server. Because of this, your app must register for
remote notifications with Apple even if you do not plan to send it any push
notifications.

### Auto push registration

`IterableConfig.autoPushRegistration` determines whether or not the SDK will:

- Automatically register for a device token when the SDK is given a new
  email address or user ID. Disable the device token for the previous user when
  a new user logs in.

If `IterableConfig.autoPushRegistration` is **true** (the default value):

- Setting `IterableAPI.email` or `IterableAPI.userId` causes the SDK to
  automatically call the `registerForRemoteNotifications()` method on
  UIApplication and pass the resulting device token to the
  `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` method on
  the app delegate.

If `IterableConfig.autoPushRegistration` is **false**:

- After setting `IterableAPI.email` or `IterableAPI.userId`, you must
  manually call the `registerForRemoteNotifications()` method on
  `UIApplication`. This will fetch the device token from Apple and pass it to
  the `application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` method
  on the app delegate.

### Send the device token to Iterable

:::tip NOTES
- Iterable users the device token to send push notifications and in-app
  messages.
- Users do not need to opt in to Apple push notifications for Iterable to get
  the device token.
:::

To send the device token to Iterable and save it on the current user's
profile, call `IterableAPI.register(token:)` from the
`application(_:didRegisterForRemoteNotificationsWithDeviceToken:)` method on
`UIApplicationDelegate`. For example:

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

_Java_
```java
// Iterable SDK automatically registers the push token with Iterable 
// whenever setEmail or setUserId is called.

// If you want to trigger token registration manually, first disable automatic 
// registration by calling setAutoPushRegistration(false) on IterableConfig.Builder when initializing the SDK.

// Then call registerForPush whenever you want to register the token:

// Only use this line if you want to register push manually.
// IterableApi.getInstance().registerForPush();
```

Once you register for push, you should see the device on the user's Iterable profile.
Access a user's profile in Iterable by navigating to **Audiences > Contact Lookup**.

## Updating email and user ID

Use the following code to update both an `email` and a `userId`:

_Swift_

```swift
IterableAPI.updateEmail("<NEW-EMAIL-ADDRESS>",
    onSuccess: { _ in
        IterableAPI.updateUser(
            [JsonKey.userId: "<NEW-USER-ID>"],
            mergeNestedObjects: false,
            onSuccess: { _ in
            // this needs to be set after both calls have finished successfully
            IterableAPI.userId = "<NEW-USER-ID>"
        }, onFailure: nil)
}, onFailure: nil)
```

_Objective-C_

```objectivec
[IterableAPI updateEmail:@"<NEW-EMAIL-ADDRESS>"
                onSuccess:^(NSDictionary * _Nullable data) {
    [IterableAPI updateUser:@{@"userId": @"<NEW-USER-ID>"}
            mergeNestedObjects:NO
                    onSuccess:^(NSDictionary * _Nullable data) {
        // this needs to be set after both calls have finished successfully
        IterableAPI.userId = @"<NEW-USER-ID>";
    } onFailure:nil];
} onFailure:nil];
```

_Java_

```java
IterableApi.getInstance().updateEmail("newEmail@somewhere.com", new IterableHelper.SuccessHandler() {
    @Override
    public void onSuccess(JSONObject data) {
        JSONObject userIDobj = new JSONObject();
        try {
            userIDobj.put("userId", "newUserId");
        } catch (JSONException e) {
            e.printStackTrace();
        }
        IterableApi.getInstance().updateUser(userIDobj);
    }
}, new IterableHelper.FailureHandler() {
    @Override
    public void onFailure(String reason, JSONObject data) {
        Log.e(TAG, reason)
    }
});
```

## Next steps

To troubleshoot user identification, see [Testing and Troubleshooting User Profiles](https://support.iterable.com/hc/articles/360035079512).

If you have already identified the user for your use case, see [Updating User Profiles](https://support.iterable.com/hc/articles/360035402611) 
and [User Update Recommendations](https://support.iterable.com/hc/articles/360035031532).
