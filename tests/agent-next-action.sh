#!/usr/bin/env bash
# The routing every agent run depends on: given a ladder state, what is the single
# next thing, and who owns it.
#
# Worth pinning offline because the agent path has no human to notice a wrong
# answer. A human reading "First red gate: G10" works out that they need API keys;
# a model reads `next.kind` and does what it says. So a mis-route here is not a
# confusing message, it is the agent confidently doing the wrong thing — and most
# of these branches are unreachable on any single live run.
#
# No network, no credentials, no device.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-44s %s\n' "$1" "$2"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export WS="$TMP/ws"; mkdir -p "$WS/artifacts"

# The four binaries G0 requires, present but never called: next_action asks only
# whether they exist, and a missing one has to outrank every other answer.
#
# PATH is replaced rather than prefixed, so removing a stub really removes the
# binary. Prefixing left the developer's own adb one entry further down, and the
# missing-tool case passed by accident against a machine that had everything.
STUB="$TMP/bin"; mkdir -p "$STUB"
for c in node gcloud adb; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done
export PATH="$STUB:/usr/bin:/bin"

source bin/config.sh

# A ladder state, written the way bin/gates writes it: id, status, owner, name, detail.
state() { : > "$WS/state.tsv"; while (($#)); do printf '%s\n' "$1" >> "$WS/state.tsv"; shift; done; }
row()   { printf '%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "${5:-}"; }

# want: owner/kind, and optionally a substring the summary must contain — or, with a
# `cmd:` prefix, one the command must contain. Which field carries a command is the
# thing being pinned: `command` does, and summaries that also spelled one out were
# printing a bare `bin/…` that does not resolve from the developer's project.
#
# next_action is captured before the split, not substituted inside the `read`: a
# temporary IFS assignment is in effect while the command's own expansions run, and
# a changed IFS inside next_action is a different function.
expect() {
  local want_owner="$1" want_kind="$2" want_in="${3:-}" label="$4"
  local owner kind gate cmd summary out
  out="$(next_action)"
  IFS="$NEXT_SEP" read -r owner kind gate cmd summary <<< "$out"
  [[ "$owner" == "$want_owner" && "$kind" == "$want_kind" ]] \
    || { bad "$label" "got $owner/$kind, wanted $want_owner/$want_kind"; return; }
  # Every routed state, not only the ones a case below happens to name. A kind with no
  # command is a step an agent is told to take and given no way to take, and it ends the
  # only way it can: by handing the developer a terminal. G4 sat like that through four
  # rounds of fixes to the wording, because the wording was never the thing that was
  # wrong. The exceptions are the steps no script of ours performs: the developer's own
  # work in their own repo or on their own machine — install a toolchain, build, run,
  # look, send a campaign.
  case "$kind" in
    install_tools|install_app|run_app|investigate|campaign_send|done) ;;
    *) [[ -n "$cmd" ]] || { bad "$label" "$kind names no command — nothing for the agent to run"; return; } ;;
  esac
  if [[ "$want_in" == cmd:* ]]; then
    if [[ "$cmd" != *"${want_in#cmd:}"* ]]; then
      bad "$label" "command lacks '${want_in#cmd:}': $cmd"; return
    fi
  elif [[ -n "$want_in" && "$summary" != *"$want_in"* ]]; then
    bad "$label" "summary lacks '$want_in': $summary"; return
  fi
  ok "$(printf '%-44s %s/%s%s' "$label" "$owner" "$kind" "${gate:+ ($gate)}")"
}

echo
echo "  next_action — one action per ladder state"
echo

# ------------------------------------------------------------------ nothing yet
rm -f "$WS/state.tsv"
expect agent run_ladder "nothing has been checked" "no state file at all"

# --------------------------------------------------------------- a missing tool
# Outranks everything, including a red gate: a gate that cannot run is not evidence,
# and telling someone to fix G10 when adb is absent sends them at the wrong problem.
state "$(row G10 red human "Iterable API keys work" "key rejected (HTTP 401)")"
rm -f "$STUB/adb"
expect human install_tools "adb" "missing adb outranks a red gate"
printf '#!/bin/sh\nexit 0\n' > "$STUB/adb"; chmod +x "$STUB/adb"

# --------------------------------------------------------------- the Google half
state "$(row G0 green human "Tooling present" "node v25")" \
      "$(row G1 red human "Google authenticated" "no token: run 'gcloud auth login'")"
expect human authenticate "gcloud auth login" "G1 red — the human signs in"

PID="" PACKAGE=""
state "$(row G2 red tool "GCP project exists" "no project selected — run bin/discover")"
expect human choose_target "set PID=… PACKAGE=…" "G2 red with no project — the agent asks"

# Two moves under one kind, and which one it is depends on whether looking has been
# agreed to. Three live transcripts had an agent read `command: agent discover`, see a
# signed-in gcloud, and list the developer's whole Firebase estate — so while the yes is
# missing the command is the question, and `owner` says `human` because a decision is
# not work. This is the assertion that would have caught it.
expect human choose_target "cmd:question choose_target" "no yes to look — the question, not the read"

# Once they have agreed, the read is genuinely the agent's to run. The stub grows an
# account, because the yes is scoped to one and an unscoped record must never match.
cat > "$STUB/gcloud" <<'EOF'
#!/bin/sh
[ "$*" = "config get-value account" ] && { echo dev@example.com; exit 0; }
exit 0
EOF
chmod +x "$STUB/gcloud"
printf 'list dev@example.com\t2026-09-23 12:00\n' > "$WS/approved"
expect agent choose_target "cmd:agent discover" "yes on record — the read is the agent's"
rm -f "$WS/approved"

# A project that is named and still unreachable is a different problem from one that
# was never chosen, and the remedy is not "pick one".
PID=some-project
state "$(row G2 red tool "GCP project exists" "PERMISSION_DENIED on some-project")"
expect human project_unreachable "PERMISSION_DENIED" "G2 red with a project named"

# --------------------------------------------------- not the agent's to run at all
# Every Google mutation is somebody's decision before it is anybody's work, and while
# nobody has taken it the next step is the decision itself. Reporting the handover here
# instead was the routing half of a demo failure: told to hand over, the agent relayed a
# command, stopped, and the developer read one of the two answers as the only one.
PID=p PACKAGE=com.example
rm -f "$WS/resolved.env"
for g in G3 G4 G5 G6 G7 G8 G9; do
  state "$(row "$g" red tool "$g" "not created yet")"
  expect human choose_driver "same screens either way" "$g red — asks who runs it first"
done
# And it asks by opening the screen that carries both answers, not by handing over the
# command that is one of them.
IFS="$NEXT_SEP" read -r _o _k _g ASKCMD _s <<< "$(next_action)"
[[ "$ASKCMD" == *"question opening" ]] && ok "the command is the fork, presented" \
  || bad "fork command" "got $ASKCMD"

# Answered, and then honoured. The terminal is where a "you run it" goes — it is
# reachable, it is just not the answer given on the developer's behalf.
printf 'DRIVER=developer\n' > "$WS/resolved.env"
expect human run_in_terminal "your own terminal" "recorded as theirs — handed over"
IFS="$NEXT_SEP" read -r _o _k _g HANDCMD _s <<< "$(next_action)"
[[ "$HANDCMD" == *"bin/handoff" ]] && ok "the command is the handover block itself" \
  || bad "handover command" "got $HANDCMD"
rm -f "$WS/resolved.env"

# ------------------------------------------------------- nothing until they say yes
# Every route below changes somebody's Google project, so the ask outranks the work.
# Pinned because the enforcement lives in bin/provision and the *routing* is what
# stops an agent walking a developer up to a wall it cannot see.
#
# DRIVER=agent throughout: this is the path a developer gets only by asking for it,
# and consent is the agent's to collect precisely because the wizard is not there to
# ask in person.
export DRIVER=agent
state "$(row G3 red tool "Firebase enabled" "firebase not enabled on p")"
expect human approve_firebase "approve the changes to p" "G3 red — approval comes first"

state "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
expect human approve_firebase "separate yes" "G4 red — approval first, and the app ask survives it"

for g in G5 G6 G7 G8 G9; do
  state "$(row "$g" red tool "$g" "not created yet")"
  expect human approve_firebase "nothing has happened yet" "$g red — unapproved, so nobody provisions"
done

# With the yes recorded, the same states route to the work itself. APPROVED=1 is the
# CI form of the answer; the agent path records it per project in the workspace.
export APPROVED=1
state "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
# Its own yes, and the summary has to say where to give it: an agent told only that a
# flag is missing sets the flag, which is the developer's answer given by the thing
# that wanted it.
expect human register_app "question register_app" "approved — creating an app is still its own opt-in"
for g in G5 G6 G7 G8 G9; do
  state "$(row "$g" red tool "$g" "not created yet")"
  expect tool provision "cmd:onboard --apply" "$g red, approved — the tool can do this part"
done

# The state every live transcript ended in, and the one the suite used to bless: both
# yeses on record, the agent driving, and an app still to register. Registering one is
# bin/provision's job and no other script's, so this has to name it — with nothing to
# name, the only action left that produced output was the handoff, which is how a
# developer who had already said yes twice was handed a terminal command.
CREATE_APP=1
state "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
expect tool provision "cmd:onboard --apply" "both yeses in — the work, not the question again"
unset CREATE_APP
unset APPROVED

# A yes belongs to the project it was given for. Approving work in one project must
# not carry over to the next one an agent happens to pick.
PID=p; approve
state "$(row G6 red tool "Service account exists" "not created yet")"
expect tool provision "" "the recorded yes counts for the project it named"
PID=other-project
expect human approve_firebase "approve the changes to other-project" "...and not for a different one"
PID=p PACKAGE=com.example

# ------------------------------------------------------------- the Iterable half
PID=p PACKAGE=com.example
state "$(row G10 red human "Iterable API keys work" "key rejected (HTTP 401) — wrong key type")"
expect human iterable_keys "" "G10 red — dashboard keys"

# ---------------------------------------------------------------- the device half
PID=p PACKAGE=com.example
state "$(row G13 red human "App installed with the SDK" "com.example is not installed")"
expect human install_app "not installed" "G13 red — build and install"

# Pending is not red. Nobody has run the app; that is not a defect and the advice
# must not read like one.
PID=p PACKAGE=com.example ITBL_EMAIL=t@example.com
state "$(row G13 green human "App installed" "v1.0")" \
        "$(row G15 pending tool "Token registered in Iterable" "no user yet")"
expect human run_app "t@example.com" "G15 pending — the join key is named"

PID=p PACKAGE=com.example
state "$(row G13 green human "App installed" "v1.0")" \
        "$(row G16 pending tool "Push arrives on device" "no Iterable push on the device")"
expect agent send_proof "cmd:$BIN/proof-push" "G16 pending — the caller sends the proof"

# The first red wins over a later pending: fixing the pending one first would be
# work against a system that is still broken upstream.
PID=p PACKAGE=com.example
state "$(row G10 red human "Iterable API keys work" "key rejected")" \
        "$(row G16 pending tool "Push arrives on device" "no Iterable push")"
expect human iterable_keys "" "a red outranks a later pending"

# --------------------------------------------------------------- the cold start
# The state a client's very first run produces, and the one no live run of ours ever
# had: nothing chosen, nothing created. Every rung here is pending rather than red,
# because an input nobody has supplied is not a defect — and the route has to be the
# same as it would be for the red form, or the first thing a client ever sees is the
# agent telling them to run an app they have not built.
PID="" PACKAGE=""
state "$(row G0 green human "Tooling present" "node v25")" \
      "$(row G1 green human "Google authenticated" "signed in")" \
      "$(row G2 pending tool "GCP project exists" "no project selected yet")" \
      "$(row G10 pending human "Iterable API keys work" "no server-side key yet")" \
      "$(row G13 pending human "App installed with the SDK" "no package selected yet")"
expect human choose_target "set PID=… PACKAGE=…" "cold start — pick a target, not a defect"

PID=p PACKAGE=""
state "$(row G13 pending human "App installed with the SDK" "no package selected yet")"
expect human choose_target "" "G13 pending, no package — a choice, not an install"

PID=p PACKAGE=com.example
state "$(row G10 pending human "Iterable API keys work" "no server-side key yet")"
expect human iterable_keys "" "G10 pending — same route as G10 red"

# ------------------------------------------------ what the blocker box calls it
# The banner is derived from this same routing, and which word it picks is the part a
# developer remembers. The input is the kind, never the gate's status: "service
# account: not created yet" is red and is also the tool's own next job, and a tool
# that calls its own to-do list BROKEN teaches somebody to stop believing the word.
banner_says() {
  local want="$1" label="$2" out
  out="$(blocker_banner 2>&1 | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g')"
  grep -qF -- "$want" <<< "$out" && ok "$(printf '%-44s %s' "$label" "$want")" \
    || bad "$label" "no '$want' in: $(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"
}

# Some of this is about what a box must not say. An alarm raised over pending work costs
# more than a missing one: it is spent the first time, and scrolled past from then on.
banner_says_not() {
  local unwanted="$1" label="$2" out
  out="$(blocker_banner 2>&1 | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g')"
  grep -qF -- "$unwanted" <<< "$out" && bad "$label" "said '$unwanted' about pending work" \
    || ok "$(printf '%-44s %s' "$label" "no '$unwanted'")"
}

PID=p PACKAGE=com.example APPROVED=1
state "$(row G6 red tool "Service account exists" "not created yet")"
banner_says "THE TOOL CAN DO THIS" "a red the tool itself clears"

state "$(row G13 green human "App installed" "v1.0")" \
      "$(row G16 red tool "Push arrives on device" "no Iterable push on the device")"
banner_says "SOMETHING IS ACTUALLY WRONG" "a push that was sent and never arrived"

state "$(row G13 red human "App installed with the SDK" "no device attached")"
banner_says "YOUR TURN" "no device is theirs to fix, not a defect"
banner_says "the tool cannot do this part" "nothing to run — plugging a phone in is theirs alone"

# Theirs to do, but not theirs to work out: the dashboard walk ships a command, and
# "the tool cannot do this part" printed directly above that command disowns it.
state "$(row G10 pending human "Iterable API keys work" "no server-side key yet")"
banner_says "it walks you through it" "a human step the tool still narrates"

# ------------------------------------------------ the ending, shared by all of them
# The wizard's copy of this had drifted: it printed the list of outstanding work and
# no box, which left the only command on the screen a relative path — shown to
# somebody standing in their own project, the one directory where bin/… cannot
# resolve. Front ends may differ in how they ask; they may not differ in this.
state "$(row G10 pending human "Iterable API keys work" "no server-side key yet")" \
      "$(row G16 pending tool "Push arrives on device" "nothing on the device yet")"
tail_out="$(pending_tail 2>&1 | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g')"

# Asserted as "the thing it names runs", not as a particular spelling. A bare bin/…, an
# absolute plugin path and a workspace shim have each been the right answer at some point
# — and the defect all three times was a command that did not resolve, never the wording.
keys_cmd="$(cmd_path iterable-keys)"
grep -qF "$keys_cmd --step 1" <<< "$tail_out" \
  && ok "$(printf '%-44s %s' "the next step is the one that resolves" "$(basename "$keys_cmd")")" \
  || bad "the rc 40 ending has no runnable command" "$(tr -s '\n ' ' ' <<< "$tail_out" | cut -c1-90)"

[[ -x "$keys_cmd" || -x "$WS/iterable-keys" ]] \
  && ok "$(printf '%-44s %s' "and what it names is executable" "not just well-formed")" \
  || bad "the ending names something unrunnable" "$keys_cmd"

n="$(grep -c "four Iterable dashboard steps" <<< "$tail_out")"
((n == 1)) \
  && ok "$(printf '%-44s %s' "named once, not boxed and listed again" "1 mention")" \
  || bad "the next step appears $n times" "in the box and again in the list reads as two tasks"

grep -qF "send the proof push" <<< "$tail_out" \
  && ok "$(printf '%-44s %s' "what waits behind it is still shown" "G16 listed")" \
  || bad "the rest of the outstanding work vanished" "only the next step survived"

# A project with no recorded yes — the earlier cases recorded one for p.
APPROVED=0 PID=q
state "$(row G6 red tool "Service account exists" "not created yet")"
banner_says "APPROVAL NEEDED" "unapproved — the ask replaces the blocker"
APPROVED=1 PID=p

# And once they have said it is theirs, it is neither of those: it is the command they run
# themselves — said as whose part it is, not issued as an order. The heading was an
# imperative until 2026-09-24, and an imperative is the one thing this box does not need to
# carry: the agent relaying it was handed the next step in the same read.
DRIVER=developer
printf 'DRIVER=developer\n' > "$WS/resolved.env"
state "$(row G6 red tool "Service account exists" "not created yet")"
banner_says "THIS PART IS YOURS TO RUN" "a recorded yes hands over instead of asking"
banner_says_not "RUN THIS IN YOUR TERMINAL" "handing over is not an instruction to obey"
banner_says "come back here and say so" "the handover says how to return"
banner_says "checks pass so far" "and where the run had got to before it"

# Before that, the same state read by something with no terminal — an agent — is the fork
# itself, and the fork must not be drawn as the page of terminal instructions. That page
# was what a developer got shown while the choice was still open, which is how "one of two
# answers" became "the next thing to do". What it is instead: where the run has got to,
# and what the next part is asking to be allowed to do.
rm -f "$WS/resolved.env"
fork_out="$(blocker_banner 2>&1 < /dev/null | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g')"
grep -qF "WHERE THIS RUN HAS GOT TO" <<< "$fork_out" \
  && ok "$(printf '%-44s %s' "unanswered, off a terminal: progress and the ask" "not a page to obey")" \
  || bad "the unanswered fork drew something else" "$(tr -s '\n ' ' ' <<< "$fork_out" | cut -c1-90)"
grep -qF "THIS PART IS YOURS TO RUN" <<< "$fork_out" \
  && bad "the fork opens with the handover block" "one answer, presented as the step" \
  || ok "$(printf '%-44s %s' "and not as a part they never claimed" "no handover page")"
grep -qF "Service account exists" <<< "$fork_out" \
  && ok "$(printf '%-44s %s' "it names the part being asked about" "the gate, by name")" \
  || bad "the ask does not say what it is asking about" "no next step named"
grep -qF "$(cmd_path onboard)" <<< "$fork_out" \
  && ok "$(printf '%-44s %s' "the terminal is still one line away" "command present")" \
  || bad "the fork hides the terminal option" "no command to run it themselves"
printf 'DRIVER=developer\n' > "$WS/resolved.env"

# A first run has produced nothing, so "not created yet" is the ordinary next job. The
# alarm belongs to a repair; spent on pending work it is how a developer learns to
# scroll past the word.
banner_says_not "SOMETHING NEEDS FIXING" "a first run is not an alarm"

# ------------------------------------------------------------ handing over a failure
# The remedy without the diagnosis is the one shape a caller cannot recover from: it
# reads as routine. `key rejected (HTTP 401)` used to reach next.summary as "run the
# setup in your own terminal", because the handover replaced the verdict outright.
state "$(row G9 red tool "Key actually works" "key rejected by FCM (HTTP 401)")"
: > "$WS/artifacts/sa-key.json"

out="$(next_action)"
IFS="$NEXT_SEP" read -r _o _k _g _c hsum <<< "$out"
[[ "$hsum" == *"HTTP 401"* ]] \
  && ok "$(printf '%-44s %s' "the handover keeps the diagnosis" "401 survives")" \
  || bad "the handover deleted the diagnosis" "$hsum"
[[ "$hsum" == *"your own terminal"* ]] \
  && ok "$(printf '%-44s %s' "...and still says whose turn it is" "both, not either")" \
  || bad "the handover lost the remedy" "$hsum"

# Once the tool has made artifacts, a red gate downstream of them is something that
# broke — and the box has to say so before it says how to fix it.
banner_says "SOMETHING NEEDS FIXING" "a broken credential is not routine setup"
banner_says "HTTP 401" "the box states the verdict, not just the remedy"
banner_says "Key actually works" "and which gate it came from"
banner_says "only what is not done gets touched" "re-running is safe, and says so"
rm -f "$WS/artifacts/sa-key.json" "$WS/resolved.env"
DRIVER=agent

# -------------------------------------------------------------------------- done
state "$(row G16 green tool "Push arrives on device" "arrived 2s after send")"
expect none done "a push reached the device" "all green — nothing left"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — every state routes to one owner and one action."
