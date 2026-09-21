#!/usr/bin/env bash
# Checks our hardcoded "which key does this endpoint need" against Iterable's own
# spec, which publishes the answer as x-iterable-api-key-types on every operation.
#
# Worth a test because the answer is changing. Iterable is replacing coarse key
# types with a per-resource scope model (Jira EN-1023); when that lands, a gate
# using the wrong key would fail with a 401 that reads exactly like a bad key.
# This turns that into a named failure instead.
#
# Needs network. Skips rather than fails when the spec can't be fetched.

set -uo pipefail
cd "$(dirname "$0")/.."

SPEC=/tmp/itbl-apidocs-test.json
URL="${ITBL_SPEC_URL:-https://api.iterable.com/api-docs}"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

echo
echo "  Key types the gates assume vs. what the spec publishes"
echo

CODE="$(curl -sS -o "$SPEC" -w '%{http_code}' "$URL" 2>/dev/null)" || CODE=000
if [[ "$CODE" != 200 ]]; then
  echo "  SKIP — could not fetch $URL (HTTP $CODE)"
  exit 0
fi

# endpoint -> the key the gates actually send. Keep in step with bin/gates-iterable.sh.
check() {
  local path="$1" verb="$2" expect="$3" out
  out="$(node -e '
    const j = require(process.argv[1]);
    const op = (j.paths[process.argv[2]] || {})[process.argv[3]];
    if (!op) { console.log("MISSING"); process.exit(0) }
    const t = op["x-iterable-api-key-types"];
    console.log(Array.isArray(t) ? t.join(",") : "UNANNOTATED");
  ' "$SPEC" "$path" "$verb")"
  case "$out" in
    MISSING)     bad "$verb $path is no longer in the spec" ;;
    UNANNOTATED) bad "$verb $path lost its x-iterable-api-key-types annotation" ;;
    *) if [[ ",$out," == *",$expect,"* ]]; then
         ok "$verb $path accepts $expect (spec says: $out)"
       else
         bad "$verb $path now wants $out, but the gates send a $expect key"
       fi ;;
  esac
}

check /api/channels                 get  Server-side
check /api/users/registerDeviceToken post Mobile
check /api/users/getByEmail         get  Server-side
check "/api/events/{email}"         get  Server-side
# bin/proof-push sends these two.
check /api/templates/push/upsert    post Server-side
check /api/templates/push/proof     post Server-side

# Android device registration uses the legacy enum value. A tool would naturally
# guess FCM or ANDROID; both are rejected.
PLATFORMS="$(node -e '
  const j=require(process.argv[1]);
  console.log((j.definitions.Device?.properties?.platform?.enum||[]).join(","));
' "$SPEC")"
[[ ",$PLATFORMS," == *",GCM,"* ]] \
  && ok "Device.platform still accepts GCM (enum: $PLATFORMS)" \
  || bad "Device.platform no longer accepts GCM (enum: $PLATFORMS)"

echo
((FAILED)) && { echo "  FAILED — the spec moved; fix bin/gates-iterable.sh"; exit 1; }
echo "  All good — the gates send the key type each endpoint asks for."
