#!/usr/bin/env bash
# Offline lint: each skill's PITFALLS.md, its pipeline/config/pitfalls index, the
# eval checks that cite pitfall ids, and the skill's links into PITFALLS.md all
# name the same pitfalls.
#
# The index is how the eval report labels a check ("pitfall #7"), so a heading added
# or removed without the index shifts every label after it, silently.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-52s %s\n' "$1" "$2"; FAILED=1; }

echo
echo "  Pitfalls — one numbering per skill, everywhere it is cited"
echo

read -r -d '' AGREE_JS <<'JS'
const fs = require("fs");
const [doc, index, scenarios, skill] = process.argv.slice(1);
const problems = [];

const headings = [...fs.readFileSync(doc, "utf8").matchAll(/^## (\d+)\. (.+)$/gm)]
  .map((m) => ({ id: Number(m[1]), text: m[2] }));
const indexText = fs.readFileSync(index, "utf8");
const ids = [...indexText.matchAll(/^  - id: (\d+)\s*$/gm)].map((m) => Number(m[1]));
const movedTo = new Map();
for (const block of indexText.split(/^(?=  - id: \d+\s*$)/m).slice(1)) {
  const id = Number(block.match(/^  - id: (\d+)/)[1]);
  const m = block.match(/^    moved_to: (\S+)\s*$/m);
  if (m) movedTo.set(id, m[1]);
}

const contiguous = (list) => list.every((n, i) => n === i + 1);
if (!contiguous(headings.map((h) => h.id))) problems.push(`PITFALLS.md headings are not 1..N: ${headings.map((h) => h.id).join(",")}`);
if (!contiguous(ids)) problems.push(`index ids are not 1..N: ${ids.join(",")}`);
if (headings.length !== ids.length) problems.push(`PITFALLS.md has ${headings.length} pitfalls, the index has ${ids.length}`);

// A pitfall moved out of the shipped skill keeps its id: a stub heading here, a
// `moved_to` in the index, and the full entry at that path.
for (const h of headings) {
  const stub = /^Moved to eval\b/i.test(h.text);
  const target = movedTo.get(h.id);
  if (stub && !target) problems.push(`pitfall ${h.id} is a moved stub but the index has no moved_to`);
  if (!stub && target) problems.push(`pitfall ${h.id} has moved_to in the index but is not a stub in PITFALLS.md`);
  if (stub && target) {
    if (!fs.existsSync(target)) problems.push(`pitfall ${h.id} moved_to ${target}, which does not exist`);
    else if (!new RegExp(`^#+ Pitfall ${h.id}\\. `, "m").test(fs.readFileSync(target, "utf8")))
      problems.push(`pitfall ${h.id} moved_to ${target}, which has no "Pitfall ${h.id}." heading`);
  }
}

if (fs.existsSync(scenarios)) {
  const cited = [...fs.readFileSync(scenarios, "utf8").matchAll(/^\s+pitfall: (\d+)\s*$/gm)].map((m) => Number(m[1]));
  const unknown = [...new Set(cited.filter((n) => n < 1 || n > ids.length))];
  if (unknown.length) problems.push(`eval checks cite pitfalls the index does not have: ${unknown.join(",")}`);
}

// GitHub's heading anchor: lowercase, drop punctuation, spaces become hyphens.
const slug = (h) => `${h.id}-${h.text}`.toLowerCase().replace(/[^\p{L}\p{N} _-]/gu, "").replace(/ /g, "-");
const anchors = new Set(headings.map(slug));
if (fs.existsSync(skill)) {
  const links = [...fs.readFileSync(skill, "utf8").matchAll(/PITFALLS\.md#([^)\s]+)/g)].map((m) => m[1]);
  const dead = [...new Set(links.filter((a) => !anchors.has(a)))];
  if (dead.length) problems.push(`SKILL.md links to missing PITFALLS.md anchors: ${dead.join(", ")}`);
}

console.log(JSON.stringify({ count: headings.length, problems }));
JS

check_platform() {
  local platform="$1" skill="$2"
  local doc="$skill/PITFALLS.md" index="pipeline/config/pitfalls/$platform.yml"
  local scenarios="eval/scenarios/$platform.yml"

  [[ -f "$doc" && -f "$index" ]] || {
    bad "$platform: PITFALLS.md or its index is missing" "$doc / $index"; return; }

  local out
  out="$(node -e "$AGREE_JS" "$doc" "$index" "$scenarios" "$skill/SKILL.md")" \
    || { bad "$platform: the check itself failed to run" "node error"; return; }

  local count problems
  count="$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).count))' "$out")"
  problems="$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).problems.join("\n"))' "$out")"
  if [[ -z "$problems" ]]; then
    ok "$(printf '%-52s %s' "$platform: PITFALLS.md, index, evals, links agree" "$count pitfalls")"
  else
    while IFS= read -r p; do bad "$platform: pitfalls disagree" "$p"; done <<< "$problems"
  fi
}

check_platform android iterable-android
check_platform ios iterable-ios
check_platform react-native iterable-react-native

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — every pitfall id means the same thing everywhere."
