#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-install-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-install-test.*|/private/tmp/iterable-ios-install-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
APP="$ROOT/SampleShop.app"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE" "$APP"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_INSTALL_STATE/calls"
if [[ "$*" == "simctl list devices --json" ]]; then
  if [[ -f "$IOS_INSTALL_STATE/physical" ]]; then
    printf '{"devices":{}}\n'
  else
    printf '{"devices":{"runtime":[{"udid":"SIM-BOOTED","state":"Booted"}]}}\n'
  fi
elif [[ "$*" == simctl\ install* || "$*" == devicectl\ device\ install\ app* ]]; then
  exit 0
else
  exit 2
fi
EOF
chmod +x "$FAKEBIN/xcrun"

write_target() {
  cat > "$WORKSPACE/proof-target.json" <<EOF
{"bundle_id":"com.example.sampleshop","device":"$1","device_kind":"$2","app_path":"$APP"}
EOF
}

write_target SIM-BOOTED simulator
simulator_out="$(
  env PATH="$FAKEBIN:$PATH" IOS_INSTALL_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-install
)"
if grep -q "simctl install SIM-BOOTED $APP" "$STATE/calls" &&
    grep -q 'Run ios-launch next' <<< "$simulator_out"; then
  ok "Simulator installation uses the exact recorded app and target"
else
  bad "Simulator installation changed or ignored the proof target"
fi

touch "$STATE/physical"
write_target 00008101-PHYSICAL physical
physical_out="$(
  env PATH="$FAKEBIN:$PATH" IOS_INSTALL_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-install
)"
if grep -q "devicectl device install app --device 00008101-PHYSICAL $APP" \
      "$STATE/calls" &&
    grep -q 'physical iPhone' <<< "$physical_out"; then
  ok "physical installation uses CoreDevice without launching or operating the app"
else
  bad "physical installation did not preserve the actor boundary"
fi

write_target 00008101-PHYSICAL simulator
env PATH="$FAKEBIN:$PATH" IOS_INSTALL_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-install >"$ROOT/mismatch.out" 2>"$ROOT/mismatch.err"
mismatch_rc=$?
if [[ "$mismatch_rc" -ne 0 ]] &&
    grep -q 'recorded Simulator is not booted' "$ROOT/mismatch.err"; then
  ok "recorded device type cannot be silently reclassified"
else
  bad "device kind mismatch reached installation"
fi

((FAILED)) && exit 1
exit 0
