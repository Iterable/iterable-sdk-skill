#!/usr/bin/env bash
# Shared config for the G0-G9 walk. Override any of these in the environment.

set -uo pipefail

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOL_ROOT="$(cd "$BIN/.." && pwd)"

# The workspace belongs to the project being integrated, not to this tool. A host
# copies a plugin into a cache that may be read-only and is erased on update, so a
# customer's credentials and gate state have no business living there. Resolved
# from the caller's cwd — which means every entry point must be run from the
# project directory, never after a `cd` into the plugin.
#
# Still overridable, so a test can run against a scratch workspace instead of the
# developer's live one. A test that reads real resolved.env isn't offline.
if [[ -z "${WS:-}" ]]; then
  _root="$(git rev-parse --show-toplevel 2>/dev/null)" || _root=""
  [[ -n "$_root" ]] || _root="$PWD"
  # Refuse rather than write. cwd inside the tool means somebody cd'd into the
  # plugin, and state written there is both in the wrong repo and gone at the next
  # update — a failure that would otherwise be invisible until it cost a morning.
  if [[ "$_root" == "$TOOL_ROOT" ]]; then
    cat >&2 <<EOF
Run this from the project you are integrating, not from the tool.

  cd /path/to/your-app && $BIN/agent

The workspace goes in your project as .iterable/ — it holds a service-account key
and your gate state. Set WS=/some/path to override deliberately.
EOF
    exit 30
  fi
  WS="$_root/.iterable"
  unset _root
fi

# Creates the workspace and makes it ignore itself, so a downloaded key cannot be
# committed by a developer who never edited their .gitignore. Self-contained on
# purpose: the tool does not write to files the project owns.
ws_init() {
  command mkdir -p "$WS" || return 1
  [[ -f "$WS/.gitignore" ]] || printf '*\n' > "$WS/.gitignore"
  ws_shims
}

# The entry points a developer is ever told to run. The rest of bin/ is internal —
# wizard and provision are dispatched to, never typed.
SHIM_CMDS="onboard teardown discover gates agent iterable-keys proof-push"

# A host installs a plugin into a version-numbered cache directory, which is both too
# long to type and not stable: old version directories stay on disk, so a path a
# developer saved in a runbook keeps working while quietly running last month's code.
#
# So each entry point gets a one-line stub in their own workspace, which is short
# enough to type, resolves from the project they are already standing in, and is
# rewritten on every run — a stale shim is a contradiction. The workspace .gitignore
# already covers these, which matters: the path inside is specific to one machine.
ws_shims() {
  local c t
  for c in $SHIM_CMDS; do
    t="$WS/$c"
    [[ -x "$BIN/$c" ]] || continue
    cat > "$t" 2>/dev/null <<EOF || continue
#!/usr/bin/env bash
# Written by iterable-onboard, and overwritten every run. Edit bin/$c instead.
target="$BIN/$c"
if [[ ! -x "\$target" ]]; then
  echo "The iterable-sdk plugin has moved or been updated, so this shortcut is stale." >&2
  echo "Ask your assistant to pick the onboarding back up — that rewrites this file." >&2
  exit 127
fi
exec "\$target" "\$@"
EOF
    chmod +x "$t" 2>/dev/null || true
  done
}

# Shortest form of a command that still resolves from the developer's project. Falls
# back to the real path when there is no shim — before the first ws_init, and in tests.
cmd_path() {
  [[ -x "$WS/$1" ]] && { wsp "$1"; return; }
  printf '%s' "$BIN/$1"
}

# Same, for a command that already carries an absolute path. next_action builds those
# for a caller with no working directory to speak of; a person reading a box has one,
# and the short form is the whole point of having written the shim.
cmd_display() {
  local c="$1" base
  case "$c" in
    "$BIN/"*)
      base="${c#$BIN/}"; base="${base%% *}"
      [[ -x "$WS/$base" ]] && { printf '%s%s' "$(wsp "$base")" "${c#$BIN/$base}"; return; } ;;
  esac
  printf '%s' "$c"
}

# Short display form. A path in a message should be copy-pasteable from where the
# developer actually is, and an absolute one usually isn't.
# Both forms of the current directory, because they differ: $PWD is what the shell was
# told, `pwd -P` has the symlinks resolved, and WS comes from git, which answers
# physically. On a Mac /tmp is a link to /private/tmp, so stripping only $PWD left every
# shortcut printed as a full absolute path — and that is also the symlink that once made
# a broken test pass, so it is worth only getting wrong once.
PWD_P="$(pwd -P 2>/dev/null)" || PWD_P="$PWD"

wsp() {
  local p="$WS/${1#/}"
  p="${p#$PWD/}"
  p="${p#$PWD_P/}"
  printf '%s' "$p"
}

# Same, for a path already carrying the workspace. The variables are absolute because
# the scripts open them; a person reading one wants it relative to where they stand.
wsd() { wsp "${1#$WS/}"; }

