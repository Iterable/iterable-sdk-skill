#!/usr/bin/env bash
# The questions an agent asks on the tool's behalf, and the two things that make them
# worth having: they say the same thing the terminal says, and choosing one of them
# changes a file rather than a conversation.
#
# Worth its own suite because a chat window is the one front end with no menu, so these
# screens are the only place a developer sees what they are agreeing to before somebody
# else's script touches their Google project. An agent that composes the screen itself
# would pass every other test here while quietly asking a weaker question — and the
# weaker question still returns "yes".
#
# No network, no credentials, no project.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
W="$TMP/ws"; mkdir -p "$W"

# Part 1 all but done, part 2 untouched: the state in which both of these questions
# come up, and the only state in which they are the right ones to ask.
fixture() {
  printf 'G1\t%s\thuman\tsigned in to Google\tok\n' "${1:-green}" > "$W/state.tsv"
  cat >> "$W/state.tsv" <<'EOF'
G2	green	tool	project reachable	ok
G3	pending	tool	Firebase on the project	not added yet
EOF
}

# q <kind> [arg] — one question object, from a workspace with no network in reach.
q() {
  WS="$W" PID=my-proj PACKAGE=com.dogshelter bash -c '
    source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for "$@"' _ "$@"
}

# The kind next_action actually reports for that same state, so these tests ask the
# question the ladder would ask and not one chosen here to pass.
kind_now() {
  WS="$W" PID=my-proj PACKAGE=com.dogshelter bash -c '
    source bin/config.sh >/dev/null 2>&1
    IFS="$NEXT_SEP" read -r o k g c s <<< "$(next_action)"; printf %s "$k"'
}

cat > "$TMP/shape.js" <<'JS'
// Structure only — the host renders 2-4 options with a short header, so a question it
// cannot draw is a question nobody gets asked.
let s = ''; process.stdin.on('data', d => s += d).on('end', () => {
  let q; try { q = JSON.parse(s) } catch (e) { console.log('ERR not JSON: ' + e.message); process.exit(1) }
  const errs = [];
  for (const f of ['header', 'prompt', 'context', 'requires', 'recommended', 'options'])
    if (!(f in q)) errs.push('missing field: ' + f);
  // A recommendation pointing at an option that has since been reworded recommends
  // nothing, and reads to the developer as one of these being the tool's pick.
  if (q.recommended !== null && !(q.options || []).some(o => o.label === q.recommended))
    errs.push(`recommends "${q.recommended}", which is not one of the options`);
  if (q.header && q.header.length > 12) errs.push(`header "${q.header}" is ${q.header.length} chars, limit is 12`);
  if (!q.prompt || !/\?$/.test(q.prompt)) errs.push('prompt is not a question: ' + q.prompt);
  if (!Array.isArray(q.context) || !q.context.length) errs.push('no context above the selector');
  if (!Array.isArray(q.options) || q.options.length < 2 || q.options.length > 4)
    errs.push('options must number 2-4, got ' + (q.options || []).length);
  (q.options || []).forEach((o, i) => {
    if (!o.label) errs.push(`option ${i + 1} has no label`);
    if (!o.description) errs.push(`option ${i + 1} ("${o.label}") has no description`);
    if (!o.effect) errs.push(`option ${i + 1} ("${o.label}") never says what it changes`);
    if (!Array.isArray(o.commands)) errs.push(`option ${i + 1} has no commands array`);
    if (typeof o.relay !== 'string') errs.push(`option ${i + 1} has no relay field`);
    // A relay is a command only the developer can run — it takes a key with the echo
    // off. Listed as the agent's to run as well, it would be run, and the keys would go
    // through whatever is reading that output.
    if (o.relay && o.commands.length)
      errs.push(`option ${i + 1} ("${o.label}") both relays and runs: ${o.relay}`);
  });
  if (errs.length) { console.log('ERR ' + errs.join('; ')); process.exit(1) }
  console.log('OK ' + q.options.length + ' options');
});
JS

shape_ok() { # <label> <kind> [arg]
  local label="$1"; shift
  local out; out="$(q "$@" | node "$TMP/shape.js")" \
    && ok "$label — $out" || bad "$label — $out"
}

echo
echo "  Shape — a question the host can actually draw"
echo

fixture
shape_ok "the Google consent question" approve_firebase
shape_ok "the Iterable walk, at the door" iterable_keys
for n in 1 2 3 4; do shape_ok "Iterable step $n of 4" iterable_step "$n"; done

echo
echo "  The opening — answerable from a standing start"
echo

