---
slug: sending-in-app-messages
feature: in-app-messages
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Sending In-App Messages
source_url: https://support.iterable.com/hc/articles/360034903151
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/in-app/sending-in-app-messages/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 6c5d21ae12a12b688e26b18540a8bebb72f04c62
fetched_at: 2026-10-06T10:32:47.156Z
summary: This document describes how to use Iterable to send in-app messages,
  which are messages that appear to a user in a mobile app or on a website (when
  sent to a website, they're called _in-browser messages_). In-app messages can
  optionally make use of a mobile inbox, if you've enabled one in your app.
---
# Sending In-App Messages

This document describes how to use Iterable to send in-app messages, which are
messages that appear to a user in a mobile app or on a website (when sent to
a website, they're called _in-browser messages_). In-app messages can optionally
make use of a mobile inbox, if you've enabled one in your app.

> [!NOTE]
> To learn more about in-app messages and Iterable's Mobile Inbox feature,
> read [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406).

## Setting up your mobile apps and websites to display in-app messages

To configure your mobile apps and websites to receive and display in-app
messages, first have your mobile engineers add Iterable's mobile SDKs (iOS,
Android, React Native, or web) to your apps and websites, and configure them to
receive push notifications (since Iterable uses silent push notifications to
tell apps when there are new in-app messages to display). For more information,
read:

- [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152)
- [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712)
- [Overview of Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714072)
- [Setting up Iterable's Web SDK](https://support.iterable.com/hc/articles/4419628585364)

> [!NOTE]
> Apps and websites can receive in-app messages [without the SDKs](https://support.iterable.com/hc/articles/360018709631),
> but using them simplifies the implementation.

## Configuring your apps to include Mobile Inbox

To add a mobile inbox to your mobile app, have your mobile engineers follow the 
instructions in [Setting up Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039137271) 
and [Setting up Mobile Inbox on Android](https://support.iterable.com/hc/articles/360038744152).
These SDKs provide a default mobile inbox UI that can be customized and stylized
as necessary.

Iterable's web SDK does not provide a mobile inbox implementation.

## Sending in-app message campaigns

To learn how to send in-app message campaigns, read:

- [Sending or Scheduling a Blast Campaign](https://support.iterable.com/hc/articles/14761834767508) and [Activating a Triggered Campaign](https://support.iterable.com/hc/articles/16765114424212)

## Sending in-app messages from journeys

To learn how to send in-app messages from journeys, read:

- [Journeys Overview](https://support.iterable.com/hc/articles/4405798856212)
- [Parts of a Journey](https://support.iterable.com/hc/articles/4411913074964)

## Events 

To learn about in-app message and Mobile Inbox-related events captured by 
Iterable, read [Events for In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/360038939972)
