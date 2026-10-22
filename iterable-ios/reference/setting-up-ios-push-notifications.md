---
slug: setting-up-ios-push-notifications
feature: push-notifications
archetype: prerequisite
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Setting up iOS Push Notifications
source_url: https://support.iterable.com/hc/articles/115000315806
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/push-notifications/setting-up-ios-push-notifications/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 0b1ae308d8199639122d2e6ff8e53fc87db4fba6
fetched_at: 2026-10-02T13:52:10.408Z
summary: This article describes how to get set up to send push notifications
  from Iterable to your iOS apps.
---
# Setting up iOS Push Notifications

This article describes how to get set up to send push notifications from Iterable
to your iOS apps. 

## Instructions

To get set up to send push notifications to your iOS app, follow these steps:

### Step 1: Enable push notifications in Xcode

First, add the Push Notifications capability to your app's Xcode project. To do 
this, follow the steps in the "Enable the Push Notifications Capability" section 
of Apple's [Registering Your App with APNs](https://developer.apple.com/documentation/usernotifications/registering_your_app_with_apns)
article.

### Step 2: Enable push notifications in the Apple Developer Portal

Next, in the Apple Developer Portal, enable the Push Notifications capability
for your App ID:

1. Sign in to the [Apple Developer Portal](https://developer.apple.com).

2. In the left nav, click **Certificates, IDs & Profiles**.

3. On the **Certificates, IDs & Profiles** page, in the left nav, click 
   **Identifiers**.

4. View your app's details by clicking its App ID.

5. On the **Capabilities** tab, scroll down and check the **Push Notifications**
   capability.

6. Save your changes.

> [!TIP]
> Make sure to regenerate and reinstall your provisioning files after adding the
> Push Notifications capability to your App ID.

### Step 3: Create and download an auth token or certificate from Apple

To send a push notification, Iterable has to communicate with Apple's Push
Notification Service (APNs) on your behalf, telling it what message to send and
where to send it. To authenticate with APNs, Apple provides token-based 
authentication (.p8 files) and certificate-based authentication (.p12 or PEM files).

> [!TIP]
> We recommend using token-based authentication (.p8 files). This approach is easier 
> to set up, auth tokens don't expire (so you don't need to worry about an expired
> certificate preventing you from sending push notifications), and push notifications 
> can be sent at a faster rate.