# The defect two live trials shared: every other question here is carried in a status
# read, and a status read runs the whole ladder against the developer's projects. So a
# question delivered that way arrives after the work it was asking about. This one has to
# come from nothing — which means it has to be provable that it touches nothing.
FRESH="$TMP/untouched/ws"
out="$(WS="$FRESH" bash bin/agent question opening 2>&1)"; rc=$?
((rc == 0)) && ok "bin/agent question opening works with no workspace and no state" \
  || bad "the opening question needs something to exist first: rc $rc, $out"

# The strong form. Every other entry point calls ws_init and drops eight shims into their
# repository; this one is asked before a developer has agreed to anything, so a file left
# behind is a change made by a question.
if [[ -e "$FRESH" ]]; then
  bad "asking the opening question created $(find "$FRESH" | wc -l | tr -d ' ') path(s) in the workspace"
else
  ok "and wrote nothing at all — no workspace, no shims, no .gitignore"
fi

printf '%s' "$out" | node "$TMP/shape.js" > "$TMP/o.txt" \
  && ok "the opening question — $(cat "$TMP/o.txt")" || bad "the opening question — $(cat "$TMP/o.txt")"

# It is agreeing to the job, not to the next step of it, so it has to describe the job:
# the three parts, what gets read, and that changes are a separate yes.
for want in "Three parts" "Google" "Iterable" "Device" "What it reads" "asked again" "no is a complete answer"; do
  grep -qF -- "$want" <<< "$out" && ok "the opening says '$want'" \
    || bad "the opening never mentions '$want'"
done
# The two claims a developer is entitled to before agreeing, and the two we would most
# like not to have to keep. Both are load-bearing elsewhere in this repo.
grep -qF "ask for a password" <<< "$out" \
  && ok "it rules out ever asking for a password" \
  || bad "the opening never says it will not ask for a password"
grep -qF "placeholder google-services.json" <<< "$out" \
  && ok "and rules out faking a google-services.json to get a build green" \
  || bad "the opening never rules out fabricating the config file"
# Said here rather than discovered at step 2 of 4, because "the tool will produce the API
# key" is what an agent says when nothing told it otherwise — and it cannot.
grep -qF "no endpoint creates an API key" <<< "$out" \
  && ok "and says up front that no API creates the Iterable key" \
  || bad "the opening lets the developer believe the keys get created for them"

grep -qF "stop here" <<< "$out" \
  && ok "no is one of the answers" || bad "the opening question has no way to decline"

echo
echo "  The door — the first read is asked about too"
echo

# The gap a live run found: an agent went from "provisioning is installed" to printing
# somebody's whole Firebase estate into a chat, and nothing had asked. No mutation, so
# the approval gate was never wrong — but "nothing has happened yet" was only true about
# changes, and the developer's project list had already been read and relayed.
q_door() {
  WS="$W" PID="" PACKAGE="" bash -c '
    source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for "$@"' _ "$@"
}
out="$(q_door choose_target | node "$TMP/shape.js")" \
  && ok "the read has a question of its own — $out" \
  || bad "nothing asks before the first read: $out"

door="$(q_door choose_target)"
grep -qF "writes nothing" <<< "$door" \
  && ok "and it says plainly that it is a read" \
  || bad "the door question never says the listing changes nothing"
# The one thing it must not do: borrow the provisioning banner's authority. With no
# project chosen firebase_plan is empty, so a full consent screen here would list no
# changes at all and still collect a yes — consent to an unnamed blank.
grep -qF "APPROVAL NEEDED" <<< "$door" \
  && bad "the door question dresses itself up as the provisioning approval" \
  || ok "it does not pose as the provisioning approval — that is asked later, with a plan"
grep -qF "separate question" <<< "$door" \
  && ok "and says so: changing things is asked separately" \
  || bad "nothing tells the developer a second, different question is coming"
# An out that does not require being listed. A developer who does not want their estate
# enumerated has to be able to get through anyway, or the question is a formality.
grep -qF "name the project myself" <<< "$door" \
  && ok "declining the read is still a way forward, not just an exit" \
  || bad "the only alternatives to being listed are abort — so the ask is a formality"
dcmds="$(q_door choose_target | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).options.forEach(o=>o.commands.forEach(c=>console.log(c))))')"
if grep -qE '(^|[^a-z-])(gcloud|curl) ' <<< "$dcmds"; then
  bad "an option at the door shells out to Google itself: $dcmds"
else
  ok "no option at the door runs gcloud itself — bin/agent discover does, once chosen"
fi

# Asked once, at the door. A project already on record means the listing is done.
q choose_target >/dev/null 2>&1 \
  && bad "still asking to look after a project is on record" \
  || ok "once a project is chosen, it stops asking to look"