# The single reader for every file in the workspace that remembers a value.
#
# Key by key rather than with `source`, for two reasons. A file in the workspace must
# not be able to run code: these files are read after every function here is defined,
# so one `approved() { return 0; }` line would forge the consent gate. And a file must
# not outrank the caller: `PID=other bin/gates` was silently reading the remembered
# project and reporting gates about an app nobody asked about.
#
# `source` also gave up on the whole file at the first apostrophe in a pasted value,
# leaving every key below it unset — which reads as "the developer never did the
# dashboard steps" rather than as a parse error.
load_env_file() {
  [[ -f "$1" ]] || return 0
  local _k _v
  # `|| [[ -n "$_k" ]]` so a hand-edited file with no trailing newline keeps its last key.
  while IFS='=' read -r _k _v || [[ -n "$_k" ]]; do
    _k="${_k#"${_k%%[![:space:]]*}"}"; _k="${_k#export }"
    [[ "$_k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # Quoting the value is what someone does after an apostrophe broke the old reader,
    # so honour one layer of it rather than exporting the quotes as part of the key.
    [[ "$_v" == \"*\" || "$_v" == \'*\' ]] && _v="${_v:1:${#_v}-2}"
    # APPROVED is the CI form of a yes — an environment variable a pipeline sets
    # deliberately, in place of a person. Honoured from a file in the workspace it
    # becomes a yes that a file can grant, and these files record pasted values. The
    # only consent that lives on disk is the approval record, which names its project.
    [[ "$_k" == APPROVED ]] && continue
    # Defined beats cached, even when defined empty: `TARGET_DEVICE= bin/gates` is
    # how you say "forget the remembered one", and it has to mean that.
    [[ -n "${!_k+x}" ]] && continue
    export "$_k=$_v"
  done < "$1"
}

# Anything resolved from live state (the project's existing package name, app id)
# is cached here so the verifier and the actor agree on what they are talking about.
#
# Read before the cache, because load_env_file exports the remembered DRIVER and from
# then on "they told me on this run" and "a file remembers it" look the same. Either
# counts as chosen; a default does not.
DRIVER_SET="${DRIVER+1}"

load_env_file "$WS/resolved.env"

: "${PID:=}"
: "${PACKAGE:=}"
: "${SA_ID:=itbl-onboard-fcm}"
: "${APP_DISPLAY_NAME:=Iterable Onboard Test}"

# Creating a project is opt-in. A tool that runs against a customer's account
# should never invent cloud resources at that scale unless asked outright.
: "${CREATE_PROJECT:=0}"
: "${CREATE_APP:=0}"

# Who runs the Google setup: `developer` at a terminal, or `agent` in a chat. Every
# screen exists in both places now, so this is a preference and not a capability gap —
# what the terminal still has to itself is hosting the Google sign-in in its own session.
#
# `developer` remains the value an unanswered fork falls back to, because the actor must
# not be able to authorise itself: may_drive_setup reads the recorded answer, not this.
# But unanswered is not the same as answered, and a run that has not asked yet must ask
# rather than route — hence driver_chosen, which is what the recommendation follows.
: "${DRIVER:=developer}"
agent_driven() { [[ "$DRIVER" == agent ]]; }

# Whether anybody has actually answered the fork. A default is not an answer, and a
# handoff block presented as the next step when nothing has been asked is the tool
# choosing for them — which is the thing the fork exists to avoid.
driver_chosen() {
  [[ "$DRIVER_SET" == 1 ]] && return 0
  [[ -f "$WS/resolved.env" ]] && grep -q '^DRIVER=' "$WS/resolved.env"
}

# The router saying "not yours to run" was not enough: a caller that never reads
# `next` still reaches the actor, and one did. So the actor asks the same question
# and answers it from disk, in the shape the consent gate already uses.
#
# A tty is the strongest available evidence that a human is present — the wizard has
# one, a chat tool does not. Failing that, the only yes that counts is the recorded
# one, which is why this reads the file rather than $DRIVER: the environment loses
# here on purpose, so `DRIVER=agent bin/onboard --apply` cannot authorise itself.
may_drive_setup() {
  [[ -t 0 ]] && return 0
  [[ "${APPROVED:-0}" == 1 ]] && return 0
  agent_driving_recorded
}

# The record on its own, with neither the tty nor the CI shortcut folded in. "They asked
# the agent to drive" is a different question from "this is allowed to run", and what
# gets printed to the developer follows the first one: a box telling somebody to open a
# terminal, in a run they asked the agent to drive, contradicts the answer they gave.
agent_driving_recorded() {
  [[ -f "$WS/resolved.env" ]] && grep -q '^DRIVER=agent$' "$WS/resolved.env"
}

# Printed instead of doing the work. The banner is the remedy; this line is why it
# appeared in the middle of something that looked like it was about to run.
handoff_refusal() {
  handoff_banner
  printf '  %s\n' "Not run: this changes a Google project and nobody recorded a request for it to be"
  printf '  %s\n\n' "driven from a chat. That record is: $(bold "$BIN/agent set DRIVER=agent")"
}

ART="$WS/artifacts"
GS_JSON="$ART/google-services.json"
SA_KEY="$ART/sa-key.json"
FCM_ROLE="roles/firebasecloudmessaging.admin"

# The wizard picks PID mid-run, so anything derived from it has to be
# recomputable rather than fixed at source time.
refresh_derived() { SA_EMAIL="$SA_ID@$PID.iam.gserviceaccount.com"; }
refresh_derived

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
cyan()  { printf '\033[36m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

# Several gates are slow by nature — a cold emulator's first dumpsys, a service-account
# key that has not propagated yet, a logcat read that polls to a deadline. Printing
# nothing until the verdict makes slow indistinguishable from hung, and a live G13 got
# read as a frozen wizard twice before this existed.
#
# An elapsed count, not just a spinner: "it is working" is the smaller half of the
# question. Somebody watching 64s tick past on a gate knows to wait; somebody watching
# 400s knows not to.
#
# Frames in an array rather than one string, because bash 3.2 indexes substrings by byte
# and these glyphs are three bytes each.
SPIN_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)

# run_spinner <out-file> <label> <command...>
#
# Runs the command with its output collected in <out-file>, marks time on one line while
# it works, erases that line, and returns the command's status. Only draws when stdout is
# a terminal: a pipe gets byte-for-byte what it always did, which is what bin/agent and
# every test suite read.
run_spinner() {
  local f="$1" label="$2"; shift 2
  if [[ ! -t 1 ]]; then "$@" > "$f" 2>&1; return $?; fi
  "$@" > "$f" 2>&1 &
  local pid=$! i=0 start=$SECONDS el drawn=0
  while kill -0 "$pid" 2>/dev/null; do
    el=$((SECONDS - start))
    # Silent for the first couple of seconds, and the cursor is only hidden once there is
    # something to hide it for. Most gates answer inside one second, and hiding and
    # restoring the cursor on every row of a ladder is a visible flicker for no reason.
    if ((el >= 2)); then
      ((drawn)) || { printf '\033[?25l'; drawn=1; }
      printf '\r  %s  %s %s\033[K' "$(cyan "${SPIN_FRAMES[i % 10]}")" "$label" "${el}s"
    fi
    ((i++))
    sleep 0.1
  done
  ((drawn)) && printf '\r\033[K\033[?25h'
  wait "$pid"
}

# Three things have to be impossible to scroll past: what the tool is about to
# change in somebody's cloud project, what is blocking the run, and that an agent
# wrote the code. Hence a bar rather than a full box — the text inside is coloured,
# and a right-hand edge would mean measuring the printable width of a string full
# of escape sequences, which is arithmetic that goes wrong silently.
#
# 31 red is "this changes something, or something is wrong", 33 yellow is "yours to
# do", 36 cyan is "read this".
#
# 2 dim is for asides only — a footnote, a CI alternative, the detail column of a gate
# that is already green. Never for an instruction, a path somebody has to open, or a
# reason something stopped: dim is grey-on-grey in most terminal themes, and putting
# the thing they need in it is a way of not telling them.
BOX_RULE='━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
box_top() { printf '\n  \033[%sm┏%s\033[0m\n' "${1:-2}" "$BOX_RULE"; }
box_end() { printf '  \033[%sm┗%s\033[0m\n\n' "${1:-2}" "$BOX_RULE"; }
box() {
  local c="${1:-2}" l; shift
  for l in "$@"; do printf '  \033[%sm┃\033[0m %s\n' "$c" "$l"; done
}

# Prose inside a box, wrapped to the rule. A line that runs past the bar takes the
# next one with it and the block stops reading as a block — and the longest strings
# here are the ones that come from a gate's verdict, which nobody wrote to fit.
box_text() {
  local c="$1"; shift
  printf '%s\n' "$*" | fold -s -w 66 | while IFS= read -r l; do box "$c" "  $l"; done
}

interactive() { [[ -t 0 && -t 1 && "${NON_INTERACTIVE:-0}" != 1 ]]; }

plain() { sed $'s/\033\\[[0-9;]*m//g'; }

# Menu over stdin lines. Echoes the chosen line to stdout; everything a person sees
# goes to stderr, because stdout is the answer.
#
# The answer is read from /dev/tty, not stdin: stdin is the option list and the loop
# below has already drained it to EOF, so reading the choice from it would spin
# forever on an empty line.
#
# Two forms, and digits work in both, so what you can type never depends on which
# one you got. With a terminal you get a highlight and arrow keys — reading a number
# off one line to type it on another is a transcription job in the middle of a
# decision, and the number is not the thing you are choosing. Without one, or when a
# list is taller than the window, the numbered form is still there.
menu() {
  local -a opts=(); local line
  while IFS= read -r line; do opts+=("$line"); done
  ((${#opts[@]})) || return 1
  if [[ -t 2 && -r /dev/tty && "${MENU_PLAIN:-0}" != 1 ]]; then
    menu_keys "${opts[@]}"
  else
    menu_plain "${opts[@]}"
  fi
}

menu_plain() {
  local -a opts=("$@"); local i choice
  for i in "${!opts[@]}"; do printf '    %2d) %s\n' $((i+1)) "${opts[$i]}" >&2; done
  echo >&2
  while :; do
    printf '  Choose 1-%d (or q to quit): ' "${#opts[@]}" >&2
    read -r choice < /dev/tty || return 1
    [[ "$choice" == q ]] && return 1
    [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#opts[@]})) \
      && { printf '%s' "${opts[$((choice-1))]}"; return 0; }
    echo "  Not a valid choice." >&2
  done
}

MENU_HINT="↑↓ move · enter choose · q cancel"

# Globals rather than parameters: _menu_draw is called from the key loop, and the
# alternative in bash 3.2 is re-defining a closure on every keystroke.
_menu_draw() {
  local i
  for ((i = _MTOP; i < _MTOP + _MVIS; i++)); do
    if ((i == _MCUR)); then
      printf '  \033[1;36m❯ %s\033[0m\033[K\n' "${_MOPTS[$i]}" >&2
    else
      printf '    %s\033[K\n' "${_MOPTS[$i]}" >&2
    fi
  done
  local where=""
  ((_MVIS < _MN)) && where="  ·  $((_MTOP + 1))-$((_MTOP + _MVIS)) of $_MN"
  printf '  \033[2m%s\033[0m\033[K\n' "$MENU_HINT${_MBUF:+ · $_MBUF}$where" >&2
}

menu_keys() {
  _MOPTS=("$@"); _MN=$#; _MCUR=0; _MTOP=0; _MBUF=""
  local key rest rows

  # A list taller than the window cannot be redrawn in place — the top has scrolled
  # off and the cursor-up lands somewhere else entirely. So the view is a window that
  # follows the highlight, which also keeps the redraw height constant.
  rows="$(tput lines 2>/dev/null)"
  [[ "$rows" =~ ^[0-9]+$ ]] || rows=24
  _MVIS=$((rows - 4)); ((_MVIS < 3)) && _MVIS=3
  ((_MVIS > _MN)) && _MVIS=$_MN

  printf '\033[?25l' >&2
  _menu_draw
  while :; do
    IFS= read -rsn1 key < /dev/tty || { printf '\033[?25h' >&2; return 1; }
    case "$key" in
      # Empty is Enter: read -n1 returns nothing for its delimiter. A bare CR is
      # accepted too, for a terminal that does not translate it.
      ''|$'\r') printf '\033[?25h\033[1A\033[K' >&2; printf '%s' "${_MOPTS[$_MCUR]}"; return 0 ;;
      $'\033')
        # Esc is also the first byte of every arrow key, and bash 3.2 has no
        # sub-second read timeout — one second is the shortest wait available. Which
        # is why q is the cancel key this advertises; Esc works, it just costs a beat.
        read -rsn2 -t 1 rest < /dev/tty
        case "$rest" in
          '[A') _MBUF=""; ((_MCUR = (_MCUR + _MN - 1) % _MN)) ;;
          '[B') _MBUF=""; ((_MCUR = (_MCUR + 1) % _MN)) ;;
          '')   printf '\033[?25h' >&2; return 1 ;;
        esac ;;
      k) _MBUF=""; ((_MCUR = (_MCUR + _MN - 1) % _MN)) ;;
      j) _MBUF=""; ((_MCUR = (_MCUR + 1) % _MN)) ;;
      q) printf '\033[?25h' >&2; return 1 ;;
      [0-9])
        # A typed number moves the highlight instead of selecting outright, so a list
        # with ten or more entries is not a race against the first keystroke: 1 then 2
        # reaches 12, and on a shorter list falls back to meaning 2.
        _MBUF="$_MBUF$key"
        ((10#$_MBUF >= 1 && 10#$_MBUF <= _MN)) || _MBUF="$key"
        ((10#$_MBUF >= 1 && 10#$_MBUF <= _MN)) && _MCUR=$((10#$_MBUF - 1)) || _MBUF="" ;;
    esac
    ((_MCUR < _MTOP)) && _MTOP=$_MCUR
    ((_MCUR >= _MTOP + _MVIS)) && _MTOP=$((_MCUR - _MVIS + 1))
    printf '\033[%dA' $((_MVIS + 1)) >&2
    _menu_draw
  done
}

# One JSON string, escaped. Written in awk rather than node because bin/agent has
# to be able to report that node is missing, and it cannot do that in JSON if
# serialising needs node.
jstr() {
  printf '%s' "${1-}" | LC_ALL=C awk '
    BEGIN { RS = "\1"; ORS = ""; printed = 0 }
    {
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\"")
      gsub(/\n/, "\\n"); gsub(/\t/, "\\t"); gsub(/\r/, "\\r")
      gsub(/\033/, "\\u001b")
      printf "\"%s\"", $0; printed = 1
    }
    END { if (!printed) printf "\"\"" }'
}

# The binaries the ladder needs, and which of them are absent. Shared by G0 and by
# bin/agent, so "what this machine cannot check" has one answer.
#
# An array, not a space-separated string, because splitting a string needs IFS and
# a caller is entitled to have changed it — `IFS=$'\t' read … <<< "$(next_action)"`
# runs this function with tabs as the only separator, and the string form then
# looked for one binary called "node gcloud adb java" and reported all four missing.
REQUIRED_TOOLS=(node gcloud adb java)
missing_tools() {
  local c
  for c in "${REQUIRED_TOOLS[@]}"; do command -v "$c" >/dev/null || echo "$c"; done
}

# Collapse a tool's multi-line diagnostic to one useful line. gcloud's reauth error
# is 12 lines; repeating it once per gate buries the actual ask.
#
# One line per gate is what makes the ladder readable as a table, so long verdicts
# still get cut — but on a word boundary and with an ellipsis. A bare `cut -c1-100`
# ended a remedy mid-word ("if the app signs in as a different addres"), which
# reads like the whole verdict and quietly loses the half that says what to do.
# Tabs go too, not only newlines: state.tsv is tab-separated and a gcloud message
# containing a tab would split into a column that nothing reads.
brief() {
  tr '\n\t' '  ' | sed 's/ERROR: ([^)]*) //; s/  */ /g' \
    | awk '{ sub(/[ \t]+$/, ""); if (length($0) > 100) { s = substr($0, 1, 99); sub(/ [^ ]*$/, "", s); print s "…" } else print }'
}

# Did a push actually arrive? The one question the whole tool answers, and the
# front ends must not answer it from the exit code alone: rc 40 says something is
# pending, which is true both before and after G16 goes green.
push_proven() { grep -q "^G16	green" "$WS/state.tsv" 2>/dev/null; }

# What a human has to do about the gates that are merely pending, one line each,
# read out of state.tsv rather than guessed. Shared by both front ends: they were
# drifting on this, and advice that disagrees with itself teaches nobody anything.
# Plain text, no escapes, so the same sentence can go to a terminal or into JSON.
advice_for() {
  case "$1" in
    # Four dashboard steps, and the advice names the first one rather than all four:
    # this is the one stretch of the flow the developer does by hand, and a wall of
    # instructions is read as a document instead of followed as steps.
    G10) echo "do the four Iterable dashboard steps, one at a time, starting with step 1" ;;
    G13) echo "run the app on the device, and accept the notification prompt" ;;
    # Three reasons the token never registered, three different things to do. Launching
    # the app again achieves nothing while it has no key to register with, and it
    # achieves nothing either when the app has run and never said who the user is —
    # which is the one the verdict can actually see, so read it rather than guess.
    G14) if [[ -z "$ITBL_MOBILE_KEY" ]]; then
           echo "finish the Iterable steps first — the app needs a mobile key before it can register anything"
         elif [[ "$(gate_detail G14)" == *"never called registerDeviceToken"* ]]; then
           echo "identify a user in the app — IterableApi.getInstance().setEmail(\"${ITBL_EMAIL:-your test user}\") — then relaunch it; the SDK registers no token until it knows who it is for"
         else
           echo "launch the app, so the SDK registers a token"
         fi ;;
    # Naming the address is the point. This is the join key between the app and
    # Iterable, and a test user who signs in as anyone else looks exactly like a
    # broken integration from here.
    G15) echo "sign in to the app as ${ITBL_EMAIL:-your test user} — that exact address, or no token is ever filed under it" ;;
    G16) echo "send the proof push" ;;
    G17) echo "set ITBL_CAMPAIGN_ID and send through a campaign, for server-side corroboration" ;;
  esac
}

