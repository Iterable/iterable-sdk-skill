#!/usr/bin/env bash
# Pins G14's verdict against recorded logcat buffers, with no device attached.
#
# The judgement worth pinning is not "did the word Success appear" — it is which
# absences mean something. A log buffer that rotates cannot prove a token was
# never registered, so the gate has exactly one way to go red (Iterable rejected
# the call) and two ways to stay quiet. Getting that wrong means a working
# integration gets reported as broken, which is the failure mode this tool exists
# to avoid.
#
# Every fixture is real output from a live emulator (Pixel 9 Pro, API 36,
# com.dogshelter, SDK 3.10.1), trimmed to the registration window. The device's
# FCM token is redacted in place. Two are derived by hand from the same recording:
#   logcat-register-rejected     — "code": "Success" swapped for a rejection
#   logcat-no-registration       — every registerDeviceToken line removed

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

# case_is <fixture> <expected-rc> <must-mention>
case_is() {
  local fixture="$1" want="$2" mention="${3:-}" out rc
  out="$(node bin/token-log.js com.dogshelter < "tests/fixtures/$fixture")"; rc=$?
  if ((rc != want)); then
    bad "$fixture: expected rc=$want, got rc=$rc ($out)"; return
  fi
  if [[ -n "$mention" ]] && ! grep -qi -- "$mention" <<< "$out"; then
    bad "$fixture: rc right but message lost '$mention': $out"; return
  fi
  ok "$fixture -> rc=$rc ${out:0:56}"
}

echo
echo "  token-log.js — recorded logcat buffers, no device"
echo

# The one green. "FCM" in the message is the legacy-transport check: a token
# registered as GCM registers fine and fails to receive later.
case_is logcat-register-success.txt   0 "tokenRegistrationType FCM"

# The one red. Iterable answered, and the answer was no.
case_is logcat-register-rejected.txt  1 "BadApiKey"

# Everything else is a state, not a fault.
case_is logcat-register-inflight.txt  2 "no response"
case_is logcat-no-iterable.txt        2 "launch"
case_is logcat-no-registration.txt    3 "never called registerDeviceToken"

# A token is a credential. The gate prints its verdict into terminals, reports and
# CI logs, so the fixture's own redaction has to hold for the parser's output too.
for f in tests/fixtures/logcat-*.txt; do
  out="$(node bin/token-log.js com.dogshelter < "$f" || true)"
  grep -q 'APA91\|redacted-by-fixture' <<< "$out" \
    && { bad "$(basename "$f"): the verdict echoed the device token"; continue; }
  ok "$(basename "$f") -> verdict carries no token"
done

echo
echo "  G14 — what the gate makes of 'ran and never registered'"
echo

STUB="$(mktemp -d)"; mkdir -p "$STUB/ws"
trap 'rm -rf "$STUB"' EXIT

cat > "$STUB/adb" <<'ADB'
#!/usr/bin/env bash
[[ "$1" == devices ]] && { echo "List of devices attached"; printf 'emulator-5554\tdevice\n'; exit 0; }
[[ "$1" == -s ]] && shift 2
case "$*" in
  "emu avd name") echo Pixel_9_Pro; exit 0 ;;
  "shell pm list packages -U com.dogshelter") echo "package:com.dogshelter uid:10218"; exit 0 ;;
esac
[[ "$1 $2 $3" == "logcat -d --uid=10218" ]] && { cat "$STUB_FIX"; exit 0; }
exit 0
ADB
chmod +x "$STUB/adb"

# gate_is <label> <fixture> <mobile-key> <expected-rc> <must-mention>
gate_is() {
  local label="$1" want="$4" mention="$5" out rc
  out="$(PATH="$STUB:$PATH" WS="$STUB/ws" STUB_FIX="tests/fixtures/$2" ITBL_MOBILE_KEY="$3" \
    PACKAGE=com.dogshelter DEVICE_WAIT=0 \
    bash -c 'source bin/config.sh >/dev/null 2>&1; source bin/gates-device.sh; g14' 2>&1)"; rc=$?
  if ((rc != want)); then bad "$label — expected rc $want, got $rc ($out)"; return; fi
  grep -qi -- "$mention" <<< "$out" || { bad "$label — rc $rc is right but never says '$mention': $out"; return; }
  ok "$label -> rc=$rc ${out:0:64}"
}

# The parser says the same thing either way; only the gate knows whether it is a
# fault. A developer who has not reached the Iterable steps yet has given the app no
# key to register with, and a live run reported that as a defect.
gate_is "no key yet — not a defect, work outstanding" logcat-no-registration.txt "" 2 "nothing to register with"
gate_is "key in hand and still nothing — red"         logcat-no-registration.txt itbl-mobile-key 1 "still not after"
# And the green must not depend on any of it.
gate_is "a registered token is green regardless"      logcat-register-success.txt "" 0 "tokenRegistrationType FCM"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — one way to go red, and a rotated buffer never becomes one."
