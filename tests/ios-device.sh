#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-device-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-device-test.*|/private/tmp/iterable-ios-device-test.*) ;;
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
printf '%s\n' "$*" >> "$IOS_DEVICE_STATE/calls"
if [[ "$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{"runtime":[{"udid":"SIM-RECORDED","name":"iPhone","state":"Shutdown","isAvailable":true}]}}\n'
elif [[ "$*" == "simctl boot SIM-RECORDED" ||
        "$*" == "simctl bootstatus SIM-RECORDED -b" ]]; then
  exit 0
else
  exit 2
fi
EOF
chmod +x "$FAKEBIN/xcrun"

cat > "$WORKSPACE/proof-target.json" <<'EOF'
{"device":"SIM-RECORDED","device_kind":"simulator"}
EOF
chmod 600 "$WORKSPACE/proof-target.json"

out="$(
  env PATH="$FAKEBIN:$PATH" IOS_DEVICE_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-device boot
)"
rc=$?
if [[ "$rc" -eq 0 &&
      "$out" == *"Booted the recorded Simulator"* &&
      "$(grep -c '^simctl boot SIM-RECORDED$' "$STATE/calls")" -eq 1 &&
      "$(grep -c '^simctl bootstatus SIM-RECORDED -b$' "$STATE/calls")" -eq 1 ]]; then
  ok "a shut-down recorded Simulator is booted without selecting another target"
else
  bad "the Simulator boot actor did not preserve the recorded target"
fi

((FAILED)) && exit 1
exit 0