echo
echo "  Consent — the same ask the terminal makes"
echo

# The point of pulling these two lists into functions. Either front end can be read by
# the developer, and the one that drifts is the one they happen to be looking at.
ctx="$(q approve_firebase | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).context.forEach(l=>console.log(l)))')"
plan="$(WS="$W" PID=my-proj PACKAGE=com.dogshelter bash -c 'source bin/config.sh >/dev/null 2>&1; firebase_plan | plan_bulleted')"
missing=0
while IFS= read -r l; do
  [[ -n "$l" ]] || continue
  grep -qF -- "$l" <<< "$ctx" || { bad "the question leaves out a planned change: $l"; missing=1; }
done <<< "$plan"
((missing)) || ok "every line of firebase_plan reaches the question"

lim=0
while IFS= read -r l; do
  grep -qF -- "$l" <<< "$ctx" || { bad "the question drops a stated limit: $l"; lim=1; }
done <<< "$(bash -c 'source bin/config.sh >/dev/null 2>&1; firebase_limits')"
((lim)) || ok "so does every line of firebase_limits — changes and boundary together"

for want in "Nothing has happened yet" "my-proj" "com.dogshelter" "teardown"; do
  grep -qF -- "$want" <<< "$ctx" && ok "the context says '$want'" \
    || bad "the context never mentions '$want'"
done

# Franco's own requirement, and the one clause that stops this being a rubber stamp: a
# yes that an agent could give on the developer's behalf is not consent.
fixture pending
reqs="$(q approve_firebase | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).requires.forEach(l=>console.log(l)))')"
grep -qF "gcloud auth login" <<< "$reqs" \
  && ok "it names the sign-in the developer has to do themselves" \
  || bad "the question never says who signs in to Google: $reqs"
fixture green
grep -qF "gcloud auth login" <<< "$(q approve_firebase | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).requires.forEach(l=>console.log(l)))')" \
  && bad "still asks for a sign-in that already happened — reads as work outstanding" \
  || ok "and stops naming it once G1 is green"

echo
echo "  Answers — a choice becomes a record, not a remark"
echo

cmds="$(q approve_firebase | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).options.forEach(o=>o.commands.forEach(c=>console.log(c))))')"

# The whole reason consent survives being asked in a chat. bin/provision counts calls
# to prove nothing runs before the yes; this proves the yes itself lands on disk, where
# may_drive_setup reads it, rather than staying in the transcript where it cannot.
grep -q 'agent approve firebase' <<< "$cmds" \
  && ok "the yes is recorded by the tool: bin/agent approve firebase" \
  || bad "no option records the approval — the agent's word would be the only trace"

# An agent handed this is an agent that never has to ask. It exists for CI, where there
# is no developer to ask, and that is the only place it belongs.
grep -q 'APPROVED=1' <<< "$cmds" \
  && bad "an option hands the agent APPROVED=1 — the CI form of the answer" \
  || ok "no option offers APPROVED=1"

# Selecting an option must not itself change somebody's project. It records the choice
# and re-reads the ladder; provisioning is a later step, behind the gate the record
# opens. An option that provisions inline would make the click and the change one
# event, with nothing in between that could still refuse.
if grep -qE '(^|[^a-z-])(gcloud|curl) ' <<< "$cmds"; then
  bad "an option reaches Google directly: $(grep -E '(gcloud|curl) ' <<< "$cmds" | tr '\n' ' ')"
else
  ok "no option talks to Google — they record, then the ladder is re-read"
fi

# Abort has to be a real answer. An option that quietly does something is worse than no
# option, because it is chosen by the people who wanted nothing to happen.
abort="$(q approve_firebase | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s).options.find(o=>/abort/i.test(o.label));console.log(JSON.stringify(o?o.commands:null))})')"
[[ "$abort" == "[]" ]] && ok "abort runs nothing at all" \
  || bad "the abort option runs something: $abort"

echo
echo "  When it is asked — outstanding only"
echo

fixture
rm -f "$W/resolved.env"
[[ "$(kind_now)" == choose_driver ]] \
  && ok "unanswered: next_action asks who runs it, rather than naming one of the answers" \
  || bad "unanswered: expected choose_driver, got $(kind_now)"
q "$(kind_now)" >/dev/null 2>&1 \
  && ok "and it arrives as a screen — the fork is asked, not assumed" \
  || bad "the fork is reported as the next step and never presented"

