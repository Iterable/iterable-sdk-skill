---
slug: sdk-testing-and-troubleshooting
feature: integration
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Testing and Troubleshooting Iterable's iOS and Android SDKs
source_url: https://support.iterable.com/hc/articles/360035392251
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/iterables-ios-and-android-sdks/testing-and-troubleshooting/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 57144ab26f62f3e5993a757992d7660253d9eb48
fetched_at: 2026-10-06T10:28:54.948Z
summary: "Here are some common issues with troubleshooting your SDK
  initialization. If you see this error:"
---
# Testing and Troubleshooting Iterable's iOS and Android SDKs

Here are some common issues with troubleshooting your SDK initialization.

## iOS SDK initialization testing

- Verify that you can add the import library without an error:

  ```groovy
  import IterableSDK	
  ```

- Double check your API credentials.

## iOS SDK troubleshooting

### CocoaPods troubleshooting

- Update your pods.
- Check the syntax of your `Podfile`.
- Ensure you're opening the Xcode `.xcworkspace`, not the `.xcodeproject` file.

If you see this error: 

```
[!] CocoaPods could not find compatible versions for pod "Iterable-iOS-AppExtensions":
  In Podfile:
    Iterable-iOS-AppExtensions

There are only pre-release versions available satisfying the following requirements:
	'Iterable-iOS-AppExtensions', '>= 0'

You should explicitly specify the version in order to install a pre-release version
```

1. Make sure that you're using the verified latest release of [CocoaPods](https://github.com/CocoaPods/CocoaPods/releases).

   To update CocoaPods run following command in the terminal:

   ```groovy
   sudo gem install cocoapods
   ```

2. Make sure that you add the `Iterable-iOS-AppExtensions` pod, without a specific
   version (or `=>0`). 

### Carthage troubleshooting

If you encounter errors when building the SDK with Carthage:

- Update to the latest released version of the SDK (6.6.5 or later).
- Update Carthage.

For example, update your SDK to version 6.6.5 or later if you see errors like
these (which occur when internal types are referenced in the module interface
files that are generated during Carthage builds where 
`BUILD_LIBRARY_FOR_DISTRIBUTION=YES`).

```
error: no type named 'SendRequestValue' in module 'IterableSDK'
error: no type named 'SendRequestError' in module 'IterableSDK'
```

### Manual import troubleshooting

- Ensure that you manually linked the libraries.
- Check that the libraries are listed in your `Linked Frameworks and Library`
section under the `General` tab.

## Android SDK initialization testing

To make sure the SDK is successfully integrated, perform a `gradle` sync. 

## Android SDK initialization troubleshooting

### Gradle sync failed

Gradle sync failed with
```groovy
ERROR: Failed to resolve: com.iterable:iterableapi:3.1.3
```
Ensure you have `jcenter()` in project level gradle file:

```groovy
allprojects {
    repositories {
        google()
        jcenter()
    }
}
```

### Multiple push providers

To learn how to work with multiple push providers, read 
[Setting up Android Push Notifications](https://support.iterable.com/hc/articles/115000331943).

## Next steps

After installing the SDK, read [Identifying the User](https://support.iterable.com/hc/articles/360035402531).
