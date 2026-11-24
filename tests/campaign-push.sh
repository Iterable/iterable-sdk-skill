#!/usr/bin/env bash
# bin/proof-push --campaign: the send that gives G17 a pushSend to match. It creates
# things in somebody's Iterable project, so nothing goes out without a recorded yes,
# and it records the same marker and send time as the template proof so G16 and G17
# read the same push.
#
# No network, no credentials, no device: curl and adb are stubs that record each call.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/bin"; mkdir -p "$STUB"
export STUB_CALLS="$TMP/calls"
KEY="srvkey-canary-5f1e0c9d7b3a"

cat > "$STUB/curl" <<'CURL'
#!/usr/bin/env bash
cat >/dev/null
method="" data="" url=""
while (($#)); do
  case "$1" in
    -X) method="$2"; shift ;;
    -d) data="$2"; shift ;;
    http*) url="$1" ;;
  esac
  shift
done
path="${url#https://api.iterable.com}"
printf '%s %s %s\n' "$method" "$path" "$data" >> "$STUB_CALLS"
HTML='<html><body>502 Bad Gateway</body></html>'
[[ -n "${STUB_TEMPLATES:-}" ]] || STUB_TEMPLATES='{"templates":[]}'
[[ -n "${STUB_CREATE:-}" ]] || STUB_CREATE='{"campaignId":21086024}'
if [[ -n "${STUB_HTML:-}" && "${path%%\?*}" == "$STUB_HTML" ]]; then printf '%s\n200' "$HTML"; exit 0; fi
case "$path" in
  /api/campaigns)            printf '{"campaigns":[]}\n200' ;;
  /api/templates\?*)         printf '%s\n200' "$STUB_TEMPLATES" ;;
  /api/channels)             printf '%s\n200' "$STUB_CHANNELS" ;;
  /api/messageTypes)         printf '%s\n200' "$STUB_TYPES" ;;
  /api/templates/push/upsert) printf '{"msg":"Upserted 1 templates with IDs: 28203359","code":"Success"}\n200' ;;
  /api/templates/push/update)
    if [[ -n "${STUB_UPDATE_FAIL:-}" ]]; then printf '{"msg":"Internal error","code":"GenericError"}\n500'
    else printf '{"msg":"Updated template 28203359","code":"Success"}\n200'; fi ;;
  /api/templates/push/proof)  printf '{"msg":"ok"}\n200' ;;
  /api/campaigns/create)     printf '%s\n200' "$STUB_CREATE" ;;
  /api/campaigns/activateTriggered)
    if [[ -n "${STUB_NO_ACTIVATE:-}" ]]; then
      printf '{"msg":"API triggered campaign activation is not enabled for your project","code":"Forbidden"}\n403'
    elif [[ -n "${STUB_ACTIVATE_ERR:-}" ]]; then
      printf '%s\n400' "$STUB_ACTIVATE_ERR"
    else
      printf '{"msg":"Activated triggered campaign","code":"Success"}\n200'
    fi ;;
  /api/push/target)
    if [[ -n "${STUB_TARGET_FAIL:-}" ]]; then printf '{"msg":"Internal error","code":"GenericError"}\n500'
    else printf '{"msg":"Sent triggered message","code":"Success"}\n200'; fi ;;
  /api/campaigns/archive)
    ids="$(sed -n 's/.*\[\(.*\)\].*/\1/p' <<< "$data")"
    [[ -n "${STUB_ARCHIVE:-}" ]] || STUB_ARCHIVE="{\"success\":[$ids],\"failed\":[]}"
    printf '%s\n200' "$STUB_ARCHIVE" ;;
  /api/campaigns/[0-9]*)
    if [[ -n "${STUB_CAMPAIGN:-}" ]]; then printf '%s\n%s' "$STUB_CAMPAIGN" "${STUB_CAMPAIGN_CODE:-200}"
    else printf '\n404'; fi ;;
  *)                         printf '{"msg":"unexpected path"}\n404' ;;
