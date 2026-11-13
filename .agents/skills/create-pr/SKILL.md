---
name: create-pr
description: >-
  Creates a draft GitHub pull request for the current branch of Iterable/iterable-sdk-skill:
  fills the repo's PR template, runs `pnpm check:all`, and keeps unrelated Jira keys out of
  the title, branch, body, and commits. Use when the user asks to create, open, or submit a
  PR in this repo. Internal to maintainers; not part of the published plugin.
---

# Create a pull request

This skill is for maintainers of this repo. It lives in `.agents/skills/` and must never be
added to the `skills` list in `.cursor-plugin/plugin.json` or `.claude-plugin/plugin.json`:
anything listed there ships to every customer who installs the plugin.

## Jira keys and links

Jira's GitHub integration links a PR to every Jira key it finds in the PR title, branch
name, description, and commit messages, and status automation can then move every linked
ticket. Matching ignores case, and backticks, slashes, and URLs do not stop it: `dre-378`,
`` `DRE-378` ``, and `.../browse/DRE-378` all link.

- **Title.** Recent merged PRs use plain imperative titles with no key, for example
  `Require whole-scope confirmation before Android provisioning`. Add a `[KEY-123] ` prefix
  only when the user gives you the PR's ticket. Never infer a key from anywhere else.
- **Branch.** The branch name may contain the PR's own key and no other.
- **Body.** When the PR has a ticket, start `## Anything reviewers should know` with
  `Ticket: [KEY-123](https://iterable.atlassian.net/browse/KEY-123)`, using the PR's own key.
  That is the only Jira key and the only Jira link the body may contain. No other Jira keys
  in any case or format, including epics, parent tickets, and related or follow-up tickets,
  and including inside code spans, URLs, and quoted text. Describe related work in words
  instead.
- **Commits.** Commit messages on the branch follow the same rule as the body.
- **Other links.** Include links to related PRs, docs, or dashboards only when a reviewer
  needs them to review or test this PR. Link another PR as a bare URL or `#number`, without
  copying its title, because a copied title can carry that PR's Jira key.

Before creating the PR, check the title, branch, body, and `git log origin/main..HEAD` for any
key other than the PR's own, matching case-insensitively. If any is found, remove it; for a
commit message, tell the user instead of rewriting history.

## Workflow

1. **Gather the change.**

   ```bash
   git fetch origin main
   git branch --show-current
   git log --oneline origin/main..HEAD
   git diff --stat origin/main...HEAD
   git diff origin/main...HEAD
   ```

   If there are no commits ahead of `origin/main`, tell the user and stop. If the branch is
   not pushed, push it with `git push -u origin HEAD`.

2. **Fill `.github/pull_request_template.md`.**
   - Under `## Type`, check the one box that matches the change.
   - Keep the matching `## If this is ...` section and delete the other one, including its
     `---` separator.
   - In the kept section, answer every prompt and replace each placeholder comment with real
     content. Check a box only when it is true.
   - For skill, pipeline, or CI changes, `CONTRIBUTING.md` asks the body to say which
     developer-facing or model-facing surface changed, what motivated it, whether it changes
     words, behavior, or both, and which tests ran. Put that under
     `## Anything reviewers should know`.

3. **Run the checks.**

   ```bash
   (cd pipeline && pnpm check:all)
   ```

   Also run `make test` when the change touches `bin/`, `tools/`, `tests/`, a skill, or the
   manifests. If a check fails, fix it or tell the user; do not check its box in the body.
   If anything a client receives changed, `tests/plugin-manifests.sh` requires the plugin
   version to move from `main`.

4. **Create the draft PR.** Write the body to a temporary file so the shell does not mangle
   it.

   ```bash
   gh pr create --draft --base main --title "<title>" --body-file <body-file>
   ```

5. **Report.** Give the user the PR URL, a one-line summary, and the checks that ran with
   their results.
