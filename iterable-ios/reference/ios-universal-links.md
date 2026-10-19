---
slug: ios-universal-links
feature: deep-linking
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: iOS Universal Links
source_url: https://support.iterable.com/hc/articles/360035496511
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/deep-links/ios-universal-links/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 5a818e49449ebd42b27f30b76483c6207ea24e1e
fetched_at: 2026-10-02T13:52:10.616Z
summary: With [universal
  links](https://developer.apple.com/ios/universal-links), iOS can open specific
  links with relevant apps rather than a web browser. Since apps can provide a
  faster, more integrated user experience, they are often preferable for this
  purpose.
---
# iOS Universal Links 

With [universal links](https://developer.apple.com/ios/universal-links), iOS
can open specific links with relevant apps rather than a web browser. Since apps
can provide a faster, more integrated user experience, they are often preferable
for this purpose.

If your app is installed, and a user taps a universal link sent with Iterable,
iOS opens the link in your app (which then tracks the link click using
Iterable's iOS SDK or an API call). If your app is not installed, the link opens
using a web browser (your link tracking domain tracks the click and redirects
the user to the appropriate content on your website).

This document describes how to configure Iterable to send messages that include
universal links.

## Universal links overview

> [!TIP]
> To learn how to configure which links Iterable rewrites as deep links,
> read [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

An iOS app can indicate that it (rather than a web browser) should be used to 
open particular kinds of links. 

To do this, its Xcode project should specify [_associated domains_](https://developer.apple.com/documentation/safariservices/supporting_associated_domains_in_your_app). 
When installing or updating the app, iOS downloads
`apple-app-site-association` files from these associated domains, examines
their contents, and uses any URL patterns associated with the app's App ID as an
indication of the links it can open. With this configuration in place, iOS
passes eligible links directly to the app in question, rather than to a web
browser.

For a deeper understanding of iOS universal links, read Apple's documentation:

- [Universal Links for Developers](https://developer.apple.com/ios/universal-links)
- [Allowing Apps and Websites to Link to Your Content](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content)
- [Supporing Universal Links in Your App](https://developer.apple.com/documentation/uikit/inter-process_communication/allowing_apps_and_websites_to_link_to_your_content/supporting_universal_links_in_your_app)
- [Supporting Associated Domains](https://developer.apple.com/documentation/safariservices/supporting_associated_domains)

## Universal links with Iterable

To help you understand if users are interacting with your content, Iterable 
tracks link clicks. To do this, it rewrites URLs in your messages to point to
your _tracking domain_ (a subdomain such as `links.<YOUR_DOMAIN>.com`). This
domain is hosted by Iterable (as configured by your DNS), and captures click
information before redirecting users to the original link destination.

Iterable rewrites universal links, too. To decide how to do this, Iterable uses 
your `apple-app-site-association` files (you may have multiple—one per
relevant subdomain on your site).

At a high level, using universal links with Iterable works as follows:

- You provide Iterable your `apple-app-site-association` files. These files 
  indicate which links your app can open. For more details, read 
  [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

- Iterable hosts a combination of all of a single tracking domain's `apple-app-site-association`  
  files at `https://<YOUR_LINK_TRACKING_DOMAIN>/apple-app-site-association`.
  For example, `https://links.example.com/apple-app-site-association`.

- When you're setting up your iOS app, you add associated domains to its
  Xcode project. These associated domains link the app to your link tracking 
  domain.

- When a user installs or updates your app, iOS looks at its associated domains 
  and downloads your link tracking domain's aggregate `apple-app-site-association` 
  file.

- When you're sending a campaign, Iterable inspects each link in the message and
  compares it to the paths in the tracking domain's aggregate
  `apple-app-site-association` file, looking for a match. If a match is found,
  Iterable rewrites the link as a deep link.

- When a user receives your message on an iOS device and taps on the 
  rewritten link:

  - If your app is installed, iOS uses it to open your link. In your app, 
    Iterable's SDK (or an API call) tracks information about the link click.

  - Otherwise, iOS opens the link in a web browser, where your link tracking
    domain captures information about the click before redirecting the user
    to the content.
      
### Instructions

To support Universal Links in your iOS app, follow these steps:

1. If you haven't already done so, configure your DNS records to support your
   tracking domain. For more information, read [Email Setup](https://support.iterable.com/hc/articles/7130133854612).

   :::tip NOTE
   After Iterable rewrites links, they have following URL formats:
  
   - Normal links: `links.<YOUR_DOMAIN>.com/u/<PATH>`
   - Deep links: `links.<YOUR_DOMAIN>.com/a/<PATH>`

   Normal links contain `/u/`, and deep links contain `/a/`.
   :::

2. Set up HTTPS for your Iterable link tracking domain.

   For Iterable to successfully rewrite deep links and have your app open
   them as expected, it must host an `apple-app-site-association` file at 
   your link tracking domain. 
   
   Since iOS [requires](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html) 
   that you host `apple-app-site-association` files with HTTPS (and without 
   redirects), you must set up HTTPS for your link tracking domain. To do this, 
   follow the instructions in [Setting up Link Tracking Domains to use HTTPS](https://support.iterable.com/hc/articles/115000427446).

3. Find your `apple-app-site-association` files or create them for each
   subdomain, as needed.

   :::tip NOTES
   - For more information about the `apple-app-site-association` file and how 
     to create one, read Apple's [Supporting Associated Domains](https://developer.apple.com/documentation/safariservices/supporting_associated_domains) document.
   - Iterable can now use unmodified `apple-app-site-association` files to
     understand how to rewrite links for deep linking. Previously, we 
     required a custom `"appID": "iterable"` section in this file; this is no
     longer necessary, but we still support this older format.
   - If you'd like to update your `apple-app-site-association` file to use 
     the the standard format, contact Iterable Support. See [Working with Iterable Support](https://support.iterable.com/hc/articles/5432399749652).
   :::

   If your iOS app currently works with Universal Links, your website already 
   hosts an `apple-app-site-association` file. Apple's [Support Universal Links](https://developer.apple.com/library/archive/documentation/General/Conceptual/AppSearch/UniversalLinks.html)
   document specifies the following:

   > After you create the apple-app-site-association file, upload it to the root
   > of your HTTPS web server or to the .well-known subdirectory. The file needs
   > to be accessible via HTTPS—without any redirects—at
   > `https://<domain>/apple-app-site-association`
   > or `https://<domain>/.well-known/apple-app-site-association`

   To create an `apple-app-site-association` file, use a format similar to the
   following:

   ```json
   {
      "applinks": {
         "apps": [],
         "details": [
            {
               "appID": "<TEAM_ID>.<BUNDLE_ID>",
               "paths": [
                  "NOT /samplepath/toignore",
                  "/samplepath/*"
               ]
            }
         ]
      }
   }
   ```

   The `paths` section defines rules that define which URLs your app can handle. 
   For example:

   - `NOT /samplepath/toignore` defines a URL your app cannot open. When 
     sending messages, Iterable rewrites links that match this path as 
     normal links (containing `/u/`).
   - `/samplepath/*` defines a set of URLs your app can open. When sending
     messages, Iterable rewrites links that match this path as universal links
     (containing `/a/`).

4. Provide the `apple-app-site-association` files to Iterable, as described in
   [Configuring Deep Links for Email or SMS](https://support.iterable.com/hc/articles/115002651226).

5. Configure your Xcode project's **Associated Domains**.

   To understand which links to open with your app instead of a web browser, iOS
   examines the app's `apple-app-site-association` files. To determine how to
   download these files, iOS looks at the associated domains declared in the
   app's Xcode project.

   Iterable hosts an aggregate `apple-app-site-association` file at your link 
   tracking domain. In your Xcode project's **Signing & Capabilities** tab, add 
   the link tracking domain to the list of **Associated Domains**. Use an 
   `applinks:` prefix.

   For example, assuming your link tracking domain is `links.<YOUR_DOMAIN>.com`:

   :::tip NOTE
   iOS downloads a fresh copy of an app's `apple-app-site-association` file 
   only when installing or updating that app. Because of this, changes to this 
   file should be accompanied by a new version of the app.
   :::

6. Update your app's code to handle Universal Links.

   If you're using Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152),
   update your app delegate's [`application(_:continue:restorationHandler:)`](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623072-application)
   method to get the deep link URL and pass it to `IterableAPI.handle(universalLink:)`:

   _Swift_
   ```swift
   func application(_ application: UIApplication, 
                    continue userActivity: NSUserActivity, 
                    restorationHandler: @escaping ([Any]?) -> Void) -> Bool {

      guard let url = userActivity.webpageURL else {
         return false
      }

      // This tracks the click, retrieves the original URL, and uses it to 
      // call handleIterableURL:context:
      return IterableAPI.handle(universalLink: url)
   }
   ```

   _Objective-C_:
   ```objectivec
   - (BOOL)application:(UIApplication *)application 
           continueUserActivity(NSUserActivity *)userActivity 
           restorationHandler:(void (^)(NSArray *restorableObjects))restorationHandler {

      // This track the click, retrieves the original URL, uses it to call
      // `handleIterableURL:context:` 
      return [IterableAPI handleUniversalLink:userActivity.webpageURL];
   }
   ```

   If you aren't using Iterable's iOS SDK, use code similar to the snippet 
   found on [Deep Links Without the SDK](https://support.iterable.com/hc/articles/115003909366)
   for your app delegate's [`application:continueUserActivity:restorationHandler`](https://developer.apple.com/reference/uikit/uiapplicationdelegate/1623072-application)
   method.

   :::tip TIP
   To check if a URL is an Iterable deep link before handling it, use the 
   `isIterableDeepLink` method:

   ```swift
   if IterableAPI.isIterableDeepLink(url.absoluteString) {
       // URL is an Iterable deep link, handle it with the SDK
       IterableAPI.handle(universalLink: url)
   } else {
       // Handle non-Iterable URLs differently if needed
   }
   ```

   This method returns `true` if the URL matches the Iterable deep link pattern
   (URLs containing `/a/` in the path).
   :::

7. Navigate to a specific view or screen in your application.

   :::tip TIP
   This step is relevant only if you're using Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152).
   :::

   Deep links usually navigate the user to a specific place in your app, to view
   some particular piece of content or information. 
   
   You can place this navigation logic in the `IterableURLDelegate.handle(url:)`
   method, which is called _after_ Iterable tracks the link click and grabs any
   campaign-related information from it. In its `url` parameter, this method
   receives the original link you placed in your message content, and your app
   can inspect it as necessary and decide where to take the user.

   Below, `IterableURLDelegate.handle(url:)` calls out to `DeepLinkHandler`, a 
   custom method that handles the navigation. If you follow this pattern, you'll
   need to provide your own implementation for this method. For a reference 
   implementation of this method, check out our [sample code](https://github.com/Iterable/iterable-swift-sdk/blob/master/sample-apps/swift-sample-app/swift-sample-app/DeepLinkHandler.swift).

   _Swift_:
   ```swift
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
       // ...
       // Initialize Iterable SDK
       let config = IterableConfig()
       // ...
       config.urlDelegate = self
 
       IterableAPI.initialize(apiKey: "<YOUR-API-KEY>", launchOptions: launchOptions, config: config)
   }
 
   // Iterable URL delegate. It will be called when you receive 
   // an `openUrl` event from push notification.
   func handle(iterableURL url: URL, inContext context: IterableActionContext) -> Bool {
       return DeeplinkHandler.handle(url: url)
   }
   ```
 
   _Objective-C_:
   ```objectivec
   - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
       // ...
       // Initialize Iterable SDK
       IterableConfig *config = [IterableConfig new];
       // ...
       config.urlDelegate = self;
 
       [IterableAPI initializeWithApiKey:@"<YOUR-API-KEY>" launchOptions:launchOptions config:config];
   }
 
   // Iterable URL delegate. It will be called when you receive 
   // an `openUrl` event from push notification.
   - (BOOL)handleIterableURL:(NSURL *)url context:(IterableActionContext *)context {
       return [DeeplinkHandler handleUrl:url];
   }
   ```
 
8. Make sure your website can display all necessary content

   Some of your users probably won't have your iOS app installed; when these
   users click Universal Links, they will be directed to your website rather
   than your app. It's important to make sure that your website can display the
   necessary content for all links included in your messages.
