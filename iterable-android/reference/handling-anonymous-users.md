---
slug: handling-anonymous-users
feature: user-profiles
archetype: identity
sdk_min_version: 3.7.0
sdk_artifact: iterableapi
title: Handling Anonymous Users via API
source_url: https://support.iterable.com/hc/articles/208499956
source_repo: Iterable/iterable-docs
source_path: docs/developer-and-api-docs/api/handling-anonymous-users/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: dce1b5d51ff199a29e8eae86e4a9b84f3cfde148
fetched_at: 2026-10-22T09:59:43.888Z
summary: There are many scenarios where you will have users that you need to
  track and connect with, but don't have their email address. This happens when
  you have mobile apps that don't require an email, SMS-first marketing, and
  more.
---
# Handling Anonymous Users via API

> [!NOTE]
> This article explains how to work with anonymous users using Iterable's APIs.
> This is a manual approach — you manage placeholder IDs and profile merging
> yourself through the API, without requiring Iterable's iOS, Android, or Web SDKs.
>
> If your apps or website use Iterable's iOS, Android, or Web SDKs, consider
> [Unknown User Activation](https://support.iterable.com/hc/articles/38755339847188)
> instead. Unknown User Activation automates profile creation, local data
> replay, and profile merging. Marketers can define profile creation criteria
> in the Iterable UI without redeploying your app or website.

There are many scenarios where you will have users that you need to track and
connect with, but don't have their email address. This happens when you have
mobile apps that don't require an email, SMS-first marketing, and more.

You might need to track anonymously in the following scenarios:

- You don't have a user's email address but want to track their event history
  and save profile data in Iterable.
- You have the user's device token and want to send them a push notification,
  but don't yet have their email address.
- You have the user's phone number and want to send them SMS, but don't yet
  have their email address.

Iterable provides two different unique identifier fields, `email` and `userId`,
and these fields apply to projects depending on the project type:

- **Hybrid project** - uses both `email` and `userId` fields as unique 
  identifiers.
- **UserID-based project** - uses just the `userId` field as a unique 
  identifier. 
- **Email-based project** - uses `email` as a unique identifier. 
  (Limited availability: Only certain accounts have the option to create _new_ 
  email-based projects - [learn more](https://support.iterable.com/hc/articles/9216719179796#project-type-availability).)

To work with anonymous users in userID-based projects and hybrid projects, you will
simply use the `userId` field instead of the `email` field to identify users. 

If you are working in an email-based project, however, then all user profiles require a
value for the `email` field. When you don't know the email address of a new user,
but need to create a profile in Iterable, you will need to create a placeholder
email address.

> [!NOTE]
> If you aren't sure which unique identifier your project uses, or to learn more
> about each project type and how they work, read [Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

## Placeholder emails for email-based projects

A placeholder email contains a unique string followed by `@placeholder.email`.

Example: `some-user+10593364321@placeholder.email`

### Placeholder email format

An auto-generated placeholder email is generated with the following formula:
`userId` + `+` + Java hash + `@placeholder.email`.

When the `userId` value is longer than 52 characters, Iterable creates the
placeholder email as: SHA1 hash + `@placeholder.email`.

For example: `4146832971d799352598ff1b5712c0b999f615d5@placeholder.email`

### Sending campaigns to users with placeholder emails

A placeholder email is _not_ a valid recipient address. Email campaigns to
placeholder addresses are not attempted, and send skip events aren't logged
for these addresses.

However, if the user's profile has other sending identifiers — such as a device
token for push notifications, or a phone number for SMS — you can still send
messages to them on those channels.

## Creating a placeholder email

You can manually assign a placeholder email to a user, or have Iterable automatically
generate one for you when creating the user.

### Manually creating a placeholder email

Placeholder email addresses in Iterable must end with `@placeholder.email`.
You can create placeholder emails by using the [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
API endpoint.

For example, if adding users through the API:

```json
{
    "email": "example@placeholder.email",
    "dataFields": {
        "firstName": "Data",
        "catName": "Spot"
    }
}
```

### Automatically assigning a placeholder email

_Email-based projects only_

Instead of manually assigning a placeholder value for the `email` field, you
can also ask Iterable to generate one for you when creating the user. This is
only available if you are working in an email-based project. Iterable doesn't
create placeholder emails for userID-based and hybrid projects.

To create a user with a placeholder email, use [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
with the following parameters in the request body:

- `userId`: The user's ID
- `preferUserId`: `true`

For example:

```json
{
    "userId": "some-user-id",
    "preferUserId": true,
    "dataFields": {
        "firstName": "Mary",
        "lastName": "Lee"
    }
}
```

This creates a user with `some-user-id+10593364321@placeholder.email`
as the assigned placeholder `email`:

```json
{
    "user": {
        "email": "some-user-id+10593364321@placeholder.email",
        "userId": "some-user-id",
        "dataFields": {
          "firstName": "Mary",
          "lastName": "Lee",
            "email": "some-user-id+10593364321@placeholder.email",
            "signupDate": "2022-10-27 22:12:43 +00:00",
            "profileUpdatedAt": "2022-10-27 22:12:39 +00:00",
            "signupSource": "API",
            "userId": "some-user-id",
            "itblInternal": {
                "documentCreatedAt": "2022-10-27 22:12:43 +00:00",
                "emailDomain": "placeholder.email",
                "documentUpdatedAt": "2022-10-27 22:12:43 +00:00"
            }
        }
    }
}
```

## Updating a placeholder email to the user's true email

When your user has converted from anonymous to known and they have provided
their true email address, make a call to Iterable's
[`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
endpoint.

For example, to update an `example@placeholder.email` email to `user@example.com`, 
the payload would look like this:

```json
{  
    "currentEmail": "example@placeholder.email",  
    "newEmail": "user@example.com"  
}
```

This call must be made in order for the historical data and profile fields to be
transferred to the new email address for the user in Iterable.

> [!NOTE]
> - You cannot use the [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)  
>   endpoint if the `newEmail` value already exists in Iterable. If `newEmail` is an 
>   existing user profile, see [below](#best-practices-for-handling-anonymous-users) 
>   for information about how to handle this.
> - Updating email addresses can only be done through Iterable's API. It cannot be
>   done through Segment.

## Best practices for handling anonymous users 

When you receive or have determined the user's actual email address, use the
[`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail) 
API endpoint to update the existing user's email address.

- The [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail)
  API endpoint transfers historical data and profile fields from the placeholder 
  email to the new email address.

- The [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
  API endpoint creates a completely separate user profile.

  Once a completely separate user profile has been created for the user's actual 
  email address, you can't use the [`POST /api/users/updateEmail`](https://support.iterable.com/hc/articles/204780579#post-api-users-updateemail) 
  API endpoint to update the placeholder email address to the user's actual email 
  address.

If a completely separate user profile has been created and you wish to merge the
historical data and profile fields from a placeholder email address to the
user's actual email address, you will need to complete the following:

- For user profile fields:

  - Use the [`GET /api/users/{email}`](https://support.iterable.com/hc/articles/204780579#get-api-users-email)
    API endpoint to retrieve the user profile fields associate with the placeholder
    email address.

  - Use the [`POST /api/users/update`](https://support.iterable.com/hc/articles/204780579#post-api-users-update)
    API endpoint to set the placeholder email address's properties (fetched
    above) on the actual email address's profile.
    
    :::tip WARNING
    This approach will overwrite the user profile fields for the user's actual
    email address with the user profile fields from the placeholder email
    address.
    :::

- For custom events:

  - Use the [`GET /api/events/{email}`](https://support.iterable.com/hc/articles/204780579#get-api-events-email)
    API endpoint to retrieve the placeholder email address's custom events.

  - To record the events of the placeholder email address onto the user's
    actual address profile, use the [`POST /api/events/trackBulk`](https://support.iterable.com/hc/articles/204780579#post-api-events-trackbulk) 
    to create the custom events.

  - Make sure you edit the `createdAt` field in the API call to backfill
    the events.

  :::tip NOTES 
  - If the `createdAt` field is left blank, Iterable will automatically 
    assign the current date and timestamp to that field .
  - Backfilling events will trigger any journeys that are triggered
    by those custom events. 
  - Consider adding a filter tile after the Start tile that will allow
    users with backfilled events to exit the journey. This can be done
    through the creation date of the custom event or by including a data
    field in the event itself that notes that it is a backfilled event. 
  :::

- Call [`POST /api/users/registerDeviceToken`](https://support.iterable.com/hc/articles/204780579#post-api-users-registerdevicetoken) 
  when a user signs in to the app and [`POST /api/users/disableDevice`](https://support.iterable.com/hc/articles/204780579#post-api-users-disabledevice) 
  when they sign out. This prevents duplicate sends to a device shared amongst 
  multiple people.
