---
slug: embedded-messages-with-iterables-ios-sdk
feature: embedded-messaging
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Embedded Messages with Iterable's iOS SDK
source_url: https://support.iterable.com/hc/articles/23061840746900
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/embedded-messaging/embedded-messages-with-iterables-ios-sdk/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 22ec62ce9f70c9153a2aed819cbf1dc3b619e2f1
fetched_at: 2026-10-02T13:52:10.888Z
summary: This article describes the steps you'll need to follow to use
  Iterable's iOS SDK to display embedded messages in your mobile app.
---
# Embedded Messages with Iterable's iOS SDK

> [!NOTE]
> To add Embedded Messaging to your Iterable account, talk to your customer success 
> manager.

This article describes the steps you'll need to follow to use Iterable's iOS
SDK to display embedded messages in your mobile app.

This document describes the necessary steps only to use embedded messaging. To 
learn about more SDK options, read [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152).

## Step 1: Coordinate with your marketing and design teams

First, collaborate with your marketing and design teams to determine:

- Where you'll display embedded messages in your apps (where your _placements_ go).
- Each placement's Iterable-assigned numeric ID (so you can display the right 
  messages in the right places).
- The data to display in each placement's messages. This determines what fields
  your app will expect to find in an embedded message payload.
- The message design for each of your placements.

## Step 2: Create a Mobile API key