esac
CURL
printf '#!/usr/bin/env bash\n[[ "$1" == devices ]] && echo "List of devices attached"\nexit 0\n' > "$STUB/adb"
chmod +x "$STUB/curl" "$STUB/adb"

TX_CHANNELS='{"channels":[{"id":153609,"name":"Push Marketing Channel","channelType":"Marketing","messageMedium":"Push"},{"id":153610,"name":"Push Transactional","channelType":"Transactional","messageMedium":"Push"},{"id":153608,"name":"Transactional Channel","channelType":"Transactional","messageMedium":"Email"}]}'
TX_TYPES='{"messageTypes":[{"id":199959,"name":"Push Marketing Message","channelId":153609},{"id":199961,"name":"Push Transactional Message","channelId":153610},{"id":199958,"name":"Transactional Message","channelId":153608}]}'
MKT_CHANNELS='{"channels":[{"id":153609,"name":"Push Marketing Channel","channelType":"Marketing","messageMedium":"Push"},{"id":153608,"name":"Transactional Channel","channelType":"Transactional","messageMedium":"Email"}]}'
MKT_TYPES='{"messageTypes":[{"id":199959,"name":"Push Marketing Message","channelId":153609},{"id":199958,"name":"Transactional Message","channelId":153608}]}'
export STUB_CHANNELS="$TX_CHANNELS" STUB_TYPES="$TX_TYPES"
BASE_TEMPLATE='{"templates":[{"templateId":28203359,"name":"Iterable onboard campaign proof","clientTemplateId":"itbl-onboard-campaign-proof","messageTypeId":199961}]}'
campaign() { printf '{"id":%s,"name":"Iterable onboard campaign proof","type":"Triggered","campaignState":"%s","messageMedium":"Push"}' "$1" "$2"; }

ALL_OUT="$TMP/all-output"
# run <ws> [VAR=value ...] -- <args to proof-push>
run() {
  local ws="$TMP/ws-$1"; shift
  local -a vars=()
  while [[ "$1" != -- ]]; do vars+=("$1"); shift; done; shift
  mkdir -p "$ws"; : > "$STUB_CALLS"
  OUT="$(env -u ITBL_EMAIL -u ITBL_USER_ID -u ITBL_CAMPAIGN_ID -u ITBL_PROOF_MARKER -u ITBL_PROOF_SENT_AT -u APPROVED \
    -u ITBL_PROOF_CAMPAIGN_ID -u ITBL_PROOF_CAMPAIGN_SENT -u ITBL_PROOF_CAMPAIGN_STALE \
    PATH="$STUB:$PATH" WS="$ws" PACKAGE=com.example.app ITBL_SERVER_KEY="$KEY" DEVICE_WAIT=0 \
    ${vars[@]+"${vars[@]}"} bin/proof-push "$@" < /dev/null 2>&1)"; RC=$?
  printf '%s\n' "$OUT" >> "$ALL_OUT"
  CALLS="$(cat "$STUB_CALLS")"
}
approve_in() {
  mkdir -p "$TMP/ws-$1"
  env -u APPROVED PATH="$STUB:$PATH" WS="$TMP/ws-$1" ITBL_SERVER_KEY="$KEY" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; approve campaign'
}
resolved() { sed -n "s/^$2=//p" "$TMP/ws-$1/resolved.env" 2>/dev/null; }
seed()     { local ws="$1"; shift; mkdir -p "$TMP/ws-$ws"; printf '%s\n' "$@" >> "$TMP/ws-$ws/resolved.env"; }
called()   { grep -qF "$1" <<< "$CALLS"; }
line_of()  { grep -nF "$1" <<< "$CALLS" | head -1 | cut -d: -f1; }
listed()   { grep -qE '^GET /api/campaigns( |\?)' <<< "$CALLS"; }