# A command, on its own line, with a path that resolves from where the developer is
# standing. Every "run bin/onboard again" in this tool was written when it was a repo
# you cd'd into, where that was true. Installed as a plugin and run from somebody's
# own project, it is a command that does not exist — and somebody typed one and got
# `zsh: no such file or directory`, which is the tool's fault and not theirs.
run_line() { local c="$1"; shift; printf '      %s\n' "$(bold "$(cmd_path "$c")${*:+ $*}")"; }

# The whole job is three parts, and each one says which it is as it starts.
#
# Eighteen gate rows is a lot of screen, and somebody who cannot see which third of the
# job they are in reads every unfinished row as a problem. Which is what happened: the
# Google part finished, the ladder printed the Iterable and device rows as not-done, and
# that read as something having gone wrong — when in fact nothing had gone wrong and the
# next part simply had not started.
#
# Parts, not steps, because parts 2 and 3 contain numbered steps of their own. Two
# depths of "step 3" on one screen is worse than no numbering at all.
part_map() {
  cat <<EOF

  $(bold "Three parts, in this order:")

    1  Google      the project, a push-only service account, its key
    2  Iterable    four steps in the dashboard, in your browser
    3  Device      run your app until a real push lands on it

  Part 1 is mine. Parts 2 and 3 are yours — I walk you through every step and
  check what it produced, so nothing here is taken on trust.

EOF
}

part() {
  local label="Part $1 of 3 · $2" pad
  pad=$(( 64 - ${#label} )); ((pad < 3)) && pad=3
  echo
  printf '  ── %s %s\n' "$(bold "$label")" "$(printf '─%.0s' $(seq 1 $pad))"
}

pending_advice() { # [gate to leave out — the one already named above it]
  local id status owner name detail
  [[ -f "$WS/state.tsv" ]] || return 0
  while IFS=$'\t' read -r id status owner name detail; do
    [[ "$status" == pending ]] || continue
    [[ -n "${1:-}" && "$id" == "$1" ]] && continue
    advice_for "$id"
  done < "$WS/state.tsv"
}

# The whole rc 40 ending, in one place because it had drifted into three. The wizard's
# copy printed the list and no box, which left the only command on the screen a
# relative path — from the developer's own project, the one directory where bin/… does
# not resolve. The box exists to carry a path that does.
#
# One thing to do, then what waits behind it. Never the same item twice: printed in
# the box and again in the list, the second copy reads as a second task.
pending_tail() {
  local owner kind gate cmd summary rest
  IFS="$NEXT_SEP" read -r owner kind gate cmd summary <<< "$(next_action)"
  if push_proven; then
    echo "  $(bold "A push arrived — and something above is still pending.")"
  else
    echo "  $(bold "Nothing is broken — and no push has been proven yet.")"
  fi
  blocker_banner
  # Unbolded, but not dim: bold is the tool saying "type this" and nothing in this list
  # is due yet, so it has to read as quieter than the box — and grey is how you make
  # text nobody reads, which is no way to print the rest of somebody's work.
  rest="$(pending_advice "$gate" | plain)"
  if [[ -n "$rest" ]]; then
    echo "  Waiting behind it:"
    while IFS= read -r l; do printf '      %s\n' "$l"; done <<< "$rest"
    echo
  fi
  # Said rather than asked, and only while it is still the answer to something: the
  # file is unexplained otherwise, and "what is sa-key.json for" arrives at step 3.
  if [[ -f "$SA_KEY" && "$(gate_status G10)" != green ]]; then
    echo "  Keep $(bold "$(wsp artifacts/sa-key.json)") — the Iterable push integration step uploads it."
    echo
  fi
  echo "  When that is done, run this again — nothing already green gets redone:"
  echo
  run_line onboard
  echo
}

# Part 2, offered rather than assumed — and this is the fix for the worst ending this
# tool had. The Google part finished, the device gates had no mobile key to look for, and
# the run ended by sending the developer off to re-run the whole thing. Nothing about
# that could clear anything: nobody had been walked through Iterable yet, and the four
# steps are in a browser — Iterable has no endpoint that creates an API key, a mobile
# app, or a push integration. So it gets asked here, in the one place where the person
# who has to do the clicking is already holding the terminal.
#
# Lives here rather than in bin/wizard so tests/iterable-part.exp can drive all three
# answers against a fixture state.tsv, with no Google project and no device.
#
# 0 = the walk ran, and the ladder's verdict is in ITBL_WALK_RC. 1 = nothing to offer.
# 2 = they chose to hand back instead.
iterable_part() {
  [[ "$(gate_status G10)" == green ]] && return 1
  interactive || return 1
  part 2 "Iterable"
  cat <<EOF

  Part 1 is done and verified: the service-account key exists, and FCM
  accepted it.

  Part 2 is four steps in the Iterable dashboard. Nothing out here can do
  them for you — Iterable has no API for creating an API key, a mobile app,
  or a push integration. Until they are done your app has no mobile key, so
  the device checks have nothing to find. That is all the rows above are
  saying, and none of it is a fault in your app or in what you just did.

  About five minutes. Every step gets checked by spending what it produced.

EOF
  local pick
  pick="$(printf '%s\n' \
    "Walk me through the four Iterable steps now" \
    "Stop here — leave my assistant the state so far" | menu)" || pick=""
  case "$pick" in
    # Quiet for the same reason provision is: it ends by exec'ing the verifier, and the
    # endings below print the verdict themselves. Without it the developer gets two.
    Walk*) ITBL_INTRO_SHOWN=1 QUIET_VERDICT=1 "$BIN/iterable-keys"; ITBL_WALK_RC=$?; return 0 ;;
    *) return 2 ;;
  esac
}

# Two audiences, and they want different sentences. Everything above this is written to
# the developer holding the terminal; this is written to whatever sent them here, and it
# is last on purpose — the instruction comes first, the handback after it.
#
# It used to ask the developer to relay the outcome ("go back and tell it you are
# done"), which made a person the transport for a fact already on disk. It isn't one:
# the run either finished or it didn't, and state.tsv says what came of it. So this
# states it instead, in the second person, because an agent reading the terminal is
# the reader being addressed.
agent_handback() {
  local owner kind gate cmd summary name
  printf '\n  %s\n' "$(dim "── for the assistant that sent me here ──")"
  # Stopped before anything was checked — at the project picker, or on a Ctrl-C out of
  # the sign-in. Pointing at state.tsv here would hand over either nothing or, worse,
  # whatever a previous run left in it.
  if [[ ! -f "$WS/state.tsv" ]]; then
    printf '  %s\n\n' "This terminal run ended before any gate was checked. Nothing changed."
    return 0
  fi
  # Through next_action like every other ending, so the gate it names can never be a
  # different one from the gate the box above it named.
  IFS="$NEXT_SEP" read -r owner kind gate cmd summary <<< "$(next_action)"
  name="$(gate_name "$gate")"
  printf '  %s\n' "This terminal run is over. Read $(bold "$(wsp state.tsv)") for the result —"
  printf '  %s\n' "nothing above needs relaying, and nothing needs retyping."
  [[ -n "$name" ]] && printf '  %s\n' "First gate still open: $(bold "$name")${gate:+ ($gate)}."
  echo
}

# One row of the ladder, by column. The front ends need a gate's name and status
# far more often than they need to parse the whole file, and every one of them was
# writing its own awk for it.
gate_field()  { awk -F'\t' -v i="$1" -v c="$2" '$1==i{print $c; exit}' "$WS/state.tsv" 2>/dev/null; }
gate_status() { gate_field "$1" 2; }
gate_name()   { gate_field "$1" 4; }
gate_detail() { gate_field "$1" 5; }

# Tells a repair from a first run without asking anybody's cloud project: once the tool
# has produced these, a red gate downstream of them is something that broke rather than
# something nobody has done yet. On a first run the same gate says "not created yet",
# and shouting SOMETHING IS WRONG at that is how a tool teaches a developer to stop
# believing the word.
setup_started() { [[ -f "$SA_KEY" || -f "$GS_JSON" ]]; }

# How far the run has got, in the numbers the developer has been watching go by. A box
# that asks for a yes has to say what it is interrupting: "the next part" means nothing
# without the part before it. Read off the ladder that just ran, so it cannot claim
# progress the gates did not find. rc 1 when nothing has run yet.
progress_line() {
  local green total
  [[ -f "$WS/state.tsv" ]] || return 1
  green="$(awk -F'\t' 'NF>1 && $2=="green"{n++} END{print n+0}' "$WS/state.tsv")"
  total="$(awk -F'\t' 'NF>1{n++} END{print n+0}' "$WS/state.tsv")"
  ((total > 0)) || return 1
  printf '%s of %s checks pass so far.' "$green" "$total"
}

# Said in the tool's own voice, because on the path we ship there is nobody else to
# say it: the developer is talking to an agent, and an agent assuring you that its
# own output is trustworthy is not worth much. Not written as a legal disclaimer —
# the useful version tells them which half of what they are looking at is evidence
# and which half is a draft.
# One line per paragraph, unwrapped: the banner wraps it to whatever width it has,
# and an agent relaying it into a chat window reflows it anyway. Pre-wrapped text
# came out ragged in both.
#
# Short on purpose. It was three paragraphs, printed at the top of every run and again
# at the end — long enough that it became the thing you scroll past to reach the part
# you needed, which is the opposite of what a warning is for. Two sentences survive
# being read every time; an essay only survives the first.
ai_notice() {
  cat <<'EOF'
An AI agent wrote the code this puts in your repository, and it can be wrong in ways that still compile. Only the push proof is evidence; the rest is a draft — review it like a pull request from somebody new.
EOF
}

ai_notice_banner() {
  box_top 36
  # Generic heading on purpose: ai_notice() also goes out as bin/agent's `notice` field,
  # where it stands alone, so the sentence has to name its own subject — and then a
  # heading that named it too was the same words twice in a five-line box.
  box 36 "$(bold "READ THIS BEFORE YOU SHIP IT")"
  ai_notice | while IFS= read -r l; do box_text 36 "$l"; done
  box_end 36
}

# ------------------------------------------------------------------- approval
#
# Provisioning changes somebody else's cloud project, so the yes has to be one the
# tool can check rather than one the agent remembers giving. An agent that skips the
# question is stopped here instead of in prose.
#
# Recorded against the project, because approving work in one project says nothing
# about the next: a remembered yes that outlives its target is how the wrong project
# gets modified. APPROVED=1 is the CI form of the same answer.
APPROVALS="$WS/approved"

# Whose credentials are about to be spent. Also what the `list` approval is scoped to,
# so switching accounts does not inherit the previous one's yes.
gcloud_account() { gcloud config get-value account 2>/dev/null | grep -v '^(unset)$'; }

# Three things get approved, separately, because they are different sizes. `firebase` is
# the provisioning plan — a service account, a role binding, a key. `create-app`
# registers a new Android app in the project, which the limits promise never happens
# "unless you ask outright", so it cannot ride along on the first yes. `list` is the read
# of the account's whole Firebase estate, which changes nothing and is still not free.
#
# `list` is scoped to the Google account and the other two to the project, because that
# is what each one is actually about: a yes to looking at what this account can see says
# nothing about the next account, and there is no project chosen yet when it is asked.
approval_scope() {
  case "${1:-firebase}" in
    list) printf 'list %s' "$(gcloud_account)" ;;
    *)    printf '%s %s' "${1:-firebase}" "${PID:-<no project chosen>}" ;;
  esac
}

