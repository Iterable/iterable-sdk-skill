---
slug: creating-users-with-apis
feature: user-profiles
archetype: identity
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Creating and Identifying Users with Iterable APIs
source_url: https://support.iterable.com/hc/articles/29156459027348
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/api/creating-users-with-APIs/index.md
source_ref: 80c2226068f35b6fef335738f56a39f4f4b3d3ca
source_sha: d3b50cd710c17034c2b70030d968192cde7913f6
fetched_at: 2026-10-22T13:16:29.996Z
summary: Understanding user identification is fundamental to working with
  Iterable's API effectively. The steps for creating and identifying users vary
  depending on your project type and the way you identify users. This article
  describes how to identify and create users with Iterable's APIs for
  email-based, userID-based, and hybrid projects.
---
# Creating and Identifying Users with Iterable APIs

Understanding user identification is fundamental to working with Iterable's API 
effectively. The steps for creating and identifying users vary depending on 
your project type and the way you identify users. This article describes how to 
identify and create users with Iterable's APIs for email-based, userID-based, 
and hybrid projects.

For more information about the relationship between project types and user 
identification, read [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

> [!NOTE]
> This article covers _most_ aspects of user identification and creation, 
> however, it doesn't cover how to manage unknown users (for example, users who 
> don't have an `email` address).
>
> Iterable provides two different ways to manage unknown users:
> - [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956)
> - [Unknown User Activation](https://support.iterable.com/hc/articles/38755339847188)

## Understanding user identification in API requests

Many of Iterable's API endpoints require you to specify a particular user (for 
example, to modify their user profile or fetch data about them). The way you 
identify users depends on your project type.

### Project types and user identification

To identify a user, provide a `userId` or an `email` in your API request body. 
This field typically goes at the top level of your request, outside of 
`dataFields`.

Your **project type** determines which fields you can use to identify users:

- **UserID-based projects** identify users by `userId`, and Iterable enforces 
  the uniqueness of this field.

- **Hybrid projects** identify users by `email` and/or `userId`, and Iterable 
  enforces the uniqueness of both. However, you don't have to provide both 
  fields to every user.

- **Email-based projects** identify users by `email` or `userId`. However, 
  Iterable only enforces `email` uniqueness, _not_ `userId`. (Email-based projects have limited availability. To learn more, read [Project Type Availability](https://support.iterable.com/hc/articles/9216719179796#project-type-availability).)

### Field validation and requirements

When you send an API request that includes an `email` or `userId`, Iterable 
validates these fields regardless of your project type.

- **`email`**: Iterable checks that the field is a valid email address format 
  and converts the value to lowercase. Iterable does _not_ check 
  deliverability. To learn more, read [Email Validation in Iterable](https://support.iterable.com/hc/articles/209082806).

- **`userId`**: Iterable rejects requests with `userId` values that don't meet 
  certain requirements. To learn more, see [UserID Validation in Iterable](https://support.iterable.com/hc/articles/41111923969556).

  Additionally, when identifying a user, the `userId` field must be 
  **non-empty**:

    - Blank, null, or empty values for `userId` are not accepted in requests to 
      identify users.

    - API requests with a `userId` lookup field that is blank, null, or empty 
      are rejected. Instead, if a user doesn't have a `userId` value, such as 
      in a hybrid project, use the `email` field to identify the user and 
      _don't_ include a blank `userId` field in the API request.

    - For email-based and hybrid projects, API requests that include `userId` 
      with a null value in `dataFields` with intention to clear the data from a 
      user profile are accepted.

### Precedence rules when both fields are provided

If you include both `email` and `userId` at the top level of an API request, 
precedence rules apply based on your project type:

- **Email-based projects**: `email` takes precedence
- **UserID-based projects**: Only `userId` is valid; `email` is treated as a 
  regular data field
- **Hybrid projects**: `userId` takes precedence

### Basic API request structure

Here's the standard structure for API requests that identify users:

```json
{
  "userId": "user1234567",           // User identifier (outside dataFields)
  "dataFields": {                    // User profile updates go here
    "favoriteColor": "red"
  }
}
```

**Important guidelines:**

- Place user identifiers (`userId` or `email`) at the top level of your 
  request, _outside_ of `dataFields`.

- Place profile updates you'd like to make for that user _inside_ the 
  `dataFields` object.

- _Do not include_ empty `userId` values to look up users in your API request. 
  Iterable rejects blank `userId` when provided to locate a record. However, 
  API requests for email-based and hybrid projects that include `userId` with a 
  null value nested in `dataFields`, with intention to clear the data from a 
  user profile, are still accepted.

- Some requests require you to place `userId` or `email` inside another object, 
  rather than at the top level of your API request. For example, when calling 
  [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart),
  you need to place `userId` or `email` inside a `user` object.

- Additionally, some requests use slightly different field names. For example, 
  [`POST /api/email/target`](https://support.iterable.com/hc/articles/204780579#post-api-email-target)
  requires `recipientEmail` and `recipientUserId`, rather than `email` and 
  `userId`. For endpoint-specific details, consult our [API Endpoints and Sample Payloads](https://support.iterable.com/hc/articles/204780579).

## Email-based projects

> [!NOTE]
> Email-based projects have limited availability. To learn more, read [Project Type Availability](https://support.iterable.com/hc/articles/9216719179796#project-type-availability).

In email-based projects, you can pass `email` and/or `userId` in requests to 
identify users. The behavior depends on which fields you provide:

- If both fields are present, `email` is prioritized to identify the user, and 
  the `userId` field is updated/overwritten for most requests that use `PUT` or 
  `POST` methods.

- If `email` is passed and there is no user with that email address, Iterable 
  creates a new user when using the following endpoints:

  - [`POST /api/email/target`](https://support.iterable.com/hc/articles/204780579#post-api-email-target)
  - [`POST /api/inApp/target`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-target)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  - [`POST /api/users/bulkUpdate`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdate)
  - [`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions)
  - [`POST /api/users/bulkUpdateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdatesubscriptions)
  - [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/lists/subscribe`](https://support.iterable.com/hc/articles/204780579#post-api-lists-subscribe)
  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`PUT /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}?action=subscribe`](https://support.iterable.com/hc/articles/204780579#put-api-subscriptions-subscriptiongroup-subscriptiongroupid)

- If only `userId` is passed (and not `email`), and there is no matching user, 
  Iterable returns an error. To avoid this and create a user without an email,
  include the parameter `preferUserId` with a value of `true`. This creates the
  user with an auto-generated placeholder email address using the
  `@placeholder.email` domain. For more information about placeholder email
  addresses, read [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956).

- If only `userId` is passed in a request to an email-based project, and 
  multiple users share the same `userId` but have different `email` values, 
  Iterable updates only one of the users. This occurs because `userId` is not 
  enforced as unique in email-based projects. The API selects the first user 
  returned in the query, but this selection is not consistent and may vary 
  between requests.

- Tracking events for an unknown user **does not** create a new user.

### Email-based project behavior across Iterable

- Lists must include an `email` column.

- [Hosted Signup Forms](https://support.iterable.com/hc/articles/207914276)
  are available for static lists.

- When previewing a template, use `email` to populate sample data.

- Journey triggers can be tested with `email` only.

- Static list subscriptions are stored in the `emailListIds` field.

> [!NOTE]
> This is the only type of project where Iterable creates a `iterableEndUserId` 
> browser cookie (which will be deprecated at a future date). This may impact 
> your implementation of a [subscription preference center](https://support.iterable.com/hc/articles/208463956)
> and when [tracking conversions, purchases, and revenue](https://support.iterable.com/hc/articles/205480285).

### Identifying users in email-based projects

In email-based projects, `email` takes precedence when both `email` and 
`userId` are provided. For example, this request to [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
looks up or creates a user with `email` address `user@example.com`, then sets 
their `favoriteColor` to `red`:

```json
{
   "email": "user@example.com",
   "userId": "user1234567",
   "dataFields": {
      "favoriteColor": "red"
   }
}
```

### Creating new users in email-based projects

To create a new user and assign them a unique email address in an email-based
project, make a request to one of the various endpoints that can create new
users in one of these ways:

- Update user data (individually or in bulk)
- Target users with email and in-app campaigns
- Update subscription information
- Update the shopping cart and track purchases
- Register device and browser tokens

For example, you can call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update) with
a request body such as:

```json
{
  "email": "user@example.com",
  "dataFields": {
    "favoriteColor": "red"
  }
}
```

For this request:

- If your project doesn't yet have a user with an `email` address of 
  `user@example.com`, Iterables creates one.

- Then, whether the user is new or already exists, Iterable sets their 
  `favoriteColor` to `red`.

### Creating new users when `email` is unknown

To create a new user for someone with an unknown email address (in an
email-based project), provide a `userId` instead of an `email`. When you do 
this, Iterable creates a new user with a placeholder `email` address using the 
`@placeholder.email` domain.

To learn more about how to do this, read [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956).

Once a placeholder `email` is assigned to a user, you can identify this user in 
subsequent API calls by their `userId`, or by the placeholder `email` given to 
them by Iterable.

### Assigning a `userId` to an existing user

In an email-based project, you can assign a `userId` to an existing user who is 
already identified by `email` by making an API call to [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update).

To learn more about how to do this, read [Updating a User's Email Address or User ID](https://support.iterable.com/hc/articles/217502386).

## UserID-based projects

> [!TIP]
> UserID-based is often the most sensible type of project to choose, because
> it:
>
> - Is simple to use. You always identify users by `userId`.
> - Allows you to match Iterable `userId` values with user identifiers you use in 
>   other systems.
> - Allows multiple users to share the same email address, which can sometimes
>   be useful.

UserID-based projects identify users exclusively by `userId`. In these 
projects, `email` is not a user identifier—it's treated like any other profile 
field (such as `favoriteColor`). You can assign `email` addresses to users, but 
you can't use `email` to look up or modify users in Iterable's web UI or when 
making API calls.

Key considerations for userID-based projects:

- The `userId` field must always be present and unique for any endpoint that 
  uses a unique identifier, including GDPR forget and unforget endpoints
- Multiple users can have the same `email` address since email uniqueness is 
  not enforced
- If `userId` is passed and there is no matching user, Iterable
  creates a new user when using the following endpoints:

  - [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
  - [`POST /api/events/track`](https://support.iterable.com/hc/articles/204780579#post-api-events-track)
  - [`POST /api/events/trackBulk`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackbulk)
  - [`POST /api/events/trackWebPushClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackwebpushclick)
  - [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen)
  - [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
  - [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
  - [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
  - [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
  - [`POST /api/workflows/triggerWorkflow`](https://support.iterable.com/hc/articles/204780579#post-api-workflows-triggerworkflow)
  - [`POST /api/email/target`](https://support.iterable.com/hc/articles/204780579#post-api-email-target)
  - [`POST /api/inApp/target`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-target)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  - [`POST /api/users/bulkUpdate`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdate)
  - [`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions)
  - [`POST /api/users/bulkUpdateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdatesubscriptions)
  - [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/lists/subscribe`](https://support.iterable.com/hc/articles/204780579#post-api-lists-subscribe)
  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`PUT /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}?action=subscribe`](https://support.iterable.com/hc/articles/204780579#put-api-subscriptions-subscriptiongroup-subscriptiongroupid)

- When an API request includes the parameter `preferUserId`, it's ignored.

- If you try to use `email` to identify a user when making an API call, the
  request returns an error. You can only identify users with `userId`.

- You aren't required to provide an `email` for every user you upload to
  Iterable. Placeholder email addresses aren't necessary.

- Iterable doesn't enforce `email` uniqueness. In other words, many users can
  have the same email address.

- Tracking events for an unknown user **creates** a new user.

### UserID-based project behavior across Iterable

- When creating a new list, specify a `userId` column, instead of an `email` 
  column.

- [Hosted Signup Forms](https://support.iterable.com/hc/articles/207914276)
  are unavailable at this time.

- When previewing a template, use `email` or `userID` to populate sample data.

- Journey triggers can be tested with `email` or `userID`.

- Iterable doesn't set a `iterableEndUserId` browser cookie.

- To identify users when you create a [custom subscription center](https://support.iterable.com/hc/articles/208463956), pass `userId` 
  as a URL parameter using the following Handlebars in the [hosted unsubscribe](https://support.iterable.com/hc/articles/206382645#hosted-unsubscribe-url) URL project setting:

  :::v-pre
  `{{userId}}`
  :::   

- To identify users when [tracking conversions, purchases, and revenue](https://support.iterable.com/hc/articles/205480285), add a URL 
  parameter with a Key of userId and Value of: 
  :::v-pre
  `{{userId}}`
  :::

- When a user unsubscribes from a link in an email (`emailUnSubscribe`, `hostedUnsubscribeClick`, 
  or `emailComplaint` event), Iterable attributes the unsubscribe to the user's 
  unique `userId`, not the email address that received the message. This is 
  important when you have users who share an email address.

- Static list subscriptions are stored in the `userListIds` field.

- When sending a proof to an unknown email address (including when sending a
  proof "to myself" for the first time), Iterable creates a new user and
  automatically assigns a `userID` with the value `itbl_generated_{{email}}` 
  (where the email address is part of the `userId`).

  :::tip TIP
  To look up users by email address in a userID-based project, use the
  segmentation tool and segment by the contact property `email`.
  :::

### Identifying users in userID-based projects

In userID-based projects, `userId` is the _only_ valid user identifier, and 
uniqueness is enforced.

For this request to [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update),
Iterable looks up or creates a user with `userId` of `user1234567`, then sets 
their `favoriteColor` to `red`:

```json
{
   "email": "user@example.com",
   "userId": "user1234567",
   "dataFields": {
      "favoriteColor": "red"
   }
}
```

Iterable also sets the user's `email` to `user@example.com`, as this is a field 
included in the request body. However, since `email` is not a user identifier 
in userID-based projects, the API does not verify its uniqueness. Multiple 
users could have the same `email` address with different `userId` values.

### Creating new users in userID-based projects

In userID-based projects, when you make an API request that includes a `userId`
not yet used by your project, some endpoints create new users:

- Update user data (individually or in bulk)
- Target users with email and in-app campaigns
- Update subscription information
- Update the shopping cart and track purchases
- Register device and browser tokens
- Track events (individually or in bulk)
- Trigger workflows

For example, call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update), with a
request body such as:

```json
{
  "userId": "user1234567",
  "dataFields": {
    "favoriteColor": "red"
  }
}
```

For this request:

- If there's no user with `userId` set to `user1234567`, Iterable creates one. 
- Whether the user is new or already exists, Iterable sets their 
  `favoriteColor` to `red`.

### Assigning email in userID-based projects

You _may_ assign an `email` to each user in a userID-based project, but it's 
not a required field and isn't used to identify unique users.

> [!NOTE]
> Since `email` is not a required field in userID-based projects, Iterable does
> not automatically assign `@placeholder.email` addresses like it does in 
> email-based projects.

To do this, call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update), with a
request body such as:

```json
{
  "userId": "user1234567",
  "dataFields": {
    "email": "user@example.com"
  }
}
```

For this request:

- If there's no user with `userId` set to `user1234567`, Iterable creates one.
- Whether the user is new or already exists, Iterable sets their `email` to 
  `user@example.com`.

  :::tip NOTE
  In userID-based projects, Iterable does not enforce `email` uniqueness. This
  allows you to give the same `email` to many users in the same project, which 
  can sometimes be useful.
  :::

## Hybrid projects

Hybrid projects use both `email` and `userId` as unique identifiers. Key 
behaviors include:

- Use either `userId` or `email` (but not both) to identify users in API 
  requests.

- If you provide both fields, `userId` takes precedence.

- Both `email` and `userId` must be unique, and this policy is enforced.

- If `userId` and/or `email` are passed and there is no matching user, Iterable
  creates a new one when using the following endpoints:

  - [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
  - [`POST /api/events/track`](https://support.iterable.com/hc/articles/204780579#post-api-events-track)
  - [`POST /api/events/trackBulk`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackbulk)
  - [`POST /api/events/trackWebPushClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackwebpushclick)
  - [`POST /api/events/trackPushOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackpushopen)
  - [`POST /api/events/trackInAppOpen`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappopen)
  - [`POST /api/events/trackInAppClick`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclick)
  - [`POST /api/events/trackInAppDelivery`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappdelivery)
  - [`POST /api/events/trackInAppClose`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackinappclose)
  - [`POST /api/workflows/triggerWorkflow`](https://support.iterable.com/hc/articles/204780579#post-api-workflows-triggerworkflow)
  - [`POST /api/email/target`](https://support.iterable.com/hc/articles/204780579#post-api-email-target)
  - [`POST /api/inApp/target`](https://support.iterable.com/hc/articles/204780579#post-api-inapp-target)
  - [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  - [`POST /api/users/bulkUpdate`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdate)
  - [`POST /api/users/updateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-updatesubscriptions)
  - [`POST /api/users/bulkUpdateSubscriptions`](https://support.iterable.com/hc/articles/204780579#post-api-users-bulkupdatesubscriptions)
  - [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken)
  - [`POST /api/users/registerBrowserToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerbrowsertoken)
  - [`POST /api/lists/subscribe`](https://support.iterable.com/hc/articles/204780579#post-api-lists-subscribe)
  - [`POST /api/commerce/trackPurchase`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-trackpurchase)
  - [`POST /api/commerce/updateCart`](https://support.iterable.com/hc/articles/204780579#post-api-commerce-updatecart)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/user/{userEmail}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-user-useremail)
  - [`PATCH /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#patch-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`DELETE /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}/byUserId/{userId}`](https://support.iterable.com/hc/articles/204780579#delete-api-subscriptions-subscriptiongroup-subscriptiongroupid-byuserid-userid)
  - [`PUT /api/subscriptions/{subscriptionGroup}/{subscriptionGroupId}?action=subscribe`](https://support.iterable.com/hc/articles/204780579#put-api-subscriptions-subscriptiongroup-subscriptiongroupid)

- If you are adding a user with an invalid `email` value, it is rejected
  even if it has a `userId` included in the request.

- When an API request includes the parameter `preferUserId`, it's ignored.

- You aren't required to provide an `email` for every user you upload to
  Iterable—placeholder email addresses aren't necessary.

- You aren't required to provide a `userId` for every user, however Iterable
  doesn't create one when the value is missing.

- To process a GDPR request to forget a user, you can use either `email` or
  `userId` with the [`POST /api/users/forget`](https://support.iterable.com/hc/articles/204780579#post-api-users-forget)
  endpoint.

#### Hybrid project behavior across Iterable

- When creating a new list, specify either a `email` or `userId` column, at 
  minimum, or upload a list with both columns.

- [Hosted Signup Forms](https://support.iterable.com/hc/articles/207914276)
  are available for static lists.

- When previewing a template, use `email` or `userID` to populate sample data.

- Journey triggers can be tested with `email` or `userID`.

- Iterable doesn't set a `iterableEndUserId` browser cookie.
:::v-pre
- To identify users when you create a [custom subscription center](https://support.iterable.com/hc/articles/208463956), pass `userId` 
  as a URL parameter using Handlebars (`{{userId}}`) in the [hosted unsubscribe](https://support.iterable.com/hc/articles/206382645#hosted-unsubscribe-url) URL project setting.

- To identify users when [tracking conversions, purchases, and revenue](https://support.iterable.com/hc/articles/205480285), add a URL 
  parameter with a **Key** of `userId` and **Value** of `{{userId}}`.
:::
- Static list subscriptions are stored in the `userListIds` field.

- When sending a proof to an unknown email address (including when sending a
  proof "to myself" for the first time), Iterable creates a new user.

### Identifying users in hybrid projects

In hybrid projects, both `userId` and `email` are valid unique identifiers, but 
`userId` always takes precedence when both are provided.

For this request to [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update),
Iterable finds or creates a user with `userId` of `user1234567` and sets their 
`favoriteColor` to `red`:

```json
{
   "email": "user@example.com",
   "userId": "user1234567",
   "dataFields": {
      "favoriteColor": "red"
   }
}
```

Iterable also attempts to set the user's `email` to `user@example.com` (even 
though it is provided outside of `dataFields`). Since hybrid projects enforce 
email uniqueness, Iterable first checks if that email is already in use:

- **If no profile exists with that `email`**: The request succeeds, creating/updating
  the user with both identifiers.
- **If a profile exists with that `email`**: The request fails with HTTP status 
  code `409`—you can't reuse an email address that belongs to another user.

### Creating new users in hybrid projects

In hybrid projects, when you make an API request that references a non-existent
`userId` or `email`, some endpoints create new user profiles:

- Update user data (individually or in bulk)
- Target users with email and in-app campaigns
- Update subscription information
- Update the shopping cart and track purchases
- Register device and browser tokens
- Track events (individually or in bulk)
- Trigger workflows

For example, you can call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
with a request body such as:

```json
{
  "email": "user@example.com",
  "dataFields": {
     "favoriteColor": "red"
  }
}
```

For this request:

- If there's no user with an `email` of `user@example.com`, Iterable creates one. 
- Whether the user is new or already exists, Iterable sets their `favoriteColor`
  to `red`.

Another example request:

[`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)

```json
{
  "userId": "user1234567",
  "dataFields": {
     "favoriteColor": "red"
  }
}
```

For this request:

- If there's no user with a `userId` of `user1234567`, Iterable creates one.
- Whether the user is new or already exists, Iterable sets their `favoriteColor`
  to `red`.
 
> [!NOTE]
> In userID-based projects, Iterable's API ignores the `preferUserId` parameter
> used in email-based projects for some endpoints.

## Want to learn more?

For more information about some of the topics in this article, check out these 
resources. Iterable Academy is open to everyone—you don't need 
to be an Iterable customer!

**Iterable Academy**
- [Foundations: Introduction to API](https://academy.iterable.com/learn/courses/36/foundations-introduction-to-api)

**Support docs**
- [API Keys](https://support.iterable.com/hc/articles/360043464871)
- [API Overview and Sample Payloads](https://support.iterable.com/hc/articles/204780579)
- [Responding to Data Subject Requests](https://support.iterable.com/hc/articles/360029174171)