echo
echo "  Campaign proof send — stubbed Iterable, no device"
echo

# ---------------------------------------------------------------- consent
run noyes ITBL_EMAIL=dev@example.com -- --campaign
((RC == 10)) && [[ -z "$CALLS" ]] \
  && ok "no recorded yes: rc 10 and not one call to Iterable" \
  || bad "no recorded yes: rc $RC, calls: ${CALLS:-none}"
grep -qF 'approve campaign' <<< "$OUT" \
  && ok "and it names the approval it is waiting for" \
  || bad "the refusal does not say how to get a yes: $OUT"
[[ -z "$(resolved noyes ITBL_CAMPAIGN_ID)$(resolved noyes ITBL_PROOF_MARKER)" ]] \
  && ok "and records no campaign and no marker" \
  || bad "a refused run recorded state: $(cat "$TMP/ws-noyes/resolved.env")"

run noyes-ci ITBL_EMAIL=dev@example.com APPROVED=1 -- --campaign
((RC == 10)) && [[ -z "$CALLS" ]] \
  && ok "APPROVED=1 is not a yes to creating a campaign" \
  || bad "APPROVED=1 let campaign mode through: rc $RC, calls: ${CALLS:-none}"

approve_in otherkey
run otherkey ITBL_EMAIL=dev@example.com ITBL_SERVER_KEY=srvkey-some-other-project -- --campaign
((RC == 10)) && [[ -z "$CALLS" ]] \
  && ok "a yes given for another server key makes no calls" \
  || bad "a yes for another key was honoured: rc $RC, calls: ${CALLS:-none}"

# ---------------------------------------------------------------- the first send
approve_in email
run email ITBL_EMAIL=dev@example.com -- --campaign
marker="$(resolved email ITBL_PROOF_MARKER)"
((RC == 0)) && called 'POST /api/campaigns/create {"name":"Iterable onboard campaign proof","templateId":28203359}' \
  && called 'POST /api/campaigns/activateTriggered {"campaignId":21086024}' \
  && ok "approved: creates the campaign from the base template and activates it" \
  || bad "first send: rc $RC, out: $OUT, calls: $CALLS"
grep -F 'POST /api/templates/push/upsert' <<< "$CALLS" | grep -qF '"messageTypeId":199961' \
  && grep -F 'POST /api/templates/push/upsert' <<< "$CALLS" | grep -qF '{{marker}}' \
  && ok "the base template uses the transactional push type and carries {{marker}}" \
  || bad "template upsert: $(grep upsert <<< "$CALLS")"
called "POST /api/push/target {\"campaignId\":21086024,\"recipientEmail\":\"dev@example.com\",\"dataFields\":{\"marker\":\"$marker\"}}" \
  && ok "push/target sends to recipientEmail with this run's marker" \
  || bad "push/target body: $(grep push/target <<< "$CALLS")"
[[ "$marker" =~ ^itbl-onboard-[0-9]+$ && "$(resolved email ITBL_PROOF_SENT_AT)" =~ ^[0-9]{13}$ ]] \
  && [[ "$(resolved email ITBL_CAMPAIGN_ID)" == 21086024 && "$(resolved email ITBL_PROOF_CAMPAIGN_ID)" == 21086024 ]] \
  && ok "records ITBL_PROOF_MARKER, ITBL_PROOF_SENT_AT, ITBL_CAMPAIGN_ID and the proof campaign" \
  || bad "recorded: $(tr '\n' ' ' < "$TMP/ws-email/resolved.env")"
! called '/api/campaigns/archive' \
  && ok "nothing is archived in the run that sends, so the queued push is not aborted" \
  || bad "archived in the sending run: $CALLS"
! listed \
  && ok "and it never lists the project's campaigns" \
  || bad "listed campaigns: $CALLS"

