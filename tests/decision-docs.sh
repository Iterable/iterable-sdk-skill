#!/usr/bin/env bash
# Offline lint: every decision in a skill's Step 0 "Decisions: read before recommending"
# table names a shipped doc, and every section it names is a heading in that doc.
#
# The table is the rule that a recommendation cites a doc. A slug that no longer ships, or
# a heading a refresh renamed, turns that rule into a citation of nothing.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-28s %s\n' "$1" "$2"; FAILED=1; }

echo
echo "  Step 0 decisions — every row cites a doc the skill ships"
echo

read -r -d '' CHECK_JS <<'JS'
const fs = require("fs");
const path = require("path");
const [skillMd, skillDir] = process.argv.slice(1);
const HEADING = "### Decisions: read before recommending";
const REQUIRED = ["Project type", "Identity mode", "An existing client's identifier", "Data region", "JWT"];
const problems = [];
let rows = 0, refs = 0;

const lines = fs.readFileSync(skillMd, "utf8").split("\n");
const at = lines.map((l, i) => (l.trimEnd() === HEADING ? i : -1)).filter((i) => i >= 0);
if (at.length !== 1) {
  problems.push(`expected one "${HEADING}" heading, found ${at.length}`);
} else {
  let i = at[0] + 1;
  const prose = [];
  while (i < lines.length && !lines[i].startsWith("|") && !lines[i].startsWith("#")) prose.push(lines[i++]);
  const rule = prose.join(" ");
  if (!/cite it in the option/.test(rule) || !/offer\s+no recommendation and say so/.test(rule))
    problems.push("the rule above the table (cite the doc; no doc, no recommendation) is missing");

  const table = [];
  while (i < lines.length && lines[i].startsWith("|")) table.push(lines[i++]);
  const body = table.slice(2);
  if (body.length === 0) problems.push("no decision rows under the heading");

  const docCache = new Map();
  const headingsOf = (file) => {
    if (!docCache.has(file))
      docCache.set(file, fs.readFileSync(file, "utf8").split("\n").filter((l) => /^#{1,6} /.test(l)).map((l) => l.trimEnd()));
    return docCache.get(file);
  };
  const SLUG = /^(\.\.\/iterable-[a-z-]+\/reference\/)?([a-z0-9]+(?:-[a-z0-9]+)*)(\.md)?$/;

  const decisions = [];
  for (const row of body) {
    rows++;
    const cells = row.split("|").slice(1, -1).map((c) => c.trim());
    const decision = cells[0] || "(blank)";
    decisions.push(decision);
    let doc = null, named = 0;
    for (const [, token] of cells.slice(1).join(" | ").matchAll(/`([^`]+)`/g)) {
      if (/^#{2,6} \S/.test(token)) {
        if (!doc) { problems.push(`${decision}: section \`${token}\` follows no doc`); continue; }
        if (!doc.file) continue;
        refs++;
        const hit = headingsOf(doc.file).some((h) => h === token || h.startsWith(token + ":") || h.startsWith(token + " "));
        if (!hit) problems.push(`${decision}: \`${doc.name}\` has no heading \`${token}\``);
        continue;
      }
      const m = SLUG.exec(token);
      if (!m) { problems.push(`${decision}: \`${token}\` is neither a slug nor a section heading`); continue; }
      named++; refs++;
      const file = path.join(skillDir, m[1] ? m[1] : "reference/", `${m[2]}.md`);
      if (fs.existsSync(file)) doc = { name: token, file };
      else { doc = { name: token, file: null }; problems.push(`${decision}: \`${token}\` does not ship (${path.relative(process.cwd(), file)})`); }
    }
    if (named === 0) problems.push(`${decision}: names no doc`);
  }
  for (const want of REQUIRED)
    if (!decisions.some((d) => d.startsWith(want))) problems.push(`no "${want}" row`);
}
console.log(JSON.stringify({ rows, refs, problems }));
JS

check() {
  local skillmd="$1" skilldir="$2" label="$3" out
  out="$(node -e "$CHECK_JS" "$skillmd" "$skilldir")" || { bad "$label" "the checker did not run"; return 1; }
  printf '%s' "$out"
}

for skill in iterable-ios iterable-android iterable-react-native; do
  if [[ ! -f "$skill/SKILL.md" ]]; then bad "$skill" "SKILL.md is missing"; continue; fi
  out="$(check "$skill/SKILL.md" "$skill" "$skill")" || continue
  problems="$(node -e 'const r = JSON.parse(process.argv[1]); console.log(r.problems.join("\n"))' "$out")"
  if [[ -z "$problems" ]]; then
    ok "$(node -e 'const r = JSON.parse(process.argv[1]); console.log(`${process.argv[2]}: ${r.rows} decisions, ${r.refs} doc and section references resolve`)' "$out" "$skill")"
  else
    while IFS= read -r p; do bad "$skill" "$p"; done <<< "$problems"
  fi
done

# The check has to be able to fail: a renamed slug and a renamed section in a copy of the
# iOS table must both be reported, against the real corpus.
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
sed -e 's/`user-id-validation-in-iterable` →/`user-id-validation` →/' \
    -e 's/`ios-sdk` → `#### Step 6.2`/`ios-sdk` → `#### Step 6.9`/' \
    iterable-ios/SKILL.md > "$TMP/SKILL.md"
if out="$(check "$TMP/SKILL.md" iterable-ios negative)"; then
  if grep -q '`user-id-validation` does not ship' <<< "$out" && grep -q 'has no heading `#### Step 6.9`' <<< "$out"; then
    ok "a slug or section that does not ship is reported"
  else
    bad "negative case" "a mutated slug and section were not both reported"
  fi
fi

echo
((FAILED)) && exit 1
exit 0
