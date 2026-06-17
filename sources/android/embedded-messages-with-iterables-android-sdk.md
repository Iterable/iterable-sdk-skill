---
url: https://support.iterable.com/hc/articles/23061877893652
title: Embedded Messages with Iterable's Android SDK
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/embedded-messaging/embedded-messages-with-iterables-android-sdk/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 6a6d6b5baf76973d611fb7f17785d3b04feeace0
fetched_at: 2026-05-25T15:11:44.823Z
---
# Embedded Messages with Iterable's Android SDK

:::tip NOTE
To add Embedded Messaging to your Iterable account, talk to your customer success 
manager.
:::

This article describes the steps you'll need to follow to use Iterable's Android
SDK to display embedded messages in your mobile app.

This document describes only the steps necessary to use embedded messaging.  To 
learn about more SDK options, read [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712).

## In this article

[[toc]]

## Step 1: Coordinate with your marketing and design teams

First, collaborate with your marketing and design teams to determine:

- Where you'll display embedded messages in your apps (where your _placements_ go).
- Each placement's Iterable-assigned numeric ID (so you can display the right 
  messages in the right places).
- The data to display in each placement's messages. This determines what fields
  your app will expect to find in an embedded message payload.
- The message design for each of your placements.

## Step 2: Create a Mobile API key

