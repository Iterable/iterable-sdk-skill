---
url: https://support.iterable.com/hc/articles/360035395671
title: Tracking Events and Purchases with Iterable's Mobile SDKs
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/event-tracking/tracking-events-with-iterables-mobile-sdks/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 0dbb170bfbd574bf405b33990d2c288ad8dcd153
fetched_at: 2026-05-25T15:11:48.241Z
---
# Tracking Events and Purchases with Iterable's Mobile SDKs

Iterable's mobile SDKs can track _events_, which correspond to actions taken
by your app's users. Events can be related to messages you've sent (for example,
a user opening an in-app message) or to a particular feature or piece of content
in your app (for example, a user signing up for a new account).

You can use events in segmentation and journeys to help you reach the right
users with the right content.

:::tip NOTES
- To reduce noise and make the data you store in Iterable as useful and
  actionable as possible, avoid the temptation to track every custom event you
  can think of. Instead, track events related to important milestones, since
  they can help you reach your customers in useful and engaging ways.
- To learn more about keeping track of your custom event usage, read 
  [Monitoring Custom Event Usage](https://support.iterable.com/hc/articles/360043366492).
:::

## In this article

[[toc]]

## Custom event names

In general, it's a good idea to avoid using spaces in custom event names, since 
you'll need to use a [special Handlebars syntax](https://support.iterable.com/hc/articles/36530857619348#blank-or-missing-values-in-rendered-content)
to reference a field name that contains a space.

For example, for an event saved when a user complete's the sign-up process for
your service, `completedSignup` is a good event name but `completed signup` is
not.

## Tracking custom events

To use track an event using Iterable's mobile SDKs, use syntax such as:

_Swift_

```swift
IterableAPI.track(
    event: "customEvent", 
    dataFields: ["key": "value"]
)
```

_Objective-C_

```objectivec
[IterableAPI track:@"custom_event" dataFields:@{@"key": @"value"}];
```

_Java_

```java
IterableApi.getInstance().track(
    "customEvent", 
    dataFields
);
```

_JavaScript (React Native)_:

```javascript
Iterable.trackEvent(
  "completedOnboarding",
  {
    "includedProfilePhoto": true,
    "favoriteColor": "red"
  }
);
```

## Tracking purchase events

To help you [track information related to purchases and revenue](https://support.iterable.com/hc/articles/205480285),
Iterable's mobile SDKs include a `trackPurchase` method.

_Swift_

```swift
// Example dataFields
let dataFields: [String: Any] = [
    "Store_Address": [
        "Street1": "123 Main St",
        "Street2": "Apt 1",
        "City": "Iter-a-ville",
        "State": "CA",
        "Zip": "90210"
    ]
]


// Create an array of CommerceItem objects
let item : CommerceItem = CommerceItem(
    id: "TOY1",
    name: "Red Racecar",
    price: 4.99,
    quantity: 1,
    sku: "RR123",
    description: "A small, red racecar.",
    url: "https://www.example.com/toys/racecar",
    imageUrl: "https://www.example.com/toys/racecar/images/car.png",
    categories: ["Toy", "Inexpensive"]
)

let items = [item]

// Make the call to Iterable's API
IterableAPI.track(purchase: 4.99, items: items, dataFields: dataFields)
```

_Objective-C_

```objectivec
// Example dataFields
NSDictionary<NSString *, id> *dataFields = @{
    @"Store_Address": @{
            @"Street1": @"123 Main St",
            @"Street2": @"Apt 1",
            @"City": @"Iter-a-ville",
            @"State": @"CA",
            @"Zip": @"90210"
    }
};

// Create an array of CommerceItem objects
CommerceItem *item = [[CommerceItem alloc]
                        initWithId:@"TOY1"
                        name:@"Red Racecar"
                        price:@4.99F
                        quantity:1
                        sku:@"RR123"
                        description:@"A small, red racecar"
                        url:@"https://www.example.com/toys/racecar"
                        imageUrl:@"https://www.example.com/toys/racecar/images/car.png"
                        categories:@[@"Toy", @"Inexpensive"]];

NSArray<CommerceItem *> *items = @[item];

// Make the call to Iterable's API
[IterableAPI trackPurchase:@4.99F items:items dataFields:dataFields];
```

_Java_

```java
// Example dataFields
JSONObject store_address = new JSONObject();
final JSONObject dataFields = new JSONObject();

try {
    store_address.put("Street1", "123 Main St");
    store_address.put("Street2", "Apt 1");
    store_address.put("City", "Iter-a-ville");
    store_address.put("State", "CA");
    store_address.put("Zip", "90210");
    datafields.put("dataFields", store_address);
} catch (JSONException e) {
    e.printStackTrace();
}

// Create an array of CommerceItem objects
CommerceItem item = new CommerceItem(
    "TOY1",
    "Red Racecar",
    4.99,
    1,
    "RR123",
    "A small, red racecar",
    "https://www.example.com/toys/racecar",
    "https://www.example.com/toys/racecar/images/car.png",
    new String[] {"Toy", "Inexpensive" }
);

List<CommerceItem> items = new ArrayList<CommerceItem>();
items.add(item);

// Make the call to Iterable's API
IterableApi.getInstance().trackPurchase(new Double(4.99), items, dataFields);
```

## Offline events processing

:::tip TIP
If you'd like to use offline events processing, we'll need to enable it for 
your account. Talk to your customer success manager to get started.
:::

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
- Update cart
- Push open
- In-app open
- In-app click
- In-app close
- Inbox session
- In-app delivery
- In-app consume
- Embedded message received
- Embedded message click
- Embedded message session
- Custom events tracked manually

When your app is next in the foreground with an internet connection, it will send
any queued offline events back to Iterable.

:::tip INFO
Iterable's mobile SDKs do not queue up any other API calls to send later (e.g., 
`registerDeviceToken`, `disableDevice`, `updateUser`, `updateSubscription`, or 
`updateEmail`).
:::

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

Starting with Android SDK 3.7.0+ and iOS SDK 6.6.8+, the SDKs include an
auto-retry feature for JWT failures during offline processing. When a queued
event encounters a 401 JWT error, the SDK automatically pauses authenticated
task processing, refreshes the JWT token, and retries the failed task.
Unauthenticated API calls (such as `disableDevice` and `mergeUser`) continue
processing while authentication is paused. This feature is controlled by a
remote configuration flag and requires no code changes.

:::tip NOTE
On older SDK versions, if the JWT token gets invalidated between the time that
offline events are queued and the time the device comes back online, those
queued events may not be saved to Iterable.
:::

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