# What the scope needs named before a yes can be recorded against it. An approval that
# names neither a project nor an account covers everything, which is the one thing it
# must never do — and a blank from a gcloud that cannot answer would match a blank on
# disk, so an unknown account is a refusal rather than a wildcard.
scope_target() {
  case "${1:-firebase}" in
    list) gcloud_account ;;
    *)    printf '%s' "$PID" ;;
  esac
}

approved() {
  # The CI form covers provisioning and the read. Registering an app is the one change a
  # pipeline should have to name for itself, with CREATE_APP=1.
  case "${1:-firebase}" in
    firebase|list) [[ "${APPROVED:-0}" == 1 ]] && return 0 ;;
  esac
  [[ -n "$(scope_target "${1:-firebase}")" ]] || return 1
  awk -F'\t' -v s="$(approval_scope "${1:-firebase}")" '$1==s{found=1} END{exit !found}' "$APPROVALS" 2>/dev/null
}

approve() {
  [[ -n "$(scope_target "${1:-firebase}")" ]] || return 1
  ws_init || return 1
  approved "${1:-firebase}" \
    || printf '%s\t%s\n' "$(approval_scope "${1:-firebase}")" "$(date '+%Y-%m-%d %H:%M')" >> "$APPROVALS"
}

# Reading somebody's whole Firebase estate spends their Google credentials and prints
# every project name, id and package they own into whatever is listening. Nothing is
# mutated, and that is exactly why it kept happening: an agent that finds gcloud already
# authenticated reads "authenticated" as "allowed" and lists. Three live transcripts now
# show the listing running before anybody was asked, while the screen that asks —
# `agent question choose_target` — existed the whole time and was skipped.
#
# So the refusal moves here, where not reading the prose cannot get past it. Same shape
# as may_drive_setup: a tty is a human present, APPROVED=1 is the CI form, and otherwise
# the only yes that counts is one recorded on disk.
may_list_projects() {
  [[ -t 0 ]] && return 0
  approved list
}

# ------------------------------------------------- proving the screen was put up
#
# `approved list` answers whether a yes is on disk and nothing about who put it there. In
# a chat the agent is the only thing typing, so no local check can tell "they chose this"
# from "it chose for them" — a tty is the only hard evidence a human is present, which is
# why that exemption exists and why this is not sold as a lock.
#
# What it does close are the two accidental paths, which are the ones that actually
# happened: recording a yes for a screen that was never generated, and generating the
# screen and answering it in the same breath. The question mints a one-time token and
# writes down when; the answer has to carry that token, and has to arrive at least
# ASK_DWELL_MS after the screen existed. An agent that renders the screen, keeps the token
# and waits is forging consent, and this will not catch it.
ASKED="$WS/asked"

# 200ms. Below this nobody has read anything — an agent chaining two commands does it in
# tens of milliseconds. Above it is a human who knows what they are clicking and clicks
# fast, and refusing them would be the tool calling a real answer fake. Not overridable
# from the environment on purpose: a caller that can widen the window has no window.
ASK_DWELL_MS=200

# Wall clock in milliseconds. `date +%N` is GNU-only and this floors at macOS bash 3.2, so
# it needs help — and which helper matters, because the reading is taken *inside* the
# process and its startup lands in the span being measured. Measured on this machine:
# node 64ms a call, perl 19ms, nothing at all for bash 5's own variable. A 200ms window
# cannot survive a 64ms ruler, so the cheapest source wins and node is the last resort.
now_ms() {
  local ms s f
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    s="${EPOCHREALTIME%%[.,]*}"; f="${EPOCHREALTIME#*[.,]}000"
    printf '%s' "$(( s * 1000 + 10#${f:0:3} ))"; return 0
  fi
  ms="$(perl -MTime::HiRes -e 'printf "%d", Time::HiRes::time()*1000' 2>/dev/null)"
  [[ "$ms" =~ ^[0-9]+$ ]] && { printf '%s' "$ms"; return 0; }
  ms="$(node -e 'process.stdout.write(String(Date.now()))' 2>/dev/null)"
  [[ "$ms" =~ ^[0-9]+$ ]] && { printf '%s' "$ms"; return 0; }
  return 1
}

# The token for a screen, minted on first render and kept afterwards. Kept rather than
# re-minted because the same screen gets rendered again by every status read, and a token
# that changed underneath the developer would refuse the answer they just gave.
#
# The clock starts unset here and is set by ask_stamp once the screen has actually been
# emitted. Two reasons. Rendering the rest of this question costs ~160ms, so a timestamp
# taken mid-render hands a third of the window back to whatever it was meant to catch. And
# only the *first* emission counts: refreshing it on every re-render would refuse a yes
# that happened to arrive just after some unrelated re-read of the ladder.
ask_for() { # <kind> — echoes the token, empty if the workspace will not take one
  local t
  if [[ -f "$ASKED/$1" ]]; then cut -f1 "$ASKED/$1"; return 0; fi
  ws_init 2>/dev/null || return 1
  command mkdir -p "$ASKED" 2>/dev/null || return 1
  t="$(head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n')"
  [[ "$t" =~ ^[0-9a-f]{32}$ ]] || return 1
  printf '%s\t0\n' "$t" > "$ASKED/$1" 2>/dev/null || return 1
  printf '%s' "$t"
}

# The screen is up as of now — called once the JSON carrying it has been written out, by
# whoever wrote it. A no-op after the first time, and a no-op when nothing was minted.
ask_stamp() { # <kind>
  local tok minted
  [[ -f "$ASKED/$1" ]] || return 0
  IFS=$'\t' read -r tok minted < "$ASKED/$1"
  [[ "$minted" == 0 ]] || return 0
  printf '%s\t%s\n' "$tok" "$(now_ms || echo 0)" > "$ASKED/$1" 2>/dev/null || return 0
}

# 0 = this answer came from a screen that existed and had time to be read; the token is
# spent either way it succeeds, so one rendering buys one yes. Echoes the reason on a
# refusal, in words that name the question and never the way around it.
ask_spent() { # <kind> <token> [now-in-ms]
  local tok minted now el
  now="${3:-}"
  [[ -f "$ASKED/$1" ]] || {
    printf '%s' "no screen for this has been put up, so there is no answer to record yet — ask $(cmd_path agent) question $1 and let them choose from it"
    return 1; }
  IFS=$'\t' read -r tok minted < "$ASKED/$1"
  [[ -n "${2:-}" && "$2" == "$tok" ]] || {
    printf '%s' "that is not the token the screen carried, so this is answering a question that is no longer on screen — re-ask $(cmd_path agent) question $1"
    return 1; }
  # The caller passes the clock reading it took on entry, because anything this function
  # does first lands inside the measurement — and `gcloud config get-value account`, which
  # the approval needs before it gets here, costs a few hundred milliseconds on its own.
  # Measured from the wrong place, the dwell passes a chained call every time.
  #
  # Skipped rather than failed when the clock is unreadable: the token is the part that
  # can always be checked, and a tool that cannot tell the time should not start calling
  # real answers fake.
  [[ "$now" =~ ^[0-9]+$ ]] || now="$(now_ms)" || now=""
  if [[ "$now" =~ ^[0-9]+$ ]] && [[ "$minted" =~ ^[0-9]+$ ]] && ((minted > 0)); then
    el=$((now - minted))
    ((el >= ASK_DWELL_MS)) || {
      printf '%s' "that yes arrived ${el}ms after the screen was generated, which is faster than anybody could have read it — put the question to them and record what they pick"
      return 1; }
  fi
  rm -f "$ASKED/$1"
}

# Printed instead of the listing. Names the question rather than the command that records
# its answer, on purpose: the remedy for a missing yes is asking, and an agent that is
# handed `approve list` at the moment of being blocked will take it.
list_refusal() {
  printf '  %s\n' "Not read: nobody has said yes to listing this account's Firebase projects."
  printf '  %s\n' "It is a question, and it has a screen — ask it and run what the answer carries:"
  printf '\n      %s\n\n' "$(bold "$BIN/agent question choose_target")"
  printf '  %s\n\n' "Do not record the answer yourself. Finding gcloud signed in is not consent."
}

# An app may be registered if the environment said so outright, or if the developer
# answered the question that asks. Recorded against the project like every other yes,
# so it cannot be spent on the next one.
may_create_app() { [[ "$CREATE_APP" == 1 ]] || approved create-app; }

