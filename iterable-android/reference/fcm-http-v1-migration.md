---
slug: fcm-http-v1-migration
feature: push-notifications
archetype: prerequisite
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: "Mobile Push Notifications: Migrating to the FCM HTTP v1 API"
source_url: https://support.iterable.com/hc/articles/26143681644564
source_repo: Iterable/iterable-docs
source_path: docs/sending-messages-by-channel/push-notification/mobile-push-notifications-migrating-to-the-fcm-http-v1-api/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: 72ab970eba676b48e10caa249676e03f51799a8e
fetched_at: 2026-09-17T15:31:48.877Z
summary: If any of your Iterable projects use Firebase Cloud Messaging (FCM) to
  send mobile or web push notifications, migrate them to the FCM HTTP v1 API
  **before July 22, 2024** (Google has changed the deadline from June 20 to July
  22). [On July 22,
  2024](https://firebase.google.com/docs/cloud-messaging/migrate-v1), Google
  will start shutting down the legacy FCM API, and Iterable projects that still
  use…
---
# Mobile Push Notifications: Migrating to the FCM HTTP v1 API

If any of your Iterable projects use Firebase Cloud Messaging (FCM) to send
mobile or web push notifications, migrate them to the FCM HTTP v1 API 
**before July 22, 2024** (Google has changed the deadline from June 20 to July 22).
[On July 22, 2024](https://firebase.google.com/docs/cloud-messaging/migrate-v1), 
Google will start shutting down the legacy FCM API, and Iterable projects that 
still use it will no longer be able to send mobile or web push notifications.

> [!TIP]
> This document discusses mobile push notifications. For information about migrating 
> web push notifications to the new FCM HTTP v1 API, read 
> [Web Push Notifications: Migrating to FCM HTTP v1 API](https://support.iterable.com/hc/articles/26920391539604).

## Overview

Iterable can use Firebase Cloud Messaging (FCM) to send mobile push notifications. 
To do this, it relies on the FCM API. However, Google has [deprecated the legacy FCM APIs](https://firebase.google.com/docs/cloud-messaging/migrate-v1), 
and replaced them with the FCM HTTP v1 API. Because of this, you must update any
Iterable projects that use the legacy FCM APIs.

> [!WARNING]
> Make these updates **before** Google starts shut off the legacy FCM APIs on 
> July 22, 2024. Otherwise, you won't be able to continue sending push 
> notifications.

> [!WARNING]
> Older Iterable project can contain _unassigned_ push integrations – push integrations
> that haven't been assigned to _mobile apps_ on the **Settings > Apps and websites**
> page of your Iterable project. To migrate these push integrations to the FCM HTTP 
> v1 API, you'll need to first assign them to mobile apps. For more information, see 
> [Appendix: Unassigned push integrations](#appendix-unassigned-push-integrations).

> [!NOTE]
> To migrate an Iterable project to the new FCM API, you'll need to add a new 
> Firebase private key (JSON) to the project. However, you do **not** need to
> update the device tokens stored on the user profiles in that project. The
> existing device tokens will continue to work as expected. Similarly, there's no
> need to release new versions of your apps.

The instructions below describe how to:

1. Create a sandbox project in Iterable.
2. For each of your mobile apps:
   - Gather some preliminary information.
   - Create a JSON private key for the new FCM API.
   - Send a test push notification from your sandbox project.
   - Update your production Iterable projects.

If you have any questions, or if you need any help with the steps in this
document, [contact Iterable support](https://support.iterable.com/hc/articles/5432399749652).

## Step 1: Create a sandbox project in Iterable

> [!TIP]
> You can use the same sandbox project to test the FCM private keys for all of
> your mobile apps — there's no need to create multiple sandbox projects. Also, if
> you have an existing sandbox project in Iterable, you can use that one rather
> than creating a new one, if you like.

Before updating your mobile apps to use the new FCM HTTP v1 API, create a
sandbox project in Iterable. You'll use this project to send test push
notifications, to make sure everything is working right before upgrading your
production mobile apps to the new FCM API.

To create a sandbox project:

1. Sign in to Iterable with a user that has the [_Create Projects_](https://support.iterable.com/hc/articles/205480335#org-permissions) 
   org permission.

2. [Create a new project](https://support.iterable.com/hc/articles/204795639#creating-a-project). 

   ![Creating a sandbox project in Iterable](https://support.iterable.com/hc/article_attachments/26154758265364/create-sandbox-project.png "Creating a sandbox project in Iterable")

   - For **Name**, provide a name that clearly identifies the project as a
     sandbox (non-production) project.

   - For **Time zone**, select any time zone that makes sense.

   - For **Unique identifier**, choose any unique identifier you like
     (**email**, **userId**, or **hybrid**). When sending test push notifications,
     you'll target specific device tokens, not user identifiers, so your selection
     here isn't particularly consequential in this case.

   - Click **Create**. Iterable creates the new project and switches you to it.

## Step 2: Test push notifications in your sandbox project

> [!TIP]
> Complete the steps in this section (through the end of the document) for each of
> your mobile apps to which Iterable sends push notifications through FCM.

For each of the mobile apps to which you use Iterable to send push notifications
through FCM, follow the steps below to:

1. Gather some preliminary information.
   - The app's legacy FCM server API key.
   - The app's package name and FCM message type.
   - A device token for a test user.
2. Create JSON private keys for the new FCM API.
3. Use the new JSON private keys to send test messages from a sandbox project.
4. Update your production Iterable projects.

### Step 2.1: Find your mobile app's legacy FCM server API key 

First, find the legacy server API key and sender ID you _currently_ use to send
push notifications to the mobile app under consideration.

If you have trouble upgrading your production Iterable projects to the new FCM
API, you can use the FCM server API key to revert to the legacy FCM API — as long 
as Google hasn't shut it off yet (which will start happening on July 22, 2024).

To find your mobile app's legacy FCM server API key:

1. Sign in to Firebase: [https://firebase.google.com](https://firebase.google.com)

2. Click **Go to console**.

   ![Firebase](https://support.iterable.com/hc/article_attachments/26154741703188/firebase-go-to-console.png "Firebase")

3. Click the tile corresponding to the Firebase project you use for the mobile 
   app in question.

   ![Selecting an app in Firebase](https://support.iterable.com/hc/article_attachments/26154749929620/firebase-mobile-app-tile.png "Selecting an app in Firebase")

4. Click the settings gear and select **Project settings**.

   ![Navigating to Project Settings in Firebase](https://support.iterable.com/hc/article_attachments/26154727251220/firebase-project-settings.png "Navigating to Project Settings in Firebase")

5. Go to the **Cloud Messaging** tab. 

6. In the **Cloud Messaging API (Legacy)** section, next to **Server key**, there's 
   a **Token** value (some projects may have multiple tokens). A token is a legacy 
   FCM server API key — copy one of them and keep it in a safe place, but don't 
   share it with others.

   ![Locating an app's legacy FCM API key](https://support.iterable.com/hc/article_attachments/26154741831956/firebase-legacy-token.png "Locating an app's legacy FCM API key")

### Step 2.2: Find your mobile app's package name and FCM message type

Next, find the package name and FCM message type associated with your app.

Every Android mobile app has a package name — a unique identifier such as
`com.example.pushtest`. To find the package name associated with one of your
Android apps, you can look at its definition in a production Iterable project:

1. With a user who has permission to [_View Channels_](https://support.iterable.com/hc/articles/205480335#project) 
   or [_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project), 
   sign in to a production Iterable project where the mobile app is defined.

2. Click **Settings > Apps and Websites**.

3. Click the tile that corresponds to your mobile app.

   ![Selecting a mobile app in an Iterable project](https://support.iterable.com/hc/article_attachments/26154738266004/iterable-production-app-tile.png "Selecting a mobile app in an Iterable project")

4. From the **Details** section, copy the app's **Package Name**. Save this value. 
   You'll need it later when adding the app to a sandbox Iterable project (which 
   you'll use to test your new FCM setup before updating your production Iterable 
   projects).

   ![Finding an app's package name in Iterable](https://support.iterable.com/hc/article_attachments/26154697931284/iterable-production-app-package-name.png "Finding an app's package name in Iterable")

5. While you're on this page, also note the app's **Message Type** (this is the 
   [Firebase message type](https://firebase.google.com/docs/cloud-messaging/concept-options), 
   not the [Iterable message type](https://support.iterable.com/hc/articles/204780529)): 
   **Data notifications** or **Notification messages**.

> [!NOTE]
> Previously, to help you choose a push integration's FCM message type, Iterable
> provided an **OS Notifications** toggle. Now, to better align with Firebase
> terminology, Iterable refers to this value as an _FCM message type_.
>
> - **OS Notifications** _OFF_ is equivalent to an FCM message type of 
>   **Data notifications**. 
> - **OS Notifications** _ON_ is equivalent to an FCM message type of 
>   **Notification messages**.
>
> Usually, for apps that use Iterable's Android SDK, you'll usually want to select
> **Data notifications**.

### Step 2.3: Find a device token for a test user

To test your new FCM private keys (JSON) in a sandbox Iterable project, you'll
need the device token for a test user who has your app installed.

1. Find the `userId` or `email` associated with the Iterable user profile of an 
   _internal user_ who has your app installed. This should **not** be an end 
   user/customer, since you'll be sending a test push notification they'll receive 
   on device.

2. Sign in to Iterable with a user who has permission to [_View User Profiles and Data_](https://support.iterable.com/hc/articles/205480335#audience) 
   or [_Create and Manage User Profiles and Data_](https://support.iterable.com/hc/articles/205480335#audience).

3. Switch to the Iterable project that contains the test user's profile.

4. Navigate to **Audience > User Lookup**.

5. Enter the user's `userId` or `email` and click **Search users**.

6. On the user's profile, in the left navigation menu, select **User fields**.

7. In the **User fields** section of the page, open the `devices` array.

8. Look through each item in the `devices` array until you find one where
   `appPackageName` is your app's package name, and `endpointEnabled` is `true`.

   ![An Iterable user profile: appPackageName and endpointEnabled](https://support.iterable.com/hc/article_attachments/26154697985556/iterable-user-profile-1.png "An Iterable user profile: appPackageName and endpointEnabled")
   ![An Iterable user profile: token](https://support.iterable.com/hc/article_attachments/26154698088980/iterable-user-profile-2.png "An Iterable user profile: token")

9. Copy the object's `token` value. You'll use it later, to send a test push
   notification.

### Step 2.4: Create a Firebase service account

> [!TIP]
> For more information about topics discussed in this section, read Google's
> documentation: [Firebase Service Accounts Overview](https://firebase.google.com/support/guides/service-accounts), 
> [Create service accounts](https://cloud.google.com/iam/docs/service-accounts-create) and
> [Create and manage custom roles](https://cloud.google.com/iam/docs/creating-custom-roles).

Next, create a Firebase service account and give it sufficient permission to
send push notifications on your behalf. When you create a private key in the
next step, you'll associate it with this Firebase service account. To create and
configure a Firebase service account:

1. Sign in to Firebase: [https://firebase.google.com](https://firebase.google.com)

2. Click **Go to console**.

3. Click the tile corresponding to the mobile app you're working on.

4. Click the settings gear and select **Project settings**.

5. Navigate to the **Service accounts** tab.

6. Click **Manage service account permissions**.

   ![Managing service accounts in Firebase](https://support.iterable.com/hc/article_attachments/26154742174612/firebase-service-accounts.png "Managing service accounts in Firebase")

7. To create a new Firebase service account, click **Create Service Account**.

   ![Creating a service account in Firebase](https://support.iterable.com/hc/article_attachments/26154742213396/firebase-create-service-account.png "Creating a service account in Firebase")

8. Under **Service account details**, enter a name, account ID, and description.
   Then, click **Create and Continue**.

   ![Specifying details for a new Firebase service account](https://support.iterable.com/hc/article_attachments/26154698268564/firebase-service-account-details.png "Specifying details for a new service account in Firebase")

9. Under **Grant this service account access to project**, select a role:
   [**Firebase Cloud Messaging API Admin**](https://cloud.google.com/iam/docs/understanding-roles#firebasecloudmessaging.admin),
   or a custom role with permission [`cloudmessaging.messages.create`](https://firebase.google.com/docs/projects/iam/permissions#messaging).
   Then, click **Continue**.

   ![Giving a Firebase service account access to a project](https://support.iterable.com/hc/article_attachments/26154759105556/firebase-service-account-grant.png "Giving a Firebase service account access to a project")

10. Under **Grant users access to this service account**, leave both fields blank 
    and click **Done**.

    ![Granting user access to a Firebase service account](https://support.iterable.com/hc/article_attachments/26154750871316/firebase-service-account-user-access.png "Granting user access to a Firebase service account")

11. You'll land back on the **Service Accounts** page.

### Step 2.5: Create and download a JSON private key for the new FCM API

Now, create and download a JSON private key associated with the Firebase service
account you just created.

> [!TIP]
> As you complete this step, do not delete your app's legacy server key from
> Firebase — keep it in place.  This ensures the success of any in-progress push
> notification sends associated with that key, and it also allows you to revert to
> the legacy FCM API if necessary.

Now, create and download a JSON private key associated with the Firebase service
account you just created:

1. Make sure you're still in the Firebase console, in the correct app.

2. On the **Service Accounts** page, in the row for your new Firebase service
   account (created in the previous step), click the three dots in the **Actions**
   column. Then, choose **Manage keys**.

   ![Managing keys for a Firebase service account](https://support.iterable.com/hc/article_attachments/26154738838164/firebase-service-account-manage-keys.png "Managing keys for a Firebase service account")

3. Select **Add Key > Create new key**, and choose **JSON**.

   ![Creating a JSON private key for a Firebase service account](https://support.iterable.com/hc/article_attachments/26154728196116/firebase-service-account-json.png "Creating a JSON private key for a Firebase service account")

4. Click **Create**. This creates the JSON key and downloads it to your machine.

### Step 2.6: Add your mobile app to your Iterable sandbox project

To add a mobile app to your sandbox project:

1. Sign in to your sandbox Iterable project with a user who has the [_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project)
   permission. (If necessary, [create a new user](https://support.iterable.com/hc/articles/115002084386) 
   with this permission.)

2. Navigate to **Settings > Apps and Websites**.

3. Click **Add new**.

4. Specify a **Name**, **Platform** (Android, most likely), and **Package name**
   (the package name you found in step 2.2, above).

   ![Adding a mobile app to a sandbox project in Iterable](https://support.iterable.com/hc/article_attachments/26154765599380/iterable-sandbox-create-app.png "Adding a mobile app to a sandbox project in Iterable")

5. Click **Create app**.

### Step 2.7: In the sandbox project, configure the mobile app's FCM push integration

Now, configure the mobile app in the sample project to use the new FCM private
key. In your sandbox Iterable project, open the mobile app's definition. Then:

1. In the **Push** section, next to **Firebase**, click **Configure**. This
   brings up the **Configure Firebase integration** window.
   
   ![Configuring a sandbox push integration in Iterable](https://support.iterable.com/hc/article_attachments/26154759407636/iterable-sandbox-configure-integration.png "Configuring a sandbox push integration in Iterable")

2. For **Firebase Cloud Messaging (FCM) type**, choose **Notification messages**
   or **Data notifications**. Select the same value you found for this app in step
   2.2, above.

3. Click **Browse files**. From your local machine, select the JSON private key
   you created for this app in step 2.2.2, above.

4. After your JSON private key uploads, click **Save**.

### Step 2.8: Send a test message from your sandbox project

Now, test the sandbox push integration you just configured. After you upload
your JSON private key and click **Save**, a **Test Firebase integration** window
appears:

![Sending a test push notification to a sandbox app](https://support.iterable.com/hc/article_attachments/26154751250708/iterable-sandbox-app-test-message.png "Sending a test push notification to a sandbox app")

1. In this window, enter the device token you found in step 2.3, above.
   Remember: this token should be associated with an **internal** user of the app
   you're currently testing, not an end user or customer.

2. Enter a message and click **Send test**. Verify that the user receives the
   message on their device.

#### Troubleshooting the test message from your sandbox project

If the test message doesn't arrive as expected, try the following:

- Make sure the device object from which you copied the token (remember, the
  token came from an object in a `devices` array on an Iterable user profile) has:
  - An `appPackageName` that matches your app's package name.
  - `endpointEnabled` set to `true`. If `endpointEnabled` is `false`, it means
    the push integration is inactive, and Iterable cannot send it any messages.
    Keep looking in the `devices` array until you find a device where `endpointEnabled` 
    is `true`.
- Make sure the FCM private key file (JSON) you uploaded to Iterable is
  connected to a Firebase [service account](https://firebase.google.com/support/guides/service-accounts) 
  associated with the app you're testing.
- Make sure the Firebase service account associated with the FCM private key has
  permission [`cloudmessaging.messages.create`](https://firebase.google.com/docs/projects/iam/permissions#messaging).
- In your Iterable project, make sure you've correctly configured the push
  integration's FCM message type. If mobile app's original definition (in one of
  your production Iterable projects) has **OS Notifications** off, the sandbox
  project's push integration should use **Data notifications**. Otherwise, it
  should use **Notification messages**.
- From the mobile app definition in a production Iterable project, try sending a
  test push notification to the test user device token you found in step 2.3,
  above. If the test notification doesn't arrive on the user's device, your app
  may not be configured correctly to display push notifications.

If the test user still doesn't receive your test push notification, 
[contact Iterable support](https://support.iterable.com/hc/articles/5432399749652).

## Step 3: Update your production Iterable projects

> [!WARNING]
> Complete this step for each mobile app definition in a production Iterable
> project for which you use FCM to send push notifications. However, make sure
> to first test each mobile app in your sandbox project.

After sending a successful test push notification to a given app, update
any production Iterable projects that are associated with that app. 

For every relevant production Iterable project:

1. Sign in to an Iterable project associated with the mobile app, with a user
   with the [_Setup and Manage Channels_](https://support.iterable.com/hc/articles/205480335#project)
   permission. 

2. Navigate to **Settings > Apps and Websites**.

3. Click the tile associated with your mobile app. It should display an **Update** 
   banner, indicating it must be updated to work with the new FCM API.

   ![Selecting a mobile app in an Iterable project](https://support.iterable.com/hc/article_attachments/26154739102740/iterable-production-app-tile.png "Selecting a mobile app in an Iterable project")

4. In the **Push** section, in the **Firebase** row, click **Update**.

   ![Updating a production app to FCM HTTP v1 API](https://support.iterable.com/hc/article_attachments/26154759526932/iterable-production-app-update.png "Updating a production app to FCM HTTP v1 API")

5. In the **Configure Firebase integration** window:

   ![Configuring the production app push integration](https://support.iterable.com/hc/article_attachments/26154759602324/iterable-production-app-upload-json.png "Configuring the production app push integration")

   - The **Firebase Cloud Messaging (FCM)** type should match the value you found 
     in step 2.2, above. **DO NOT** modify this setting.

   - Upload the new FCM private key (JSON) you created for this app in step 2.2.2, 
     above.

   - Click **Save**.

6. In the **Test Firebase integration** window:

   ![Sending a test push notification to a production app](https://support.iterable.com/hc/article_attachments/26154739287700/iterable-production-app-test-message.png "Sending a test push notification to a production app")

   - Enter the same device token you found in step 2.3, above.

   - Enter a message.

   - Click **Send test** and verify the message arrives on the user's device.

> [!NOTE]
> You _can_ choose send a test push notification _later_. However, if possible, do
> it right away.
>
> When you upload a new FCM private key (JSON) to a given app's push integration,
> Iterable immediately starts using that key when sending push notifications — even 
> if you don't send a test message.
>
> If there's a problem with the new FCM private key, or with your push integration's 
> configuration, then your Iterable project can't send push notifications to that 
> app until you resolve the issue.
>
> So, if there's a problem, it's a good idea to find out right away.

### Troubleshooting a production project

If your production test message doesn't arrive on the test user's device, take a
look at the steps described in this section.

#### Re-upload your private key

If you accidentally uploaded the wrong private key (JSON file), you can switch
to the correct one:

1. On the far-right side of the row associated with the push integration you're
   updating, click the button identified by three dots. Then, select 
   **Edit integration**.

   ![Editing a production app push integration](https://support.iterable.com/hc/article_attachments/26154742843284/iterable-production-app-edit-integration.png "Editing a production app push integration")

2. Upload the correct private key (JSON file), and then click **Save**.

   ![Uploading a new private key to a production app push integration](https://support.iterable.com/hc/article_attachments/26154739411604/iterable-production-app-replace-json.png "Uploading a new private key to a production app push integration")

3. Send a test push notification.

   ![Testing an updated private key in a production app push integration](https://support.iterable.com/hc/article_attachments/26154739470100/iterable-production-app-test-replaced-json.png "Testing an updated private key in a production app push integration")

If the test message still doesn't appear on the test user's device, try
reverting to your legacy API key while you troubleshoot the problem (see next
section).

####  Revert to your legacy FCM server key while you troubleshoot

> [!WARNING]
> Your legacy FCM server API key will only work until Google [starts turning off](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
> the legacy API, on July 22, 2024. If, by that point, you haven't updated your 
> mobile app's definition in your Iterable project, you won't be able to continue 
> sending push notification campaigns to that app, from that project. If you're having any
> trouble, [contact Iterable support](https://support.iterable.com/hc/articles/5432399749652).

To revert your mobile app definition back to your legacy FCM server API key,
make sure you're still in your production Iterable project, and that you're
looking at the mobile app definition associated with the app you're updating.
Then:

1. On the far-right side of the row associated with the push integration you
   need to revert, click the button identified by three dots and select 
   **Revert to legacy API key**. 

   ![Reverting to a legacy FCM API key in a production app push integration](https://support.iterable.com/hc/article_attachments/26154739560468/iterable-production-app-revert-to-legacy-api-key.png "Reverting to a legacy FCM API key in a production app push integration")

2. In the **Configure Firebase integration** window:

   ![Entering the legacy API key in a prodution app push integration](https://support.iterable.com/hc/article_attachments/26154766127636/iterable-production-app-revert-enter-api-key.png "Entering the legacy API key in a prodution app push integration")

   - The **Firebase Cloud Messaging (FCM)** type should match the value you
     found in step 2.2, above. **DO NOT** modify this setting.

   - In the **API Key** field, paste the legacy server API key you found for
     this app in step 2.1, above.  

   - Click **Save**.

3. In the **Test Firebase integration** window:

   - Enter the same device token you found in step 2.3, above.

   - Enter a message.

   - Click **Send test**. Your test user should receive the message.

#### Troubleshooting ideas

To investigate why your production push integration isn't sending push
notifications as expected:

- Make sure the device object from which you copied the token (remember, the
  token came from an object in a `devices` array on an Iterable user profile) has
  an `appPackageName` that matches your app's package name, and `endpointEnabled`
  set to `true`.
- Make sure the FCM private key file (JSON) you uploaded to Iterable is
  connected to a Firebase [service account](https://firebase.google.com/support/guides/service-accounts) 
  associated with the app you're testing.
- Make sure the Firebase service account associated with the FCM private key has
  permission [`cloudmessaging.messages.create`](https://firebase.google.com/docs/projects/iam/permissions#messaging).
- Make sure that, when you updated your production push integration, that you 
  didn't inadvertently change the FCM message type from **Data notifications** 
  to **Notification messages**, or vice-versa.
  - Do not modify this setting in a production project unless you are 100%
    confident it's the right thing to do. Changing this setting incorrectly can
    prevent your users from receiving push notifications.
  - To determine the correct FCM message type:
    - Consult your notes from step 2.2.
    - Check with your mobile engineers. 
    - Assuming you added the app in question to your sandbox project (above),
      and that you successfully sent and received a test push notification from
      that sandbox project, you can check the FCM message type on the app's 
      sandbox push integration.
    - If your app uses Iterable's mobile SDKs, you'll probably use 
      **Data notifications**.
- From the mobile app definition in your sandbox Iterable project, try sending a
  test push notification to the same device token. If it arrives, try to determine 
  how the push integration is configured differently in the two projects.

> [!TIP]
> If you've checked these things and your test user still does not receive a push
> notification, [contact Iterable support](https://support.iterable.com/hc/articles/5432399749652).

## Appendix: Unassigned push integrations

Some older Iterable projects may have push integrations that aren't assigned
to a mobile app (as defined on **Settings > Apps and websites**). To update
these unassigned push integrations to the new FCM HTTP v1 API:

1. Define a mobile app in your Iterable project.
2. Assign the existing push integration to the new mobile app.
3. Update the push integration to use a JSON private key for FCM.

### Step 1: Define a mobile app in your Iterable project

To upgrade an "unassigned" push integration to the new FCM HTTP v1 API, first 
create a mobile app in your Iterable project. This mobile app app should
correspond to a real-world mobile app to which you send push notifications.

To create a mobile app in Iterable:

1. Navigate to **Settings > Apps and Websites**. 

2. Click **New app or website**. This brings up the **New app or website** page:

   ![Creating a new app or website](https://support.iterable.com/hc/article_attachments/27456462437396/new-app-or-website.png "Creating a new app or website")

3. For **Name**, enter the name of your app. For example, `Example Push Test`.

4. For **Platform**, select **Android**.

5. For **Package name**, enter your app's [package name](https://developer.android.com/studio/build/application-id).
   For example, `com.example.pushtest`.

6. (Optional) For **Store URL**, enter your app's Play Store URL.

7. Click **Create app**. You'll be taken to the app's details page:

   ![App details page](https://support.iterable.com/hc/article_attachments/27456453781652/app-details.png "App details page")

### Step 2: Assign the existing push integration to the new mobile app

After you've created a mobile app, assign the existing, unassigned push
integration to it. Don't worry, assigning a push integration to a mobile app
doesn't affect the integration's ability to continue sending push notifications.

> [!WARNING]
> Assign the push integration to the new mobile app that you created in the
> previous step — not a previously existing app. Previously existing apps may
> already be targeted by various campaigns, which could then be sent to the newly
> assigned push integration.

To associate an existing push integration with your new mobile app:

![Assigning a push integration to an app](https://support.iterable.com/hc/article_attachments/27456439910932/assign-integration.png "Assigning a push integration to an app")

1. Navigate to **Settings > Apps and websites**.

2. In the **Unassigned Integrations** section, at the bottom of the page, find 
   the existing push integration.

3. For that push integration, click **Assign App**.

4. In the **Assign push integration** window, select the mobile app you just created.

5. Click **Assign**.

> [!NOTE]
> After clicking **Assign**, you may see an error message, but you can ignore it.
> Additionally, the previously unassigned push integration remains visible in the 
> **Unassigned Integrations** area until you navigate away and come back, even though 
> it has already been assigned to the app you selected.

### Step 3: Update the push integration to use a JSON private key for FCM

Now, to learn how to create private keys for the FCM HTTP v1 API and test them
in a sandbox project, and how to update the mobile apps in your production
Iterable projects to use those new private keys, follow the steps at the top of
this document.
