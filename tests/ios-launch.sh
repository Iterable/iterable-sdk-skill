#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-launch-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-launch-test.*|/private/tmp/iterable-ios-launch-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_LAUNCH_STATE/calls"
if [[ "$*" == "simctl list devices --json" ]]; then
  if [[ -f "$IOS_LAUNCH_STATE/no-simulator" ]]; then
    printf '{"devices":{}}\n'
  else
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-0":[{"udid":"SIM-BOOTED","state":"Booted","name":"iPhone"}]}}\n'
  fi
elif [[ "$*" == simctl\ launch* ]]; then
  printf '%s|%s|%s\n' \
    "${SIMCTL_CHILD_ITERABLE_PROOF_RUN_ID:-}" \
    "${SIMCTL_CHILD_ITERABLE_PROOF_EXPIRES_AT:-}" \
    "${SIMCTL_CHILD_ITERABLE_PROOF_PHASE:-}" \
    > "$IOS_LAUNCH_STATE/simulator-environment"
elif [[ "$*" == devicectl\ device\ process\ launch* ]]; then
  exit 0
else
  exit 2
fi
EOF
chmod +x "$FAKEBIN/xcrun"

write_target() {
  cat > "$WORKSPACE/proof-target.json" <<EOF
{"bundle_id":"com.example.sampleshop","device":"$1","device_kind":"$2","run_id":"run-launch-1"}
EOF
}

write_target SIM-BOOTED simulator
simulator_out="$(
  env PATH="$FAKEBIN:$PATH" IOS_LAUNCH_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-launch --phase restore
)"
simulator_rc=$?
if [[ "$simulator_rc" -eq 0 &&
      "$(stat -f '%Lp' "$WORKSPACE/launches/restore.json")" == 600 ]] &&
    node -e '
      const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.exit(v.launched===true && v.phase==="restore" &&
        v.bundle_id==="com.example.sampleshop" &&
        v.device==="SIM-BOOTED" && v.device_kind==="simulator" &&
        v.run_id==="run-launch-1" &&
        Date.parse(v.expires_at)>Date.parse(v.launched_at) ? 0 : 1);
    ' "$WORKSPACE/launches/restore.json" &&
    grep -q '^run-launch-1|.*|restore$' "$STATE/simulator-environment" &&
    grep -q 'simctl launch --terminate-running-process SIM-BOOTED com.example.sampleshop' \
      "$STATE/calls"; then
  ok "Simulator launch carries one short-lived run and writes only its scoped receipt"
else
  bad "Simulator launch did not preserve the actor/read boundary"
fi

touch "$STATE/no-simulator"
write_target 00008101-PHYSICAL physical
physical_out="$(
  env PATH="$FAKEBIN:$PATH" IOS_LAUNCH_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-launch --phase initial
)"
physical_rc=$?
if [[ "$physical_rc" -eq 0 ]] &&
    [[ "$(stat -f '%Lp' "$WORKSPACE/launches/initial.json")" == 600 ]] &&
    node -e '
      const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.exit(v.device_kind==="physical" ? 0 : 1);
    ' "$WORKSPACE/launches/initial.json" &&
    grep -q 'devicectl device process launch --device 00008101-PHYSICAL --terminate-existing --environment-variables' \
      "$STATE/calls" &&
    grep -q 'ITERABLE_PROOF_RUN_ID.*run-launch-1' "$STATE/calls" &&
    grep -q 'proof phase initial' <<< "$physical_out" &&
    grep -q 'Re-run ios-verify status now' <<< "$physical_out" &&
    ! grep -q 'use the app manually\\|identify User A' <<< "$physical_out"; then
  ok "physical launch records the run without blindly asking for login"
else
  bad "physical launch did not bind the exact app to the proof run"
fi

env PATH="$FAKEBIN:$PATH" IOS_LAUNCH_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-launch --phase wrong >"$ROOT/wrong.out" 2>"$ROOT/wrong.err"
wrong_rc=$?
if [[ "$wrong_rc" -ne 0 ]]; then
  ok "unknown proof phases are rejected before launch"
else
  bad "an unknown proof phase reached the device"
fi

((FAILED)) && exit 1
exit 0