# What provisioning would change, read out of the ladder rather than written out by
# hand in each front end. A consent banner that lists something the run will not do,
# or leaves out something it will, is worse than no banner at all — and there were
# three hand-maintained copies of this list before it lived here.
firebase_plan() {
  local id status owner name detail todo=""
  # Nothing is planned against a project nobody has chosen, and a list that names no
  # project reads as a list of things about to happen to an unknown one.
  [[ -n "$PID" ]] || return 0
  # Unconditional, because provision enables these every run and a banner that only
  # mentions gate-shaped work would understate what it touches.
  echo "enable   the Firebase, IAM and FCM APIs, if they are not on already"
  if [[ -f "$WS/state.tsv" ]]; then
    while IFS=$'\t' read -r id status owner name detail; do
      [[ "$status" == green ]] && continue
      todo="$todo $id"
    done < "$WS/state.tsv"
  else
    # No ladder has run, so nothing is known to be done already — and a consent
    # banner that understates the work because it has no state to read is worse than
    # one that overstates it. Assume all of it.
    todo="G3 G4 G5 G6 G7 G8 G9"
  fi
  for id in $todo; do
    case "$id" in
      G3) echo "add      Firebase to the project" ;;
      G4) echo "register $PACKAGE as an Android app — asked separately, and no is an answer" ;;
      G5) echo "download google-services.json — a config file, not a secret" ;;
      G6) echo "create   a service account, '$SA_ID'" ;;
      # Two lines, because the role name is the evidence for the claim and neither
      # half fits on one line of a banner with the other.
      G7) echo "grant    it one role: $FCM_ROLE"
          echo "         which can send push and do nothing else" ;;
      G8) echo "create   a JSON key for it, mode 0600, at" 
          echo "         $(wsp artifacts/sa-key.json)" ;;
      G9) echo "verify   the key by asking FCM to validate a send (nothing sent)" ;;
    esac
  done
}

# The boundary half of an honest ask, pulled out of the banner so the agent's question
# can carry the same three lines. A front end that lists the changes and then writes its
# own limits is the one that promises something no script here honours.
firebase_limits() {
  cat <<'EOF'
touch an app, integration or credential you already have
create a Firebase project, or register an app, unless you ask outright
ask for, store or type a password — you sign in yourself
EOF
}

# A plan line that starts with spaces continues the one above it. Bulleting it makes
# one change look like two, the second with no verb — so the marker goes on the first
# line only and the continuation keeps its alignment.
plan_bulleted() {
  local l
  while IFS= read -r l; do
    case "$l" in ' '*) printf '  %s\n' "$l" ;; *) printf '· %s\n' "$l" ;; esac
  done
}

# firebase_consent_banner [prompt]
#
# The same list of changes either way; only the way to say yes differs, because a
# wizard asks on the next line and an agent has to record an answer. Hard-coding one
# of them meant whichever front end lost the coin toss told the developer to run a
# command that does not apply to them.
firebase_consent_banner() {
  local how="${1:-command}"
  box_top 31
  box 31 "$(bold "APPROVAL NEEDED — this changes your Google Cloud project")" ""
  box 31 "  project   ${PID:-<none chosen yet>}" "  package   ${PACKAGE:-<none chosen yet>}" ""
  box 31 "$(bold "  What it would do")"
  firebase_plan | plan_bulleted | while IFS= read -r l; do box 31 "    $l"; done
  box 31 "" "$(bold "  What it will not do")"
  firebase_limits | while IFS= read -r l; do box 31 "    · $l"; done
  box 31 ""
  if [[ "$how" == prompt ]]; then
    box 31 "$(bold "  Answer below.") Nothing has happened yet, and no is a complete answer."
  else
    box 31 "$(bold "  Yes")  $BIN/agent approve firebase" \
           "$(dim "        or APPROVED=1 in the environment, for CI")" \
           "$(bold "  No")   change nothing and walk away. Nothing has happened yet."
  fi
  box 31 "" "  The JSON key it creates is a long-lived credential until you delete it." \
         "  Undo everything it adds, whenever you like:" \
         "  $(bold "$BIN/teardown")"
  box_end 31
}

# The block that sends a developer to their own terminal, printed once they have asked for
# it. What that path does that a chat cannot: it hosts the Google sign-in in the same
# session rather than relaying it, and it takes the Iterable keys off a prompt with the echo
# off rather than off the clipboard. Everything else on it exists as a screen here too,
# which is why this is a fallback and not the recommendation.
#
# Printed by the tool rather than composed by whoever relays it, because the part that
# goes missing in a paraphrase is the last line — and a developer holding a finished
# terminal and no next step is exactly what this is for.
# handoff_banner [failing gate] [its verdict]
#
# With a verdict it is a repair: the problem goes first, because a box that opens with
# "signs you in to Google" above a rejected credential describes the wrong job, and a
# developer who reads the remedy before the diagnosis has no way to tell whether the tool
# understood what went wrong. Without one it is a first run, and there is nothing to state.
handoff_banner() {
  local proj prog gate="${1:-}" why="${2:-}" colour=36
  proj="$(git rev-parse --show-toplevel 2>/dev/null)" || proj="$PWD"
  [[ -n "$why" ]] && colour=31
  box_top "$colour"
  if [[ -n "$why" ]]; then
    box "$colour" "$(bold "SOMETHING NEEDS FIXING — and it is in your terminal, not here")" ""
    [[ -n "$gate" ]] && box "$colour" "  $(bold "$gate")"
    box_text "$colour" "$why"
    box "$colour" ""
  else
    # Not an order. The developer is reading this through an agent that already has the
    # next step — kind, command and question, on every read — so the instruction is the
    # one thing this box does not need to supply. What it supplies is where the run got
    # to and whose turn the next part is, which is the only thing the relay cannot
    # reconstruct. It opened with "RUN THIS IN YOUR TERMINAL — then come back here"
    # until 2026-09-24, and shown mid-conversation that reads as the tool taking the
    # keyboard off both of them.
    box "$colour" "$(bold "THIS PART IS YOURS TO RUN — one command, and it asks you the rest")" ""
    prog="$(progress_line)" && box "$colour" "  $prog" ""
  fi
  # The command is relative now, so the directory is part of it rather than a footnote.
  # Not folded: wrapping a path mid-string reads worse than letting one dim line run
  # past the bar, which is why the bar has no right-hand edge in the first place.
  box "$colour" "      $(bold "$(cmd_path onboard)")" \
                "      run from $proj" ""
  # One list for both cases, not two that can drift apart. The last line is what makes it
  # true of a repair as well: the same command, and it leaves alone whatever still works.
  box "$colour" "$(bold "  What it does")" \
                "    · signs you in to Google, in your own browser" \
                "    · lets you pick the Firebase project and the Android app —" \
                "      and offers to register the app if the project has none" \
                "    · shows you every change it would make before making any," \
                "      and stops if you say no" \
                "    · walks the Iterable dashboard steps one at a time, and takes" \
                "      the two API keys with the terminal echo off" \
                "    · picks the device by name, and proves it with a real push" \
                "    · skips whatever already works — only what is not done gets touched" ""
  box "$colour" "$(bold "  When it finishes") — or if it stops and you are not sure why —" \
                "  come back here and say so, and I will carry on from there." \
                "  Nothing to copy: the result is in $(wsp "" | sed 's:/$::') and I read it from there."
  box_end "$colour"
}

# Printed on the agent path, where this text is what the developer is most likely to be
# shown verbatim — so it is written to a reader who is not holding a terminal and did not
# ask for one. The agent relaying it already knows the next step; it has the kind, the
# command and the question from the same read that produced this. So this box is not here
# to instruct anybody. It is here to tell the developer where the run stopped and what
# they are being asked to allow next, because that is the part a relay cannot reconstruct
# and the part a "run this" heading crowds out.
#
# handoff_banner is the wrong box here twice over: it is a page of instructions for one of
# the two answers, and shown before either was chosen it is read as the answer. The
# terminal line stays, last and in one line, because it has to remain reachable in one
# step — it is an answer, not the ask.
next_part_banner() { # [gate name] [its verdict]
  local colour=36 prog
  box_top "$colour"
  box "$colour" "$(bold "WHERE THIS RUN HAS GOT TO — and what the next part needs")" ""
  prog="$(progress_line)" && box "$colour" "  $prog" ""
  if [[ -n "${1:-}" ]]; then
    box "$colour" "  Next: $(bold "$1")"
    [[ -n "${2:-}" ]] && box_text "$colour" "$2"
    box "$colour" ""
  fi
  box "$colour" \
    "$(bold "  I can do this part from here") — one question at a time, answered" \
    "  by picking one. You see every change before it is made, and no is a" \
    "  complete answer to any of them." \
    "" \
    "  Say go and I carry on from here. Nothing changes until you do." \
    "" \
    "  $(bold "Or run it yourself") — the same questions, as a terminal menu:" \
    "      $(bold "$(cmd_path onboard)")"
  box_end "$colour"
}

# The one thing stopping the run, printed where nobody can scroll past it. Which
# gate that is has already been decided by next_action — this is only how it looks,
# so the styling can never disagree with the routing.
blocker_banner() {
  local owner kind gate cmd summary name colour label
  IFS="$NEXT_SEP" read -r owner kind gate cmd summary <<< "$(next_action)"
  [[ "$kind" == done ]] && return 0
  [[ "$kind" == approve_firebase ]] && { firebase_consent_banner; return 0; }
  if [[ "$kind" == run_in_terminal ]]; then
    if setup_started; then handoff_banner "$(gate_name "$gate")" "$(gate_detail "$gate")"
    else handoff_banner; fi
    return 0
  fi
  # Unanswered, so which box depends on who is reading. At a terminal the fork is already
  # settled by where they are standing — the wizard is what "do it here" means — and
  # offering a chat to somebody mid-command is a question they cannot answer. Without a
  # tty this is going through an agent, and a page about the terminal is not the ask.
  if [[ "$kind" == choose_driver ]]; then
    if [[ -t 0 ]]; then
      if setup_started; then handoff_banner "$(gate_name "$gate")" "$(gate_detail "$gate")"
      else handoff_banner; fi
    else
      next_part_banner "$(gate_name "$gate")" "$(gate_detail "$gate")"
    fi
    return 0
  fi
  name="$(gate_name "$gate")"
  # The kind says whether anything is wrong; the owner says whose turn it is. Not the
  # gate's status: a red "service account: not created yet" is the tool's ordinary
  # next job, and labelling it BROKEN — or shouting it at somebody who has simply not
  # plugged a phone in — teaches a developer to stop believing the word.
  case "$kind" in
    investigate|project_unreachable)
      colour=31; label="SOMETHING IS ACTUALLY WRONG — a defect, not pending work" ;;
    *)
      colour=33
      # Shipping a command is the difference between "you are on your own here" and
      # "you drive, it narrates". Said the first way above a command the tool provides
      # — the four Iterable steps, say — it reads as the tool disowning its own walk.
      if [[ "$owner" != human ]]; then label="THE TOOL CAN DO THIS — one command away"
      elif [[ -n "$cmd" ]]; then label="YOUR TURN — run this and it walks you through it"
      else label="YOUR TURN — the tool cannot do this part"; fi ;;
  esac
  box_top "$colour"
  box "$colour" "$(bold "$label")" ""
  [[ -n "$name" ]] && box "$colour" "  $(bold "$name")"
  box_text "$colour" "$summary"
  # Bold, like every other command this tool prints: the box exists to carry one thing
  # to type, and it was the only line on the screen not marked as one.
  [[ -n "$cmd" ]] && box "$colour" "" "      $(bold "$(cmd_display "$cmd")")"
  box_end "$colour"
}

