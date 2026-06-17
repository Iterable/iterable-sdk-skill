---
slug: push-notification-overview
feature: push-notifications
archetype: feature
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Push Notification Overview
source_url: https://support.iterable.com/hc/articles/360035079872
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/push-notifications/push-notification-overview/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 3306f88835e0c1b30e4b4020287d772cfd93ba1e
fetched_at: 2026-05-25T15:11:44.170Z
polished_at: 2026-06-05T13:59:18.315Z
layer: a
snippets: []
summary: To alert users about updates, offers, content, and other information
  that may be immediately relevant, it often makes sense to contact them on
  their mobile devices. Iterable can send push notification campaigns to your
  users, allowing you reach them when and where it matters.
---
# Push Notification Overview

To alert users about updates, offers, content, and other information that may be
immediately relevant, it often makes sense to contact them on their mobile
devices. Iterable can send push notification campaigns to your users, allowing
you reach them when and where it matters.

You can also use Iterable to send silent push notifications, which wake your app
in the background to perform a task — update a badge count, download some data,
or trigger a request for an app store review. When you send a silent push
notification, you'll define a JSON payload to send along with it, and your app's
code can use this data as needed.

## Iterable's mobile SDKs

To make it easy to work with push notification campaigns sent from Iterable,
consider using Iterable's mobile SDKs:

- [iOS SDK](https://support.iterable.com/hc/articles/360035018152), 
- [Android SDK](https://support.iterable.com/hc/articles/360035019712), 
- [React Native SDK](https://support.iterable.com/hc/articles/360045714132)  

These SDKs help with:

- Capturing device tokens and sending them to Iterable.
- Handling rich push notifications, which contain images and action buttons.
- Deep link handling.
- Capturing events (when push notifications are delivered, when users click
  on them, etc.).

## Next steps

If you're a marketer, work with your mobile engineers to implement the
technical setup described in [Setting up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806)
and [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943).

Then, read [Sending Push Notifications](https://support.iterable.com/hc/articles/115000379086) 
to learn how to send a push notification campaign.
