# Editing screen copy

This directory is the writer-facing part of the onboarding screens. The shell code keeps
commands, consent records and state changes; these Markdown files keep what a developer
reads.

Start by finding the screen:

```bash
make screens-help
make screens KIND=opening
```

Then edit its Markdown file and render it again. Physical line wrapping does not change the
output: lines inside one paragraph are joined, while a blank line remains a paragraph break.

Each screen has these fixed sections:

- `Header` — the short chip shown by a chat UI.
- `Prompt` — the question.
- `Context` — the explanation above it.
- `Requirements` — anything the developer has to do themselves.
- `Option: ...` — one answer, with `Label` and `Description`.

The word after `Option:` is a stable behavior id. Do not rename or remove it. The label,
description and order of the option may change safely: the id is what connects it to its
command in `bin/questions.sh`.

Text such as `{{part_map}}` is a placeholder filled by the tool. Leave known placeholders
where the dynamic content should appear. A typo, missing section, unknown option id or
unknown placeholder produces a file-and-line error from `make screens` and `make test`.

Only `opening.md` has moved so far. It is the complete vertical slice for this editing model;
the remaining screens still live in `bin/questions.sh` and can move here one at a time.
