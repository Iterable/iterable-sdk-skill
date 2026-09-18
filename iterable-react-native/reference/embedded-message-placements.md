---
slug: embedded-message-placements
feature: embedded-messaging
archetype: prerequisite
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Defining Placements for Embedded Messages
source_url: https://support.iterable.com/hc/articles/23060983437076
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/embedded-messaging/placements-for-embedded-messages/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: 9d3f509c00fb5c26601026bd89837ba68cfcad9c
fetched_at: 2026-09-17T15:32:00.898Z
summary: Before you can create embedded message templates and campaigns, you'll
  need to decide where in your apps to display them. Places in your app or
  website that display embedded messages are called _placements_, and you'll
  define them in Iterable _and_ in the code of your mobile apps and websites.
---
# Defining Placements for Embedded Messages

> [!NOTE]
> To add Embedded Messaging to your Iterable account, talk to your customer success 
> manager.

Before you can create embedded message templates and campaigns, you'll need to
decide where in your apps to display them. Places in your app or website that
display embedded messages are called _placements_, and you'll define them in
Iterable _and_ in the code of your mobile apps and websites.

This article provides an overview of placements and describes how to create them.

## Placements overview

Embedded messages should appear in your apps and websites in the places where
they are _most relevant and useful_ to your users.

Different screens and pages in your apps and websites — and even places _on_
those screens and pages (scroll positions, etc.) — provide different contexts
for your messages. To leverage that context to create useful, engaging messages,
associate each of your embedded message campaigns with the specific location —
the _placement_ — where it will provide the most value.

Before you can create embedded messaging templates or campaigns, you'll need to
define your placements in Iterable, and add them to your mobile app and website
code. Then, you can configure your embedded messaging campaigns to appear in 
sensible places in your apps and websites.

### Different placements for different kinds of messages

When creating an embedded message or template in Iterable, you'll associate it
with a single placement. Because of this:

