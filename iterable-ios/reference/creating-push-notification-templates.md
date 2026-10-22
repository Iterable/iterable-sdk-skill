---
slug: creating-push-notification-templates
feature: push-notifications
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Creating Push Notification Templates
source_url: https://support.iterable.com/hc/articles/360044425971
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/push-notification/creating-push-notification-templates/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: af5fc6f952b211c941dfa386077e538bda7c2e0f
fetched_at: 2026-10-06T10:32:44.160Z
summary: "[Push
  Notification](https://support.iterable.com/hc/articles/360035079872) templates
  are reusable message blueprints that you can send in campaigns and journeys to
  your users as mobile push notifications. Push notifications can contain text,
  links, and images, and you can customize them with user profile data, event
  data, data feeds, and Catalog data."
---
# Creating Push Notification Templates

[Push Notification](https://support.iterable.com/hc/articles/360035079872)
templates are reusable message blueprints that you can send in campaigns and
journeys to your users as mobile push notifications. Push notifications can
contain text, links, and images, and you can customize them with user
profile data, event data, data feeds, and Catalog data.

Additionally, you can use silent push notifications to send data to your app
and trigger a background task, without displaying a message to your user.

![A push notification template](https://support.iterable.com/hc/article_attachments/10030269282452/push-template.png "A push notification template")

> [!TIP]
> Need a refresher on templates or push notifications? Check out these articles:
>
> - [Templates Overview](https://support.iterable.com/hc/articles/205480315)
> - [Sending Push Notifications](https://support.iterable.com/hc/articles/115000379086)

## Permissions

To create and edit templates, you'll need the [_Create and Manage Templates and Creative Library_](https://support.iterable.com/hc/articles/205480335#templates-and-creative-library) 
permission.

## Setting up your mobile apps

To send push notifications, you'll need to:

- Work with your mobile engineers to set up your app to receive and display them.
- Add information about your mobile apps to Iterable, on the **Settings > Apps and websites** 
  page.

For more information, read:

 - [Setting up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806)
 - [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943)

## Creating a push notification template

To create a push notification template you can reuse across many campaigns:

1. Go to **Content > Templates**.

2. Click **New template > Push**.

3. Give your template a name that makes it easy to find when you (or your 
   teammates) set up campaigns or journeys. This field has a 150-character 
   limit.

4. Click **Create template**.

You can also create templates as you're setting up a new campaign, and with 
Iterable's API. For more info, read [Working with Templates](https://support.iterable.com/hc/articles/6532713719572).

## Configuring push notification template details

To update template details such as message type, title, body, media URLs etc.,
open it up and click **Edit details**. As you make changes, the preview updates.
When you're done editing, click **Save** or **Cancel**.

> [!WARNING]
> Do not include leading whitespace characters in template details input fields — doing so 
> can cause send failures. For example:
>
> ✅ <code>hi@fiterable.com</code>  
> ❌ <code>&nbsp;hi@fiterable.com</code>
>
> You can trim unwanted whitespace from snippets and Handlebars expressions using 
> the `~` character. See [Removing Whitespace](https://support.iterable.com/hc/articles/36530857619348#removing-whitespace)
> to learn more.

Here are the settings you can update:

### Message type

The category to associate with your template, which affects who receives
campaigns based on it. For more details, see [Message Channels and Message and Message Types Overview](https://support.iterable.com/hc/articles/204780529).

### Interruption level 

> [!TIP]
> iOS 15+ only

How and when Iterable should alert users about the incoming push notification. 
There are four options:

- **Passive** — Don't alert the user. Deliver the notification silently
  to the Notification Center, without playing a sound/vibration or lighting
  up the screen. Do not override a scheduled delivery (Notification Summary),
  break through a Focus, or override the ring/silent switch.

- **Active (default)** — Alert the user about the push notification, playing a
  sound/vibration and lighting up the screen as allowed by device settings.
  Don't override a scheduled delivery (Notification Summary), break through a
  Focus, or override the ring/silent switch.

- **Time Sensitive** — Alert the user about the push notification, playing a
  sound/vibration and lighting up the screen as allowed by device settings.
  Also, since the message is urgent, override a scheduled delivery
  (Notification Summary) and break through a Focus if needed (unless the user
  has blocked the app from doing so). 
  
  :::warning IMPORTANT
  - Before you can send Time Sensitive notifications, your engineering team must
    add the Time Sensitive Notifications capability to your app in Xcode, and then
    release a new version.
  - Be careful with this option, since users can block your app from sending
    Time Sensitive notifications if they decide you are misusing them. 
  :::

- **Critical** — Highly invasive. Only for urgent messages related to personal
  health and public safety. Play a sound and vibration, regardless of system
  settings and the ringer switch. This option is disabled by default, since it
  requires a special entitlement from Apple. If you need to use it, talk to
  your Iterable customer success manager.

For more information about interruption levels, read the [Notifications](https://developer.apple.com/design/human-interface-guidelines/ios/system-capabilities/notifications)
section of Apple's Human Interface Guidelines.

### Relevance score

> [!TIP]
> iOS 15+ only

Helps iOS determine which of your push notifications to display when featuring
your app in a Notification Summary:

- When iOS features your app in a Notification Summary, it displays the
  push notification (for your app) with the highest relevance score. 

- Otherwise, the relevance score determines how iOS sorts your app's push
  notifications in the non-featured section of the Notification Summary (push
  notifications with higher relevance scores sort to the top).

If you don't select a relevance score, it's equivalent to choosing the lowest
possible relevance score (0.0).

### Badge count

> [!TIP]
> iOS only

:::v-pre
The badge count that the app should show after receiving this push notification.
An exact number can go here, or a Handlebars expression that references a badge
count stored on the user's Iterable profile. For example, `{{badgeCount}}`.
:::

### Wake up

> [!TIP]
> iOS only

Causes the app to wake up in the background to perform a background update on
the push notification's arrival. Turning this off ensures that the user doesn't
wake the application and cause it to ping your system's servers.

### Deliver silently

Causes this template to be sent as a silent push notification. A silent push
notification does not appear to the user. Instead, it delivers JSON data to your
app, so that it can perform a background task. You might use a silent push
notification, for example, to trigger an app store review request, kick off a
download of some data so that it's available when your user opens the app, or to
update your app's badge count (iOS).

When you enable this option:

- Unless you're just updating the badge count, you'll also need to specify some 
  data in the **Raw data (JSON)** field. Iterable sends this data along with the 
  silent push notification, and your app can use it as needed. To update the badge 
  count, custom JSON is unnecessary — just specify a value in the **Badge count** 
  field.

- You'll no longer be able to provide a message title or body, since they would
  never appear to the user.

Some things to know about silent push notifications:

- Silent push notifications can be sent from standalone campaigns or from
  campaigns in a journey.

- There's no particular SDK version requirement for silent push notifications,
  and you can use them without Iterable's SDK.

- Even if a user has disallowed push notifications, you can still send them
  silent push notifications. However, if they're unsubscribed from the message
  channel or type you're using for the campaign, they won't receive it.

- You can also use Iterable's API to create silent push notification templates.

- In your campaign engagement metrics, silent push notifications count as sends.
  However, since users can't interact with them, there won't be a corresponding
  increase in clicks or opens. This means that your open rate may decrease.

> [!TIP]
> For your mobile apps to handle silent push notifications, work with your
> engineering teams to make these updates:
>
> - In iOS apps, handle incoming silent push notifications in 
>   [`application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`](https://developer.apple.com/documentation/uikit/uiapplicationdelegate/1623013-application).
>
> - In your Android apps, handle incoming silent push notifications in 
>   a custom [`FirebaseMessagingService`](https://support.iterable.com/hc/articles/360035019712#step-7-2-handle-firebase-push-messages-and-tokens). 
>   If you're using Iterable's Android SDK, consider doing this by extending 
>   [`IterableFirebaseMessagingService`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/IterableFirebaseMessagingService.java).
>
> If you send a silent push notification to an app that isn't set up receive and 
> use it, nothing happens.

### Title

The title to display above the push notification.

### Body

The content of your push notification.

> [!TIP]
> To generate variations of your text in the **Title** or **Body** field, type
> text as you normally would (minimum, 10 characters), click **Iterate** icon in
> the bottom corner of the text field (pink star), and select from the list or
> click **Try Again**. See [Using Copy Assist](https://support.iterable.com/hc/articles/17172997847572#using-copy-assist).

### Media URL

The URL of an image or video (video is iOS only) to include with your push 
notification. Enter the URL in the Android and iOS fields. HTTPS only.

### Data feeds

Data feeds allow you to fetch user-specific data from external URLs (your own or
third-party) and use it to personalize your messages. For example, a restaurant
chain might use a data feed to fetch information about locations close to the
user, and then highlight them in their messages. To tell the data feed which
user you need information for, you can pass query parameters in the data feed 
URL.

To enable data feeds, check **Data feeds**. Then, select an existing data feed
from the dropdown or click **Add a new data feed**.

For more information about data feeds, related configuration options, and how
to use them, read [Data Feeds Overview](https://support.iterable.com/hc/articles/204795659).

### Open action

The action to take when a user taps the push notification:

- **Open App** — Opens the app associated with the push notification.

- **Open URL** — Passes the specified URL to the URL handler of the associated
  mobile app. This URL can deep link to specific content in the app or point to
  external content to open in a web browser.

- **Custom action** — Passes the specified value to the application's custom 
  action handler (defined in the app's code). Decide in advance with your team's 
  mobile engineers on a list of supported custom actions and what they should do.

### Action buttons

Buttons that sit below push notifications and allow users to take immediate
action. Use them to encourage users to make a purchase, write a review, visit a
website, share content on social media, unsubscribe from a list or take some
other relevant action.

In this example, **Check out now!** is an action button:

![Push action button](https://support.iterable.com/hc/article_attachments/10030262456340/push-action-button.png "Push action button")

To add add an action button, click **Add action button**. Then, configure 
these options:

- **Button name** — The text to display on the button. Click the pencil button
  to edit.

- **Button type**

  - **Normal** — A button with black text.
  
  - **Destructive** — A button with red text.
 
  - **Text input** — A button that displays a text input after being tapped. 
    For this type of button, you can specify **Placeholder** text for the text
    input (appears before the user enters anything else), and the text to use 
    on the button itself.

- **Button action** — Different types of button can be used to do different things:

  - **Open app** — Opens the app associated with the push notification.
    Otherwise, the option is executed in the background. Available for normal
    buttons.

  - **Open URL** — Opens an external URL or a deep link to content within the 
    app. Available for all button t ypes.

  - **Custom action** — Passes the specified value to the application's custom
    action handler (defined in the app's code—decide in advance with your
    team's mobile engineers on a list of supported custom actions and what they
    should do). The **Open app** option nested under **Custom action** causes the 
    app to come to the foreground to execute the action. Leaving it unchecked 
    causes the action to execute in the background. Available for all button
    types.

  - **Track only** — Sends Iterable a track push open event with the associated
    button identifier, without opening the app or redirecting the user. This
    option is useful for buttons that dismiss push notifications. Available for
    desctructive and text input buttons.

> [!NOTE]
> - To include images, videos or action buttons with iOS push notifications, 
>   have your mobile engineers add a Notification Service Extension to your iOS 
>   application. For more information, read about [Advanced iOS Push Notifications](https://support.iterable.com/hc/articles/360035451931).
> - Action buttons do not support Handlebars or snippets.

### Custom sound

The name of the sound file to play when the push notification arrives. For the
sound file to play, your mobile engineers must bundle it in your mobile app.

For more information, read:

- [Setting Up iOS Push Notifications](https://support.iterable.com/hc/articles/115000315806) 
- [Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943).

### Raw data (JSON)

Additional JSON data to send along with the push notification. When the push
notification arrives, this data is available for your apps to process.

This data can be used to trigger custom functionality in your app. For example,
a push notification that congratulates a user on reaching a VIP status of some
sort might also include custom metadata that tells the app about this status.
The app might use this information to change its styling or to unlock additional
functionality.

You can customize raw JSON with Handlebars expressions, which output different
content for different users. To verify that your raw JSON works as expected, click 
**Preview** and scroll to the bottom of the page. As you load data for different
users, this preview updates. For more information, read [Previewing a JSON Payload](https://support.iterable.com/hc/articles/115002807783#previewing-a-json-payload).

### Locales

Use locales to define the content this template use for users in different
locales. This feature doesn't translate for you, but provides a place for you to
put localized content. 

For more information, read [Supporting Multiple Languages](https://support.iterable.com/hc/articles/213279923).

## Previewing and sending test messages

After configuring and designing your template, preview it and make any necessary
fixes. To do this, use the **Preview** page and send test messages.

### Previewing your template

To see what your push notification looks like when rendered with different
combinations of user data, data feeds, and Catalog data, you can preview it.
When previewing, you can load a user profile and see how the template renders
for that user.

![Previewing a push notification with user data](https://support.iterable.com/hc/article_attachments/10030239379860/push-preview-mode.png "Previewing a push notification with user data")

> [!NOTE]
> Previewing a template for a specific user does not change the template. However, 
> you can use the **Details** button on this page to edit your template's details.

To preview a push notification template with user data:

1. With the template open, click **Preview**.

   ![Preview button](https://support.iterable.com/hc/article_attachments/9922764448148/preview-button.png "Preview button")

2. Enter the email address of a user in your project and click **Load user data**. 
   That user's data loads.

   Feel free to play around with this data, modifying it as needed — your
   changes do not get saved to the user profile. Treat this page as a playground,
   and check how different combinations of data cause your template to render.
   Make sure that the template looks correct in all the different ways it may
   appear to your users.

   :::tip TIP
   If the preview doesn't update after you've edited or loaded data, click the
   refresh icon near the previewer.
   :::

3. To see how your template renders with a data feed loaded, click 
   **Load data feeds**. Feel free to edit the loaded data feed data, to see how
   different data affects the template. This does not affect the data feed itself.

4. Click **Exit preview** to return to the template page.

For more information on previewing templates and campaign templates
with data, check out [Previewing Templates with Data](https://support.iterable.com/hc/articles/115002807783).

### iOS and Android previews

Before sending a push notification, it can be helpful to preview how it 
appears on both iOS and Android devices. To do this, in the template's **Design** 
area, click the iOS and Android buttons below the device preview.

### Sending test messages

After setting up your template, designing its content, and previewing it with 
user data, it's always a good idea to send yourself (and other internal users)
some test messages. This way, you can validate the message from the perspective
of your users.

To send a copy of the push notifications to yourself or another internal user,
open the template and open up design mode. Then, use the **Send test messsage** 
dropdown menu and choose **To yourself**, **To an internal list**, **As random users**,
or **To another address**. 

To prevent you from accidentally sending a test message to a production list,
these sends are capped at 50 users.

For more information, read [Sending Test Messages](https://support.iterable.com/hc/articles/360044426191).

> [!NOTE]
> The user receiving a test message must have a `devices` array associated with 
> their profile.

## Sending a push notification campaign

You've built and tested your template. Now, you can use it with some campaigns.
To learn how, read:

- [Sending or Scheduling a Blast Campaign](https://support.iterable.com/hc/articles/14761834767508)
- [Activating a Triggered Campaign](https://support.iterable.com/hc/articles/16765114424212)
- [Tutorial: Build Your First Journey](https://support.iterable.com/hc/articles/4405783163284#step-3-add-an-email-tile)

When creating a campaign (whether standalone as part of a journey), you'll 
select a template — or the content of another, already existing campaign — to
use as the starting point for its content. The new campaign gets its own copy of
the template, so you can customize it however you like. No need to worry about
affecting the original template.

Similarly, if you change a template you've already used in a campaign, your
changes affect the template itself, but not the already-existing campaigns.

> [!TIP]
> To apply template changes to a campaign you've already created, you can manually
> make the same changes to the campaign's template, create a new campaign using the
> updated template, or reselect the updated template for the campaign.

## Want to learn more?

For more information about some of the topics in this article, check out these 
resources. Iterable Academy is open to everyone — you don't need to be 
an Iterable customer!

**Iterable Academy**
- [Product Bite: Creating a Mobile Push Campaign](https://academy.iterable.com/product-bite-creating-a-mobile-push-campaign)
- [Product Bite: Channel Optimization](https://academy.iterable.com/product-bite-channel-optimization)

**Support docs**
- [Sending Push Notifications](https://support.iterable.com/hc/articles/115000379086)
- [Working with Templates](https://support.iterable.com/hc/articles/6532713719572)
- [Handlebars Overview](https://support.iterable.com/hc/articles/35601631606036)
- [Link Parameters](https://support.iterable.com/hc/articles/209530726)