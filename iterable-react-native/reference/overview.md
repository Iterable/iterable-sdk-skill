---
slug: overview
feature: integration
archetype: integration
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Overview of Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/360045714072
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/overview/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: e8d2268f9774c59a5afee18ad77a5b20aba0a284
fetched_at: 2026-08-28T14:44:26.800Z
summary: Iterable's [React Native
  SDK](https://github.com/iterable/react-native-sdk) helps you integrate
  Iterable into iOS and Android applications built with [React
  Native](https://reactnative.dev). It allows you to work with push
  notifications, in-app messages, embedded messages, user data, events and
  subscription preferences—all without making manual calls to Iterable's API.
---
# Overview of Iterable's React Native SDK

Iterable's [React Native SDK](https://github.com/iterable/react-native-sdk) helps
you integrate Iterable into iOS and Android applications built with 
[React Native](https://reactnative.dev). It allows you to work with push
notifications, in-app messages, embedded messages, user data, events and subscription
preferences—all without making manual calls to Iterable's API.

The SDK wraps Iterable's native iOS and Android SDKs, and it can be used in both
JavaScript and TypeScript-based React Native projects.

All of Iterable's mobile SDKs are open source. To see the code, take a look at
the following GitHub repositories:

- Iterable's [React Native SDK](https://github.com/iterable/react-native-sdk)
- Iterable's [iOS SDK](https://github.com/Iterable/iterable-swift-sdk)
- Iterable's [Android SDK](https://github.com/Iterable/iterable-android-sdk)

To learn how to use Iterable's React Native SDK, read these articles:

## [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132)

This article describes how to install and initialize Iterable's React Native 
SDK in existing React Native-based iOS and Android apps. 

## [Expo Plugin for Iterable's React Native SDK](https://support.iterable.com/hc/articles/37200225506196)

This article describes how to use Iterable's Expo plugin to integrate the React
Native SDK into Expo-managed applications. Learn how to install and configure
the plugin to enable push notifications, in-app messages, and other Iterable
features in your Expo projects.

## [JWT Authentication with Iterable's React Native SDK](https://support.iterable.com/hc/articles/43901001355412)

This article explains how to implement JWT (JSON Web Token) authentication in
your React Native mobile apps to enhance security and protect your user data.
Learn how to configure authentication handlers, manage token refresh, and
handle authentication errors.

## [Managing User Identity with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714152)

This article discusses how to identify your app's users to Iterable—whether
anonymously by user ID, or with an email address—so that you can then save
data back to their Iterable user profiles.

## [Managing User Profile Data and Subscription Preferences with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134851)

As people use your mobile apps, it's often useful to save information and
actions back to Iterable, and to update their subscription preferences. This
article describes how to do this.

## [Tracking Events with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134891)

This article describes how to use Iterable's React Native SDK to save
information about events (including purchases) back to Iterable from your
mobile apps.

## [Deep Links and Custom Actions with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134911)

This article describes how to use Iterable's React Native SDK to use deep 
links and custom actions to navigate users to specific content in your apps.

## [Push Notifications with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134871)

This article describes how to use Iterable's React Native SDK to display
push notifications and track related events.

## [In-App Messages with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714172)

This article describes how to use Iterable's React Native SDK to display
in-app messages and track related events.

## [Embedded Messages with Iterable's React Native SDK](https://support.iterable.com/hc/articles/49144129810324)

This article describes the steps you'll need to follow to use Iterable's React Native SDK to display [embedded messages](https://support.iterable.com/hc/articles/23060529977364) in your mobile appand track related events.

> [!NOTE]
> To add Embedded Messaging to your Iterable account, talk to your customer success 
> manager.

## [Using a Mobile Inbox with Iterable's React Native SDK](https://support.iterable.com/hc/articles/5422108307604)

This article describes how to set up and customize the [mobile inbox](https://support.iterable.com/hc/articles/217517406) 
implementation provided by Iterable's React Native SDK. 

## [Migrating to Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134931)

If you have an existing React Native-based iOS or Android app that integrates
with Iterable, read this article for some tips on how to migrate to Iterable's
React Native SDK.

## Limitations

### API Call Failures

Iterable's React Native SDK does not surface API call failures to JavaScript or
TypeScript code.
