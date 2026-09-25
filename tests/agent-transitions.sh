#!/usr/bin/env bash
# Whether a state can be *left*. The other suites pin what the tool says at a given
# state; this one runs what it said and asks whether anything moved.
#
# That gap is where the failure this tool kept having actually lived. At G4 with both
# yeses on record, `next` reported a step whose only option re-ran a command that was
# already done: every assertion about that state passed, and an agent following it
# looped until the handoff block was the only thing left that produced output. A suite
# that checks states one at a time cannot see it, because nothing is wrong with either
# state — only with the step between them.
#
# So each case below starts from a fixture ladder and follows `next.command` the way an
# agent would: render the screen, take the recommended answer, run the commands it
# carries, read `next` again. A state that returns the same step with nothing on disk
# changed is a dead end and fails here.
#
# What it deliberately does not do: run anything that acts. The walk follows `bin/agent`
# — the recorder — and stops the moment `next` names a script that provisions, sends, or
# hands over. Arriving at `onboard --apply` is the pass condition, not a step to take.
#
# No network, no credentials, no project. The one live read in the flow (`agent
# discover`) is substituted with a canned listing, because its job here is to make a
# project "looked at" and the screens branch on whether it has been.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %-46s %s\n' "$1" "${2:-}"; }
bad() { printf '  \033[31mFAIL\033[0m %-46s %s\n' "$1" "${2:-}"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export WS="$TMP/ws"
STUB="$TMP/bin"; mkdir -p "$STUB" "$WS"

# node is real: every screen here is parsed by the same code that renders it, and a
# stubbed parser would agree with anything. The rest answer without reaching anything.
for c in adb java; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done
ln -s "$(command -v node)" "$STUB/node"
cat > "$STUB/gcloud" <<'EOF'
#!/bin/sh
[ "$*" = "config get-value account" ] && { echo dev@example.com; exit 0; }
exit 0
EOF
chmod +x "$STUB/gcloud"
export PATH="$STUB:/usr/bin:/bin"

source bin/config.sh

# Recompute from scratch each time: config.sh reads the recorded choices when it is
# sourced, so a routing decision made in this shell would be made against the state as
# it was before the walk started running commands.
next_of() { WS="$WS" bash -c 'source bin/config.sh; next_action'; }

# What has actually been recorded, as one short string. The loop guard compares this and
# nothing else: a step that comes back unchanged with an unchanged workspace is a step
# that cannot be got past, whatever its wording.
ws_digest() {
  { cat "$WS/resolved.env" "$WS/approved" "$WS/.env" 2>/dev/null
    ls "$WS" 2>/dev/null; } | shasum | cut -c1-12
}

state() { : > "$WS/state.tsv"; while (($#)); do printf '%s\n' "$1" >> "$WS/state.tsv"; shift; done; }
row()   { printf '%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "${5:-}"; }

# The commands behind the answer an agent would come back with. `recommended` is the
# tool's own pick, so walking it walks the path the tool is asking for — the one that has
# to lead somewhere. Falls back to the first option, which is the yes on every screen
# that has no recommendation.
answer_to() {
  local kind="$1" q
  q="$(bash bin/agent question "$kind" 2>/dev/null)" || return 3
  # Long enough to have read it. The approval dwell is deliberately not overridable from
  # the environment, so the walk waits the way a person does rather than asking to be
  # exempted — and a suite that had to be exempted would not be walking the real path.
  sleep 0.25
  printf '%s' "$q" | node -e '
    let s=""; process.stdin.on("data",d=>s+=d).on("end",()=>{
      const q=JSON.parse(s), o=(q.options||[]);
      const pick=o.find(x=>q.recommended&&x.label===q.recommended)||o[0];
      if(!pick){process.exit(4)}
      (pick.commands||[]).forEach(c=>console.log(c));
    })'
}

# One command from a chosen option. `discover` is the live read, substituted with the
# canned listing; `handoff` prints a block for the developer; a bare `agent` re-reads the
# ladder, which is the fixture here, so running it would overwrite the state the case is
# about. A question leads to another question on several screens — picking a different
# project is two hops — so those recurse, with a depth limit because a screen that leads
# back to itself is the thing being looked for and must not hang the suite.
run_one() {
  local cmd="$1" depth="${2:-0}" line cmds
  case "$cmd" in
    "$BIN/agent discover") cp tests/fixtures/discovered.json "$WS/discovered.json" ;;
    "$BIN/agent") ;;
    "$BIN/agent set "*|"$BIN/agent approve "*) bash $cmd >/dev/null 2>&1 || return 1 ;;
    "$BIN/agent question "*)
      ((depth < 3)) || return 0
      cmds="$(answer_to "${cmd##* }")" || return 1
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        run_one "$line" "$((depth + 1))" || return 1
      done <<< "$cmds" ;;
    *) ;;
  esac
}

# Follow `next` until it names something that acts, or until it stops moving.
walk() {
  local label="$1" step out kind gate cmd summary fp cmds line
  local -a seen=()
  for ((step = 0; step < 10; step++)); do
    out="$(next_of)"
    IFS="$NEXT_SEP" read -r _ kind gate cmd summary <<< "$out"
    # install_tools is not on this list on purpose: it outranks every gate, so a walk that
    # reaches it has learned nothing about the ladder — it has found a gap in this suite's
    # own stubs, and every case after it would pass for the same empty reason.
    case "$kind" in
      done|install_app|run_app|investigate|campaign_send)
        ok "$label" "reaches the developer's own work ($kind)"; return ;;
      install_tools)
        bad "$label" "the suite's own environment is short of $summary"; return ;;
    esac
    [[ -n "$cmd" ]] || { bad "$label" "$kind at ${gate:-?} names nothing to run"; return; }
    # Anything that is not the recorder is the end of the walk: it provisions, sends, or
    # hands over, and this suite does not run those.
    [[ "$cmd" == "$BIN/agent"* ]] || { ok "$label" "arrives at an action ($(basename "${cmd%% *}") ${cmd#* })"; return; }
    case "$cmd" in
      "$BIN/agent"|"$BIN/agent discover")
        ok "$label" "arrives at a read the developer agreed to"; return ;;
    esac
    fp="$kind|$cmd|$(ws_digest)"
    for line in ${seen[@]+"${seen[@]}"}; do
      [[ "$line" == "$fp" ]] && {
        bad "$label" "$kind comes back unchanged — ${cmd#"$BIN/"} leads to itself"; return; }
    done
    seen+=("$fp")

    case "$cmd" in
      "$BIN/agent question "*)
        cmds="$(answer_to "${cmd##* }")" || {
          bad "$label" "$kind names a screen the tool will not render: ${cmd##* }"; return; }
        [[ -n "$cmds" ]] || { bad "$label" "the answer to ${cmd##* } carries no command"; return; }
        while IFS= read -r line; do
          [[ -n "$line" ]] || continue
          run_one "$line" 1 || { bad "$label" "the chosen answer failed: $line"; return; }
        done <<< "$cmds" ;;
      *) run_one "$cmd" || { bad "$label" "the step it named failed: $cmd"; return; } ;;
    esac
  done
  bad "$label" "still asking after 10 steps"
}