run email ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" STUB_CREATE='{"campaignId":21086031}' -- --campaign
a="$(line_of 'POST /api/campaigns/archive {"campaignIds":[21086024]}')" t="$(line_of '"campaignId":21086031,"recipientEmail"')"
((RC == 0)) && called 'GET /api/campaigns/21086024' && [[ -n "$a" && -n "$t" ]] && ((a > t)) \
  && ! called 'archive {"campaignIds":[21086031]}' \
  && ok "the next run sends through a new campaign, and only then archives the last run's" \
  || bad "next run: rc $RC, calls: $CALLS"
grep -qF 'Archived campaign 21086024' <<< "$OUT" && [[ "$(resolved email ITBL_PROOF_CAMPAIGN_ID)" == 21086031 ]] \
  && [[ -z "$(resolved email ITBL_PROOF_CAMPAIGN_STALE)" ]] \
  && ok "and says so, and records the new campaign" \
  || bad "next run output: $OUT, resolved: $(tr '\n' ' ' < "$TMP/ws-email/resolved.env")"

approve_in uid; run uid ITBL_USER_ID=u-0a1b2c -- --campaign
grep -F 'POST /api/push/target' <<< "$CALLS" | grep -qF '"recipientUserId":"u-0a1b2c"' \
  && ! grep -F 'POST /api/push/target' <<< "$CALLS" | grep -qF recipientEmail \
  && ok "a userId identity is targeted with recipientUserId, not recipientEmail" \
  || bad "userId target body: $(grep push/target <<< "$CALLS")"

# ---------------------------------------------------------------- --keep-campaign
approve_in keep; run keep ITBL_EMAIL=dev@example.com -- --campaign --keep-campaign
((RC == 0)) && called 'POST /api/push/target' && ! called '/api/campaigns/archive' \
  && ok "--keep-campaign sends and archives nothing" \
  || bad "--keep-campaign: rc $RC, calls: $CALLS"
run keep ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" -- --campaign --keep-campaign
((RC == 0)) && ! called create && ! called activateTriggered && ! called upsert && ! called archive \
  && called '"campaignId":21086024,"recipientEmail"' \
  && ok "and the next --keep-campaign run reuses it: no template, no create, no activate" \
  || bad "keep reuse: rc $RC, calls: $CALLS"
approve_in keepstale
seed keepstale ITBL_PROOF_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
run keepstale ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" STUB_CHANNELS="$MKT_CHANNELS" STUB_TYPES="$MKT_TYPES" -- --campaign
r1=$RC s1="$(resolved keepstale ITBL_PROOF_CAMPAIGN_STALE)"
run keepstale ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" -- --campaign --keep-campaign
((r1 == 10 && RC == 0)) && [[ "$s1" == 21086024 ]] && called '"campaignId":21086024,"recipientEmail"' && ! called archive \
  && ok "--keep-campaign never archives the campaign it sends through, even when an earlier run queued it" \
  || bad "keep after a queued archive: run 1 rc $r1 stale '$s1', run 2 rc $RC, calls: $CALLS"

# ---------------------------------------------------------------- the recorded campaign
approve_in gone
seed gone ITBL_PROOF_CAMPAIGN_ID=21086000
run gone ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086000 Archived)" -- --campaign
((RC == 0)) && called create && ! called '"campaignId":21086000' && ! called archive \
  && ok "a recorded campaign that is no longer Ready or Running is left alone and replaced" \
  || bad "archived recorded campaign: rc $RC, calls: $CALLS"
run gone ITBL_EMAIL=dev@example.com STUB_CAMPAIGN='{"msg":"unavailable"}' STUB_CAMPAIGN_CODE=500 -- --campaign
((RC == 1)) && ! called create && ! called push/target && grep -qF 'unavailable' <<< "$OUT" \
  && ok "a failed campaign lookup stops the run instead of creating another" \
  || bad "lookup failure: rc $RC, out: $OUT, calls: $CALLS"