# Answered, and honoured. The terminal is reachable in one answer; it is just not the
# one given on their behalf.
printf 'DRIVER=developer\n' > "$W/resolved.env"
[[ "$(kind_now)" == run_in_terminal ]] \
  && ok "recorded as theirs: the handover becomes the step, because they asked for it" \
  || bad "a recorded DRIVER=developer does not route to the terminal: $(kind_now)"
q "$(kind_now)" >/dev/null 2>&1 \
  && ok "and the consent question rides along — 'actually, you do it' is an answer to it" \
  || bad "the developer path gets no question, so the fork cannot be reopened"

printf 'firebase my-proj\t2026-09-22 12:00\n' > "$W/approved"
q "$(kind_now)" >/dev/null 2>&1 \
  && bad "asks again after the yes is recorded — invites a second answer to a settled question" \
  || ok "once recorded, the question stops being asked"
rm -f "$W/approved" "$W/resolved.env"

# Silence for the many kinds that are work rather than a decision. A question attached
# to 'read the log' is an agent asking permission to do its job.
for k in provision send_proof done investigate; do
  q "$k" >/dev/null 2>&1 \
    && bad "$k got a question — it is work, not a decision" \
    || ok "$k: no question, just the step"
done
# Building and running carry exactly one decision, which device, and only until it is
# answered. The device screen is proved in its own section; here, that it stops.
for k in run_app install_app; do
  TARGET_DEVICE=Pixel_9_Pro q "$k" >/dev/null 2>&1 \
    && bad "$k asks something with a device already chosen — nothing is left to decide" \
    || ok "$k with a device on record: no question, just the step"
done

echo
echo "  The Iterable walk — four steps, and one rule that cannot be dropped"
echo

entry="$(q iterable_keys)"
# The one line in here that is a security boundary rather than guidance. The keys are
# typed into a 0600 file in the developer's own terminal; an agent that offers to take
# them in chat has put two live credentials in a transcript.
grep -qF "never come through this conversation" <<< "$entry" \
  && ok "the walk says the keys never come through the chat" \
  || bad "the walk never rules out taking the keys in conversation"
grep -qF "no API" <<< "$entry" \
  && ok "and says why these four are manual at all" \
  || bad "the walk asks for manual work without saying why it is manual"

# The instructions, in the question itself. They used to live only in the stdout of a
# second command, with the question's context opening "the block above is step N of 4" —
# an assertion about output the question did not produce. An agent that asked the question
# without running that command therefore showed the right options above nothing, and a
# live trial produced exactly that: a selector with invented instructions, including a
# rename this repo had already deleted. One call carries both now.
ctx() { q iterable_step "$1" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{console.log((JSON.parse(s).context||[]).join("\n"))})'; }
for n in 1 2 3 4; do
  grep -qF "Step $n of 4" <<< "$(ctx "$n")" \
    && ok "step $n carries its own clicks, not a pointer to a block" \
    || bad "step $n's question has no instructions in it — the options alone are the screen"
done
# The two substitutions that break push while everything else still reads as configured.
# They are the whole reason this walk is narrated instead of linked, so losing them from
# the relay costs more than losing the rest of it.
grep -qF "Require JWT" <<< "$(ctx 1)" \
  && ok "and the JWT-off arrow survives the relay" \
  || bad "step 1 relays without the JWT trap"
grep -qF "Data notifications" <<< "$(ctx 3)" \
  && ok "and so does the FCM type" \
  || bad "step 3 relays without the FCM-type trap"
# Nothing to type, though. The captures and the successor are options on the same screen,
# and a command printed beside the option that runs it is the terminal path in a chat's
# clothes — which is what the chat front end exists to stop being the only way.
grep -qF "iterable-keys --take" <<< "$(ctx 1)" \
  && bad "step 1's instructions hand over a command its own options already carry" \
  || ok "the relayed clicks name no command — the options do that"

# The chain, because nothing tracks which step the walk is on. Each step names its
# successor, exactly as the terminal walk does — a walk that forgets its own next step
# is a developer stranded on step 2 with nothing on screen saying more exist.
for n in 2 3; do
  grep -qF "iterable-keys --step $((n + 1))" <<< "$(q iterable_step "$n")" \
    && ok "step $n hands on to step $((n + 1))" \
    || bad "step $n names no successor"
done

# Step 1 is the exception, and on purpose: it has two values to collect, so what it hands
# on to is the next capture until both are in. Advancing while a key is missing is how a
# walk arrives at step 4 with nothing to prove anything with — the gates then fail on an
# empty key and the last thing anybody touched was three steps ago.
s1="$(q iterable_step 1)"
grep -qF "iterable-keys --take server" <<< "$s1" \
  && ok "step 1 offers to take the server-side key off the clipboard" \
  || bad "step 1 has no way to hand over the server-side key"