To use Iterable's Android SDK to display embedded messages, you'll need a mobile 
API key. To learn how to create one, read [Creating API keys](https://support.iterable.com/hc/articles/360043464871#creating-api-keys)

## Step 3: Install Iterable's Android SDK in your app

To learn how to install Iterable's Android SDK in your app, read 
[Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712).
Embedded Messaging is supported by versions [3.5.0+](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.5.0)
of Iterable's Android SDK.

## Step 4: Configure the SDK

Next, configure the SDK, specify a URL handler and a custom action handler,
enable embedded messaging, set allowed URL protocols, initialize the SDK with an 
API key, and identify the user.

For example:

```kotlin
val config = IterableConfig.Builder()
    .setUrlHandler(this)
    .setCustomActionHandler(this)
    .setEnableEmbeddedMessaging(true)
    // Specify the URL schemes you're expecting to receive in the campaigns you 
    // send with Iterable. The SDK passes URLs with these URL schemes to your URL 
    // handler, which can then handle them as necessary. For example, if you 
    // indicate that "mycompany" is an allowed protocol, the SDK will pass URLs 
    // such as "mycompany://profile" to your URL handler, which can respond as
    // needed. For example, for "mycompany://profile", it might deep link to 
    // the app's user profile screen.
    .setAllowedProtocols(arrayOf("mycompany"))
    .build()

IterableApi.initialize(this, apiKey, config)

IterableApi.getInstance().setEmail(email) 
// IterableApi.getInstance().setUserId(userId) 
```

:::tip NOTE
If your project is hosted on [Iterable's EDC](https://support.iterable.com/hc/articles/17572750887444),
you'll need to [configure the SDK appropriately](https://support.iterable.com/hc/articles/360035019712#step-5-2-if-necessary-configure-the-sdk-to-use-iterable-s-edc).
:::

### Step 4.1: Define a URL handler

In the example SDK configuration code above, notice the call to `setUrlHandler` 
on `IterableConfig`. The SDK uses the object (which must implement interface 
`IterableUrlHandler`) passed to this method to handle two types of URLs:

- Standard URLs, such as `https://example.com/product/123`.
- URLs with allowed custom URL schemes, such as `mycompany://profile`. The SDK
  ignores URLs that use custom URL schemes not specified as allowed protocols
  on `IterableConfig` (see above).
  

When a user clicks a button or a link on an incoming message, and the click is 
associated with one of the two URL types listed above, the SDK passes that URL to
the URL handler. Then, the URL handler can handle (or not handle) it as it makes
sense. For example, it might open the link in a browser or open it as a deep link.

The object you provide to `setUrlHandler` must implement interface 
`IterableUrlHandler`, which defines this method:

```java
boolean handleIterableURL(
    @NonNull Uri uri, 
    @NonNull IterableActionContext actionContext
);
```

This method should return `true` for URLs it can handle, and `false` for URLs it
cannot handle. 

When the URL handler can't handle a given URL, the SDK checks for another
installed app that can handle that URL (for example, a web browser). If there
are no other apps that can handle the URL, the SDK does nothing.

Here's an example implementation:

```kotlin
override fun handleIterableURL(uri: Uri, actionContext: IterableActionContext): Boolean {
    val urlString = uri.toString()
    // For example, urlString might be: "mycompany://profile"
    if (urlString.contains("mycompany://profile")) {
        // Navigate the user to the profile page ...
        return true
    }
    return false
}
```

In this sample, `handleIterableUrl` handles `mycompany://profile` URLs by 
navigating the user to the user profile screen. Then, it returns `true` to 
indicate that it handled the URL.

Implementations of this method will vary, depending on your app architecture
and the URLs you need to handle. However, it's important to remember that this 
method is shared across message mediums. Make sure to handle URLs you might 
receive from any message type, not just embedded messages.

### Step 4.2: Define a custom action handler

Custom actions represent custom functionality you'd like your app to execute — 
maybe a deep link, a style update, or another behavior of some kind. Custom
actions use the `action://` URL scheme.

:::tip NOTE
In-app messages also support `iterable://dismiss` and `iterable://delete` custom
actions. Embedded messages do not yet support these actions. The `iterable://`
URL scheme is reserved for Iterable-specific actions pre-defined by the SDK.

For tips on alternatives to a dismiss action, read [Closing, dismissing, or hiding an embedded message](#closing-dismissing-or-hiding-an-embedded-message).
:::

Similar to your URL handler, the object specified on `IterableConfig` as your 
custom action handler serves as your app's central handler for custom actions.
When a user clicks a button or a link associated with a custom action, this
action is passed to your custom action handler, where you can deal with it
however necessary (usually by executing custom functionality of some kind).

Your custom action handler must implement interface `IterableCustomActionHandler`, 
which defines this method:

```java
boolean handleIterableCustomAction(
    @NonNull IterableAction action, 
    @NonNull IterableActionContext actionContext
);
```

This method should return `true` when it can handle the custom action URL, and 
`false` when it cannot. When it returns `false`, the custom action is dropped —
since custom actions are special, non-standard URLs, they cannot be opened by
a web browser.

For example, here's a sample custom action handler that handles an 
`action://joinClass/1` URL:

```kotlin
override fun handleIterableCustomAction(
    action: IterableAction,
    actionContext: IterableActionContext
): Boolean {
    // The custom action's type is stored in action.type
    if (action.type?.contains("joinClass"))
        // Sign the user up for a class ...
        return true
    }
    return false
}
```

Implementations of this method will vary. However, be sure to account for any
specific custom actions you'll send to your app (in an embedded message, or in
any other kind of message).

### Closing, dismissing, or hiding an embedded message

Embedded messages don't have a native "dismiss" action like in-app messages do.
However, you can implement custom logic to control when an embedded message is
displayed to a user. Here are some strategies you can use:

- **Set an expiration date for the campaign:** Set an expiration date for your 
  embedded message campaign in Iterable. Once the campaign expires, the message 
  is no longer displayed to users. This method does not allow end-users to dismiss 
  the message actively, however.

- **Implement custom logic based on eligibility criteria:**
  For more dynamic control, you can create a solution that changes a user's
  eligibility criteria for an embedded message campaign. When a user's eligibility
  changes such that they no longer meet the targeting criteria, the embedded message
  is no longer returned in their message array the next time the page is
  refreshed, or automatically via silent push.

  This approach typically involves:
   
  - **Updating user profile or list membership:** You can use an Iterable SDK
    or API to update a user's profile fields or their membership in a list. This
    update can be triggered by a user action (for example, tapping a button in your
    app).

  - **Leveraging custom events and journeys:** You can track a custom event in
    Iterable when a specific user action occurs (such as a `message_dismissed`
    event), then use the event to trigger a journey in Iterable. Within the
    journey, you can perform a user profile update or a list membership update
    that removes the user from the campaign's eligibility criteria.

Specific implementation details vary depending on your application, SDK, and 
desired user experience.

## Step 5: Enable support for push notifications in your app

To alert your app when the signed-in user's embedded message _eligibility_ changes
(that is, when they are newly eligible, or no longer eligible, for some embedded
message campaign in your project), Iterable sends silent push notifications.

After receiving one of these silent push notifications, the SDK refreshes its
local cache of embedded messages by re-fetching them from Iterable's API.

To learn how to enable push notifications in your Android app, read
[Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943).

## Step 6: Fetch embedded messages from Iterable

When your app first launches, and each time it comes to the foreground,
Iterable's Android SDK automatically refresh a local, on-device cache of
embedded messages for the signed-in user. These are the messages the signed-in
user is _eligible_ to see.

:::tip NOTE
A user is _eligible_ for an embedded message campaign if they're selected by its
associated _eligibility list_ (a standard dynamic list in Iterable).
:::

At key points during your app's lifecycle, you may want to manually refresh your
app's local cache of embedded messages. For example, as users navigate around, 
on pull-to-refresh, etc.

To refresh the local cache of embedded messages, call:

```kotlin
IterableApi.getInstance().embeddedManager.syncMessages()
```

However, do not poll for new embedded messages at a regular interval.

:::tip NOTE
Currently, Iterable's Android SDK does not persist the embedded messages
downloaded from the server. When your app is restarted, Iterable's Android SDK
re-fetches the user's embedded messages from Iterable, which can cause the
creation of multiple [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events)
events for the same message.
:::

To fetch embedded messages, Iterable's Android SDK calls:

[`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages)

## Step 7: Track message receipt

For each embedded message received from Iterable, Iterable's Android SDK
automatically tracks an [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events) 
event. Each of these events represents the download of a particular message to a 
particular device — but not, necessarily, that the message was displayed or seen 
by the user.

To track message receipt, Iterable's Android SDK calls:

[`POST /api/embedded-messaging/events/received`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-received)

## Step 8: Set up SDK listeners

Now, set up listeners for the SDK to call when new embedded messages arrive
on device, to tell your views to display messages as needed. To add these
listeners, call the following methods on `IterableEmbeddedManager`:

```kotlin
public fun addUpdateListener(updateHandler: IterableEmbeddedUpdateHandler)
public fun removeUpdateListener(updateHandler: IterableEmbeddedUpdateHandler)
```

Typically, a view that displays embedded messages adds itself as a listener
when it appears, and removes itself as a listener when it disappears. For
example, for an activity or a fragment:

```kotlin
override fun onResume() {
  super.onResume()
  IterableApi.getInstance().embeddedManager.addUpdateListener(this)
  // ...
}

override fun onPause() {
  super.onPause()
  IterableApi.getInstance().embeddedManager.removeUpdateListener(this)
  // ...
}
```

`IterableEmbeddedUpdateHandler`, the interface that listeners must implement, 
declares these methods:

- `fun onMessagesUpdated()` – Called by the SDK to tell your app that embedded
   messages have been updated, and that you can grab the local queue and display
   them. 

- `fun onEmbeddedMessagingDisabled()` – Called by the SDK when there's a failure
  fetching embedded messages from the server. Use this method to hide your
  embedded message display or show default content, as needed.

- `fun onEmbeddedMessagingSyncSucceeded()` – Called when an embedded messaging
  sync completes successfully. Use this method to update any loading state in
  your UI, or to log that the sync finished. This method has a default empty
  implementation, so overriding it is optional.

- `fun onEmbeddedMessagingSyncFailed(reason: String?)` – Called when an embedded
  messaging sync fails. The `reason` parameter contains a failure reason string,
  when available (for example, a network or server error message). Use this
  method to log failures, show fallback content, or surface non-sensitive error
  information to your users. This method has a default empty implementation, so
  overriding it is optional.

For example, a view registered as a listener might have implementations similar
to:

```kotlin
override fun onMessagesUpdated() {
    // Fetch messages for the placement associated with the current view
    val messages = embeddedManager.getMessages(placementId)

    // Show or hide messages...
    // ...
}

override fun onEmbeddedMessagingDisabled() {
    // Hide embedded UI or show default content
    // showFallbackContent()
}

override fun onEmbeddedMessagingSyncSucceeded() {
    // Stop loading indicators, confirm latest content is shown
    // hideLoadingSpinner()
}

override fun onEmbeddedMessagingSyncFailed(reason: String?) {
    // Log or surface a non-sensitive error state
    // Log.d("Embedded", "Sync failed: ${reason ?: "Unknown error"}")
    // showEmbeddedErrorState()
}
```

:::tip TIP
You may want to check the local list of messages right when your view appears,
_as well as_ when the SDK calls `onMessagesUpdated`. That way, if there are
messages already available for display when the view first appears, you can show
them. Otherwise, you can display a loading spinner or hide the embedded message
view altogether.
:::

:::warning IMPORTANT
The SDK does not always call `onMessagesUpdated`,
`onEmbeddedMessagingSyncSucceeded`, or `onEmbeddedMessagingSyncFailed` on the
main thread. To prevent crashes, make sure you're on the main thread before
updating your app's UI to display embedded messages.
:::

## Step 9: Display embedded messages

For each incoming embedded message, create a view and add it to your app's user
interface, using the fields included in the message to populate the message
content and set its styles. For example, you might use one `IterableEmbeddedMessage` 
to drive the creation of a single banner message, or many of them to drive the 
creation of a carousel.

As you're setting up your embedded message views:

- Associate each message view with its corresponding `IterableEmbeddedMessage` 
  object, so you have access to the underlying message (and its `messageId`) when 
  tracking events.
- Add click handlers where necessary, so you can handle clicks and track them in 
  Iterable. As messages appear and disappear, track impressions (described in
  the next section).

`IterableEmbeddedMessage` objects have various fields, corresponding to the data 
included with your campaign:

- `metadata` – Identifying information about the campaign.
  - `messageId` – The ID of the message.
  - `placementId` – The ID of the placement associated with the message.
  - `campaignId` – The ID of the campaign associated with the message.
  - `isProof` – Whether or not the campaign is a test message.

- `elements` – What to display, and how to handle interaction.
  - `title` – The message's title text.
  - `body` – The message's body text.
  - `mediaUrl` – The URL of an image associated with the message.
  - `mediaUrlCaption` – Text description of the image.
  - `defaultAction` – What to do when a user clicks on the message (outside of its buttons).
  - `buttons` – Buttons to display.
  - `text` – Extra data fields. Not for display.

- `payload` – Custom JSON data included with the campaign.

Use this data to build a custom view. Or use one the out-of-the-box views
provided by the SDK, as described below.

:::tip TIP
For a look at the JSON payload associated with an embedded message, see 
[`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages).
:::

### Out-of-the-box views

Iterable's Android SDK provides an `IterableEmbeddedView` class you can use to
display embedded messages as a card, a banner, or a notification. For more 
information about out-of-the-box views, read [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).

You can customize out-of-the-box views, in some ways, to more closely match the
styles of your apps. 

Out-of-the-box views handle clicks, too. To do this, they automatically:

- Pass URLs and custom actions to the URL and custom action handlers you set up 
  in [step 4](#step-4-configure-the-sdk).
- Track [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events) 
  events.

:::tip NOTE
When using out-of-the-box views to display embedded messages, you'll still need to 
manually track sessions and impressions, as described in [step 10](#step-10-track-sessions-and-impression).
:::

To use an out-of-the-box view, first create an `IterableEmbeddedViewConfig` object, 
to declare the styles you'd like the view to use:

```kotlin
// Grab your app's colors from wherever it makes sense.
val config = IterableEmbeddedViewConfig(
    backgroundColor: Color.parseColor("#FFFFFF"), 
    borderColor: Color.parseColor("#000000"),
    borderWidth: 1,
    borderCornerRadius: 8f,
    primaryBtnBackgroundColor: Color.parseColor("#0000FF"), 
    primaryBtnTextColor: Color.parseColor("#FFFFFF"), 
    secondaryBtnBackgroundColor: Color.parseColor("#FFFFFF"), 
    secondaryBtnTextColor: Color.parseColor("#000000"), 
    titleTextColor: Color.parseColor("#000000"), 
    bodyTextColor: Color.parseColor("#000000")  
)
```

Then, when it's time to display a message, create the `IterableEmbeddedView`
using the `newInstance` factory method:

```kotlin
val messageView = IterableEmbeddedView.newInstance(ootbType, message, config)
```

This method takes three parameters:

- A value of type `IterableEmbeddedViewType`, an `enum` with three constants:
  - `BANNER`
  - `CARD`
  - `NOTIFICATION`
- The `IterableEmbeddedMessage` to display.
- The `IterableEmbeddedViewConfig` created above (optional — pass `null` or omit
  to use default styles).

:::warning IMPORTANT — Migration from older SDK versions
In SDK versions prior to 3.6.5, `IterableEmbeddedView` was instantiated using a
constructor:

```kotlin
// Old approach (deprecated — unstable):
val messageView = IterableEmbeddedView(ootbType, message, config)
```

This constructor has been **deprecated** because it violates Android Fragment
best practices: the system cannot recreate the fragment after configuration
changes or process death, causing crashes.

**Use the `newInstance` factory method instead**, as shown above. The old 
constructor still works but is marked as deprecated and will be removed in a 
future SDK release.
:::

Then, add the view to your layout. It's important to fully specify the size
of the view, with minimum dimensions, as described in 
[Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).

For example, one way to add an out-of-the-box layout to a view is to swap it
with a "placeholder" view that's already there. For example, this layout
contains a placeholder `FrameLayout`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<RelativeLayout
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:layout_width="match_parent"
    android:layout_height="match_parent">

    <FrameLayout
        android:id="@+id/placeholder_view"
        android:layout_width="match_parent"
        android:layout_height="wrap_content"/>

</RelativeLayout>
```

When it's time to display the embedded message, you could replace the placeholder
view using code such as:

```kotlin
val ft: FragmentTransaction = childFragmentManager.beginTransaction()
ft.replace(R.id.placeholder_view, messageView)
ft.commit()
```

With this approach, the placeholder view might be an empty state that can remain
in place when there are no embedded messages available, or a view with a loading
spinner, or something similar. 

However, this is just an example. The specific approach you'll take when adding
an out-of-the-box view to your app depends on your app architecture.

## Step 10: Track sessions and impression

A _session_ is a period of time when a user is on a screen or page that can
display embedded messages. 

Every session can have many _impressions_. An impression represents the
on-screen appearances of a given embedded message, in context of a session. Each
impression tracks:

- The total number of times a message appears during a session.
- The total amount of time that message was visible, across all its appearances
  in the session.

To help you track message sessions and impressions (views of a message),
Iterable's Android SDK provides a session manager. Sessions and impressions are 
tracked in Iterable as [`embeddedSession`](https://support.iterable.com/hc/articles/23061677642260#embeddedsession-events) 
and [`embeddedImpression`](https://support.iterable.com/hc/articles/23061677642260#embeddedimpression-events)
events.

### Step 10.1: Start a session

When a user comes to a screen or page in your app where embedded messages are
displayed (in one or more placements), use the session manager to start a
session. To start a session, call:

```kotlin
// When the screen that displays your embedded message is displayed or comes to
// the foreground
IterableApi
   .getInstance()
   .embeddedManager
   .getEmbeddedSessionManager()
   .startSession()
```

### Step 10.2: Start and pause impressions 

As messages appear or disappear during an ongoing embedded message session, use
the session manager to track message impressions. 

The session manager tracks the total number of times each message appears during
a session, and the total amount of time each message is on-screen across all
those appearances. To start and pause impressions, call:

```kotlin
// When a message appears, start an impression (associating it with a placement)
IterableApi
    .getInstance()
    .embeddedManager
    .getEmbeddedSessionManager()
    .startImpression(messageId, placementId)

// When a message disappears…
IterableApi
    .getInstance()
    .embeddedManager
    .getEmbeddedSessionManager()
    .pauseImpression(messageId)
```

:::tip NOTE
An embedded message can disappear and reappear many times during a session.
Because of this, when an embedded message disappears, you don't _end_ its
impression — you _pause_ it. Then, you start the impression again if and when
the message reappears. In other words, you start and end sessions, but you start 
and _pause_ impressions.  
:::

Be sure to start and pause impressions when your app goes to and from the
background, too.

### Step 10.3: End the session, saving impression data to Iterable

When a user leaves a screen in your app where embedded messages are displayed,
use the session manager to end the active session. This causes the SDK to send
session and impression data back to the server.

To end a session, call:

```kotlin
// When a screen that displays embedded messages is dismissed 
// or goes to the background
IterableApi
    .getInstance()
    .embeddedManager
    .getEmbeddedSessionManager()
    .endSession()
```

To track sessions and impressions, Iterable's Android SDK calls:

[`POST /api/embedded-messaging/events/session`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-session)

## Step 11: Handle clicks

Finally, configure your app to handle clicks on embedded messages. When a user
clicks a link or a button, it can be associated with:

- A standard URL (for example, `https://example.com/products/1`).
- A custom URL scheme (for example, `mycompany://profile`).
- A custom action (for example, `action://joinClass/1`).

Above, you set up a [URL handler](#step-4-1-define-a-url-handler) for handling
standard URLs and custom URL schemes, and a [custom action handler](#step-4-2-define-a-custom-action-handler) 
for handling custom action URLs.

Now, just listen for clicks, and then tell the SDK to invoke the URL or the
custom action handler (depending on the type of URL that was clicked).

### Click handling for out-of-the-box views

If you're using an out-of-the-box view to display embedded messages, you can
skip this step. Out-of-the-box views automatically:

- Pass standard URLs and URLs with allowed custom URL schemes to the URL handler 
  you defined above. If your URL handler can't handle the URL (returns `false`), 
  the SDK attempts to open it with another app that can handle it (for example, 
  a web browser).
- Pass custom actions to your custom action handler. If your custom action handler
  can't handle the custom action (returns `false`), the custom action is dropped
  (since it can't be handled by a web browser).
- Track [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events) 
  events.

### Click handling for custom embedded message views

However, if you're using custom views instead of out-of-the-box views, you'll 
need to handle clicks. As you instantiate custom embedded message views in your 
Android app:

- Add click handlers to the message's buttons and links. Do this however it makes
  sense for your app.
- Set up a default click handler, to handle clicks on the message but outside
  of any particular button or link.

In your click handlers:

- Execute any necessary custom application logic (update the UI if needed, etc.).

- Call `handleEmbeddedClick` on `IterableEmbeddedManager`. This method forwards
  URLs and custom actions to the handlers you defined above. For example:

  ```kotlin
  IterableApi
      .getInstance()
      .embeddedManager
      .handleEmbeddedClick(
          message,
          buttonIdentifier,
          clickedUrl
       )
  ```

- Track an [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events)
  event:

  ```kotlin
  IterableApi
      .getInstance()
      .trackEmbeddedClick(
          embeddedMessage, 
          buttonId, 
          clickedUrl
      )
  ```

  To track clicks, Iterable's Android SDK calls:

  [`POST /api/embedded-messaging/events/click`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-click)

## Want to learn more?

- [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).
- The [GitHub repository for Iterable's Android SDK](https://github.com/iterable/iterable-android-sdk).
  In particular, these files:
  - [`IterableEmbeddedManager.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/IterableEmbeddedManager.kt)
  - [`EmbeddedSessionManager.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/EmbeddedSessionManager.kt)
  - [`IterableEmbeddedPlacement.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi/src/main/java/com/iterable/iterableapi/IterableEmbeddedPlacement.kt)
  - [`IterableEmbeddedView.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/java/com/iterable/iterableapi/ui/embedded/IterableEmbeddedView.kt)
  - [`IterableEmbeddedViewConfig.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/java/com/iterable/iterableapi/ui/embedded/IterableEmbeddedViewConfig.kt)
  - [`IterableEmbeddedViewType.kt`](https://github.com/Iterable/iterable-android-sdk/blob/master/iterableapi-ui/src/main/java/com/iterable/iterableapi/ui/embedded/IterableEmbeddedViewConfig.kt)

