#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-send-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-send-test.*|/private/tmp/iterable-ios-send-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE"

cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
config="$(cat)"
printf '%s\n' "$config" >> "$IOS_SEND_STATE/calls"
if grep -q '/api/templates/push/upsert' <<< "$config"; then
  printf '{"msg":"Upserted 1 templates with IDs: 424242"}\n200\n'
elif grep -q '/api/templates/push/proof' <<< "$config"; then
  if [[ -f "$IOS_SEND_STATE/fail-proof-response" ]]; then
    printf 'connection reset after request\n000\n'
  else
    printf '{"msg":"Push proof sent"}\n200\n'
  fi
else
  printf '{"msg":"unexpected"}\n500\n'
fi
EOF
chmod +x "$FAKEBIN/curl"

cat > "$WORKSPACE/.env" <<'EOF'
ITERABLE_DATA_REGION=US
ITERABLE_SERVER_KEY=server-key-that-must-never-print
EOF
cat > "$WORKSPACE/proof-target.json" <<'EOF'
{
  "proof_mode": "instrumented",
  "bundle_id": "com.example.sampleshop",
  "identity_type": "email",
  "identity": "ios-proof@example.com",
  "switch_identity": "ios-proof-b@example.com",
  "device": "00008101-TESTDEVICE",
  "device_kind": "physical",
  "environment": "development",
  "run_id": "causal-run-1",
  "started_at": "2026-10-08T12:00:00Z",
  "markers": {
    "direct": "ITBL-IOS-DIRECT-ABC123",
    "user_targeted": "ITBL-IOS-USER-A-ABC123",
    "user_targeted_switch": "ITBL-IOS-USER-B-ABC123"
  }
}
EOF
chmod 600 "$WORKSPACE/.env" "$WORKSPACE/proof-target.json"

prepare_springboard() {
  local purpose="$1"
  local observed_at
  observed_at="$(node -e 'process.stdout.write(new Date().toISOString())')"
  mkdir -p "$WORKSPACE/observations"
  cat > "$WORKSPACE/observations/current-notifications-$purpose.json" <<EOF
{"inspected":true,"kind":"notifications","purpose":"$purpose","bundle_id":"com.example.sampleshop","device":"00008101-TESTDEVICE","run_id":"causal-run-1","observed_at":"$observed_at","non_interactive":true,"may_foreground_target":true,"classification":"springboard_visible","summary":"SpringBoard accessibility state was read"}
EOF
  chmod 600 "$WORKSPACE/observations/current-notifications-$purpose.json"
}

run_send() {
  env PATH="$FAKEBIN:$PATH" IOS_SEND_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-send "$@"
}

run_send target --recipient initial >"$ROOT/unconfirmed.out" 2>"$ROOT/unconfirmed.err"
unconfirmed_rc=$?
if [[ "$unconfirmed_rc" -ne 0 &&
      ! -e "$WORKSPACE/sends/development/user-targeted.json" ]]; then
  ok "a targeted proof send requires explicit confirmation"
else
  bad "a targeted proof send happened without confirmation"
fi

run_send target --recipient initial --confirm >"$ROOT/unprepared.out" 2>"$ROOT/unprepared.err"
unprepared_rc=$?
if [[ "$unprepared_rc" -ne 0 &&
      ! -e "$WORKSPACE/sends/development/user-targeted.json" ]] &&
    grep -q 'prepare SpringBoard' "$ROOT/unprepared.err"; then
  ok "a targeted proof send cannot bypass SpringBoard preparation"
else
  bad "the sender allowed a proof send without fresh device preparation"
fi

prepare_springboard pre-send
initial_out="$(run_send target --recipient initial --confirm 2>&1)"
initial_rc=$?
initial_manifest="$WORKSPACE/sends/development/user-targeted.json"
expected_marker_hash="$(printf '%s' 'ITBL-IOS-USER-A-ABC123' | shasum -a 256 | awk '{print $1}')"
expected_identity_hash="$(printf '%s' 'ios-proof@example.com' | shasum -a 256 | awk '{print $1}')"
if [[ "$initial_rc" -eq 0 && -f "$initial_manifest" &&
      "$(stat -f '%Lp' "$initial_manifest")" == 600 ]] &&
    node -e '
      const fs=require("fs"), crypto=require("crypto");
      const v=require(process.argv[1]);
      const calls=fs.readFileSync(process.argv[4],"utf8");
      const match=calls.match(/iterableProofNonce\\":\\"([0-9a-f]{64})/);
      const nonceHash=match
        ? crypto.createHash("sha256").update(match[1]).digest("hex")
        : "";
      process.exit(
        v.contract===3 &&
        v.state==="sent" &&
        v.sent===true &&
        v.kind==="user-targeted" &&
        v.source==="iterable-api-template-proof" &&
        v.marker_sha256===process.argv[2] &&
        v.recipient_sha256===process.argv[3] &&
        v.template_id===424242 &&
        v.delivery_nonce_sha256===nonceHash &&
        /^[0-9a-f]{64}$/.test(v.payload_sha256) &&
        !calls.includes(`"delivery_nonce":"${match?.[1]||""}"`) ? 0 : 1
      );
    ' "$initial_manifest" "$expected_marker_hash" "$expected_identity_hash" \
      "$STATE/calls" &&
    [[ "$(grep -c '/api/templates/push/' "$STATE/calls")" -eq 2 ]] &&
    grep -q 'recipientEmail\\":\\"ios-proof@example.com' "$STATE/calls" &&
    ! grep -q 'server-key-that-must-never-print' <<< "$initial_out"; then
  ok "User A proof carries its recipient contract and sender-only nonce"