grep -qF "iterable-keys --take mobile" <<< "$s1" \
  && ok "step 1 offers to take the mobile key the same way" \
  || bad "step 1 has no way to hand over the mobile key"
grep -qF "iterable-keys --step 2" <<< "$s1" \
  && bad "step 1 advances with neither key stored — step 4 arrives with nothing to prove" \
  || ok "and does not advance while a key is missing"
# And it does advance, once both are in. Same screen, read against a different state:
# the walk has no memory of its own, so what moves it on is what is on disk.
printf 'ITBL_SERVER_KEY=aaaaaaaaaaaaaaaaaaaaaaaaaa\nITBL_MOBILE_KEY=bbbbbbbbbbbbbbbbbbbbbbbbbb\n' > "$W/.env"
grep -qF "iterable-keys --step 2" <<< "$(q iterable_step 1)" \
  && ok "with both keys stored, step 1 hands on to step 2" \
  || bad "both keys stored and step 1 still will not advance"
rm -f "$W/.env"
# Step 4 in both states it can be read in: with the identity recorded and without. The
# second one is where a screen with no exit used to be — the app may sign nobody in yet,
# and "I don't know" has to lead somewhere.
for st in "ITBL_EMAIL=dev@example.com" ""; do
  [[ -n "$st" ]] && printf '%s\n' "$st" > "$W/.env" || rm -f "$W/.env"
  s4="$(q iterable_step 4)"
  grep -qF "step 5" <<< "$s4" && bad "step 4 invents a fifth step" \
    || ok "step 4 invents no fifth step${st:+ (identity recorded)}"
  grep -qF "bin/onboard" <<< "$s4" \
    && ok "step 4 ends at the verifier${st:+ (identity recorded)} — proved, not trusted" \
    || bad "step 4 ends without verifying anything${st:+ (identity recorded)}"
done
rm -f "$W/.env"

# Every step keeps a way to not be done. "Done" is the developer's claim and the gates
# check it later; saying it did not work has to leave the step open rather than move past
# it. A walk whose only answer is "done" collects that answer from people who are stuck.
#
# Asserted on the effect rather than the label, because the label is different on the two
# steps that collect a value — "show it again" and "that is the wrong address" are both
# this answer — and what makes it that answer is that the walk does not move.
for n in 1 2 3 4; do
  q iterable_step "$n" | node -e '
    let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
      const o = JSON.parse(s).options.filter(o => !o.relay)
        .find(o => /still open|stays as it is/.test(o.effect || ""));
      process.exit(o ? 0 : 1);
    })' \
    || bad "step $n offers no way to say it did not work, with the step left open"
done
ok "every step leaves 'that did not work' as an answer that changes nothing"

# The one thing no screen in this walk may have: somewhere to type a key. free_text is how
# a typed answer reaches `agent set`, and a key typed there is a key in the transcript —
# so the identity, which is an email address and not a secret, is the only value in part 2
# collected that way.
for n in 1 2 3 4; do
  ft="$(q iterable_step "$n" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const q=JSON.parse(s);console.log(q.free_text?q.free_text.command:"")})')"
  case "$n" in
    4) [[ "$ft" == *"set ITBL_EMAIL="* ]] \
         && ok "step 4 takes the test identity as typed text — an address, not a secret" \
         || bad "step 4 has no way to say what address the app signs in as: '$ft'" ;;
    *) [[ -z "$ft" ]] && ok "step $n has no typed-answer field at all" \
         || bad "step $n invites typed input, and the value in front of it is a key: $ft" ;;
  esac
done
grep -qiE 'do not read the clipboard yourself' <<< "$s1" \
  && ok "and step 1 tells the agent the clipboard is not its to read either" \
  || bad "nothing stops the relaying agent reading the key straight off the clipboard"

# The exit that hands the keys to a terminal, at every step — the one place the echo is
# off. It has to be a relay and never a command, because an agent that runs it is an
# agent reading the prompts it was written to keep away from.
for n in 1 2 3 4; do
  relay="$(q iterable_step "$n" | node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s).options.find(o=>o.relay);console.log(o?o.relay:"")})')"
  [[ -n "$relay" ]] || { bad "step $n offers no way to finish in a terminal"; continue; }
  grep -q 'iterable-keys$' <<< "$relay" \
    || bad "step $n relays something other than the interactive walk: $relay"
done
ok "every step can be handed to the developer's own terminal, as a relay"

