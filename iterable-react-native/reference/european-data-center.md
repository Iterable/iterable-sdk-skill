---
slug: european-data-center
feature: integration
archetype: prerequisite
sdk_min_version: 3.2.1
sdk_artifact: "@iterable/react-native-sdk"
title: Iterable's European Data Center (EDC)
source_url: https://support.iterable.com/hc/articles/17572750887444
source_repo: Iterable/iterable-docs
source_path: docs/welcome-to-iterable/about-iterable/iterables-european-data-center-edc/index.md
source_ref: 275e9063f5aa922a9c282d6d34a8aebec3d15448
source_sha: f144b8c50c37374866060543ae8bcea9cfbf7099
fetched_at: 2026-10-22T10:00:27.099Z
summary: New Iterable customers can choose to host their Iterable projects and
  data (personal and non-personal) on Iterable's European data center (EDC),
  which is in Ireland.
---
# Iterable's European Data Center (EDC)

New Iterable customers can choose to host their Iterable projects and data
(personal and non-personal) on Iterable's European data center (EDC), which is
in Ireland. 

Iterable's EDC is GDPR-compliant, does not send data to the US, handles data
storage and data processing, and offers feature parity with Iterable's USDC-based
offering.

> [!NOTE]
> Whether your project is USDC-based or EDC-based depends on the terms of your 
> Iterable contract and may not correspond to your company's physical location. 
> For example, if your company is located in Spain (an EU country), but your 
> Iterable account is hosted on Iterable's US data center, you have a USDC-based
> project. This means you should sign in to Iterable using the URL for USDC-based 
> Iterable projects ([https://app.iterable.com](https://app.iterable.com)) and use the 
> link tracking domain for USDC-based projects `links.iterable.com`).
>
> Most Iterable customers use Iterable's US data center. If you're not sure which 
> data center your account is hosted on, check with your Iterable customer success 
> manager.

## Organizations and projects

In Iterable, a single organization can have multiple projects, each with
separate data. All of an organization's projects must be hosted on the same data
center — all in the US, or all in the EU.

## UserID-based and hybrid projects only

Iterable's EDC supports userID-based and hybrid projects, but not email-based
projects.

For more information about the types of projects Iterable provides, read
[Project Types and Unique Identifiers](https://support.iterable.com/hc/articles/9216719179796).

## Signing in to Iterable: region-specific URLs

To sign in to Iterable:

- For USDC-based projects, visit <https://app.iterable.com>.
- For EDC-based projects, visit <https://app.eu.iterable.com>.

## SAML SSO: region-specific URLs

USDC- and EDC-based projects use different single sign-on / ACS / reply URLs:

- USDC-based projects: `https://auth.iterable.com/login/callback?connection=-saml-org-<YOUR_ORG_ID>`
- EDC-based projects: `https://auth.eu.iterable.com/login/callback?connection=-saml-org-<YOUR_ORG_ID>`

For more information, read [Setting Up Single Sign-On](https://support.iterable.com/hc/articles/12227358446868).

## Default link tracking domains: region-specific URLs

USDC- and EDC-based projects use different default link tracking domains:

- USDC-based projects: `links.iterable.com`
- EDC-based projects: `links.eu.iterable.com`

When setting up tracking links, be sure to use the correct domain for your 
project type. (Keep in mind that "US/EDC-based" refers to where your project's 
data is stored and may not correspond to your company's physical location).

For more information, read [Setting up Link Tracking Domains to use HTTPS](https://support.iterable.com/hc/articles/115000427446).

## IP addresses for Iterable's EDC

Iterable's EDC uses different IP addresses than Iterable's US data center. If
you need to allow Iterable's IP addresses in your firewall, see 
[Allowing Iterable IP Addresses](https://support.iterable.com/hc/articles/45758621331732).

## SMS providers for EDC-based Iterable projects

To send SMS from EDC-based Iterable projects, you can use:

- Iterable SMS.
- Your own Telnyx account.

For EDC-based Iterable projects, Twilio is not supported.

For more information about SMS, read [SMS Overview](https://support.iterable.com/hc/articles/211970843).

## Email providers for EDC-based Iterable projects

To send email from an EDC-based Iterable project, you can use:

- Iterable's default integration with Amazon SES.
- An Iterable-managed integration with Mailgun, or your own Mailgun account.
- An Iterable-managed integration with Sparkpost, or your own Sparkpost account.

For EDC-based Iterable projects, Sendgrid is not supported.

To learn more about setting up email in Iterable, read [Email Setup](https://support.iterable.com/hc/articles/7130133854612).

## Smart Ingest

Iterable's [Smart Ingest](https://support.iterable.com/hc/articles/24354008224916)
feature supports EDC-based projects. Smart Ingest allows you to import data from 
a supported data source into Iterable. During the setup process, your data 
source administrator must allow the IP addresses used by Smart Ingest to 
connect to your data warehouse.

These IPs vary by region, so make sure that you're allowing the correct set of 
IPs for a successful connection. To learn more, read [Smart Ingest IPs to allow](https://support.iterable.com/hc/articles/25899748801172#smart-ingest-ips-to-allow).

## API keys

Every Iterable API key is associated with a specific Iterable project, which
means that it's also associated with a specific data center:

- API keys created in a USDC-based project can only be used with Iterable's USDC-based 
  API endpoints (base URL: `https://api.iterable.com`).
- API keys created in EDC-based project can only be used with Iterable's EDC-based 
  API endpoints (base URL: `https://api.eu.iterable.com`).

For more information about API keys, read [API Keys](https://support.iterable.com/hc/articles/360043464871).

## API documentation

You can make API calls directly from Iterable's API docs: enter an API key,
choose an endpoint, specify request parameters / a request body, and submit the
request.

Iterable provides two sets of API documentation:

- API docs for USDC endpoints - <https://api.iterable.com/api/docs>. 

  Requests submitted on this page are sent to Iterable's USDC-based API endpoints 
  (base URL: `https://api.iterable.com`). On this page, you can only use API keys 
  associated with USDC-based Iterable projects.

- API docs for EDC endpoints - <https://api.eu.iterable.com/api/docs>. 

  Requests submitted on this page are sent to Iterable's EDC-based API endpoints 
  (base URL: `https://api.eu.iterable.com`). On this page, you can only use API 
  keys associated with EDC-based Iterable projects.

Our [Getting Started with Iterable's API](https://support.iterable.com/hc/articles/41044692130196) provides 
information about each endpoint, too.

## SDK support

Iterable's mobile and web SDKs support Iterable's EDC:

- iOS SDK, [version 6.4.15+](https://github.com/Iterable/iterable-swift-sdk/releases/tag/6.4.15).
  To learn more, see [Iterable's iOS SDK](https://support.iterable.com/hc/articles/360035018152).

- Android SDK, [version 3.4.15+](https://github.com/Iterable/iterable-android-sdk/releases/tag/3.4.15)
  To learn more, see [Iterable's Android SDK](https://support.iterable.com/hc/articles/360035019712).

- React Native SDK, [version 1.3.16+](https://github.com/Iterable/react-native-sdk/releases/tag/1.3.16)
  To learn more, see [Installing Iterable's React Native SDK](https://support.iterable.com/hc/articles/360045714132).

- Web SDK, [version 1.0.5+](https://github.com/Iterable/iterable-web-sdk/releases/tag/v1.0.5)
  To learn more, see [Setting Up Iterable's Web SDK](https://support.iterable.com/hc/articles/4419628585364).