#!/usr/bin/env bash
# G9's three-way judgement, against response bodies recorded from real runs.
#
# The distinction under test is the one the tool got wrong twice: an eventually
# consistent "not yet" must not be reported as a defect, and a genuine denial must
# not be waited on. Both arrive as the same HTTP status, so only the body separates
# them — which is exactly the kind of logic worth pinning down offline.
#
# No network, no credentials, no cloud changes.

set -uo pipefail
cd "$(dirname "$0")/.."
# A scratch workspace, because the real one now lives in the project being
# integrated and an offline test must not read or create it.
WS="$(mktemp -d)/ws" source bin/config.sh

FAILED=0
check() {
  local want_rc="$1" code="$2" body="$3" label="$4" out rc
  out="$(classify_fcm_response "$code" "$body")"; rc=$?
  if ((rc == want_rc)); then
    printf '  \033[32mPASS\033[0m %-34s -> %d  %s\n' "$label" "$rc" "$out"
  else
    printf '  \033[31mFAIL\033[0m %-34s -> got %d, wanted %d  (%s)\n' "$label" "$rc" "$want_rc" "$out"
    FAILED=1
  fi
}

echo
echo "  G9 response classification  (0 green, 1 red, 2 not yet)"
echo

# Recorded 2026-09-19: IAM had not yet made a freshly bound role effective, while
# G7 was already green because the binding was in the policy.
check 2 403 '{"error":{"code":403,"message":"Permission '"'"'cloudmessaging.messages.create'"'"' denied on resource '"'"'projects/ai-auto-onboarding'"'"' (or it may not exist).","status":"PERMISSION_DENIED"}}' \
  "403 role not yet effective"

# Recorded 2026-09-19: the success case. Auth worked, the fake token did not.
check 0 400 '{"error":{"code":400,"message":"The registration token is not a valid FCM registration token","status":"INVALID_ARGUMENT"}}' \
  "400 placeholder token rejected"

check 0 200 '{"name":"projects/p/messages/fake"}' "200 validate_only accepted"

# A denial that is not about our permission is a real failure, not a race.
check 1 403 '{"error":{"code":403,"message":"Firebase Cloud Messaging API has not been used in project 123 before or it is disabled.","status":"PERMISSION_DENIED"}}' \
  "403 API disabled"

check 1 401 '{"error":{"code":401,"message":"Request had invalid authentication credentials.","status":"UNAUTHENTICATED"}}' \
  "401 bad credentials"

# A 400 that is not about the registration token means the request itself is wrong.
check 1 400 '{"error":{"code":400,"message":"Invalid JSON payload received.","status":"FAILED_PRECONDITION"}}' \
  "400 malformed request"

check 1 500 '{"error":{"code":500,"message":"Internal error encountered.","status":"INTERNAL"}}' \
  "500 server error"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — 'not yet' and 'denied' stay distinguishable."