approve_in noarch
seed noarch ITBL_PROOF_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
run noarch ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" STUB_CREATE='{"campaignId":21086031}' \
  STUB_ARCHIVE='{"success":[],"failed":[21086024]}' -- --campaign
((RC == 0)) && called '"campaignId":21086031,"recipientEmail"' \
  && grep -qF 'https://app.iterable.com/campaigns/21086024' <<< "$OUT" && ! grep -qF 'Archived campaign' <<< "$OUT" \
  && ok "an archive Iterable reports as failed is a warning with the link, not 'archived', and the send goes on" \
  || bad "archive failed[]: rc $RC, out: $OUT, calls: $CALLS"
grep -F 'could not be archived' <<< "$OUT" | grep -qF 21086024 && ! grep -qF '"failed"' <<< "$OUT" \
  && ok "and the warning names the campaign without dumping Iterable's body" \
  || bad "archive failed[] warning: $OUT"
[[ "$(resolved noarch ITBL_PROOF_CAMPAIGN_STALE)" == 21086024 && "$(resolved noarch ITBL_PROOF_CAMPAIGN_ID)" == 21086031 ]] \
  && ok "and the campaign that failed to archive stays recorded" \
  || bad "archive failed[] recorded: $(tr '\n' ' ' < "$TMP/ws-noarch/resolved.env")"
run noarch ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 0 Running)" STUB_CREATE='{"campaignId":21086040}' -- --campaign
((RC == 0)) && called 'POST /api/campaigns/archive {"campaignIds":[21086024,21086031]}' \
  && grep -qF 'Archived campaign 21086024' <<< "$OUT" && [[ -z "$(resolved noarch ITBL_PROOF_CAMPAIGN_STALE)" ]] \
  && ok "and the next run archives it along with the last run's campaign" \
  || bad "archive retry: rc $RC, out: $OUT, calls: $CALLS, resolved: $(tr '\n' ' ' < "$TMP/ws-noarch/resolved.env")"

approve_in moved
seed moved ITBL_PROOF_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
run moved ITBL_EMAIL=dev@example.com STUB_CREATE='{"campaignId":21086031}' -- --campaign
((RC == 0)) && called 'GET /api/campaigns/21086024' && called create && ! called archive \
  && (( $(grep -cF 21086024 <<< "$OUT") == 1 )) \
  && ok "a recorded campaign this project does not have gets one line naming it, then a new one is made" \
  || bad "recorded campaign 404: rc $RC, out: $OUT, calls: $CALLS"

# ---------------------------------------------------------------- failures record nothing
approve_in tfail
seed tfail ITBL_PROOF_MARKER=itbl-onboard-1 ITBL_PROOF_SENT_AT=1700000000000
run tfail ITBL_EMAIL=dev@example.com STUB_TARGET_FAIL=1 -- --campaign
((RC == 1)) && [[ "$(resolved tfail ITBL_PROOF_MARKER)" == itbl-onboard-1 && "$(resolved tfail ITBL_PROOF_SENT_AT)" == 1700000000000 ]] \
  && [[ -z "$(resolved tfail ITBL_CAMPAIGN_ID)$(resolved tfail ITBL_PROOF_CAMPAIGN_SENT)" ]] \
  && ok "a failed push/target records no marker, no send time and no campaign for G17" \
  || bad "failed send: rc $RC, resolved: $(tr '\n' ' ' < "$TMP/ws-tfail/resolved.env")"
[[ "$(resolved tfail ITBL_PROOF_CAMPAIGN_ID)" == 21086024 ]] \
  && ok "but keeps the campaign it created, for the re-run" \
  || bad "failed send lost the campaign id: $(tr '\n' ' ' < "$TMP/ws-tfail/resolved.env")"

