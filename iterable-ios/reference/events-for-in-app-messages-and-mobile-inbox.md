---
slug: events-for-in-app-messages-and-mobile-inbox
feature: in-app-messages
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Events for In-App Messages and Mobile Inbox
source_url: https://support.iterable.com/hc/articles/360038939972
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/in-app/events-for-in-app-messages-and-mobile-inbox/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: a98014b1a78b52b28e0bb8e075750240f2de44e8
fetched_at: 2026-10-06T10:32:47.805Z
summary: "As users interact with in-app messages and your app's mobile inbox,
  Iterable can capture various events that describe the actions they're taking.
  You can use these events to:"
---
# Events for In-App Messages and Mobile Inbox

As users interact with in-app messages and your app's mobile inbox, Iterable can
capture various events that describe the actions they're taking. You can use
these events to:

- Determine how users are interacting with your in-app message campaigns.
- Segment users and filter journeys.
- Trigger journeys.
- Trigger system webhooks.

This document describes the in-app message and Mobile Inbox events Iterable
can capture, how to capture them, and how to use them.

> [!TIP]
> For more information about event tracking, read [Tracking Events with Iterable's Mobile SDKs](https://support.iterable.com/hc/articles/360035395671).

## APIs for capturing in-app message events

Iterable's mobile SDKs and web SDK automatically capture the events described in
this document (however, the web SDK does not yet provide a mobile inbox, and
does not capture mobile inbox-related events). 

It's also possible to capture these events by making calls to Iterable's [API](https://support.iterable.com/hc/articles/204780579):

- [`POST /api/inApp/target`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-target)
- [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
- [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
- [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
- [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
- [`POST /api/events/inAppConsume`](https://support.iterable.com/hc/articles/204780579#post-api-events-inappconsume)

Other in-app message and Mobile Inbox APIs include:

- [`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages)
- [`POST /api/inApp/cancel`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-cancel)

> [!NOTE]
> Iterable does not provide APIs for tracking [inbox session](#inbox-session) or 
> [inbox message impression](#inbox-message-impression) events. To track these 
> events, use Iterable's mobile SDKs.

## Event definitions

This section describes the various events Iterable can capture for in-app 
messages and Mobile Inbox.

## In-browser message events

There are no events specific to [in-browser messages](https://support.iterable.com/hc/articles/4418166649748) 
(in-app messages that target a website instead of a mobile app). They're
standard in-app message events, with `platform` set to `Web`, `deviceId` set to
the browser user agent associated with the event, and `appPackageName` is set to
your app's package name.

### In-app click

An in-app click event indicates that a user tapped a link or button in an
in-app message. 

> [!NOTE]
> - Iterable's mobile SDKs automatically capture in-app click events. To capture
>   them manually, call the [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
>   API endpoint.
> - For a description of when Iterable's mobile SDKs capture click, close, and
>   delete events, read about [click, close, and delete events](#click-close-and-delete-events).

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `clickedUrl` — The URL of the clicked link/button (string, if available)
- `createdAt` — When the event occurred (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS`, `Android`, or `Web` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppClick` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `inboxSessionId` — The ID of the inbox session in which this event occurred. Not 
  present if there's not an inbox session associated with the event.
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `location` — The location from which the event was initiated: `in-app`,
    `inbox` or a custom value (string).
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)

### In-app close

An in-app close event indicates that a user closed an in-app message by tapping
a button or link in the message's content or by tapping a back button (or an 
auto-generated close button on an [in-browser message](https://support.iterable.com/hc/articles/4418166649748), 
if your web SDK implementation is configured to add one).

> [!NOTE]
> - Iterable's mobile SDKs automatically capture in-app close events. To capture
>   them manually, call the [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
>   API endpoint.
> - For a description of when Iterable's mobile SDKs capture click, close, and
>   delete events, read about [click, close, and delete events](#click-close-and-delete-events).

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `clickedUrl` — The URL (if any) of the button/link the user clicked to close the
  in-app message.
- `closeAction` — The type of action that initiated the close: `link` (for buttons
  or links), `back` (for a back button), `other` or a custom value (string)
- `createdAt` — When the event occurred (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS`, `Android`, or `Web` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppClose` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `inboxSessionId` — The ID of the inbox session in which this event occurred. Not 
  present if there's not an inbox session associated with the event.
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `location` — The location from which the event was initiated: `in-app`,
    `inbox` or a custom value (string).
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)

### In-app delete 

An in-app delete event indicates that a user deleted an inbox-enabled in-app 
message by swiping it in the inbox or clicking a delete button/link (with URL
`iterable://delete`) in its content.

> [!NOTE]
> - Iterable's mobile SDKs automatically capture in-app delete events. To capture
>   them manually, call the [`POST /api/events/inAppConsume`](https://support.iterable.com/hc/articles/204780579#post-api-events-inappconsume) 
>   endpoint, making sure to provide a `deleteAction` value. When `deleteAction` 
>   is excluded, the API does not generate this event.
> - For a description of when Iterable's mobile SDKs capture click, close, and
>   delete events, read about [click, close, and delete events](#click-close-and-delete-events).

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `createdAt` — When the event occurred (date)
- `deleteAction` — How the message was deleted: `inbox-swipe` (the message was
  deleted with a swipe in the inbox), or `delete-button` (the user tapped a button
  or link having URL `iterable://delete`) or a custom value.
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS`, `Android`, or `Web` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppDelete` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `inboxSessionId` — The ID of the inbox session in which this event occurred. Not 
  present if there's not an inbox session associated with the event.
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `location` — The location from which the event was initiated: `in-app`,
    `inbox` or a custom value (string).
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)

### In-app delivery

An in-app delivery event indicates that an in-app message arrived on a user's
device. It does not mean that the user viewed the message.

> [!NOTE]
> Iterable's mobile SDKs automatically capture in-app delivery events. To capture
> them manually, call the [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
> API endpoint.

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `createdAt` — When the event occurred (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS`, `Android`, or `Web` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppDelivery` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)

### In-app open

An in-app open event indicates that an in-app message was displayed, either
because it appeared on arrival or because the user selected it in the inbox.

> [!NOTE]
> Iterable's mobile SDKs automatically track in-app open events. However, you 
> can also track these events manually by calling [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen). 
> This endpoint also sets a message's `read` field to `true`.

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `createdAt` — When the event occurred (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS`, `Android`, or `Web` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppOpen` (string)
- `expiresAt` — The expiration date and time for the message associated with the
   event (date)
- `inboxSessionId` — The ID of the inbox session in which this event occurred. Not 
   present if there's not an inbox session associated with the event.
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `location` — The location from which the event was initiated: `in-app`,
    `inbox` or a custom value (string)
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)

### In-app send

An in-app send event indicates that Iterable sent an in-app message to a user.  It
does not mean that the user received the message.

> [!NOTE]
> Iterable captures this event any time it sends an in-app message to a user, 
> regardless of whether it was triggered by the web interface or the
> [`POST /api/inApp/target`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-target)
> API.

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `channelIds` — The IDs of the channels associated with the in-app message.
- `contentId` — The ID of the template revision for the message associated with
  the event (long)
- `createdAt` — When the event occurred (date)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppSend` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `messageTypeIds` — The IDs of the message types associated with the in-app
  message.
- `templateId` — The ID of the template associated with the message (long)

### In-app send skip

An in-app send skip event indicates that Iterable did not send an in-app message to
an intended recipient, for any of various reasons.

> [!NOTE]
> Iterable captures this event automatically. There is no way to generate it
> manually.

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `createdAt` — When the event occurred (date)
- `email` — The email address of the recipient (string)
- `eventType` — `inAppSendSkip` (string)
- `messageId` — The ID of the message associated with the event (string)
- `reason` — A string that describes why Iterable did not send the message to the
  intended recipient; for example, `DuplicateMarketingMessage` (string)

### Inbox message impression

An inbox message impression event captures the number of unique times a
specific message appeared in the message list during a single inbox session
(period when the inbox was open). It's useful for understanding how many times a
user had the opportunity to notice a particular message in the inbox during a
single inbox session.

> [!NOTE]
> Iterable's mobile SDKs automatically capture inbox message impression events.
> It is not possible to capture these events manually.

Fields:

- `campaign` — An object containing various fields that describe the campaign
  associated with the event (object)
- `campaignId` — The ID of the campaign associated with the message (long)
- `createdAt` — When the event was created; close to the end of the session (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier, or a browser user agent (string)
  - `platform` — `iOS` or `Android` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `eventType` — `inboxMessageImpression` (string)
- `expiresAt` — The expiration date and time for the message associated with the
  event (date)
- `impressionCount` — The number of times the message appeared in the inbox list
  during the inbox session associated with this event (long)
- `inboxSessionEnd` — The date and time when the inbox session ended (date)
- `inboxSessionId` — The ID of the inbox session associated with this event.
- `inboxSessionStart` — The date and time when the inbox session started (date)
- `messageContext` — An object containing various fields that describe the message
  associated with the event (object)
  - `saveToInbox` — Whether or not the message associated with the event was
    configured to use the inbox (boolean)
  - `silentInbox` — Whether or not the message associated with the event was
    configured to send directly to the inbox (boolean)
- `messageId` — The ID of the message associated with the event (string)
- `templateId` — The ID of the template associated with the message (long)
- `totalDuration` — The total number of seconds the message was visible in the
  inbox during the inbox session associated with this event.

### Inbox session

An inbox session event indicates that an app displayed the mobile inbox and captures
how long it was open. The time span for this event starts when the inbox appears on
the screen and ends when the user navigates away, minimizes the app, or closes the
app. Tapping on a message in the inbox to view its content does not end the inbox
session.

> [!NOTE]
> Iterable's mobile SDKs automatically capture inbox session events. It is not 
> possible to capture these events manually.

Fields:

- `createdAt` — When the event was created; close to the end of the session (date)
- `deviceInfo` — An object containing various fields that describe the device and
  app associated with the event (object)
  - `deviceId` — The device's unique identifier  (string)
  - `platform` — `iOS` or `Android` (string)
  - `appPackageName` — The package name of the app (string)
- `email` — The email address of the recipient (string)
- `endTotalMessageCount` — The number of messages in the inbox at the end of the
  inbox session. May differ from `startTotalMessageCount` since messages can be
  added or deleted during a session (long)
- `eventType` — `inboxSession` (string)
- `inboxSessionEnd` — The date and time when the inbox session ended (date)
- `inboxSessionId` — The ID of this inbox session.
- `inboxSessionStart` — The date and time when the inbox session started (date)
- `startTotalMessageCount` — The number of messages in the inbox at the start of
  the inbox session (long)
- `uniqueImpressionCount` — The number of unique messages that made an impression
  during the inbox session (long)

## Click, close, and delete events

When a user taps a link or button in an in-app message, events are saved to
their user profile in Iterable.

- Tapping any button or link creates an [in-app click](#in-app-click) event and 
  an [in-app close](#in-app-close) event.

- Tapping a delete button (URL `iterable://delete`) also creates an 
  [in-app delete](#in-app-delete) event.

- Swiping to delete a mobile inbox message creates an [in-app delete](#in-app-delete) 
  event.

## Using in-app message and Mobile Inbox events

Iterable provides various ways to make use of in-app message and Mobile
Inbox events, as described below.

### Campaign analytics

Use campaign analytics to learn how users are interacting with your in-app
messages.

To view the analytics for an in-app message campaign, navigate to 
**Messaging > Campaigns** and open the (active) campaign in question. Use
the drop-down menu initially labeled **No Metrics Selected** to pick the
metrics you'd like to view.

Available in-app message and Mobile Inbox analytics include: 

- Average order value
- In-app click rate
- Revenue
- Total in-app clicks
- Total in-app closes
- Total in-app deletes
- Total in-app deliveries
- Total in-app holdouts
- Total in-app opens
- Total in-app sends
- Total in-app send skips
- Total inbox impressions
- Total purchases
- Total unsubscribes
- Unique in-app clicks
- Unique purchases
- Unique unsubscribes

> [!NOTE]
> Total in-app deliveries can be higher than total sends, since any given
> user may receive the message on multiple devices and each device counts as a
> delivery. Similarly, a user can log out and log back in, which downloads the
> in-app messages again and creates new delivery events.

### Segmenting users and filtering journeys

In-app message and Mobile Inbox events can be used to segment users or filter
them in a journey.

For example:

- This screenshot shows a segmentation query that searches for users that
  have five or more inbox message impressions for a particular `messageId`:

- This screenshot shows a journey filter on users that have deleted any
  messages from their inbox by searching for **In-App Delete** events with 
  `messageContext.location` set to `inbox`:

The following in-app message and Mobile Inbox events can be used to segment users
and filter journeys:

- [In-app click](#in-app-click)
- [In-app close](#in-app-close)
- [In-app delete](#in-app-delete)
- [In-app delivery](#in-app-delivery)
- [In-app open](#in-app-open)
- [In-app send](#in-app-send)
- [In-app send skip](#in-app-send-skip)
- [Inbox message impression](#inbox-message-impression)
- [Inbox session](#inbox-session)

### Triggering journeys

In-app message and Mobile Inbox events can be used to trigger journeys
for particular users.

To do this, navigate to **Content > Journeys** and open the necessary journey.
Edit the journey's Start tile and select the appropriate entry source:

The following in-app message and Mobile Inbox events can trigger journeys:

- [In-app click](#in-app-click)
- [In-app close](#in-app-close)
- [In-app delete](#in-app-delete)
- [In-app delivery](#in-app-delivery)
- [In-app open](#in-app-open)

> [!NOTE]
> It is not possible to trigger a journey based on an inbox session or inbox 
> message impression event.

### Triggering system webhooks

Inbox and in-app events can be used to trigger system webhooks to send data
to external systems.

To do this, navigate to **Integrations > System Webhooks** and create or edit a
webhook. Select the in-app or Mobile Inbox events that should trigger the
webhook:

The following in-app message and Mobile Inbox events can trigger system webhooks:

- [In-app click](#in-app-click)
- [In-app close](#in-app-close)
- [In-app delete](#in-app-delete)
- [In-app delivery](#in-app-delivery)
- [In-app open](#in-app-open)
- [In-app send](#in-app-send)
- [In-app send skip](#in-app-send-skip)

> [!NOTE]
> It is not possible to trigger a system webhook based on an [inbox session](#inbox-session) 
> or [inbox message impression](#inbox-message-impression) event.
