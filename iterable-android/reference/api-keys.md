---
slug: api-keys
feature: integration
archetype: prerequisite
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: API Keys
source_url: https://support.iterable.com/hc/articles/360043464871
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/api/api-keys/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: a471f729824c851571d0c97c020dfc9c68d0dcbc
fetched_at: 2026-09-17T15:31:47.626Z
summary: "[Iterable's API](https://support.iterable.com/hc/articles/204780579)
  can be used to interact with a project's users, templates, campaigns,
  journeys, and more. To authenticate with the API, you must use an API key."
---
# API Keys

[Iterable's API](https://support.iterable.com/hc/articles/204780579) can be 
used to interact with a project's users, templates, campaigns, journeys, and 
more. To authenticate with the API, you must use an API key.

This guide describes the types of API keys Iterable provides, their permissions,
how to manage them, and how to use them.

## API key permissions and security

API keys are secrets that open a gateway to read and/or update the data 
contained in your Iterable project. API keys have permissions that determine what the key can and cannot do. Most API key permissions are governed by the type of API key you create.

Before you make an API key, it's imperative to consider the level of security necessary and decide on the correct [API key type](#api-keys) for your use case.
If you are using a client-side API key, you should also consider additional 
security settings ([Event creation](#event-creation) and [JWT authentication](#jwt-authentication)).

### API keys and their environments

Every Iterable API key is associated with a specific Iterable project, which 
means that it's also associated with a specific data center:

- **USDC-based Iterable projects:** API keys created in USDC-based Iterable 
  projects use the following environments:
  - Base URL: `https://api.iterable.com`
  - API Explorer: <https://api.iterable.com/api/docs>

- **EDC-based Iterable projects:** API keys created in [EDC-based](https://support.iterable.com/hc/articles/17572750887444) 
  Iterable projects use the following environments:
  - Base URL: `https://api.eu.iterable.com`
  - API Explorer: <https://api.eu.iterable.com/api/docs>

### User associated with API key operations

When you use an API key to update or create a resource, the operation is 
usually associated with the user who created the Iterable project.

For certain endpoints, the user associated with the operation can be 
overridden with the `createdByUserId` or the `creatorUserId` parameter (where 
specified) as an optional request parameter.

For example:

- [Snippets APIs](https://support.iterable.com/hc/articles/204780579#snippets) 
  accept the `createdByUserId` parameter to specify the user who created the 
  snippet.
- [Templates APIs](https://support.iterable.com/hc/articles/204780579#templates)
  accept the `creatorUserId` parameter to specify the user who created the 
  template.

### Selecting a key type

When you decide which API key to create, consider:

- Where the API key will be used (server-side applications vs client-side applications)
- What actions the API key will perform (read only, update)
- What data and endpoints the API key will interact with
- Who will have access to the key (client-side keys are accessible to malicious
  users, while server-side keys are kept secret)

If you know which endpoints you will be using, you can check the [API Explorer](https://support.iterable.com/hc/articles/41044692130196#api-explorer)
to see which API key type(s) are required to call each endpoint.

[Server-side API keys](#server-side-keys) have the highest level of access to
read and/or update data, and as a best practice should only be used by servers
making API calls, where they can be kept secret. Using a server-side API key in
a client-side environment is considered a security vulnerability, since 
malicious users of your site or app could potentially access your API key and 
use it to read or change data in your Iterable project.

[Client-side API keys](#client-side-keys) can access only a limited set of
Iterable's API endpoints. However, since you can't prevent malicious users from
accessing API keys stored in client-side code, it's a best practice to
[require JWT authentication](#jwt-authentication) for client-side API key,
since it provides an additional layer of security. You can also choose to allow
a limited time frame to [create new event definitions](#event-creation) while
your project is in development.

### Client-side key security settings

Available security settings for client-side API keys include _Event creation_ and
_JWT authentication_. These options will appear once you select a client-side type
of API key.

#### Event Creation

> [!WARNING]
> Currently, the _Event creation_ permission is only available to newly created
> Iterable organizations as of August 30, 2022. Client-side API keys for existing 
> orgs and projects created before this date don't require this permission to 
> create new events.
>
> It's important to audit your API use at this time and ensure you have correct
> measures in place to avoid disruption when these permissions change.
>
> For more information on our phased release plan, see our 
> [release notes](https://support.iterable.com/hc/articles/5670417757588).

This setting defines whether an API key can create new custom event definitions
in your project. Regardless of the selection, keys can still track known events
as defined in your project's **Custom events**.

- **Block event track calls**: When selected, the API key cannot create new
  custom event definitions. API calls tracking events with a unknown event name
  will be ignored, and the data will not be stored in your project as a tracked
  event.

- **Allow event track calls**: This permission enables a client-side API key
  to post new custom event definitions for the specified period of time, up to
  14 days in the future.

  Until expiration, API calls tracking custom events with a previously untracked
  value for `eventName` will create a new event definition in your project's
  **Custom events**.

  Once the period expires, the permission will toggle back to a blocked state.

  If you need additional time to create events with your API key, you can edit
  the API key later and extend the permission for another 14 days.

> [!NOTE]
> For more information about managing your project's data schema, read 
> [Data Schema Overview](https://support.iterable.com/hc/articles/26678893969812).

#### JWT authentication

Every call to Iterable's API that authenticates with a JWT-enabled API key must
also include a valid JWT as the value of an `Authorization` header (Bearer schema).

When you're creating a client-side key, _JWT authentication_ is selected by
default. Client-side keys that do not require JWT authentication allow 
for anonymous, unauthenticated API access.
**We _strongly_ recommend selecting this option for all of your client-side keys.**

JWT authentication security cannot be changed after you create
your API key. If your key has JWT enabled and you need a key that does not
require JWT, or vice-versa, you will need to create a new key.

To learn more about how to use JWT authentication, check out our guide,
[JWT-Enabled API Keys](https://support.iterable.com/hc/articles/360050801231).

> [!WARNING]
> Using a client-side API key without JWT authentication allows an attacker to
> call API methods on behalf of _any other user in the project_ (provided they
> know or can guess their email address). For example, the attacker could get
> messages for other users, update a victim's email address to their own email,
> etc.
>
> An attacker can also use unsecured keys to unsubscribe any user whose email
> address is known or guessable.

## Types of API keys

Iterable provides five different types of API keys with varying levels of 
access. These keys are classified as either server-side or client-side.

### Server-side keys

> [!WARNING]
> **Never** embed a server-side API key in client-side code (whether JavaScript, a
> mobile application, or otherwise), since they can be used to access project
> data. Use these server-side API keys **only** when making API calls from your servers.

#### Read-only

  Useful for calling Iterable's API in situations where data should only be
  read (never modified), this type of API key can access the following endpoints:

  - [`GET /api/campaigns`](https://support.iterable.com/hc/articles/204780579#get-api-campaigns)
  - [`GET /api/campaigns/metrics`](https://support.iterable.com/hc/articles/204780579#get-api-campaigns-metrics)
  - [`GET /api/campaigns/recurring/{id}/childCampaigns`](https://support.iterable.com/hc/articles/204780579#get-api-campaigns-recurring-id-childcampaigns)
  - [`GET /api/channels`](https://support.iterable.com/hc/articles/204780579#get-api-channels)
  - [`GET /api/experiments/metrics`](https://support.iterable.com/hc/articles/204780579#get-api-experiments-metrics)
  - [`GET /api/journeys`](https://support.iterable.com/hc/articles/204780579#get-api-journeys)
  - [`GET /api/lists`](https://support.iterable.com/hc/articles/204780579#get-api-lists)
  - [`GET /api/lists/{listId}/size`](https://support.iterable.com/hc/articles/204780579#get-api-lists-listid-size)
  - [`GET /api/metadata`](https://support.iterable.com/hc/articles/204780579#get-api-metadata)
  - [`GET /api/metadata/{table}`](https://support.iterable.com/hc/articles/204780579#get-api-metadata-table)
  - [`GET /api/metadata/{table}/{key}`](https://support.iterable.com/hc/articles/204780579#get-api-metadata-table-key)
  - [`GET /api/messageTypes`](https://support.iterable.com/hc/articles/204780579#get-api-messagetypes)
  - [`GET /api/snippets`](https://support.iterable.com/hc/articles/204780579#get-api-snippets)
  - [`GET /api/snippets/{identifier}`](https://support.iterable.com/hc/articles/204780579#get-api-snippets-identifier)
  - [`GET /api/templates`](https://support.iterable.com/hc/articles/204780579#get-api-templates)
  - [`GET /api/templates/email/get`](https://support.iterable.com/hc/articles/204780579#get-api-templates-email-get)
  - [`GET /api/templates/embedded/get`](https://support.iterable.com/hc/articles/204780579#get-api-templates-embedded-get)
  - [`GET /api/templates/getByClientTemplateId`](https://support.iterable.com/hc/articles/204780579#get-api-templates-getbyclienttemplateid)
  - [`GET /api/templates/inapp/get`](https://support.iterable.com/hc/articles/204780579#get-api-templates-inapp-get)
  - [`GET /api/templates/push/get`](https://support.iterable.com/hc/articles/204780579#get-api-templates-push-get)
  - [`GET /api/templates/sms/get`](https://support.iterable.com/hc/articles/204780579#get-api-templates-sms-get)
  - [`GET /api/users/getFields`](https://support.iterable.com/hc/articles/204780579#get-api-users-getfields)

#### Server-side

  Server-side API keys can access all of Iterable's API endpoints, **except** for:

  - [`POST /api/events/inAppConsume`](https://support.iterable.com/hc/articles/204780579#post-api-events-inappconsume)
  - [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
  - [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
  - [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
  - [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
  - [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen)
  - [`POST /api/events/trackWebPushClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackwebpushclick)
  - [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken)

### Client-side keys

#### JavaScript

  Useful for calling Iterable's API from front-end [JavaScript code](https://support.iterable.com/hc/articles/10359708795796),
  this type of API key can access the following endpoints:

  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`POST /api/events/track`](https://support.iterable.com/hc/articles/204780579#post-api-events-track)
  - [`POST /api/events/trackWebPushClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackwebpushclick)
  - [`POST /api/users/merge`](https://support.iterable.com/hc/articles/204780579#post-api-users-merge)
    (For merging an anonymous user only; to merge known users, use a server-side key.)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)

#### Mobile

  Useful for calling Iterable's API from mobile apps (for example, when using
  Iterable's [iOS SDK](https://support.iterable.com/hc/articles/360035018152),
  [Android SDK](https://support.iterable.com/hc/articles/360035019712) or
  [React Native SDK](https://support.iterable.com/hc/articles/360045714072))
  this type of API key can access the following endpoints:

  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`POST /api/embedded-messaging/events/click`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-click)
  - [`POST /api/embedded-messaging/events/received`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-received)
  - [`POST /api/embedded-messaging/events/session`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-session)
  - [`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages)
  - [`POST /api/events/inAppConsume`](https://support.iterable.com/hc/articles/204780579#post-api-events-inappconsume)
  - [`POST /api/events/track`](https://support.iterable.com/hc/articles/204780579#post-api-events-track)
  - [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
  - [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
  - [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
  - [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
  - [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen)
  - [`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages)
  - [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice)
  - [`POST /api/users/merge`](https://support.iterable.com/hc/articles/204780579#post-api-users-merge)
    (For merging an anonymous user only; to merge known users, use a 
    server-side key.)
  - [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  - [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
  - [`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions)

#### Web

  This type of API key can access the following endpoints:

  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`POST /api/embedded-messaging/events/click`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-click)
  - [`POST /api/embedded-messaging/events/received`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-received)
  - [`POST /api/embedded-messaging/events/session`](https://support.iterable.com/hc/articles/204780579#post-api-embedded-messaging-events-session)
  - [`GET /api/embedded-messaging/messages`](https://support.iterable.com/hc/articles/204780579#get-api-embedded-messaging-messages)
  - [`POST /api/events/inAppConsume`](https://support.iterable.com/hc/articles/204780579#post-api-events-inappconsume)
  - [`POST /api/events/track`](https://support.iterable.com/hc/articles/204780579#post-api-events-track)
  - [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
  - [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
  - [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
  - [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
  - [`POST /api/events/trackWebPushClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackwebpushclick)
  - [`GET /api/inApp/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-getmessages)
  - [`GET /api/inApp/web/getMessages`](https://support.iterable.com/hc/articles/204780579#get-api-inapp-web-getmessages)
  - [`POST /api/users/merge`](https://support.iterable.com/hc/articles/204780579#post-api-users-merge)
    (For merging an anonymous user only; to merge known users, use a 
    server-side key.)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  - [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
  - [`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions)

## Creating API keys

To create API keys for an Iterable project:

1. Sign in to an Iterable project as an [org admin](https://support.iterable.com/hc/articles/205480335#org-administrators)
   or as a member that has the [_Manage Integrations_](https://support.iterable.com/hc/articles/205480335#project)
   project permission.

2. Navigate to **Integrations > API Keys**.  This screen lists information about
   each of the API keys that have been created for the project, but it does not
   display the full API keys.

3. Click **New API Key**.

4. In the **Create API Key** window, enter a name for the key and select 
   the [type of API key](#types-of-api-keys) you'd like to generate. 

   It's a good idea to create a descriptive name for the API key so you know
   what the key is used for. This can be helpful if you have security reasons
   to disable or delete keys later, or for when you simply need to find and
   update a key later.

5. (Client-side only) If you have selected a client-side key type, you will
   see additional settings:

   - _Event Creation_ - Block creation of new event definitions, or allow them
     for up to 14 days in the future. For more information on this setting, see
     [Event creation](#event-creation) above.

   - _JWT Authentication_ - this is selected by default and highly recommended.
     To learn more about why this is encouraged, see
     [JWT authentication](#jwt-authentication) above.

   :::warning IMPORTANT
   There are two things to know about enabling JWT authentication (or not):

   - JWT authentication can only be enabled or disabled when you create the API
     key. This setting cannot be changed later.

   - If you enable JWT authentication for an API key, you cannot later convert
     it to a different type of API key. For example, you cannot change a mobile
     API key that requires JWT authentication into a server-side API key.
   :::

6. When you have finished, click **Create**.

   ![Creating a new API key](https://support.iterable.com/hc/article_attachments/19310367284244/create-api-key.png "Creating a new API key")

7. In the **Copy Your New API Key** window, copy the API key:

   ![Copying an API key](https://support.iterable.com/hc/article_attachments/19310329981972/copy-api-key.png "Copying an API key")

   If your API key requires JWT authentication, also copy the **JWT Secret** your
   server should use when generating per-user JSON Web Tokens:

   ![Copying an API key and its JWT secret](https://support.iterable.com/hc/article_attachments/19310338279444/copy-api-key-and-secret.png "Copying an API key and its JWT secret")
   
   Store the values displayed on this screen in a secure location. After you
   close the window, Iterable cannot display them again. If you lose them, you'll
   need to create a new API key.

## Using API keys

### Providing API keys in HTTP requests

With any HTTP client in your application code, or using a third-party tool such 
as [Postman](https://www.postman.com), [Insomnia](https://insomnia.rest)
or [curl](https://curl.haxx.se), the API key must be provided as an HTTP 
request header.

To do this, set the API key as the value for an `Api-Key` or `Api_Key` request 
header. The parameter name is not case sensitive.

For example:

```
curl -H "Api-Key: <YOUR_API_KEY>" https://api.iterable.com/api/users/user@example.com
```

or

```
curl -H "Api-Key: <YOUR_API_KEY>" https://api.eu.iterable.com/api/users/user@example.com
```

#### Exceptions for legacy projects

Certain legacy projects have exceptions that still allow API keys to be 
provided in the query string or request body. However, this is not a best 
practice and it is not supported for most projects.

> [!WARNING]
>
> Beginning November 10, 2025, API calls that provide the key in the query string 
> or request body will be subject to **stricter rate limiting**. This change only 
> impacts legacy projects with exceptions to make API calls using the query 
> string or request body.
>
> To avoid being impacted by this change, modify your application code to use 
> API keys as HTTP request headers instead of using the query string or request 
> body.

### Using API keys with Iterable's SDKs

You can use an Iterable API key with Iterable's [Web SDK](https://support.iterable.com/hc/articles/10359708795796), 
[iOS SDK](https://support.iterable.com/hc/articles/360035018152#step-6-initialize-the-sdk-with-your-api-key),
[Android SDK](https://support.iterable.com/hc/articles/360035019712#step-5-set-sdk-configuration-options) 
[React Native SDK](https://support.iterable.com/hc/articles/360045714132#step-6-initialize-iterable-s-react-native-sdk).

Make sure to use a client-side API key with the SDKs. 

## Editing API keys

When you edit an API key, you can change the following:

- **Name**

- **Event Creation** (client-side keys) - This permission can be extended for
  14 days at a time. 
  
  API Keys that were created prior to August 5, 2022 have legacy permissions
  for event creation and have no restrictions when creating new event definitions.
  When you edit a legacy key, you will see a notice and have the option to update
  the key to the new permission settings and either block event creation, or
  apply an expiration period for event creation. You cannot change this permission
  back to the legacy setting once this has been set.

JWT authentication can only be changed at the time the key is created. If you
need a key with or without this security, [create a new key](#creating-api-keys).

To edit an API key:

1. Navigate to **Integrations > API Keys**.

2. Click **Edit** for the API key you'd like to modify.

3. In **Edit API Key** window, provide updated values for the API key. Then, click 
   **Update**.

   :::tip NOTE
   You cannot change the type of an API key that requires JWT authentication.
   :::

## Disabling API keys

Disabling keys can be helpful when there are security reasons to restrict access
for specific applications and/or when troubleshooting problems with your data.

Disabled keys can be re-enabled later.

To disable an API key:

1. Navigate to **Integrations > API Keys**:

2. Find the API key to delete. In its row, click the down arrow and select
   **Disable Key**. 

## Deleting API keys

This is a permanent action. Only delete an API key if it is no longer in use.
If you are not sure, you can instead disable it.

To delete an API key:

1. Navigate to **Integrations > API Keys**:

2. Find the API key to delete. In its row, click the down arrow and select
   **Delete Key**. 

3. Confirm the deletion.

## Want to learn more?

For more information about some of the topics in this article, check out these 
resources. Iterable Academy is open to everyone — you don't need 
to be an Iterable customer!

**Iterable Academy**
- [Creating and Managing Your API Key](https://academy.iterable.com/setting-up-and-using-an-api-key-in-iterable)

**Support docs**
- [Getting Started with Iterable's API](https://support.iterable.com/hc/articles/41044692130196)
- [API Endpoints and Sample Payloads](https://support.iterable.com/hc/articles/204780579)
- [JWT-Enabled API Keys](https://support.iterable.com/hc/articles/360050801231)
