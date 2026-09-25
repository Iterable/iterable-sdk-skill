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

grep -qF "THIS PART IS YOURS TO RUN" <<< "$out" \
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
echo "  The read of their account — a signed-in gcloud is not a yes"
echo

# Three live transcripts ended the same way: the agent saw gcloud already authenticated,
# listed every Firebase project the account could see, and printed them into the
# conversation. Nothing was mutated, which is why prose never held it — the skill said
# "ask next.question before you run anything" and the command ran anyway. So the listing
# refuses here too, and this counts the HTTP calls it managed to make.
#
# A gcloud that answers, because the gate sits behind the token check and is scoped to
# whichever account is active.
gstub() { # <account>
  cat > "$STUB/gcloud" <<EOF
#!/bin/sh
echo "gcloud \$*" >> "\$CALLS"
[ "\$1 \$2" = "auth print-access-token" ] && { echo ya29.stub; exit 0; }
[ "\$* " = "config get-value account " ] && { echo "$1"; exit 0; }
exit 1
EOF
  chmod +x "$STUB/gcloud"
}
# curl records and fails, so "got past the gate" shows up as an attempted read rather
# than as a result. node too: a listing that parses nothing still asked.
http_calls() { local n; n="$(grep -cE '^(curl|node)' "$1/calls" 2>/dev/null)"; printf '%s' "${n:-0}"; }

discover_run() { local ws="$1"; shift
  mkdir -p "$ws"; : > "$ws/calls"
  CALLS="$ws/calls" PATH="$STUB:/usr/bin:/bin" WS="$ws" \
    env "$@" bash bin/discover --json 2>&1 < /dev/null
}

gstub "dev@example.com"
WS9="$TMP/unasked"
out="$(discover_run "$WS9")"; rc=$?
((rc == 10)) && ok "no yes on record: exits 10 — blocked on a human" \
  || bad "unasked listing: expected rc 10, got $rc — $out"
(( $(http_calls "$WS9") == 0 )) && ok "no yes on record: read nothing at all" \
  || bad "listed the account anyway: $(tr '\n' ' ' < "$WS9/calls")"

# The refusal names the *question*, not the command that records its answer. Handed
# `approve list` at the moment of being blocked, an agent takes it — which is the
# accidental-consent failure this whole gate exists to stop, one indirection later.
grep -qF "question choose_target" <<< "$out" \
  && ok "and it says to ask the screen that exists for this" \
  || bad "refused without naming the question: $out"
grep -qF "approve list" <<< "$out" \
  && bad "the refusal hands over the command that records the yes" \
  || ok "and does not hand over the yes itself"

# --------------------------------------------------- the yes needs a screen behind it
#
# A gate an agent can satisfy by running the command it was just told about is a gate that
# only stops the careless. So the yes carries a one-time token that only rendering the
# question produces, and it has to arrive slowly enough for somebody to have read what
# they were agreeing to. Neither proves a human answered — nothing local can, because in a
# chat the agent is the only thing typing — but together they rule out the two ways it has
# actually gone wrong: recording a yes for a screen nobody put up, and putting the screen
# up and answering it in the same breath.
agent_run() { local ws="$1"; shift
  mkdir -p "$ws"; : > "$ws/calls"
  CALLS="$ws/calls" PATH="$STUB:/usr/bin:/bin" WS="$ws" bash bin/agent "$@" 2>&1 < /dev/null
}

WS10="$TMP/asked"; mkdir -p "$WS10"; : > "$WS10/calls"
out="$(agent_run "$WS10" approve list)"; rc=$?
((rc == 10)) && grep -q 'no screen for this has been put up' <<< "$out" \
  && ok "no screen was ever rendered: the yes is refused, rc 10" \
  || bad "recorded a yes for a question nobody asked: rc $rc, $out"

# Rendering the screen is what produces the token, and the token appears in exactly one
# place: the command the developer's own choice runs.
q="$(agent_run "$WS10" question choose_target)"
TOK="$(cut -f1 "$WS10/asked/choose_target" 2>/dev/null)"
[[ "$TOK" =~ ^[0-9a-f]{32}$ ]] && ok "rendering the question mints a token" \
  || bad "no token was minted: '$TOK'"
grep -qF -- "--asked $TOK" <<< "$q" \
  && ok "and the screen's first option carries it" \
  || bad "the token never reached the option's command"

# The dwell. Chained straight off the render this is tens of milliseconds, and the whole
# point is that a human cannot read a five-paragraph consent screen in that time.
out="$(agent_run "$WS10" approve list --asked "$TOK")"; rc=$?
((rc == 10)) && grep -q 'faster than anybody could have read it' <<< "$out" \
  && ok "answered in the same breath as the question: refused, and says why" \
  || bad "a yes recorded milliseconds after the ask was accepted: rc $rc, $out"