# 1-4 and nothing else: a step number from somewhere other than the chain is a bug in
# whatever asked, and inventing a screen for it hides that.
for n in 0 5 '' abc; do
  q iterable_step "$n" >/dev/null 2>&1 \
    && bad "invented a question for step '$n'" \
    || ok "step '$n' is refused rather than improvised"
done

echo
echo "  The pickers — the wizard's menus, in a chat"
echo

# The gap that produced both live trials: the wizard stops at nine screens and only two
# of them had a chat twin, so an agent reaching "pick a project" had nothing to show. It
# improvised a picker in its own words once, and handed the whole job to a terminal the
# other time. Neither was a decision to do that — it had run out of wizard.
DISC="$TMP/disc"; mkdir -p "$DISC"
node -e '
const projects = [];
for (let i = 1; i <= 12; i++) projects.push({ id: `proj-number-${i}`, name: `Project ${i}`, apps: [] });
projects[4].apps  = [{ package: "com.other.thing", appId: "1:5:android:aaa" }];
projects[7].apps  = [{ package: "com.dogshelter", appId: "1:8:android:bbb" }];
projects[10].apps = [{ package: "com.dogshelter", appId: "1:11:android:ccc" },
                     { package: "com.dogshelter.dev", appId: "1:11:android:ddd" }];
process.stdout.write(JSON.stringify({ account: "dev@example.com", projects }));
' > "$DISC/discovered.json"

# gcloud and curl, shadowed so that reaching for either is recorded and fails. Stronger
# than removing them from PATH: it proves no call was attempted, not merely that the
# screen could be drawn without one. A picker that reads somebody's account to draw its
# own menu is the one-time yes at the door being spent a second time.
QSTUB="$TMP/qstub"; mkdir -p "$QSTUB"
for c in gcloud curl; do
  printf '#!/bin/sh\necho "%s $*" >> "$QCALLS"\nexit 1\n' "$c" > "$QSTUB/$c"
  chmod +x "$QSTUB/$c"
done
QCALLS="$TMP/qcalls"; : > "$QCALLS"

# qd <kind> [pid] — a question against the cached discovery, with Google out of reach.
qd() {
  local kind="$1" pid="${2:-}"
  QCALLS="$QCALLS" WS="$DISC" PID="$pid" PACKAGE=com.dogshelter PATH="$QSTUB:$PATH" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for "$@"' _ "$kind"
}

out="$(qd pick_project | node "$TMP/shape.js")" \
  && ok "the project picker — $out" || bad "the project picker — $out"

proj="$(qd pick_project)"
# Ranked, not listed. Twelve projects and four option slots means the order is the whole
# design: a developer whose answer is on page two will type it, and one whose answer is
# ranked first will click it.
labels="$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>JSON.parse(s).options.forEach(o=>console.log(o.label)))' <<< "$proj")"
[[ "$(head -1 <<< "$labels")" == proj-number-8 || "$(head -1 <<< "$labels")" == proj-number-11 ]] \
  && ok "a project that already has the package is offered first — the path that creates nothing" \
  || bad "the zero-mutation project is not first: $(tr '\n' ' ' <<< "$labels")"
grep -qF "9 more not shown" <<< "$proj" \
  && ok "and it admits how many it left out, rather than implying that was all of them" \
  || bad "twelve projects, three shown, and nothing says so"
grep -q '"free_text"' <<< "$proj" \
  && ok "the ones it left out can still be typed" \
  || bad "no way to name a project that did not fit in the options"
grep -qF 'set PID={{answer}}' <<< "$proj" \
  && ok "and a typed answer becomes a recorded choice, not a remark" \
  || bad "the free-text answer is not wired to anything"

# The whole point of caching discover's read.
if [[ -s "$QCALLS" ]]; then
  bad "drawing the picker called Google again: $(tr '\n' ' ' < "$QCALLS")"
else
  ok "drawing it called neither gcloud nor curl — it renders the read, it does not repeat it"
fi

# Empty cache: refuse rather than draw a menu with nothing in it. An agent handed an
# empty picker fills it in itself, which is the behaviour this whole file exists to stop.
EMPTY="$TMP/empty"; mkdir -p "$EMPTY"
WS="$EMPTY" PID="" PACKAGE=com.dogshelter bash -c \
  'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for pick_project' >/dev/null 2>&1 \
  && bad "offered a project picker with nothing discovered — an empty menu invites an invented one" \
  || ok "no discovery yet, no picker: it refuses instead of drawing an empty one"

for k in pick_app register_app; do
  out="$(qd "$k" proj-number-11 | node "$TMP/shape.js")" \
    && ok "$k — $out" || bad "$k — $out"
