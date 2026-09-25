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
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — one way to go red, and a rotated buffer never becomes one."
