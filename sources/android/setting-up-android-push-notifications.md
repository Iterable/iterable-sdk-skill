---
url: https://support.iterable.com/hc/articles/115000331943
title: Setting up Android Push Notifications
useInNovaDocs: true
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/push-notifications/setting-up-android-push-notifications/index.md
source_ref: 16ae7f4a908f84d6eb15fe6f5390f07cc5afe20d
source_sha: 45fa32087746810e08046766184fd4c2eb1acc94
fetched_at: 2026-05-25T15:11:43.429Z
---
# Setting up Android Push Notifications

This guide describes the technical setup necessary to use Iterable to send push 
notifications to Android devices.

:::tip TIP
For details about push notifications on Android, read Google's [Notifications Overview](https://developer.android.com/guide/topics/ui/notifiers/notifications)
document.
:::

## In this article

[[toc]]

## Configuring Iterable to send Android push notifications

Follow the steps below to configure Iterable to send Android push notifications:

### Step 1: Set up Firebase for your Android app

To send Android push notifications, Iterable uses [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
(FCM). To learn how to set up Firebase for your Android app, read Google's
[Add Firebase to your Android project](https://firebase.google.com/docs/android/setup)
document.

### Step 2: Create a mobile app in Iterable

In your Iterable projects, you can define _mobile apps_ that correspond to your
real-world mobile apps. Each mobile app in Iterable stores details about an
app's name, identifier, platform, and store URL. 

To create a mobile app in Iterable:

1. Navigate to **Settings > Apps and Websites**. 

2. Click **New app or website**. This brings up the **New app or website** page:

   ![Creating a new app or website](https://support.iterable.com/hc/article_attachments/26154725921684/new-app-or-website.png "Creating a new app or website")

3. For **Name**, enter the name of your app. For example, `Example Push Test`.

4. For **Platform**, select **Android**.

5. For **Package name**, enter your app's [package name](https://developer.android.com/studio/build/application-id).
   For example, `com.example.pushtest`.

6. (Optional) For **Store URL**, enter your app's Play Store URL.

7. Click **Create app**. You'll be taken to the app's details page:

   ![App details page](https://support.iterable.com/hc/article_attachments/26154740912660/app-details.png "App details page")

### Step 3: Add a push integration to the mobile app

A _push integration_ stores the credentials Iterable uses to authenticate with 
FCM when sending push notifications. Push integrations are stored in the mobile
apps you create in your Iterable project. 

To create a push integration:

1. Create a service account in Firebase.
2. Create a JSON private key that Iterable can use to authenticate with Firebase.
3. Configure the push integration in Iterable.
4. Send a test push notification.

:::warning IMPORTANT
Firebase Cloud Messaging (FCM) has [deprecated their legacy HTTP APIs](https://firebase.google.com/docs/cloud-messaging/migrate-v1) 
and replaced them with the FCM HTTP v1 API. If you have any existing push
integrations that use legacy FCM HTTP API credentials, you'll need to update 
them. For more information, read [Migrating to the FCM HTTP v1 API for Push Notifications](https://support.iterable.com/hc/articles/26143681644564).
:::

#### Step 3.1: Create a service account in Firebase

First, create a [service account](https://firebase.google.com/support/guides/service-accounts)
in Firebase and give it the necessary permissions to send push notifications
on your behalf.

:::tip TIP
Read Google's [Create service accounts](https://cloud.google.com/iam/docs/service-accounts-create)
document for more information.
:::

To create and configure a service account:

1. Sign in your Firebase account. Open the Firebase project that contains the
   app to which you'll send push notifications.

   ![Choosing an app in Firebase](https://support.iterable.com/hc/article_attachments/26154748820628/firebase-mobile-app-tile.png "Choosing an app in Firebase")

2. Click the gear button (in the upper-left). From the menu, choose 
   **Project settings**.

   ![Opening project settings in Firebase](https://support.iterable.com/hc/article_attachments/26154726130452/firebase-project-settings.png "Opening project settings in Firebase")

3. Navigate to the **Service accounts** tab and click **Manage service account permissions**.

   ![Managing service accounts in Firebase](https://support.iterable.com/hc/article_attachments/26154757616916/firebase-service-accounts.png "Managing service accounts in Firebase")

5. To create a new service account, click **Create Service Account**.

   ![Creating a service account in Firebase](https://support.iterable.com/hc/article_attachments/26154741147156/firebase-create-service-account.png "Creating a service account in Firebase")

6. Under **Service account details**, enter a name, account ID, and description. 
   Then, click **Create and Continue**.

   ![Specifying details for a new Firebase service account](https://support.iterable.com/hc/article_attachments/26154741205524/firebase-service-account-details.png "Specifying details for a new service account in Firebase")

7. Under **Grant this service account access to project**, select role 
   [**Firebase Cloud Messaging API Admin**](https://cloud.google.com/iam/docs/understanding-roles#firebasecloudmessaging.admin).
   Or, choose a custom role that has the [`cloudmessaging.messages.create`](https://firebase.google.com/docs/projects/iam/permissions#messaging)
   permission. Then, click **Continue**.
   
   ![Giving a Firebase service account access to a project](https://support.iterable.com/hc/article_attachments/26154757815828/firebase-service-account-grant.png "Giving a Firebase service account access to a project")

   :::tip TIP
   To learn about creating and managing custom Identity and Access Management (IAM)
   roles in Google Cloud, read Google's [Create and manage custom roles](https://cloud.google.com/iam/docs/creating-custom-roles)
   document.
   :::

8. Under **Grant users access to this service account**, leave both fields blank.
   
   ![Granting user access to a Firebase service account](https://support.iterable.com/hc/article_attachments/26154737500308/firebase-service-account-user-access.png "Granting user access to a Firebase service account")

9. Click **Done**. You'll be taken back to the **Service Accounts** page.

#### Step 3.2: Create and download an FCM private key (JSON)

Now, create and download a JSON private key that Iterable can use to
authenticate with FCM when sending push notifications.

1. On the **Service Accounts** page, in the row for your new service account, 
   click the three dots in the **Actions** column. Choose **Manage keys**.

   ![Managing keys for a Firebase service account](https://support.iterable.com/hc/article_attachments/26154741351444/firebase-service-account-manage-keys.png "Managing keys for a Firebase service account")

2. Click **Create new key**, and then choose **JSON**.
   
   ![Creating a JSON private key for a Firebase service account](https://support.iterable.com/hc/article_attachments/26154749445396/firebase-service-account-json.png "Creating a JSON private key for a Firebase service account")

3. Click **Create**. This downloads the JSON private key to your machine.

#### Step 3.3: Configure the push integration in Iterable

Back in Iterable, configure your mobile app's push integration:

1. Navigate to **Settings > Apps and Websites** and open your app.

2. In the **Push** sections, under **Integrations**, in the **Firebase** row, 
   click **Configure**. A **Configure Firebase integration** window will appear.

   ![Configuring a Firebase push integration](https://support.iterable.com/hc/article_attachments/26154758067092/configure-firebase-integration.png "Configuring a Firebase push integration")

3. For **Firebase Cloud Messaging (FCM) type**, choose between:

   - **Notification messages** - The Firebase SDK handles incoming push
     notifications.  Generally, you should only select this option if you aren't
     using Iterable's Android SDK.
   - **Data notifications** - Iterable's SDK handles incoming push notifications.
     If you're using Iterable's Android SDK, this is usually the right option.

   :::tip TIP
   For more information about these options, read [About FCM messages](https://firebase.google.com/docs/cloud-messaging/concept-options),
   from Google.
   :::

4. Upload the JSON file you created above.

5. Click **Save**. As soon as you do, Iterable starts using these new credentials
   to send push notifications to your Android app.

#### Step 3.4: Send a test push notification

Finally, a **Test Firebase integration** window appears. Send a test push 
notification to make sure that everything works as expected (assuming that you've
set your app up to receive push notifications, as described further down in this
document).

![Sending a test message](https://support.iterable.com/hc/article_attachments/26154737764756/test-firebase-integration.png "Sending a test message")

1. Grab a test user's device token:

   - Visit **Audience > User Lookup**.
   - Look up an internal user by `email` or `userId` (whatever makes sense in
     your project).
   - Navigate to the **User fields** tab.
   - Open the `devices` array.
   - From an Android device where `appPackageName` is your app's package name, 
     and `endpointEnabled` is `true`, copy the `token` field.

2. In the **Test Firebase integration** window:

   - Enter the device token and a message. 
   - Click **Send test**. 

   The device should receive the push notification message. If not, check the
   configuration of the service account in Firebase, fix as necessary, and try
   again. If you're still having trouble, contact Iterable support.

### Step 4: Install Iterable's Android SDK in your mobile app

To learn how to install Iterable's Android SDK, read about Iterable's 
[Android SDK](https://support.iterable.com/hc/articles/360035019712).

:::tip NOTE
You can receive Iterable push notifications without setting up the Android
SDK. To do so:

- Set up your Android app as described in Google's 
  [Set up a Firebase Cloud Messaging client app on Android](https://firebase.google.com/docs/cloud-messaging/android/client) document.
- Call [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken) 
  each time the app opens.
- Call [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice) 
  each time the user signs out of the app
- Track push notification opens by calling [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen).
:::

### Step 5: Additional SDK configuration

#### Handling Firebase push messages and tokens

The SDK automatically adds a `FirebaseMessagingService` to the app manifest, so
you don't have to do any extra setup to handle incoming push messages.

If your application implements its own `FirebaseMessagingService`, make sure you
forward `onMessageReceived` and `onNewToken` calls to
`IterableFirebaseMessagingService.handleMessageReceived` and
`IterableFirebaseMessagingService.handleTokenRefresh`, respectively:

```java
public class MyFirebaseMessagingService extends FirebaseMessagingService {

    @Override
    public void onMessageReceived(RemoteMessage remoteMessage) {
        IterableFirebaseMessagingService.handleMessageReceived(this, remoteMessage);
    }

    @Override
    public void onNewToken(String s) {
        IterableFirebaseMessagingService.handleTokenRefresh();
    }
}
```

To handle silent push notifications, use a custom `FirebaseMessagingService`.

:::warning IMPORTANT
The step above is mandatory for handling multiple push providers.
:::

Note that `FirebaseInstanceIdService` is deprecated and replaced with
`onNewToken` in recent versions of Firebase.

#### Disabling push notifications to a device

When a user logs out, you typically want to disable push notifications to
that user/device. This can be accomplished by calling `disablePush`. Please
note that it will only attempt to disable the device if you have previously
called `registerForPush`.

In order to re-enable push notifications to that device, simply call
`registerForPush` as usual when the user logs back in.

### Step 6: Use Iterable to send a test Android push notification

To send a test Android push notification:

1. In Iterable, navigate to **Audience > User Lookup** and enter the user's 
   `email` or `userId`.

   - In the `devices` array, find an object where `appPackageName` corresponds 
     to your app's package name, and `endpointEnabled` is `true`.
   - Copy that object's `token`.

2. Navigate to **Settings > Apps and Websites**.

3. Click the mobile app to which you'd like to send a push notification.

4. In the **Integrations** section, click **Test Push**. You'll see a 
   **Send Test Push** window:

   ![Testing a Firebase integration](https://support.iterable.com/hc/article_attachments/26154737837332/test-push.png "Testing a Firebase integration")

3. Enter the device token you found above, and specify a test message.

5. Click **Send test**.

Monitor the recipient's device to verify that the push notification arrives.

## Android 13: Push notification permissions 

To learn about the `POST_NOTIFICATIONS` permission introduced in Android 13,
which allows you to prompt users for permission to send push notifications,
check out [this information about Android 13](https://support.iterable.com/hc/articles/360057572291#android-13).

## Customizing Android push notifications

The following sections describe the technical setup necessary for various
Android push notification customizations in Iterable.

For marketer-specific information about how to configure these features in 
Iterable when sending a campaign, read [Creating a Push Notification Campaign](https://support.iterable.com/hc/articles/115000379086).

### Notification color

Add this line to `AndroidManifest.xml` to specify the notification color:

```xml
<meta-data android:name="iterable_notification_color" android:value="#FFFFFF"/>
```
where `#FFFFFF` can be replaced with a hex representation of a color of your
choice. In stock Android, the notification icon and action buttons will be
tinted with this color.

You can also use a color resource:

```xml
<meta-data android:name="iterable_notification_color" android:resource="@color/notification_color"/>
```

### Channel name

Since Android 8.0, Android requires apps to specify a channel for every
notification. Iterable uses one channel for all notification; to customize the
name of this channel, add this to `AndroidManifest.xml`:

```xml
<meta-data android:name="iterable_notification_channel_name" android:value="Notifications"/>
```

You can also use a string resource to localize the channel name:

```xml
<meta-data android:name="iterable_notification_channel_name" android:resource="@string/notification_channel_name"/>
```

### Badging / dots

Since Android 8.0, apps can indicate that they've received a notification by
displaying a dot (badge) on their icon.  By default, Iterable's Android SDK
displays these badges. However, you can explicitly enable or disable them in
`AndroidManifest.xml`:

```xml
<meta-data android:name="iterable_notification_badging" android:value="false"/>
```

### Sounds

To add sound to Android push notifications sent with Iterable, follow these 
instructions:

1. Put the necessary sound files in the Android project's **res/raw** folder.

   :::warning IMPORTANT
   - Sound file names should be lowercase and should not have any special 
     characters.
   - Take a look at Android's [documentation about supported media formats](https://developer.android.com/guide/topics/media/media-formats#audio-formats). This documentation is not 
     specific about which formats work for push notifications, so it's best to 
     test as necessary.
   :::

2. Navigate to **Content > Templates** and open the push notification template.

3. Click **Edit details** and scroll down.

4. Enter the path to the custom sound file in the **Custom sound** field.

   ![Custom sound field](https://support.iterable.com/hc/article_attachments/9922751249556/push-custom-sound.png "Custom sound field")

   :::tip NOTES
   - To use the default push notification sound, set this field to `default`.
   - Whether or not a device plays the sound or vibrates depends on the
     user's [device settings](https://support.google.com/android/answer/9082609).
   :::

### Deep links

Iterable push notification templates make it possible to set deep link
URLs for iOS and Android. 

To learn more about using Iterable's Android SDK to handle deep links,
read [Android App Links](https://support.iterable.com/hc/articles/360035127392).

If your app is not using Iterable's Android SDK, it can still handle a deep
link contained in an Iterable push notification. Iterable provides the deep
link URL in the `defaultAction` object included in the notification's
payload. When this object's `type` field is set to `openUrl`, the `data`
field will contain the deep link URL.

After a user has opened a tapped on a push notification to open the app,
use the `getPayloadData` method on `IterableApi` to access the notification 
payload.

### Background color

To set the background color of a push notification, update the
`AndroidManifest.xml` file:

```xml
<meta-data android:name="iterable_notification_color" android:value="#FFFFFF"></meta-data>
```

`#FFFFFF` can be replaced with any hex color. In stock Android, the 
notification icon and action buttons will be tinted with this color.

Alternatively, you can also use a color resource:

```xml
<meta-data android:name="iterable_notification_color" android:resource="@color/notification_color"/>
```

### Custom icons

By default, push notifications display the application icon. To use a 
different icon, place the image resource inside your app's **res/drawable** 
directory. Then, edit `AndroidManifest.xml`, adding the following line:

```xml
<meta-data android:name="iterable_notification_icon" android:resource="@drawable/ic_notification_icon"/>
```

In this case, `ic_notification_icon` is the name of the notification icon.

Alternatively, call `setNotificationIcon(String iconName)` to use the custom 
icon, referencing the image asset by name and without a file extension.

## Further reading

For more information about push notifications in Iterable, read:

- [Sending Push Notifications](https://support.iterable.com/hc/articles/115000379086)
- Iterable's [Android SDK](https://support.iterable.com/hc/articles/360035019712)

