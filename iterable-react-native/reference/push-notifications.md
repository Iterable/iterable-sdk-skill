---
slug: push-notifications
feature: push-notifications
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Push Notifications with Iterable's React Native SDK
source_url: https://iterable.zendesk.com/hc/articles/360046134871
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/push-notifications/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: cd2ea10bb40d789aed557a58d5946ab34fb682e5
fetched_at: 2026-08-28T14:44:26.827Z
summary: Iterable's React Native SDK provides methods to track push
  notification-related events and to access a push notification's payload, as
  described below.
---
# Push Notifications with Iterable's React Native SDK

Iterable's React Native SDK provides methods to track push notification-related 
events and to access a push notification's payload, as described below.

## Identify the user

Before you call the methods described below, [identify your app's user](https://iterable.zendesk.com/hc/articles/360045714152)
so that Iterable knows which profile to update.

## Tracking push notification events

Iterable's React Native SDK can be used to track push notification events, as
described in this section.

### Tracking push notification opens

Iterable's SDK automatically tracks push notification opens. However, it's also
possible to manually track these events by calling the static `trackPushOpenWithCampaignId`
method on the `Iterable` class.

**Method declaration:**

```javascript
static trackPushOpenWithCampaignId(
  campaignId: number, 
  templateId: number, 
  messageId: string | undefined, 
  appAlreadyRunning: boolean, 
  dataFields: any | undefined
)
```

|Parameter Name      |Description                                              |
|:-------------------|:--------------------------------------------------------|
|`campaignId`        |The ID of the Iterable campaign to associate with the push open.|
|`templateId`        |The ID of the Iterable template to associate with the push open.|
|`messageId`         |The ID of the Iterable message (specific send of a specific campaign to a specific user) to associate with the push open.|
|`appAlreadyRunning` |Whether or not the app was already running when the push notification arrived.|
|`dataFields`        |Information to store with the event.|

**Description:**

This method creates a `pushOpen` event on the current user's Iterable profile,
populating it with data provided to the method call.

**Example:**

```javascript
Iterable.trackPushOpenWithCampaignId(
    12345,
    67890,
    "0fc6657517c64014868ea2d15f23082b",
    false,
    {
        "discount": 0.99,
        "product": "cappuccino"
    }
);
```

This example tracks a push notification open, associating it with campaign ID
`12345`, template ID `67890`, message ID `0fc6657517c64014868ea2d15f23082b`, an
indication that the app was not already running, and various pieces of contextual
information.

## Getting the last push payload

To access the payload associated with the most recent push notification with 
which the user opened the app (by clicking an action button, etc.), call the 
static `getLastPushPayload` method on the `Iterable` class.

**Method declaration:**

```typescript
static getLastPushPayload(): Promise<any | undefined>
```

This method returns a `Promise`. Use `then` to get the results.

**Description:**

This method returns the payload of the last push notification with which the
user opened the app (by clicking an action button, etc.).

**Example:**

```javascript
Iterable.getLastPushPayload().then(payload => {
  console.log("pushPayload: " + JSON.stringify(payload))
});
```

This example outputs JSON similar to the following (note that the associated
push notification included this custom metadata: `{ "promotion": "summer sale" }`):

```json
{
  "requestCode": 2073073108,
  "title": "Get ready for summer!",
  "itbl": "{\"defaultAction\":{\"type\":\"openApp\"},\"attachment-url\":\"https:\\/\\/placekitten.com\\/400\\/300\",\"campaignId\":1357094,\"isGhostPush\":false,\"messageId\":\"b01f6c699af047579e8647e5176246bc\",\"actionButtons\":[{\"identifier\":\"tellMeMore\",\"action\":{\"type\":\"\"},\"title\":\"Tell me more!!\"}],\"templateId\":1887105}",
  "body": "Stop by your local store for big summer savings.",
  "promotion": "summer sale",
  "actionIdentifier": "tellMeMore"
}
```

## Deep links and custom actions

To learn about handling deep links and custom actions associated with push
notifications, read [Deep Links and Custom Actions with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134911).
