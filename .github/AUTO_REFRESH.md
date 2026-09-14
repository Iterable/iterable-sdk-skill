# Auto-refresh the skill corpora when iterable-docs changes

Companion to `.github/workflows/refresh-docs.yml`, written to be shared with the
docs team. It explains what we are asking for, why it mirrors something they
already merged, and what the credential can and cannot do.

## The problem

`iterable-android/reference/` and `iterable-react-native/reference/` are a
deterministic reshaping of Iterable's published docs — no LLM step, the corpus
*is* the docs. Each platform's `pipeline/config/<platform>.yml` pins the exact
docs commit it was built from (`source.ref`).

That pin only moves when a human remembers to move it. So every merge to
iterable-docs silently widens the gap between what the docs say and what the
skill tells developers. Nobody gets told; the corpus just quietly goes stale.

## The mechanism

Two halves, one already built:

**Sender** — `iterable-docs`, [PR #1569](https://github.com/Iterable/iterable-docs/pull/1569).
On a push to `master` that touches an SDK doc tree, POST a `repository_dispatch`
of type `iterable-docs-changed` to `Iterable/iterable-sdk-skill`, carrying the
docs commit sha. Path-filtered, so unrelated docs merges cost nothing.

**Receiver** — this repo, `.github/workflows/refresh-docs.yml`. Already on
`main`. Resolves the sha, rebuilds every platform's `reference/` from the docs
at that commit, bumps `source.ref` only for platforms whose corpus actually
changed, validates the result, and commits straight to `main`.

Nothing on our side gates a docs change behind a human. Once `pnpm check:all`
passes, the refreshed corpus is live, and a human audits it afterwards (see
`REVIEW.md`). That is our call to make, not a burden the docs team inherits:
from their side this is one outbound notification per relevant merge, and what
they publish is what we serve.

## Why this shape

It is deliberately the same shape as `rag-backfill.yaml`, which the docs team
merged in [#1489](https://github.com/Iterable/iterable-docs/pull/1489)
(NOVA-1418) for Nova's RAG index: same `push: master` + test-label trigger, same
`gha-runner-no-perms` runner, one outbound call per relevant merge. Reviewing
ours should feel familiar.

One honest difference. Nova calls the Argo API with a service-account token that
already existed in the docs repo, so it needed no new credential. Ours is a
cross-repo GitHub call, so it needs a GitHub credential the docs repo does not
have yet. That is the whole reason this is a bigger ask than theirs, and it is
the part worth scrutinising.

## What we need from the docs team

1. **Review and merge PR #1569.** It adds one workflow file and changes nothing
   else.
2. **A repo secret, `SKILL_REPO_DISPATCH_TOKEN`** — see below.
3. **A label, `sync-to-skill-repo`**, mirroring Nova's `sync-to-nova-stg`, so
   the workflow can be tested from a PR before it ever runs on `master`.

## The credential, precisely

A GitHub App installation token or fine-grained PAT, scoped to exactly one
repository (`Iterable/iterable-sdk-skill`) with exactly one permission:

| | |
|---|---|
| Repository access | `Iterable/iterable-sdk-skill` only |
| Permission | **Contents: write** — nothing else |
| Used for | one API call: `POST /repos/Iterable/iterable-sdk-skill/dispatches` |

`Contents: write` is what GitHub requires for the dispatch endpoint; there is no
narrower permission that reaches it. Worth being clear about what that does and
does not allow:

- It **cannot** read anything in `iterable-docs`. It is scoped to our repo.
- It **cannot** approve or merge PRs (that needs Pull requests: write).
- It **can**, if leaked, write to our repo's contents. The blast radius is a
  public docs corpus with reviewed PRs and no production surface.

We would prefer a GitHub App or machine account over anyone's personal PAT, so
it neither expires unnoticed nor ties org automation to one person's account. We
have already been bitten by exactly that: our own `DOCS_READ_TOKEN` was a
fine-grained PAT, it expired ~2026-08-29, and refreshes failed silently for two
weeks before anyone looked.

## Doc trees the sender watches

Under `docs/developer-and-api-docs/`:

`iterables-ios-and-android-sdks`, `iterables-react-native-sdk`,
`in-app-messages`, `push-notifications`, `embedded-messaging`, `deep-links`,
`managing-user-profiles`, `event-tracking`, `unknown-user-activation-dev`.

These mirror the `articles` lists in `pipeline/config/*.yml`. If the docs team
reorganises a tree, the filter needs the same edit — a rename means refreshes
stop firing rather than break loudly, which is the one maintenance hazard here.

## Context

Julie Snow raised the underlying concern on 2026-07-23: redundant copies of the
docs drifting from the source. This is the mechanism that stops ours from
drifting.
