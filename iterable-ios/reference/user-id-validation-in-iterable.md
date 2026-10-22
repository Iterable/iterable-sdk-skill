---
slug: user-id-validation-in-iterable
feature: user-profiles
archetype: identity
sdk_min_version: 6.7.5
sdk_artifact: IterableSDK
title: User ID Validation in Iterable
source_url: https://support.iterable.com/hc/articles/41111923969556
source_repo: Iterable/iterable-docs
source_path: docs/audience-management/users-and-user-profiles/user-id-validation-in-iterable/index.md
source_ref: 9875968f907df280d7023b1f8f45ba0293940498
source_sha: d2af79dc054d08c4d6149b66d9879935056b6856
fetched_at: 2026-10-22T10:00:06.988Z
summary: "Whenever you create or update a user in Iterable, you can provide a
  `userId` value. When you do this, Iterable performs the following validations
  on the `userId` field:"
---
# User ID Validation in Iterable

Whenever you create or update a user in Iterable, you can provide a `userId` 
value. When you do this, Iterable performs the following validations on the 
`userId` field:

- **Maximum length** of 128 characters.

- **Must not contain non-printable ASCII characters**, such as
  [non-breaking spaces](https://www.ascii-code.com/character/nbsp) and 
  [soft hyphens](https://www.ascii-code.com/character/shy).
  
  Non-printable characters are typically created programmatically and aren't 
  visible printed characters. Not to be confused with space, tab, or other 
  whitespace characters, or with [hard hyphen](https://www.ascii-code.com/character/-)
  (also called a minus sign).

- **Must not end with a space**.

- Values are **case-sensitive**.

- Iterable doesn't generate values for this field. You must include the value
  when creating users.

- Values should **not contain PII**, such as an email or phone number.

- **Uniqueness** is:
  - Enforced in userID-based and hybrid projects.
  - _Not_ enforced in email-based projects. In the event the same `userId` is 
    associated with multiple users, there are some important considerations. To 
    learn more, read [Identifying users by `userId` in email-based projects](https://support.iterable.com/hc/articles/29156459027348#email-based-projects).

## Providing a `userId` value

Iterable does not generate values for the `userId` field. You must include 
the value when creating users.

> [!NOTE]
> The only exception is when you are using Unknown User Activation, in which case
> Iterable generates a `userId` value for you. To learn more, read [Unknown User
> Activation Overview](https://support.iterable.com/hc/articles/38755339847188).

### User ID best practices

Ideally, user ID values are static (unchanging), not guessable, and meaningless
outside of the context where it is used.

Here are some good options for `userId` field values:

- The same ID field you use to identify a user in your application—assuming
  it meets these best practices.

- The same ID field as another, primary system of record (such as your CRM, or 
  another integration that you rely on to store your user's data).

- Randomly generated universally unique identifiers (UUIDs). [Learn more](https://en.wikipedia.org/wiki/Universally_unique_identifier).

- Other database-generated unique IDs.

Practices to avoid:

- Anything that is considered personally identifiable information (or PII), such
  as:
  
  - Names
  - Email addresses
  - Phone numbers
  - Dates of birth

- Any values that may be guessable, such as:

  - Formulas based on PII information
  - Sequential values (10001, 10002, 10003 ... _n+1_)
  - Usernames or "handles"

> [!WARNING]
>
> **You can edit values in the `userId` field.** 
>
> Values stored in the `userId` field are not permanent in Iterable. They can be
> overwritten or changed. Learn more at [Updating a User's Email Address or User ID](https://support.iterable.com/hc/articles/217502386).
