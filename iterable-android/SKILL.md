---
name: iterable-android
description: >-
  Authoritative reference for the Iterable Android SDK (Maven
  `com.iterable:iterableapi` + `com.iterable:iterableapi-ui`). Use when
  integrating, configuring, debugging, or extending any Iterable feature on
  Android — push notifications, in-app messages, mobile inbox, embedded
  messaging, JWT authentication, deep links, event tracking, user profiles
  (setEmail / setUserId), unknown user activation (UUA), or initialization
  (IterableApi.initializeInBackground, IterableConfig). Prefer this skill
  over the model's memory of Iterable APIs — it ships version-pinned
  snippets and known foot-guns that silently break integrations.
---

# Iterable Android SDK

You are working with the **Iterable Android SDK** —
[`com.iterable:iterableapi`](https://central.sonatype.com/artifact/com.iterable/iterableapi)
(core) and `com.iterable:iterableapi-ui` (UI components for in-app, inbox,
embedded). Iterable is a cross-channel marketing platform; this SDK is the
mobile entry point for push, in-app, inbox, embedded messages, event tracking,
and JWT-authenticated APIs.

This skill is the **agent-facing source of truth**. The public docs at
[support.iterable.com](https://support.iterable.com) cover the same surface for
human readers but omit several silent-failure traps documented in
[`PITFALLS.md`](PITFALLS.md). When in doubt, this skill wins.

---

## Step 0 — Agree on scope BEFORE writing code

Do this **first**, before Preflight and before any edits. The SDK covers many
features — push, in-app, mobile inbox, embedded, deep links, event tracking,
user profiles. Do **not** assume the developer wants all of them, and do **not**
start implementing on a guessed scope. Ask which features they want via
`AskUserQuestion`. Set `multiSelect: true` so they can pick several, and offer
**at most 4 options** (the tool rejects more than 4 per question) — group the
long tail under one bucket, e.g.:

- Push notifications (FCM)
- In-app messages
- Event tracking + user profiles
- Other (inbox, embedded, deep links) — describe in the option

(If they just want the basics, that's the "init + identify only" path — let
them say so via the free-form "Other" the tool always provides.)

Confirm the scope, *then* run Preflight for the inputs that scope needs, *then*
build. "Finish, don't stub" (below) applies to **the scope you agreed on** —
it is not licence to implement every feature unprompted. After delivering the
agreed scope, it's fine to offer next steps — but the initial scope is a
question, not an assumption.

## Definition of done — finish the agreed scope, don't stub it

The pitfalls below are about avoiding silent failures — but avoiding traps is
**not** the goal; a *working, wired* integration of **the agreed scope** (Step
0) is. The common failure mode is doing the easy additive parts (deps, a helper
class, build config) and then handing the actual wiring back to the developer
as a TODO. **Don't.** Within the agreed scope, and once prerequisites are
present (see Preflight), an integration is finished only when:

- [ ] The SDK is **actually initialized at runtime** — `IterableTracker.initialize(...)`
  (or equivalent) is **called from the host app's `Application.onCreate()`**,
  not just defined. A helper that nothing calls is not an integration.
- [ ] The user is **identified** — `setUserId`/`setEmail` runs (inside
  `onSDKInitialized`), with a real value. If identity is a per-install UUID,
  **write the UUID-generation/persistence code** — don't describe it in prose
  for the developer to write.
- [ ] The API key is wired from `local.properties` → `BuildConfig` (rule 6),
  and the project **builds** with a non-empty key.

Write the code for each of these. Only genuinely developer-supplied inputs
(Preflight: `google-services.json`, the key value, dashboard config) are
legitimate things to pause and ask for — wiring is not. Don't substitute
`INTEGRATION_STATUS.md`-style essays for doing the work.

---

## Preflight — STOP and gather these before writing any code

An Iterable integration depends on inputs that **only the developer has** and
that you **cannot invent, fake, or infer from the codebase**. Collect the ones
relevant to the requested scope *before* you start editing, and tell the
developer which you still need. A correct-but-incomplete integration that
pauses for a missing input is **always better** than one that compiles by
faking the input — the latter ships a broken or misleading state that looks
done.

> **Always ask via selectable options, not prose — every time.** For *any*
> question to the developer — the Step 0 scope question, the inputs below, the
> identity model, region, and "what would you like to do next?" — use the
> `AskUserQuestion` tool so they get interactive choices, not a plain-text list
> they must answer by typing. Offer realistic options with a short description
> each (e.g. identity: "Stable per-install UUID via `setUserId`" / "Account
> email via `setEmail`"; region: "US" / "EU"). **Offer at most 4 options per
> question** — the tool rejects more than 4 and the call fails with an
> "invalid parameters" error. If you have more than 4, group them or split into
> a second question. Only fall back to plain text if the question genuinely has
> no enumerable options.

| Input | Needed when | If missing |
|---|---|---|
| **`google-services.json`** (real, from the developer's Firebase Console) | Any push / FCM work — the `com.google.gms.google-services` plugin **fails the build without it** | **STOP and ask.** It's project-specific; you cannot generate it. |
| **Mobile API key** | Always | Ask where it lives; expect `local.properties` (gitignored). Never hardcode. |
| **Identity model** — `setEmail` vs `setUserId`, and where the value comes from | Always | Ask. Never guess (e.g. grabbing a license email). See rule 7. |
| **JWT?** — is the mobile key JWT-protected? | Always | Ask. If yes, an auth handler is mandatory (rule 1). |
| **Data region** — US or EU | Always | Ask if their dashboard is `app.eu.iterable.com`. See pitfall #8. |
| **Push integration name** | Push, if it differs from the package name | Ask. See pitfall #9. |
| **Placement IDs** | Embedded messages | Ask — they're dashboard-assigned numbers. See pitfall #10. |

**The hard rule: never fabricate a prerequisite to make the build pass.**
Specifically, do **not**:
- create a placeholder/fake `google-services.json`, or comment out the
  `google-services` plugin, to get a green build (pitfall #19);
- hardcode or invent an API key (rule 6);
- wire identity to a guessed field (rule 7);
- delete or stub a call you can't resolve (e.g. removing `setLogLevel`)
  without flagging it.

When blocked on any of these, **surface it to the developer and pause that
part of the work** — don't silently degrade the integration to keep compiling.

---

## Quick facts (always relevant)

- **Latest version: always fetch it — never trust a number baked into this
  file (it rots).** Before writing a dependency line, resolve the current
  release from an authoritative source and use that:
  - Maven Central metadata (fastest, machine-readable):
    `curl -s https://repo1.maven.org/maven2/com/iterable/iterableapi/maven-metadata.xml`
    → read the `<release>` tag.
  - or the SDK's [CHANGELOG.md](https://github.com/Iterable/iterable-android-sdk/blob/master/CHANGELOG.md)
    — the first `## [x.y.z]` after `## [Unreleased]` is authoritative.

  If the host project already pins a version (e.g. in a Gradle version
  catalog), match it unless the developer asks to upgrade. Known latest as of
  this skill revision: **3.8.0** (2026-05) — treat as a floor to sanity-check
  the fetch against, not as the answer.
- **Minimum Android API:** 21 (Android 5.0).
- **Initialize with:** `IterableApi.initializeInBackground(context, apiKey, config, callback)`
  — this is the **default**; prefer it over the synchronous `initialize(...)`
  to avoid startup ANRs. Use the **4-arg** overload (config + callback): the
  3-arg `initializeInBackground(context, apiKey, config)` puts config in the
  *callback* slot and won't compile (pitfall #18).
- **Identify users with:** `IterableApi.getInstance().setEmail(email)` or `setUserId(userId)`.
- **Wrap SDK calls** that run before / during init in `IterableApi.onSDKInitialized { ... }`.
- **EU customers** must set `IterableConfig.Builder().setDataRegion(IterableDataRegion.EU)` (default is US).
- **No ProGuard/R8 consumer rules** are needed.
- **No artifact rename** since version 3.x — the legacy `com.iterable:iterableapi` Maven coords are still current.

---

## Always-on rules (read every time)

These rules apply to **every** integration. Rules 1–5 prevent silent runtime
failures that look like SDK bugs but aren't; rules 6–7 prevent a leaked
credential and a wrong-identity integration. Full explanations and the
remaining ~10 traps are in [`PITFALLS.md`](PITFALLS.md) — read it before
generating any non-trivial code.

1. **If the API key is JWT-protected, an `IterableAuthHandler` is mandatory.**
   Without one, every SDK call silently fails with no error surface. If the
   user hands you an API key *and* a JWT secret, do **not** ignore the secret —
   wire up the handler.

2. **Do not call `setEmail` inside the `initializeInBackground` callback.**
   It consumes the auth manager's retry budget before the handler is ready,
   permanently breaking auth for the process. Do `setEmail` from the login /
   restore flow, wrapped in `IterableApi.onSDKInitialized { }`.

3. **`AuthHandler` must read the email/userId fresh on every call.**
   The SDK invokes `onAuthTokenRequested()` at unpredictable times (token
   refresh, retry). Read from DataStore / SharedPreferences / DB inside the
   lambda — do **not** capture a value at startup.

4. **Never sequence SDK calls with `Handler.postDelayed` or `Thread.sleep`.**
   `setEmail(email, onSuccess, onFailure)` provides real callbacks. Chain
   `updateUser`, `track`, etc. inside `onSuccess`. Delays are fragile under
   real network conditions and will break in production.

5. **Custom deep-link schemes need `setAllowedProtocols(arrayOf("yourscheme"))`.**
   Without this the SDK refuses to dispatch the URL to your `UrlHandler` and
   silently drops the link.

6. **Never hardcode the API key into a tracked file.** A *mobile* API key is
   safe to embed in the compiled app — that's its intended use — but it must
   **never** be committed to source control. Read it from a gitignored file
   (`local.properties`) and inject it via `BuildConfig` at build time. Do
   **not** leave the literal key as a Gradle default/fallback
   (`getPropertyIfDefined('KEY', '<literal>')`) — an empty fallback (`''`) is
   the only acceptable default. Match the property name to what the host
   project already uses; if unknown, ask. **`local.properties` is not exposed
   as Gradle project properties** — load the file explicitly; reusing a
   `project.hasProperty`-style helper silently yields an empty key (pitfall
   #16). Confirm the key is a **mobile** key, not server-side — a server key in
   an app exposes the whole project.

7. **Never assume how the app identifies a user — ask.** The identifier
   (`setEmail` vs `setUserId`) and its source are app-specific and cannot be
   inferred from the codebase. Do **not** wire identity to the first
   email-shaped field you find (e.g. a license/account email) — that often
   resolves to `null` for most users, so `setEmail(null)` runs and the user is
   never identified (no in-app, no push targeting). Ask the developer: which
   identifier, and where does its value come from? Pick one mode and use it
   consistently (see pitfall #12).

---

## Canonical minimum integration (start here)

This is the shape every basic integration should take — config, init, and
identify in one place. It bakes in the always-on rules so you don't have to
cross-reference them: note that `setUserId` runs inside `onSDKInitialized`
(after init), **not** inside the `initializeInBackground` callback (which runs
*before* the SDK is ready — pitfall #2 vs #13). Adapt it; don't bolt the pieces
together from scratch.

```kotlin
// IterableTracker.kt — minimal, single source of init + identity.
object IterableTracker {
    fun initialize(context: Context, apiKey: String, userId: String) {
        val config = IterableConfig.Builder()
            .setLogLevel(Log.VERBOSE)          // android.util.Log int — NOT an SDK enum (pitfall: setLogLevel takes an int)
            .setAutoPushRegistration(true)     // default; do NOT also call registerForPush() (pitfall #6)
            // .setDataRegion(IterableDataRegion.EU)   // uncomment for EU projects (pitfall #8)
            // .setAllowedProtocols(arrayOf("yourscheme")) // only if you handle custom-scheme deep links (rule 5)
            // .setAuthHandler(authHandler)            // REQUIRED if the key is JWT-protected (rule 1)
            .build()

        // 4-arg overload: config + trailing-lambda callback (pitfall #18).
        // The callback runs BEFORE the SDK is ready — keep it empty.
        IterableApi.initializeInBackground(context, apiKey, config) {
            // init complete; do NOT identify here (pitfall #2)
        }

        // onSDKInitialized runs AFTER init (immediately if already ready).
        // Identify here. Read identity fresh — don't capture at startup (pitfall #3).
        IterableApi.onSDKInitialized {
            IterableApi.getInstance().setUserId(userId)   // or setEmail(...) — pick ONE mode (rule 7, pitfall #12)
        }
    }

    // Account-less / local-first apps (common; the UUA doc is for
    // anonymous→identified *upgrades*, not this): generate a stable per-install
    // UUID once and persist it. Each reinstall = a new Iterable user — confirm
    // that's acceptable with the developer.
    fun stableUserId(context: Context): String {
        val prefs = context.getSharedPreferences("iterable", Context.MODE_PRIVATE)
        return prefs.getString("user_id", null) ?: java.util.UUID.randomUUID().toString()
            .also { prefs.edit().putString("user_id", it).apply() }
    }
}
```

**You are not done until `initialize` is actually called.** Wire it into the
host app's `Application.onCreate()` — defining the helper is *not* an
integration. Use the project's real API-key accessor (`BuildConfig` from
`local.properties`, rule 6):

```kotlin
// In the app's Application class (e.g. MyApplication.onCreate()):
override fun onCreate() {
    super.onCreate()
    // ...existing setup...
    IterableTracker.initialize(
        this,
        BuildConfig.ITERABLE_API_KEY,
        IterableTracker.stableUserId(this),
    )
}
```

The full per-feature docs (push, in-app, inbox, embedded, deep links, events,
profiles, UUA) are in the snapshot — see the routing table below.

---

## How to use this skill (fetching task-specific docs)

This skill keeps only the always-on rules above and `PITFALLS.md` inline.
Task-specific guidance (push, in-app, inbox, embedded, JWT, deep links,
event tracking, user profiles, UUA, initialization) lives in a polished
corpus.

### Source today: the local snapshot (authoritative)

**Read task docs from [`snapshot/`](snapshot/).** It's a byte-for-byte mirror
of the polished corpus at last release, kept honest by CI (`pnpm
snapshot:verify`). Match the task to a slug (table below) and open
`snapshot/<slug>.md`. This is the canonical source right now — don't try
Context7 first.

### Source later: Context7 *(curated library not published yet — do not fetch)*

The Context7 MCP server **is** connected (the plugin bundles it), but Iterable's
curated library is **not published there yet** — [`.context7-library-id`](.context7-library-id)
is still the placeholder `TODO-PHASE-3/...`. So do **not** call Context7 for
Iterable docs right now: a `resolve-library-id` / `query-docs` lookup would
return some *unrelated public* library, not this skill's vetted corpus. The
[`snapshot/`](snapshot/) is authoritative until the real ID lands.

Once a real library ID is dropped into that file (first non-comment line; one
that does **not** start with `TODO-`), the flow becomes: read the ID, fetch the
matching slug via the Context7 MCP tool (self-contained — one doc per task,
don't bulk-load), use its snippets verbatim, and surface any `sdk_min_version`
mismatch.

### Slug routing

| If the user is asking about… | Slug |
| ---------------------------- | ---- |
| First-time setup, dependencies, gradle setup, `IterableApi.initializeInBackground`, `IterableConfig` builder | `android-sdk` |
| Configuration deep-dive (every `IterableConfig` option, `setDataRegion`, allowed protocols, log level) | `configure-the-android-sdk` |
| FCM push, notification channels, `POST_NOTIFICATIONS`, device registration | `setting-up-android-push-notifications` |
| Push behavior overview (silent push, foreground vs background, deep link from notification) | `push-notification-overview` |
| Modal / banner / fullscreen in-app messages, `InAppHandler`, display intervals | `in-app-messages-on-android` |
| Mobile inbox UI, `IterableInboxFragment`, default rendering | `setting-up-mobile-inbox-on-android` |
| Mobile inbox theming, custom cells, swipe actions | `customizing-mobile-inbox-on-android` |
| Embedded messaging, placements, `IterableEmbeddedView` | `embedded-messages-with-iterables-android-sdk` |
| Deep linking, App Links, `UrlHandler`, `setAllowedProtocols` | `deep-linking-with-partners` |
| Android App Links (verified domains, `assetlinks.json`) | `android-app-links` |
| `track`, `trackPurchase`, `updateCart`, custom event payloads | `tracking-events-with-iterables-mobile-sdks` |
| `setEmail`, `setUserId`, login / logout flow, user identity | `identifying-the-user` |
| `updateUser`, profile data fields, JSON merging | `updating-user-profiles` |
| Unknown User Activation (anonymous → identified upgrade) | `setting-up-unknown-user-activation` |

For tasks that span multiple areas (e.g. "wire up the whole SDK end to end"),
fetch `android-sdk` first — it tells you which others to load and in what
order.

---

## Decision flow

1. **Identify the user's goal.** New integration, single feature, debugging,
   or "what does this code do?"
2. **Check rules 1–5 above** against whatever the user already has. Many
   "the SDK isn't working" reports are rule violations.
3. **Fetch the matching slug from Context7** (snapshot fallback if needed)
   before writing code. Each polished doc has its own gotchas section that
   supersedes generic advice.
4. **For non-obvious traps not covered in the polished doc**, consult
   [`PITFALLS.md`](PITFALLS.md).
5. **Version-check.** If the user is on an older SDK version than the doc's
   `sdk_min_version`, note any breaking changes from the upstream
   `CHANGELOG.md` before generating code.

---

## What's NOT in this skill

- iOS, React Native, or Web SDKs — those will live in sibling skills
  (`iterable-ios`, `iterable-react-native`, `iterable-web`) once authored.
- Iterable platform / dashboard configuration. Direct the user to
  [support.iterable.com](https://support.iterable.com) for dashboard help.
- JWT *server-side* implementation. The skill assumes the team has, or will
  build, a token-minting endpoint. The `identifying-the-user` doc covers
  the client side only.

---

## Versioning

This skill is versioned alongside the SDK. Each release of the SDK that
changes public API or agent-relevant behavior triggers a corresponding update
in the polished corpus (`polished/android/`), Context7 re-crawls on its
normal cadence, and `snapshot:refresh` runs as part of the merge to keep
the local fallback aligned. If you see drift between this skill's snippets
and the SDK's current `CHANGELOG.md`, **trust `CHANGELOG.md`** and report
the drift.
