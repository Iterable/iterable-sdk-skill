---
slug: mobile-inbox
feature: mobile-inbox
archetype: feature
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Using a Mobile Inbox with Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/5422108307604
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/mobile-inbox/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: 0088f17792b5278225b686005e654262de6a4eab
fetched_at: 2026-08-28T14:44:26.838Z
summary: A mobile inbox displays a list of saved in-app messages that users can
  revisit at their convenience. This way, they can access messages right when
  they're relevant—for example, maybe pulling up a coupon while shopping.
---
# Using a Mobile Inbox with Iterable's React Native SDK

A mobile inbox displays a list of saved in-app messages that users can revisit
at their convenience. This way, they can access messages right when they're
relevant—for example, maybe pulling up a coupon while shopping.

Iterable's React Native SDK provides a default mobile inbox implementation. It
includes a customizable user interface, and it saves events to Iterable as users
view and interact with your in-app messages.

This guide describes how to set up a mobile inbox in your React Native app.

> [!TIP]
> To learn more, check out our guide about [In-App Messages and Mobile Inbox](https://support.iterable.com/hc/articles/217517406).

## Overview

Here's what a mobile inbox looks like on iOS and Android:

![A mobile inbox in an iOS app](https://support.iterable.com/hc/article_attachments/6024856442900/mobile-inbox-ios-demo.gif "A mobile inbox in an iOS app")
![A mobile inbox in an Android app](https://support.iterable.com/hc/article_attachments/6024839708052/mobile-inbox-android-demo.gif "A mobile inbox in an Android app")

## Adding a mobile inbox to your React Native app

The following instructions describe how to use the default mobile inbox
configuration provided by Iterable's React Native SDK.

### Step 1: Install Iterable's React Native SDK

First, install Iterable's React Native SDK. To do this, follow
[these instructions](https://support.iterable.com/hc/articles/360045714132).

The mobile inbox included in the SDK relies on the [React Native Webview](https://www.npmjs.com/package/react-native-webview)
package. As described in the above instructions, add this package to your
project by running one of the following commands (depending on your preferred
package manager):

- `yarn add react-native-webview`
- `npm install react-native-webview`

Then, in your project's `ios` directory, run `pod install`.

### Step 2: Import the `IterableInbox` component

In the code for the screen where you'll use the mobile inbox, import the
`IterableInbox` component:

```javascript
import { IterableInbox } from '@iterable/react-native-sdk'
```

### Step 3: Display the inbox

You can display a mobile inbox when a user visits a particular tab in your app,
or when they tap on a particular button. Below, you'll find example code for
each of these approaches (they both require the instantiation of an
`IterableInbox` component).

#### Displaying a mobile inbox as part of a tab bar

This example code adds a mobile inbox to a tab bar, on the `Inbox` tab:

```typescript
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Icon from 'react-native-vector-icons/Ionicons'
import { Linking, StyleSheet, Text, View } from 'react-native'
import Home from './Home'
import SettingsTab from './SettingsTab'
import { Coffee, coffees } from './Data'
import { IterableUtil } from './IterableUtil'
import {
  Iterable,
  IterableAction,
  IterableActionContext,
  IterableInbox,
  type IterableInboxRowViewModel,
} from '@iterable/react-native-sdk'

interface Props { }
export default class App extends React.Component<{}, {returnToInboxTrigger: boolean, isInboxTab: boolean}> {
  constructor(props: Props) {
    super(props)
    this.homeTabRef = React.createRef()
    this.state = {
      returnToInboxTrigger: false,
      isInboxTab: false
    }

    IterableUtil.initialize(this.urlHandler, this.customActionHandler)

    Linking.getInitialURL().then(url => {
      console.log('url receieved: ' + url)
      if (url != null) {
        Iterable.handleAppLink(url)
      }
    });
    Linking.addEventListener('url', event => {
      console.log('url receieved: ' + event.url)
      if (event.url != null) {
        Iterable.handleAppLink(event.url)
      }
    });
  }

  render() {
    const Tab = createBottomTabNavigator();

    return (
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={({ route }) => ({
            tabBarIcon: ({ focused, color, size }) => {
              if (route.name == 'Home') {
                return <Icon name="ios-home" size={size} color={color} />
              } else if (route.name == 'Inbox') {
                return <Icon name="ios-mail" size={size} color={color} />
              } else {
                return <Icon name="ios-settings" size={size} color={color} />
              }
            },
          })}
          tabBarOptions={{
            activeTintColor: 'tomato',
            inactiveTintColor: 'gray',
          }}
        >
          <Tab.Screen
            name="Home"
            component={Home}
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                this.setState({
                  isInboxTab: false
                })
              }
            })}
          />
          <Tab.Screen
            name="Inbox"
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                if(this.state.isInboxTab) {
                  this.setState({
                    returnToInboxTrigger: !this.state.returnToInboxTrigger,
                  })
                }
                this.setState({
                  isInboxTab: true
                })
              }
            })}
          >
            {() =>
              <IterableInbox
                returnToInboxTrigger={this.state.returnToInboxTrigger}
              />
            }
          </Tab.Screen>
          <Tab.Screen
            name="Settings"
            component={SettingsTab}
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                this.setState({
                  isInboxTab: false
                })
              }
            })}
          />
        </Tab.Navigator>
      </NavigationContainer>
    )
  }

  private homeTabRef: any

  private navigate(coffee: Coffee) {
    if (this.homeTabRef && this.homeTabRef.current) {
      this.homeTabRef.current.navigate(coffee)
    }
  }

  private urlHandler = (url: String, context: IterableActionContext): boolean => {
    // ...
  }

  private customActionHandler = (action: IterableAction, context: IterableActionContext) => {
    // ...
  }
}
```
> [!NOTE]
> In the above example, note the `isInboxTab` and `returnToInboxTrigger` state
> variables. These variables help manage navigation _within_ the mobile inbox
> (from details of a particular message back to the message list).
>
> If a user is on a tab that contains a mobile inbox and has opened up a message,
> re-tapping that tab should navigate them back to the message list. To manage
> this navigation, the tabs in the above code sample use the `isInboxTab` and
> `returnToInboxTrigger` variables (and their associated setters).
>
> Each tab, when tapped, sets `isInboxTab` to `true` or `false`, depending on
> whether or not it displays a mobile inbox. This tracks whether the most recently
> visited tab displays the inbox, or not.
>
> Then, when the inbox tab is tapped, it checks `isInboxTab`. If it's `true`,
> which means that the inbox is already being displayed, the code triggers a
> navigation back to the message list—if necessary—by toggling
> `returnToInboxTrigger`.
>
> The value of `returnToInboxTrigger` doesn't matter—toggling it in either
> direction triggers the navigation, if it's needed. Note how
> `returnToInboxTrigger` is included in the instantiation of the `IterableInbox`
> component, which is how the inbox knows which state variable to watch.
>
> `returnToInboxTrigger` is optional. If you don't include it when instantiating
> your `IterableInbox`, re-tapping the same inbox tab (after opening up an in-app
> message) will not navigate you back to the inbox message list.

#### Displaying a mobile inbox after a button press

Sometimes, rather than putting a mobile inbox in its own tab on a tab bar, you
may want to display it when a particular button is pressed. Here's some example
code that demonstrates how to do this:

```typescript
import React, { useState } from 'react'
import { View, Alert, StyleSheet } from 'react-native'
import Icon from 'react-native-vector-icons/Ionicons'
import { SafeAreaView } from 'react-native-safe-area-context'
import HomeTab from './HomeTab'
import {
  Iterable,
  IterableAction,
  IterableActionContext,
  IterableConfig,
  IterableInAppMessage,
  IterableInAppShowResponse,
  IterableInbox,
  IterableLogLevel,
} from '@iterable/react-native-sdk'
import { BottomTabScreenProps } from '@react-navigation/bottom-tabs'

type BottomTabParamList = {
    Home: undefined;
    Inbox: undefined;
    Settings: undefined;
};

type Props = BottomTabScreenProps<BottomTabParamList,'Home'>

export default function Home({ navigation }: Props) {

    const [isInboxSelected, setIsInboxSelected] = useState<boolean>(false)
    const config = new IterableConfig()
    config.inAppDisplayInterval = 1.0

    config.urlHandler = (url: string, context: IterableActionContext) => {
       // ...
    }

    config.customActionHandler = (action: IterableAction, context: IterableActionContext) => {
       // ....
    }

    config.inAppHandler = (message: IterableInAppMessage) => {
        return IterableInAppShowResponse.show
    }

    config.logLevel = IterableLogLevel.info

    Iterable.initialize("<YOUR_API_KEY>", config);

    const toggleInbox = () => {
        setIsInboxSelected(!isInboxSelected)
    }

    let {
        container,
        buttonContainer,
    } = styles

    return(
        <SafeAreaView style={container}>
            <View style={buttonContainer}>
                <Icon.Button
                    name="ios-mail"
                    style={{
                        width: "50%"
                    }}
                    backgroundColor={isInboxSelected ? "red" : "blue"}
                    onPress={toggleInbox}
                >
                    {isInboxSelected ? "Hide Inbox" : "Show Inbox"}
                </Icon.Button>
            </View>
            {isInboxSelected
                ? <IterableInbox safeAreaMode={false} />
                : <HomeTab />}
        </SafeAreaView>
    )
}

const styles = StyleSheet.create({
    container: {
        height: '100%',
        backgroundColor: 'whitesmoke',
        flexDirection: 'column',
        justifyContent: 'flex-start',
        marginTop: 0,
        paddingBottom: 0,
        paddingLeft: 0,
        paddingRight: 0
    },

    buttonContainer: {
        backgroundColor: 'whitesmoke',
        alignItems: 'center',
        marginTop: 20
    },
})
```

In this example, pressing the **Show Inbox** button calls `toggleInbox`, which
updates `isInboxSelected`. And that changes what's displayed on the page:

```typescript
{isInboxSelected
   ? <IterableInbox safeAreaMode={false} />
   : <HomeTab />}
```

> [!TIP]
> Use the `safeAreaMode` parameter on `IterableInbox` to indicate whether or not the
> inbox should be displayed inside a React Native [`SafeAreaView`](https://reactnative.dev/docs/safeareaview).
> In our example, we set `safeAreaMode` to `false`—there's already an `SafeAreaView`
> being used, and we don't need another.

## Customizing the mobile inbox

There are various ways to customize the default styles of the mobile inbox,
as described below.

### Customizations object

The primary way to customize your mobile inbox is by providing styles
in a `customizations` object that you pass to your `IterableInbox`:

```jsx
<IterableInbox
    customizations={iterableInboxCustomization}
/>
```

Here's an example customizations object:

```typescript
const iterableInboxCustomization = {
  navTitle: "",
  noMessagesTitle: "",
  noMessagesBody: "",

  unreadIndicatorContainer: {
    height: '100%',
    flexDirection: 'column',
    justifyContent: 'flex-start'
  },

  unreadIndicator: {
    width: 15,
    height: 15,
    borderRadius: 15 / 2,
    backgroundColor: 'orange',
    marginLeft: 10,
    marginRight: 5,
    marginTop: 10
  },

  unreadMessageThumbnailContainer: {
    paddingLeft: 0,
    flexDirection: 'column',
    justifyContent: 'center'
  },

  readMessageThumbnailContainer: {
    paddingLeft: 30,
    flexDirection: 'column',
    justifyContent: 'center'
  },

  messageContainer: {
    paddingLeft: 10,
    width: '75%',
    flexDirection: 'column',
    justifyContent: 'center'
  },

  title: {
    fontSize: 22,
    paddingBottom: 10
  },

  body: {
    fontSize: 15,
    color: 'lightgray',
    width: '85%',
    flexWrap: "wrap",
    paddingBottom: 10
  },

  createdAt: {
    fontSize: 12,
    color: 'lightgray'
  },

  messageRow: {
    flexDirection: 'row',
    backgroundColor: 'white',
    paddingTop: 10,
    paddingBottom: 10,
    width: '100%',
    height: 200,
    borderStyle: 'solid',
    borderColor: 'red',
    borderTopWidth: 1
  }
}
```

In this object, you can specify:

- `navTitle` — The title that appears at the top of the inbox screen.

- `noMessagesTitle` — The title that appears in the middle of the screen when the
  inbox contains no messages. Default value: "No saved messages".

- `noMessagesBody` — The body text that appears in the middle of the screen when
  the inbox contains no messages. Default value: "Check again later!"

- `unreadIndicatorContainer` — The container that holds the unread indicator.

- `unreadIndicator` — The unread indicator icon.

- `unreadMessageThumbnailContainer` — For an unread message, this is the
  container for the thumbnail image associated with the message (as configured
  when setting up the template in Iterable).

- `readMessageThumbnailContainer` — For a read message, this is the container
  for the thumbnail image associated with the message (as configured when setting
  up the template in Iterable).

- `messageContainer` — A container around various elements in the message item:
  title, body, and created at.

- `title` — The title of the message, as displayed in the inbox.

- `body` — The body of the message, as displayed in the inbox (not when the
  message has been opened).

- `createdAt` — The message date.

- `messageRow` — A message row. Use these styles to customize row height, padding,
  background color, border, etc.

### Tab bar customizations

To tell the `IterableInbox` about the height and padding of the tab bar, use
the optional `tabBarHeight` and `tabBarPadding` props. For example:

```jsx
<IterableInbox
    tabBarHeight={55}
    tabBarPadding={5}
/>
```

If your app uses custom tab bar dimensions, provide these values to make sure
that the inbox component lays out as expected. If you don't provide them, they
default to:

- `tabBarHeight` — 80
- `tabBarPadding` — 20

### Message list item layout

To specify a custom layout for your inbox rows, when you instantiate your
`IterableInbox`, assign a function to its `messageListItemLayout` prop.
The inbox will call this function for each of its rows, and it should return:

1. JSX that represents the custom layout for the row.
2. The height of the row (must be the same for all rows).

A row layout can reference the fields stored in the passed-in `rowViewModel`,
which is an instance of `IterableInboxRowViewModel`. `IterableInboxRowViewModel` has these fields:

- `title` (a `string`)
- `subtitle?` (a `string`)
- `imageUrl?` (a `string`)
- `createdAt?` (a `Date`)
- `read` (a `boolean`)
- `inAppMessage` (a `IterableInAppMessage`)

In the sample code below, the custom layout function is called `MessageListItemLayout`:

```typescript
import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import Icon from 'react-native-vector-icons/Ionicons'
import { View, Text, StyleSheet } from 'react-native'
import Home from './Home'
import SettingsTab from './SettingsTab'
import { Coffee, coffees } from './Data'
import { IterableUtil } from './IterableUtil'
import { Linking } from 'react-native';
import {
  Iterable,
  IterableAction,
  IterableActionContext,
  IterableInbox,
  IterableInboxRowViewModel,
} from '@iterable/react-native-sdk'
import { getTabBarHeight } from '@react-navigation/bottom-tabs/lib/typescript/src/views/BottomTabBar';

const MessageListItemLayout = (
  last: boolean,
  rowViewModel: IterableInboxRowViewModel
) => {
  const messageTitle = rowViewModel.inAppMessage.inboxMetadata?.title
  const messageBody = rowViewModel.inAppMessage.inboxMetadata?.subtitle
  const messageCreatedAt = rowViewModel.createdAt

  let styles = StyleSheet.create({
     unreadIndicatorContainer: {
        height: '100%',
        flexDirection: 'column',
        justifyContent: 'flex-start'
     },

     unreadIndicator: {
        width: 15,
        height: 15,
        borderRadius: 15 / 2,
        backgroundColor: 'blue',
        marginLeft: 10,
        marginRight: 5,
        marginTop: 7
     },

     unreadMessageContainer: {
        paddingLeft: 5
     },

     readMessageContainer: {
        paddingLeft: 30
     },

     title: {
        fontSize: 22,
        paddingBottom: 10
     },

     body: {
        fontSize: 15,
        color: 'lightgray',
        paddingBottom: 10
     },

     createdAt: {
        fontSize: 12,
        color: 'lightgray'
     },

     messageRow: {
        flexDirection: 'row',
        backgroundColor: 'white',
        paddingTop: 10,
        paddingBottom: 10,
        width: '100%',
        height: 120,
        borderStyle: 'solid',
        borderColor: 'black',
        borderTopWidth: 1
     }
  })

  const {
     unreadIndicatorContainer,
     unreadIndicator,
     unreadMessageContainer,
     readMessageContainer,
     title,
     body,
     createdAt,
     messageRow
  } = styles

  function messageRowStyle(rowViewModel: IterableInboxRowViewModel) {
     return last ? {...messageRow, borderBottomWidth: 1} : messageRow
  }

  return(
     [  <View style={messageRowStyle(rowViewModel)}>
           <View style={unreadIndicatorContainer}>
              {rowViewModel.read ? null : <View style={unreadIndicator}/>}
           </View>
           <View style={rowViewModel.read ? readMessageContainer : unreadMessageContainer}>
              <Text style={title}>{messageTitle}</Text>
              <Text style={body}>{messageBody}</Text>
              <Text style={createdAt}>{messageCreatedAt}</Text>
           </View>
        </View>, styles.messageRow.height]
  )
}

interface Props { }

export default class App extends React.Component<{}, {returnToInboxTrigger: boolean, isInboxTab: boolean}> {
  constructor(props: Props) {
    super(props)
    this.homeTabRef = React.createRef()
    this.state = {
      returnToInboxTrigger: false,
      isInboxTab: false
    }

    IterableUtil.initialize(this.urlHandler, this.customActionHandler)

    Linking.getInitialURL().then(url => {
      console.log('url receieved: ' + url)
      if (url != null) {
        Iterable.handleAppLink(url)
      }
    });
    Linking.addEventListener('url', event => {
      console.log('url receieved: ' + event.url)
      if (event.url != null) {
        Iterable.handleAppLink(event.url)
      }
    });
  }

  render() {
    const Tab = createBottomTabNavigator();

    return (
      <NavigationContainer>
        <Tab.Navigator
          screenOptions={({ route }) => ({
            tabBarIcon: ({ focused, color, size }) => {
              if (route.name == 'Home') {
                return <Icon name="ios-home" size={size} color={color} />
              } else if (route.name == 'Inbox') {
                return <Icon name="ios-mail" size={size} color={color} />
              } else {
                return <Icon name="ios-settings" size={size} color={color} />
              }
            },
          })}
          tabBarOptions={{
            activeTintColor: 'tomato',
            inactiveTintColor: 'gray',
          }}
        >
          <Tab.Screen
            name="Home"
            component={Home}
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                this.setState({
                  isInboxTab: false
                })
              }
            })}
          />
          <Tab.Screen
            name="Inbox"
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                if(this.state.isInboxTab) {
                  this.setState({
                    returnToInboxTrigger: !this.state.returnToInboxTrigger,
                  })
                }

                this.setState({
                  isInboxTab: true
                })
              }
            })}
          >
            {() =>
              <IterableInbox
                returnToInboxTrigger={this.state.returnToInboxTrigger}
                messageListItemLayout={(last: boolean, rowViewModel: IterableInboxRowViewModel) => MessageListItemLayout(last, rowViewModel)}
              />
            }
          </Tab.Screen>
          <Tab.Screen
            name="Settings"
            component={SettingsTab}
            listeners={({ navigation, route }) => ({
              tabPress: (e) => {
                this.setState({
                  isInboxTab: false
                })
              }
            })}
          />
        </Tab.Navigator>
      </NavigationContainer>
    )
  }

  private homeTabRef: any

  private navigate(coffee: Coffee) {
    if (this.homeTabRef && this.homeTabRef.current) {
      this.homeTabRef.current.navigate(coffee)
    }
  }

  private urlHandler = (url: String, context: IterableActionContext): boolean => {
    // ...
  }

  private customActionHandler = (action: IterableAction, context: IterableActionContext) => {
    // ...
  }
}
```
