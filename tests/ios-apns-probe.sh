#!/usr/bin/env bash
# The direct Apple check against a fake APNs: each refusal reason gets its named
# cause, the request is a silent push signed with the workspace key, and the
# device token never appears in the output.

set -uo pipefail
cd "$(dirname "$0")/.." || exit
REPO="$PWD"

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  [[ $# -lt 2 ]] || printf '  %s\n' "$2"
  FAILED=1
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-apns-probe.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-apns-probe.*|/private/tmp/iterable-ios-apns-probe.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
server_pid=""
trap '[[ -z "$server_pid" ]] || { kill "$server_pid" 2>/dev/null; wait "$server_pid" 2>/dev/null; }; rm -rf "$ROOT"' EXIT

WORKSPACE="$ROOT/workspace"
DEVICES="$ROOT/devices"
mkdir -p "$WORKSPACE"
"$REPO/tests/fixtures/ios-prove/simulate" register "$DEVICES" SIM-APPLE-1 com.example.dogshelter
node -e '
  const crypto=require("crypto"), fs=require("fs"), dir=process.argv[1];
  const {privateKey,publicKey}=crypto.generateKeyPairSync("ec",{namedCurve:"P-256"});
  fs.writeFileSync(`${dir}/AuthKey_ABC123DEFG.p8`,privateKey.export({type:"pkcs8",format:"pem"}),{mode:0o600});
  fs.writeFileSync(`${dir}/public.pem`,publicKey.export({type:"spki",format:"pem"}));
  fs.writeFileSync(`${dir}/apns.json`,JSON.stringify({key_path:`${dir}/AuthKey_ABC123DEFG.p8`,key_id:"ABC123DEFG",team_id:"TEAM123456"},null,2)+"\n",{mode:0o600});
' "$WORKSPACE"
printf 200 > "$ROOT/scenario"
node "$REPO/tests/fixtures/ios-prove/fake-apns.js" "$ROOT/port" "$ROOT/scenario" "$ROOT/requests" &
server_pid=$!
for _ in $(seq 1 50); do [[ -s "$ROOT/port" ]] && break; sleep 0.1; done
ORIGIN="http://127.0.0.1:$(cat "$ROOT/port")"
TOKEN_HEX="$(node -e 'process.stdout.write(Buffer.alloc(80,0x11).toString("hex"))')"

probe() {
  env ITERABLE_IOS_TEST_MODE=1 IOS_APNS_PROBE_ORIGIN="${PROBE_ORIGIN:-$ORIGIN}" \
    node "$REPO/bin/ios-apns-probe.js" --workspace "${PROBE_WORKSPACE:-$WORKSPACE}" --devices-root "$DEVICES" \
      --udid SIM-APPLE-1 --bundle com.example.dogshelter --environment "${PROBE_ENVIRONMENT:-development}"
}
field() {
  node -e '
    let v=JSON.parse(process.argv[1]);
    for (const key of process.argv[2].split(".")) v=v?.[key];
    process.stdout.write(v == null ? "" : Array.isArray(v) ? v.join(" ") : String(v));
  ' "$1" "$2"
}

out="$(probe)"
if [[ "$(field "$out" status)" == ready && "$(field "$out" classification)" == apple_push_ready &&
      "$(field "$out" diagnostic_only)" == true && "$out" != *"$TOKEN_HEX"* ]]; then
  ok "Apple's 200 is apple_push_ready, marked diagnostic, without printing the token"
else
  bad "a 200 was not classified as ready" "$out"
fi
request="$(tail -1 "$ROOT/requests")"
if node -e '
  const crypto=require("crypto"), fs=require("fs");
  const r=JSON.parse(process.argv[1]), token=process.argv[2], pub=fs.readFileSync(process.argv[3]);
  const [h,c,sig]=r.authorization.replace(/^bearer /,"").split(".");
  const header=JSON.parse(Buffer.from(h,"base64url")), claims=JSON.parse(Buffer.from(c,"base64url"));
  const verified=crypto.verify("sha256",Buffer.from(`${h}.${c}`),{key:pub,dsaEncoding:"ieee-p1363"},Buffer.from(sig,"base64url"));
  process.exit(r.method==="POST" && r.path===`/3/device/${token}` && r.topic==="com.example.dogshelter" &&
    r.push_type==="background" && r.priority==="5" &&
    JSON.stringify(JSON.parse(r.body))===JSON.stringify({aps:{"content-available":1}}) &&
    header.alg==="ES256" && header.kid==="ABC123DEFG" && claims.iss==="TEAM123456" &&
    Math.abs(claims.iat-Date.now()/1000)<60 && verified ? 0 : 1);
' "$request" "$TOKEN_HEX" "$WORKSPACE/public.pem"; then
  ok "the probe is one silent push to the app's real token, signed ES256 with the workspace key"
else
  bad "the probe request was not the expected silent, signed push"
fi

expect() {
  local scenario="$1" status="$2" classification="$3" name="$4" out
  printf '%s' "$scenario" > "$ROOT/scenario"
  out="$(probe)"
  if [[ "$(field "$out" status)" == "$status" && "$(field "$out" classification)" == "$classification" ]]; then
    ok "$name"
  else
    bad "$name" "$out"
  fi
  LAST="$out"
}
expect "400 TopicDisallowed" blocked app_id_push_disabled "TopicDisallowed names the App ID's Push capability or a restricted key"
if [[ "$(field "$LAST" summary)" == *"App ID com.example.dogshelter isn't enabled for Push on team TEAM123456"* &&
      "$(field "$LAST" urls)" == *"identifiers/list"*"authkeys/list"* &&
      "$(field "$LAST" steps)" == *"tick Push Notifications, click Save, then Confirm"* &&
      "$(field "$LAST" steps)" == *"team selector"* ]]; then
  ok "the TopicDisallowed answer carries the Identifiers and Keys pages and the exact steps"
else
  bad "the TopicDisallowed guidance is incomplete" "$LAST"
fi
expect "400 DeviceTokenNotForTopic" blocked bundle_id_mismatch "DeviceTokenNotForTopic is a Bundle ID mismatch"
expect "400 BadDeviceToken" blocked apns_environment_mismatch "BadDeviceToken is a sandbox/production mismatch"
expect "403 InvalidProviderToken" blocked apns_key_rejected "InvalidProviderToken routes to replacing the APNs key"
[[ "$(field "$LAST" next_command_hint)" == *"replace_apns_key"* ]] && ok "a rejected key points at provisioning's replace step" ||
  bad "a rejected key gave no replace step" "$LAST"
expect "403 ExpiredProviderToken" blocked apns_key_rejected "ExpiredProviderToken is a key, Key ID, or Team ID problem"
expect "410 Unregistered" blocked device_token_unregistered "Unregistered asks for a fresh registration"
expect "429 TooManyRequests" inconclusive apns_unavailable "429 is inconclusive"
expect "503 ServiceUnavailable" inconclusive apns_unavailable "5xx is inconclusive"
out="$(PROBE_ORIGIN="http://127.0.0.1:1" probe)"
[[ "$(field "$out" status)" == inconclusive ]] && ok "an unreachable APNs is inconclusive, not a verdict" || bad "a network failure was judged" "$out"
mkdir -p "$ROOT/nokey"
out="$(PROBE_WORKSPACE="$ROOT/nokey" probe)"
[[ "$(field "$out" classification)" == no_apns_key && "$(field "$out" status)" == not_run ]] &&
  ok "a workspace without an imported APNs key does not run the probe" || bad "the probe ran without a key" "$out"
requests_before="$(grep -c . "$ROOT/requests")"
printf '400 TopicDisallowed' > "$ROOT/scenario"
probe >/dev/null
[[ "$(grep -c . "$ROOT/requests")" -eq $((requests_before + 1)) ]] && ok "one probe per call, never retried" ||
  bad "the probe retried"

((FAILED)) && exit 1
exit 0
