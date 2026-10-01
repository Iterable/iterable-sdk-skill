#!/usr/bin/env bash
# The words as a surface someone edits: that they can be found, and that they fit where they
# are printed. Whether they are the *right* words is not a thing a test can hold.
#
# tools/screens is what a docs editor reads: every screen's current wording, each headed by
# the file and line it is written on. Two ways it can fail without looking broken, and both
# leave someone with text and nowhere to type:
#
#   the list goes empty     kinds() reads question_for's own case arms. Reformat that case
#                           and the sed finds nothing, and screens prints a tidy nothing.
#   an address goes missing where() reads which q_ function each arm calls. A screen it
#                           cannot place is headed "no q_ function", which is a dead end.
#
# The wording itself is checked in agent-questions.sh, against the JSON the chat is handed.
# Here, the pointer being a real one — and the one limit a person editing a gate name cannot
# see from the text they are editing.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }
COPY_TMP="$(mktemp -d)"; trap 'rm -rf "$COPY_TMP"' EXIT

echo
echo "  The words — findable, and inside the space they are printed in"
echo

# The editor-facing entry point has to explain itself without requiring node or rendering a
# ten-second conversation. The names come from the same dispatch as the renderer, so help is
# discovery rather than another screen list to maintain.
HELP="$(tools/screens --help)" || { bad "tools/screens --help did not run"; echo "  FAILED"; exit 1; }
if grep -qF 'make screens KIND=SCENARIO' <<< "$HELP" \
   && grep -qE '^  pick_device[[:space:]]+bin/questions.sh:' <<< "$HELP" \
   && grep -qE '^  iterable_step 4[[:space:]]+bin/questions.sh:' <<< "$HELP"; then
  ok "screens help shows how to render one scenario and lists every kind of selector"
else
  bad "screens help does not make the available scenarios discoverable"
fi

LIST="$(tools/screens --list)"
if grep -qxF 'pick_device' <<< "$LIST" \
   && grep -qxF 'iterable_step 1' <<< "$LIST" \
   && grep -qxF 'iterable_step 4' <<< "$LIST"; then
  ok "the plain scenario list includes ordinary and argument-taking screens"
else
  bad "tools/screens --list omitted a screen scenario"
fi

# The first writer-facing screen: prose in Markdown, actions still in shell. Validate the
# live file, then prove the stable option ids connect each editable label to the right
# command even though those ids never have to become developer-visible.
# shellcheck source=bin/screen-copy.sh
. bin/screen-copy.sh
if screen_copy_validate opening "agent terminal stop" "part_map"; then
  ok "the opening Markdown has every required section, option id and placeholder"
else
  bad "copy/screens/opening.md does not satisfy the writer-facing format"
fi

OPENING="$(WS="$COPY_TMP/ws" bash bin/agent question opening)"
AGENT_LABEL="$(screen_copy_option_scalar opening agent Label)"
TERMINAL_LABEL="$(screen_copy_option_scalar opening terminal Label)"
STOP_LABEL="$(screen_copy_option_scalar opening stop Label)"
if printf '%s' "$OPENING" | AGENT_LABEL="$AGENT_LABEL" TERMINAL_LABEL="$TERMINAL_LABEL" \
   STOP_LABEL="$STOP_LABEL" node -e '
     let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
       const q=JSON.parse(s), byLabel=l=>q.options.find(o=>o.label===l);
       const a=byLabel(process.env.AGENT_LABEL), t=byLabel(process.env.TERMINAL_LABEL);
       const stop=byLabel(process.env.STOP_LABEL);
       if (!a || !a.commands.some(c=>c.includes("DRIVER=agent"))) process.exit(1);
       if (!t || !t.commands.some(c=>c.includes("DRIVER=developer"))) process.exit(1);
       if (!stop || stop.commands.length) process.exit(1);
     })'; then
  ok "editable option labels remain attached to behavior by stable ids"
else
  bad "an opening option inherited another option's behavior"
fi

# Writer mistakes should point at the copy, not fail later as malformed JSON. Each fixture
# breaks one rule and asks only for the useful part of the resulting message.
cp copy/screens/opening.md "$COPY_TMP/opening.md"
sed -i.bak 's/{{part_map}}/{{part_maps}}/' "$COPY_TMP/opening.md"
ERR="$(SCREEN_COPY_ROOT="$COPY_TMP" bash -c \
  'source bin/screen-copy.sh; screen_copy_validate opening "agent terminal stop" part_map' 2>&1)" || true
if grep -qF 'unknown placeholder {{part_maps}}' <<< "$ERR"; then
  ok "a placeholder typo names the file, line and unknown placeholder"
else
  bad "an unknown Markdown placeholder did not produce a useful error"
fi

sed '/^## Option: stop/,$d' copy/screens/opening.md > "$COPY_TMP/opening.md"
ERR="$(SCREEN_COPY_ROOT="$COPY_TMP" bash -c \
  'source bin/screen-copy.sh; screen_copy_validate opening "agent terminal stop" part_map' 2>&1)" || true