# Separator for next_action's five fields. Not a tab: tab is IFS whitespace, so
# `read` collapses a run of them and silently shifts every later field up — an
# action with no command was arriving with its summary parsed as the command.
NEXT_SEP=$'\037'

# The single next action, read out of state.tsv: owner, kind, gate, command, summary,
# separated by NEXT_SEP. Derived from the state rather than from the exit code, because rc 40
# says something is pending and never which thing, and rc 10 says a human is needed
# and never which step. The gate id is the only precise answer.
#
# Here rather than in bin/agent so every branch can be run against a fixture
# state.tsv with no network — the routing has more cases than any live run reaches.
# Red and pending are two different claims — a defect, versus work nobody has done
# yet — and the verdict must keep them apart. The *next step*, though, is decided by
# which gate is open rather than by how it failed: routing them through separate
# tables meant a cold start (no project chosen yet, which is pending and not broken)
# fell through the pending catch-all and told the developer to go run an app they had
# not built.
next_action() {
  local id status owner name detail first_open="" open_status="" missing
  local a_owner=human a_kind=unknown a_gate="" a_cmd="" a_summary=""
  local -a details=()
  if [[ -f "$WS/state.tsv" ]]; then
    while IFS=$'\t' read -r id status owner name detail; do
      [[ -n "$id" ]] || continue
      details+=("$id	$detail")
      if [[ -z "$first_open" && ( "$status" == red || "$status" == pending ) ]]; then
        first_open="$id"; open_status="$status"
      fi
    done < "$WS/state.tsv"
  fi
  _detail_of() {
    local row
    for row in "${details[@]+"${details[@]}"}"; do
      [[ "${row%%	*}" == "$1" ]] && { printf '%s' "${row#*	}" | plain; return; }
    done
  }

  # Whose move it is on `choose_target`, which is two different moves. Looking at their
  # Firebase estate is the agent's to run only once looking has been agreed to; until
  # then the next thing is the question, and reporting the read as the command is how it
  # got run three times without anybody being asked. `owner` moves with it: a decision
  # is `human` and a command to run is `agent`, and the field has to mean that.
  _target_action() {
    if approved list; then a_owner=agent; a_cmd="$BIN/agent discover"
    else a_owner=human; a_cmd="$BIN/agent question choose_target"; fi
  }

  missing="$(missing_tools | tr '\n' ' ')"; missing="${missing% }"

  if [[ -n "$missing" ]]; then
    a_kind=install_tools
    a_summary="install $missing, then re-run — without them the ladder cannot check those rungs at all"
  elif [[ -n "$first_open" ]]; then
    a_gate="$first_open"
    # A pending gate's remedy is the advice, which says what to do; a red gate's is
    # the verdict, which says what is wrong. Fall back to the other when one is empty.
    if [[ "$open_status" == pending ]]; then
      a_summary="$(advice_for "$first_open")"
      [[ -n "$a_summary" ]] || a_summary="$(_detail_of "$first_open")"
    else
      a_summary="$(_detail_of "$first_open")"
    fi
    case "$first_open" in
      G0)  a_kind=install_tools ;;
      G1)  a_kind=authenticate; a_cmd="gcloud auth login" ;;
      G2)  if [[ -z "$PID" ]]; then
             a_kind=choose_target; _target_action
             # This one is quoted inside a box a person reads, so it has to be a command
             # they could type. It used to be a bare `bin/agent …` for want of anything
             # short enough to fit — the shim is short enough.
             a_summary="pick a Firebase project and an Android package, then: $(cmd_path agent) set PID=… PACKAGE=…"
           # A project that does not answer is still a target worth changing: a typo'd id
           # and a project somebody has no access to are both fixed at the same screen,
           # the one that shows what is on record and offers picking again. The diagnosis
           # stays in the summary above it. Without the command this was the one red
           # state whose remedy was unnameable.
           else a_kind=project_unreachable; a_cmd="$BIN/agent question project_unreachable"; fi ;;
      # Enabling Firebase is provision's own first step (bin/provision:58-61), so this is
      # the same work under a different gate. It used to report a kind of its own that had
      # no command, no question and no row in the skill's table — three ways of saying
      # nothing, where `provision` says onboard --apply.
      G3)  a_kind=provision; a_owner=tool; a_cmd="$BIN/onboard --apply" ;;
      G4)  if [[ -z "$PACKAGE" ]]; then
             a_kind=choose_target; _target_action
           elif may_create_app; then
             # Registering the app is bin/provision's job, so once that yes is on record the
             # next step is the work itself. Without this arm the one gate that needs
             # provisioning is the only gate that never names it, and an agent following
             # `next` re-asks a question it already has the answer to, forever.
             a_kind=provision; a_owner=tool; a_cmd="$BIN/onboard --apply"
           else
             a_kind=register_app; a_cmd="$BIN/agent question register_app"
             a_summary="$a_summary — registering it is its own yes: $(cmd_path agent) question register_app"
           fi ;;
      G5|G6|G7|G8|G9) a_kind=provision; a_owner=tool; a_cmd="$BIN/onboard --apply" ;;
      # The first of four, not all four: the walk is the step, and a caller handed
      # every instruction at once hands them all on to the developer at once.
      G10) a_kind=iterable_keys; a_cmd="$BIN/iterable-keys --step 1" ;;
      # No package means nobody has said which app this is about, which is a choice
      # and not a missing install — telling them to build would name no target.
      G13) if [[ -z "$PACKAGE" ]]; then
             a_kind=choose_target; _target_action
             # The advice has to be replaced, not kept: "run the app and accept the
             # prompt" above a command that lists Firebase projects describes two
             # different jobs, and neither of them the one the command does.
             a_summary="name the app this is about first — nothing has chosen a package yet"
           # Installed, with only the notification dialog outstanding: that is somebody
           # opening their own app, not a build to redo. Routed as install_app it read as
           # "reinstall", which is both wrong and the expensive kind of wrong.
           elif [[ "$open_status" == pending && "$(_detail_of G13)" == *"not asked yet"* ]]; then
             a_kind=run_app
           else a_kind=install_app; fi ;;
      G14|G15) [[ "$open_status" == pending ]] && a_kind=run_app || a_kind=investigate ;;
      # Sending is the caller's to run, not the developer's: there is a command for
      # it, and an owner of `human` on a step that ships its own command tells
      # somebody the tool cannot do the very thing it is offering to do.
      G16) [[ "$open_status" == pending ]] && { a_kind=send_proof; a_owner=agent; a_cmd="$BIN/proof-push"; } || a_kind=investigate ;;
      G17) a_kind=campaign_send ;;
      *)   [[ "$open_status" == pending ]] && a_kind=run_app || a_kind=investigate ;;
    esac
    # The one step whose entire content is "somebody has to use their own app", so it
    # names the screen that asks them. A kind with no command is a step an agent is told
    # to take and given no way to take, and here it filled the gap by driving the device
    # over adb: minutes of guessed taps, and a permission dialog answered by a tool.
    [[ "$a_kind" == run_app ]] && a_cmd="$BIN/agent question run_app"
    # Who does it outranks whether it is allowed, because the terminal path asks for
    # consent in person — the wizard shows the same banner and records the same yes.
    # Routing to the approval first would ask an agent to collect permission for work
    # it is not the one doing.
    if ! agent_driven; then
      case "$a_kind" in
        provision|register_app)
          # Nobody has answered the fork yet, so the next step is the fork — not one of
          # its two answers. Routing straight to the handoff here is how a developer who
          # never chose gets a terminal block presented as the next thing to do, with the
          # choice mentioned underneath it as an aside. The approval branch below does not
          # match this kind, so the fork stays the next step until it is answered.
          if ! driver_chosen; then
            a_owner=human; a_kind=choose_driver; a_cmd="$BIN/agent question opening"
            # Same rule as the handover below: the verdict survives the routing. A red
            # gate that reads only "choose who runs this part" has had its diagnosis
            # deleted by a question about staffing.
            a_summary="${a_summary:+$a_summary — }choose who runs this part; the same screens either way, here or in your terminal"
          else
            a_owner=human; a_kind=run_in_terminal; a_cmd="$BIN/handoff"
            # The gate's verdict has to survive being handed over. It used to be replaced
            # outright, so `key rejected by FCM (HTTP 401)` reached the caller as "run the
            # setup in your own terminal" — the remedy with the diagnosis deleted, which
            # is the one shape a caller cannot recover from, since it reads as routine.
            a_summary="${a_summary:+$a_summary — }run the setup in your own terminal; nothing already working gets redone"
          fi
          ;;
      esac
    fi

    # Approval outranks the action it would authorise. Every kind here changes
    # somebody's Google project, and the developer is entitled to see the list and
    # say yes before any of it happens — not to be told afterwards which of their
    # things an agent decided to create.
    if ! approved; then
      case "$a_kind" in
        provision|register_app)
          # The remedy first: brief() truncates at 100 characters, and the second
          # half of the sentence is the part that survives losing.
          a_summary="approve the changes to ${PID:-the project} first — nothing has happened yet"
          [[ "$a_kind" == register_app ]] &&
            a_summary="$a_summary; registering $PACKAGE is a second, separate yes"
          a_owner=human; a_kind=approve_firebase; a_cmd="$BIN/agent approve firebase"
          ;;
      esac
    fi
  elif [[ -f "$WS/state.tsv" ]]; then
    a_owner=none; a_kind=done
    a_summary="a push reached the device — nothing left to do"
  else
    a_owner=agent; a_kind=run_ladder; a_cmd="$BIN/agent"
    a_summary="nothing has been checked yet"
  fi
  unset -f _detail_of _target_action
  printf '%s%s%s%s%s%s%s%s%s\n' \
    "$a_owner" "$NEXT_SEP" "$a_kind" "$NEXT_SEP" "$a_gate" "$NEXT_SEP" \
    "$a_cmd" "$NEXT_SEP" "$a_summary"
}

tok() { gcloud auth print-access-token 2>/dev/null; }

# firebase.googleapis.com rejects user credentials with 403 unless a quota
# project is attached. The gcloud CLI sends one implicitly, which is why
# `gcloud projects list` works while a raw curl with the same token does not.
# Resolution order: the project we're working on, gcloud's configured project,
# then whatever ADC has recorded.
quota_project() {
  if [[ -n "${QP:-}" ]]; then printf '%s' "$QP"; return; fi
  if [[ -n "$PID" ]]; then printf '%s' "$PID"; return; fi
  # Written only after a call actually succeeded with it — see firebase_projects.
  [[ -s "$WS/.quota" ]] && { tr -d '\n' < "$WS/.quota"; return; }
  local p
  p="$(gcloud config get-value project 2>/dev/null)"
  [[ -n "$p" && "$p" != "(unset)" ]] && { printf '%s' "$p"; return; }
  node -e 'try{process.stdout.write(require(process.env.HOME+"/.config/gcloud/application_default_credentials.json").quota_project_id||"")}catch(e){}' 2>/dev/null
}

