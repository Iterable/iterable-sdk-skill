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
export WS="$TMP/ws"; mkdir -p "$WS"

# The four binaries G0 requires, present but never called: next_action asks only
# whether they exist, and a missing one has to outrank every other answer.
#
# PATH is replaced rather than prefixed, so removing a stub really removes the
# binary. Prefixing left the developer's own adb one entry further down, and the
# missing-tool case passed by accident against a machine that had everything.
STUB="$TMP/bin"; mkdir -p "$STUB"
for c in node gcloud adb java; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done
export PATH="$STUB:/usr/bin:/bin"

source bin/config.sh

# A ladder state, written the way bin/gates writes it: id, status, owner, name, detail.
state() { : > "$WS/state.tsv"; while (($#)); do printf '%s\n' "$1" >> "$WS/state.tsv"; shift; done; }
row()   { printf '%s\t%s\t%s\t%s\t%s' "$1" "$2" "$3" "$4" "${5:-}"; }

# want: owner/kind, and optionally a substring the summary must contain.
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
  if [[ -n "$want_in" && "$summary" != *"$want_in"* ]]; then
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
expect agent choose_target "bin/agent set" "G2 red with no project — the agent asks"

# A project that is named and still unreachable is a different problem from one that
# was never chosen, and the remedy is not "pick one".
PID=some-project
state "$(row G2 red tool "GCP project exists" "PERMISSION_DENIED on some-project")"
expect human project_unreachable "PERMISSION_DENIED" "G2 red with a project named"

PID=p PACKAGE=com.example
state "$(row G4 red tool "Android app registered" "no app with packageName com.example")"
expect human register_app "CREATE_APP=1" "G4 red — creating an app stays opt-in"

for g in G5 G6 G7 G8 G9; do
  PID=p PACKAGE=com.example; state "$(row "$g" red tool "$g" "not created yet")"
  expect tool provision "" "$g red — the tool can do this part"
done

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
expect human send_proof "bin/proof-push" "G16 pending — send the proof"

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
expect agent choose_target "bin/agent set" "cold start — pick a target, not a defect"

PID=p PACKAGE=""
state "$(row G13 pending human "App installed with the SDK" "no package selected yet")"
expect agent choose_target "" "G13 pending, no package — a choice, not an install"

PID=p PACKAGE=com.example
state "$(row G10 pending human "Iterable API keys work" "no server-side key yet")"
expect human iterable_keys "" "G10 pending — same route as G10 red"

# -------------------------------------------------------------------------- done
state "$(row G16 green tool "Push arrives on device" "arrived 2s after send")"
expect none done "a push reached the device" "all green — nothing left"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — every state routes to one owner and one action."
