#!/usr/bin/env bash
# Offline: how a run ends. One instruction, once, in a colour you can read — then the
# handback, last.
#
# All three were broken at the same time on a real run. provision exec's the verifier,
# which printed the whole rc-40 ending, and then the wizard printed it again: two
# identical YOUR TURN boxes, which read as two separate things to do. Underneath that,
# the list of what was still waiting and the file to keep were both grey, while the
# only line addressed to the assistant was grey too — and phrased as a question to the
# developer, so the outcome travelled by being retyped.
#
# Nothing here touches the network: the ladder state is a fixture.

set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-52s %s\n' "$1" "$2"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WSD="$TMP/.iterable"; mkdir -p "$WSD/artifacts"
printf '{}\n' > "$WSD/artifacts/sa-key.json"

# Everything the tool can do is done; what is left is the Iterable walk and the app.
# That is the state the duplicated ending was found in.
cat > "$WSD/state.tsv" <<'EOF'
G0	green	human	Tooling present	node v22.3.0
G1	green	human	Google authenticated	someone@example.com, token spendable
G2	green	tool	GCP project exists	stub-project ACTIVE
G9	green	tool	Key actually works	FCM accepted the credential
G10	red	human	Iterable API keys work	no server-side key yet
G13	pending	human	App installed with the SDK	not installed yet
EOF

# next_action calls missing_tools and reports install_tools ahead of everything when one
# is absent, which would replace every ending under test with the install branch. Stubbing
# the tools *away* would cause that; so would leaving PATH alone on a machine that has no
# gcloud — which is how this suite passed for months and then failed the first time CI ran
# it on a clean runner. Supply them instead, so the branch under test is the one that runs
# on every host.
. tests/lib/stub-toolchain.sh
stub_toolchain "$TMP/tools"

render() { ( cd "$TMP" && WS="$WSD" PID=stub-project PACKAGE=com.example \
  PATH="$TMP/tools:$PATH" bash -c "source '$ROOT/bin/config.sh'; $1" 2>&1 ); }

strip() { LC_ALL=C sed $'s/\033\\[[0-9;]*m//g'; }

echo
echo "  How a run ends — once, legibly, and in that order"
echo

# ------------------------------------------------------------------ said once
END="$(render 'pending_tail; agent_handback')"
BOXES="$(grep -c '┏' <<< "$(strip <<< "$END")")"
if [[ "$BOXES" == 1 ]]; then
  ok "the rc-40 ending draws exactly one box"
else
  bad "one box per ending" "drew $BOXES"
fi

# The wizard is the front end that had the duplicate, and it cannot be driven here —
# it wants a terminal and a Google session. So pin the wiring instead: the verifier is
# quiet on both of the wizard's paths through it, because the wizard prints the ending.
for call in '"$BIN/gates"' '"$BIN/provision"'; do
  if grep -qF "QUIET_VERDICT=1 $call" bin/wizard; then
    ok "the wizard keeps the verifier quiet for ${call//\"/}"
  else
    bad "quiet verifier for ${call//\"/}" "the wizard would print the ending twice"
  fi
done

# ------------------------------------------------------- the order of the two
PLAIN="$(strip <<< "$END")"
box_at="$(grep -n '┏' <<< "$PLAIN" | head -1 | cut -d: -f1)"
hand_at="$(grep -n 'for the assistant' <<< "$PLAIN" | head -1 | cut -d: -f1)"
if [[ -n "$box_at" && -n "$hand_at" ]] && ((hand_at > box_at)); then
  ok "the instruction comes first, the handback after it"
else
  bad "instruction before handback" "box at ${box_at:-none}, handback at ${hand_at:-none}"
fi

# The handback states the outcome rather than asking for it to be relayed. A developer
# is not a transport for a fact that is already on disk.
if grep -qF 'state.tsv' <<< "$PLAIN"; then
  ok "the handback names the file the result is in"
else
  bad "handback names state.tsv" "nothing says where to read the outcome"
fi
if grep -qiE 'tell (it|your assistant) (you are|that you are) done' <<< "$PLAIN"; then
  bad "handback asks for a relay" "the outcome is on disk; asking is how it gets garbled"
else
  ok "and does not ask anybody to relay it"
fi
if grep -qF 'Iterable API keys work' <<< "$PLAIN"; then
  ok "and names the gate that is still open"
else
  bad "handback names the open gate" "no gate named"
fi

# ------------------------------------------------------------------ legibility
# Every line that only exists in dim is a line most terminal themes render as grey on
# grey. What is left of the ending with the dim parts removed has to still be the whole
# instruction — the box, what waits behind it, and the file to keep.
undim() { LC_ALL=C sed -E $'s/\033\\[2m[^\033]*\033\\[0m//g' <<< "$1" | strip; }
KEPT="$(undim "$END")"
for want in 'iterable-keys --step 1' 'Waiting behind it' 'sa-key.json' 'state.tsv'; do
  if grep -qF "$want" <<< "$KEPT"; then
    ok "survives the dim being unreadable: $want"
  else
    bad "lost when dim is unreadable: $want" "it is the only place that appears"
  fi
done

# ------------------------------------------------------------- dim, accounted for
# A count per file, so a new grey line takes a deliberate edit here. Every one of these
# is a footnote or a status glyph or the detail column of a gate that is already green:
#   config.sh  the handback's own rule, and APPROVED=1 as a CI alternative
#   gates      three status glyphs, a green row's detail, the ASK.md footnote
#   onboard    the ASK.md footnote
ACTUAL="$(grep -ro '\$(dim' bin/ 2>/dev/null | cut -d: -f1 | sort | uniq -c \
  | awk '{print $2":"$1}' | tr '\n' ' ')"
EXPECT="bin/config.sh:2 bin/gates:5 bin/onboard:1 "
if [[ "$ACTUAL" == "$EXPECT" ]]; then
  ok "dim appears only where an aside is allowed"
else
  bad "dim spread" "expected [$EXPECT] got [$ACTUAL]"
fi

# ------------------------------------------------------------ the AI notice
# It is printed at the top of every run and again at the end, so length is the whole
# problem: long enough to scroll past is long enough to never be read.
NOTICE="$(render 'ai_notice_banner' | strip | grep -c .)"
if ((NOTICE <= 7)); then
  ok "the AI notice fits in $NOTICE lines, bars included"
else
  bad "AI notice length" "$NOTICE lines — it was shortened once for being scrolled past"
fi
# Still has to say the one thing that distinguishes evidence from a draft.
if render 'ai_notice' | grep -qiE 'push proof.*evidence|evidence.*push proof'; then
  ok "and still names the push proof as the only evidence"
else
  bad "AI notice lost its point" "shortening removed the evidence-vs-draft distinction"
fi

# ------------------------------------------------- stopped before any check
# The trap fires on every exit, including a Ctrl-C at the project picker. Handing over
# "read state.tsv" there is worse than saying nothing: the file is either absent or a
# previous run's, and an agent that believes it reports last week's ladder as today's.
mv "$WSD/state.tsv" "$TMP/kept.tsv"
EARLY="$(render 'agent_handback' | strip)"
mv "$TMP/kept.tsv" "$WSD/state.tsv"
if grep -qF 'state.tsv' <<< "$EARLY"; then
  bad "early exit points at state.tsv" "there is no ladder result to read"
else
  ok "an exit before any check says so instead of naming a file"
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — one ending, readable, with the handback last."
