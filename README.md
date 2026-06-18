# iterable-sdk-skill

A skill that turns your AI coding assistant (Cursor, Claude Code) into a
reliable guide for integrating the **Iterable Android SDK**. It's derived from
Iterable's official documentation, so the code your assistant writes matches how
the SDK actually works — not the model's stale guess at it.

It also adds the one thing the docs don't have: hand-written **pitfalls** for the
silent-failure traps that quietly break integrations (JWT keys with no auth
handler, missing `POST_NOTIFICATIONS` on Android 13+, `setEmail` inside the init
callback, and more).

## Install

**Claude Code** — install the plugin from this repo's marketplace:

```
/plugin marketplace add Iterable/iterable-sdk-skill
/plugin install iterable-sdk@iterable
```

This installs the skill and wires up its documentation source in one step.

**Cursor (or a manual install)** — symlink the skill directory into your
assistant's skills folder:

```bash
git clone --depth 1 git@github.com:Iterable/iterable-sdk-skill.git ~/iterable-skills
ln -s ~/iterable-skills/iterable-android ~/.cursor/skills/iterable-android
```

Either way, the skill activates automatically whenever you mention Iterable: it
loads its always-on rules and `PITFALLS.md`, then pulls the documentation for
whatever feature you're working on (see [How it works](#how-it-works)).

## How it works

The skill carries a copy of the Iterable documentation inside it
(`iterable-android/snapshot/`), so it always has the docs on hand — even offline.
This snapshot is the active source today.

The Claude Code plugin also connects to [Context7](https://context7.com), a
service that hosts docs for AI assistants to query on demand. That connection is
bundled and ready, but stays dormant until Iterable's curated library is
published there; once it is, the skill fetches the latest docs live, with the
snapshot as its fallback. No reinstall needed when that happens.

> Context7 works without an API key at a lower rate limit. To raise it, get a
> free key at [context7.com](https://context7.com) and add it as a
> `CONTEXT7_API_KEY` header on the `context7` MCP server.

## What it covers

Push notifications, in-app messages, mobile inbox, embedded messaging, deep
linking, JWT authentication, event tracking, user profiles, and unknown-user
activation. Snippets are Kotlin-first and version-pinned to the SDK release each
was validated against.

See [`iterable-android/SKILL.md`](iterable-android/SKILL.md) for the full
routing table.

## Repo layout

```
iterable-android/   the installable skill (SKILL.md + PITFALLS.md + snapshot/)
polished/           the docs in agent-ready form (what gets published to Context7)
pipeline/           tooling that builds polished/ from sources/, CI-gated
sources/            raw Iterable docs, fetched at pinned commits
context7.json       Context7 manifest
```

## Staying current

When Iterable's docs change, a workflow rebuilds the skill's content and opens a
PR for a reviewer to check and merge — updates are never applied automatically.
See [`REVIEW.md`](REVIEW.md).

## Limitations

- **Android only.** iOS, React Native, and Web are not yet covered.
- **Some docs carry foreign snippets.** A few articles come from shared "Mobile
  SDKs" pages and still contain iOS/JS code an Android agent must ignore.
- **Context7 fetch is not live yet.** The skill works today from its bundled
  snapshot; on-demand Context7 fetching turns on in an upcoming release.
