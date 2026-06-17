---
slug: android-app-links
feature: deep-linking
archetype: feature
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Android App Links
source_url: https://support.iterable.com/hc/articles/360035127392
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/deep-links/android-app-links/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 3c933bbc8661bddfeaa8914f3dbb8233d98469c6
fetched_at: 2026-05-25T15:11:45.366Z
polished_at: 2026-06-05T14:02:08.697Z
layer: a
snippets:
  - index: 0
    lang: java
    hash: "8191331288e0"
    line_count: 24
  - index: 1
    lang: java
    hash: 7f9532ca4355
    line_count: 7
  - index: 2
    lang: java
    hash: 61186d66b7f8
    line_count: 6
summary: Messages sent with Iterable can include Android App Links, which
  redirect users to your installed mobile app—no browser required. Iterable
  tracks clicks on these links as expected.
---
# Android App Links

Messages sent with Iterable can include Android App Links, which redirect users 
to your installed mobile app—no browser required. Iterable tracks clicks on these
links as expected.

> [!WARNING]
> You must set up [iOS deep linking](https://support.iterable.com/hc/articles/360035496511) 
> before implementing Android deep linking (they rely on similar architecture).

## Setting up Android App Links

### 1. Enable Android App Links

To enable Android App Links, follow these steps:

- Configure your Iterable project to support deep links. For more information,
  read [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

- Configure your mobile app to handle Android App Links by following the 
  [instructions in the Android documentation](https://developer.android.com/training/app-links/index.html).

- Create intent filters for Iterable URIs by using the [App Links Assistant](https://developer.android.com/studio/write/app-link-indexing)

    - Set the **Host** to your tracking domain. For example, 
      `https://links.<YOUR_TRACKING_DOMAIN>.com`.

    - Set the **Path** to use `/a` as the **pathPrefix**.

- Generate the `assetlinks.json` file

### 2. Upload `assetlinks.json`

After you generate an `assetlinks.json` file with your app's fingerprint, 
you'll need to provide it to Iterable so that it can be hosted at 
`<YOUR_TRACKING_DOMAIN>/.well-known/assetlinks.json`. To upload it, 
follow the instructions in [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

Then, use Google's [Statement List Generator and Tester](https://developers.google.com/digital-asset-links/tools/generator)
to test it out.

### 3. Determine which links to rewrite

To determine which links to rewrite as deep links for a given campaign, Iterable
looks at the relevant tracking domain's `apple-app-site-association` file. Even
if you only have an Android app, you'll still need to create this file. To learn
how to do so, read [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

### 4. Update your code

If you already have a `urlHandler`, you can use the same handler for email deep
links by calling `handleAppLink` in the activity that handles all Android App
Links in your app:

```java
// MainActivity.java
@Override
public void onCreate() {
    super.onCreate();
    ...
    handleIntent(getIntent());
}

@Override
public void onNewIntent(Intent intent) {
    super.onNewIntent(intent);
    if (intent != null) {
        handleIntent(intent);
    }
}

private void handleIntent(Intent intent) {
    if (Intent.ACTION_VIEW.equals(intent.getAction()) && intent.getData() != null) {
        IterableApi.getInstance().handleAppLink(intent.getDataString());
        // Overwrite the intent to make sure we don't open the deep link
        // again when the user opens our app later from the task manager
        setIntent(new Intent(Intent.ACTION_MAIN));
    }
}
```

Alternatively, call `getAndTrackDeeplink` along with a callback to handle the
original deep link URL. You can use this method for any incoming URLs, as it
will execute the callback without changing the URL for non-Iterable URLs.

```java
IterableApi.getAndTrackDeeplink(uri, new IterableHelper.IterableActionHandler() {
    @Override
    public void execute(String result) {
        Log.d("HandleDeeplink", "Redirected to: "+ result);
        // Handle the original deep link URL here
    }
});
```

**💡 TIP**

To check if a URL is an Iterable deep link before handling it, use the 
`isIterableDeepLink` method:

```java
if (IterableApi.getInstance().isIterableDeepLink(urlString)) {
    // URL is an Iterable deep link, handle it with the SDK
    IterableApi.getInstance().handleAppLink(urlString);
} else {
    // Handle non-Iterable URLs differently if needed
}
```

This method returns `true` if the URL matches the Iterable deep link pattern
(URLs containing `/a/` in the path).

## FAQ

For answers to common questions about deep links, read the [Deep Link FAQs](https://support.iterable.com/hc/articles/360035624191#deep-link-faqs).