approve_in badcid
run badcid ITBL_EMAIL=dev@example.com STUB_CREATE='{"campaignId":"21086024; rm"}' -- --campaign
((RC == 1)) && ! called activateTriggered && ! called push/target && [[ -z "$(resolved badcid ITBL_PROOF_CAMPAIGN_ID)" ]] \
  && grep -qF 'could not read a campaign id' <<< "$OUT" \
  && ok "a campaign id that is not a number stops the run before anything uses it" \
  || bad "bad campaign id: rc $RC, out: $OUT, calls: $CALLS"

# ---------------------------------------------------------------- marketing only
approve_in mkt
run mkt ITBL_EMAIL=dev@example.com STUB_CHANNELS="$MKT_CHANNELS" STUB_TYPES="$MKT_TYPES" -- --campaign
((RC == 10)) && ! called upsert && ! called create && ! called activate && ! called push/target \
  && ok "only a marketing push type: stops with rc 10, nothing created, nothing sent" \
  || bad "marketing only: rc $RC, calls: $CALLS"
grep -qi 'marketing' <<< "$OUT" && grep -qF -- '--message-type 199959' <<< "$OUT" \
  && ok "and asks, naming the marketing type and how to choose it" \
  || bad "marketing-only message: $OUT"
[[ -z "$(resolved mkt ITBL_CAMPAIGN_ID)$(resolved mkt ITBL_PROOF_MARKER)" ]] \
  && ok "and records nothing" || bad "marketing-only recorded: $(cat "$TMP/ws-mkt/resolved.env")"

run mkt ITBL_EMAIL=dev@example.com STUB_CHANNELS="$MKT_CHANNELS" STUB_TYPES="$MKT_TYPES" -- --campaign --message-type 199959
((RC == 0)) && grep -F upsert <<< "$CALLS" | grep -qF '"messageTypeId":199959' && called push/target \
  && ok "naming the marketing type outright sends through it" \
  || bad "--message-type: rc $RC, calls: $CALLS"

# ---------------------------------------------------------------- an existing base template
approve_in base
run base ITBL_EMAIL=dev@example.com STUB_TEMPLATES="$BASE_TEMPLATE" -- --campaign
((RC == 0)) && ! called upsert && ! called '/api/messageTypes' && ! called '/api/templates/push/update' \
  && called '"templateId":28203359}' \
  && ok "an existing base template is reused rather than upserted again" \
  || bad "base reuse: rc $RC, calls: $CALLS"

approve_in basemt
run basemt ITBL_EMAIL=dev@example.com STUB_TEMPLATES="$BASE_TEMPLATE" -- --campaign --message-type 199959
((RC == 0)) && called 'POST /api/templates/push/update {"templateId":28203359,"messageTypeId":199959}' && ! called upsert \
  && (( $(line_of '/api/templates/push/update') < $(line_of '/api/campaigns/create') )) \
  && ok "--message-type moves an existing base template to that type before the campaign is made" \
  || bad "--message-type with a base template: rc $RC, calls: $CALLS"

# ---------------------------------------------------------------- activation
approve_in noact
run noact ITBL_EMAIL=dev@example.com STUB_NO_ACTIVATE=1 -- --campaign
((RC == 10)) && called create && ! called push/target && ! called archive \
  && ok "activation disabled: rc 10, and no send to a campaign that is not running" \
  || bad "activation disabled: rc $RC, calls: $CALLS"
((RC == 10)) && grep -qF 'https://app.iterable.com/campaigns/21086024' <<< "$OUT" \
  && grep -qF 'proof-push --campaign' <<< "$OUT" \
  && ok "and ends with the dashboard link and the command that resumes" \
  || bad "activation disabled ending: $OUT"
(( $(grep -c 'activateTriggered' <<< "$CALLS") == 1 )) && ! grep -q 'GET /api/campaigns' <<< "$(sed -n '/activateTriggered/,$p' <<< "$CALLS")" \
  && ok "and it does not poll" || bad "activation disabled polled: $CALLS"