reset_ws() { rm -rf "$WS"; mkdir -p "$WS"; }

echo
echo "  transitions — every state has a way out of it"
echo

# --------------------------------------------------------------- the cold start
# Nothing chosen, nothing created. The first thing a client ever runs.
reset_ws
state "$(row G0 green human "Tooling present" "ok")" \
      "$(row G1 green human "Google authenticated" "dev@example.com")" \
      "$(row G2 pending tool "GCP project exists" "no project selected yet")"
walk "cold start — nothing chosen"

# ------------------------------------------------------------ the divergence point
# The state every failed trial ended in: the Android work is done, the project has no
# app for this package, and nothing has been agreed to yet. Four questions deep, it has
# to arrive at the script that registers the app.
reset_ws
bash bin/agent set PID=proof-project PACKAGE=com.example >/dev/null
state "$(row G0 green human "Tooling present" "ok")" \
      "$(row G1 green human "Google authenticated" "dev@example.com")" \
      "$(row G2 green tool "GCP project exists" "proof-project ACTIVE")" \
      "$(row G3 green tool "Firebase enabled" "firebase enabled on proof-project")" \
      "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
walk "no app registered, nothing agreed to yet"

# Same state, one difference: they have already said the agent drives. The opening fork
# must not be re-asked, and the consent still has to be.
reset_ws
bash bin/agent set PID=proof-project PACKAGE=com.example DRIVER=agent >/dev/null
state "$(row G2 green tool "GCP project exists" "proof-project ACTIVE")" \
      "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
