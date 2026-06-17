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

The skill is a single directory you symlink into your assistant's skills folder.

```bash
git clone --depth 1 git@github.com:Iterable/iterable-sdk-skill.git ~/iterable-skills

# Cursor
ln -s ~/iterable-skills/iterable-android ~/.cursor/skills/iterable-android

# Claude Code
ln -s ~/iterable-skills/iterable-android ~/.claude/skills/iterable-android
```

That's it. The skill activates automatically whenever you mention Iterable: it
loads its always-on rules and `PITFALLS.md`, then pulls the documentation for
whatever feature you're working on (see [How it works](#how-it-works)).

## How it works

The Iterable documentation that powers the skill is published to
[Context7](https://context7.com), a service that hosts docs for AI assistants to
query. When you ask the skill to build something, it fetches the relevant
articles from Context7 on demand, so it works from the current documentation
rather than what the model happened to memorize.

A copy of the same docs ships inside the skill (`iterable-android/snapshot/`),
which it falls back to if Context7 is unreachable or your assistant is offline.
This snapshot is the active source today; the Context7 library comes online in an
upcoming release.

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
