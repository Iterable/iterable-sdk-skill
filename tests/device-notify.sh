#!/usr/bin/env bash
# Pins G16's verdict against recorded `dumpsys notification` output, no device.
#
# G16 is the gate the whole tool exists for, so the thing to pin is that it cannot
# pass by accident: a notification the app posted itself, a stale push from an
# earlier run, or a dump whose contents are redacted must none of them read as
# "the push we sent arrived".
#
# Fixtures are real output from a live emulator (Pixel 9 Pro, API 36) carrying a
# push sent by bin/proof-push. Derived by hand from the same recording:
#   dumpsys-notification-none     — the app's own record deleted, its stats left
#   dumpsys-notification-blocked  — numBlocked=0 changed to 2
# Captured separately, also real:
#   dumpsys-notification-redacted — the same moment dumped without --noredact

set -uo pipefail
cd "$(dirname "$0")/.."

MARKER=itbl-onboard-1789988520
SENT_AT=1789988521079

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

# case_is <label> <fixture> <marker|-> <expected-rc> <must-mention>
case_is() {
  local label="$1" fixture="$2" marker="$3" want="$4" mention="${5:-}" out rc
  [[ "$marker" == - ]] && marker=""
  out="$(node bin/notify-parse.js com.dogshelter "$marker" "$SENT_AT" < "tests/fixtures/$fixture")"; rc=$?
  if ((rc != want)); then
    bad "$label: expected rc=$want, got rc=$rc ($out)"; return
  fi
  if [[ -n "$mention" ]] && ! grep -qi -- "$mention" <<< "$out"; then
    bad "$label: rc right but message lost '$mention': $out"; return
  fi
  ok "$label -> rc=$rc ${out:0:56}"
}

echo
echo "  notify-parse.js — recorded notification dumps, no device"
echo

# The green with a marker: this is the push we sent, and the lag proves it.
case_is "marker matched"        dumpsys-notification-arrived.txt "$MARKER" 0 "after send"
# Re-running the ladder does not re-send, so a green can be about an old push. It
# has to say so — read without an age it means "a push just landed", and someone
# watching the device sees nothing and concludes the gate is lying.
case_is "says how old it is"    dumpsys-notification-arrived.txt "$MARKER" 0 " ago"
# Arrived and invisible: Android bundles a second notification from the same app
# with the first and marks it SILENT. The gate is right and the developer, who saw
# no banner, is also right — so the verdict has to reconcile them.
case_is "arrived but silent"    dumpsys-notification-silent.txt  "$MARKER" 0 "SILENT, no banner"
# ...and the ordinary arrival must not claim that.
out="$(node bin/notify-parse.js com.dogshelter "$MARKER" "$SENT_AT" < tests/fixtures/dumpsys-notification-arrived.txt)"
[[ "$out" != *SILENT* ]] && ok "a banner-showing arrival says nothing about SILENT" \
  || bad "non-silent arrival claimed SILENT: $out"
# The green without one: somebody else sent it, so the channel is all we have.
case_is "no marker, channel"    dumpsys-notification-arrived.txt -         0 "iterable channel"
# A marker from an earlier run must not match a notification still on screen.
case_is "stale marker"          dumpsys-notification-arrived.txt itbl-onboard-0000000000 2 "none carrying"

case_is "nothing arrived"       dumpsys-notification-none.txt    "$MARKER" 2 "nothing from com.dogshelter"
# Stats outlive the record they came from. numPostedByApp=2 is still in this
# fixture, and it must not be mistaken for something being on screen.
case_is "nothing, stats remain" dumpsys-notification-none.txt    -         2 "nothing from com.dogshelter"
# The one reading that explains "Iterable sent it and I never saw it".
case_is "suppressed"            dumpsys-notification-blocked.txt -         2 "numBlocked=2"

# Redacted content: arrival and channel are still readable, the marker is not.
# Saying so beats reporting a marker mismatch that never happened.
case_is "redacted, marker"      dumpsys-notification-redacted.txt "$MARKER" 2 "redacted"
case_is "redacted, no marker"   dumpsys-notification-redacted.txt -         0 "iterable channel"

# A push to another app on the same device says nothing about ours.
out="$(node bin/notify-parse.js com.example.other "$MARKER" "$SENT_AT" < tests/fixtures/dumpsys-notification-arrived.txt)"; rc=$?
((rc == 2)) && ok "other package -> rc=2 ${out:0:40}" || bad "other package: expected rc=2, got rc=$rc ($out)"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — nothing but the push we sent reads as the push we sent."
