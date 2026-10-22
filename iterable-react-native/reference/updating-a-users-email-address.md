---
slug: updating-a-users-email-address
feature: user-profiles
archetype: identity
sdk_min_version: 3.2.1
sdk_artifact: "@iterable/react-native-sdk"
title: Updating a User's Email Address or User ID
source_url: https://support.iterable.com/hc/articles/217502386
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/api/updating-a-users-email-address/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: 510751fc6ae6e983ceae45146ba7e44f491ee7b2
fetched_at: 2026-10-22T10:00:23.018Z
summary: Sometimes you'll need to change the email address or user ID for a
  user—perhaps they were previously anonymous and now they have converted to a
  known contact, their `email` has changed, or you are updating your project's
  `userId` fields to standardize, correct, or otherwise update this value.
---
# Updating a User's Email Address or User ID

Sometimes you'll need to change the email address or user ID for a
user—perhaps they were previously anonymous and now they have converted to a
known contact, their `email` has changed, or you are updating your project's
`userId` fields to standardize, correct, or otherwise update this value.

This article describes how to change these fields using Iterable's API.

> [!WARNING]
> After updating a user profile (for example, by calling [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)),
> wait 60 seconds before making other API calls related to the same user.
>
> For GDPR forget requests ([`POST /api/users/forget`](https://support.iterable.com/hc/articles/204780579#post-api-users-forget)),
> provide ten minutes to process.
>
> These delays can help prevent you from accidentally sending a campaign to the
> wrong email address, and other similar problems.

## Email-based Projects

### Updating email address in an email-based project

Email-based projects identify users by `email`. To update a user's email 
address, call [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail),
with a request body such as:

```json
{
   "currentEmail": "current@example.com",
   "newEmail": "new@example.com"
}
```

In the request body, specify `currentEmail` or `currentUserId`, but not both.
If you provide both, `currentEmail` takes precedence.

### Updating user ID in an email-based project

To add or update the `userId` field for a user in an email-based project, you
can call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update). 

In the request body:

- For `email`, specify the existing user's email address.
- In `dataFields`, provide a `userId`.

For example:

```json
{
   "email": "existingUser@example.com",
   "dataFields": {
     "userId": "newUserId"
   }
}
```

For this request:

- Iterable checks to see whether your project already has a user with `email`
  set to `existingUser@example.com`. It not, the user is created.
- Whether the user is new or already exists, Iterable assigns a `userId` of
  `newUserId` to the user.

To add or update a user's `userId` in an email-based project, call
[`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update),
with the new `userId` value inside of `dataFields`.

> [!WARNING]
> **Email-based projects do not enforce `userId` uniqueness.**
>
> This means you won't receive an error if you update a user to have a non-unique
> `userId` value, and a duplicate `userId` will exist in your Iterable project.
> This may cause problems when making API calls based on `userId`.
>
> If you need unique `userId` values, consider creating a userID-based project or 
> a hybrid project. To learn more, read [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

## UserID-based projects and hybrid projects

### Updating email address in a userID-based project or hybrid project

To update an existing user's `email` in a userID-based or hybrid project, call 
[`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update),
with a request body such as:

```json
{
  "userId": "someUserId",
  "dataFields": {
     "email": "newEmail@example.com"
   }
 }
```

### Updating user ID in a userID-based project or hybrid project

To update an existing user's `userId` in a userID-based or hybrid project, 
call [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update),
with a request body such as:

```json
{
  "userId": "oldUserId",
  "dataFields": {
     "userId": "newUserId"
   }
 }
```

## Common Errors

There may be errors encountered when you are attempting to update a unique
identifier for a user. This happens because values are uniquely enforced and
conflicts can result in errors.

### Unique `email` projects

Both email-based projects and hybrid projects enforce a unique value for the
`email` field. 

When updating the `email` field, watch out for these common errors:

- When `currentEmail` does not exist: 

  ```json
  {
     "msg": "Cannot change user Some(oldEmail@example.com) to newEmail@example.com. User does not exist",
     "code": "BadParams",
     "params": null
  }
  ```

- When `newEmail` already exists:

  ```json
  {
     "msg": "Cannot change user Some(oldEmail@example.com) to newEmail@example.com. New email already exists",
     "code": "EmailAlreadyExists",
     "params": null
  }
  ```

- When `newEmail` has been GDPR forgotten:

  ```json
  {
     "msg": "Cannot change user oldEmail@example.com to newEmail@example.com. New email is on the forgotten list",
     "code": "EmailAlreadyExists",
     "params": null
  }
  ```

### Unique `userId` projects

UserID-based projects and hybrid projects enforce unique `userId` values. Here
are some things you may sees when updating a `userId` value:

- When the user you're trying to update doesn't actually exist, you'll receive
  a `200` response, and Iterable creates the user with the new `userId`.

- When the updated `userId` is already taken by another user:

  ```json
  {
     "msg": "userId already exists: newUserId",
     "code": "ExternalKeyConflict",
     "params": null
  }
  ```

- When the original `userId` has been GDPR forgotten:

```json
{
    "msg": "User with userId originalUserID is forgotten",
    "code": "ForgottenUserError",
    "params": null
}
```