# A wrong token is a different refusal from a missing screen, because it means something
# else: the question moved on, and this is answering a screen nobody is looking at.
out="$(agent_run "$WS10" approve list --asked 00000000000000000000000000000000)"; rc=$?
((rc == 10)) && grep -q 'not the token the screen carried' <<< "$out" \
  && ok "a token that does not match is told apart from no screen at all" \
  || bad "wrong token gave rc $rc: $out"

sleep 0.3
rec="$(agent_run "$WS10" approve list --asked "$TOK")"; rrc=$?
((rrc == 0)) && grep -q '"approved":true' <<< "$rec" \
  && ok "the real thing goes through: $(tr -d '\n' <<< "$rec" | cut -c1-58)" \
  || bad "a properly asked yes was refused: rc $rrc, $rec"

# One rendering, one yes. Otherwise a token read out of an old transcript keeps working.
out="$(agent_run "$WS10" approve list --asked "$TOK")"; rc=$?
((rc == 10)) && ok "and the token is spent — one screen buys one yes" \
  || bad "the same token was accepted twice: rc $rc"

discover_run "$WS10" >/dev/null 2>&1
(( $(http_calls "$WS10") > 0 )) && ok "with the yes on record, the read goes ahead" \
  || bad "the recorded yes was not honoured — nothing can ever list"

# Scoped to the account, because that is what was agreed to. The workspace outlives a
# `gcloud config set account`, and a yes for one person's estate is not a yes for the
# next one's.
gstub "someone.else@example.com"
out="$(discover_run "$WS10")"; rc=$?
((rc == 10)) && ok "a different account is asked again — the yes named the first one" \
  || bad "the yes carried over to another Google account: rc $rc"
gstub "dev@example.com"

# An unscoped yes would cover every account this workspace is ever pointed at.
cat > "$STUB/gcloud" <<'EOF'
#!/bin/sh
echo "gcloud $*" >> "$CALLS"
[ "$1 $2" = "auth print-access-token" ] && { echo ya29.stub; exit 0; }
exit 1
EOF
chmod +x "$STUB/gcloud"
WS11="$TMP/no-account"; mkdir -p "$WS11"
out="$(CALLS="$WS11/calls" PATH="$STUB:/usr/bin:/bin" WS="$WS11" bash bin/agent approve list 2>&1)"; rc=$?
((rc == 30)) && ok "refuses to record a yes with no account to scope it to" \
  || bad "recorded an unscoped listing approval: rc $rc, $out"
gstub "dev@example.com"

