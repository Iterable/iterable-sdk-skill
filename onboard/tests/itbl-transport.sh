#!/usr/bin/env bash
# The HTTP status must survive the call.
#
# Exists because of a live failure at G10. itbl_req echoed the body and *set*
# ITBL_CODE, so every caller wrote `body="$(itbl_get …)"` — a command
# substitution, i.e. a subshell — and the status died with that subshell. Under
# `set -u` the next line blew up with "ITBL_CODE: unbound variable" on a real run
# against real keys. tests/itbl-classify.sh could not catch it: it feeds
# classify_itbl_response literal codes and never exercises the plumbing.
#
# Offline — the transport is stubbed, so this tests the wiring, not the network.

set -uo pipefail
cd "$(dirname "$0")/.."
source bin/config.sh

FAILED=0
ok() { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
no() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

STUB_CODE=200
STUB_BODY=""
itbl_curl() { printf '%s\n%s' "$STUB_BODY" "$STUB_CODE"; }

check() {
  local label="$1" code="$2" body="$3" want_rc="$4" rc=0
  STUB_CODE="$code" STUB_BODY="$body"
  ITBL_CODE=sentinel ITBL_BODY=sentinel
  itbl_get some-key /api/channels || rc=$?
  [[ "$ITBL_CODE" == "$code" ]] || { no "$label: code is '$ITBL_CODE', want '$code'"; return; }
  [[ "$ITBL_BODY" == "$body" ]] || { no "$label: body is '$ITBL_BODY', want '$body'"; return; }
  [[ "$rc" == "$want_rc" ]]     || { no "$label: rc is $rc, want $want_rc"; return; }
  ok "$label -> code $ITBL_CODE, body intact, rc $rc"
}

echo
echo "  itbl_call — the status and body both reach the caller"
echo

check "200 with a JSON body"  200 '{"channels":[]}' 0
check "401 bad key"           401 '{"msg":"invalid api key"}' 1
check "400 empty payload"     400 '{"msg":"Invalid parameters"}' 1
check "empty body"            204 '' 0

# A body containing its own newlines is the case a naive split gets wrong: the
# status is the *last* line, not the second one.
check "multi-line body" 500 "$(printf '<html>\n<body>oops</body>\n</html>')" 1

# The end-to-end shape of every gate: call, then classify. This is the exact
# sequence that failed live, so assert it runs without an unbound variable.
STUB_CODE=200 STUB_BODY='{"channels":[{"messageMedium":"Push"}]}'
if out="$(itbl_get k /api/channels && classify_itbl_response "$ITBL_CODE" "$ITBL_BODY" 2>&1)"; then
  ok "call-then-classify works under set -u ($out)"
else
  no "call-then-classify failed: $out"
fi

# Guards the fix rather than the symptom. Capturing the function's stdout puts it
# in a subshell, which is what broke the status in the first place. Comments are
# excluded, or the note in config.sh explaining this very bug trips the lint.
CAPTURED="$(grep -rn '\$(itbl_get\|\$(itbl_post\|\$(itbl_call' bin/ | grep -v ':[0-9]*: *#' || true)"
if [[ -n "$CAPTURED" ]]; then
  no "a caller captures itbl_get/itbl_post output in a subshell — read ITBL_BODY instead"
  sed 's/^/      /' <<< "$CAPTURED"
else
  ok "no caller captures the response in a subshell"
fi

echo
if ((FAILED == 0)); then
  echo "  All good — a gate reads the status the call actually returned."
else
  echo "  Broken."
fi
exit "$FAILED"
