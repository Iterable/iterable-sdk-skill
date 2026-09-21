#!/usr/bin/env bash
# Nothing in somebody's Google project changes before they have said yes.
#
# Worth its own suite because the promise is about a call that must *not* happen, and
# that is invisible to every other test here: the skills ask the agent to ask, and an
# agent that skips the question would otherwise be the only thing between a client's
# cloud project and a script. So the refusal lives in bin/provision, and this proves
# it by counting the commands provision managed to run.
#
# No network, no credentials, no project.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/bin"; mkdir -p "$STUB"

# Every binary provision could reach, recording that it was reached. gcloud exits 1
# so the run stops at the first step rather than walking the whole ladder — what is
# being measured is whether it got that far at all.
for c in gcloud curl adb java; do
  printf '#!/bin/sh\necho "%s $*" >> "$CALLS"\nexit 1\n' "$c" > "$STUB/$c"
  chmod +x "$STUB/$c"
done
printf '#!/bin/sh\necho "node $*" >> "$CALLS"\nexit 1\n' > "$STUB/node"; chmod +x "$STUB/node"

# run <label> <ws> [env=val ...] — provision, in a workspace of its own.
provision_run() {
  local ws="$1"; shift
  mkdir -p "$ws"; : > "$ws/calls"
  CALLS="$ws/calls" PATH="$STUB:/usr/bin:/bin" WS="$ws" PID=proj PACKAGE=com.example \
    env "$@" bash bin/provision 2>&1
}

echo
echo "  Approval — the tool refuses before it asks Google anything"
echo

WS1="$TMP/unapproved"
# Handed over on purpose, because consent is what this block is about: the driver gate
# below refuses earlier and for a different reason, and that reason is tested there.
mkdir -p "$WS1"; echo "DRIVER=agent" > "$WS1/resolved.env"
out="$(provision_run "$WS1")"; rc=$?
calls="$(wc -l < "$WS1/calls" 2>/dev/null || echo 0)"

((rc == 10)) && ok "unapproved: exits 10 — blocked on a human, not a defect" \
  || bad "unapproved: expected rc 10, got $rc"

((calls == 0)) && ok "unapproved: made no calls at all" \
  || bad "unapproved: reached Google $calls time(s) — $(tr '\n' ' ' < "$WS1/calls")"

# The banner is the whole point of refusing rather than failing: a developer who is
# asked has to be able to see what they would be agreeing to, and where the key goes.
for want in "APPROVAL NEEDED" "proj" "com.example" "service account" "send push and do nothing else" "0600" "teardown"; do
  grep -qF -- "$want" <<< "$out" && ok "the banner says '$want'" \
    || bad "the banner never mentions '$want'"
done
# The other half of an honest ask: what it will leave alone. A list of changes with
# no boundary reads as open-ended access to the project.
grep -qF "unless you ask outright" <<< "$out" \
  && ok "the banner also says what it will not touch" \
  || bad "the banner lists changes without saying what it leaves alone"

echo
WS2="$TMP/ci-approved"
provision_run "$WS2" APPROVED=1 >/dev/null 2>&1
calls="$(wc -l < "$WS2/calls" 2>/dev/null || echo 0)"
((calls > 0)) && ok "APPROVED=1: gets past the gate (the CI form of the answer)" \
  || bad "APPROVED=1: still made no calls — the gate is unconditional"

# The agent path records the answer instead of passing an environment variable, and
# provision has to accept that form too or the two front ends disagree about consent.
WS3="$TMP/agent-approved"; mkdir -p "$WS3"
rec="$(CALLS="$WS3/calls" PATH="$STUB:/usr/bin:/bin" WS="$WS3" PID=proj PACKAGE=com.example \
  bash bin/agent approve firebase 2>&1)"; rrc=$?
((rrc == 0)) && grep -q '"approved":true' <<< "$rec" \
  && ok "agent approve firebase records it: $(tr -d '\n' <<< "$rec" | cut -c1-72)" \
  || bad "agent approve firebase returned rc $rrc: $rec"
# A recorded yes answers *whether*, and the driver gate below answers *who* — so this
# needs both records to get through, and that is the intended reading of consent from
# a chat: they agreed to the changes and they agreed to you making them.
echo "DRIVER=agent" >> "$WS3/resolved.env"
provision_run "$WS3" >/dev/null 2>&1
calls="$(wc -l < "$WS3/calls" 2>/dev/null || echo 0)"
((calls > 0)) && ok "a recorded yes gets past the gate too" \
  || bad "the recorded approval was not honoured by provision"

# An approval that names no project covers everything, which is the one thing it must
# never do.
WS4="$TMP/no-project"; mkdir -p "$WS4"
out="$(PATH="$STUB:/usr/bin:/bin" WS="$WS4" PID="" bash bin/agent approve firebase 2>&1)"; rc=$?
((rc == 30)) && grep -q 'no project chosen' <<< "$out" \
  && ok "refuses to record a yes with no project named" \
  || bad "approving with no project gave rc $rc: $out"

echo
echo "  Driver — the actor refuses setup the developer never handed over"
echo

# Twice in one day, an agent ran the setup itself while the router was telling it to
# hand over. Routing is advice to whoever reads it; this is the part that cannot be
# skipped by not reading. Neither case here has a tty, which is what a chat tool looks
# like from inside the script.
WS5="$TMP/env-driver"
out="$(provision_run "$WS5" DRIVER=agent APPROVED=0)"; rc=$?
calls="$(wc -l < "$WS5/calls" 2>/dev/null || echo 0)"

((rc == 10 && calls == 0)) \
  && ok "DRIVER=agent in the environment authorises nothing — rc 10, no calls" \
  || bad "an environment variable got past the driver gate: rc $rc, $calls call(s)"

grep -qF "RUN THIS IN YOUR TERMINAL" <<< "$out" \
  && ok "the refusal is the handoff block — it says where to go instead" \
  || bad "refused without telling anyone what to do instead: $out"

# Order matters: asked for approval first, an agent collects permission for work that
# was never its to do, and the developer reads that as having been consulted.
grep -qF "APPROVAL NEEDED" <<< "$out" \
  && bad "asked for approval before refusing — consent for somebody else's job" \
  || ok "does not ask for consent it has no use for"

# The recorded form is the developer's own choice, and it does work.
WS6="$TMP/recorded-driver"; mkdir -p "$WS6"
echo "DRIVER=agent" > "$WS6/resolved.env"
provision_run "$WS6" APPROVED=1 >/dev/null 2>&1
calls="$(wc -l < "$WS6/calls" 2>/dev/null || echo 0)"
((calls > 0)) && ok "a recorded DRIVER=agent gets through — they can still delegate it" \
  || bad "the recorded driver choice was refused as well: nothing can provision"

# The helper itself, because bin/onboard --apply guards on it at its own call site.
drive_check() { WS="$1" PATH="$STUB:/usr/bin:/bin" bash -c '
  source bin/config.sh >/dev/null 2>&1; may_drive_setup' < /dev/null; }
WS7="$TMP/helper"; mkdir -p "$WS7"
drive_check "$WS7" && bad "may_drive_setup allows a bare non-tty caller" \
  || ok "may_drive_setup: no tty, no record, no"
echo "DRIVER=developer" > "$WS7/resolved.env"
drive_check "$WS7" && bad "may_drive_setup allows DRIVER=developer" \
  || ok "may_drive_setup: recorded as the developer's job, still no"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — no yes, no calls."
