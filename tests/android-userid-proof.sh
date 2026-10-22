#!/usr/bin/env bash
# The Android proof for an app that identifies users with setUserId and has no email.
# Until this existed the ladder only knew ITBL_EMAIL, and a trial agent with a correct
# setUserId integration rewrote the app to sign every user in as `<id>@<app>.local`
# so the proof would run. So: a userId is recorded, looked up and sent to as a userId,
# and a workspace with an email sends exactly what it always did.
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
printf '%s %s %s\n' "$method" "${url#https://api.iterable.com}" "$data" >> "$STUB_CALLS"
case "$url" in
  */api/templates/push/upsert) printf '{"msg":"Upserted 1 templates with IDs: 42"}\n200' ;;
  */api/templates/push/proof)  printf '{"msg":"ok"}\n200' ;;
  */api/users/byUserId/*|*/api/users/getByEmail*) printf '%s\n%s' "$STUB_USER" "${STUB_CODE:-200}" ;;
  */api/events/*)              printf '{"events":[{"eventName":"pushSend"}]}\n200' ;;
  *)                           printf '{"msg":"unexpected path"}\n404' ;;
esac
CURL

cat > "$STUB/adb" <<'ADB'
#!/usr/bin/env bash
[[ "$1" == devices ]] && { echo "List of devices attached"; [[ -n "${STUB_LOGCAT:-}" ]] && printf 'emulator-5554\tdevice\n'; exit 0; }
[[ "$1" == -s ]] && shift 2
case "$*" in
  "emu avd name") echo Pixel_9_Pro; exit 0 ;;
  "shell pm list packages -U com.example.app") echo "package:com.example.app uid:10218"; exit 0 ;;
esac
[[ "$1 $2 $3" == "logcat -d --uid=10218" ]] && { cat "$STUB_LOGCAT"; exit 0; }
exit 0
ADB
chmod +x "$STUB/curl" "$STUB/adb"

# One workspace per case, so an identity recorded by one cannot answer for another.
run() {
  local ws="$TMP/ws-$1"; shift
  mkdir -p "$ws"
  PATH="$STUB:$PATH" WS="$ws" PACKAGE=com.example.app ITBL_SERVER_KEY=server-key-canary \
    DEVICE_WAIT=0 bash -c "$@"
}
calls() { cat "$STUB_CALLS" 2>/dev/null; : > "$STUB_CALLS"; }

echo
echo "  Android proof by userId — stubbed Iterable, no device"
echo

# ---------------------------------------------------------------- the proof send
: > "$STUB_CALLS"
run uid 'ITBL_USER_ID=u-0a1b2c bin/proof-push' >/dev/null 2>&1
grep -qxF 'POST /api/templates/push/proof {"templateId":42,"recipientUserId":"u-0a1b2c"}' <<< "$(calls)" \
  && ok "a userId workspace sends the proof to recipientUserId" \
  || bad "the userId proof body is wrong: $(cat "$STUB_CALLS")"

run email 'ITBL_EMAIL=dev@example.com bin/proof-push' >/dev/null 2>&1
grep -qxF 'POST /api/templates/push/proof {"templateId":42,"recipientEmail":"dev@example.com"}' <<< "$(calls)" \
  && ok "an email workspace sends the same body as before, to recipientEmail" \
  || bad "the email proof body changed: $(cat "$STUB_CALLS")"

# ---------------------------------------------------------------- G15 and G17
export STUB_USER='{"user":{"userId":"u-0a1b2c","dataFields":{"devices":[{"applicationName":"com.example.app","endpointEnabled":true}]}}}'
out="$(run uid 'source bin/config.sh >/dev/null 2>&1; source bin/gates-iterable.sh; ITBL_USER_ID="u 0a/1b" g15' 2>&1)"; rc=$?
c="$(calls)"
((rc == 0)) && grep -qF 'GET /api/users/byUserId/u%200a%2F1b' <<< "$c" \
  && ok "G15 looks the user up by userId, path-encoded, and finds the device" \
  || bad "G15 by userId: rc $rc, calls: $c, out: $out"

out="$(STUB_CODE=400 STUB_USER='{"msg":"User not found","code":"BadParams"}' \
  run uid 'source bin/config.sh >/dev/null 2>&1; source bin/gates-iterable.sh; ITBL_USER_ID=u-0a1b2c g15' 2>&1)"; rc=$?
calls >/dev/null
((rc == 2)) && grep -qF 'u-0a1b2c' <<< "$out" \
  && ok "an unknown userId is pending, not broken, and names the ID" \
  || bad "unknown userId: rc $rc, $out"

out="$(run email 'source bin/config.sh >/dev/null 2>&1; source bin/gates-iterable.sh; ITBL_EMAIL=dev@example.com g15' 2>&1)"; rc=$?
grep -qF 'GET /api/users/getByEmail?email=dev%40example.com' <<< "$(calls)" \
  && ok "G15 for an email still reads getByEmail" \
  || bad "G15 for an email no longer reads getByEmail: $out"

out="$(run uid 'source bin/config.sh >/dev/null 2>&1; source bin/gates-iterable.sh; ITBL_USER_ID=u-0a1b2c g17' 2>&1)"; rc=$?
((rc == 0)) && grep -qF 'GET /api/events/byUserId/u-0a1b2c?limit=50' <<< "$(calls)" \
  && ok "G17 reads the userId's events" \
  || bad "G17 by userId: rc $rc, $out"

# ---------------------------------------------------------------- recording it
ws="$TMP/ws-set"; mkdir -p "$ws"
envof() { grep -E '^ITBL_(EMAIL|USER_ID)=' "$ws/.env" 2>/dev/null | tr '\n' ' '; }
agent_set() { PATH="$STUB:$PATH" WS="$ws" bin/agent set "$1" >/dev/null 2>&1; }

agent_set ITBL_EMAIL=dev@example.com
agent_set ITBL_IDENTITY=u-0a1b2c
[[ "$(envof)" == "ITBL_USER_ID=u-0a1b2c " ]] \
  && ok "a typed answer that is not an email is recorded as ITBL_USER_ID, and the email is dropped" \
  || bad "typed userId recorded as: $(envof)"
agent_set ITBL_IDENTITY=dev@example.com
[[ "$(envof)" == "ITBL_EMAIL=dev@example.com " ]] \
  && ok "a typed email is recorded as ITBL_EMAIL, and the userId is dropped" \
  || bad "typed email recorded as: $(envof)"
agent_set "ITBL_USER_ID=has space" && bad "a userId with a space was accepted" \
  || ok "a userId the env file cannot hold is refused"

# ---------------------------------------------------------------- what the device saw
printf '%s\n' \
  '10-22 15:40:00.000 9000 9001 V IterableRequest:   "userId": "u-0a1b2c",' \
  '10-22 15:40:00.000 9000 9001 V IterableRequest:   "preferUserId": true,' > "$TMP/logcat.txt"
seen="$(STUB_LOGCAT="$TMP/logcat.txt" run uid 'source bin/config.sh >/dev/null 2>&1; app_identity' 2>/dev/null)"
[[ "$seen" == u-0a1b2c ]] \
  && ok "the userId the app registered is read off the device" \
  || bad "app_identity read '$seen' from a userId registration"

# ---------------------------------------------------------------- the step 4 screen
s4="$(run uid 'ITBL_USER_ID=u-0a1b2c bin/agent question iterable_step 4' 2>/dev/null)"
grep -qF 'That is the wrong user ID' <<< "$s4" && grep -qF 'setUserId()' <<< "$s4" \
  && ok "step 4 with a userId talks about the user ID and setUserId()" \
  || bad "step 4 with a userId still talks about an address"
grep -qF 'set ITBL_IDENTITY={{answer}}' <<< "$s4" \
  && ok "and its typed answer goes through the identity router" \
  || bad "step 4's typed answer still writes ITBL_EMAIL only"
grep -qiF 'invent an email' <<< "$s4" \
  && ok "and it says never to invent an email address to fit the step" \
  || bad "step 4 no longer warns against inventing an email"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — a userId app is proved as a userId app."