done
WS="$DISC" PID="" PACKAGE=com.dogshelter bash -c \
  'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for pick_app' >/dev/null 2>&1 \
  && bad "asked which app before a project was chosen" \
  || ok "the app picker waits for a project to be chosen"

app="$(qd pick_app proj-number-11)"
grep -qF "applicationId" <<< "$app" \
  && ok "the app picker says to check build.gradle, not to recognise the name" \
  || bad "nothing warns that the package has to match the build"

# The one screen on the Google side that creates something. Its yes is its own, recorded
# under its own scope — the provisioning approval must not quietly include it, because the
# stated limits promise an app is never registered unless asked outright.
reg="$(qd register_app proj-number-2)"
grep -qF "approve create-app" <<< "$reg" \
  && ok "registering an app records a yes of its own scope" \
  || bad "the registration question does not record a scoped approval"
grep -q 'CREATE_APP=1' <<< "$reg" \
  && bad "an option hands the agent CREATE_APP=1 — the flag is the environment's, not the agent's" \
  || ok "no option offers CREATE_APP=1"
grep -qF "unless you ask for it outright" <<< "$reg" \
  && ok "and it says that this is the asking the limits promised" \
  || bad "the registration screen never connects itself to the promise it is honouring"

# A yes recorded for one project must not be spendable in another — the same rule the
# firebase approval already follows, and the reason approve takes a scope at all.
SC="$TMP/scope"; mkdir -p "$SC"
WS="$SC" PID=proj-a bash bin/agent approve create-app >/dev/null 2>&1
WS="$SC" PID=proj-a CREATE_APP=0 bash -c 'source bin/config.sh >/dev/null 2>&1; may_create_app' \
  && ok "the app-registration yes counts in the project it was given for" \
  || bad "a recorded create-app approval does not count"
WS="$SC" PID=proj-b CREATE_APP=0 bash -c 'source bin/config.sh >/dev/null 2>&1; may_create_app' \
  && bad "a create-app yes for proj-a authorises creating one in proj-b" \
  || ok "and not in a different project"
# proj-b deliberately: proj-a has a real record, so it would pass for the right reason
# and prove nothing about the flag.
WS="$SC" PID=proj-b CREATE_APP=0 APPROVED=1 bash -c 'source bin/config.sh >/dev/null 2>&1; approved create-app' \
  && bad "APPROVED=1 covers app creation as well — the CI form grew a second meaning" \
  || ok "APPROVED=1 covers provisioning only, not creating an app"
WS="$SC" PID=proj-b APPROVED=1 bash -c 'source bin/config.sh >/dev/null 2>&1; approved' \
  && ok "and still covers provisioning, where CI needs it" \
  || bad "APPROVED=1 stopped working for provisioning"

# Sign-in is a relay and can only be a relay. An agent that runs `gcloud auth login`
# itself is an agent sitting in the middle of somebody's Google password.
si="$(qd sign_in)"
out="$(node "$TMP/shape.js" <<< "$si")" && ok "the sign-in screen — $out" || bad "the sign-in screen — $out"
relay="$(node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s).options.find(o=>o.relay);console.log(o?o.relay:"")})' <<< "$si")"
[[ "$relay" == "gcloud auth login" ]] \
  && ok "and it hands the sign-in over rather than running it" \
  || bad "the sign-in is not relayed: '$relay'"

# The remembered target. Offered, never assumed — a run that silently reuses last week's
# project is how the wrong account gets provisioned.
kt="$(qd keep_target proj-number-8)"
out="$(node "$TMP/shape.js" <<< "$kt")" && ok "the remembered-target screen — $out" || bad "the remembered-target screen — $out"
grep -qF "proj-number-8" <<< "$kt" \
  && ok "it names what it remembered, so confirming it is a real look" \
  || bad "the confirmation does not say what is being confirmed"
qd keep_target >/dev/null 2>&1 \
  && bad "asked to confirm a remembered target when none is on record" \
  || ok "nothing remembered, nothing to confirm"

echo
echo "  The ladder's own names — a screen nothing can reach is not a screen"
echo

# next_action names these steps, and question_for has to answer to those names rather
# than to the ones the screens were written under. `sign_in` was one such: the ladder
# reports `authenticate`, so the screen existed and no status read ever produced it.
#
# A project chosen and no package yet: the state most of these kinds are reported in,
# and the one where every screen has something to say.
qdp() { WS="$DISC" PID="${2:-proj-number-8}" PACKAGE="" \
  bash -c 'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for "$1"' _ "$1"; }