# Quota-project candidates for the project *list*, which runs before any project
# is chosen. Best guess first; duplicates dropped.
quota_candidates() {
  {
    [[ -s "$WS/.quota" ]] && { tr -d '\n' < "$WS/.quota"; echo; }
    local p
    p="$(gcloud config get-value project 2>/dev/null)"
    [[ -n "$p" && "$p" != "(unset)" ]] && echo "$p"
    node -e 'try{const q=require(process.env.HOME+"/.config/gcloud/application_default_credentials.json").quota_project_id;if(q)console.log(q)}catch(e){}' 2>/dev/null
    gcloud projects list --format='value(projectId)' --limit="${LIMIT:-50}" 2>/dev/null
  } | awk 'NF && !seen[$0]++'
}

# Single writer for resolved.env, so the wizard and the actor cannot drift in how
# they record a choice. An empty value deletes the key — used to drop a derived
# value like APP_ID that a new project invalidates.
#
# A newline in the value would write a second KEY=VALUE line, and the reader above
# honours whatever it finds — so one pasted project id could set APPROVED=1 and grant
# its own consent, for every run after it. Refused here rather than sanitised: a value
# arriving with a line break in it is not a project id or a package name, and quietly
# keeping the first line would record a choice nobody made.
save_resolved() {
  case "${2:-}" in
    *$'\n'*) return 1 ;;
  esac
  ws_init; touch "$WS/resolved.env"
  grep -v "^$1=" "$WS/resolved.env" > "$WS/.resolved.tmp" 2>/dev/null || true
  mv "$WS/.resolved.tmp" "$WS/resolved.env"
  [[ -n "${2:-}" ]] && echo "$1=$2" >> "$WS/resolved.env"
  return 0
}

# curl, with the headers that carry a credential handed over on stdin instead of in
# the argument list. `ps` shows a full command line to every process on the machine,
# and iterable-keys tells the developer in bold that a key never goes into one — so
# `-H "Api-Key: $key"` made that sentence false. curl reads a config file from `-`
# exactly as it reads one from disk, and its own docs name this as the way to keep a
# credential out of a process list.
#
#   curl_auth "Authorization: Bearer $t" -- -sS -X POST -d "$data" "$url"
#
# stdin belongs to the config, so anything wanting `-d @-` cannot use this.
curl_auth() {
  local hdrs=() h
  while (($#)) && [[ "$1" != -- ]]; do hdrs+=("$1"); shift; done
  shift
  { for h in "${hdrs[@]}"; do
      h="${h//\\/\\\\}"; h="${h//\"/\\\"}"
      printf 'header = "%s"\n' "$h"
    done
  } | curl -K - "$@"
}

# POST with the same auth and quota-project handling as api_get. Every call to
# firebase.googleapis.com needs the quota header, not just the reads — leaving it
# off the writes is exactly how the 403 came back after api_get was fixed.
api_post() {
  local url="$1" data="${2:-}" body code qp
  [[ -n "$data" ]] || data='{}'
  qp="$(quota_project)"
  body="$(curl_auth "Authorization: Bearer $(tok)" -- \
    -sS -w $'\n%{http_code}' -X POST \
    -H 'Content-Type: application/json' \
    ${qp:+-H "x-goog-user-project: $qp"} \
    -d "$data" "$url" 2>&1)"
  code="${body##*$'\n'}"
  printf '%s' "${body%$'\n'*}"
  [[ "$code" =~ ^2 ]]
}

# GET a URL with the user's token; echoes body, returns non-zero on non-2xx.
api_get() {
  local url="$1" body code qp
  qp="$(quota_project)"
  body="$(curl_auth "Authorization: Bearer $(tok)" -- \
    -sS -w $'\n%{http_code}' \
    ${qp:+-H "x-goog-user-project: $qp"} \
    "$url" 2>&1)"
  code="${body##*$'\n'}"
  printf '%s' "${body%$'\n'*}"
  [[ "$code" =~ ^2 ]]
}

# The app's google-services.json, written only once it is whole. `api_get … > "$GS_JSON"`
# truncated the target before the fetch even ran, so a re-run that failed left an empty
# file where a good one had been — and G5 then called the file unparseable instead of
# calling the download failed. Lives here rather than in provision so a test can stub
# api_get and prove the existing file survives.
fetch_gs_json() {
  api_get "https://firebase.googleapis.com/v1beta1/projects/$PID/androidApps/$1/config" \
    | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
        const j=JSON.parse(d);
        if(!j.configFileContents){console.error(JSON.stringify(j).slice(0,300));process.exit(1)}
        process.stdout.write(Buffer.from(j.configFileContents,"base64").toString("utf8"))})' \
    > "$GS_JSON.part" || { rm -f "$GS_JSON.part"; return 1; }
  mv "$GS_JSON.part" "$GS_JSON"
}

jqn() { local s="$1"; shift; node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d||'{}');$s})" "$@"; }

# Verdict on an FCM messages:send response, split out as a pure function so the
# three-way judgement can be tested against recorded bodies without a network.
#   0 = proves the credential authenticates
#   1 = a real failure
#   2 = eventually consistent, ask again shortly
classify_fcm_response() {
  local code="$1" body="$2"
  case "$code" in
    200) echo "FCM accepted validate_only send"; return 0 ;;
    # A 400 on the placeholder token still proves auth: FCM authenticated us and
    # then rejected the fake registration token, which is exactly what we want.
    400) grep -qiE 'registration.token|INVALID_ARGUMENT' <<< "$body" \
           && { echo "authenticated (400 on placeholder token, as expected)"; return 0; }
         echo "HTTP 400: $(api_err "$body")"; return 1 ;;
    # IAM takes ~75s to make a new binding effective, so this 403 arrives even
    # though G7 is green and the binding really is in the policy.
    403) grep -q 'cloudmessaging.messages.create' <<< "$body" \
           && { echo "role not effective yet (cloudmessaging.messages.create denied)"; return 2; }
         echo "HTTP 403: $(api_err "$body")"; return 1 ;;
    *)   echo "HTTP $code: $(api_err "$body")"; return 1 ;;
  esac
}

# Google wraps one useful sentence in twenty lines of JSON. Pull out that sentence.
api_err() {
  printf '%s' "$1" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    let m; try { m = JSON.parse(d).error?.message } catch (e) {}
    process.stdout.write((m || d).replace(/\s+/g," ").trim().slice(0, 200));
  })' 2>/dev/null
}

android_apps() { api_get "https://firebase.googleapis.com/v1beta1/projects/$PID/androidApps"; }

# ----------------------------------------------------------------- Iterable side
# Keys live in their own file, not resolved.env: resolved.env holds choices that
# are safe to print, this holds secrets that are not.
ITBL_ENV="$WS/.env"
# Same reader as the cache, and for the stronger version of the same reason: this file
# holds values pasted from a dashboard, and it is read here — below every function.
load_env_file "$ITBL_ENV"

# EDC-based Iterable projects answer on api.eu.iterable.com. A key from one data
# centre returns 401 against the other, which reads exactly like a bad key — so
# this is a knob, not a constant.
: "${ITBL_BASE:=https://api.iterable.com}"
: "${ITBL_SERVER_KEY:=}"
: "${ITBL_MOBILE_KEY:=}"
: "${ITBL_EMAIL:=}"
# Set only when the proof push was sent through a campaign. A proof send raises no
# pushSend event, so G17 can corroborate nothing without this — see the plan.
: "${ITBL_CAMPAIGN_ID:=}"
# The push integration name Iterable matches against; equals the package name
# unless the integration predates Aug 2019 or was named by hand.
itbl_integration() { printf '%s' "${ITBL_PUSH_INTEGRATION:-$PACKAGE}"; }

# Single writer for the workspace .env, kept 0600. An empty value deletes the key.
save_env() {
  ws_init
  # umask, not a chmod afterwards: the temp file holds every *other* key, and `mv`
  # carries its mode with it, so the world-readable window existed at both names.
  # The chmod stays for a file an older version of this left behind at 0644.
  ( umask 077
    touch "$ITBL_ENV"
    grep -v "^$1=" "$ITBL_ENV" > "$WS/.env.tmp" 2>/dev/null || true
    mv "$WS/.env.tmp" "$ITBL_ENV"
    [[ -n "${2:-}" ]] && printf '%s=%s\n' "$1" "$2" >> "$ITBL_ENV" )
  chmod 600 "$ITBL_ENV"
  return 0
}

