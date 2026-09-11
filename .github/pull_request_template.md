<!--
Thanks for opening a PR. Pick the section below that matches your change
type and delete the others.

Full reviewer guide: REVIEW.md
-->

## Type

- [ ] Manual reference-content edit
- [ ] Skill / pipeline / CI change

<!--
Automated docs refreshes do not open PRs — `refresh-docs.yml` validates and
commits them straight to `main`, and a maintainer audits them afterwards.
REVIEW.md has that playbook.
-->

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
