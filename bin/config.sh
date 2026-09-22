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

# Anything resolved from live state (the project's existing package name, app id)
# is cached here so the verifier and the actor agree on what they are talking about.
#
# Sourced key by key rather than with `source`, because a cache must not outrank
# the caller: `PID=other bin/gates` was silently reading the remembered project
# and reporting gates about an app nobody asked about. Whatever is already in the
# environment wins.
if [[ -f "$WS/resolved.env" ]]; then
  while IFS='=' read -r _k _v; do
    [[ "$_k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    # Defined beats cached, even when defined empty: `TARGET_DEVICE= bin/gates` is
    # how you say "forget the remembered one", and it has to mean that.
    [[ -n "${!_k+x}" ]] && continue
    export "$_k=$_v"
  done < "$WS/resolved.env"
  unset _k _v
fi

: "${PID:=}"
: "${PACKAGE:=}"
: "${SA_ID:=itbl-onboard-fcm}"
: "${APP_DISPLAY_NAME:=Iterable Onboard Test}"

# Creating a project is opt-in. A tool that runs against a customer's account
# should never invent cloud resources at that scale unless asked outright.
: "${CREATE_PROJECT:=0}"
: "${CREATE_APP:=0}"

# Who runs the Google setup: `developer` at a terminal, or `agent` in a chat. The
# default is the developer, and not out of caution — the wizard is simply better at
# this part. It hosts the Google sign-in, it offers to register an Android app when
# the project has none, and it takes the Iterable keys with the echo off.
#
# That first case is why the default changed. A demo hit a project with no Android
# app, so there was no google-services.json to download; the agent driving the
# scripts needed CREATE_APP=1, improvised around the missing file to keep the build
# green, and then stopped without naming a way forward. The wizard asks.
: "${DRIVER:=developer}"
agent_driven() { [[ "$DRIVER" == agent ]]; }

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
  [[ -f "$WS/resolved.env" ]] && grep -q '^DRIVER=agent$' "$WS/resolved.env"
}

# Printed instead of doing the work. The banner is the remedy; this line is why it
# appeared in the middle of something that looked like it was about to run.
handoff_refusal() {
  handoff_banner
  printf '  %s\n' "$(dim "Not run: this changes a Google project and nobody recorded a request for it to be")"
  printf '  %s\n\n' "$(dim "driven from a chat. That record is: $BIN/agent set DRIVER=agent")"
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
dim()   { printf '\033[2m%s\033[0m' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

# Three things have to be impossible to scroll past: what the tool is about to
# change in somebody's cloud project, what is blocking the run, and that an agent
# wrote the code. Hence a bar rather than a full box — the text inside is coloured,
# and a right-hand edge would mean measuring the printable width of a string full
# of escape sequences, which is arithmetic that goes wrong silently.
#
# 31 red is "this changes something, or something is wrong", 33 yellow is "yours to
# do", 36 cyan is "read this", 2 dim is context.
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
    | awk '{ if (length($0) > 100) { s = substr($0, 1, 99); sub(/ [^ ]*$/, "", s); print s "…" } else print }'
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
    # Launching the app again achieves nothing while it has no key to register with,
    # so the advice follows the reason rather than the gate.
    G14) [[ -n "$ITBL_MOBILE_KEY" ]] \
           && echo "launch the app, so the SDK registers a token" \
           || echo "finish the Iterable steps first — the app needs a mobile key before it can register anything" ;;
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
  # Dim, and unbolded even where the advice bolds a command: bold is the tool saying
  # "type this", and nothing in this list is due yet. The one that is due is in the box.
  rest="$(pending_advice "$gate" | plain)"
  if [[ -n "$rest" ]]; then
    echo "  $(dim "Waiting behind it:")"
    while IFS= read -r l; do printf '      %s\n' "$(dim "$l")"; done <<< "$rest"
    echo
  fi
  # Said rather than asked, and only while it is still the answer to something: the
  # file is unexplained otherwise, and "what is sa-key.json for" arrives at step 3.
  if [[ -f "$SA_KEY" && "$(gate_status G10)" != green ]]; then
    echo "  $(dim "Keep $(wsp artifacts/sa-key.json) — the Iterable push integration step uploads it.")"
    echo
  fi
  echo "  When that is done, run this again — nothing already green gets redone:"
  echo
  run_line onboard
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

# Said in the tool's own voice, because on the path we ship there is nobody else to
# say it: the developer is talking to an agent, and an agent assuring you that its
# own output is trustworthy is not worth much. Not written as a legal disclaimer —
# the useful version tells them which half of what they are looking at is evidence
# and which half is a draft.
# One line per paragraph, unwrapped: the banner wraps it to whatever width it has,
# and an agent relaying it into a chat window reflows it anyway. Pre-wrapped text
# came out ragged in both.
ai_notice() {
  cat <<'EOF'
An AI agent wrote the code and configuration this puts in your repository, and it can be wrong in ways that still compile and still pass every check here.

Evidence: the push proof. A real notification, on a real device, read back out of the operating system — not an agent's report that it worked.

A draft: everything else. Read the diff, run your own tests, and treat it like a pull request from somebody new to your codebase. It is your code now.
EOF
}

ai_notice_banner() {
  box_top 36
  box 36 "$(bold "READ THIS BEFORE YOU SHIP IT")" ""
  # Paragraph by paragraph, so the blank lines survive the wrap.
  ai_notice | while IFS= read -r l; do
    [[ -n "$l" ]] && box_text 36 "$l" || box 36 ""
  done
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

approval_scope() { printf 'firebase %s' "${PID:-<no project chosen>}"; }

approved() {
  [[ "${APPROVED:-0}" == 1 ]] && return 0
  [[ -n "$PID" ]] || return 1
  awk -F'\t' -v s="$(approval_scope)" '$1==s{found=1} END{exit !found}' "$APPROVALS" 2>/dev/null
}

approve() {
  [[ -n "$PID" ]] || return 1
  ws_init || return 1
  approved || printf '%s\t%s\n' "$(approval_scope)" "$(date '+%Y-%m-%d %H:%M')" >> "$APPROVALS"
}

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
      G4) echo "register $PACKAGE as an Android app — needs CREATE_APP=1" ;;
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
  box 31 "" "$(bold "  What it will not do")" \
    "    · touch an app, integration or credential you already have" \
    "    · create a Firebase project, or register an app, unless you ask outright" \
    "    · ask for, store or type a password — you sign in yourself" ""
  if [[ "$how" == prompt ]]; then
    box 31 "$(bold "  Answer below.") Nothing has happened yet, and no is a complete answer."
  else
    box 31 "$(bold "  Yes")  $BIN/agent approve firebase" \
           "$(dim "        or APPROVED=1 in the environment, for CI")" \
           "$(bold "  No")   change nothing and walk away. Nothing has happened yet."
  fi
  box 31 "" "$(dim "  The JSON key it creates is a long-lived credential until you delete it.")" \
         "$(dim "  Undo everything it adds, whenever you like:")" \
         "  $(bold "$BIN/teardown")"
  box_end 31
}

# The block that sends a developer to their own terminal, and the reason the default
# points there: the wizard hosts the Google sign-in, it offers to register an Android
# app when the project has none, and it takes the Iterable keys with the echo off.
# None of those three are things a chat can do.
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
  local proj gate="${1:-}" why="${2:-}" colour=36
  proj="$(git rev-parse --show-toplevel 2>/dev/null)" || proj="$PWD"
  [[ -n "$why" ]] && colour=31
  box_top "$colour"
  if [[ -n "$why" ]]; then
    box "$colour" "$(bold "SOMETHING NEEDS FIXING — and it is in your terminal, not here")" ""
    [[ -n "$gate" ]] && box "$colour" "  $(bold "$gate")"
    box_text "$colour" "$why"
    box "$colour" ""
  else
    box "$colour" "$(bold "RUN THIS IN YOUR TERMINAL — then come back here")" ""
  fi
  # The command is relative now, so the directory is part of it rather than a footnote.
  # Not folded: wrapping a path mid-string reads worse than letting one dim line run
  # past the bar, which is why the bar has no right-hand edge in the first place.
  box "$colour" "      $(bold "$(cmd_path onboard)")" \
                "$(dim "      run from $proj")" ""
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
                "  come back here and say so, and I will carry on from there." ""
  box "$colour" "$(dim "  Nothing to copy. The result is in $(wsp "" | sed 's:/$::'), and I read it")" \
                "$(dim "  from there rather than asking you to retype it.")"
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
  [[ -n "$cmd" ]] && box "$colour" "" "      $(cmd_display "$cmd")"
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
             a_kind=choose_target; a_owner=agent; a_cmd="$BIN/agent discover"
             # This one is quoted inside a box a person reads, so it has to be a command
             # they could type. It used to be a bare `bin/agent …` for want of anything
             # short enough to fit — the shim is short enough.
             a_summary="pick a Firebase project and an Android package, then: $(cmd_path agent) set PID=… PACKAGE=…"
           else a_kind=project_unreachable; fi ;;
      G3)  a_kind=enable_firebase ;;
      G4)  if [[ -z "$PACKAGE" ]]; then
             a_kind=choose_target; a_owner=agent; a_cmd="$BIN/agent discover"
           else
             a_kind=register_app
             a_summary="$a_summary — registering it needs CREATE_APP=1, on purpose"
           fi ;;
      G5|G6|G7|G8|G9) a_kind=provision; a_owner=tool; a_cmd="$BIN/onboard --apply" ;;
      # The first of four, not all four: the walk is the step, and a caller handed
      # every instruction at once hands them all on to the developer at once.
      G10) a_kind=iterable_keys; a_cmd="$BIN/iterable-keys --step 1" ;;
      # No package means nobody has said which app this is about, which is a choice
      # and not a missing install — telling them to build would name no target.
      G13) if [[ -z "$PACKAGE" ]]; then
             a_kind=choose_target; a_owner=agent; a_cmd="$BIN/agent discover"
           else a_kind=install_app; fi ;;
      G14|G15) [[ "$open_status" == pending ]] && a_kind=run_app || a_kind=investigate ;;
      # Sending is the caller's to run, not the developer's: there is a command for
      # it, and an owner of `human` on a step that ships its own command tells
      # somebody the tool cannot do the very thing it is offering to do.
      G16) [[ "$open_status" == pending ]] && { a_kind=send_proof; a_owner=agent; a_cmd="$BIN/proof-push"; } || a_kind=investigate ;;
      G17) a_kind=campaign_send ;;
      *)   [[ "$open_status" == pending ]] && a_kind=run_app || a_kind=investigate ;;
    esac
    # Who does it outranks whether it is allowed, because the terminal path asks for
    # consent in person — the wizard shows the same banner and records the same yes.
    # Routing to the approval first would ask an agent to collect permission for work
    # it is not the one doing.
    if ! agent_driven; then
      case "$a_kind" in
        provision|enable_firebase|register_app)
          a_owner=human; a_kind=run_in_terminal; a_cmd="$BIN/handoff"
          # The gate's verdict has to survive being handed over. It used to be replaced
          # outright, so `key rejected by FCM (HTTP 401)` reached the caller as "run the
          # setup in your own terminal" — the remedy with the diagnosis deleted, which
          # is the one shape a caller cannot recover from, since it reads as routine.
          a_summary="${a_summary:+$a_summary — }run the setup in your own terminal; nothing already working gets redone"
          ;;
      esac
    fi

    # Approval outranks the action it would authorise. Every kind here changes
    # somebody's Google project, and the developer is entitled to see the list and
    # say yes before any of it happens — not to be told afterwards which of their
    # things an agent decided to create.
    if ! approved; then
      case "$a_kind" in
        provision|enable_firebase|register_app)
          # The remedy first: brief() truncates at 100 characters, and the CREATE_APP
          # half of the sentence is the part that survives losing.
          a_summary="approve the changes to ${PID:-the project} first — nothing has happened yet"
          [[ "$a_kind" == register_app ]] &&
            a_summary="$a_summary; registering $PACKAGE also needs CREATE_APP=1, on purpose"
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
  unset -f _detail_of
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
save_resolved() {
  ws_init; touch "$WS/resolved.env"
  grep -v "^$1=" "$WS/resolved.env" > "$WS/.resolved.tmp" 2>/dev/null || true
  mv "$WS/.resolved.tmp" "$WS/resolved.env"
  [[ -n "${2:-}" ]] && echo "$1=$2" >> "$WS/resolved.env"
  return 0
}