> [!NOTE]
> Token-based push authentication doesn't require the use of Iterable's mobile
> SDKs (and if you do use the SDKs, there's no particular SDK version requirement).

- **Token-based authentication (.p8 file)** — Recommended by Apple. With this approach,
  Iterable can use the same, non-expiring auth token to send push notifications
  to all of your apps (development and production). This is the fastest, most
  convenient, least error-prone way to authenticate with APNs. To set up token-based 
  authentication:

  1. Follow the instructions Apple provides in [Establishing a Token-Based Connection to APNs](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns).

  2. Download the .p8 file. You'll upload it to Iterable in a later step.

- **Certificate-based authentication (.p12 file or PEM file)** — With this approach, 
  Iterable uses per-app, per-environment (development and production)
  certificates to send push notifications to your apps. These certificates
  expire each year, so you have to manually keep them up-to-date. To set up 
  certificate-based authentication:
  
  1. Follow the instructions Apple provides in [Establishing a Certificate-Based Connection to APNs](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_certificate-based_connection_to_apns).

  2. Download the certificate on your Mac. Then, install it in **KeyChain Access**
     by double-clicking it and choosing to install it in your **login** keychain.

  3. Open **Keychain Access** and select the **login** keychain.

  4. Select the certificate you just installed, and choose **File > Export Items**.

  5. Enter a name in the **Save As** field. 

  6. Accept the default `.p12` file format and click **Save**. Respond to the 
     prompts, and enter a password for the file if necessary.

  7. Keep track of this file. You'll upload it to Iterable in a later step.

### Step 4: Create or update an app in Iterable

Iterable uses _mobile apps_ to store information about your mobile apps: their
names, identifiers, platforms, store URLs, and push notification 
configuration—including authentication credentials needed to send push
notifications.

> [!TIP]
> To create or update a mobile app in Iterable, you'll need to sign in with an account
> whose role includes the [_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project) permission.

To create or update a mobile app in Iterable:

1. Navigate to **Settings > Apps and websites**. 

2. If you've already created a mobile app in Iterable, open it up to view its
   details. Otherwise, create a new app by clicking **Add a new app or website**, 
   and fill in the various fields:

   - **Name** — The name of your app. For example, `My Test App`.
   - **Platform** — **iOS**
   - **Bundle ID** — Your app's bundle ID. For example, `com.example.testapp`.
   - **Store URL** — Optional. Your app's App Store URL.

   Then, click **Create app**. 

3. Click **Add new credential**.

4. Depending on the type of credentials you generated in the previous section of 
   this article, select **.p8 Auth Key**, **.p12 Certificate**, or **PEM File**:

   ![Choose a type of credential](https://support.iterable.com/hc/article_attachments/8157607707284/integration-credentials.png "Choose a type of credential")

   Then, click **Continue**.

5. Upload and configure your credentials.

   - **For .p8 auth tokens:**

     ![Setting up an authentication token](https://support.iterable.com/hc/article_attachments/8157593840532/p8-upload.png "Setting up an authentication token")

     - Upload your .p8 file.
     - Enter your **Key ID**, which you can find in the Apple Developer Portal
       (it's displayed on the page where you download the key, and when you click 
       into the key details).
     - Enter your **Team ID**, which you can find on the **Membership** tab of
       your account in the Apple Developer Portal.
     - Enter your app's **Bundle ID**.
     - Click **Update**.

     :::warning IMPORTANT
     When adding auth tokens (.p8 files) to your iOS mobile apps in Iterable,
     don't delete any certificates (.p12 files) that are already in use.
     Instead, add the .p8 files using the **Upload & Replace** option found in
     the overflow menu for the existing push integration. This will prevent any
     interruption in Iterable's ability to send push notifications to your users
     (and everything will just keep working when your existing certificates
     expire, too).

     ![Upload and replace a .p12 file](https://support.iterable.com/hc/article_attachments/8158482180500/upload-and-replace.png "Upload and replace a .p12 file")
     :::

   - **For .p12 certificates:**

     ![Setting up a certificate](https://support.iterable.com/hc/article_attachments/8157594001044/p12-upload.png "Setting up a certificate")

     - Upload your .p12 file.
     - Enter the password for the certificate.
     - Select an environment (production or sandbox).
     - Click **Update**.

   - **For PEM files:**

     ![Setting up a PEM file](https://support.iterable.com/hc/article_attachments/8157644495380/pem-upload.png "Setting up a PEM file")

     :::tip INFO
     A PEM file is another representation of the same information found in a .p12 
     file. 
     :::

     - Paste in the text for your certificate.
     - Paste in the text for your RSA private key.
     - Choose an environment (production or sandbox).
     - Click **Update**.

### Step 5: Install and configure Iterable's iOS SDK

Iterable's iOS SDK simplifies the process of working with push notifications in
your iOS apps. To learn how to install and configure this SDK, read
[Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152).

> [!NOTE]
> Don't use the SDK? You don't have to use Iterable's iOS SDK to receive push
> notifications from Iterable.  If you'd like, you can work with our API instead:
>
> - Call [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken) 
>   each time the app opens, to save the device's push token to Iterable.
>
> - Call [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice) 
>   each time a user signs out of the app, to prevent further push notifications
>   from being sent to that user.
>
> - Call [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen)
>   to track push notification opens.

### Step 6: Send a test push notification

Now, send a test push notification:

1. In Iterable, navigate to **Audience > Contact Lookup**. Enter the user's 
   email address or their user ID (the search box will reflect the necessary
   field) and pull up their Iterable user profile.

2. Find the `devices` array on their profile, and use the `appPackageName` field 
   to find the object that corresponds to your app.

3. Copy the `token` field from this object. You'll use this value to send your
   test push notification.

4. Navigate to **Settings > Apps and websites**. Click the mobile app to which you'd
   like to send a test push notification.

6. In the **Push Credentials** section, click **Test Push**. This will bring up
   the **Send Test Push** window, where you can enter:
   
   - **Device token** — The token you found above, which determines the
     destination app and recipient for your test push message.
   - **Message** — A test message to send.

7. On your mobile device, make sure the iOS app is _not_ in the foreground (by
   default, iOS apps do not display their own push notifications when they're
   in the foreground).

8. Click **Send notification**.

9. The push notification should arrive on the device.
