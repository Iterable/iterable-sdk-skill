#!/usr/bin/env bash
# Offline lint: the packaging says the same thing everywhere, and nothing in it is
# specific to the machine it was built on.
#
# None of this is visible from inside the repo — it only shows up once a host reads
# the manifests, which is after the build has been handed to somebody. The version in
# particular decides whether a change reaches a client at all: hosts keep old version
# directories, so a number that does not move means a refresh nobody receives.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-48s %s\n' "$1" "$2"; FAILED=1; }

j() { node -e '
  const v = process.argv.slice(2).reduce((o, k) => (o == null ? o : o[k]),
    JSON.parse(require("fs").readFileSync(process.argv[1], "utf8")));
  process.stdout.write(v === undefined || v === null ? "" : String(v));
' "$@" 2>/dev/null; }

echo
echo "  Packaging — one version, one name, no host paths"
echo

# ------------------------------------------------------------------- the version
CV="$(j .claude-plugin/plugin.json version)"
XV="$(j .cursor-plugin/plugin.json version)"
XM="$(j .cursor-plugin/marketplace.json metadata version)"

if [[ -n "$CV" && "$CV" == "$XV" && "$CV" == "$XM" ]]; then
  ok "$(printf '%-48s %s' "all three manifests name one version" "$CV")"
else
  bad "the manifests disagree on the version" "claude=$CV cursor=$XV cursor-mkt=$XM"
fi

# YY.M.PATCH, calendar-based — see README. Checked because the whole delivery
# mechanism keys off this string, and a typo in it is a silent non-delivery.
[[ "$CV" =~ ^[0-9][0-9]\.[0-9]+\.[0-9]+(-beta)?$ ]] \
  && ok "$(printf '%-48s %s' "the version is a calendar version" "YY.M.PATCH")" \
  || bad "'$CV' is not YY.M.PATCH[-beta]" "the host sorts and directory-names on this"

# --------------------------------------------------------------------- the names
CN="$(j .claude-plugin/plugin.json name)"
XN="$(j .cursor-plugin/plugin.json name)"
MN="$(j .claude-plugin/marketplace.json plugins 0 name)"
if [[ -n "$CN" && "$CN" == "$XN" && "$CN" == "$MN" ]]; then
  ok "$(printf '%-48s %s' "the plugin has one name in both hosts" "$CN")"
else
  bad "the plugin name disagrees" "claude=$CN cursor=$XN listed-as=$MN"
fi

# The committed marketplace is the published one. tools/install-local rewrites this
# in its copy; if the committed value ever becomes a local key, a client's host would
# be told to look for a marketplace that only exists on one laptop.
[[ "$(j .claude-plugin/marketplace.json name)" == iterable ]] \
  && ok "the committed marketplace is the published one" \
  || bad "the committed marketplace name is not 'iterable'" "a local test key was committed"

# --------------------------------------------------------------------- the skills
# A skill directory that is not listed ships nothing, and a listed one that does not
# exist makes the host refuse the whole plugin. Both are invisible from in here.
LISTED="$(node -e '
  process.stdout.write((require("./.claude-plugin/plugin.json").skills || [])
    .map(s => s.replace(/^\.\//, "")).join(" "));
')"
CLISTED="$(node -e '
  process.stdout.write((require("./.cursor-plugin/plugin.json").skills || [])
    .map(s => s.replace(/^\.\//, "")).join(" "));
')"
[[ "$LISTED" == "$CLISTED" ]] \
  && ok "$(printf '%-48s %s' "both hosts are offered the same skills" "$(wc -w <<< "$LISTED" | tr -d ' ') of them")" \
  || bad "the two manifests list different skills" "claude='$LISTED' cursor='$CLISTED'"

missing=""
for s in $LISTED; do
  [[ -f "$s/SKILL.md" ]] || { missing="$missing $s"; continue; }
  grep -q '^name:' "$s/SKILL.md" && grep -q '^description:' "$s/SKILL.md" \
    || missing="$missing $s(frontmatter)"
done
[[ -z "$missing" ]] && ok "every listed skill exists, with name and description" \
                    || bad "listed but not shippable:$missing" "the host refuses the plugin"

unlisted=""
for d in */; do
  d="${d%/}"
  [[ -f "$d/SKILL.md" ]] || continue
  [[ " $LISTED " == *" $d "* ]] || unlisted="$unlisted $d"
done
[[ -z "$unlisted" ]] && ok "no skill is written but unshipped" \
                     || bad "has a SKILL.md and is not listed:$unlisted" "it would ship nothing"

# --------------------------------------------------------------------- the agents
# A host discovers agents/ by convention, so every file in it is loaded into every
# client session — a build role put there costs a client tokens for something they
# could never invoke. Pinned as an exact list on purpose: adding to a client's
# always-on cost should take a deliberate edit here, not just a new file.
SHIPPED="gate-auditor gcp-provisioner iterable-api-client web-operator"
have=""
for a in agents/*.md; do
  [[ -f "$a" ]] || continue
  have="$have $(basename "$a" .md)"
done
have="$(tr ' ' '\n' <<< "${have# }" | sort | tr '\n' ' ')"
want="$(tr ' ' '\n' <<< "$SHIPPED" | sort | tr '\n' ' ')"
[[ "$have" == "$want" ]] \
  && ok "$(printf '%-48s %s' "only client-facing agents are shipped" "$(wc -w <<< "$want" | tr -d ' ') of them")" \
  || bad "agents/ has changed" "shipped='${have% }' expected='${want% }' — build roles belong in tools/agents/"

# ------------------------------------------------------------------- the MCP files
# Two names for one file because the hosts look in different places. They drifted
# once; a client on one host would then get doc fetching the other host's client does not.
if [[ -f mcp.json && -f .mcp.json ]]; then
  cmp -s mcp.json .mcp.json \
    && ok "mcp.json and .mcp.json are identical" \
    || bad "the two MCP files have drifted" "one host would get different servers"
else
  bad "an MCP file is missing" "mcp.json and .mcp.json must both exist"
fi

# ---------------------------------------------------------------- the host's paths
# Everything below is read verbatim by a client's agent. An absolute path from this
# machine in it is an instruction to use a directory the client does not have — and it
# reads authoritative, so it gets followed before it gets doubted.
hits="$(grep -rn "$HOME\|/Users/" --include='*.md' \
          iterable-provision iterable-android iterable-react-native iterable-verify agents \
          2>/dev/null | grep -v '/Users/you\b' || true)"
if [[ -z "$hits" ]]; then
  ok "no path from this machine in any skill or agent"
else
  bad "a host-specific path in shipped text:" "a client cannot follow it"
  printf '        %s\n' $(printf '%s\n' "$hits" | cut -d: -f1-2)
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — the packaging is consistent and portable."