# POST with the same auth and quota-project handling as api_get. Every call to
# firebase.googleapis.com needs the quota header, not just the reads — leaving it
# off the writes is exactly how the 403 came back after api_get was fixed.
api_post() {
  local url="$1" data="${2:-}" body code qp
  [[ -n "$data" ]] || data='{}'
  qp="$(quota_project)"
  body="$(curl -sS -w $'\n%{http_code}' -X POST \
    -H "Authorization: Bearer $(tok)" \
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
  body="$(curl -sS -w $'\n%{http_code}' \
    -H "Authorization: Bearer $(tok)" \
    ${qp:+-H "x-goog-user-project: $qp"} \
    "$url" 2>&1)"
  code="${body##*$'\n'}"
  printf '%s' "${body%$'\n'*}"
  [[ "$code" =~ ^2 ]]
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
# shellcheck disable=SC1090
[[ -f "$ITBL_ENV" ]] && source "$ITBL_ENV"

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
  ws_init; touch "$ITBL_ENV"; chmod 600 "$ITBL_ENV"
  grep -v "^$1=" "$ITBL_ENV" > "$WS/.env.tmp" 2>/dev/null || true
  mv "$WS/.env.tmp" "$ITBL_ENV"; chmod 600 "$ITBL_ENV"
  [[ -n "${2:-}" ]] && printf '%s=%s\n' "$1" "$2" >> "$ITBL_ENV"
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
  curl -sS -w $'\n%{http_code}' -X "$method" \
    -H "Api-Key: $key" -H 'Content-Type: application/json' \
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

require_pid() {
  [[ -n "$PID" ]] && return 0
  cat >&2 <<EOF
No project selected. Pick one with:

    $BIN/discover             # lists your Firebase projects and their Android apps
    $BIN/agent set PID=your-project-id
EOF
  return 1
}
