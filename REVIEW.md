# Reviewer guide

The pipeline opens automated PRs whenever Iterable's docs change (see
[`refresh-docs.yml`](.github/workflows/refresh-docs.yml)). This document is
the reviewer's playbook for those PRs and for any hand-authored change to
the corpus.

The corpus is a **deterministic transform** of Iterable's docs — **no LLM
rewrites the content**. So review is mostly mechanical: confirm the transform
faithfully reshaped the upstream docs and didn't lose anything. There is no
LLM output to second-guess.

---

## When you'd be reviewing

Three flavors of PR land in this repo:

| PR type | Source | Reviewer focus |
|---|---|---|
| **Automated docs refresh** | `refresh-docs.yml` dispatch / `workflow_dispatch` | Source diff fidelity + snapshot refreshed |
| **Manual content edit** | a contributor hand-edits a corpus doc | Why is hand-editing needed? Should the transform learn it instead? |
| **Pipeline / schema / CI change** | edits under `pipeline/`, `.github/`, or `iterable-android/` (not snapshot) | Standard code review, plus run `pnpm check:all` |

The rest of this document is the **docs-refresh** flow because that's the one
that happens on cadence. The other two are covered by standard code review.

---

## Step 1 — Verify the source diff looks sane (2 min)

Open the PR. The body lists the touched slugs and points at the auto-fetched
sources. Spot-check:

- [ ] **Source files match Iterable's docs at the pinned commit.** If
  `source_ref` in any frontmatter is suspicious (e.g. points to a branch
  rather than a commit SHA), stop and investigate — the pin is the pipeline's
  one guarantee against moving-target drift.
- [ ] **No source file was added or removed unexpectedly.** A new file
  means the pipeline picked up a new Iterable doc; confirm it's intentional.
- [ ] **The slug list in the PR title matches the actual `sources/` diff.**
  Mismatch usually means the workflow misparsed slugs — flag, don't merge.

---

## Step 2 — Refresh the snapshot and run the gates (2 min)

The transform runs automatically in the refresh workflow, so the `polished/`
diff is already in the PR. You just need to keep the installable snapshot in
sync and confirm the gates pass:

```bash
git checkout <pr-branch>
cd pipeline
pnpm snapshot:refresh   # mirror polished/ → iterable-android/snapshot/
pnpm check:all          # MUST be green before you push
```

Commit any `iterable-android/snapshot/` changes — CI's `snapshot:verify` gate
will fail the build otherwise.

---

## Step 3 — Read the diff for what the gates can't catch (5 min)

The mechanical gates catch frontmatter validity, snippet-manifest consistency,
snapshot drift, and (advisory) snippet syntax. Because the transform is
deterministic, there's no hallucination risk — but it's still worth a human
read of the diff against `sources/`:

- [ ] **The transform only reshaped, never changed meaning.** Boilerplate
  removed, callouts converted, blank lines collapsed — but no claim added,
  weakened, or reversed. If the diff shows a *content* change that isn't
  explained by an upstream edit, the transform has a bug; file it against
  `pipeline/`, don't hand-patch the output.
- [ ] **Links still resolve.** The transform doesn't touch URLs, but upstream
  may have changed one. Spot-check any new/changed `support.iterable.com` link.

### Upstream bugs stay in
- [ ] **Snippet errors that came from upstream stay in.** The corpus mirrors
  the docs; we don't hand-fix upstream typos here. Track them as issues
  against `Iterable/iterable-docs` and move on.
- [ ] **Snippet-match ≠ snippet-compiles.** `snapshot:verify` proves the
  snapshot matches the corpus byte-for-byte; the `kotlinc` gate is advisory
  (no classpath). Neither proves a snippet compiles against the pinned SDK. A
  doc can be perfectly faithful and still ship a *wrong-overload* example
  (real case: the 3-arg `initializeInBackground(context, key, config)` binds
  config to the callback slot — see PITFALLS.md #18). When a snippet is
  load-bearing, eyeball it against the actual SDK signatures; if it's an SDK
  foot-gun rather than a one-doc typo, add it to `PITFALLS.md` rather than
  patching the doc. (v2: blocking compile check with the SDK aar closes this.)

---

## Step 4 — Final check before merging (1 min)

- [ ] `pnpm check:all` is green locally.
- [ ] `iterable-android/snapshot/` was refreshed in this PR.
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
- `kotlinc -script` snippet check is advisory (no classpath in v1); the
  "unresolved reference" warnings are expected.

If a fix would touch any of the above, open a separate PR scoped to the
fix, not a refresh PR.