- Each of your embedded message campaigns will be displayed in your apps or 
  websites _only_ where you expect (by the placement you've associated it with).

- Iterable can prompt the person creating the template or campaign to fill in
  the specific data required by the placement.

For example:

- You might use your an app's home screen to display embedded message campaigns
  promoting upcoming events, and your user profile screen to display embedded 
  messages campaigns about account upgrades. 

- Similarly, you don't want checkout-related embedded messages to appear on
  your home screen, or home screen messages to appear at checkout. Use different
  placements to show the right message in the right place.

### The same placement can exist in multiple apps

The same placement can exist in many apps. For example, you might put a home
screen placement on your iOS app's home screen, and _also_ on your Android app's
home screen. Embedded messages campaigns associated with that placement will
appear on each app's home screen (to eligible users).

### A placement can display multiple messages at once

Placements, depending on their configuration and implementation, can display 
one or many embedded messages at the same time. 

For example, this is how embedded messages can power a carousel interface. A
three-item carousel would expect to receive up to three embedded message
campaigns, all for the same placement, and then display them together. (And
if the user isn't eligible for three campaigns, the carousel could show only
one or two messages, as needed.)

### Collaboration is key

Your marketing, design, and engineering teams **must have** a shared understanding 
of your plans for embedded messages in your apps and websites:

- Where the embedded messages will appear (placements)
- What data the embedded messages will display (data requirements)
- How the messages will display that data (message design)

Close collaboration will set you up for success!

## Permissions

To work with embedded message placements n Iterable, you'll need various 
[permissions](https://support.iterable.com/hc/articles/205480335):

|Action|Required permission|
|------|-------------------|
|View embedded message placements|[_View Channels_](https://support.iterable.com/hc/articles/205480335#project)|
|Create embedded message placements|[_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project)|
|Manage embedded message placements|[_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project)|

## Defining and configuring placements in Iterable

> [!TIP]
> You must create at least one placement in your Iterable project before you can
> create any embedded message templates or campaigns. Why? Every template and
> campaign must be associated _with_ a placement, so that it knows that data
> to include (title, body, media URL, etc.).

To define your placements and add them to Iterable, follow these steps:

### Step 1: Decide where to display embedded messages (placements)

As described above, _placements_ are the places in your apps and websites that
display embedded messages, and each placement only displays its associated messages.

To decide where to add placements in your apps and websites, consider all the
places where they might add value for your users and for your business. The
options here are endless and deserve a thorough review.

Then, work with your marketing, design, and engineering teams to make sure you
have a common understanding of where your placements will exist — and to verify
that there aren't any hidden design or implementation constraints that will
affect those placement decisions.

### Step 2: For each placement, define data requirements and message design

You know _where_ you'll display embedded messages — but _what_ will you display,
and _how_ are you going to display it? 

The design for each of your placements will call for different data, and display
it in different ways. Messages may look different from one placement to the
next, but messages shown by the same placement will generally contain the same
elements.

> [!TIP]
> A message's data requirements affect its design, and vice-versa. As you're
> planning how to use embedded messages in your apps and websites, consider these
> things together.  And be sure to partner with your marketing, design, and
> engineering teams to make sure that you're thinking about things in the same
> way.

#### What to display (data requirements)

First, consider each placement's data requirements. What data will the
placement's messages display? What data must the marketer include with each
embedded campaign meant for placement, to make sure the app has the data it
needs to build the agreed-upon message interface?

For example, you might decide that the embedded messages shown by your home screen 
placement should have:

- Title text
- Body text
- An image
- A single button

On the other hand, embedded messages on your user profile might have:

- Title text
- Body text
- Two buttons
- Custom data

To learn about the types of data you can include with an embedded message, read 
[Creating placements in Iterable](#step-3-create-placements-in-iterable), below.

#### How to display it (message design)

As you specify each placement's data requirements, decide also on a design for 
its messages.  There are two ways a placement can display messages: out of the
box message components, and custom displays. 

- **Out-of-the-box views** – Provided by Iterable's mobile SDKs, these are
pre-made, customizable components for cards, notifications, and banners. 

  With these components, you can customize background color, border color / width
  / radius, button background and text color, and title and body text color.

  Your engineers will need to integrate these components into your apps and
  websites, but they won't need to build the display components themselves.  This
  can help you get up and running with embedded messages more quickly.

  For more information about out-of-the-box components, read
  [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).

- **Custom message displays** – Fully custom message displays designed by your
  designers and implemented by your engineers. 

  This is the most flexible way to display embedded messages. Custom displays
  make it possible to build embedded messaging displays that perfectly match the
  interface of your app and website. However, building custom message displays
  can add time to your implementation of Embedded Messaging.

### Step 3: Create placements in Iterable

After deciding where to add embedded messages placements in your apps and
websites, and defining their data requirements and message design, define those 
placements in your Iterable project. 

> [!WARNING]
> As you create each placement, copy down the numeric ID that Iterable assigns it.
> Your engineers will need this ID when updating your apps and websites to display 
> embedded messages.

To add a placement to your Iterable project, go to **Settings > Embedded Message Placements** 
and click **New Placement**. You'll see this page:

![Creating a new embedded message placement in Iterable](https://support.iterable.com/hc/article_attachments/23358161599508/creating-a-placement-in-iterable.png "Creating a new embedded message placement in Iterable")

#### Placement settings

In the **Placement** section, provide some general configuration information:

- **Name** – The name of your placement. Used to select the placement when you're
  creating a template or defining campaign content.

- **Description** – A description of the placement, to help your Iterable project's 
  team members understand its purpose.

- **Media Layout** – The layout to use for the embedded message preview that
  appears while you're building an embedded message template or campaign. 

  These options generally correspond to the out-of-the-box views provided by
  Iterable's mobile SDKs:
  
  - **Top** – Card view
  - **Right** – Banner view
  - **None** – Notification

  Choose the preview option that most closely represents how you'll display this
  placement's embedded messages in your apps and websites.

  :::warning IMPORTANT
  This option affects the way that embedded messages show up in Iterable's
  previewer, **not** how they'll actually appear in your app. Since your apps
  can display embedded message campaigns using any sort of custom interface
  you build, there's no way for Iterable to provide a perfectly accurate preview.
  :::

- **Type** – How many messages the placement should display at a time.

  - **Banner** – One message.
  - **Carousel or Feed** – Many messages.

- **Campaign Limit** – When **Type** is **Carousel or Feed**, this option
  specifies the number of campaigns the placement can display at once. For
  instance, if your placement will have a carousel that displays three messages,
  set this to `3`.

> [!WARNING]
> **Type** and **Campaign Limit** do not currently affect how many embedded
> message campaigns you can create and activate for a given placement, or how
> many embedded messages your app or website can display for that placement. For
> now, use these fields to communicate your intention for the placement, to other
> Iterable users who view it in Iterable.

#### Details settings

> [!NOTE]
> When setting up a placement, you aren't defining actual values to use for
> the fields you enable. You'll do that when you create an actual template or
> campaign.
  
Under **Details**, define the fields the placement's messages will use to
display messages. When an Iterable user creates a template or campaign, they'll
be prompted to provide values for the fields you set up here.

- **Title** – A title, usually for prominent display in your message.

- **Body** – Message content.

- **Media URL** – A URL to an image to display in your message.

- **Data Feeds** – External URLs Iterable should query before delivering an
  embedded message to a device. The data returned by these URLs can be used to
  personalize the message.

- **Text Fields** – Extra data to include with your message. 

  Text fields are for data, not content. Similar to **Raw data (JSON)**,
  your app can use the values of these fields to style your embedded message, or
  to trigger custom functionality in your app.

  Click **Add Field** to add custom field text fields. In the text input, enter
  the label that should appear in Iterable as someone creates a template or
  campaign. The person creating the template or campaign can then enter a value 
  for the field.

- **Open Action** – An action (link or custom action) to invoke when an embedded 
  message is tapped.

- **Action Buttons** – Buttons to include in your message (and associated URLs
  or custom actions to invoke when they're clicked). Click the pencil button next
  to each button to change its name.

- **Raw Data (JSON)** – The value entered here is used as the default value for
  the corresponding **Raw Data (JSON)** input on new templates and campaigns
  associated with this placement. You can edit the value before activating the
  campaign.

When you're done, click **Create**.

> [!WARNING]
> Placements cannot be edited after they are created. If you need to make changes,
> you'll need to create a new placement.

## Managing placements

On the **Settings > Embedded Message Placements** page, you can also archive
placements, copy placements, and edit campaign display priority for a placement.

To do these things, click the details button next to the name of the placement, 
and choose an option.

![Copy, archive, and edit a placement's priority](https://support.iterable.com/hc/article_attachments/23358181883028/managing-a-placement.png "Copy, archive, and edit a placement's priority")

Archiving a placement deactivates any of its associated embedded message
campaigns, and causes associated templates to show an error when you open them.

## Next steps

Next up, read [Configuring Your Apps to Retrieve and Display Embedded Messages](https://iterable.zendesk.com/hc/articles/23194187295892).