To use Iterable's iOS SDK to display embedded messages, you'll need a mobile API 
key. To learn how to create one, read [Creating API keys](https://support.iterable.com/hc/articles/360043464871#creating-api-keys)

## Step 3: Install Iterable's iOS SDK in your app

To learn how to install Iterable's iOS SDK in your app, read [Install the SDK](https://support.iterable.com/hc/articles/360035018152#step-2-install-the-sdk).
Embedded Messaging is supported by versions [6.5.0+](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.5.0)
of Iterable's iOS SDK.

## Step 4: Configure the SDK

Next, configure the SDK, specify a URL handler and a custom action handler,
enable embedded messaging, set allowed URL protocols, initialize the SDK with an 
API key, and identify the user.

For example:

```swift
let config = IterableConfig()
config.urlDelegate = self
config.customActionDelegate = self
config.enableEmbeddedMessaging = true
// Specify the URL schemes you're expecting to receive in the campaigns you 
// send with Iterable. The SDK passes URLs with these URL schemes to your URL 
// handler, which can then handle them as necessary. For example, if you 
// indicate that "mycompany" is an allowed protocol, the SDK will pass URLs 
// such as "mycompany://profile" to your URL handler, which can respond as
// needed. For example, for "mycompany://profile", it might deep link to 
// the app's user profile screen.
config.allowedProtocols = ["mycompany"]

IterableApi.initialize(apiKey: apiKey, config:config)

IterableAPI.email = email
// IterableAPI.userId = userId
```

> [!NOTE]
> If your project is hosted on [Iterable's EDC](https://support.iterable.com/hc/articles/17572750887444),
> you'll need to [configure the SDK appropriately](https://support.iterable.com/hc/articles/360035018152#step-6-2-if-necessary-configure-the-sdk-to-use-iterable-s-edc).

### Step 4.1: Define a URL handler

In the example SDK configuration code above, notice that on `IterableConfig`, 
`urlDelegate` is set to an object that conforms to protocol `IterableURLDelegate`
(in this case, `self`). The SDK uses the `urlDelegate` to handle two types of
URLs: 

- Standard URLs, such as `https://example.com/product/123`.
- URLs with allowed custom URL schemes, such as `mycompany://profile`. The SDK
  ignores URLs that use custom URL schemes not specified as allowed protocols
  on `IterableConfig` (see above).

When a user clicks a button or a link on an incoming message, and the click is 
associated with one of the two URL types listed above, the SDK passes that URL to
the URL handler. Then, the URL handler can handle (or not handle) it as it makes
sense. For example, it might open the link in a browser or open it as a deep link.

Your URL handler must conform to protocol `IterableURLDelegate`, which specifies
a method for URL handling:

```swift
@objc(handleIterableURL:context:)
func handle(
    iterableURL url: URL, 
    inContext context: IterableActionContext
) -> Bool
```

This method should return `true` for URLs it can handle, and `false` for URLs it
cannot handle. 

When the URL handler can't handle a given URL, the SDK checks for another
installed app that can handle that URL (for example, a web browser). If there
are no other apps that can handle the URL, the SDK does nothing.

Here's an example implementation:

```swift
func handle(iterableURL url: URL, inContext _: IterableActionContext) -> Bool {
    let urlString = url.absoluteString
    // For example, urlString might be: "mycompany://profile"
    if(urlString.contains("mycompany://profile")) {
        // Navigate the user to the profile page...
        return true
    }
    return false
}
```

In this sample, `handle` reponds to `mycompany://profile` URLs by navigating the
user to the user profile screen. Then, it returns `true` to indicate that it
handled the URL.

Implementations of this method will vary, depending on your app architecture
and the URLs you need to handle. However, it's important to remember that this 
method is shared across message mediums. Make sure to handle URLs you might 
receive from any message type, not just embedded messages.

### Step 4.2: Define a custom action handler

Custom actions represent custom functionality you'd like your app to execute — 
maybe a deep link, a style update, or another behavior of some kind. Custom
actions use the `action://` URL scheme.

> [!NOTE]
> In-app messages also support `iterable://dismiss` and `iterable://delete` custom
> actions. Embedded messages do not yet support these actions. The `iterable://`
> URL scheme is reserved for Iterable-specific actions pre-defined by the SDK.
>
> For tips on alternatives to a dismiss action, read [Closing, dismissing, or hiding an embedded message](#closing-dismissing-or-hiding-an-embedded-message).

Similar to your URL handler, the object specified on `IterableConfig` as your 
`customActionDelegate` serves as your app's central handler for custom actions.
When a user clicks a button or a link associated with a custom action, this
action is passed to your custom action handler, where you can deal with it
however necessary (usually by executing custom functionality of some kind).

Your custom action handler must conform to protocol `IterableCustomActionDelegate`, 
which specifies a method for custom action handling:

```swift
@objc(handleIterableCustomAction:context:)
func handle(iterableCustomAction action: IterableAction, inContext context: IterableActionContext) -> Bool
```

This method should return `true` when it can handle the custom action URL, and 
`false` when it cannot. When it returns `false`, the custom action is dropped —
since custom actions are special, non-standard URLs, they cannot be opened by
a web browser.

For example, here's a sample custom action handler that handles an 
`action://joinClass/1` URL:

```swift
func handle(iterableCustomAction action: IterableAction, inContext context: IterableActionContext) -> Bool {
    // The custom action's full URL is stored in action.type
    if (action.type.contains("joinClass")) {
        // Sign the user up for a class ...
        return true
    }
    return true
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

To learn how to enable push notifications in your iOS app, read
[Enable Push Notifications](https://support.iterable.com/hc/articles/360035018152#step-7-enable-push-notifications).

## Step 6: Fetch embedded messages from Iterable

When your app first launches, and each time it comes to the foreground,
Iterable's iOS SDK automatically refresh a local, on-device cache of embedded
messages for the signed-in user. These are the messages the signed-in user is
_eligible_ to see.

> [!NOTE]
> A user is _eligible_ for an embedded message campaign if they're selected by its
> associated _eligibility list_ (a standard dynamic list in Iterable).

At key points during your app's lifecycle, you may want to manually refresh your
app's local cache of embedded messages. For example, as users navigate around, on
pull-to-refresh, etc.

To refresh the local cache of embedded messages, call:

```swift
IterableApi.getInstance().embeddedManager.syncMessages() { }
```

However, do not poll for new embedded messages at a regular interval.

> [!NOTE]
> Currently, Iterable's iOS SDK does not persist the embedded messages downloaded 
> from the server. When your app is restarted, Iterable's iOS SDK re-fetches the
> user's embedded messages from Iterable, which can cause the creation of multiple
> [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events) 
> events for the same message.

To fetch embedded messages, Iterable's iOS SDK calls:

[`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages)

## Step 7: Track message receipt

For each embedded message received from Iterable, Iterable's iOS SDK automatically 
tracks an [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events)
event. Each of these events represents the download of a particular message to a
particular device — but not, necessarily, that the message was displayed or seen
by the user.

To track message receipt, Iterable's iOS SDK calls:

[`POST /api/embedded-messaging/events/received`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-received)

## Step 8: Set up SDK listeners

Now, set up listeners for the SDK to call when new embedded messages arrive on
device, to tell your views to display messages as needed. To add these
listeners, call the following methods on `IterableEmbeddedManager`:

```swift
public func addUpdateListener(_ listener: IterableEmbeddedUpdateDelegate)
public func removeUpdateListener(_ listener: IterableEmbeddedUpdateDelegate)
```

Typically, a view that displays embedded messages adds itself as a listener when
it appears, and removes itself as a listener when it disappears. For example, on
a view controller:

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    IterableAPI.embeddedManager.addUpdateListener(self)
    // ...
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    IterableAPI.embeddedManager.removeUpdateListener(self)
    // ...
}
```

`IterableEmbeddedUpdateDelegate`, the protocol to which listeners must conform, declares these methods:

* `func onMessagesUpdated()` – Called by the SDK to tell your app that embedded messages have been updated, and that you can grab the local queue and display them.

* `func onEmbeddedMessagingDisabled()` – Called by the SDK when there's a failure fetching embedded messages from the server. Use this method to hide your embedded message display or show default content, as needed.

* `@objc optional func onEmbeddedMessagingSyncSucceeded()` – Called when an embedded messaging sync completes successfully. Use this method to update any loading state in your UI, or to log that the sync finished.

* `@objc optional func onEmbeddedMessagingSyncFailed(_ error: String?)` – Called when an embedded messaging sync fails. The `error` parameter contains a failure reason string, when available (for example, a network or server error message). Use this method to log failures, show fallback content, or surface non-sensitive error information to your users.

For example, a view registered as a listener might have implementations similar to:

```swift
extension MyEmbeddedViewController: IterableEmbeddedUpdateDelegate {
    func onMessagesUpdated() {
        // Fetch messages for the placement associated with the current view
        let embeddedMessages = IterableAPI.embeddedManager.getMessages(for: placementId)

        // Show or hide messages...
        // updateUI(with: embeddedMessages)
    }

    func onEmbeddedMessagingDisabled() {
        // Hide embedded UI or show default content
        // showFallbackContent()
    }

    func onEmbeddedMessagingSyncSucceeded() {
        // Stop loading indicators, confirm latest content is shown
        // hideLoadingSpinner()
    }

    func onEmbeddedMessagingSyncFailed(_ error: String?) {
        // Log or surface a non-sensitive error state
        // log("Embedded sync failed: \(error ?? "Unknown error")")
        // showEmbeddedErrorState()
    }
}
```

> [!TIP]
> You may want to check the local list of messages right when your view appears,
> as well as when the SDK calls `onMessagesUpdated`. That way, if there are
> messages already available for display when the view first appears, you can show
> them. Otherwise, you can display a loading spinner or hide the embedded message
> view altogether.

> [!WARNING]
> The SDK does not always call `onMessagesUpdated`,
> `onEmbeddedMessagingSyncSucceeded`, or `onEmbeddedMessagingSyncFailed` on the
> main thread. To prevent crashes, make sure you're on the main thread before
> updating your app's UI to display embedded messages.

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

> [!TIP]
> For a look at the JSON payload associated with an embedded message, see 
> [`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages).