else
  bad "User A sender did not create one secure exact manifest"
fi

run_send target --recipient initial --confirm >"$ROOT/repeat.out" 2>"$ROOT/repeat.err"
repeat_rc=$?
if [[ "$repeat_rc" -ne 0 ]] &&
    grep -q 'already exists' "$ROOT/repeat.err"; then
  ok "a proof send cannot be overwritten or silently repeated"
else
  bad "the sender allowed duplicate evidence for one run"
fi

prepare_springboard pre-send-switch
switch_out="$(run_send target --recipient switch --confirm 2>&1)"
switch_rc=$?
if [[ "$switch_rc" -eq 0 &&
      -f "$WORKSPACE/sends/development/user-targeted-switch.json" ]] &&
    grep -q 'ITBL-IOS-USER-B-ABC123' "$STATE/calls" &&
    ! grep -q 'ios-proof-b@example.com' <<< "$switch_out"; then
  ok "User B gets a distinct generated marker without leaking the identity in output"
else
  bad "User B sender did not remain distinct and secret-safe"
fi

run_send record-direct >"$ROOT/direct.out" 2>"$ROOT/direct.err"
direct_rc=$?
if [[ "$direct_rc" -ne 0 && ! -e "$WORKSPACE/sends/development/direct.json" ]]; then
  ok "a direct dashboard send cannot be recorded without explicit confirmation"
else
  bad "direct send evidence appeared without confirmation"
fi

direct_out="$(run_send record-direct --confirm 2>&1)"
direct_manifest="$WORKSPACE/sends/development/direct.json"
if [[ -f "$direct_manifest" && "$(stat -f '%Lp' "$direct_manifest")" == 600 ]] &&
    node -e '
      const v=require(process.argv[1]);
      process.exit(
        v.contract===2 &&
        v.kind==="direct" &&
        v.source==="iterable-dashboard-test-push" ? 0 : 1
      );
    ' "$direct_manifest" &&
    grep -q 'Delivery remains unproved' <<< "$direct_out"; then
  ok "dashboard-only direct send is recorded without being called delivery proof"
else
  bad "direct dashboard provenance was missing or overstated"
fi

rm -rf "$WORKSPACE/sends"
node -e '
  const fs=require("fs");
  const path=process.argv[1];
  const v=JSON.parse(fs.readFileSync(path,"utf8"));
  v.run_id="causal-run-2";
  v.started_at=new Date(Date.now()-1000).toISOString();
  fs.writeFileSync(path,JSON.stringify(v,null,2)+"\n",{mode:0o600});
' "$WORKSPACE/proof-target.json"
node -e '
  const fs=require("fs");
  const path=process.argv[1];
  const v=JSON.parse(fs.readFileSync(path,"utf8"));
  v.run_id="causal-run-2";
  v.observed_at=new Date().toISOString();
  fs.writeFileSync(path,JSON.stringify(v,null,2)+"\n",{mode:0o600});
' "$WORKSPACE/observations/current-notifications-pre-send.json"
touch "$STATE/fail-proof-response"
calls_before_uncertain="$(grep -c '/api/templates/push/proof' "$STATE/calls")"
run_send target --recipient initial --confirm >"$ROOT/uncertain.out" 2>"$ROOT/uncertain.err"
uncertain_rc=$?
uncertain_manifest="$WORKSPACE/sends/development/user-targeted.json"
run_send target --recipient initial --confirm >"$ROOT/uncertain-repeat.out" 2>"$ROOT/uncertain-repeat.err"
uncertain_repeat_rc=$?
calls_after_uncertain="$(grep -c '/api/templates/push/proof' "$STATE/calls")"
if [[ "$uncertain_rc" -ne 0 && "$uncertain_repeat_rc" -ne 0 &&
      -f "$uncertain_manifest" &&
      "$calls_after_uncertain" -eq $((calls_before_uncertain + 1)) ]] &&
    node -e '
      const v=require(process.argv[1]);
      process.exit(
        v.contract===3 &&
        v.state==="prepared" &&
        v.sent===false &&
        !v.sent_at ? 0 : 1
      );
    ' "$uncertain_manifest" &&
    grep -q 'will not resend' "$ROOT/uncertain.err" &&
    grep -q 'risking a duplicate' "$ROOT/uncertain-repeat.err"; then
  ok "an uncertain API response leaves a non-repeatable send intent"
else
  bad "an uncertain API response could be retried as a duplicate send"
fi

((FAILED)) && exit 1
exit 0