for k in $(grep -o 'a_kind=[a-z_]*' bin/config.sh | cut -d= -f2 | sort -u); do
  case "$k" in
    # Work, a dead end, or nothing to decide: these are steps, not questions.
    install_tools|project_unreachable|provision|enable_firebase|investigate|\
    campaign_send|done|run_ladder|unknown|send_proof) continue ;;
  esac
  qdp "$k" >/dev/null 2>&1 \
    && ok "$k reaches a screen" \
    || bad "next_action reports $k and question_for has no screen for it"
done

# G4 and G13 both report choose_target with a project already chosen, and the question
# left at that point is which app — not whether to list projects again.
ct="$(qdp choose_target proj-number-11)"
node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>process.exit(
  ["App","New app"].includes(JSON.parse(s).header)?0:1))' <<< "$ct" \
  && ok "choose_target with a project on record asks which app, not which project" \
  || bad "choose_target after a project is chosen still asks about projects"
WS="$DISC" PID=proj-number-11 PACKAGE=com.dogshelter bash -c \
  'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for choose_target' >/dev/null 2>&1 \
  && bad "asked to choose a target when both halves are already chosen" \
  || ok "both chosen, nothing to ask"

# The creation yes needs something to have looked first. A project id typed in by hand
# has never been listed, and "PID has no app for PACKAGE" would then be the tool stating
# a fact it does not have — with a button under it that creates something.
un="$(qd register_app a-typed-project-id)"
grep -qF "approve create-app" <<< "$un" \
  && bad "offered to create an app in a project whose apps were never listed" \
  || ok "no listing, no creation yes — it offers to look first"
grep -qF "agent discover" <<< "$un" \
  && ok "and the offer to look is the option, so choosing it is the consent" \
  || bad "nothing on the screen leads to the listing it says is missing"

echo
echo "  The device — a choice, not a lookup"
echo

# adb and emulator, stubbed: two devices and a second AVD that is not running. A suite
# that needs a real phone plugged in is a suite nobody runs.
DSTUB="$TMP/dstub"; mkdir -p "$DSTUB"
cat > "$DSTUB/adb" <<'EOF'
#!/bin/sh
case "$*" in
  devices) printf 'List of devices attached\nemulator-5554\tdevice\nR58MABCDEF\tdevice\n' ;;
  "-s emulator-5554 emu avd name") echo Pixel_9_Pro ;;
  "-s R58MABCDEF shell getprop ro.product.model") echo SM-G991B ;;
  *) exit 1 ;;
esac
EOF
printf '#!/bin/sh\n[ "$*" = "-list-avds" ] && printf "Pixel_9_Pro\\nOld_Tablet\\n"\n' > "$DSTUB/emulator"
chmod +x "$DSTUB/adb" "$DSTUB/emulator"

qdev() { # <kind> [target-device]
  WS="$DISC" PID=proj-number-11 PACKAGE=com.dogshelter TARGET_DEVICE="${2:-}" PATH="$DSTUB:$PATH" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; source bin/questions.sh; question_for "$1"' _ "$1"
}

dev="$(qdev install_app)"
out="$(node "$TMP/shape.js" <<< "$dev")" && ok "the device screen — $out" || bad "the device screen — $out"
grep -qF "Pixel_9_Pro" <<< "$dev" \
  && ok "it offers the running emulator by its AVD name, not by a port number" \
  || bad "the running emulator is missing or named as emulator-5554"
grep -qF "SM-G991B" <<< "$dev" \
  && ok "and names the physical phone by its model, which is how its owner recognises it" \
  || bad "the attached phone is offered as a bare serial"
grep -qF "Old_Tablet" <<< "$dev" \
  && ok "an emulator that is not running is still choosable — starting it is part of the check" \
  || bad "a stopped AVD is not offered at all"
grep -qF 'set TARGET_DEVICE={{answer}}' <<< "$dev" \
  && ok "and a device it did not list can still be typed" \
  || bad "no way to name a device the picker missed"

# Asked even when only one device is attached — a phone left plugged in to charge
# resolves as "the only device" and takes the proof push. Not asked twice.
qdev run_app Pixel_9_Pro >/dev/null 2>&1 \
  && bad "asked which device again when one is already on record" \
  || ok "a recorded device is not re-asked: from there it is work, not a decision"

echo
echo "  The contract"
echo

# A consumer pinned to contract 3 must not be handed a new required field and told
# nothing. The question field is additive, but `next` grew, and that is the version's job.
grep -q '^CONTRACT=4' bin/agent \
  && ok "bin/agent declares contract 4" \
  || bad "the contract number was not bumped for the new next.question field"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — the tool asks, the agent renders, and the answer lands on disk."