[[ -z "$(resolved noact ITBL_CAMPAIGN_ID)$(resolved noact ITBL_PROOF_MARKER)" && "$(resolved noact ITBL_PROOF_CAMPAIGN_ID)" == 21086024 ]] \
  && ok "and records the campaign it made, but no marker and nothing for G17" \
  || bad "activation disabled recorded: $(tr '\n' ' ' < "$TMP/ws-noact/resolved.env")"

run noact ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Ready)" -- --campaign
((RC == 0)) && called 'GET /api/campaigns/21086024' && ! called create && ! called archive && ! listed \
  && called activateTriggered && called '"campaignId":21086024,"recipientEmail"' \
  && ok "resuming looks up the recorded campaign, activates it and sends, without archiving it" \
  || bad "resume: rc $RC, calls: $CALLS"

approve_in actsent
seed actsent ITBL_PROOF_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
run actsent ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 21086024 Running)" STUB_CREATE='{"campaignId":21086031}' STUB_NO_ACTIVATE=1 -- --campaign
((RC == 10)) && called 'activateTriggered {"campaignId":21086031}' && ! called archive && ! grep -qF 'Archived' <<< "$OUT" \
  && [[ "$(resolved actsent ITBL_PROOF_CAMPAIGN_STALE)" == 21086024 ]] \
  && ok "activation disabled on the run after a send: the last run's campaign is left running and recorded" \
  || bad "activation disabled after a send: rc $RC, out: $OUT, calls: $CALLS"
run actsent ITBL_EMAIL=dev@example.com STUB_CAMPAIGN="$(campaign 0 Running)" -- --campaign
a="$(line_of 'POST /api/campaigns/archive {"campaignIds":[21086024]}')" t="$(line_of '"campaignId":21086031,"recipientEmail"')"
((RC == 0)) && ! called create && ! called activateTriggered && [[ -n "$a" && -n "$t" ]] && ((a > t)) \
  && [[ -z "$(resolved actsent ITBL_PROOF_CAMPAIGN_STALE)" ]] \
  && ok "and once the new one is running, the resume sends through it, then archives the old one" \
  || bad "resume after activation disabled: rc $RC, out: $OUT, calls: $CALLS"

approve_in acterr
run acterr ITBL_EMAIL=dev@example.com STUB_ACTIVATE_ERR='{"error":"BadRequest","message":"Template 28203361 failed validation"}' -- --campaign
((RC == 1)) && ! called push/target && grep -qF 'Template 28203361 failed validation' <<< "$OUT" \
  && ! grep -qF 'activate it in the dashboard' <<< "$OUT" \
  && ok "any other activation error fails with Iterable's message, not the resume ending" \
  || bad "other activation error: rc $RC, out: $OUT"

# ---------------------------------------------------------------- a 2xx that is not JSON
for p in /api/templates /api/channels /api/messageTypes /api/templates/push/upsert /api/templates/push/update \
    /api/campaigns/create /api/campaigns/activateTriggered /api/push/target; do
  w="html-${p//\//_}"
  approve_in "$w"
  if [[ "$p" == /api/templates/push/update ]]; then
    run "$w" ITBL_EMAIL=dev@example.com STUB_HTML="$p" STUB_TEMPLATES="$BASE_TEMPLATE" -- --campaign --message-type 199959
  else
    run "$w" ITBL_EMAIL=dev@example.com STUB_HTML="$p" -- --campaign
  fi
  after="$(sed -n "\#${p}#,\$p" <<< "$CALLS" | sed 1d)"
  ((RC == 1)) && called "$p" && grep -qF 'not JSON' <<< "$OUT" && ! grep -qE 'SyntaxError|    at ' <<< "$OUT" \
    && ! grep -qE 'activateTriggered|push/target' <<< "$after" \
    && [[ -z "$(resolved "$w" ITBL_PROOF_CAMPAIGN_SENT)$(resolved "$w" ITBL_CAMPAIGN_ID)$(resolved "$w" ITBL_PROOF_MARKER)" ]] \
    && ok "a 200 with an HTML body from $p stops the run with a clear error" \
    || bad "HTML from $p: rc $RC, out: $OUT, calls: $CALLS"
