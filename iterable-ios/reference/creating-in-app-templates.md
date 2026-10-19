---
slug: creating-in-app-templates
feature: in-app-messages
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Creating In-App Templates
source_url: https://support.iterable.com/hc/articles/360044425951
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/in-app/creating-in-app-templates/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 95cafb9a899e7a111c2122ea618c6cd93cd0fc49
fetched_at: 2026-10-06T11:07:38.927Z
summary: In-app templates are message blueprints that you can reuse across
  multiple in-app message campaigns, which users can view as they're using your
  mobile apps or websites. They can contain text, buttons, links, and images,
  and you can customize them with user profile and event data, data feeds, and
  Catalog data.
---
# Creating In-App Templates

In-app templates are message blueprints that you can reuse across multiple
in-app message campaigns, which users can view as they're using your mobile apps
or websites. They can contain text, buttons, links, and images, and you
can customize them with user profile and event data, data feeds, and Catalog
data.

![Create in-app templates](https://support.iterable.com/hc/article_attachments/9922906570004/in-app-template.png "Create in-app templates")

> [!TIP]
> Need a refresher on templates or in-app/browser messaging? Check out these 
> articles:
>
> - [Templates Overview](https://support.iterable.com/hc/articles/205480315)
> - [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406)
> - [In-Browser Messaging Overview](https://support.iterable.com/hc/articles/4418166649748)
>
> For information on editing, copying, previewing, and other related topics, read 
> [Working with Templates](https://support.iterable.com/hc/articles/6532713719572).

This article describes how to create an in-app message template, configure its
settings, design its content, preview it, send test messages, and use it with a
campaign.

## Permissions

To create and edit templates, you'll need the [_Create and Manage Templates and Creative Library_](https://support.iterable.com/hc/articles/205480335#templates-and-creative-library)
permission.

## Setting up your mobile apps

To send in-app messages, first add your mobile apps to Iterable, on the 
**Settings > Apps and websites** page. 

Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152),
[Android SDK](https://support.iterable.com/hc/articles/360035019712), and 
[React Native SDK](https://support.iterable.com/hc/articles/360045714072) include
functionality to fetch and display in-app messages in your apps.

## Creating a new in-app template

To create a template that you can reuse for one or many in-app message
campaigns:

1. Go to **Content > Templates**.

2. Click **New template > In-App**.

3. Give your template a name that will make it easy to find when you (or your 
   teammates) are setting up campaigns or journeys. This field has a 150-character 
   limit.

4. Click **Create template**.

   ![Create an in-app template](https://support.iterable.com/hc/article_attachments/9922890700948/in-app-template.png "Create an in-app template")

There are other ways to create templates, too: as you're setting up a new 
campaign, and by using Iterable's API. For more info, read 
[Working with Templates](https://support.iterable.com/hc/articles/6532713719572).

## Configuring the details of an in-app message template

To update in-app message template details such as message type, expiration time,
mobile inbox options, position, etc., open it up and configure the options in
the **Details** area.

To update these options, click **Edit details**. As you make changes, the template
preview (on the right side of the page) will update. When you're done editing, 
click **Save** or **Cancel**.

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

![In-app edit details](https://support.iterable.com/hc/article_attachments/9922906761492/in-app-edit-details.png "In-app edit details")

Here are the details you can update:

### Message type

The message category to associate with campaigns based on this template. This 
affects who will receive those campaigns. Read [Message Channels and Message Types](https://support.iterable.com/hc/articles/204780529).

### Expiration time

The last possible time that messages based on this template can be displayed or
listed in the app's mobile inbox (if applicable). 

By default, an in-app message expires 90 days after Iterable sends the campaign.
That is, if a mobile app doesn't retrieve the message in 90 days (maybe because
the user never opens the app), the user won't see it.

To specify a custom expiration time, use the **Expiration time** field. Use
this calendar to set a specific or relative expiration time. An expiration date
can be up to one year in the future.

To set a relative expiration time, use the text input near the calendar control
to enter an expiration time relative to the campaign send time. Use this syntax:

- `y` - years
- `M` - months
- `w` - weeks
- `h` - hours
- `m` - minutes
- `s` - seconds

For example:

- **send time** `+3h+14m+7d` - 3 hours, 14 minutes, 7 days after **send time**
- **send time** `+1M+1w` - 1 month and 1 week after **send time**
- **send time** `/d+3d` - 3 days after midnight on the day of **send time**

> [!WARNING]
> If a specific or relative expiration date falls before a campaign's send date,
> recipients will never see the in-app message.

Keep in mind: You can change an in-app campaign's expiration time, but Iterable 
doesn't update the expiration time for users who have already been sent the 
campaign. If you need to change an in-app campaign's expiration time, you can 
[recall the campaign](https://support.iterable.com/hc/articles/10373174278804)
and send it again with the new expiration time.

### Show in mobile inbox

Makes this message available in your app's mobile inbox, if it has one. 

### Deliver silently

Available when you select **Show in mobile inbox**. Causes this message to
appear _only_ in your app's mobile inbox. It won't appear to the user unless
they tap on it in the inbox to view it.

### Message format

The type of data to send with this message:

- **Content, styles, and layout** — Only send HTML content, as defined in the
  template editor.

- **Raw data (JSON)** — Only send the JSON data entered in the **Raw JSON** 
  input.

- **Everything: content, styles, layout, and raw data (HTML & JSON)** — Send
  HTML content, and any JSON data entered in the **Raw JSON** input. 

### Mobile inbox title

Available when you select **Show in mobile inbox**. The title of the message
that appears in your app's mobile inbox. 

This field accepts snippets, Handlebars, and emojis. Text beyond 25 characters 
will be truncated in the mobile inbox.

### Mobile inbox body

Available when you select **Show in mobile inbox**. The message body that
appears in your app's mobile inbox, as it's displayed in the list of available
messages. 

This field accepts snippets, Handlebars, and emojis. Text beyond 75 characters
will be truncated in the mobile inbox.

### Mobile inbox thumbnail URL

Available when you select **Show in mobile inbox**. The URL of an image to
display in the mobile inbox for this message.

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

### Position

Specifies the position of the in-app message on the mobile device:

- **Top** — Displays the in-app message at the top of the screen.
- **Bottom** — Displays the in-app message at the bottom of the screen.
- **Center** — Displays the in-app message in the center of the screen.
- **Full** — Displays the in-app message at the top of the screen, extending its
  background to all edges.

### Preset animations

Default animations to use when showing and hiding in-app messages.

> [!NOTE]
> - To use this feature, you must be on [version 3.2.8+](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.2.8)
>   of Iterable's Android SDK, [version 6.2.14+](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.2.14)
>   of Iterable's iOS SDK, or [version 1.0.18+](https://github.com/Iterable/react-native-sdk/releases/tag/1.0.18)
>   of Iterable's React Native SDK.
> - Don't use preset animations for in-app messages that include [CSS animations](https://support.iterable.com/hc/articles/360035539271),
>   which can lead to unpredictable results.

When an incoming in-app message has this option enabled, your apps display
and hide it using default animations based on the message's **Position**:

- **Top** - The in-app message slides in and out from the top edge of the 
  screen.
- **Bottom** - The in-app message slides in and out from the bottom edge of 
  the screen.
- **Center** - The in-app message fades in and out.
- **Full** - The in-app message fades in and out.

For example, here's the animation for the **Top** position:

![Preset animation for Top](https://support.iterable.com/hc/article_attachments/8932172622356/animation.gif "Preset animation for Top")

(This example in-app message has a cream-colored background, which causes the
color change you see at the end of the animation.)

Notes about preset animations:

- To preview an animation, click the play button near the device preview.

- On iOS, the sliding animations move through the safe area, but they don't 
  obstruct it when complete.

- On Android, the animation that slides in from the top moves under the status
  bar. After it completes, the status bar will overlap the in-app message a bit 
  — be sure to leave some extra space near the top of the message and to test as 
  necessary.

- For messages with this option disabled, different versions of Iterable's
  SDKs show and hide the messages in different ways:

  - Older versions of the iOS SDK (6.2.13 and lower) slide messages in from 
    the bottom. Older versions of the Android SDK (3.2.7 and lower) do not 
    animate them.

  - Newer versions of the iOS SDK (6.2.14 and higher) and Android SDK (3.2.8
    and higher) will not animate the message's appearance or disappearance.

> [!WARNING]
> Don't use CSS animations and preset animations in tandem, since the results can
> be unpredictable.

### Background overlay

A colored, semi-transparent background to display behind an in-app message. The
background extends to the edges of the screen, including the status bar.

> [!NOTE]
> This feature requires [version 3.2.8+](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.2.8)
> of Iterable's Android SDK, [version 6.2.14+](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.2.14)
> of Iterable's iOS SDK, or [version 1.0.18+](https://github.com/Iterable/react-native-sdk/releases/tag/1.0.18)
> of Iterable's React Native SDK.

Configure a background overlay with these values:

- **Hex Color** - The background's RGB color, specified as a hexadecimal value. 
  For example, enter `FF0000` for red, `00FF00` for green, or `0000FF` for 
  `blue`. You can also use RGB triplets such as `FF0` (yellow).

- **Opacity** - The opacity to use for the background. Enter a value between
  0 and 100 (inclusive).

The in-app preview updates as you change these values.

> [!NOTE]
> If an in-app message has a display type of **Full**, its background color
> will be obscured. However, that background color can be seen briefly while the
> message animates.

### Raw data (JSON)

Visible when **Message format** is set to 
**Everything: content, styles, layout, and raw data (HTML & JSON)**. JSON data
to send to your mobile app as part of the in-app message. Use this data to drive 
a custom message display or trigger functionality in your app.

For example, you could use JSON to insert a custom native modal or inline
message:

```json
{
  "title" : "We appreciate your business!",
  "body" : "Thanks for being a loyal customer. Here's 20% off your next purchase as a thanks!",
  "button_text" : "Save",
  "button_link" : "myapp://loyalty_promo"
}
```
Some other things you can do with this JSON data:

- Trigger a custom behaviors when the message is opened.
- Specify coupon codes.
- Describe link and attribution information.
- Indicate a notification type, and have your app behave differently depending
  on the type received.

You can customize raw JSON with Handlebars expressions, which output different
content for different users. To verify that your raw JSON works as expected, click 
**Preview** and scroll to the bottom of the page. As you load data for different
users, this preview updates. For more information, read [Previewing a JSON Payload](https://support.iterable.com/hc/articles/115002807783#previewing-a-json-payload).

## Designing the content of an in-app message template

To edit your template's design and content, open it up and click **Edit design**.

![In-app edit design button](https://support.iterable.com/hc/article_attachments/9922911487380/in-app-edit-design-button.png "In-app edit design button")

In design mode, you can:

- **Choose a template editor** to edit your template's content. If you're using
  the WYSIWYG or Side by Side editor, you can switch between the two in
  **Preferences**. 
  
  Unsure which template editor is right for you? Check out [Template Editors Overview](https://support.iterable.com/hc/articles/115002425483).

  :::tip TIP 
  We recommend personalizing your templates with [Handlebars](https://support.iterable.com/hc/articles/35601631606036), 
  [data feeds](https://support.iterable.com/hc/articles/204795659), and 
  [Catalog](https://support.iterable.com/hc/articles/360033214932) data.
  :::

- Insert a snippet into your template's content by clicking the **Snippet** 
  button. For more info about snippets, read [Adding a Snippet to a Template](https://support.iterable.com/hc/articles/4415894606356).

- Create and insert an **SMS Smart Opt-In** link with disclaimer text. For more 
  information, read [SMS Smart Opt-In](https://support.iterable.com/hc/articles/10870034844308).

- Manage [custom fonts](https://support.iterable.com/hc/articles/11555162439956#custom-fonts), 
  and whether or not your template should convert CSS to inline styles, click 
  **Preferences**.

![In-app edit design](https://support.iterable.com/hc/article_attachments/9922896444436/in-app-edit-design.png "In-app edit design")

Here are other things you can do in design mode:

- Add locales, using the locales dropdown menu. When you switch to a new locale, 
  you can define content to send to users tho use that locale. After you save a 
  locale, it will appear in the **Active** section of the locales dropdown menu. 
  For more information about locales, read [Supporting Multiple Languages](https://support.iterable.com/hc/articles/213279923).

- Edit your template's details without leaving design mode, by clicking the 
  **Details** button. This will bring up a side panel where you can make changes.

- View how the template will look when rendered with dynamic data for a 
  particular user of your choosing, by clicking the **Preview** toggle.

- Send a copy of the in-app message to yourself or other internal users, with the 
  **Send test message** dropdown menu. On this menu, you can choose **To yourself**, 
  **To an internal list**, **As random users**, or **To another address**. 
  For more info, read [Sending Test Messages](https://support.iterable.com/hc/articles/360044426191).

- Copy the template to the current or another project, by opening the overflow 
  menu (three dots) and choosing **Make a copy**. 

- Export the template's HTML, by opening the overflow menu (three dots) and 
  choosing **Export html**. This will download a file to your local machine.

> [!NOTE]
> When using the Drag and Drop editor to build an in-app template for your website, 
> we recommend a maximum content width of 768px. Exceeding this limit may cause 
> your content to get cut off or display with a horizontal scroller when the 
> campaign is live on your website.

### Buttons and links in in-app messages

As you're designing the content of an in-app message, you'll need to add buttons
and links, which can navigate users to content in your app or on your website,
trigger custom behavior in your app, or simply close the message.

Every in-app message must contain at least a single link or button, with a valid
URL, so that the user has a way to close it. If you don't include one, the 
template editor won't let you save the template.

URLs for buttons and links can be:

- **Web URLs** — For example, `https://www.example.com/sample/content`

- **Custom actions** — For example, `action://customActionName`, where
  `customActionName` is the name of any custom action supported by your mobile
  app's custom action handler. If you omit `customActionName` (leaving only
  `action://`), tapping the button or link simply closes the in-app message.

- **Iterable actions** — For example, `iterable://actionName`, where `actionName` 
  is the name of a pre-defined action supported by Iterable's SDK. For example, 
  to create a delete button/or link, use URL `iterable://delete`. To create a 
  close button/link, use URL `iterable://dismiss`.

### Example in-app message buttons

Here's an example in-app message template, shown as it's being edited in 
Iterable:

![Sample in-app message](https://support.iterable.com/hc/article_attachments/8934822632084/sample-in-app-message.png "Sample in-app message")

- The **Close** button might have URL `iterable://dismiss`, which closes the 
  message.

- The **View Feature** might have URL `action://feature`, which tells the app 
  to invoke the custom action triggered by `feature`.

- The **Go To Home Screen** button might have URL `action://home`, which tells 
  the app to invoke the custom action triggered by `home`.

### X-style close buttons

![Circle close button](https://support.iterable.com/hc/article_attachments/8934804875540/circle-button.png "Circle close button")

One way to create an X-style close button, using the Drag and Drop editor:

1. Add a button to the message template.

2. Set the button's text to `X`.

3. Set the button's **URL** to `action://`, which closes the in-app message when 
   tapped.

4. Choose a **Background Color** for the button.

5. Choose a **Text Color** for the button.

6. For **Align**, choose right.

7. Specify a **Border Radius** of `20`.

8. For **Content Padding** specify:
   - **Top** and **Bottom**: `0`
   - **Left** and **Right**: `10`

9. Specify a **Solid**, 1-pixel border of any desired color.

## Previewing an in-app message and sending test messages

After configuring and designing your template, preview it and make any necessary
fixes. There are a couple of ways to check your template: using the 
**Preview** page, and sending test messages.

### Previewing a template with user data

To see what your in-app message will look like when rendered with different
combinations of user data, data feeds, Catalog data, and on different devices,
use the **Preview** page. On this page, you can load a user profile and see 
how the template will render for that user.

![Previewing with user data](https://support.iterable.com/hc/article_attachments/9922926635284/in-app-preview.png "Previewing with user data")

> [!NOTE]
> Previewing a template for a specific user won't make any changes to your template. 
> However, you _can_ use the **Details** button to update your template's details.

To preview an in-app message template with user data:

1. With the template open, click **Preview**.

    ![Template preview button](https://support.iterable.com/hc/article_attachments/9922891072148/preview-button.png "Template preview button")

2. In the **User data** field, enter the email address of one of the users in
   your project. Then, click **Load user data**. That user's data will load in
   the large text area below the **User data** input.
    
   Feel free to play around with this data, modifying it as needed — your
   changes won't get saved to the user profile. Treat this page as a playground,
   and check how different combinations of data will cause your template to
   render. Make sure that the template looks correct in all the different ways 
   it may appear to your users.

   :::tip TIP
   If the preview doesn't update after you've edited or loaded data, click the
   refresh icon.
   :::

3. To see how your template will render with a data feed loaded, click 
   **Load data feeds**.  Feel free to edit the loaded data feed data, to see how
   *different data will look. This won't affect the data feed itself.

For more information on previewing templates with data, check out 
[Previewing a Template with User Data](https://support.iterable.com/hc/articles/115002807783).

### Sending a test message

After setting up your template, designing its content, and previewing it with 
user data, it's always a good idea to send yourself (and other internal users)
some test messages. This way, you can validate the message from the perspective
of your users.

To send a copy of the in-app messages to yourself or another internal user, open
the template and open up design mode. Then, use the **Send test message**
dropdown menu and choose **To yourself**, **To an internal list**, 
**As random users**, or **To another address**. For more info about these options, 
read [Sending Test Messages](https://support.iterable.com/hc/articles/360044426191).

![Send a test message](https://support.iterable.com/hc/article_attachments/9922907140884/send-test-message.png "Send a test message")

> [!NOTE]
> To prevent you from accidentally a proof to a production list, these sends are 
> capped at 50 users.

## Sending an in-app message campaign

You've built and tested your template. Now, you can use it with some campaigns.
To learn how, read:

- [Sending or Scheduling a Blast Campaign](https://support.iterable.com/hc/articles/14761834767508)
- [Activating a Triggered Campaign](https://support.iterable.com/hc/articles/16765114424212)
- [Tutorial: Build Your First Journey](https://support.iterable.com/hc/articles/4405783163284#step-3-add-an-email-tile)

When creating a campaign (whether standalone as part of a journey), you'll 
select a template — or the content of another, already existing campaign — to
use as the starting point for its content. The new campaign will get its own
copy of the template, so you can customize it however you like. No need to
worry about affecting the original template.

Similarly, if you change a template that you've already used in a campaign, your
changes will affect the template itself, but not the already-existing campaigns.

> [!TIP]
> To apply template changes to a campaign you've already created, you can manually
> make the same changes to the campaign's template, create a new campaign using the
> updated template, or reselect the updated template for the campaign.

## Want to learn more?

For more information about some of the topics in this article, check out these 
resources. Iterable Academy is open to everyone — you don't need to be 
an Iterable customer!

**Iterable Academy**
- [Product Bite: Creating an In-App Template](https://academy.iterable.com/creating-an-in-app-template)

 **Support docs** 
- [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406)
- [Sending In-App Messages](https://support.iterable.com/hc/articles/360034903151)
- [Working with Templates](https://support.iterable.com/hc/articles/6532713719572)
