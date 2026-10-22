---
slug: event-tracking-testing-and-troubleshooting
feature: event-tracking
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: "Event Tracking: Testing and Troubleshooting"
source_url: https://support.iterable.com/hc/articles/360035402451
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/event-tracking/event-tracking-testing-and-troubleshooting/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 1286f5d3c53c5e61ae398c4749ccf1d9fc601e44
fetched_at: 2026-10-06T10:28:57.985Z
summary: Here's how to verify that your events are tracking correctly in
  Iterable and how to fix it if they aren't.
---
# Event Tracking: Testing and Troubleshooting

Here's how to verify that your events are tracking correctly in Iterable and how 
to fix it if they aren't.

## Testing

Go to **Audience > Contact Lookup** and search for a user to view their tracked 
events.

Click **Events > History** to confirm that your events are being tracked to the 
right user. When inspecting events, verify that the `dataFields` object contains 
any data you passed in.

![Viewing a user's event history](https://support.iterable.com/hc/article_attachments/18551602370068/viewing-a-users-event-history.png "Viewing a user's event history")

> [!NOTE]
> - By default, Iterable tracks some user information (like their IP address) from 
>   third-party systems. If you would like to turn this tracking off, please 
>   notify your customer success manager or contact Iterable Support.

## Troubleshooting

Having issues? First, make sure you're using the right the API key. Then check 
that you're using the same user identifier you used when you initiated the SDK 
(with either an `email` or `userId` identity call).

### If push open events aren't being tracked

Make sure you're using the latest version of Iterable's mobile SDKs:

- Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152)
- Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)

### If custom events aren't being tracked

Make sure you're using an event-tracking API call to track custom events. You 
can either call the `POST /api/events/track` Iterable API endpoint, or use the 
following code to add custom event tracking to your app:

#### Swift

```swift
IterableAPI.track(event: "Custom_event", dataFields: ["key": "value"])
```

#### Java
```java
IterableApi.getInstance().track("Custom_event", datafields);
```