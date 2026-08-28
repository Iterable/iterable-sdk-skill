---
slug: expo
feature: integration
archetype: integration
sdk_min_version: 3.1.0
sdk_artifact: "@iterable/react-native-sdk"
title: Expo Plugin for Iterable's React Native SDK
source_url: https://support.iterable.com/hc/articles/37200225506196
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-react-native-sdk/expo/index.md
source_ref: 59c40504c91bc0b13751c5ef5f348810eb0fd4f2
source_sha: 258b9e115662257942fb8f6bb7ab57d8cc4d68eb
fetched_at: 2026-08-28T14:44:26.860Z
summary: "Iterable's React Native SDK offers an Expo plugin that extends
  configuration management, making it easier to manage dependencies and
  configurations. Use the Expo plugin to minimize the potential for
  configuration errors, which might occur during a manual setup, and to
  significantly reduce the time to complete the following tasks, which are
  required to use Iterable's React Native SDK:"
---
# Expo Plugin for Iterable's React Native SDK

Iterable's React Native SDK offers an Expo plugin that extends configuration
management, making it easier to manage dependencies and configurations.
Use the Expo plugin to minimize the potential for configuration errors, which
might occur during a manual setup, and to significantly reduce the time
to complete the following tasks, which are required to use Iterable's React 
Native SDK:

- Configure native dependencies
- Set up iOS and Android project settings
- Handle native code modifications
- Manage platform-specific configurations

The Expo plugin has the following additional benefits:

- The plugin automatically configures push notifications for both iOS and 
  Android platforms.
  - For **iOS**, the plugin adds bridge to native Iterable code, sets up the 
    notification service extension, configures required entitlements, and 
    handles notification permissions.
  
  - For **Android**, the plugin adds bridge to native Iterable code, configures 
    the Firebase integration, sets up notification handling, and manages 
    notification permissions.

- The plugin configures deep linking capabilities for both platforms.
  - For **iOS**, the plugin sets up Universal Links and configures associated 
    domains.
  
  - For **Android**, the plugin configures App Links and sets up intent filters.

