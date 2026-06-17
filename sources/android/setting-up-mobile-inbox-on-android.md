---
url: https://support.iterable.com/hc/articles/360038744152
title: Setting up Mobile Inbox on Android
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/setting-up-mobile-inbox-on-android/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 968c6cc97c2aec2e8e4124b5ef18aa9a000a139d
fetched_at: 2026-05-25T15:11:41.984Z
---
# Setting up Mobile Inbox on Android

Apps using version 3.2.0 and later of Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)
can save in-app messages to an inbox. This inbox displays a list of saved in-app
messages and allows users to read them at their convenience. The SDK provides a
default user interface for the inbox, which can be customized to match your
brand's styles. This document describes how Android developers can add Iterable's
Mobile Inbox functionality to your mobile app.

To learn how to use Iterable to send in-app messages that users can save to a
mobile inbox, read [Sending In-App Messages](https://support.iterable.com/hc/articles/360034903151).

:::warning IMPORTANT
Versions 3.2.0 and higher of Iterable's Android SDK depend on the
[AndroidX](https://developer.android.com/jetpack/androidx) support libraries.
[Migrate your app to use AndroidX](https://developer.android.com/jetpack/androidx/migrate)
before using version 3.2.0 or higher.
:::

## In this article

[[toc]]

## Installing Iterable's Android SDK

To add a mobile inbox to your Android app, first install Iterable's
[Android SDK](https://support.iterable.com/hc/articles/360035019712).

## Displaying the mobile inbox

In your app, show the mobile inbox when the user selects a specific tab or taps
a particular button.

- To show the inbox as a tab: 

    When using a [Navigation](https://developer.android.com/guide/navigation)
    component, add the `IterableInboxFragment` to the navigation graph XML:

    ```xml
    <fragment
        android:id="@+id/inboxFragment"
        android:name="com.iterable.iterableapi.ui.inbox.IterableInboxFragment"
        android:label="Inbox"
        tools:layout="@layout/iterable_inbox_fragment" />
    ```

- To show the inbox as a separate activity in response to a button tap:

    Use the provided `InboxActivity` wrapper:

    Kotlin:

    ```kotlin
    startActivity(Intent(context, IterableInboxActivity::class.java))
    ```

    Java:

    ```java
    startActivity(new Intent(getContext(), IterableInboxActivity.class));
    ```

## Syncing a mobile inbox across many devices

Iterable's iOS and Android SDKs automatically sync a mobile inbox across all the
devices on which a user has logged in to your app. Additionally, they sync the
read state for each message.

If you're not using one of Iterable's mobile SDKs:

- To determine whether or not a message has been read, examine its `read` field,
  as returned by [`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages).
- To mark a message as read, call [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen).

:::tip NOTE
For more information about cross-device read state syncing, see:
- Iterable's Android SDK, [v3.2.12 release notes](https://support.iterable.com/hc/articles/360027543332#_3-2-12)
- Iterable's iOS SDK, [v6.2.21 release notes](https://support.iterable.com/hc/articles/360027798391#_6-2-21)
:::

## Customizing the mobile inbox

To learn how to customize the mobile inbox in an Android app, read 
[Customizing Mobile Inbox on Android](https://support.iterable.com/hc/articles/360039091471).

## Further reading

User guides:
- [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406)
- [Sending In-App Messages](https://support.iterable.com/hc/articles/360034903151)
- [Events for In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/360038939972)

Developer documentation:
- Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152)
- Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)
- [In-App Messages Overview](https://support.iterable.com/hc/articles/360035538391)
- [In-App Messages on iOS](https://support.iterable.com/hc/articles/360035536791)
- [In-App Messages on Android](https://support.iterable.com/hc/articles/360035537231)
- [Setting up Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039137271)
- [Customizing Mobile Inbox on iOS](https://support.iterable.com/hc/articles/360039091471)
- [Customizing Mobile Inbox on Android](https://support.iterable.com/hc/articles/360039189931)
- [Animating In-App Messages with CSS](https://support.iterable.com/hc/articles/360035539271)
- [Image Carousels in In-App Messages](https://support.iterable.com/hc/articles/360035171132)
- [Testing and Troubleshooting In-App Messages](https://support.iterable.com/hc/articles/360035623391)
- [In-App Messages Without the SDK](https://support.iterable.com/hc/articles/360018709631)
- [Getting Started with Iterable's API](https://support.iterable.com/hc/articles/41044692130196)
- [API Endpoints and Sample Payloads](https://support.iterable.com/hc/articles/204780579)
