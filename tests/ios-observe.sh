#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-observe-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-observe-test.*|/private/tmp/iterable-ios-observe-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices --json" ]]; then
  if [[ -f "$IOS_OBSERVE_STATE/simulator-mode" ]]; then
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"SIM-OBSERVE-1","name":"iPhone 16","state":"Booted","isAvailable":true}]}}\n'
  else
    printf '{"devices":{}}\n'
  fi
else
  exit 2
fi
EOF
cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
printf 'Xcode 18.0\nBuild version 18A1\n'
EOF
cat > "$FAKEBIN/sw_vers" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -productVersion ]] && printf '15.0\n'
EOF
cat > "$FAKEBIN/uname" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -m ]] && printf 'arm64\n'
EOF
cat > "$FAKEBIN/agent-device" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_OBSERVE_STATE/calls"
case "$1" in
  open)
    printf '{"ok":true}\n'
    ;;
  snapshot)
    printf '{"elements":[{"text":"All Dogs"},{"text":"Logout"}]}\n'
    ;;
  logs)
    if [[ "${2:-}" == path ]]; then
      printf '%s\n' "$IOS_OBSERVE_STATE/app.log"
    fi
    ;;
  wait)
    if [[ -f "$IOS_OBSERVE_STATE/fail-wait" ]]; then
      printf '{"matched":false,"reason":"fixture timeout"}\n' >&2
      exit 1
    fi
    printf '{"matched":true}\n'
    ;;
  close)
    ;;
esac
EOF
chmod +x "$FAKEBIN/xcrun" "$FAKEBIN/agent-device"
cat > "$STATE/app.log" <<'EOF'
Sample Shop: Iterable initialized
Sample Shop: remote notification registration failed: fixture failure
Sample Shop: Api-Key=server-secret-that-must-not-print
unrelated line
EOF

cat > "$WORKSPACE/proof-target.json" <<'EOF'
{
  "bundle_id":"com.example.sampleshop",
  "device":"PHYSICAL-DEVICE",
  "device_kind":"physical",
  "environment":"development",
  "started_at":"2026-10-16T08:00:00Z",
  "run_id":"observe-run",
  "markers":{"user_targeted":"ITBL-IOS-USER-A-OBSERVE"}
}
EOF
chmod 600 "$WORKSPACE/proof-target.json"