Read this article to learn about the requirements that must be satisfied before 
using this plugin and how to automate [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132)
by utilizing [Iterable's Expo plugin](https://github.com/Iterable/iterable-expo-plugin).

## Requirements

For the best compatibility with Expo SDK 55 and React Native's New Architecture,
use the latest versions of `@iterable/expo-plugin` and `@iterable/react-native-sdk`
and meet these requirements:

- [Expo SDK 55 or later](https://docs.expo.dev/get-started/set-up-your-environment/)
- [React Native 0.83.2 or later](https://github.com/facebook/react-native)
- [React 19.2 or later](https://github.com/facebook/react)
- [Node.js 20.19.4 or later](https://nodejs.org/)
- [Iterable's React Native SDK 3.0.0 or later](https://github.com/Iterable/react-native-sdk/releases/tag/3.0.0)
- [@iterable/expo-plugin 1.1.0 or later](https://github.com/Iterable/iterable-expo-plugin/releases/tag/1.1.0)

> [!NOTE]
> While the plugin may work on other versions, these are the versions it is built
> for and tested against. Untested versions are not supported.

## Special considerations

Before you install the Expo plugin, note the following considerations and 
limitations.

### Non-EAS compatibility

If your app is not built with [EAS](https://expo.dev/eas) and you are using
`@iterable/expo-plugin` versions earlier than 1.1.0, or Expo SDK 54 or earlier,
a [compatibility issue](https://github.com/facebook/react-native/issues/50411)
between React Native 0.75 and Xcode 16.3 may require you to install:

- [React Native 0.75](https://github.com/facebook/react-native/tree/v0.75.3)
- [Xcode 16.2 or earlier](https://developer.apple.com/xcode/) (download [here](https://download.developer.apple.com/Developer_Tools/Xcode_16.2/Xcode_16.2.xip))

Or:
- [React Native 0.76 or later](https://github.com/facebook/react-native)
- [Xcode 16.3 or later](https://developer.apple.com/xcode/)

### React Native's New Architecture

[@iterable/react-native-sdk 3.0.0 or later](https://github.com/Iterable/react-native-sdk/releases/tag/3.0.0)
and [@iterable/expo-plugin 1.1.0 or later](https://github.com/Iterable/iterable-expo-plugin/releases/tag/1.1.0)
support [React Native's New Architecture](https://reactnative.dev/architecture/landing-page)
(Fabric, TurboModules, and Codegen).

Expo SDK 55 requires the New Architecture. Ensure `newArchEnabled` is set to
`true` in your `app.json`. In Expo SDK 55, this is set to `true` by default.

```json
{
  "expo": {
    "newArchEnabled": true
  }
}
```

If you are using an older version of the Expo plugin with Expo SDK versions 54 or
earlier, you can disable the New Architecture (see [Disabling New Architecture](#disabling-new-architecture)).

### Xcode 26.4 compatibility

`@iterable/expo-plugin` 1.1.0 or later automatically applies an iOS build
workaround during `expo prebuild` that compiles the `{fmt}` C++ library pod in
C++17 mode, for compatibility with [Xcode 26.4](https://github.com/expo/expo/issues/44229)
or later and React Native 0.83.2 or later. No additional configuration is required.

### Expo Go

Your Expo app needs to be run as a [development build](https://docs.expo.dev/develop/development-builds/introduction/)
instead of through Expo Go. Both [@iterable/expo-plugin](https://github.com/Iterable/iterable-expo-plugin)
and [@iterable/react-native-sdk](https://github.com/Iterable/react-native-sdk) 
will **NOT** work in Expo Go, as they rely on native code, which Expo Go
[does not support](https://expo.dev/blog/expo-go-vs-development-builds#expo-go-limitations).

### Native code

> [!WARNING]
> If you are manually configuring your native code instead of using other Expo
> config plugins, **DO NOT use this plugin**.
>
> [@iterable/expo-plugin](https://github.com/Iterable/iterable-expo-plugin)
> works by modifying the native code of your Expo app. This means that any
> changes you make to your native code will be overwritten when you run
> `npx expo prebuild --clean`.

## Installing and configuring the Expo plugin

The Expo plugin
([@iterable/expo-plugin](https://github.com/Iterable/iterable-expo-plugin))
simplifies the installation and configuration process by automating several
steps that would otherwise need to be done manually. Simplified processes include:

### 1. Simplified installation

Instead of manually configuring native dependencies and settings, all you need
to do is:

1. Install the plugin and SDK with a single command:
   ```bash
   npx expo install @iterable/expo-plugin @iterable/react-native-sdk
   ```
2. Add a simple configuration to your `app.json` or `app.config.js`:
   ```json
    {
      "expo": {
        "plugins": [
          ["@iterable/expo-plugin", {}]
        ]
      }
    }
   ```

### 2. Automated native setup

The plugin handles all of the native configuration automatically, including:

- Setting up the necessary native dependencies
- Configuring iOS and Android project settings
- Handling any required native code modifications

> [!WARNING]
> **Do not run `npx expo prebuild --clean`** if you are manually configuring your 
> native code. Doing so will delete *everything* in your iOS/Android directories.

If you are **NOT manually configuring** your native code, run:

```bash
npx expo prebuild --clean
```

### 3. Development workflow

After the automated setup:

- Run `npx expo run:ios` for iOS development
- Run `npx expo run:android` for Android development

### 4. Simple integration

Once the setup is complete, you can start using the SDK in your React Native 
code with a straightforward import and initialization:

```tsx
import {useEffect} from 'react';
import {Iterable, IterableConfig} from '@iterable/react-native-sdk';

const App = () => {
  useEffect(() => {
    Iterable.initialize('MY_API_KEY', new IterableConfig());
  }, []);
}
```

## Configuration options

When you add the plugin to your `app.json` or `app.config.js`, you can use the 
following plugin options:

```json
{
  "expo": {
    "plugins": [
      ["@iterable/expo-plugin", {
        "appEnvironment": "development",
        "autoConfigurePushNotifications": true,
        "enableTimeSensitivePush": true,
        "requestPermissionsForPushNotifications": true,
      }]
    ]
  }
}
```

|Option/Description | Type | Default |
|:--------|:------|:---------|:-------------|
|`appEnvironment` - The environment for your app | `development` or `production` | `development`|
|`autoConfigurePushNotifications` - Whether to automatically configure push notifications| boolean | `true`|
|`enableTimeSensitivePush` (iOS only) - Whether to enable time-sensitive push notifications| boolean | `true`|
|`requestPermissionsForPushNotifications` (iOS only) - Whether to request permissions for push notifications| boolean | `true`|

## Additional configuration tasks

### Disabling New Architecture

> [!WARNING]
> The following steps apply only to Expo SDK versions 54 and earlier. Expo SDK
> 55 or later uses New Architecture exclusively, so setting `newArchEnabled` to `false`
> has no effect.

To disable the New Architecture, add the following to your `app.json`:

```json
{
  "expo": {
    "newArchEnabled": false
  }
}
```

### Adding push capabilities

#### iOS 

To add push capabilities to your iOS app, configure push notifications for iOS 
in Iterable as described [here](https://support.iterable.com/hc/articles/115000315806).

#### Android

To add push capabilities for your Android app, configure push notifications for 
Android in Iterable as described [here](https://support.iterable.com/hc/articles/115000331943).

Your app also needs a `google-services.json` file. If you don't have one,
you can get it from the Firebase console. Follow steps [4.1.1 and
4.1.2](https://support.iterable.com/hc/articles/360045714132#step-4-android-app-setup)
to configure Firebase for Iterable and download the `google-services.json` file.

Add the path to your google-services.json file to the app file under
`expo.android.googleServicesFile`.  

For example, if the google services file was added to the root of the app, the 
Expo file would look like this:

```json
{
  "expo": {
    "android": {
      "googleServicesFile": "./google-services.json"
    }
  }
}
```

### Adding Deeplinks 

Deep linking allows users to navigate to specific screens in your app using
URLs.

To set up deep linking in your **Expo** application, [configure deep links in Iterable](https://support.iterable.com/hc/articles/115002651226),
then follow these instructions.

#### iOS

To add deeplinks to your Expo app for use with Iterable on iOS devices, add 
associated domains to your `app.json` under the iOS configuration.

For example: 
```json
{
  "expo": {
    "ios": {
      "associatedDomains": [
          "applinks:expo.dev",
          "applinks:iterable.com",
          "applinks:links.anotherone.com"
       ]
    }
  }
}
```

This is the equivalent of adding them through **Signing & Capabilities** in
Xcode, as described in step 5 of [Iterables iOS Universal Links
Documentation](https://support.iterable.com/hc/articles/360035496511).

Learn more about how Expo sets up [iOS Universal Links](https://docs.expo.dev/linking/ios-universal-links/).

#### Android

To add deeplinks to your Expo app for use with Iterable on Android devices, add
URL schemes and intent filters to your `app.json` under the Android
configuration.  These would be in `expo.android.intentFilters`.

For example:
```json
{
  "expo": {
    "android": {
      "intentFilters": [
        {
          "action": "MAIN",
          "category": ["LAUNCHER"],
          "autoVerify": true,
        },
        {
          "action": "VIEW",
          "autoVerify": true,
          "data": [
            {
              "scheme": "https",
              "host": "links.example.com",
              // Deep links coming from Iterable are prefixed by "/a/", so include this as the "pathPrefix".
              "pathPrefix": "/a/"
            }
          ],
          "category": ["BROWSABLE", "DEFAULT"]
        }
      ]
    }
  }
}
```

Learn more about how Expo sets up [Android App Links](https://docs.expo.dev/linking/android-app-links/).

### Configuring Proguard

If you're using [Proguard](https://reactnative.dev/docs/signed-apk-android#enabling-proguard-to-reduce-the-size-of-the-apk-optional) 
when building your Android app, add this line of ProGuard configuration to your 
build: `-keep class org.json.** { *; }`.

To do this using Expo:

1. Add the
   [expo-build-properties](https://www.npmjs.com/package/expo-build-properties)
   plugin by running: 
    ```bash
    npx expo install expo-build-properties
    ```

2. Add the plugin to your *app.json* file.

3. Then add `{android:{extraProguardRules:"-keep class org.json.** { *; }"}}` to 
   the plugin option.

The overall code in your *app.json* file should look something like this:
```json
{
  "expo": {
    "plugins": [
      [
        "expo-build-properties",
        {
          "android": {
            "extraProguardRules": "-keep class org.json.** { *; }"
          }
        }
      ]
    ]
  }
}
```

Learn more in the [Configure Proguard](https://support.iterable.com/hc/articles/360035019712#step-4-configure-proguard)
section of Iterable's Android SDK setup docs.

### Configuring EAS Builds

When building your app with EAS Build, you may encounter signing errors related
to the `IterableExpoRichPush` notification service extension target that this
plugin creates. To successfully build your app with EAS Build, you must
configure this target in your `app.json` file for EAS builds.

#### iOS EAS Build Configuration

To resolve signing issues with the `IterableExpoRichPush` target, add the app
extension configuration to your `app.json` file. Add the following to your
`expo.extra.eas` configuration:

```json
{
  "expo": {
    "ios": { 
      "bundleIdentifier": "your.app.bundle.id" 
    },
    "extra": {
      "eas": {
        "projectId": "YOUR_EAS_PROJECT_ID",
        "build": {
          "experimental": {
            "ios": {
              "appExtensions": [
                {
                  "targetName": "IterableExpoRichPush",
                  "bundleIdentifier": "your.app.bundle.id.IterableExpoRichPush"
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

For example, if your EAS project ID is `abc123` and your bundle identifier is `com.myapp`:

```json
{
  "expo": {
    "ios": { 
      "bundleIdentifier": "com.myapp" 
    },
    "extra": {
      "eas": {
        "projectId": "abc123",
        "build": {
          "experimental": {
            "ios": {
              "appExtensions": [
                {
                  "targetName": "IterableExpoRichPush",
                  "bundleIdentifier": "com.myapp.IterableExpoRichPush"
                }
              ]
            }
          }
        }
      }
    }
  }
}
```

**ℹ️ NOTE**

To find your EAS project ID, run:
```bash
eas project:info
```

## Troubleshooting

If you run into issues, try the following troubleshooting steps:

### EAS Build issues

If you encounter the error "Signing for 'IterableExpoRichPush' requires a 
development team" after adding the above configuration:

1. Ensure that your EAS credentials are properly configured:
   ```bash
   eas credentials
   ```

2. Verify that your Apple Developer account has the necessary capabilities for 
   push notifications.

3. Clear the build cache:
   ```bash
   eas build --platform ios --profile development --clear-cache
   ```

4. If needed, ensure your bundle identifier follows the correct pattern: 
   `your.main.bundle.id.IterableExpoRichPush`

### Native Module Not Found

If you encounter the error "Your JavaScript code tried to access a native module 
that doesn't exist in this development client," try:

1. Clean your project.
```bash
rm -rf node_modules
rm -rf ios/Pods
yarn cache clean
```

2. Reinstall dependencies.
```bash
yarn install
```

3. Rebuild native projects.
```bash
npx expo prebuild --clean
cd ios && pod install && cd ..
```

### Failure to delete

If you encounter the error "Failed to delete [ios|android] code: ENOTEMPTY: 
directory not empty" when running `npx expo prebuild --clean`," run the same 
command a second time. This generally resolves the issue.

## License

[MIT](https://github.com/Iterable/iterable-expo-plugin/blob/main/LICENSE)
