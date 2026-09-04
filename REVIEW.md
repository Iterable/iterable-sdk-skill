# Reviewer guide

A workflow opens an automated PR whenever Iterable's docs change (see
[`refresh-docs.yml`](.github/workflows/refresh-docs.yml)). This document is
the reviewer's playbook for those PRs and for any hand-authored change to a
platform `reference/` directory (`iterable-android/reference/`,
`iterable-react-native/reference/`, …).

The corpus is a **deterministic transform** of Iterable's docs — **no LLM
rewrites the content**. There is no LLM output to second-guess, so the review
is not about hallucination. It's about whether the new guidance is something we
want the agent handing to a developer.

---

## When you'd be reviewing

Three flavors of PR land in this repo:

| PR type | Source | Reviewer focus |
|---|---|---|
| **Automated docs refresh** | `refresh-docs.yml` dispatch / `workflow_dispatch` | Does the new guidance still agree with `PITFALLS.md`? |
| **Manual content edit** | a contributor hand-edits a reference doc | Why is hand-editing needed? Should the transform learn it instead? |
| **Skill / pipeline / CI change** | edits to `SKILL.md`, `PITFALLS.md`, `pipeline/`, `.github/` | Standard code review, plus run `pnpm check:all` |

The rest of this document is the **docs-refresh** flow because that's the one
that happens on cadence. The other two are covered by standard code review.

---

## Step 1 — Check provenance (1 min)

Open the PR. The body lists the touched slugs and the docs commit.

- [ ] **`source_ref` in the changed frontmatter is a 40-char commit SHA**, not a
  branch name. The pin is our one guarantee against moving-target drift.
- [ ] **The `source.ref` bump in the changed `pipeline/config/<platform>.yml`
  file(s) matches the docs commit in the PR body.** Unchanged platforms must
  not have a pin bump.
- [ ] **No doc was added or removed unexpectedly.** Each corpus only contains
  slugs listed in `pipeline/config/<platform>.yml`; `validate:reference` fails
  if they disagree, so an add/remove means someone edited the config too.

---

## Step 2 — Run the gates (1 min)

```bash
git checkout <pr-branch>
cd pipeline && pnpm check:all
```

---

## Step 3 — Read the diff as documentation (5 min)

This is the part no gate can do. The diff is what the agent will tell a
developer to do, so read it that way:

- [ ] **Does the changed guidance contradict `PITFALLS.md`?** This is the most
  important question in the review. The pitfalls encode silent-failure traps;
  if Iterable's docs now recommend something a pitfall warns against, one of the
  two is wrong. Resolve it in this PR — don't merge a corpus that argues with
  itself.
- [ ] **Did headings move?** `SKILL.md`'s routing table points at slugs, and the
  upgrade row points at `## Upgrading the SDK` inside `android-sdk`. If a
  referenced section was renamed, update the routing table in the same PR.
- [ ] **The transform only reshaped, never changed meaning.** Boilerplate
  removed, callouts converted, blank lines collapsed — but no claim added,
  weakened, or reversed. A *content* change not explained by an upstream edit
  means the transform has a bug; file it against `pipeline/`, don't hand-patch
  the output.
- [ ] **Links still resolve.** The transform doesn't touch URLs, but upstream
  may have changed one. Spot-check any new/changed `support.iterable.com` link.

### Upstream bugs stay in
- [ ] **Snippet errors that came from upstream stay in.** The corpus mirrors
  the docs; we don't hand-fix upstream typos here. Track them as issues
  against `Iterable/iterable-docs` and move on.
- [ ] **Nothing here proves a snippet compiles.** The gates check frontmatter
  and slug agreement, not code. A doc can be perfectly faithful and still ship a
  *wrong-overload* example (real case: the 3-arg
  `initializeInBackground(context, key, config)` binds config to the callback
  slot — see PITFALLS.md #18). When a snippet is load-bearing, eyeball it
  against the actual SDK signatures; if it's an SDK foot-gun rather than a
  one-doc typo, add it to `PITFALLS.md` rather than patching the doc.

---

## Step 4 — Final check before merging (1 min)

- [ ] `pnpm check:all` is green locally.
- [ ] The PR description still accurately describes what changed.

---

## What we DON'T review

- **Docs team voice / branding decisions.** That's the docs team's domain.
  Our job is to faithfully transform their docs, not to second-guess them.
- **SDK API correctness.** That's the SDK team's domain. We surface what the
  docs say; if the docs are wrong, file an upstream bug.
- **The transform's reshaping rules.** Boilerplate-stripping and callout
  conversion live in `pipeline/src/lib/layer-a.ts`. If the reshaping is
  consistently wrong, fix the transform in a separate PR — don't hand-edit
  each corpus file.

---

## Escalation

- **A content change you can't explain by an upstream edit:** the transform
  has a bug — stop and file it against `pipeline/` before merging.
- **CI gate that keeps failing across multiple PRs:** the gate may be broken,
  not the content. File an issue against `pipeline/`.

---

## Tracked v1 limitations (don't try to fix in a refresh PR)

These are known and live on the roadmap; **do not** hand-fix them in a
docs-refresh PR.

- The corpus is the docs reshaped, with **no editorial cleanup** — prose
  stays in the docs' customer-facing voice, and Java/Kotlin duplicates are
  both kept. Agent-facing judgement lives in `SKILL.md` / `PITFALLS.md`.
- A few docs come from shared "Mobile SDKs" sources and still contain
  iOS/JavaScript snippets (`identifying-the-user`, `updating-user-profiles`,
  `tracking-events-with-iterables-mobile-sdks`). Deterministic
  foreign-language stripping is a candidate v1.1 transform.
- **No snippet compile check.** There is no gate that compiles corpus snippets
  against the pinned SDK; a reviewer's eye on load-bearing snippets is the only
  check. Adding one means an Android toolchain in CI — worth it only if wrong
  snippets actually reach developers.

If a fix would touch any of the above, open a separate PR scoped to the
fix, not a refresh PR.
