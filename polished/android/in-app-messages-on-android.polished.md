---
slug: in-app-messages-on-android
feature: in-app-messages
archetype: feature
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: In-App Messages on Android
source_url: https://support.iterable.com/hc/articles/360035537231
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/in-app-messages/in-app-messages-on-android/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 67ade49d8716b4d65cdb7779eb210afa0b5054da
fetched_at: 2026-05-27T12:44:52.898Z
polished_at: 2026-06-05T13:59:18.311Z
layer: a
snippets:
  - index: 0
    lang: java
    hash: 8db83c22f9a3
    line_count: 18
  - index: 1
    lang: java
    hash: bcfe488ba3d1
    line_count: 10
  - index: 2
    lang: kotlin
    hash: 28725ee7538d
    line_count: 1
  - index: 3
    lang: java
    hash: 265c585feb80
    line_count: 1
summary: By default, when an in-app message arrives from the server, the SDK
  automatically shows it if the app is in the foreground. If an in-app message
  is already showing when the new message arrives, the new message will be shown
  30 seconds after the currently displayed in-app message closes ([see how to
  change this default value
  below](#changing-the-display-interval-between-in-app-messages)). Once an…
---
# In-App Messages on Android

## Default behavior

By default, when an in-app message arrives from the server, the SDK automatically
shows it if the app is in the foreground. If an in-app message is already showing
when the new message arrives, the new message will be shown 30 seconds after the
currently displayed in-app message closes ([see how to change this default value below](#changing-the-display-interval-between-in-app-messages)).  
Once an in-app message is shown, it will be "consumed" from the server queue and
removed from the local queue as well. There is no need to write any code to get this
default behavior.

## Overriding whether to show or skip a particular in-app message

An incoming in-app message triggers a call to the `onNewInApp` method of
`IterableConfig.inAppHandler` (an `IterableInAppHandler` object). To override the
default behavior, set `inAppHandler` in `IterableConfig` to a custom class that
overrides the `onNewInApp` method. `onNewInApp` should return `InAppResponse.SHOW`
to show the incoming in-app message or `InAppResponse.SKIP` to skip showing it.

> [!TIP]
> To determine the priority of an `IterableInAppMessage` object, call its
> `getPriorityLevel` method. You can use this priority to help determine whether or
> not to display it.

```java
class MyInAppHandler implements IterableInAppHandler {
    @Override
    public InAppResponse onNewInApp(IterableInAppMessage message) {
        if (/* add conditions here */) {
            return InAppResponse.SHOW;
        } else {
            return InAppResponse.SKIP;
        }
    }
}

// ...

IterableConfig config = new IterableConfig.Builder()
  .setPushIntegrationName("myPushIntegration")
  .setInAppHandler(new MyInAppHandler())
  .build();
IterableApi.initialize(context, "<your-api-key>", config);
```

## Getting the local queue of in-app messages

The SDK keeps the local in-app message queue in sync by checking the server queue
every time the app goes into foreground, and via silent push messages that arrive
from Iterable servers to notify the app whenever a new in-app message is added to
the queue.

To access the in-app message queue, call
`IterableApi.getInstance().getInAppManager().getMessages()`. To show a message, call
`IterableApi.getInstance().getInAppManager().showMessage(message)`.

```java
// Get the in-app messages list
IterableInAppManager inAppManager = IterableApi.getInstance().getInAppManager();
List<IterableInAppMessage> messages = inAppManager.getMessages();

// Show an in-app message 
inAppManager.showMessage(message);

// Show an in-app message without consuming (not removing it from the queue)
inAppManager.showMessage(message, false)

```

## Handling in-app message buttons and links

The SDK handles in-app message buttons and links as follows:

- If the URL of the button or link uses the `action://` URL scheme, the SDK passes
  the action to `IterableConfig.customActionHandler.handleIterableCustomAction()`. If
  `customActionHandler` (an `IterableCustomActionHandler` object) has not been set,
  the action will not be handled.

  For the time being, the SDK will treat `itbl://` URLs the same way as `action://`
  URLs. However, this behavior will eventually be deprecated (timeline TBD), so it's
  best to migrate to the `action://` URL scheme as it's possible to do so.

- The `iterable://` URL scheme is reserved for action names predefined by
  the SDK. If the URL of the button or link uses an `iterable://` URL known
  to the SDK, it will be handled automatically and will not be passed to the
  custom action handler. For example, buttons or links with URL `iterable://dismiss` 
  dismiss an in-app message and create in-app click and in-app close events.

- The SDK passes all other URLs to `IterableConfig.urlHandler.handleIterableURL()`. 
  If `urlHandler` (an `IterableUrlHandler` object) has not been set, or if it
  returns `false` for the provided URL, the URL will be opened by the system
  (using a web browser or other application, as applicable).

## Changing the display interval between in-app messages

To customize the time delay between successive in-app messages, set
`inAppDisplayInterval` on `IterableConfig` to an appropriate value in
seconds. The default value is 30 seconds.

## Pausing the display of in-app messages (SDK v3.2.6 and above)

In certain areas of your app, you may want to prevent interruptions. To pause the
display of in-app messages, call the following method:

_Kotlin_

```kotlin
IterableApi.getInstance().inAppManager.setAutoDisplayPaused(true)
```

_Java_

```java
IterableApi.getInstance().getInAppManager().setAutoDisplayPaused(true);
```

With this done, the app will not automatically display new in-app messages.
However, it will keep the local queue of in-app messages in sync.

> [!TIP]
> While in-app message display has been paused, you can still call the `showMessage` 
> method on `IterableInAppManager` to manually display messages.

To resume the display of in-app messages from your app's queue, call 
`setAutoDisplayPaused(false)`.