done
approve_in upfail
run upfail ITBL_EMAIL=dev@example.com STUB_TEMPLATES="$BASE_TEMPLATE" STUB_UPDATE_FAIL=1 -- --campaign --message-type 199959
((RC == 1)) && grep -qF 'template update failed' <<< "$OUT" && ! called create && ! called push/target \
  && ok "a failed template update stops the run before a campaign is made" \
  || bad "template update 500: rc $RC, out: $OUT, calls: $CALLS"
approve_in html-lookup
seed html-lookup ITBL_PROOF_CAMPAIGN_ID=21086024
run html-lookup ITBL_EMAIL=dev@example.com STUB_HTML=/api/campaigns/21086024 -- --campaign
((RC == 1)) && grep -qF 'not JSON' <<< "$OUT" && ! called create && ! called push/target \
  && ok "an HTML campaign lookup is an error, never 'no campaign, make one'" \
  || bad "HTML lookup: rc $RC, out: $OUT, calls: $CALLS"

# ---------------------------------------------------------------- template mode
seed tpl ITBL_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
run tpl ITBL_EMAIL=dev@example.com --
((RC == 0)) && called '/api/templates/push/proof' && [[ -z "$(resolved tpl ITBL_CAMPAIGN_ID)" ]] && ! grep -qF G17 <<< "$OUT" \
  && ok "a template proof forgets the campaign id campaign mode recorded" \
  || bad "template proof after a campaign: rc $RC, out: $OUT, resolved: $(tr '\n' ' ' < "$TMP/ws-tpl/resolved.env")"

seed tpl-set ITBL_CAMPAIGN_ID=777 ITBL_PROOF_CAMPAIGN_SENT=21086024
run tpl-set ITBL_EMAIL=dev@example.com --
((RC == 0)) && [[ "$(resolved tpl-set ITBL_CAMPAIGN_ID)" == 777 ]] && grep -qF 'G17' <<< "$OUT" && grep -qF 777 <<< "$OUT" \
  && ok "but keeps one set with bin/agent set, and warns G17 gates on it" \
  || bad "agent-set campaign id: rc $RC, out: $OUT, resolved: $(tr '\n' ' ' < "$TMP/ws-tpl-set/resolved.env")"

seed tpl-env ITBL_CAMPAIGN_ID=21086024 ITBL_PROOF_CAMPAIGN_SENT=21086024
echo 'ITBL_CAMPAIGN_ID=555' > "$TMP/ws-tpl-env/.env"
run tpl-env ITBL_EMAIL=dev@example.com --
((RC == 0)) && [[ -z "$(resolved tpl-env ITBL_CAMPAIGN_ID)" ]] && grep -qF 'ITBL_CAMPAIGN_ID=555' "$TMP/ws-tpl-env/.env" \
  && grep -qF 'G17' <<< "$OUT" && grep -qF 555 <<< "$OUT" \
  && ok "and leaves one from .env alone, warning that G17 now gates on that" \
  || bad ".env campaign id: rc $RC, out: $OUT"

run bad ITBL_EMAIL=dev@example.com -- --campaign --message-type marketing
((RC == 30)) && [[ -z "$CALLS" ]] \
  && ok "a non-numeric --message-type is refused before any call" \
  || bad "bad --message-type: rc $RC, calls: $CALLS"

# ---------------------------------------------------------------- the key
if grep -rqF "$KEY" "$ALL_OUT" "$TMP"/ws-* "$STUB_CALLS"; then
  bad "the server key was printed or written: $(grep -rlF "$KEY" "$ALL_OUT" "$TMP"/ws-* "$STUB_CALLS")"
else
  ok "the server key is in no output, no saved file and no request body"
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — no yes, no campaign; one push, recorded like the proof."
