#!/usr/bin/env bash
# Pins classify_itbl_response against response bodies, offline.
#
# Same reason as tests/fcm-classify.sh: the interesting logic is "which failures
# mean the key is wrong, and which mean the key is fine but the request wasn't",
# and that judgement is worthless if it only runs inside a curl pipeline where it
# can't be exercised.
#
# Bodies marked (recorded) are real, copied from Iterable's documentation. Those
# marked (shaped) match Iterable's documented {msg,code,params} envelope but the
# exact wording is not confirmed — the classification they exercise depends on the
# status code and, for the JWT case, on a substring of a recorded body.

set -uo pipefail
cd "$(dirname "$0")/.."
source bin/config.sh

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

# case <label> <expected-rc> <code> <body> [mode] [must-mention]
case_is() {
  local label="$1" want="$2" code="$3" body="$4" mode="${5:-strict}" mention="${6:-}"
  local out rc
  out="$(classify_itbl_response "$code" "$body" "$mode")"; rc=$?
  if ((rc != want)); then
    bad "$label: expected rc=$want, got rc=$rc ($out)"; return
  fi
  if [[ -n "$mention" ]] && ! grep -qi "$mention" <<< "$out"; then
    bad "$label: rc right but message lost '$mention': $out"; return
  fi
  ok "$label -> rc=$rc ${out:0:58}"
}

echo
echo "  classify_itbl_response — recorded and shaped bodies, no network"
echo

case_is "200 channels list" 0 200 \
  '{"channels":[{"id":1,"name":"Push","channelType":"Marketing","messageMedium":"Push"}]}'

# The mobile-key probe: we send {} on purpose, so a 400 proves the key got past
# authentication. Under strict mode the same response is a real failure.
case_is "400 empty body, auth-only" 0 400 \
  '{"msg":"Invalid parameters","code":"BadParams","params":null}' auth-only
case_is "400 empty body, strict" 1 400 \
  '{"msg":"Invalid parameters","code":"BadParams","params":null}' strict

# (shaped) — 401 is documented for every endpoint the ladder uses as "Invalid API key".
case_is "401 bad key" 1 401 \
  '{"msg":"Invalid API key","code":"BadApiKey","params":null}' strict "key rejected"

# A 401 in auth-only mode must still be a failure: the whole point of the probe is
# that a bad key is distinguishable from a bad payload.
case_is "401 bad key, auth-only" 1 401 \
  '{"msg":"Invalid API key","code":"BadApiKey","params":null}' auth-only "key rejected"

# (recorded) — from Iterable's JWT-Enabled API Keys doc. A JWT-enabled key used
# without a JWT must not be reported as "wrong key type": the fix is the shared
# secret or a different key, and saying "revoked" would send you the wrong way.
case_is "401 JWT required" 1 401 \
  '{"msg":"JWT token is expired","code":"InvalidJwtPayload","params":{"endpoint":"/api/events/track"}}' \
  strict "JWT"

case_is "429 rate limited" 1 429 '{"msg":"Too many requests","code":"RateLimit"}' strict "rate limit"
case_is "500 server error"  1 500 '{"msg":"Internal error","code":"GenericError"}' strict
case_is "unparseable body"  1 502 '<html>bad gateway</html>' strict

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — a wrong key stays distinguishable from a wrong request."
