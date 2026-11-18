#!/usr/bin/env bash
# G17 against recorded /api/events answers: green only for a pushSend from this run's
# campaign, sent at or after this run's send time. Any other pushSend in the user's
# history is somebody else's push, and a gate that counts it is green about nothing.
#
# No network, no credentials: curl is a stub that answers with a fixture.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/bin"; mkdir -p "$STUB" "$TMP/ws"

cat > "$STUB/curl" <<'CURL'
#!/usr/bin/env bash
cat >/dev/null
for a in "$@"; do
  case "$a" in */api/events/*) cat "$STUB_EVENTS"; printf '\n200'; exit 0 ;; esac
done
printf '{"msg":"unexpected path"}\n404'
CURL
chmod +x "$STUB/curl"

CAMPAIGN=21086024
SENT_AT=1794936511867   # 2026-11-17T17:28:31.867Z, 12s before the fixtures' pushSend

# case_is <label> <fixture> <expected-rc> <must-mention> [campaign] [sent-at]
case_is() {
  local label="$1" fixture="$2" want="$3" mention="$4" campaign="${5-$CAMPAIGN}" sent="${6-$SENT_AT}" out rc
  out="$(STUB_EVENTS="tests/fixtures/$fixture" PATH="$STUB:$PATH" WS="$TMP/ws" \
    ITBL_SERVER_KEY=server-key-canary ITBL_EMAIL=dev@example.com \
    ITBL_CAMPAIGN_ID="$campaign" ITBL_PROOF_SENT_AT="$sent" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; source bin/gates-iterable.sh; g17' 2>&1)"; rc=$?
  if ((rc != want)); then
    bad "$label: expected rc=$want, got rc=$rc ($out)"; return
  fi
  [[ "$out" == *"$mention"* ]] && ok "$label (rc $rc)" || bad "$label: no \"$mention\" in: $out"
}

echo
echo "  G17 — recorded event lists, stubbed Iterable"
echo

case_is "this campaign's pushSend, after the send"  events-match.json             0 "21f080a1"
case_is "a few seconds early, inside the skew"     events-within-skew.json       0 "pushSend"

case_is "stale pushSend from an earlier run"       events-stale.json             2 "no pushSend"
case_is "pushSend from another campaign"           events-other-campaign.json    2 "no pushSend"
case_is "pushSend just outside the skew"           events-outside-skew.json      2 "no pushSend"
case_is "nothing recorded yet"                     events-empty.json             2 "no events"

case_is "pushSendSkip for this send"               events-skip.json              1 "pushSendSkip — Iterable chose not to send"
case_is "pushBounce for this send"                 events-bounce.json            1 "pushBounce — the push service rejected"
case_is "pushSendFailure for this send"            events-failure.json           1 "pushSendFailure — Iterable tried to send"
case_is "a stale skip does not fail a fresh run"   events-stale-skip.json        2 "no pushSend"
case_is "a stale pushSend does not hide a skip"    events-skip-after-stale-send.json 1 "pushSendSkip"

case_is "no campaign to match against"             events-match.json             2 "ITBL_CAMPAIGN_ID" ""
case_is "no send time to match against"            events-match.json             2 "send time"        "$CAMPAIGN" ""

echo
if ((FAILED)); then echo "  G17 can go green about a push this run did not send."; exit 1; fi
echo "  All good — G17 only counts this run's push."
