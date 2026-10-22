---
slug: user-profile-fields-used-by-iterable
feature: user-profiles
archetype: identity
sdk_min_version: 3.2.1
sdk_artifact: "@iterable/react-native-sdk"
title: User Profile Fields Used by Iterable
source_url: https://support.iterable.com/hc/articles/217744303
source_repo: Iterable/iterable-docs
source_path: docs/audience-management/users-and-user-profiles/user-profile-fields-used-by-iterable/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: 51d92087789bba35ac0db9c47d2a9e9c3c7bdfd8
fetched_at: 2026-10-22T10:00:21.283Z
summary: User profiles in Iterable contain various fields that Iterable uses for
  specific purposes. This document describes these fields and their meanings.
---
# User Profile Fields Used by Iterable

User profiles in Iterable contain various fields that Iterable uses for specific 
purposes. This document describes these fields and their meanings.

> [!NOTE]
> The character limit for user profile fields is approximately 32k characters. 
> All user profile fields are case-sensitive and space-sensitive.

## Fields used as unique identifiers

Each user in an Iterable project must have a unique identifier. Two fields are
available in Iterable to uniquely identify users: `email` and `userId`. When you
create your project, you will choose a _project type_. The project type
determines which field(s) you can use to identify your users. It also impacts
how you manage records in Iterable. 