if grep -qF 'missing option "stop"' <<< "$ERR"; then
  ok "removing a behavior-backed option says which stable id is missing"
else
  bad "a missing Markdown option did not name its stable id"
fi

cp copy/screens/opening.md "$COPY_TMP/opening.md"
printf '\n## Prompt\n\nAnother question?\n' >> "$COPY_TMP/opening.md"
ERR="$(SCREEN_COPY_ROOT="$COPY_TMP" bash -c \
  'source bin/screen-copy.sh; screen_copy_validate opening "agent terminal stop" part_map' 2>&1)" || true
if grep -qF 'duplicate "Prompt" section' <<< "$ERR"; then
  ok "duplicating a fixed section says which heading must be removed"
else
  bad "a duplicate Markdown section did not produce a useful error"
fi

# --where rather than the whole thing: the render is ten seconds of node per pass, and it is
# not what is fragile here.
W="$(tools/screens --where)" || { bad "tools/screens --where did not run"; echo "  FAILED"; exit 1; }

# Counted against the dispatch directly, so the check does not share kinds()' sed with the
# thing it is checking.
ARMS=$(sed -n '/^question_for() {/,/^}/p' bin/questions.sh \
       | grep -cE '^    [a-z_|]+\)')
LISTED=$(grep -c $'^[a-z_]*\t' <<< "$W")
if ((ARMS > 10 && LISTED >= ARMS)); then
  ok "$LISTED screens listed, from $ARMS arms of the dispatch"
else
  bad "$LISTED screens listed for $ARMS arms — the list is reading the dispatch wrong"
fi

# An empty second field, not the words "no q_ function": that sentence is printed by the
# display path, and a test that greps for it would pass on a kind that resolved to nothing.
MISSING="$(awk -F'\t' '$2 == "" { print $1 }' <<< "$W")"
if [[ -z "$MISSING" ]]; then
  ok "every kind resolves to somewhere in the file"
else
  bad "screens cannot place these kinds — their readers get sent nowhere:"
  printf '        %s\n' $MISSING
fi

# Nothing dropped on the way. where() looks each function up by its definition line and skips
# the ones it cannot find, so a function written as `q_foo ()  {` disappears from the address
# of a screen that still has two other functions in it — no empty field, and no mention of
# the one you would need to edit. The line numbers themselves are read from the file at
# render time, so they cannot be stale; being there at all is the part worth asserting.
NAMED="$(sed -n '/^question_for() {/,/^}/p' bin/questions.sh | grep -oE 'q_[a-z_]+' | sort -u)"
DROPPED=""
for fn in $NAMED; do
  grep -qE "[0-9]+ +$fn( |\$)" <<< "$W" || DROPPED+=" $fn"
done
if [[ -z "$DROPPED" ]]; then
  ok "all $(wc -w <<< "$NAMED" | tr -d ' ') screen functions appear in the addresses"
else
  bad "the dispatch calls these and no address mentions them:$DROPPED"
fi

# One screen rendered for real, because everything the render needs — the stub toolchain, the
# fixture discovery cache, config.sh sourced from outside a workspace — can break at once and
# --where would not notice. pick_device uses all three.
OUT="$(tools/screens pick_device 2>&1)"
if grep -q 'Which device' <<< "$OUT" && grep -q 'Pixel_9_Pro' <<< "$OUT"; then
  ok "a screen renders with its sample devices in it"
else
  bad "tools/screens pick_device did not render — the fixtures or the render broke:"
  printf '%s\n' "$OUT" | sed 's/^/      /' | head -12
fi

# The fixtures hold a fake key path and a fake account; they are a temp directory for a
# reason, and a docs editor running this all afternoon should not be leaving a trail.
LEFT=$(ls -d /tmp/iterable-screens.* 2>/dev/null | wc -l | tr -d ' ')
((LEFT == 0)) && ok "the sample workspace goes away with the process" \
              || bad "$LEFT sample workspaces left in /tmp — the cleanup trap is not firing"

# Gate names print into a fixed column — `%-4s %-34s` in bin/gates — and the verdict starts
# where that column ends. A name one character over does not wrap; it shoves that gate's
# verdict right while every other row stays put, and the ladder stops reading as a list.
# Nothing about the sentence tells you that, which is why it is here and not a comment.
NAMES="$(grep -hoE '^(gate|note) G[0-9]+ +"[^"]*"' bin/gates bin/gates-*.sh \
         | sed 's/.*"\(.*\)"/\1/')"
WIDE="$(awk 'length > 34 { print length ": " $0 }' <<< "$NAMES")"
COUNT=$(grep -c . <<< "$NAMES")
if ((COUNT < 10)); then
  # Otherwise the check passes by finding nothing, which is what it would do the day the
  # ladder is declared some other way.
  bad "only $COUNT gate names found — this is not reading the ladder any more"
elif [[ -z "$WIDE" ]]; then
  ok "all $COUNT gate names fit the 34-column field bin/gates prints them in"
else
  bad "a gate name is wider than its column — the verdict beside it gets pushed out of line:"
  printf '%s\n' "$WIDE" | sed 's/^/        /'
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — the wording has an address, and it fits."
