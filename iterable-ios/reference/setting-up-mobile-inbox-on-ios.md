---
slug: setting-up-mobile-inbox-on-ios
feature: mobile-inbox
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Setting up Mobile Inbox on iOS
source_url: https://support.iterable.com/hc/articles/360039137271
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/setting-up-mobile-inbox-on-ios/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 730cbeb72d54e46983fded591bfb6a19db7b80a0
fetched_at: 2026-10-02T13:52:10.755Z
summary: Apps using version 6.2.0 and later of Iterable's [iOS
  SDK](https://support.iterable.com/hc/articles/360035018152) can save in-app
  messages to an inbox. This inbox displays a list of saved in-app messages and
  allows users to read them at their convenience. The SDK provides a default
  user interface for the inbox, which can be customized to match your brand's
  styles. This document describes how iOS…
---
# Setting up Mobile Inbox on iOS

Apps using version 6.2.0 and later of Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152)
can save in-app messages to an inbox. This inbox displays a list of saved in-app
messages and allows users to read them at their convenience. The SDK provides a
default user interface for the inbox, which can be customized to match your
brand's styles. This document describes how iOS developers can add Iterable's
Mobile Inbox functionality to your mobile app.

To learn how to use Iterable to send in-app messages that can be saved to a 
mobile inbox, read [Sending In-App Messages](https://support.iterable.com/hc/articles/360034903151).

## Installing Iterable's iOS SDK

To add a mobile inbox to your iOS app, first install 
Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152).

## Displaying the mobile inbox

To display the mobile inbox in your app, use one of two classes included in 
Iterable's iOS SDK:

- `IterableInboxNavigationViewController` 
- `IterableInboxViewController`

> [!NOTE]
> It's generally best to use `IterableInboxNavigationViewController`, since
> it has a built-in navigation controller.

There are two primary ways to display this view controller:

1. As a tab on a `UITTabBarController`

	To display the mobile inbox in this way, configure a tab to load an
	`IterableInboxNavigationViewController` (either in code or with a storyboard). 

	When using this approach, the tab representing the mobile inbox
	automatically shows a badge count for unread messages.

2. In response to a user interaction

	To instantiate and display a mobile inbox in response to user
	interaction, use code similar to the following:

	```swift
	let viewController = IterableInboxNavigationViewController()
	present(viewController, animated: true)
	```

## Syncing a mobile inbox across many devices

Iterable's iOS and Android SDKs automatically sync a mobile inbox across all the
devices on which a user has logged in to your app. Additionally, they sync the
read state for each message.

If you're not using one of Iterable's mobile SDKs:

- To determine whether or not a message has been read, examine its `read` field,
  as returned by [`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages).
- To mark a message as read, call [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen).

> [!NOTE]
> For more information about cross-device read state syncing, see:
> - Iterable's Android SDK, [v3.2.12 release notes](https://support.iterable.com/hc/articles/360027543332#_3-2-12)
> - Iterable's iOS SDK, [v6.2.21 release notes](https://support.iterable.com/hc/articles/360027798391#_6-2-21)

## Customizing the mobile inbox

To learn how to customize a mobile inbox for your iOS app, read 
[Customizing Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039091471).