### Out-of-the-box views

Iterable's iOS SDK provides an `IterableEmbeddedView` class you can use to
display embedded messages as a card, a banner, or a notification. For more 
information about out-of-the-box views, read [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).

You can customize out-of-the-box views, in some ways, to more closely match the
styles of your apps. 

Out-of-the-box views handle clicks, too. To do this, they automatically:

- Pass URLs and custom actions to the URL and custom action handlers you set up 
  in [step 4](#step-4-configure-the-sdk).
- Track [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events) 
  events.

> [!NOTE]
> When using out-of-the-box views to display embedded messages, you'll still need to 
> manually track sessions and impressions, as described in [step 10](#step-10-track-sessions-and-impression).

To use an out-of-the-box view, first create an `IterableEmbeddedViewConfig` object, 
to declare the styles you'd like the view to use:

```swift
// Grab your app's colors from wherever it makes sense.
let config = IterableEmbeddedViewConfig(
    backgroundColor: UIColor.white, 
    borderColor: UIColor.purple, 
    borderWidth: 1.0, 
    borderCornerRadius: 8.0, 
    primaryBtnBackgroundColor: UIColor.purple, 
    primaryBtnTextColor: UIColor.white, 
    secondaryBtnBackgroundColor: UIColor.white, 
    secondaryBtnTextColor: UIColor.purple, 
    titleTextColor: UIColor.black, 
    bodyTextColor: UIColor.black
)
```

Then, when it's time to display a message, create the `IterableEmbeddedView`:

```swift
let iterableEmbeddedView = IterableEmbeddedView(
    message: message,
    viewType: viewType,
    config: emViewConfig
)
```

This initializer takes three parameters:

- The `IterableEmbeddedMessage` to display.
- A value of type `IterableEmbeddedViewType`, an `enum` with three cases:
  - `banner`
  - `card`
  - `notification`
- The `IterableEmbeddedViewConfig` created above.

Then, add the view to your layout. It's important to fully specify the size
of the view, with minimum dimensions as described in [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).

For example, this code, in an iOS view controller, creates an `IterableEmbeddedView`.
Then, after adding it to the current view, it specifies constraints, indicating
how the out-of-the-box view should fit in the screen's overall layout:

```swift
let iterableEmbeddedView = IterableEmbeddedView(message:embeddedMessage, viewType:IterableEmbeddedViewType.card, config:config)
iterableEmbeddedView?.translatesAutoresizingMaskIntoConstraints = false
view.addSubview(iterableEmbeddedView!)
NSLayoutConstraint.activate([
    iterableEmbeddedView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
    iterableEmbeddedView.leadingAnchor.constraint(equalTo: view.leadingAnchor), constant: 10),
    iterableEmbeddedView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 10),
    iterableEmbeddedView.heightAnchor.constraint(equalToConstant: 300)
])
```

This is just an example. The specific approach you'll take when adding an
out-of-the-box view to your app depends on your app architecture.

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
Iterable's iOS SDK provides a session manager. Sessions and impressions are 
tracked in Iterable as [`embeddedSession`](https://support.iterable.com/hc/articles/23061677642260#embeddedsession-events) 
and [`embeddedImpression`](https://support.iterable.com/hc/articles/23061677642260#embeddedimpression-events) 
events.

### Step 10.1: Start a session

When a user comes to a screen or page in your app where embedded messages are
displayed (in one or more placements), use the session manager to start a
session. To start a session, call:

```swift
// When the screen that displays your embedded message is displayed or comes to
// the foreground
EmbeddedSessionManager.shared.startSession()
```

### Step 10.2: Start and pause impressions 

As messages appear or disappear during an ongoing embedded message session, use
the session manager to track message impressions. 

The session manager tracks the total number of times each message appears during
a session, and the total amount of time each message is on-screen across all
those appearances. To start and pause impressions, call:

```swift
// When a message appears, start an impression (associating it with a placement)
EmbeddedSessionManager.shared.startImpression(
    messageId: embeddedMessage.metadata.messageId, 
    placementId: embeddedMessage.metadata.placementId 
)

// When a message disappears…
EmbeddedSessionManager.shared.pauseImpression(
    messageId: embeddedMessage.metadata.messageId
)
```

> [!NOTE]
> An embedded message can disappear and reappear many times during a session.
> Because of this, when an embedded message disappears, you don't _end_ its
> impression — you _pause_ it. Then, you start the impression again if and when
> the message reappears. In other words, you start and end sessions, but you start 
> and _pause_ impressions.

Be sure to start and pause impressions when your app goes to and from the
background, too.

### Step 10.3: End the session, saving impression data to Iterable

When a user leaves a screen in your app where embedded messages are displayed,
use the session manager to end the active session. This causes the SDK to send
session and impression data back to the server.

To end a session, call:

```swift
// When a screen that displays embedded messages is dismissed 
// or goes to the background
EmbeddedSessionManager.shared.endSession()
```

To track sessions and impressions, Iterable's iOS SDK calls:

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

If you're using a custom view to display an embedded message, you'll need to 
handle clicks. As you instantiate custom embedded message views in your iOS
app:

- Add click handlers to the message's buttons (if the message has buttons), in
  whatever way makes sense for your app. 
- Set up a default click handler, too, for general clicks on the message
  (outside of any specific button or link). 

In your click handlers:

- Execute any necessary custom application logic (update the UI if needed, etc.).

- Call `handleEmbeddedClick` on `IterableEmbeddedManager`. This method forwards
  URLs and custom actions to the handlers you defined above. For example:

  ```swift
  IterableAPI.embeddedManager.handleEmbeddedClick(
      message: embeddedMessage,
      buttonIdentifier: buttonIdentifier
      clickedUrl: url
  )
  ```

- Track an [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events) 
  event:

  ```swift
  IterableAPI.track(
      embeddedMessageClick: embeddedMessage,
      buttonIdentifier: buttonIdentifier
      clickedUrl: url
  )
  ```
  To track clicks, Iterable's iOS SDK calls:

  [`POST /api/embedded-messaging/events/click`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-click)

## Want to learn more?

- [Out-of-the-Box Views for Embedded Messages](https://iterable.zendesk.com/hc/articles/23230946708244).
- The [GitHub repository for Iterable's iOS SDK](https://github.com/Iterable/iterable-swift-sdk).
  In particular, these files:
  - [`IterableEmbeddedManager.swift`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/Internal/IterableEmbeddedManager.swift)
  - [`EmbeddedSessionManager.swift`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/Internal/EmbeddedSessionManager.swift)
  - [`IterableEmbeddedMessage.swift`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/IterableEmbeddedMessage.swift)
  - [`IterableEmbeddedView.swift`](https://github.com/Iterable/iterable-swift-sdk/blob/master/swift-sdk/uicomponents/IterableEmbeddedView.swift)