out="$(
  env \
    PATH="$FAKEBIN:$PATH" \
    IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
    IOS_OBSERVE_STATE="$STATE" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-observe inspect --kind app --purpose identity
)"
rc=$?
if [[ "$rc" -eq 0 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(
        v.non_interactive===true &&
        v.may_foreground_target===true &&
        v.purpose==="identity" &&
        v.kind==="app" &&
        JSON.stringify(v.snapshot).includes("All Dogs") &&
        v.relevant_log_tail.includes("registration failed") &&
        !v.relevant_log_tail.includes("server-secret-that-must-not-print") ? 0 : 1
      );
    ' "$out" &&
    grep -q 'open com.example.sampleshop' "$STATE/calls" &&
    grep -q 'snapshot --force-full --json' "$STATE/calls" &&
    grep -q 'logs path' "$STATE/calls" &&
    [[ -f "$WORKSPACE/observations/current-app-identity.json" &&
       "$(stat -f '%Lp' "$WORKSPACE/observations/current-app-identity.json")" == 600 ]] &&
    node -e '
      const value=require(process.argv[1]);
      process.exit(
        value.non_interactive===true &&
        value.may_foreground_target===true &&
        value.purpose==="identity" &&
        value.classification==="iterable_or_apns_error_visible" ? 0 : 1
      );
    ' "$WORKSPACE/observations/current-app-identity.json" &&
    [[ ! -e "$WORKSPACE/proof" ]]; then
  ok "non-interactive app inspection caches redacted diagnosis without manufacturing proof"
else
  bad "non-interactive app inspection did not expose existing state safely"
fi

marker_hash="$(printf '%s' 'ITBL-IOS-USER-A-OBSERVE' | shasum -a 256 | awk '{print $1}')"
mkdir -p "$WORKSPACE/sends/development"
cat > "$WORKSPACE/sends/development/user-targeted.json" <<EOF
{"contract":3,"state":"sent","sent":true,"kind":"user-targeted","source":"iterable-api-template-proof","bundle_id":"com.example.sampleshop","device":"PHYSICAL-DEVICE","device_kind":"physical","environment":"development","run_id":"observe-run","marker_sha256":"$marker_hash","sent_at":"2026-10-16T08:01:00Z"}
EOF
chmod 600 "$WORKSPACE/sends/development/user-targeted.json"
touch "$STATE/fail-wait"
for attempt in 1 2; do
  env \
    PATH="$FAKEBIN:$PATH" \
    IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
    IOS_OBSERVE_STATE="$STATE" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-observe delivery --kind user-targeted --timeout 1000 \
      >"$ROOT/timeout-$attempt.out" 2>"$ROOT/timeout-$attempt.err"
done
attempts_file="$WORKSPACE/observations/attempts/user-targeted.json"
if [[ -f "$attempts_file" && "$(stat -f '%Lp' "$attempts_file")" == 600 ]] &&
    node -e '
      const value=require(process.argv[1]);
      process.exit(
        value.contract===1 &&
        value.attempts===2 &&
        value.last_result==="timeout" &&
        value.observer_output.includes("/observations/runs/observe-run/user-targeted/") &&
        value.run_id==="observe-run" ? 0 : 1
      );
    ' "$attempts_file" &&
    [[ "$(find "$WORKSPACE/observations/runs/observe-run/user-targeted" \
        -type f -name 'agent-device-wait-*.log' | wc -l | tr -d ' ')" == 2 ]] &&
    find "$WORKSPACE/observations/runs/observe-run/user-targeted" \
      -type f -name 'agent-device-wait-*.log' -exec grep -q 'fixture timeout' {} \; &&
    find "$WORKSPACE/observations/runs/observe-run/user-targeted" \
      -type f -name 'agent-device-wait-*.log' \
      -exec sh -c '[[ "$(stat -f "%Lp" "$1")" == 600 ]]' _ {} \; &&
    [[ ! -e "$WORKSPACE/proof/development/user-targeted.json" ]]; then
  ok "bounded delivery timeouts preserve raw observer output without manufacturing proof"
else
  bad "delivery timeout state could not break repeated observation loops"
fi

rm -rf "$WORKSPACE/proof" "$WORKSPACE/observations"
touch "$STATE/simulator-mode" "$STATE/fail-wait"
cat > "$WORKSPACE/proof-target.json" <<'EOF'
{
  "bundle_id":"com.example.sampleshop",
  "device":"SIM-OBSERVE-1",
  "device_kind":"simulator",
  "environment":"development",
  "started_at":"2026-10-16T08:00:00Z",
  "run_id":"simulator-observe-run",
  "identity":"dogs@example.com",
  "markers":{"user_targeted":"ITBL-IOS-USER-A-DURABLE"}
}
EOF
chmod 600 "$WORKSPACE/proof-target.json"
durable_nonce="$(node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))')"
durable_nonce_hash="$(printf '%s' "$durable_nonce" | shasum -a 256 | awk '{print $1}')"
marker_hash="$(printf '%s' 'ITBL-IOS-USER-A-DURABLE' | shasum -a 256 | awk '{print $1}')"
cat > "$WORKSPACE/sends/development/user-targeted.json" <<EOF
{"contract":3,"state":"sent","sent":true,"kind":"user-targeted","source":"iterable-api-template-proof","bundle_id":"com.example.sampleshop","device":"SIM-OBSERVE-1","device_kind":"simulator","environment":"development","run_id":"simulator-observe-run","marker_sha256":"$marker_hash","delivery_nonce_sha256":"$durable_nonce_hash","sent_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
chmod 600 "$WORKSPACE/sends/development/user-targeted.json"
SIM_ROOT="$ROOT/CoreSimulator/Devices"
SIMULATE="$PWD/tests/fixtures/ios-prove/simulate"
"$SIMULATE" register "$SIM_ROOT" SIM-OBSERVE-1 com.example.sampleshop
STORE_FILE="$SIM_ROOT/SIM-OBSERVE-1/data/Library/UserNotifications/0B5E8D2A-3C1F-4E7A-9B6D-2F8C4A1E7D90/DeliveredNotifications.plist"
printf 'com.example.sampleshop\0dogs@example.com\0ITBL-IOS-USER-A-DURABLE\0' > "$STORE_FILE"
env PATH="$FAKEBIN:$PATH" IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_OBSERVE_STATE="$STATE" \
  ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$SIM_ROOT" IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-observe delivery --kind user-targeted --timeout 1000 >/dev/null 2>&1
if [[ ! -f "$WORKSPACE/proof/development/user-targeted.json" ]]; then
  ok "loose strings in a file named like the store do not count as a delivered record"
else
  bad "the durable fallback accepted bytes that are not a notification record"
  rm -f "$WORKSPACE/proof/development/user-targeted.json"
fi
"$SIMULATE" deliver apns "$SIM_ROOT" SIM-OBSERVE-1 com.example.sampleshop \
  ITBL-IOS-USER-A-DURABLE "$durable_nonce" 424242 "$ROOT/unused-log.ndjson"

env \
  PATH="$FAKEBIN:$PATH" \
  IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
  IOS_OBSERVE_STATE="$STATE" \
  ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$SIM_ROOT" \
  IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-observe delivery --kind user-targeted --timeout 1000 \
    >"$ROOT/durable.out" 2>"$ROOT/durable.err"
durable_rc=$?
durable_receipt="$WORKSPACE/proof/development/user-targeted.json"
if [[ "$durable_rc" -eq 0 && -f "$durable_receipt" ]] &&
    node -e '
      const value=require(process.argv[1]);
      process.exit(
        value.observed===true &&
        value.observer==="simulator-delivered-notifications" &&
        value.device==="SIM-OBSERVE-1" &&
        /^[a-f0-9]{64}$/.test(value.durable_evidence_path_sha256) ? 0 : 1
      );
    ' "$durable_receipt" &&
    grep -q 'durable delivered-notification record' "$ROOT/durable.out" &&
    [[ ! -e "$WORKSPACE/observations/attempts/user-targeted.json" ]]; then
  ok "a dismissed Simulator banner is proved from the exact durable delivery record"
else
  bad "durable Simulator evidence did not recover a real screen-observation miss"
fi

((FAILED)) && exit 1
exit 0