urlenc() { node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$1"; }

# Set by the proof sender so G16 can require the push it reads to be the one that
# was sent, rather than any notification the app happened to post.
: "${ITBL_PROOF_MARKER:=}"
: "${ITBL_PROOF_SENT_AT:=}"

# ------------------------------------------------------------------- Device side
# The developer's own app, on their own device. Everything here is a read over
# adb: the tool never builds or installs their app for them, and never sends from
# the device. How long to keep asking a device that answers "not yet".
: "${DEVICE_WAIT:=45}"
# A cold AVD boot is slow enough that the wizard has to say so rather than look hung.
: "${BOOT_WAIT:=240}"
: "${BOOT_POLL:=5}"

# `adb devices` also lists entries in state `offline`, `unauthorized` and
# `no permissions`, none of which answer a shell command.
adb_devices() { adb devices 2>/dev/null | awk '$2=="device"{print $1}'; }

avd_list() { emulator -list-avds 2>/dev/null; }

# The AVD behind a serial, empty for a physical phone. `emulator-5556` is a port
# number, which is not a thing anyone recognises as their own device — every
# message a human reads should name the AVD instead.
avd_of() { adb -s "$1" emu avd name 2>/dev/null | head -1 | tr -d '\r'; }

device_label() {
  local avd; avd="$(avd_of "$1")"
  [[ -n "$avd" ]] && { printf '%s (%s)' "$avd" "$1"; return 0; }
  printf '%s (%s)' "$(adb -s "$1" shell getprop ro.product.model 2>/dev/null | tr -d '\r')" "$1"
}

# Every device worth offering, running first, one per line: field 1 is the machine
# value (an AVD name, or a serial for a phone, which has no AVD name to go by) and the
# rest is for a person to recognise it by. The wizard feeds this to its menu and the
# chat picker renders the same lines as options — one list, so the two front ends cannot
# offer different devices, and an emulator that is not running is still shown rather
# than silently omitted from somebody's own machine.
device_options() {
  local s avd running=" "
  for s in $(adb_devices); do
    avd="$(avd_of "$s")"
    if [[ -n "$avd" ]]; then
      running="$running$avd "
      printf '%-28s running\n' "$avd"
    else
      printf '%-28s running · %s\n' "$s" "$(adb -s "$s" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    fi
  done
  for avd in $(avd_list); do
    [[ "$running" == *" $avd "* ]] && continue
    printf '%-28s not running — start it\n' "$avd"
  done
}

# A remembered device, resolved fresh every run. TARGET_DEVICE holds an AVD name
# or a physical serial, never an emulator serial: those are port numbers handed
# out in boot order, so the same AVD is emulator-5554 today and 5556 tomorrow and
# a remembered serial would quietly point at whatever booted first.
target_serial() {
  local want="$1" s
  for s in $(adb_devices); do
    [[ "$s" == "$want" ]] && { printf '%s' "$s"; return 0; }
    [[ "$(avd_of "$s")" == "$want" ]] && { printf '%s' "$s"; return 0; }
  done
  return 1
}

# The app's uid, asked of the device rather than remembered. `pm list packages`
# matches by prefix, so the pattern is anchored: com.example and com.example.dev
# are different apps and would otherwise share an answer.
app_uid() {
  adb -s "$1" shell pm list packages -U "$PACKAGE" 2>/dev/null | tr -d '\r' \
    | sed -n "s|^package:$PACKAGE uid:\([0-9]\{1,\}\).*|\1|p" | head -1
}

# logcat, narrowed to the chosen app. One buffer is shared by every app on the
# device and the Iterable SDK's lines look identical whichever app emitted them, so
# an unscoped read attributes another app's integration to this one.
#
# Returns 1 when it cannot narrow — no package chosen, app not installed, or a
# device whose logcat has no --uid. The caller decides what an unscoped read is
# worth, because the answer differs: for an identity it is worth nothing, and for
# evidence that the SDK ran it is the best available and has to be said out loud.
logcat_for_package() {
  local uid
  [[ -n "$PACKAGE" ]] || return 1
  uid="$(app_uid "$1")"
  [[ -n "$uid" ]] || return 1
  adb -s "$1" logcat -d --uid="$uid" 2>/dev/null
}

# Which identity the app actually registered, straight out of the SDK's own request
# body in logcat. The developer cannot reliably answer this from memory — the app
# decides it in code, and a wrong answer looks exactly like a broken Iterable
# project — so ask the device instead of asking them. Prints one address per line,
# most recent first; empty if the buffer has rotated or the app never registered.
#
# Silent unless the read can be attributed to the chosen package. A confident wrong
# join key is worse than no suggestion: this offered an address belonging to a
# different app on the same emulator while the chosen app was not even installed.
app_identity() {
  local d out; d="$(device_serial)" || return 0
  out="$(logcat_for_package "$d")" || return 0
  printf '%s\n' "$out" \
    | grep -F 'IterableRequest' \
    | grep -oE '"email": *"[^"]+"' \
    | grep -oE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | tail -r | awk '!seen[$0]++'
}

# Starts an AVD and waits for the OS, not just the port: adb answers well before
# sys.boot_completed, and a gate that reads a half-booted device gets nonsense.
# Lives here rather than in the wizard only so a test can reach the timeout branch
# without a pty and without a real cold boot.
boot_avd() {
  local avd="$1" waited=0 s
  echo "  Starting $avd. A cold boot takes a minute or two — leave it." >&2
  ( emulator -avd "$avd" -no-boot-anim >/dev/null 2>&1 & ) >/dev/null 2>&1
  while ((waited < BOOT_WAIT)); do
    if s="$(target_serial "$avd")" \
       && [[ "$(adb -s "$s" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == 1 ]]; then
      printf '%s' "$s"; return 0
    fi
    sleep "$BOOT_POLL"; waited=$((waited + BOOT_POLL))
  done
  echo "  $avd did not finish booting in ${BOOT_WAIT}s. It may still come up." >&2
  return 1
}

: "${TARGET_DEVICE:=}"

# One serial, or the reason there isn't one. ANDROID_SERIAL wins because adb
# honours it natively, so a developer who already exports it keeps their setup.
#
# With several devices attached this deliberately does not choose. Picking the
# first one and reporting a green gate about a device the developer wasn't
# thinking of is worse than asking. bin/wizard asks; everything else says how.
device_serial() {
  local list n s
  list="$(adb_devices)"
  # Taken on trust, a serial for a device that isn't there turns every read into a
  # silent failure: `adb -s` writes "device not found" to stderr and exits, and a
  # gate that greps the empty output concludes the app isn't installed. It is not
  # the same claim, and this is the only place that can tell them apart.
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    grep -qx -- "$ANDROID_SERIAL" <<< "$list" && { printf '%s' "$ANDROID_SERIAL"; return 0; }
    echo "ANDROID_SERIAL=$ANDROID_SERIAL is not connected (adb sees: ${list:-nothing})" | tr '\n' ' '
    return 1
  fi
  if [[ -n "$TARGET_DEVICE" ]]; then
    s="$(target_serial "$TARGET_DEVICE")" && { printf '%s' "$s"; return 0; }
    echo "$TARGET_DEVICE is not running — start it, or choose another device"
    return 1
  fi
  n="$(printf '%s' "$list" | grep -c '[^[:space:]]')"
  case "$n" in
    0) echo "no device — start an emulator or attach a phone, then re-run"; return 1 ;;
    1) printf '%s' "$list"; return 0 ;;
    *) local labels=""
       for s in $list; do labels="${labels:+$labels, }$(device_label "$s")"; done
       # Remedy first, list second: brief() truncates at 100 characters, and two
       # AVD names are enough to push the only actionable part of this off the end.
       echo "$n devices attached — pick one: $BIN/agent set TARGET_DEVICE=<name|serial> ($labels)"
       return 1 ;;
  esac
}

: "${ITBL_CODE:=}"
: "${ITBL_BODY:=}"

# Separate from itbl_call so a test can stub the transport and prove the
# code/body split with no network. Appends the status on its own last line,
# because bodies contain newlines and the gates need the status to tell
# "wrong key" from "key fine, request rejected".
itbl_curl() {
  local method="$1" key="$2" path="$3" data="${4:-}"
  # The Api-Key header goes in over stdin — see curl_auth.
  curl_auth "Api-Key: $key" -- \
    -sS -w $'\n%{http_code}' -X "$method" \
    -H 'Content-Type: application/json' \
    ${data:+-d "$data"} "$ITBL_BASE$path" 2>&1
}

# Sets ITBL_CODE and ITBL_BODY in the caller. Returns non-zero on non-2xx.
#
# Deliberately not "echo the body, set the code": `body="$(itbl_get …)"` runs the
# function in a subshell, so the status it assigns dies with that subshell and the
# next line reads an unset variable. Both values come back through globals, and
# the only subshell is the one inside this function.
itbl_call() {
  local out
  out="$(itbl_curl "$@")"
  ITBL_CODE="${out##*$'\n'}"
  ITBL_BODY="${out%$'\n'*}"
  [[ "$ITBL_CODE" =~ ^2 ]]
}
itbl_get()  { itbl_call GET  "$1" "$2"; }
itbl_post() { itbl_call POST "$1" "$2" "${3:-}"; }

# Iterable wraps errors as {"msg":…,"code":…,"params":…}.
itbl_err() {
  printf '%s' "$1" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    let m; try { const j=JSON.parse(d); m=j.msg||j.error } catch (e) {}
    process.stdout.write((m || d).replace(/\s+/g," ").trim().slice(0, 200));
  })' 2>/dev/null
}

# Verdict on an Iterable API response, pure so it can be tested against recorded
# bodies. mode=auth-only means a 400 still counts: we sent a deliberately invalid
# body to prove the key authenticates without creating anything.
#   0 = the key authenticated, 1 = a real failure
classify_itbl_response() {
  local code="$1" body="$2" mode="${3:-strict}"
  case "$code" in
    200|201)
      echo "HTTP $code"; return 0 ;;
    400)
      [[ "$mode" == auth-only ]] \
        && { echo "authenticated (400 on a deliberately empty body, as expected)"; return 0; }
      echo "HTTP 400: $(itbl_err "$body")"; return 1 ;;
    401|403)
      # A JWT-enabled key fails closed without a JWT. The fix is a different key
      # or the shared secret, not a different call — so name it.
      grep -q 'InvalidJwtPayload\|JWT' <<< "$body" \
        && { echo "key needs a JWT ($(itbl_err "$body"))"; return 1; }
      echo "key rejected (HTTP $code) — wrong key type, wrong data centre, or revoked"; return 1 ;;
    429)
      echo "rate limited (429)"; return 1 ;;
    *)
      echo "HTTP $code: $(itbl_err "$body")"; return 1 ;;
  esac
}

# Every Firebase-enabled project, in one call — no per-project probing.
#
# The catch: this call needs a quota project that has firebase.googleapis.com
# enabled. A project you merely have access to is not enough — it answers 403
# SERVICE_DISABLED. Every Firebase project qualifies by definition, so rather
# than guess we try candidates against the real call and keep the first that
# answers. That makes the cached quota project one we have proven, not assumed.
firebase_projects() {
  # Here as well as at the call site, so a caller added later inherits the refusal
  # instead of having to remember it. rc 10 is "a human is needed", which is what an
  # unasked question is — and it is not rc 1, so nothing reads it as "Google said no".
  may_list_projects || return 10
  local url='https://firebase.googleapis.com/v1beta1/projects?pageSize=100' body p
  while read -r p; do
    body="$(QP="$p" api_get "$url" 2>/dev/null)" || continue
    ws_init; printf '%s' "$p" > "$WS/.quota"
    printf '%s' "$body" | jqn 'process.stdout.write((j.results||[])
      .filter(p=>!p.state||p.state==="ACTIVE")
      .map(p=>[p.projectId,p.displayName||""].join("\t")).join("\n"))'
    return 0
  done <<< "$(quota_candidates)"
  return 1
}

android_apps_of() {
  QP="$1" PID="$1" api_get "https://firebase.googleapis.com/v1beta1/projects/$1/androidApps" \
    | jqn 'process.stdout.write((j.apps||[])
             .map(a=>[a.packageName,a.appId].join("\t")).join("\n"))'
}

app_id_for_package() {
  android_apps 2>/dev/null | jqn '
    const a=(j.apps||[]).find(a=>a.packageName===process.argv[1]);
    process.stdout.write(a?a.appId:"")' "$1"
}

# Three answers, not two: 0 present (echoes the email), 1 absent, 2 could not tell
# (echoes the error).
#
# `describe` cannot give the middle answer. A service account that has been deleted
# answers PERMISSION_DENIED on iam.serviceAccounts.get, not NOT_FOUND — GCP declines
# to say whether it ever existed, and measured on 2026-09-22 it does that even to the
# caller who just deleted it. A filtered list either works or fails as a whole, so an
# empty result means absent and nothing else.
sa_exists() {
  local out
  out="$(gcloud iam service-accounts list --project="$PID" \
          --filter="email=$SA_EMAIL" --format='value(email)' 2>&1)" \
    || { printf '%s' "$(tr -s '\n' ' ' <<< "$out")"; return 2; }
  [[ -n "$out" ]] || return 1
  printf '%s' "$out"
}

require_pid() {
  [[ -n "$PID" ]] && return 0
  cat >&2 <<EOF
No project selected. Pick one with:

    $BIN/discover             # lists your Firebase projects and their Android apps
    $BIN/agent set PID=your-project-id
EOF
  return 1
}
