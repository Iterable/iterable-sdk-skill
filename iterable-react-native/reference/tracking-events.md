---
slug: tracking-events
feature: event-tracking
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Tracking Events and Purchases with Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/360046134891
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/tracking-events/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: 381795f3d7eabb6b0cf97de20ead603d22ff4cf9
fetched_at: 2026-08-28T14:44:26.850Z
summary: When users take particular actions in your mobile apps—open push
  notifications, complete their profiles, close in-app messages, etc.—Iterable's
  React Native SDK can save corresponding events, of custom or pre-defined
  types, to their Iterable profiles. This guide describes how to do this, which
  gives your marketing team more data to use when segmenting users or setting up
  journeys.
---
# Tracking Events and Purchases with Iterable's React Native SDK

When users take particular actions in your mobile apps—open push notifications,
complete their profiles, close in-app messages, etc.—Iterable's React Native SDK
can save corresponding events, of custom or pre-defined types, to their Iterable
profiles. This guide describes how to do this, which gives your marketing team
more data to use when segmenting users or setting up journeys.

## Identify the user

Before you call the methods described below, [identify your app's user](https://iterable.zendesk.com/hc/articles/360045714152)
so that Iterable knows which profile to update.

## Push notification and in-app message events

Iterable automatically tracks various in-app message and push notification-related
events, but you can also use Iterable's React Native SDK to track them manually.
To learn more, read [Push Notifications with Iterable's React Native SDK](https://iterable.zendesk.com/hc/articles/360046134871)
and [In-App Messages with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714172)

## Tracking purchases

To create a `purchase` event on a user's Iterable profile, call the static
`trackPurchase` method on the `Iterable` class.

- **Method declaration:**

    ```typescript
    static trackPurchase(
      total: number,
      items: Array<IterableCommerceItem>,
      dataFields: any | undefined
    )
    ```

    |Parameter Name|Description|
    |:-------------------|:----------------------------------------------------|
    |`total`             |The total cost of the purchase.                      |
    |`items`             |The items included in the purchase.                  |
    |`dataFields`        |Descriptive data to store on the `purchase` event.   |

    Represent each item in the purchase with an `IterableCommerceItem` object.  This
    class has nine fields: `id` (string, required), `name` (string, required),
    `price` (number, required), `quantity` (number, required), `sku` (string,
    optional), `description` (string, optional), `url` (string, optional),
    `imageUrl` (string, optional), and `categories` (array of strings, optional),
    and a constructor to initialize those values.

    :::tip NOTE
    Iterable does not sum the `price` fields for the various items in the
    purchase. Instead, it uses the `total` that you provide.
    :::

- **Description:**

    This method creates a `purchase` event on the user's Iterable profile.

- **Example:**

    ```javascript
    const dataFields = {
      "Store_Address": {
      "Street1": "123 Main St",
      "Street2": "Apt 1",
      "City": "Iter-a-ville",
      "State": "CA",
      "Zip": "90210"}
    };

    const item = new IterableCommerceItem(
      "TOY1",
      "Red Racecar",
      4.99,
      1,
      "RR123",
      "A small, red racecar.",
      "https://www.example.com/toys/racecar",
      "https://www.example.com/toys/racecar/images/car.png",
      ["Toy", "Inexpensive"]
    );

    const items = [item];

    Iterable.trackPurchase(4.99, items, dataFields);
    ```

    This example creates a `purchase` event on the current user's Iterable
    profile.

## Updating shopping cart

To update the items saved in the shopping cart (or equivalent) implemented in the application,
call the static `updateCart` method on the `Iterable` class.

- **Method declaration:**

    ```typescript
    static updateCart(
      items: Array<IterableCommerceItem>,
    )
    ```
    |Parameter Name|Description|
    |:-------------------|:----------------------------------------------------|
    |`items`             |The items to be added to the shopping cart.          |

- **Description:**

    This method updates the shopping cart (or equivalent) in the application.

    Represent each item in the shopping cart with an `IterableCommerceItem` object.
    This class has nine fields: `id` (string, required), `name` (string, required),
    `price` (number, required), `quantity` (number, required), `sku` (string,
    optional), `description` (string, optional), `url` (string, optional),
    `imageUrl` (string, optional), and `categories` (array of strings, optional),
    and a constructor to initialize those values.

- **Example:**

    ```javascript
    const item = new IterableCommerceItem(
      "TOY1",
      "Red Racecar",
      4.99,
      1,
      "RR123",
      "A small, red racecar.",
      "https://www.example.com/toys/racecar",
      "https://www.example.com/toys/racecar/images/car.png",
      ["Toy", "Inexpensive"]
    );

    const items = [item];

    Iterable.updateCart(items);
    ```

    This method updates the shopping cart (or equivalent) with a single defined item.

## Tracking custom events

To save an event of a custom type to a user's Iterable profile, call the static
`trackEvent` method on the `Iterable` class.

- **Method declaration:**

    ```typescript
    static trackEvent(name: string, dataFields: any | undefined)
    ```

    |Parameter Name|Description|
    |:-------------|:----------------------------------------------------------|
    |`name`        |The `eventName` for the custom event.                      |
    |`dataFields`  |Descriptive data to store on the event.                    |

- **Description:**

    This method creates a custom event (`eventType` of `customEvent`) with
    `eventName` set to the value you provide in the `name` parameter, and
    stores it on the current user's profile.

- **Example:**

    ```javascript
    Iterable.trackEvent(
      "completedOnboarding",
      {
        "includedProfilePhoto": true,
        "favoriteColor": "red"
      }
    );
    ```

    This call creates an event such as following on the user's Iterable profile:

    ```json
    {
        "eventName": "completedOnboarding",
        "eventType": "customEvent",
        "email": "user@example.com",
        "createdAt": "2020-07-14 04:06:04 +00:00",
        "eventUpdatedAt": "2020-07-14 04:06:04 +00:00",
        "dataFields": {
            "includedProfilePhoto": true,
            "favoriteColor": "red"
        },
        "itblInternal": {
            "documentCreatedAt": "2020-07-14 04:06:04 +00:00",
            "documentUpdatedAt": "2020-07-14 04:06:04 +00:00"
        }
    }
    ```

## Offline events processing

> [!TIP]
> If you'd like to use offline events processing, we'll need to enable it for
> your account. Talk to your customer success manager to get started.

Mobile apps built with Iterable's mobile SDKs can queue up events created when a
device is offline (for example, because there isn't a network connection
available, or because airplane mode is on), and then send them to Iterable the
next time the app is in the foreground with a network connection.

To use this feature, upgrade your apps to use:

- Iterable's iOS SDK, version [`6.4.5+`](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.5)
- Iterable's Android SDK, version [`3.4.7+`](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.4.7)
- Iterable's React Native SDK, version [`1.3.3+`](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.3)

After you've upgraded your apps to use these SDK versions and your customer
success manager has enabled offline events processing for your account, your
apps will automatically capture and save offline events. Iterable's mobile SDKs
provide offline processing for the following types of events:

- Purchase
- Push open
- In-app open
- In-app click
- In-app close
- Inbox session
- In-app delivery
- In-app consume
- Custom events tracked manually

When your app is next in the foreground with an internet connection, it will send
any queued offline events back to Iterable.

> [!NOTE]
> Iterable's mobile SDKs do not queue up any other API calls to send later (e.g.,
> `registerDeviceToken`, `disableDevice`, `updateUser`, `updateSubscription`, or
> `updateEmail`).

### Timestamps

When sending offline events to Iterable (when a network connection has been
reestablished), Iterable's mobile SDKs include values for two timestamps:

`createdAt` - The date and time when the user triggered the event.
`sentAt` - The date and time when the event is sent to Iterable.

Iterable uses the difference between an event's `sentAt` time and the server time
when the event is received to adjust the event's `sentAt` and `createdAt` times to
be in sync with server time. When you query events from Iterable's API, you'll
see both of these timestamps.

### Differentiating offline and online events

To determine if a particular event saved in Iterable was originally captured
offline, check its attributes for mismatched `createdAt` and `sentAt` values. This
indicates that the event was captured at one time and saved at another, as is
the case for offline events.

If an event doesn't have a `sentAt` value, it was captured online (`sentAt` is a
new field introduced with this feature.

### Multiple users

When users sign out of your app, Iterable's mobile SDKs delete any captured
offline events that haven't yet been saved back to Iterable.

### Storage limits and timeframes

Iterable's mobile SDKs will capture up to 1000 offline events, and then stop
capturing new offline events. However, there's no limit to the amount of time
for which offline events can be saved on a device.

### JWT-enabled API keys

Iterable's mobile SDKs support offline events processing for JWT-enabled API
keys and non JWT-enabled API keys.

However, when using a JWT-enabled API key, if the JWT token happens to get
invalidated between a time that offline events are queued up and the time that
the device comes back online, those queued events may not be saved to Iterable.
We may improve this in the future.

### Increased event volume

When you have your customer success manager enable offline events processing for
your account (and update to an SDK version that supports it), you may see an
increase in the number of custom events saved in your project (since offline
events that were previously dropped are now captured). However, this isn't
necessarily the case, and depends on the usage patterns of your users. To
monitor custom event usage, use the [Custom Event Usage](https://support.iterable.com/hc/articles/360043366492)
page.

### Triggering journeys

Like other events, offline events can trigger journeys when they're eventually
saved back to Iterable. However, it may not be desirable for older events to
trigger journeys that are no longer relevant. Because of this, offline events
saved to Iterable more than 24 hours after their creation will not trigger
journeys.
