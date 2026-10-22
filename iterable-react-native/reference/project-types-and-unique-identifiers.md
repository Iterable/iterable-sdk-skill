---
slug: project-types-and-unique-identifiers
feature: user-profiles
archetype: prerequisite
sdk_min_version: 3.2.1
sdk_artifact: "@iterable/react-native-sdk"
title: Project Types and Unique Identifiers
source_url: https://support.iterable.com/hc/articles/9216719179796
source_repo: Iterable/iterable-docs
source_path: docs/setup-and-administration/projects/project-types-and-unique-identifiers/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: a37d7e60a1978d0dceb462a9b64214f6fec36935
fetched_at: 2026-10-22T10:00:26.559Z
summary: Every Iterable project uses a specific field (`email` and/or `userId`)
  to uniquely identify each user. This allows an individual record to be
  referenced without confusion. This selection has a lasting impact on how your
  project works and how you access data via API.
---
# Project Types and Unique Identifiers

Every Iterable project uses a specific field (`email` and/or `userId`) to
uniquely identify each user. This allows an individual record to be referenced
without confusion. This selection has a lasting impact on how your project works
and how you access data via API. 

Continue reading to learn more about the different project types and unique
identifiers, as well as how to determine the best setting for your project.

> [!NOTE]
> Currently, there's no way to change the unique identifier for an existing 
> project. You can only make this selection when creating a project.

## Project types

In Iterable, you define a _project type_ by specifying which field to use
to identify users.

Iterable supports these project types:

- **Hybrid projects**: Use both `email` and `userId` as unique identifiers.
- **UserID-based projects**: Use `userId` as a unique identifier.
- **Email-based projects** (_Limited availability_): Use `email` as a unique 
  identifier.
  - Only certain accounts have the option to create new email-based projects—[learn more](#project-type-availability).

### Comparing project types

Let's compare how different project types handle your data when creating and 
identifying users.

| |**Hybrid projects**|**UserID-based projects**|**Email-based projects** (_Limited availability_)|
|---|---|---|---|
|**Unique identifier** |`email` and `userId`<br/> (at least one of these fields is required)|`userId`|`email`|
|**Enforce `email` uniqueness?**|Yes|No|Yes|
|**Enforce `userId` uniqueness?**|Yes|Yes|No|
|**[How to identify users in API requests](https://support.iterable.com/hc/articles/29156459027348)**|`email` or `userId`|`userId`|`email` or `userId`|
|**Contact lookup by...**|`email` or `userId`|`userId`|`email`|
|**Static subscription list field**|`userListIds`|`userListIds`|`emailListIds`|
|**"Placeholder" email addresses assigned to anonymous users**|No|No|Yes|
|**[Signup form](https://support.iterable.com/hc/articles/207914276) support**|Yes|No|Yes|
|**GDPR forget by...**|`email` or `userId`|`userId`|`email`|
|**[EDC](https://support.iterable.com/hc/articles/17572750887444) support**|Yes|Yes|No|
|**Available for new accounts?**|Yes|Yes|[No](#project-type-availability)|

### Choosing a project type

Because the unique identifier project setting has implications across your data
platforms and you can’t change it later, consult with your development teams and
other interested stakeholders (such as CRM administrators) _before_ creating
your project in Iterable.

Consider these points when choosing a project type:

- **UserID-based projects may be best when you need to...**
  - Track anonymous users (see [Handling Anonymous Users](https://support.iterable.com/hc/articles/208499956)).
  - Support multiple users with the same email address, or single users with 
    multiple accounts.
  - Avoid using email as a parameter in your API requests.

- **Hybrid projects allow you to...**
  - Maintain email uniqueness (one email per user) and keep track of anonymous 
    users.
  - Use `userId` as a primary identifier while ensuring that every user's email 
    address is unique.

> [!NOTE]
>
> **Limitations:**
>
> - Email-based projects have [limited availability](#project-type-availability).
>
> - Iterable doesn't support multiple email addresses or phone numbers for a 
>   single user.
>
> - Iterable does not generate values for the `userId` field. You must include 
>   the value when creating users. To learn more, see [UserID Validation in Iterable](https://support.iterable.com/hc/articles/41111923969556).
>   
>   The only exception where Iterable generates a `userId` value is when using
>   Unknown User Activation. To learn more, read [Unknown User Activation
>   Overview](https://support.iterable.com/hc/articles/38755339847188).

#### Project type availability

Originally, all Iterable projects identified users by email address. However,
for greater flexibility and to encourage best practices in data management
and privacy, Iterable introduced userID-based and hybrid projects. These 
projects can identify users by `userId` and/or `email`, depending on your data 
needs.

All Iterable accounts can create userID-based and hybrid projects. However, 
email-based projects can only be created by Iterable accounts that meet _all_ 
of the following criteria:

- Organizations that are hosted in Iterable's USDC-based data center.
- Organizations that were created before May 28, 2024.
- Organizations that have created an email-based project since May 28, 2023.

If your Iterable account doesn't meet these criteria, and you need to identify 
users by `email`, create a hybrid project.

## Unique identifiers

Each user in an Iterable project must have a unique identifier, which depends 
on the project type:

- `email`, in email-based projects
- `userId`, in userID-based projects
- Either field, in hybrid projects

To learn about the `email` and `userId` fields and their data requirements, see 
[User Profile Fields Used by Iterable](https://support.iterable.com/hc/articles/217744303).

To learn about how each field is handled across Iterable in the API, see
[Creating and Identifying Users with Iterable APIs](https://support.iterable.com/hc/articles/29156459027348).

### Checking the unique identifier for a project

To check the unique identifier(s) for your project, you can:

- Go to **Settings > Project Settings** and see the project type under the 
  **Unique Identifier** setting.

- Go to **Audience > Contact Lookup** and see which fields you can search for.
  You can only find users by unique identifiers here.

> [!NOTE]
> Currently, there's no way to change the unique identifier for an existing
> project. You can only make this choice when creating a project.