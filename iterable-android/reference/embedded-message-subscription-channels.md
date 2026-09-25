---
slug: embedded-message-subscription-channels
feature: embedded-messaging
archetype: prerequisite
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Adding an Embedded Message Subscription Channel and Type to Your Iterable
  Project
source_url: https://support.iterable.com/hc/articles/23060629030548
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/embedded-messaging/embedded-messaging-subscription-channels-and-types/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: b4ece97017a56433619bad04118c3532f518cca3
fetched_at: 2026-09-17T15:31:50.077Z
summary: Before creating embedded messages templates and campaigns in Iterable,
  you'll need to add an embedded messaging subscription channel with an opt-out
  message type to your Iterable project.
---
# Adding an Embedded Message Subscription Channel and Type to Your Iterable Project

> [!NOTE]
> To add Embedded Messaging to your Iterable account, talk to your customer success 
> manager.

Before creating embedded messages templates and campaigns in Iterable, you'll
need to add an embedded messaging subscription channel with an opt-out message
type to your Iterable project.

Subscription channels and message types do not affect embedded message
eligibility, but they may in the future. For now, the existence of an embedded
message channel and associated opt-out message type is simply a prerequisite for
creating embedded message templates and campaigns.

## Permissions

To work with subscription channels and message types in Iterable, you'll need 
various [permissions](https://support.iterable.com/hc/articles/205480335):

|Action|Required permission|
|------|-------------------|
|Create embedded message subscription channels and message types|[_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project)|

## Creating an embedded message subscription channel and type

![An embedded message subscription channel](https://support.iterable.com/hc/article_attachments/23358128098708/embedded-message-subscription-channels-and-types.png "An embedded message subscription channel")

To create an embedded message subscription channel and type:

1. Navigate to **Settings > Message Channels and Types**.

2. In the left sidebar, select **Embedded**.

3. Click **New Subscription Channel**.

4. In the **New Embedded Channel** window that appears, provide a **Name** and
   choose **Marketing** or **Transactional**.

If your new channel doesn't automatically receive an associated opt-out message
type (check by clicking the message types dropdown menu that appears with the
subscription channel), create one:

1. For your new subscription channel, click **New Message Type**.

2. Give it a **Name**.

3. Select **Opt-Out**.

4. Click **Create Message Type**.

## Next steps

Now that you've configured the subscription channel(s) and type(s) for your 
embedded messages, you'll need to decide where embedded messages should appear 
in your app. To learn how to do this, see [Defining Placements for Embedded Messages](https://support.iterable.com/hc/articles/23060983437076).