walk "driver recorded, consent outstanding"

# ------------------------------------------------------------------ which app
# A project on record and no package. The question is which app, and both answers to it
# — pick one that exists, or register a new one — have to reach the work.
reset_ws
bash bin/agent set PID=proof-project DRIVER=agent >/dev/null
cp tests/fixtures/discovered.json "$WS/discovered.json"
state "$(row G2 green tool "GCP project exists" "proof-project ACTIVE")" \
      "$(row G4 pending tool "Android app registered" "no package selected yet")"
walk "project chosen, no package yet"

# --------------------------------------------------------- a project that will not answer
# Not a walk: the remedy here changes which project the ladder is aimed at, and the ladder
# in this suite is a fixture that cannot come back green, so there is no move for the walk
# to observe. What is checkable is the shape — the step names a screen, the screen renders,
# and what it recommends is aiming somewhere else rather than carrying on with the project
# that just refused. It used to name no screen at all.
reset_ws
bash bin/agent set PID=nosuch-project-xyz PACKAGE=com.example >/dev/null
cp tests/fixtures/discovered.json "$WS/discovered.json"
state "$(row G1 green human "Google authenticated" "dev@example.com")" \
      "$(row G2 red tool "GCP project exists" "PERMISSION_DENIED on nosuch-project-xyz")"
IFS="$NEXT_SEP" read -r _o UKIND _g UCMD USUM <<< "$(next_of)"
if [[ "$UKIND" != project_unreachable ]]; then
  bad "a project that does not answer" "routed to $UKIND"
elif [[ -z "$UCMD" ]]; then
  bad "a project that does not answer" "names nothing to run"
elif ! UANS="$(answer_to "${UCMD##* }")"; then
  bad "a project that does not answer" "the screen it names will not render: ${UCMD##* }"
elif [[ "$UANS" != *"question pick_project"* ]]; then
  bad "a project that does not answer" "the recommended answer is not to pick again: $UANS"
elif [[ "$USUM" != *PERMISSION_DENIED* ]]; then
  bad "a project that does not answer" "the diagnosis did not survive the routing: $USUM"
else
  ok "a project that does not answer" "offers picking again, and still says why"
fi

# ------------------------------------------------------------ a credential that fails
# Not pending work: the key exists and FCM rejects it. The remedy is still a command,
# and the walk has to reach it rather than stall on the diagnosis.
reset_ws
bash bin/agent set PID=proof-project PACKAGE=com.example DRIVER=agent >/dev/null
state "$(row G2 green tool "GCP project exists" "proof-project ACTIVE")" \
      "$(row G9 red tool "Key actually works" "key rejected by FCM (HTTP 401)")"
walk "a key FCM rejects"

echo
if ((FAILED)); then
  echo "  A state with no way out ends in a handoff. That is the whole failure."
  echo
  exit 1
fi
echo "  All good — every state the walk reached could be left."
echo
