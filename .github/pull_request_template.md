<!--
Thanks for opening a PR. Pick the section below that matches your change
type and delete the others.

Full reviewer guide: REVIEW.md
-->

## Type

- [ ] Docs refresh (automated, opened by `refresh-docs.yml`)
- [ ] Manual reference-content edit
- [ ] Skill / pipeline / CI change

---

## If this is a docs refresh

**Touched slugs:** <!-- auto-filled by refresh-docs.yml -->

Reviewer checklist (see [`REVIEW.md`](../REVIEW.md) for the full version):

- [ ] `source_ref` is a commit SHA, not a branch; the `source.ref` bump matches the docs commit in the body
- [ ] `pnpm check:all` green locally
- [ ] **Changed guidance still agrees with `PITFALLS.md`** — if the docs now contradict a pitfall, resolve it in this PR
- [ ] If a referenced heading moved, `SKILL.md`'s routing table updated to match
- [ ] Diff read as documentation: the transform only reshaped (boilerplate stripped, callouts converted) — no content added, weakened, or reversed
- [ ] Upstream snippet bugs (if any) tracked as separate issues against `Iterable/iterable-docs` — **not** hand-fixed here

---

## If this is a manual reference-content edit

Why is the deterministic transform insufficient for this change? (One sentence.)

<!-- e.g. "Foreign-language stripping of a cross-platform doc — the transform
doesn't do this yet." -->

- [ ] `pnpm check:all` green locally
- [ ] Considered whether the transform (`pipeline/src/lib/layer-a.ts`) could be updated instead of editing by hand
- [ ] Noted that the next `pnpm refresh:docs` will overwrite this file if upstream changes

---

## If this is a skill / pipeline / CI change

- [ ] `pnpm check:all` green
- [ ] If changing the schema or a validator, tested both the success and the failure case locally
- [ ] If changing `SKILL.md`, sanity-checked the routing table against that skill's `reference/`

---

## Anything reviewers should know

<!-- Context that doesn't fit a checkbox: blocked-on, follow-up, gotchas. -->
