---
slug: user-profile-testing-and-troubleshooting
feature: user-profiles
archetype: feature
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: Testing and Troubleshooting User Profiles
source_url: https://support.iterable.com/hc/articles/360035079512
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/managing-user-profiles/testing-and-troubleshooting-user-profiles/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: 0a355a206dbbda47fa468a293aa64ee0ae837111
fetched_at: 2026-10-06T10:28:56.748Z
summary: To verify that a user profile has been generated and contains the right
  data, go to **Audience > Contact Lookup** and search by the user's email
  address or user ID. This will return a matching user profile if the user
  exists.
---
# Testing and Troubleshooting User Profiles

## Viewing a user profile

To verify that a user profile has been generated and contains the right data, go 
to **Audience > Contact Lookup** and search by the user's email address or user 
ID. This will return a matching user profile if the user exists.

![Viewing a user profile](https://support.iterable.com/hc/article_attachments/18551573134356/viewing-a-user-profile.png "Viewing a user profile")

> [!NOTE]
> - You can store a soft limit of 1,000 fields on a user profile.
> - In email-based projects, if you create a new user by setting the `IterableAPI.userId`
>   SDK property, Iterable automatically assigns that user an `@placeholder.email` 
>   email address (this is a user identifier — not a valid email address). To 
>   learn more, see [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956).

## Troubleshooting common issues

### User profile not found

There are a couple of possible reasons for this error:

- Make sure you're signed in to the right project. (User profiles created and
  updated in your sandbox project won't appear in production, and vice versa).

- Make sure you're creating users _after_ initiating the Iterable SDK.

### User profile update failed

This error may be caused by a record conflict. To troubleshoot, first find out 
which [unique identifier](https://support.iterable.com/hc/articles/9216719179796) 
your project uses.

For email-based projects, we recommend using `email` as the primary key when 
updating a user's profile. If you use `userId`, you may run into a duplicate 
record error, as this field is non-unique in this project type.

### Error: `dataTypeMismatch`

This error occurs when you pass the wrong data format for an existing field.
Make sure all your data formats match when making an update user profile call.

### Invalid API key

Verify that your API key is valid. For more information about API keys, read
[API Keys](https://support.iterable.com/hc/articles/360043464871).

> [!WARNING]
> **Never** embed server-side API keys in client-side code (whether JavaScript, a 
> mobile application or otherwise), since they can be used to access all of your
> project's data. Use server-side API keys **only** when making API calls from your
> servers.

### Error 4XX: Email already exists

You'll see this error when you make a [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
call and propose a new email address that already exists on another user profile
in your Iterable project.

### Duplicate users

This can happen when your web and mobile apps don't sync properly. If a user 
changes their email address in your web app, their Iterable user profile is 
updated with their new email address. If your mobile app isn't synced to fetch 
new data from an updated user profile, when the user acesses your mobile app 
later, the `registerDeviceToken` method creates a new user with their old email 
address.

Make sure you're not calling the `registerDeviceToken` method with a user's old 
email address.