# The helper and the read itself, because bin/discover guards at its call site and a
# caller added later will not.
list_check() { WS="$1" CALLS="$1/calls" PATH="$STUB:/usr/bin:/bin" bash -c '
  source bin/config.sh >/dev/null 2>&1; may_list_projects' < /dev/null; }
WS12="$TMP/list-helper"; mkdir -p "$WS12"; : > "$WS12/calls"
list_check "$WS12" && bad "may_list_projects allows a bare non-tty caller" \
  || ok "may_list_projects: no tty, no record, no"
WS="$WS12" CALLS="$WS12/calls" PATH="$STUB:/usr/bin:/bin" APPROVED=1 bash -c '
  source bin/config.sh >/dev/null 2>&1; may_list_projects' < /dev/null \
  && ok "may_list_projects: APPROVED=1 is the CI form of the same answer" \
  || bad "the CI form cannot list, so no pipeline can run this at all"

: > "$WS12/calls"
WS="$WS12" CALLS="$WS12/calls" PATH="$STUB:/usr/bin:/bin" bash -c '
  source bin/config.sh >/dev/null 2>&1; firebase_projects' < /dev/null >/dev/null 2>&1
rc=$?
((rc == 10)) && ok "firebase_projects refuses on its own — rc 10, not 'Google said no'" \
  || bad "firebase_projects listed without a yes: rc $rc"
(( $(http_calls "$WS12") == 0 )) && ok "and made no call while refusing" \
  || bad "firebase_projects reached the network before refusing"

echo
echo "  A pasted value cannot grant its own consent"
echo

# The pickers offer a free-text option, so a project id typed into a chat reaches
# `agent set PID=…`. resolved.env is read line by line and the reader honours whatever
# key it finds, so a value with a line break in it used to write a second setting —
# APPROVED=1 — which approved() reads as a yes, on that run and every one after it.
# Verified as a live bypass before this existed: approved() returned true with no
# approval file on disk at all.
WS8="$TMP/pasted"; mkdir -p "$WS8"
out="$(WS="$WS8" bash bin/agent set "PID=fine
APPROVED=1" 2>&1)"; rc=$?
((rc == 30)) && ok "a value spanning two lines is refused, not trimmed and stored" \
  || bad "a multi-line paste was accepted: rc $rc, $out"
grep -qF "APPROVED" "$WS8/resolved.env" 2>/dev/null \
  && bad "APPROVED=1 reached resolved.env from a pasted project id" \
  || ok "and nothing of it reached the file"

# The stronger form, independent of how the line got there: a hand-edited workspace, a
# stale file, a future writer. Consent on disk is the approval record, which names the
# project it covers; APPROVED is the CI form and belongs to the environment.
printf 'APPROVED=1\n' > "$WS8/resolved.env"
WS="$WS8" PID=proj bash -c 'source bin/config.sh >/dev/null 2>&1; approved' \
  && bad "APPROVED=1 in resolved.env grants consent — a file said yes for the developer" \
  || ok "APPROVED=1 in the workspace is ignored: only the environment can say it"
WS="$WS8" PID=proj APPROVED=1 bash -c 'source bin/config.sh >/dev/null 2>&1; approved' \
  && ok "and the CI form still works from the environment, where a pipeline sets it" \
  || bad "the CI approval path broke"

# workspace/.env is the same shape of file and the worse case: it is read below every
# function here, so while it was `source`d a line of it could redefine approved() and
# grant a yes with no approval record on disk. Reproduced as a live bypass.
rm -f "$WS8/resolved.env"
cat > "$WS8/.env" <<'ENVEOF'
approved() { return 0; }
APPROVED=1
ITBL_SERVER_KEY=from_the_file
ENVEOF
WS="$WS8" PID=proj bash -c 'source bin/config.sh >/dev/null 2>&1; approved firebase' \
  && bad ".env redefined approved() — a pasted-keys file can forge consent" \
  || ok ".env cannot redefine approved(): it is read as key=value, never executed"
WS="$WS8" PID=proj bash -c 'source bin/config.sh >/dev/null 2>&1; [[ "${APPROVED:-0}" == 1 ]]' \
  && bad "APPROVED=1 in .env was honoured" \
  || ok "and APPROVED in .env is ignored, as in resolved.env"
# iterable-keys writes into that file that an exported key "wins over this file", and
# the template it writes has the keys empty — so `source` clobbered the shell's value.
out="$(WS="$WS8" ITBL_SERVER_KEY=from_the_shell bash -c \
  'source bin/config.sh >/dev/null 2>&1; printf %s "$ITBL_SERVER_KEY"')"
[[ "$out" == from_the_shell ]] \
  && ok "a key exported in the shell wins over .env, which is what .env says it does" \
  || bad "the .env value beat the shell export: got '$out'"
rm -f "$WS8/.env"

# Format, not just line breaks. The mistake a pasting developer actually makes is the
# display name, which is why that error says so rather than just refusing.
for bad_pid in "My Dog Shelter" "UPPER-case" "-leading" "sh"; do
  WS="$WS8" bash bin/agent set "PID=$bad_pid" >/dev/null 2>&1 \
    && bad "accepted '$bad_pid' as a project id" \
    || ok "refuses '$bad_pid' as a project id"
done
WS="$WS8" bash bin/agent set PID=dog-shelter-ai-one-shot >/dev/null 2>&1 \
  && ok "and a real project id goes through" || bad "a valid project id was refused"
WS="$WS8" bash bin/agent set PACKAGE=dogshelter >/dev/null 2>&1 \
  && bad "accepted 'dogshelter' as a package name" \
  || ok "refuses a package name with no dot in it"
WS="$WS8" bash bin/agent set PACKAGE=com.dogshelter >/dev/null 2>&1 \
  && ok "and a real package name goes through" || bad "a valid package name was refused"

# Nothing grants itself the right to create an app. An outside audit found the wizard
# exporting CREATE_APP=1 for any project whose G4 was not green, which made one
# "Go ahead?" the answer to two questions — and the second one is the change the stated
# limits promise never happens unless the developer asks for it outright.
for f in bin/wizard bin/agent bin/provision bin/onboard bin/questions.sh; do
  grep -qE '(export +)?CREATE_APP=1' "$f" \
    && bad "$f sets CREATE_APP=1 itself — the flag is the environment's, for a run with nobody in it" \
    || ok "$(basename "$f") never grants itself app creation"
done
grep -qF 'approve create-app' bin/wizard \
  && ok "and the wizard asks for it and records the answer, like every other front end" \
  || bad "the wizard has no scoped create-app approval at all"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — no yes, no calls."
