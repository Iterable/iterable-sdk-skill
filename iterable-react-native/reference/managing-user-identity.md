---
slug: managing-user-identity
feature: user-profiles
archetype: identity
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Managing User Identity with Iterable's React Native SDK
source_url: https://iterable.zendesk.com/hc/articles/360045714152
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/managing-user-identity/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: d9c6d023a1405845d55aef9e6315f6e1dbecd905
fetched_at: 2026-08-28T14:44:26.822Z
summary: As people use your mobile apps, you'll likely want to save data and
  events to their Iterable user profiles. Your marketing team can then use this
  data to send relevant, personalized messages.
---
# Managing User Identity

As people use your mobile apps, you'll likely want to save data and events to
their Iterable user profiles. Your marketing team can then use this data to send
relevant, personalized messages.

Before you can save data, you'll need to identify the user it belongs to. This
guide describes how to do so.

## Identifying users by user ID

To identify a user by the `userId` field, call the static `setUserId` method on
the `Iterable` class.

- **Method declaration:**

    ```typescript
    static setUserId(userId: string | undefined)
    static setUserId(userId: string | undefined, authToken?: string | undefined)
    ```

    |Parameter Name|Description|
    |:-------------|:--------------------------------------------------------------|
    |`userId`      |The user ID to associate with the current user.                |
    |`authToken`   |A valid, pre-fetched JWT the SDK can use to authenticate API requests for this user.|

- **Description:**

    These methods associate the current user with the specified `userId`. If
    your Iterable project doesn't yet have a user with that `userId`,
    `setUserId` creates one.

    They also add a placeholder `email` address to the user's Iterable profile,
    in the form: `userId` + hash + `@placeholder.email` (email-based projects
    only). To learn more, read [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956).

    :::tip NOTES
    - Specify an `email` or a `userId`, but not both.
    - Iterable's React Native SDK persists a `userId` or `email` across app
      sessions and restarts, until you manually change it.
    - Assuming `IterableConfig.autoPushRegistration` is `true` (its default
      value), setting a `userId` or `email` automatically registers the device for
      push notifications and sends the `deviceId` and `token` to Iterable.
    - Use the `authToken` parameter to pass in a pre-fetched JWT, as needed, to
      avoid race conditions.
    :::

 - **Example:**

    ```javascript
    Iterable.setUserId("testUser123");
    ```

    This example associates the app's current user with a `userId` of
    `testUser123`. The placeholder email it creates would look something like
    `testUser123+1033671565@placeholder.email`.

## Identifying users by email

To identify a user by their email address, call the static `setEmail` method
on the `Iterable` class:

- **Method declaration:**

    ```typescript
    static setEmail(email: string | undefined)
    static setEmail(email: string | undefined, authToken?: string | undefined)
    ```

    |Parameter Name|Description|
    |:-------------|:--------------------------------------------------------------|
    |`email`       |The email address to associate with the current user.          |
    |`authToken`   |A valid, pre-fetched JWT the SDK can use to authenticate API requests for this user.|

- **Description:**

    These methods associates the current user with the specified `email`.
    If your Iterable project doesn't yet have a user profile with that `email`,
    `setEmail` creates one.

    :::tip NOTES
    - Specify an `email` or a `userId`, but not both.
    - Iterable's React Native SDK persists a `userId` or `email` across app
      sessions and restarts, until you manually change it.
    - Assuming `IterableConfig.autoPushRegistration` is `true` (its default value),
      setting a `userId` or `email` automatically registers the device for push
      notifications and sends the `deviceId` and `token` to Iterable.
    - Use the `authToken` parameter to pass in a pre-fetched JWT, as needed, to
      avoid race conditions.
    :::

- **Example:**

    ```javascript
    Iterable.setEmail("user@example.com");
    ```

    This example associates the app's current user with an `email` of
    `user@example.com`.

## Getting the current `userId`

To get the `userId` your app associates with the current user, call the static
`getUserId` method on the `Iterable` class.

- **Method declaration:**

    ```typescript
    static getUserId(): Promise<string | undefined>
    ```

    Returns a [`Promise`](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise).
    Use [`then`](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise/then)
    to get the results.

- **Description:**

    Returns the `userId` your app associates with its current user.

- **Example:**

    ```javascript
    Iterable.getUserId().then(userId => {
        console.log("Current userId: " + userId);
    });
    ```

    This example fetches the current `userId` and outputs it to the console.

## Getting the current email

To get the `email` associated with the current user, call the static `getEmail`
method on the `Iterable` class.

- **Method declaration:**

    ```typescript
    static getEmail(): Promise<string | undefined>
    ```

    Returns a [`Promise`](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise).
    Use [`then`](https://developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Promise/then)
    to get the results.

- **Description**:

    Returns the `email` your app associates with its current user.

- **Example:**

    ```javascript
    Iterable.getEmail().then(email => {
        console.log("Current email: " + email);
    });
    ```

    This example fetches the current `email` and outputs it to the console.

## Modifying an email address

To modify a user's email address, or to give a real (non-placeholder) email
address to a user identified by `userId`, call the static `updateEmail` method on
the `Iterable` class.

- **Method declaration:**

    ```typescript
    static updateEmail(email: string, authToken?: string | undefined)
    ```

    |Parameter Name|Description|
    |:-------------|:--------------------------------------------------------------|
    |`email`       |The new email address to associate with the current user.      |
    |`authToken`   |A valid, pre-fetched JWT the SDK can use to authenticate API requests for this user.|

- **Description:**

    This method changes the value of the `email` field on the current user's Iterable
    profile.

- **Example:**

    ```javascript
    Iterable.updateEmail("newEmail@example.com")
    ```

    This example changes the current user's `email` to `newEmail@example.com`.

## Signing out

To tell the SDK that the current user has signed out, set `email` or `userId`
(whichever is currently set) to `null`:

```javascript
Iterable.setEmail(null)
```
```javascript
Iterable.setUserId(null)
```

Assuming `IterableConfig.autoPushRegistration` is `true` (its default value),
setting `email` or `userId` to `null` prevents Iterable from sending further push
notifications to that user, for that app, on that device. On the user's Iterable
profile, in the `devices` array, notice that `endpointEnabled` is `false` for the
device in question.

> [!TIP]
> To manually disable push notifications to the device, call the static
> `disableDeviceForCurrentUser` method on the `Iterable` class.
