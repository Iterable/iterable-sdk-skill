---
slug: embedded-messages-with-iterables-react-native-sdk
feature: embedded-messaging
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Embedded Messages with Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/49144129810324
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/embedded-messaging/embedded-messages-with-iterables-react-native-sdk/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: 88948a289f4214d375316e4cd8ab8dca1af22120
fetched_at: 2026-08-28T14:44:26.871Z
summary: This article describes the steps you'll need to follow to use
  Iterable's React Native SDK to display embedded messages in your mobile app.
  It describes only the steps necessary to use embedded messaging. To learn
  about more SDK options, read [Overview of Iterable's React Native
  SDK](https://support.iterable.com/hc/articles/360045714072).
---
# Embedded Messages with Iterable's React Native SDK

> [!NOTE]
> To add Embedded Messaging to your Iterable account, talk to your customer success 
> manager.

This article describes the steps you'll need to follow to use Iterable's React Native SDK to display embedded messages in your mobile app. It describes only the steps necessary to use embedded messaging. To learn about more SDK options, read [Overview of Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714072).

## Step 1: Coordinate with your marketing and design teams

First, collaborate with your marketing and design teams to determine:

- Where you'll display embedded messages in your apps (where your _placements_ go).  
- Each placement's Iterable-assigned numeric ID (so you can display the right messages in the right places).  
- The data to display in each placement's messages. This determines what fields your app will expect to find in an embedded message payload.  
- The message design for each of your placements.

## Step 2: Create a mobile API key

To use Iterable's React Native SDK to display embedded messages, you'll need a mobile API key. To learn how to create one, read [Creating API keys](https://support.iterable.com/hc/articles/360043464871#creating-api-keys).

## Step 3: Install Iterable's React Native SDK in your app

To learn how to install Iterable's React Native SDK in your app, read [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132). Embedded Messaging is supported by version [**3.0.0+**](https://github.com/Iterable/react-native-sdk/releases/tag/3.0.0) of Iterable's React Native SDK.  

To install the latest version of Iterable’s React Native SDK, run the following in your project root:

```shell
## Yarn
yarn add @iterable/react-native-sdk@latest

## Npm
npm install @iterable/react-native-sdk@latest
```

## Step 4: Configure the SDK

Next, configure the SDK, specify a URL handler and a custom action handler, enable embedded messaging, set allowed URL protocols, initialize the SDK with an API key, and identify the user.

For example:

```ts
import { Iterable, IterableConfig } from '@iterable/react-native-sdk';

const config = new IterableConfig();

// Set up URL and custom action handlers (see below)
config.urlHandler = (url, context) => {
  // Handle URLs (see Step 4.1)
  return false;
};

config.customActionHandler = (action, context) => {
  // Handle custom actions (see Step 4.2)
  return false;
};

// Enable embedded messaging
config.enableEmbeddedMessaging = true;

// Define the URL schemes you expect to handle in your Iterable campaigns.
// The SDK will send URLs with these schemes to your URL handler for processing.
// For example, if you specify "mycompany" as an allowed protocol, the SDK will
// forward URLs such as "mycompany://profile" to your handler, allowing you to
// take any appropriate action -- such as deep linking the user directly to the 
// app’s profile screen.
config.allowedProtocols = ['mycompany'];

// Set up callbacks for embedded message updates
config.onEmbeddedMessageUpdate = () => {
  // Called when embedded messages are updated
  console.log('Embedded messages updated!');
};

config.onEmbeddedMessagingDisabled = () => {
  // Called when embedded messaging is disabled
  console.warn('Embedded messaging has been disabled');
};

// Initialize the SDK
await Iterable.initialize('<YOUR_API_KEY>', config);

// Set the user's email or userId
Iterable.setEmail('user@example.com');
// OR (do not do both)
Iterable.setUserId('userId');
```

> [!NOTE]
> If your project is hosted on [Iterable's EDC](https://support.iterable.com/hc/articles/17572750887444),
> you'll need to configure the SDK appropriately. See [Initialize Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132#step-6-initialize-iterable-s-react-native-sdk).

### Step 4.1: Define a URL handler

In the example SDK configuration code above, notice that on `IterableConfig`, `urlHandler` is set to a function that handles URLs. The SDK uses the `urlHandler` to handle two types of URLs:

- Standard URLs, such as `https://example.com/product/123`.  
- URLs with allowed custom URL schemes, such as `mycompany://profile`. The SDK ignores URLs that use custom URL schemes not specified as allowed protocols on `IterableConfig` (see above).

When a user clicks a button or a link on an embedded message, and the click is associated with one of the two URL types listed above, the SDK passes that URL to the URL handler. Then, the URL handler can handle (or not handle) it as it makes sense. For example, it might open the link in a browser or open it as a deep link.

Your URL handler function should return `true` for URLs it can handle, and `false` for URLs it cannot handle.

When the URL handler can't handle a given URL, the SDK checks for another installed app that can handle that URL (for example, a web browser). If there are no other apps that can handle the URL, the SDK does nothing.

Here's an example implementation:

```ts
config.urlHandler = (url: string, context: IterableActionContext) => {
  // For example, url might be: "mycompany://profile"
  if (url.includes('mycompany://profile')) {
    // Navigate the user to the profile page...
    navigation.navigate('Profile');
    return true;
  }
  return false;
};
```

In this sample, `urlHandler` handles `mycompany://profile` URLs by navigating the user to the user profile screen. Then, it returns `true` to indicate that it handled the URL.

Implementations of this method will vary, depending on your app architecture and the URLs you need to handle. However, it's important to remember that this method is shared across message mediums. Make sure to handle URLs you might receive from any message type, not just embedded messages.

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

Similar to your URL handler, the `customActionHandler` set on `IterableConfig` serves as your app's central handler for custom actions. When a user clicks a button or a link associated with a custom action, this action is passed to your custom action handler, where you can deal with it however necessary (usually by executing custom functionality of some kind).

Your custom action handler function should return `true` when it can handle the custom action URL, and `false` when it cannot. When it returns `false`, the custom action is dropped — since custom actions are special, non-standard URLs, they cannot be opened by a web browser.

For example, here's a sample custom action handler that handles an `action://joinClass/1` URL:

```ts
config.customActionHandler = (
  action: IterableAction, 
  context: IterableActionContext
) => {
  // The custom action's name is stored in action.type
  if (action.type.includes('joinClass')) {
    // Sign the user up for a class ...
    enrollUserInClass();
    return true;
  }
  return false;
};
```

Implementations of this method will vary. However, be sure to account for any specific custom actions you'll send to your app (in an embedded message, or in any other kind of message).

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

Specific implementation details vary depending on your application, SDK, and desired user experience.

## Step 5: Enable support for push notifications in your app

To alert your app when the signed-in user's embedded message _eligibility_ changes (that is, when they are newly eligible, or no longer eligible, for some embedded message campaign in your project), Iterable sends silent push notifications.

After receiving one of these silent push notifications, the SDK refreshes its local cache of embedded messages by re-fetching them from Iterable's API.

To learn how to enable push notifications in your React Native app, read [Push Notifications with Iterable's React Native SDK](https://support.iterable.com/hc/articles/360046134871).

## Step 6: Fetch embedded messages from Iterable

When your app first launches, and each time it comes to the foreground,
Iterable's React Native SDK automatically refreshes a local, on-device cache of
embedded messages for the signed-in user. These are the messages the signed-in
user is _eligible_ to see.

> [!NOTE]
> A user is _eligible_ for an embedded message campaign if they're selected by its
> associated _eligibility list_ (a standard dynamic list in Iterable).

At key points during your app's lifecycle, you may want to manually refresh your app's local cache of embedded messages. For example, as users navigate around, on pull-to-refresh, etc.

To refresh the local cache of embedded messages, call:

```ts
Iterable.embeddedManager.syncMessages();
```

However, do not poll for new embedded messages at a regular interval.

> [!NOTE]
> Currently, Iterable's React Native SDK does not persist the embedded messages downloaded from the server. When your app is restarted, Iterable's React Native SDK re-fetches the user's embedded messages from Iterable, which can cause the creation of multiple [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events) events for the same message.

To fetch embedded messages, Iterable's React Native SDK calls:

[`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages)

## Step 7: Track message receipt

For each embedded message received from Iterable, Iterable's React Native SDK automatically tracks an [`embeddedReceived`](https://support.iterable.com/hc/articles/23061677642260#embeddedreceived-events) event. Each of these events represents the download of a particular message to a particular device — but not, necessarily, that the message was displayed or seen by the user.

To track message receipt, Iterable's React Native SDK calls:

[`POST /api/embedded-messaging/events/received`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-received)

## Step 8: Set up SDK listeners

Now, set up listeners for the SDK to call when new embedded messages arrive on device, to tell your views to display messages as needed. You can set up these listeners through the `IterableConfig` object:

```ts
const config = new IterableConfig();

config.onEmbeddedMessageUpdate = () => {
  // Called when embedded messages are updated
  // Fetch messages for the placement(s) you want to display
  refreshEmbeddedMessages();
};

config.onEmbeddedMessagingDisabled = () => {
  // Called when embedded messaging is disabled
  // Hide embedded UI or show default content
  showFallbackContent();
};
```

These callbacks are triggered:

- `onEmbeddedMessageUpdate` – Called by the SDK to tell your app that embedded messages have been updated, and that you can grab the local queue and display them.  
    
- `onEmbeddedMessagingDisabled` – Called by the SDK when there's a failure fetching embedded messages from the server. Use this method to hide your embedded message display or show default content, as needed.

For example, in a React component:

```tsx
import React, { useEffect, useState } from 'react';
import { View, Text } from 'react-native';
import { Iterable, IterableConfig, IterableEmbeddedMessage } from '@iterable/react-native-sdk';

function EmbeddedMessageScreen() {
  const [messages, setMessages] = useState<IterableEmbeddedMessage[]>([]);
  const [isDisabled, setIsDisabled] = useState(false);
  const [isIterableConfigured, setIsIterableConfigured] = useState(false);

  useEffect(() => {
    const config = new IterableConfig();

    config.onEmbeddedMessageUpdate = () => {
      // handle update
      setIsDisabled(false);
    };

    config.onEmbeddedMessagingDisabled = () => {
      // handle disabled
      setIsDisabled(true);
    };

    // initialize iterable and set email
    // Note: Callbacks are set during SDK initialization in your app setup,
    // not in individual components. This is just for illustration.
    Iterable.initialize(API_KEY, config)
      // set email
      .then(() => Iterable.setEmail('myemail@address.com'))
      // fetch initial messages
      .then(() => fetchMessages());
  }, []);

  const fetchMessages = async () => {
    const placementIds = [123, 456]; // Your placement IDs
    const embeddedMessages = await Iterable.embeddedManager.getMessages(placementIds);
    setMessages(embeddedMessages);
  };

  if (isDisabled) {
    return <Text>Embedded messages are currently unavailable</Text>;
  }

  return (
    <View>
      {messages.map((message) => (
        <EmbeddedMessageView key={message.metadata.messageId} message={message} />
      ))}
    </View>
  );
}
```

> [!TIP]
> You may want to check the local list of messages right when your view appears,
> _as well as_ when the SDK calls `onEmbeddedMessageUpdate`. That way, if there are
> messages already available for display when the view first appears, you can show
> them. Otherwise, you can display a loading spinner or hide the embedded message
> view altogether.

## Step 9: Display embedded messages

For each incoming embedded message, use the fields included in the message to populate the message content and set its styles. For example, you might use one `IterableEmbeddedMessage` to drive the creation of a single banner message, or many of them to drive the creation of a carousel.

As you're setting up your embedded message views:

- Associate each message view with its corresponding `IterableEmbeddedMessage` object, so you have access to the underlying message (and its `messageId`) when tracking events.  
- Add click handlers where necessary, so you can handle clicks and track them in Iterable.  
- As messages appear and disappear, track impressions (described in the next section).

`IterableEmbeddedMessage` objects have various fields, corresponding to the data included with your campaign:

- **`metadata`** – Identifying information about the campaign.
  - `messageId` – The ID of the message.  
  - `placementId` – The ID of the placement associated with the message.  
  - `campaignId` – The ID of the campaign associated with the message.  
  - `isProof` – Whether or not the campaign is a test message.

- **`elements`** – What to display, and how to handle interaction.
  - `title` – The message's title text.  
  - `body` – The message's body text.  
  - `mediaUrl` – The URL of an image associated with the message.  
  - `mediaUrlCaption` – Text description of the image.  
  - `defaultAction` – What to do when a user clicks on the message (outside of its buttons).  
  - `buttons` – Buttons to display.  
  - `text` – Extra data fields. Not for display.

- **`payload`** – Custom JSON data included with the campaign.

Use this data to build a custom view.

> [!TIP]
> For a look at the JSON payload associated with an embedded message, see 
> [`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages).

Below is an example of creating a custom embedded message view in React Native:

```tsx
import React from 'react';
import { View, Text, Image, TouchableOpacity, StyleSheet } from 'react-native';
import { IterableEmbeddedMessage } from '@iterable/react-native-sdk';

interface EmbeddedMessageViewProps {
  message: IterableEmbeddedMessage;
  onPress: () => void;
  onButtonPress: (buttonId: string) => void;
}

function EmbeddedMessageView({ message, onPress, onButtonPress }: EmbeddedMessageViewProps) {
  const { elements } = message;

  return (
    <TouchableOpacity style={styles.container} onPress={onPress}>
      {elements?.mediaUrl && (
        <Image 
          source={{ uri: elements.mediaUrl }} 
          style={styles.image}
          accessibilityLabel={elements.mediaUrlCaption || undefined}
        />
      )}
      
      {elements?.title && (
        <Text style={styles.title}>{elements.title}</Text>
      )}
      
      {elements?.body && (
        <Text style={styles.body}>{elements.body}</Text>
      )}
      
      {elements?.buttons && elements.buttons.length > 0 && (
        <View style={styles.buttonContainer}>
          {elements.buttons.map((button) => (
            <TouchableOpacity
              key={button.id}
              style={styles.button}
              onPress={() => onButtonPress(button.id)}
            >
              <Text style={styles.buttonText}>{button.title}</Text>
            </TouchableOpacity>
          ))}
        </View>
      )}
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: 16,
    backgroundColor: '#fff',
    borderRadius: 8,
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  image: {
    width: '100%',
    height: 200,
    borderRadius: 8,
    marginBottom: 12,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
  },
  body: {
    fontSize: 14,
    color: '#666',
    marginBottom: 12,
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
    paddingVertical: 12,
    paddingHorizontal: 16,
    backgroundColor: '#007AFF',
    borderRadius: 6,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});

export default EmbeddedMessageView;
```

### Out-of-the-box views

Iterable's React Native SDK provides an `IterableEmbeddedView` component you can use to
display embedded messages as a card, a banner, or a notification. For more 
information about out-of-the-box views, read [Out-of-the-Box Views for Embedded
Messages](https://support.iterable.com/hc/en-us/articles/23230946708244-Out-of-the-Box-Views-for-Embedded-Messages).

> [!NOTE]
> When using out-of-the-box views to display embedded messages, you'll still need to 
> manually track sessions and impressions, as described in [step 10](#step-10-track-sessions-and-impressions).

You can customize out-of-the-box views to more closely match the styles of your
apps using the `config` property. 

Out-of-the-box views handle clicks, too. To do this, they automatically:

- Pass URLs and custom actions to the URL and custom action handlers you set up 
  in [step 4](#step-4-configure-the-sdk).
- Track [`embeddedClick`](https://support.iterable.com/hc/articles/23061677642260#embeddedclick-events) events.

Optional `onButtonClick` and `onMessageClick` callbacks on `IterableEmbeddedView`
run **in addition** to that default behavior, so you can log or customize UX without
replacing Iterable’s action handling.

Render `IterableEmbeddedView` with a view type, the `IterableEmbeddedMessage`
to show, and optionally click callbacks and a config:

```tsx
import {
  IterableEmbeddedView,
  IterableEmbeddedViewType,
  type IterableEmbeddedMessage,
  type IterableEmbeddedMessageElementsButton,
  type IterableEmbeddedViewConfig,
} from '@iterable/react-native-sdk';

// `viewType` — which out-of-the-box layout to use
const viewType = IterableEmbeddedViewType.Card;

// `message` — typically from Iterable.embeddedManager.getMessages(...)
const message: IterableEmbeddedMessage = { /* ... */ };

// `config` -- optional styling updates for the component
const config: IterableEmbeddedViewConfig = {
  backgroundColor: '#FFFFFF',
  borderColor: '#000000',
  borderWidth: 1,
  borderCornerRadius: 8,
  primaryBtnBackgroundColor: '#0000FF',
  primaryBtnTextColor: '#FFFFFF',
  secondaryBtnBackgroundColor: '#FFFFFF',
  secondaryBtnTextColor: '#000000',
  titleTextColor: '#000000',
  bodyTextColor: '#000000',
};

return (
  <IterableEmbeddedView
    viewType={viewType}
    message={message}
    config={config}
    onButtonClick={(button: IterableEmbeddedMessageElementsButton) => {
      /* optional extra logic */
    }}
    onMessageClick={() => {
      /* optional extra logic */
    }}
  />
);
```

Available options for `IterableEmbeddedView`:
| Property | Description | Options |
|---|---|---|
| `viewType`<span style="color: red">*</span> | The type of view to render.  | `IterableEmbeddedViewType.Card` `IterableEmbeddedViewType.Banner` `IterableEmbeddedViewType.Notification` |  
| `message`<span style="color: red">*</span> | The message to render.  Retrieved from `Iterable.embeddedManager.getMessages(...)`. |   |  
| `config`  | Customizable styling options. |   |  
| `onButtonClick` | A callback for when the button is pressed containing a reference to the clicked button JSON and the message JSON. |   |  
| `onMessageClick` | A callback for when the message is pressed containing a reference to the message JSON. |   |  

Place the component inside your React Native layout like any other view—for example
inside a `ScrollView`, a screen, or a conditional branch when you have a message to
show. Give the surrounding layout appropriate flex, padding, and minimum size where
needed; see 
[Out-of-the-Box Views for Embedded Messages](https://support.iterable.com/hc/articles/23230946708244)
for general sizing guidance. You might keep an empty state, loading UI, or nothing in
the same slot when no embedded message is available—the exact pattern depends on your
app architecture.

## Step 10: Track sessions and impressions

A _session_ is a period of time when a user is on a screen or page that can display embedded messages.

Every session can have many _impressions_. An impression represents the on-screen appearances of a given embedded message, in context of a session. Each impression tracks:

- The total number of times a message appears during a session.  
- The total amount of time that message was visible, across all its appearances in the session.

To help you track message sessions and impressions (views of a message), Iterable's React Native SDK provides session management methods. Sessions and impressions are tracked in Iterable as [`embeddedSession`](https://support.iterable.com/hc/articles/23061677642260#embeddedsession-events) 
and [`embeddedImpression`](https://support.iterable.com/hc/articles/23061677642260#embeddedimpression-events) events.

### Step 10.1: Start a session

When a user comes to a screen or page in your app where embedded messages are displayed (in one or more placements), start a session. To start a session, call:

```ts
// When the screen that displays your embedded message is displayed or comes to
// the foreground
Iterable.embeddedManager.startSession();
```

For example, in a React component:

```tsx
import { useEffect } from 'react';
import { useFocusEffect } from '@react-navigation/native';
import { Iterable } from '@iterable/react-native-sdk';

function EmbeddedMessageScreen() {
  useFocusEffect(
    React.useCallback(() => {
      // Start session when screen comes into focus
      Iterable.embeddedManager.startSession();
    
      return () => {
      // End session when screen loses focus
      Iterable.embeddedManager.endSession();
    };
  });

  // ... rest of component
}
```

### Step 10.2: Start and pause impressions

As messages appear or disappear during an ongoing embedded message session, use the SDK to track message impressions.

The SDK tracks the total number of times each message appears during a session, and the total amount of time each message is on-screen across all those appearances. To start and pause impressions, call:

```ts
// When a message appears, start an impression (associating it with a placement)
Iterable.embeddedManager.startImpression(
  embeddedMessage.metadata.messageId,
  embeddedMessage.metadata.placementId
);

// When a message disappears, pause the impression
Iterable.embeddedManager.pauseImpression(
  embeddedMessage.metadata.messageId
);
```

> [!NOTE]
> An embedded message can disappear and reappear many times during a session. Because of this, when an embedded message disappears, you don't _end_ its impression — you _pause_ it. Then, you start the impression again if and when the message reappears. In other words, you start and end sessions, but you start and _pause_ impressions.

Be sure to start and pause impressions when your app goes to and from the background, too.

Here's an example using React hooks:

```ts
import { useEffect } from 'react';
import { AppState } from 'react-native';
import { Iterable, IterableEmbeddedMessage } from '@iterable/react-native-sdk';

function useEmbeddedImpression(message: IterableEmbeddedMessage | null, isVisible: boolean) {
  useEffect(() => {
    if (!message || !isVisible) return;

    // Start impression when message becomes visible
    Iterable.embeddedManager.startImpression(
      message.metadata.messageId,
      message.metadata.placementId
    );

    // Handle app state changes
    const subscription = AppState.addEventListener('change', (nextAppState) => {
      if (nextAppState === 'background' || nextAppState === 'inactive') {
        // Pause the impression as app is not visible
        Iterable.embeddedManager.pauseImpression(message.metadata.messageId);
      } else if (nextAppState === 'active') {
        // Start the impression as the user returns to the app
        Iterable.embeddedManager.startImpression(
          message.metadata.messageId,
          message.metadata.placementId
        );
      }
    });

    return () => {
      // Pause impression when component unmounts or message changes
      Iterable.embeddedManager.pauseImpression(message.metadata.messageId);
      subscription.remove();
    };
  }, [message, isVisible]);
}
```

### Step 10.3: End the session, saving impression data to Iterable

When a user leaves a screen in your app where embedded messages are displayed, end the active session. This causes the SDK to send session and impression data back to the server.

To end a session, call:

```ts
// When a screen that displays embedded messages is dismissed 
// or goes to the background
Iterable.embeddedManager.endSession();
```

To track sessions and impressions, Iterable's React Native SDK calls:

[`POST /api/embedded-messaging/events/session`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-session)

## Step 11: Handle clicks

Finally, configure your app to handle clicks on embedded messages. When a user clicks a link or a button, it can be associated with:

- A standard URL (for example, `https://example.com/products/1`).  
- A custom URL scheme (for example, `mycompany://profile`).  
- A custom action (for example, `action://joinClass/1`).

Above, you set up a [URL handler](#step-4-1-define-a-url-handler) for handling
standard URLs and custom URL schemes, and a [custom action handler](#step-4-2-define-a-custom-action-handler) 
for handling custom action URLs.

Now, listen for clicks on your embedded message views, and then tell the SDK to
invoke the URL or the custom action handler (depending on the type of URL that
was clicked).

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
React Native app:

- Add click handlers to the message's buttons and links. Do this however it makes
  sense for your app.
- Set up a default click handler, to handle clicks on the message but outside
  of any particular button or link.

The SDK provides a convenient `handleClick` method on `Iterable.embeddedManager`
to make handling this functionality easier.  This function will both delegate
the click and track it correctly.  Example:

```ts
import { Iterable, IterableEmbeddedMessage } from '@iterable/react-native-sdk';

function handleEmbeddedMessageClick(message: IterableEmbeddedMessage) {
  // Handle click on the message body (using default action)
  Iterable.embeddedManager.handleClick(
    message,
    null, // No button ID for default action
    message.elements?.defaultAction
  );
}

function handleButtonClick(message: IterableEmbeddedMessage, buttonId: string) {
  // Find the button that was clicked
  const button = message.elements?.buttons?.find(b => b.id === buttonId);
  
  if (button) {
    Iterable.embeddedManager.handleClick(
      message,
      buttonId,
      button.action
    );
  }
}
```

Here's a complete example custom embedded message component:

```tsx
import React from 'react';
import { View, Text, Image, TouchableOpacity, StyleSheet } from 'react-native';
import { Iterable, IterableEmbeddedMessage } from '@iterable/react-native-sdk';

interface EmbeddedMessageCardProps {
  message: IterableEmbeddedMessage;
}

function EmbeddedMessageCard({ message }: EmbeddedMessageCardProps) {
  const { elements, metadata } = message;

  const handleDefaultActionClick = () => {
    if (elements?.defaultAction) {
      Iterable.embeddedManager.handleClick(message, null, elements.defaultAction);
    }
  };

  const handleButtonClick = (buttonId: string) => {
    const button = elements?.buttons?.find(b => b.id === buttonId);
    if (button) {
      Iterable.embeddedManager.handleClick(message, buttonId, button.action);
    }
  };

  return (
    <TouchableOpacity 
      style={styles.card} 
      onPress={handleDefaultActionClick}
      disabled={!elements?.defaultAction}
    >
      {elements?.mediaUrl && (
        <Image 
          source={{ uri: elements.mediaUrl }} 
          style={styles.image}
        />
      )}
      
      <View style={styles.content}>
        {elements?.title && (
          <Text style={styles.title}>{elements.title}</Text>
        )}
        
        {elements?.body && (
          <Text style={styles.body}>{elements.body}</Text>
        )}
        
        {elements?.buttons && elements.buttons.length > 0 && (
          <View style={styles.buttonContainer}>
            {elements.buttons.map((button) => (
              <TouchableOpacity
                key={button.id}
                style={styles.button}
                onPress={() => handleButtonClick(button.id)}
              >
                <Text style={styles.buttonText}>{button.title}</Text>
              </TouchableOpacity>
            ))}
          </View>
        )}
      </View>
    </TouchableOpacity>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    marginHorizontal: 16,
    marginVertical: 8,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 8,
    elevation: 4,
    overflow: 'hidden',
  },
  image: {
    width: '100%',
    height: 180,
  },
  content: {
    padding: 16,
  },
  title: {
    fontSize: 18,
    fontWeight: 'bold',
    marginBottom: 8,
    color: '#000',
  },
  body: {
    fontSize: 14,
    color: '#666',
    marginBottom: 16,
  },
  buttonContainer: {
    flexDirection: 'row',
    gap: 8,
  },
  button: {
    flex: 1,
    paddingVertical: 12,
    backgroundColor: '#007AFF',
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontSize: 14,
    fontWeight: '600',
  },
});

export default EmbeddedMessageCard;
```

If you need more control, you can manually track clicks using:

```ts
Iterable.embeddedManager.trackClick(
  message,
  buttonId, // or null for default action
  clickedUrl
);
```

To track clicks, Iterable's React Native SDK calls:

[`POST /api/embedded-messaging/events/click`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-click)

---

## Want to learn more?

- [Embedded Messaging Overview](https://support.iterable.com/hc/articles/23060529977364)
- [Out-of-the-Box Views for Embedded Messages](https://support.iterable.com/hc/articles/23230946708244)
- [Overview of Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714072)  
- [API Documentation](https://iterable-react-native-sdk.netlify.app)  
- The GitHub repository for Iterable's React Native SDK: [react-native-sdk](https://github.com/Iterable/react-native-sdk). In particular, these files:  
  - `src/embedded/classes/IterableEmbeddedManager.ts`  
  - `src/embedded/types/IterableEmbeddedMessage.ts`  
  - `src/core/classes/IterableConfig.ts`  
- The example app in the [react-native-sdk repository](https://github.com/Iterable/react-native-sdk/tree/master/example)

