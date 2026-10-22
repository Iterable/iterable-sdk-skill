---
slug: push-campaign-metrics
feature: push-notifications
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Push Campaign Metrics
source_url: https://support.iterable.com/hc/articles/205730229
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/push-notification/push-campaign-metrics/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 2a1b38c070dcce3873b5811054b275e6106a31e2
fetched_at: 2026-10-06T11:07:35.108Z
summary: When a push campaign is published, Iterable will attempt to send a push
  to all devices registered for the contacts receiving the push. That total
  number of pushes attempted to all devices registered but not currently
  disabled will show up as the **Total Pushes Sent**.
---
# Push Campaign Metrics

## Send

When a push campaign is published, Iterable will attempt to send a push to
all devices registered for the contacts receiving the push. That total number
of pushes attempted to all devices registered but not currently disabled will
show up as the **Total Pushes Sent**.

**Unique Pushes Sent** represents the total number of contacts that were sent
the push. If a contact has more than one enabled device, both devices will be
sent the push, but the Unique Pushes Sent will only count at a user level.

## Bounce

If a push notification is sent to a device with a disabled token/regId, Apple
or Google will register the event as a bounce and provide feedback to
Iterable. A token/regId can become disabled due to a variety of reasons such
as when a user uninstalls the app, the app or token is no longer valid, the
user reinstalled their OS or upgraded to a new OS (less frequent case).

When a push notification is sent to a device that has disabled push
notifications, this will not count as a bounce.

The bounce reporting on the campaign metrics page will also include app
uninstalls that occurred after the campaign was sent. Iterable measures this
by sending a "ghost push" after the actual campaign.

On the user profile view, you will be able to see bounce and uninstall events
as two different events.

## Delivery

The total pushes delivered is the total pushes sent minus the total pushes
bounced. Therefore, the push delivery rate is (total pushes sent - total
pushes bounced)/(total pushes sent).

## Open

When a user clicks on a push notification, Iterable's mobile SDKs automatically
track a push open event. If you're not using Iterable's mobile SDKs, you can
manually track a push open event by calling [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen).

## Uninstall

Iterable will track uninstalls with no additional work by you. 

Uninstalls only happen when we get a bounce, so if a recipient has merely
disabled notifications from their device settings, push messages will be
received successfully by the device, but will not be displayed to the
recipient.

To track uninstalls, Iterable sends a silent push notification, or "ghost"
push, some time (currently, 12 hours) after a campaign has been sent. Based
on this silent push notification, if Iterable receives feedback that the
device token is no longer valid, it assigns an uninstall to the device
attributed to the prior campaign.

Similarly, if a "real" push campaign uncovers an invalid device token, it
will also check for a prior campaign, within the last 12 hours, to attribute
that previous campaign as the cause for the uninstall. If there was no recent
campaign, Iterable still tracks the uninstall, but does not attribute it to
any campaign.

## Unsubscribe

Since a push does not require an opt-out directly in the message like an
email would, we allow each company to define the events that would constitute
a push unsubscribe and send the event directly through Iterable's
[`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions) 
API.

When the unsubscribe event is sent, the body of the call should include the
`email` of the contact, the `campaignId`, and either the `channelId` or
`messageTypeId` (depending on how unsubscribes are managed in your Iterable
account). If you are setting up your Iterable account, read
[Message Channels and Types Best Practices](https://support.iterable.com/hc/articles/205117329).

