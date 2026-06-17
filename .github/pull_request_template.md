<!--
Thanks for opening a PR. Pick the section below that matches your change
type and delete the others.

Full reviewer guide: REVIEW.md
-->

## Type

- [ ] Docs refresh (automated, opened by `refresh-docs.yml`)
- [ ] Manual polished-content edit
- [ ] Pipeline / schema / CI / skill change

---

## If this is a docs refresh

**Touched slugs:** <!-- auto-filled by refresh-docs.yml -->

Reviewer checklist (see [`REVIEW.md`](../REVIEW.md) for the full version):

- [ ] Source diff looks sane; `source_ref` is a commit SHA, not a branch
- [ ] `pnpm snapshot:refresh` committed
- [ ] `pnpm check:all` green locally
- [ ] Corpus diff read against `sources/`: the transform only reshaped (boilerplate stripped, callouts converted) — no content added, weakened, or reversed
- [ ] Upstream snippet bugs (if any) tracked as separate issues against `Iterable/iterable-docs` — **not** hand-fixed here

---

## If this is a manual polished-content edit

Why is the deterministic transform insufficient for this change? (One sentence.)

<!-- e.g. "Foreign-language stripping of a cross-platform doc — the transform
doesn't do this yet." -->

- [ ] `pnpm recompute:manifest` run for every edited corpus file
- [ ] `pnpm snapshot:refresh` committed
- [ ] `pnpm check:all` green locally
- [ ] Considered whether the transform (`pipeline/src/lib/layer-a.ts`) could be updated instead of editing by hand

---

## If this is a pipeline / schema / CI / skill change

- [ ] `pnpm typecheck` green
- [ ] `pnpm check:all` green
- [ ] If changing the schema or a validator, tested both the success and the failure case locally
- [ ] If changing `iterable-android/SKILL.md`, sanity-checked the routing table against `polished/<platform>/`
- [ ] If changing the snippet manifest format, ran `pnpm recompute:manifest polished/**/*.polished.md` and confirmed no semantic drift

---

## Anything reviewers should know

<!-- Context that doesn't fit a checkbox: blocked-on, follow-up, gotchas. -->
