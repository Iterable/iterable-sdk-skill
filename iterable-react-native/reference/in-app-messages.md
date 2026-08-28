---
slug: in-app-messages
feature: in-app-messages
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: In-App Messages with Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/360045714172
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/in-app-messages/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: f16e23544e5cb8db400eda069e97955e7458e89e
fetched_at: 2026-08-28T14:44:26.833Z
summary: Iterable's React Native SDK makes it possible to display in-app
  messages, customize them, and track events related to their usage.
---
# In-App Messages with Iterable's React Native SDK

Iterable's React Native SDK makes it possible to display in-app messages,
customize them, and track events related to their usage. 

## Overview

By default, Iterable's React Native SDK displays all in-app messages that it
receives, and tracks events when a user interacts with them. 

Alternatively, you can customize your app so that it skips the display of
certain in-app messages and then displays them later (in whatever order you
wish).  To manually display an in-app message, you can take one of two
approaches:

- Using the SDK's default display functionality
- With custom rendering that you provide (when you render a message in this way,
  you'll also need to track events and consume the messages).

The methods described in this document help you customize your app's handling
of in-app messages.

## Identify the user

Before you call the methods described below, [identify your app's user](https://iterable.zendesk.com/hc/articles/360045714152)
so that Iterable knows which profile to update.

## Showing or skipping an incoming in-app message

When Iterable retrieves in-app messages, it passes them to the function stored
in the `inAppHandler` property of the [`IterableConfig`](#iterableconfig) object
that was passed to the SDK's `initialize` method.

- **Property declaration:**

  ```typescript
  inAppHandler?: (message: IterableInAppMessage) => IterableInAppShowResponse
  ```

  |Parameter Name|Description                                                |
  |:-------------|:----------------------------------------------------------|
  |`message`     |The incoming in-app message (an [`IterableInAppMessage`](#iterableinappmessage) object).|

- **Description**

  Implement this property to override default in-app message behavior. For 
  example, you might use [the custom payload](#inspecting-the-custom-payload-attached-to-an-in-app-message)
  associated with an incoming message to choose whether or not to display it, or
  you might inspect the `priorityLevel` property to determine the message's
  priority.

- **Example:**

  ```javascript
  config.inAppHandler = (message: IterableInAppMessage) => {
      return IterableInAppShowResponse.show
  }
  ```

  This example simply returns [`IterableInAppShowResponse.show`](#iterableinappshowresponse)
  for all incoming messages, indicating that the SDK should display them in
  the app. Alternatively, you could specify `IterableInappShowResponse.skip`.

## Getting the local queue of message

To get a list of the current user's in-app messages, call the `getMessages` 
method on the static `inAppManager` property (an [`IterableInAppManager`](#iterableinappmanager) 
object) of an `Iterable` instance. 

- **Method declaration:**

  ```typescript
  getMessages(): Promise<Array<IterableInAppMessage>>
  ```

  This method returns a `Promise`. Use `then` to get the array of 
  [`IterableInAppMessage`](#iterableinappmessage) objects.

- **Description:**

  Returns the user's list of in-app messages. This method does not cause the app
  to immediately check for new in-app messages on the server, since the SDK
  keeps the list in sync.

- **Example:**

  ```javascript
  Iterable.inAppManager.getMessages().then(messages => {
    messages.forEach(message => {
      console.log(JSON.stringify(message, null, 2))
    });
  })
  ```

  This example grabs the user's list of messages and outputs them to the 
  console. For example, on the console, a single message would look something 
  like this:

  ```json
  {
    "campaignId": 1348743,
    "messageId": "9c438a20d26e4e9f8ad4edea23f811cd",
    "trigger": {
      "type": 0
    },
    "createdAt": "2020-07-14T16:46:44.463Z",
    "expiresAt": "2020-10-12T16:46:44.463Z",
    "saveToInbox": false,
    "customPayload": {
      "promotion": "summer sale"
    },
    "read": false
  }
  ```

## Getting the local queue of inbox messages

To get a list of the current user's in-app messages designated for the mobile
inbox, call the `getInboxMessages` method on the static `inAppManager` property
(an [`IterableInAppManager`](#iterableinappmanager) object) of an `Iterable`
instance. 

- **Method declaration:**

  ```typescript
  getInboxMessages(): Promise<Array<IterableInAppMessage>>
  ```

  This method returns a `Promise`. Use `then` to get the array of 
  [`IterableInAppMessage`](#iterableinappmessage) objects.

- **Description:**

  Returns the user's list of in-app messages designated for the mobile inbox.
  This method does not cause the app to immediately check for new in-app
  messages on the server, since the SDK keeps the list in sync.

- **Example:**

  ```javascript
  Iterable.inAppManager.getInboxMessages().then(messages => {
    messages.forEach(message => {
      console.log(JSON.stringify(message, null, 2))
    });
  })
  ```

  This example grabs the user's list of messages and outputs them to the console. 
  For example, on the console, a single message would look something like this:

  ```json
  {
    "campaignId": 1348743,
    "messageId": "9c438a20d26e4e9f8ad4edea23f811cd",
    "trigger": {
      "type": 0
    },
    "createdAt": "2020-07-14T16:46:44.463Z",
    "expiresAt": "2020-10-12T16:46:44.463Z",
    "saveToInbox": false,
    "customPayload": {
      "promotion": "summer sale"
    },
    "read": false
  }
  ```

## Showing an in-app message that was previously skipped

If you skip showing an in-app message when it arrives, you can show it at another
time by calling the static `showMessage` method on the `inAppManager` property 
(an object of type [`IterableInAppManager`](#iterableinappmanager)) on an `Iterable` 
instance.

- **Method Declaration:**

  ```typescript
  showMessage(message: IterableInAppMessage, consume: boolean): Promise<string | undefined>
  ```

  |Parameter Name|Description                                                |
  |:-------------|:----------------------------------------------------------|
  |`message`     |The message to show (an [`IterableInAppMessage`](#iterableinappmessage) object).|
  |`consume`     |Whether or not the message should be consumed from the user's message queue.|

  This method returns a `Promise`. Use `then` to get the string it returns, which 
  corresponds to the URL of the button or link a user tapped in the in-app message 
  to close it.

- **Description:**

  Uses the SDK to render an in-app message, and consumes it if necessary.

- **Example:**

  ```javascript
  Iterable.inAppManager.showMessage(message, false).then(url => {
    console.log("url: " + url)
  });
  ```

## Removing an in-app message from the current user's queue

To remove an in-app message from the current user's queue, call the `removeMessage` 
method on the static `inAppManager` property (an object of type [`IterableInAppManager`](#iterableinappmanager)) 
on an `Iterable` instance.  This method calls the `inAppConsume` method internally.

- **Method Declaration:**

  ```typescript
  removeMessage(message: IterableInAppMessage, location: IterableInAppLocation, source: IterableInAppDeleteSource): void
  ```

  |Parameter Name|Description                                                |
  |:-------------|:----------------------------------------------------------|
  |`message`     |The message to remove (an [`IterableInAppMessage`](#iterableinappmessage) object).|
  |`location`    |The message's location—whether or not it's in a mobile inbox. An [`IterableInAppLocation`](#iterableinapplocation) object.|
  |`source`      |How a user deleted the message. An [`IterableInAppDeleteSource`](#iterableinappdeletesource) object.|

- **Description:**

  Removes the specified in-app message from the user's message queue.

- **Example:**

  ```javascript
  Iterable.inAppManager.removeMessage(message, IterableInAppLocation.inApp, IterableInAppDeleteSource.unknown);
  ```

## Setting the read status of an in-app message

To set the read status of an in-app message, call the `setReadForMessage` method
on the static `inAppManager` property (an object of type [`IterableInAppManager`](#iterableinappmanager)) 
of an `Iterable` instance.

- **Method Declaration:**

  ```typescript
  setReadForMessage(message: IterableInAppMessage, read: boolean): void
  ```

  |Parameter Name|Description                                                                               |
  |:-------------|:-----------------------------------------------------------------------------------------|
  |`message`     |The message to set status for. An [`IterableInAppMessage`](#iterableinappmessage) object.|
  |`read`        |Boolean value indicating if an in-app message is read.                                     |

- **Description:**

  Sets the read status of a specified in-app message.

- **Example:**

  ```javascript
  Iterable.inAppManager.setReadForMessage(message, true);
  ```

## Getting the HTML content of an in-app message

To get the HTML content of an in-app message, call the `getHtmlContentForMessage` 
method on the static `InAppManager` property (an object of type [`IterableInAppManager`](#iterableinappmanager)) 
of an `Iterable` instance.

- **Method Declaration:**

  ```typescript
  getHtmlContentForMessage(message: IterableInAppMessage): Promise<IterableHtmlInAppContent>
  ```

  |Parameter Name|Description                                                                                  |
  |:-------------|:--------------------------------------------------------------------------------------------|
  |`message`     |The message to get HTML content from. An [`IterableInAppMessage`](#iterableinappmessage) object.|

  This method returns a `Promise`. Use `then` to get the HTML content of the
  specified in-app message as an `IterableHtmlInAppContent` object.

- **Description:**

  Gets the HTML content of a specified in-app message.

- **Example:**

  ```javascript
  Iterable.inAppManager.getHtmlContentForMessage(message);
  ```

## Pausing or unpausing the automatic display of incoming in-app messages

To pause or unpause the automatic display of incoming in-app messages, call the
`setAutoDisplayPaused` method on the static `InAppManager` property (an object
of type [`IterableInAppManager`](#iterableinappmanager)) of an `Iterable`
instance.

- **Method Declaration:**

  ```typescript
  setAutoDisplayPaused(paused: Boolean): void
  ```

  |Parameter Name|Description                                                                               |
  |:-------------|:-----------------------------------------------------------------------------------------|
  |`paused`      |Boolean value that indicates whether or not to pause the automatic display of in-app messages.|

- **Description:**

  Pauses or unpauses the automatic display of incoming in-app messages. By default,
  automatic displaying is enabled.

- **Example:**

  ```javascript
  Iterable.inAppManager.setAutoDisplayPaused(paused);
  ```

## Inspecting the custom payload attached to an in-app message

To access the custom payload attached to an in-app message, use the `customPayload` 
property of the [`IterableInAppMessage`](#iterableinappmessage) instance.

- **Property declaration:**

  ```typescript
  readonly customPayload?: any
  ```

- **Description:**

  When building out the [template for an in-app message](https://support.iterable.com/hc/articles/360044425951),
  you can attach a custom payload of JSON data. Use this data to provide any
  extra information that might be useful to the app.

- **Example:**

  ```javascript
  Iterable.inAppManager.getMessages().then((messages) => {
    console.log("messages: " + messages.length);
    messages.forEach((message) => {
      console.log(JSON.stringify(message.customPayload, null, 2));
    });
  })
  ```

  This example outputs the JSON payload associated with each in-app message in
  the users's queue.

## Displaying an in-app message in a custom way

To display an in-app message in a custom way:

1. Send the message with a custom payload that includes any data you'll need to
   display when rendering the in-app message.

   To indicate that the in-app message requires custom display, you might include
   a `customDisplay` property (along with any other relevant data) in its custom 
   payload:

   ```json
   {
     "customDisplay": true,
     "promotionTitle": "Summer Sale",
     "promotionText": "Everything is 50% off."
   }
   ```

   :::tip TIP
   When using Iterable to specify the custom payload for an in-app message, 
   use merge tags to include dynamic data. For example, this custom
   payload includes the user's email in the custom payload:

   ```json
   {
     "email": "{{email}}"
   }
   ```
   :::

2. In your mobile app, use the [`inAppHandler`](#showing-or-skipping-an-incoming-in-app-message)
   to skip the default display for messages that require custom rendering. For
   example, to check for the `customDisplay` boolean in the message's payload:

   ```javascript
   config.inAppHandler = (message: IterableInAppMessage) => {
     if (message.customPayload.customDisplay == true) {
       return IterableInAppShowResponse.skip
     } else {
       return IterableInAppShowResponse.show
     }
   };

3. Whenever your app decides to show the custom in-app message, render it with a
   custom interface of your own design. As a trivial example, this code uses an alert
   to display information from the example in-app message described above:

   ```javascript
   Alert.alert(message.customPayload.promotionTitle, message.customPayload.promotionText);
   ```

4. Be sure to handle event tracking ([open](#tracking-in-app-message-opens, 
   [click](#tracking-in-app-message-clicks), and [close](#tracking-in-app-message-closes))
   and to [consume the in-app message](#consuming-an-in-app-message) after the
   user views it.

## Tracking in-app message opens

Iterable's SDK automatically tracks in-app message opens when you use the SDK's
default rendering. However, it's also possible to manually track these events by
calling the static `trackInAppOpen` method on the `Iterable` class:

- **Method declaration:**

  ```typescript
  static trackInAppOpen(
    message: IterableInAppMessage, 
    location: IterableInAppLocation
  )
  ```

  |Parameter Name|Description                                                |
  |:-------------|:----------------------------------------------------------|
  |`message`     |The in-app message (an [`IterableInAppMessage`](#iterableinappmessage) object).|
  |`location`    |The location of the in-app message (an [`IterableInAppLocation`](#iterableinapplocation) object). Useful for determining if the messages is in a mobile inbox.|

- **Description:**

  Creates an `inAppOpen` event on the user's profile.

- **Example:**

  ```javascript
  Iterable.trackInAppOpen(messages, IterableInAppLocation.inApp)
  ```

## Tracking in-app message clicks

Iterable's SDK automatically tracks in-app message clicks when you use the SDK's
default rendering. However, you can also manually track these events by calling
the static `trackInAppClick` method on the `Iterable` class.

- **Method declaration:**

  ```typescript
  static trackInAppClick(
    message: IterableInAppMessage, 
    location: IterableInAppLocation, 
    clickedUrl: string
  )
  ```

  |Parameter Name|Description|
  |:-------------|:----------------------------------------------------------|
  |`message`     |The in-app message (an [`IterableInAppMessage`](#iterableinappmessage) object).|
  |`location`    |The location of the in-app message (an [`IterableInAppLocation`](#iterableinapplocation) object). Useful for determining if the messages is in a mobile inbox.|
  |`clickedUrl`  |The URL clicked by the user.                               |

- **Description:**

  Creates an `inAppClick` event on the user's profile.

- **Example:**

  ```javascript
  Iterable.trackInAppClick(message, IterableInAppLocation.inapp, "https://example.com")
  ```

## Tracking in-app message closes

Iterable's SDK automatically tracks in-app message close events when you use the
SDK's default rendering. However, it's also possible to manually track these
events by calling the static `trackInAppClose` method on the `Iterable` class.

- **Method declaration:**

  ```typescript
  static trackInAppClose(
    message: IterableInAppMessage, 
    location: IterableInAppLocation, 
    source: IterableInAppCloseSource, 
    clickedUrl: string
  )
  ```

  |Parameter Name|Description|
  |:-------------|:----------------------------------------------------------|
  |`message`     |The in-app message (an [`IterableInAppMessage`](#iterableinappmessage) object).|
  |`location`    |The location of the in-app message (an [`IterableInAppLocation`](#iterableinapplocation) object). Useful for determining if the messages is in a mobile inbox.|
  |`source`      |How the in-app message was closed (an [`IterableInAppCloseSource`](#iterableinappclosesource) object).|
  |`clickedUrl`  |The URL clicked by the user.                               |

- **Description:**

  Creates an `inAppClose` event on the user's profile.

- **Example:**

  ```javascript
  Iterable.trackInAppClose(message, IterableInAppLocation.inApp, IterableInAppCloseSource.back, "https://example.com")
  ```

  This example creates an `inAppClose` event, for the provided message.

## Consuming an in-app message

After a user has read an in-app message, you can _consume_ it so that it's no
longer in their queue of messages. When you use the SDK's default rendering for 
in-app messages, it handles this automatically. However, you can also use this
method to do it manually (for example, after rendering an in-app message in a
custom way).

- **Method declaration:**

  ```typescript
  static inAppConsume(message: IterableInAppMessage, location: IterableInAppLocation, source: IterableInAppDeleteSource) {
  ```

  |Parameter Name|Description|
  |:-------------------|:--------------------------------------------------------|
  |`message`  |The in-app message to consume (an [`IterableInAppMessage`](#iterableinappmessage) object).                                    |
  |`location` |The message's location (whether or not it's in a mobile inbox (an [`IterableInAppLocation`](#iterableinapplocation) object).|
  |`source`   |How a user chose to delete the message. Use with a mobile inbox (an [`IterableInAppDeleteSource`](#iterableinappdeletesource) object).|

- **Description:**

  Creates an `inAppDelete` event (unless otherwise specified) and removes the specified message from the user's message queue.

- **Example:**

  ```javascript
  Iterable.inAppConsume(message, IterableInAppLocation.inApp, IterableInAppDeleteSource.unknown)
  ```
  
  This example consumes the message stored in the `message` variable. Specifying
  a `source` of `IterableInAppDeleteSource.unknown` prevents an `inAppDelete`
  event from being created.

## Helper classes

The methods described in this guide rely on various classes, described below.

### IterableConfig

A set of configuration options passed to the SDK's initialize method. Includes
properties such as `pushIntegrationName`, `autoPushRegistration` and 
`inAppDisplayInterval`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/core/classes/IterableConfig.ts).

### IterableInAppManager

A class that manages in-app messages. Can be used to get access to a list of a
user's in-app messages, show a message, remove a message, or mark a message
as read (locally). [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/classes/IterableInAppManager.ts).

### IterableInAppLocation

An enum that describes the various places that an in-app message can exist:
`inApp` or `inbox`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/enums/IterableInAppLocation.ts).

### IterableInAppCloseSource

An enum that describes the various ways in which an in-app message might have 
been closed: `back`, `link` or `unknown`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/enums/IterableInAppCloseSource.ts).

### IterableInAppDeleteSource

An enum that describes the various ways in which an in-app message might have
been deleted: `inboxSwipe`, `deleteButton` or `unknown`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/enums/IterableInAppDeleteSource.ts).

### IterableInAppShowResponse

An enum that describes two display options for an incoming in-app message: `show` 
or `skip`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/enums/IterableInAppShowResponse.ts).

### IterableInAppMessage

A class that represents an in-app message. Contains various properties, such as
`campaignId`, `templateId` and `customPayload`. [Source code](https://github.com/Iterable/react-native-sdk/blob/master/src/inApp/classes/IterableInAppMessage.ts).
