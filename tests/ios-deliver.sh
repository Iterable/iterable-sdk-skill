#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-deliver-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-deliver-test.*|/private/tmp/iterable-ios-deliver-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE/observations"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
[[ "$*" == "simctl list devices --json" ]] && printf '{"devices":{}}\n'
EOF
cat > "$FAKEBIN/agent-device" <<'EOF'
#!/usr/bin/env bash
set -eu
case "$1" in
  open)
    printf 'observer-open\n' >> "$IOS_DELIVER_STATE/order"
    printf '{"ok":true}\n'
    ;;
  wait)
    printf 'observer-wait-start\n' >> "$IOS_DELIVER_STATE/order"
    for _ in $(seq 1 300); do
      if [[ -f "$IOS_DELIVER_STATE/send-proof" ]]; then
        printf '{"matched":true}\n'
        exit 0
      fi
      sleep 0.01
    done
    printf '{"matched":false,"reason":"fixture timeout"}\n' >&2
    exit 1
    ;;
  close) ;;
esac
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
request="$(cat) $*"
if grep -q '/api/templates/push/upsert' <<< "$request"; then
  printf 'curl-upsert\n' >> "$IOS_DELIVER_STATE/order"
  printf '{"msg":"Upserted 1 templates with IDs: 424242"}\n200\n'
elif grep -q '/api/templates/push/proof' <<< "$request"; then
  printf 'curl-proof\n' >> "$IOS_DELIVER_STATE/order"
  touch "$IOS_DELIVER_STATE/send-proof"
  printf '{"msg":"Push proof sent"}\n200\n'
else
  printf '{"msg":"unexpected request"}\n500\n'
fi
EOF
chmod +x "$FAKEBIN"/*

NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cat > "$WORKSPACE/proof-target.json" <<EOF
{
  "proof_mode":"behavioral",
  "bundle_id":"com.example.dogshelter",
  "identity_type":"email",
  "identity":"dogs@example.com",
  "device":"PHYSICAL-DELIVER-1",
  "device_kind":"physical",
  "environment":"development",
  "run_id":"deliver-run",
  "started_at":"$NOW",
  "markers":{"user_targeted":"ITBL-IOS-USER-A-DELIVER"}
}
EOF
cat > "$WORKSPACE/.env" <<'EOF'
ITERABLE_SERVER_KEY=server-deliver-key
ITERABLE_DATA_REGION=US
EOF
cat > "$WORKSPACE/scope.json" <<'EOF'
{"data_region":"US"}
EOF
cat > "$WORKSPACE/observations/current-notifications-pre-send.json" <<EOF
{
  "inspected":true,
  "non_interactive":true,
  "may_foreground_target":true,
  "kind":"notifications",
  "purpose":"pre-send",
  "classification":"springboard_visible",
  "bundle_id":"com.example.dogshelter",
  "device":"PHYSICAL-DELIVER-1",
  "run_id":"deliver-run",
  "observed_at":"$NOW"
}
EOF
chmod 600 \
  "$WORKSPACE/proof-target.json" \
  "$WORKSPACE/.env" \
  "$WORKSPACE/scope.json" \
  "$WORKSPACE/observations/current-notifications-pre-send.json"

env \
  PATH="$FAKEBIN:$PATH" \
  IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
  IOS_DELIVER_STATE="$STATE" \
  IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-deliver target --recipient initial --confirm --timeout 3000 \
    >"$ROOT/deliver.out" 2>"$ROOT/deliver.err"
deliver_rc=$?
wait_line="$(grep -n '^observer-wait-start$' "$STATE/order" | cut -d: -f1)"
proof_line="$(grep -n '^curl-proof$' "$STATE/order" | cut -d: -f1)"
if [[ "$deliver_rc" -eq 0 &&
      -n "$wait_line" && -n "$proof_line" ]] &&
    ((wait_line < proof_line)) &&
    [[ "$(grep -c '^curl-proof$' "$STATE/order")" == 1 &&
       -f "$WORKSPACE/sends/development/user-targeted.json" &&
       -f "$WORKSPACE/proof/development/user-targeted.json" ]] &&
    node -e '
      const send=require(process.argv[1]);
      const receipt=require(process.argv[2]);
      process.exit(
        send.sent===true &&
        send.state==="sent" &&
        receipt.observed===true &&
        receipt.observer==="agent-device accessibility" ? 0 : 1
      );
    ' "$WORKSPACE/sends/development/user-targeted.json" \
      "$WORKSPACE/proof/development/user-targeted.json"; then
  ok "the independent observer is waiting before the single proof send"
else
  bad "delivery coordination did not close the short-banner race safely"
fi

env \
  PATH="$FAKEBIN:$PATH" \
  IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
  IOS_DELIVER_STATE="$STATE" \
  IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-deliver target --recipient initial --confirm --timeout 3000 \
    >"$ROOT/repeat.out" 2>"$ROOT/repeat.err"
repeat_rc=$?
if [[ "$repeat_rc" -eq 30 &&
      "$(grep -c '^curl-proof$' "$STATE/order")" == 1 ]] &&
    grep -q 'do not use the coordinator to resend' "$ROOT/repeat.err"; then
  ok "the coordinator refuses a duplicate send after any recorded attempt"
else
  bad "delivery coordination could repeat a proof send"
fi

((FAILED)) && exit 1
exit 0