For more information, see [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796). For information about how these fields are used with 
Iterable’s APIs, see [Creating and Identifying Users with Iterable APIs](https://support.iterable.com/hc/articles/29156459027348).

### Identifying users by `email`

Iterable uses the [`email`](#email) field as a unique identifier for users in 
hybrid and email-based projects. To learn more about the `email` field and 
accepted values, see [Email Validation in Iterable](https://support.iterable.com/hc/articles/209082806).

In hybrid and email-based projects, each user's `email` **must be unique**. 

In userID-based projects, `email` uniqueness is not enforced and there may 
be multiple users with the same `email` address.

### Identifying users by `userId`

The [`userId`](#userid) field stores a unique value that you've assigned to 
identify each user. To learn more about the `userId` field and accepted values, 
see [UserID Validation in Iterable](https://support.iterable.com/hc/articles/41111923969556).

In userID-based and hybrid projects, each user's `userId` **must be unique**.

In email-based projects, unique values for `userId` are not required or 
enforced. In the event the same `userId` is associated with multiple users, 
there are some important considerations. To learn more, read 
[Identifying users by `userId` in email-based projects](https://support.iterable.com/hc/articles/29156459027348#email-based-projects).

## Fields managed by Iterable

Iterable manages the fields described below. These fields are visible in the
responses to various API calls, but (unless otherwise noted) they should not
be included in calls to [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update) 
or other endpoints that update user profiles.

### `emailListIds`

An array of integers that represent the static lists of which a user is a 
member. The values in this array change as the user is added to or removed
from lists.

This array does not contain IDs for dynamic lists.

This field applies to email-based projects only. For userId and hybrid 
projects, Iterable uses [`userListIds`](#userlistids).

### `itblInternal`

A collection of various fields managed by Iterable.

### `itblInternal.phoneCountry`

A two-letter code that represents the country associated with the user's 
[`phoneNumber`](#phonenumber), as defined by [ISO-3166](https://www.iso.org/iso-3166-country-codes.html). 

When you send an SMS campaign to a user, Iterable checks to see if the user has
`itblInternal.phoneCountry` set. If it isn't set, Iterable uses `phoneNumber` 
to look up the ISO-3166 country code, and adds that country code to the user's 
profile.

Currently, this field is only used for reporting purposes, and is not used to 
determine a user's language or system actions related to a user's country.

> [!TIP]
>
> There are a couple of ways to measure SMS success by country:
>
> - [Campaign Analytics](https://support.iterable.com/hc/articles/218203223#segment-analysis) — 
>   Create a segment analysis using `itblInternal.phoneCountry`.
> - [Messaging Insights](https://support.iterable.com/hc/articles/360052814452) -
>   In the **Audience** view, select the `itblInternal.phoneCountry` segment.

### `itblInternal.phoneType`

Iterable also stores the user's phone type in the `itblInternal.phoneType` field,
which is a string that represents the type of phone number the user has.

This is an informational field that you may find useful when reviewing your user 
profiles or creating segments. For example, some number types can be blocked from
receiving SMS messages, which is helpful when determining the size of your SMS-ready
audience.

This field may have one of the following values:
- `MOBILE` - Mobile phone number
- `FIXED_LINE` - Fixed line phone number
- `FIXED_LINE_OR_MOBILE` - Fixed line or mobile phone number
- `TOLL_FREE` - Toll-free number
- `PREMIUM_RATE` - Premium rate number
- `SHARED_COST` - Shared cost number
- `VOIP` - Voice over IP number
- `PERSONAL_NUMBER` - Personal number
- `PAGER` - Pager number

### `itblDS`

An object containing information related to [Iterable AI](https://support.iterable.com/hc/articles/360052990091). 
Its `brandAffinityLabel` field represents the contact's level of engagement
with your brand, as determined by [Brand Affinity™](https://support.iterable.com/hc/articles/360052990191).
Its `predictiveGoals` field provides user conversion scores for goals that are
created in Iterable's [Predictive Goals](https://support.iterable.com/hc/articles/5026416447636#view-a-user-s-conversion-scores).

### `itblUserId`

A unique identifier used internally by Iterable for hybrid and userID-based 
projects. Using this field to reference a user is NOT recommended. Instead, use 
[`userId`](#userid), which is a field that you can access and manage.

### `knownLitigatorFilter`

A string that represents the confidence level of the user's known litigator status.
The possible values are `LT1`, `LT2`, and `LT3`. The `LT1` value denotes high
confidence that the phone number has been involved in TCPA litigation, while the
value `LT2` denotes a lower confidence level. If a user is detected as both LT1
and LT2, the field will be updated to `LT3`.

### `profileUpdatedAt`

The most recent time at which a user's profile was updated (via CSV upload or 
API call). This field is a date, and it has the following format:
`2016-08-02 18:53:45 +00:00`. For more information, read
[Field Data Types](https://support.iterable.com/hc/articles/208183076).

> [!NOTE]
> Previously, Iterable would process user update requests that didn't actually 
> change the user's profile data. This resulted in an update to the 
> `profileUpdatedAt` field even though the user profile hadn't actually changed. 
> As of February 2023, `profileUpdatedAt` is no longer modified when user profile 
> data has not changed. To learn more about this change, see
> [2023 Release Notes](https://support.iterable.com/hc/articles/11667879575572#february-2023).
>
> In the rare case you need the original behavior, talk to your customer success 
> manager.

### `receivedSMSDisclaimer`

Indicates whether or not the user has received an SMS message, from the current
Iterable project, that includes SMS opt-out instructions. Receiving opt-out
instructions in a proof will not set this field to `true`.

### `signupDate`

The date when the user's profile was created in Iterable.  This field is a date, and
it has the following format: `2016-08-02 18:53:45 +00:00`.  For more information,
read [Field Data Types](https://support.iterable.com/hc/articles/208183076).

### `signupSource`

How the contact was created in Iterable (for example, `API` or `IMPORT`).

### `subscribedMessageTypeIds`

An array of integers that represent the opt-in message types to which a contact has
subscribed. Contacts will receive messages associated with opt-in message types only
if both of the following are true:

- They have subscribed to those opt-in message types 
- They have not unsubscribed from the channels associated with those types

> [!WARNING]
> `subscribedMessageTypeIds` is available only for accounts or projects for which 
> [opt-in message types](https://support.iterable.com/hc/articles/204780529) have 
> been enabled. To do so, contact your Iterable customer success manager.

### `unsubscribedChannelIds`

An array of integers that represent the message channels from which a user has
unsubscribed.  Users will not receive messages from any message type belonging to a
message channel from which they have unsubscribed.

### `unsubscribedMessageTypeIds`

An array of integers that represent the opt-out message types from which a user has
unsubscribed.

Users will receive messages from opt-out message types only if both of the following
are true:

- They have not unsubscribed from those opt-out message types
- They have not unsubscribed from the channels associated with those types

### `userListIds`

An array of integers that represent the static lists of which a user is a 
member. The values in this array change as the user is added to or removed
from lists.

This array does not contain IDs for dynamic lists.

This field applies to userId and hybrid projects. For email-based projects, 
Iterable uses [`emailListIds`](#emaillistids).

## Fields used for sending messages

When sending messages, Iterable relies on the fields described below. 

> [!WARNING]
> The specific names of these fields are important. For example, Iterable uses the
> `phoneNumber` field when sending SMS messages; it won't recognize `phone_number`
> or `PhoneNumber`.

### `country`

The user's country.

**Accepted values** - Any string value. This field has a string data type and 
is not validated. When you add this data to Iterable, you can enter any value 
your company uses to represent a user's country.

Alternatively, you can set up your project so that Iterable automatically looks 
up the country based on the user's IP address. When Iterable stores the 
`country` field, it uses the English-language name of the country, as found in 
the [GeoNames database](https://www.geonames.org/countries/).

When using SMS Smart Opt-In, Iterable uses the `country` field to assign a 
number from your SMS senders that matches the user's country. For complete 
detail on how `country` is used to assign a number, see
[SMS Smart Opt-In](https://support.iterable.com/hc/articles/10870034844308#how-sms-smart-opt-in-selects-a-number-for-the-user-to-reply-to).

Iterable can automatically populate the `country` field based on the user's IP 
address. This lookup is triggered whenever the `ip` field is updated on the 
user profile.

To learn more about updating a user's IP and/or geolocation fields using 
inbound data, read [Automatically populating IP and geolocation fields](#automatically-populating-ip-and-geolocation-fields) below.

### `devices`

A nested data type that contains an array of objects, each representing a 
mobile device/mobile app combination for which a user can (or used to be able 
to) receive push notifications (silently or otherwise).

Each object in the `devices` array contains the following fields:

- `applicationName` - A string that identifies the mobile app for which the user 
  can receive push notifications.

- `appPackageName` - The unique application identifier associated with your app
  (as specified by its developers). Different for iOS and Android.

- `appVersion` - The version of your app running on the user's device. 

- `deviceId` - A randomly generated UUID for a user's device. Generated by Iterable
   and stored in local storage on the device, and in Iterable itself. When the 
   user re-installs the app, a new one is created (we don't track a device across
   app reinstalls).

- `endpointEnabled` - Indicates whether or not Iterable can send push notifications
  to this device. If a user prevents an app from displaying push notifications, 
  but after the app has already registered its device token with Iterable, the 
  app's code should disable the device in Iterable by calling [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice). 
  This sets `endpointEnabled` to `false` for this device, preventing Iterable from
  sending future push campaigns to it. If the app does not disable the device,
  Iterable will continue to send push campaigns to it. The user will never see those
  campaigns, but they'll still be counted in the campaign's total send count.
  To check if Iterable can send push notifications to a given device/app
  combination, check its `endpointEnabled` field. If `true`, Iterable can send push
  notifications to that device.

- `identifierForVendor` - iOS only. An alphanumeric string that uniquely identifies a
   device to the app’s vendor. Unique to that device for that app developer.

- `iterableSdkVersion` - The release version of the SDK. Numbers will differ
   by platform (iOS, Android, React Native), correspond with the release numbers 
   on our Github pages ([iOS](https://github.com/Iterable/iterable-swift-sdk/releases),
   [Android](https://github.com/Iterable/iterable-android-sdk/tags), 
   [React Native](https://github.com/Iterable/react-native-sdk/releases)).

- `localizedModel` - iOS only. the model of the device. For example: "iPhone", 
   "iPad", "iPod Touch".

-  `model` - The model name of the device. Apple examples: "iPhone", "iPad", "iPod Touch". 
   Android example - "sdk_gphone_x86_arm".

- `notificationsEnabled` - whether or not push notifications are enabled on the
   device.

- `platform` - The platform from which the device can receive push notifications. 
  For example, `APNS_SANDBOX`.

- `platformEndpoint` - The specific address Iterable uses to reach the device
   by push notification.

- `systemVersion`: The version number of the device's operating system.

- `token` - A string Iterable uses to identify the device when sending it a push 
  notification.

- `userInterfaceIdiom`: iOS only. The device's category. For example: "Phone", 
  "Pad", "carPlay".

> [!TIP]
> **TIPS**
>
> - To add a device to this list (or re-enable one that is already there), call 
>   [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken).
> - To disable a device on the list, so that it will no longer receive messages, call 
>   [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice).

### `email`

A user's email address.

- This field is validated. To learn more, see [Email Validation in Iterable](https://support.iterable.com/hc/articles/209082806).

- Iterable uses this field to send email campaigns to users.

  - An exception to this is anonymous users with `@placeholder.email`. These users 
    have placeholders in order to identify the user in Iterable, but their `email` 
    is not a valid recipient address. Email campaigns sent to `@placeholder.email`
    addresses are skipped. (Send skip events are not logged for this scenario.) See
    [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956)
    to learn more about placeholder emails.

- `email` is one of two possible fields that uniquely identify Iterable users,
  along with [`userId`](#userid). To continue learning about the `email` field,
  unique identifiers, and how they work, read
  [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

### `ip`

The user's IP address.

Iterable can automatically update the `ip` field based on the IP address 
contained in inbound email click (`emailClick`) and/or SMS click (`smsClick`) 
events. This ensures that the `ip` field is refreshed regularly for your most 
engaged users. To learn more, read [Automatically populating IP and geolocation fields](#automatically-populating-ip-and-geolocation-fields) below.

### `locale`

A user's location and/or language preference. If you have multiple locale 
variants of a template (all with the same `templateId`), Iterable uses this 
field to determine which version to send to the user.

This field maps to the codes you set up in the [Locales](https://support.iterable.com/hc/articles/12441621049876) 
section of your Project Settings page.

### `phoneNumber`

A string that represents the user's phone number. Iterable uses this number when
sending SMS messages.

Values must be formatted using [E.164](https://en.wikipedia.org/wiki/E.164).
For example:

- US: `+14155550132`
- Germany: `+498999998000`

When you send an SMS to the user, Iterable checks to see if the user has
[`itblInternal.phoneCountry`](#itblinternal-phonecountry) set. If it doesn't,
Iterable uses `phoneNumber` to look up the country code and add it to the user's
profile.

Iterable doesn't send SMS campaigns to users without a `phoneNumber` set. 

> [!WARNING]
> When updating a `phoneNumber`, if you don't include a country code, Iterable
> automatically adds `+1` (the country code for USA, Canada, and parts of the 
> Caribbean) to the front of the number.
>
> For example, if you try to update a user's number to `4155550132`, Iterable 
> saves it in the user's profile as `+14155550132`.

### `profile`

:::v-pre
A hidden field housing all of a user profile data. Fields at the root level on 
the user profile can be referenced via merge tags by writing either
`{{firstName}}` or `{{profile.firstName}}`.
:::
To avoid confusion, do not use `profile` as a field name in your user profiles.

### `timeZone`

The user's time zone, which Iterable uses for the following features:

- [Send Time Optimization](https://support.iterable.com/hc/articles/360050923471)
- [Quiet Hours](https://support.iterable.com/hc/articles/16928857601940)
- [Sending in Different Time Zones](https://support.iterable.com/hc/articles/14761834767508#sending-in-different-time-zones)

Values are case-sensitive and must be precisely formatted, as described by the 
[IANA time zone database](https://en.wikipedia.org/wiki/List_of_tz_database_time_zones).

Examples:

  - `America/Los_Angeles`
  - `Europe/London`
  - `Asia/Tokyo`

You can set values in the `timeZone` field by uploading your own data to the 
user profile using any data import method (such as API, CSV, or Smart Ingest), 
or by enabling project settings so Iterable can automatically update the 
`timeZone` field.

Iterable provides project settings that capture each user's IP address, and 
look up the user's time zone based on their IP address. This ensures that the 
`timeZone` field is refreshed regularly for your most engaged users.

To learn more about updating a user's IP and/or geolocation fields using
email or SMS click events, or to learn how to set up your project so that 
Iterable can automatically update the `timeZone` field, see [Automatically populating IP and geolocation fields](#automatically-populating-ip-and-geolocation-fields) below.

### `userId`

The ID of a user. This is always a value which you've either assigned or
imported from another source. To learn more about the `userId` field and 
accepted values, see [UserID Validation in Iterable](https://support.iterable.com/hc/articles/41111923969556).

> [!NOTE]
> This is one of two possible fields that uniquely identify Iterable users,
> along with [`email`](#email). To continue learning about the `userId` field,
> unique identifiers, and how they work, see our guide 
> [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

### `whatsAppPhoneNumber`

A string that represents the user's WhatsApp phone number. Iterable uses this number when
sending WhatsApp messages.

Values must be formatted using [E.164](https://en.wikipedia.org/wiki/E.164).
For example:
- US: `+14155550132`
- Germany: `+498999998000`

## Automatically populating IP and geolocation fields

If enabled for your project, Iterable can automatically populate the following 
geolocation fields: `ip`, `city`, `region`, `country`, and `timeZone`. This is 
helpful for campaigns that use [Quiet Hours](https://support.iterable.com/hc/articles/16928857601940)
and [send in different time zones](https://support.iterable.com/hc/articles/14761834767508#sending-in-different-time-zones),
as Iterable can use the user's IP address to infer their time zone and send 
messages at the most appropriate time. IP lookup is skipped when the event's
`userAgent` contains "GoogleImageProxy" (for example, when a user opens an email
from Gmail).

To have Iterable automatically update user fields based on their IP geolocation:

1. Set up click tracking for your email and/or SMS campaigns:
   - [Email link tracking](https://support.iterable.com/hc/articles/7130133854612#step-3-set-up-tracking-domains)
     must be enabled to capture the user's IP address on email click events.
   - [SMS shortlinks](https://support.iterable.com/hc/articles/4403865896724)
     must be enabled to capture the user's IP address on SMS click events.

2. Update the user's `ip` field with the [**Overwrite IP Field**](https://support.iterable.com/hc/articles/206382645#overwrite-ip-field)
   project setting. This automatically captures a user's IP address each time 
   they click a link in an email and/or SMS campaign.
 
3. Turn on the [**Overwrite Location Fields**](https://support.iterable.com/hc/articles/206382645#overwrite-location-fields)
   project setting to update the `city`, `region`, `country`, and `timeZone` 
   fields based on the user's IP address, every time the `ip` field is updated.

## Other reserved field names

The following field names are reserved by Iterable, and you can't manually set
them:

- `campaignId`
- `channelId`
- `eventName`
- `messageTypeId`
- `templateId`
- `total`

Also avoid using `size` as a field name. You can do it, but referencing 
such a field can be unreliable, since it sometimes references the 
[number of items in an object or array](https://support.iterable.com/hc/articles/36531450481300#display-the-size-of-an-array).

## Common event fields

You'll often see the following fields on Iterable system events:

- `messageId`: A unique identifier for a particular send of a particular campaign 
  to a particular user.
- `contentId`: An ID associated with the specific template revision sent to the 
  user for a campaign.
- `catalogLookupCount`: The number of times a catalog was referenced in the message.
- `catalogCollectionCount`: The number of times a catalog collection was referenced
  in the message.

## Want to learn more?

For more information about some of the topics in this article, check out this
Iterable Academy course. Iterable Academy is open to everyone — you don't need
to be an Iterable customer!

- [Foundations: Setting Up Senders](https://academy.iterable.com/setting-up-senders)