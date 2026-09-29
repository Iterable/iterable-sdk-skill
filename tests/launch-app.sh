#!/usr/bin/env bash
# Pins the one allowed device action: open the chosen package's launcher activity.
# Everything after that — sign-in and the notification prompt — remains human work.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

STUB="$(mktemp -d)"
trap 'rm -rf "$STUB"' EXIT
mkdir -p "$STUB/ws"

cat > "$STUB/adb" <<'ADB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$STUB_CALLS"

if [[ "$1" == devices ]]; then
  printf 'List of devices attached\nemulator-5554\tdevice\n'
  exit 0
fi

[[ "$1 $2" == "-s emulator-5554" ]] || exit 1
shift 2
case "$*" in
  "emu avd name") echo Pixel_9_Pro ;;
  "shell pm path com.example.app")
    [[ "${STUB_INSTALLED:-1}" == 1 ]] && echo package:/data/app/com.example.app/base.apk
    ;;
  "shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.example.app")
    if [[ "${STUB_LAUNCHABLE:-1}" == 1 ]]; then
      printf 'Starting: Intent\nStatus: ok\n'
    else
      echo 'Error: Activity not started, unable to resolve Intent' >&2
      exit 1
    fi
    ;;
esac
ADB
chmod +x "$STUB/adb"

run_launch() {
  PATH="$STUB:$PATH" WS="$STUB/ws" PACKAGE="${PACKAGE_UNDER_TEST-com.example.app}" \
    TARGET_DEVICE=Pixel_9_Pro STUB_CALLS="$STUB/calls" \
    STUB_INSTALLED="${STUB_INSTALLED:-1}" STUB_LAUNCHABLE="${STUB_LAUNCHABLE:-1}" \
    bin/launch-app 2>&1
}

echo
echo "  Opening the installed app"
echo

: > "$STUB/calls"
out="$(run_launch)"; rc=$?
if ((rc == 0)) && [[ "$out" == *"Opened com.example.app on emulator-5554."* ]]; then
  ok "opens the selected package on the selected device"
else
  bad "expected a successful launch, got rc $rc: $out"
fi

expected="shell am start -W -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -p com.example.app"
grep -qF "$expected" "$STUB/calls" \
  && ok "uses the package's MAIN/LAUNCHER activity" \
  || bad "did not issue the expected launch intent"

if grep -qE 'shell (input|monkey)|pm grant|keyevent| tap | text ' "$STUB/calls"; then
  bad "used device input or granted a permission"
else
  ok "does not tap, type, sign in, or grant permission"
fi

echo
echo "  Refusing states that cannot be launched"
echo

: > "$STUB/calls"
STUB_INSTALLED=0 out="$(run_launch)"; rc=$?
if ((rc == 20)) && [[ "$out" == *"is not installed"* ]] \
   && ! grep -q 'shell am start' "$STUB/calls"; then
  ok "does not try to open an app that is not installed"
else
  bad "uninstalled app should stop before launch, got rc $rc: $out"
fi

: > "$STUB/calls"
PACKAGE_UNDER_TEST="" out="$(run_launch)"; rc=$?
if ((rc == 10)) && [[ "$out" == *"no package selected"* ]] \
   && ! grep -q 'shell am start' "$STUB/calls"; then
  ok "does not guess which package to open"
else
  bad "missing package should ask for a choice, got rc $rc: $out"
fi

: > "$STUB/calls"
unset STUB_INSTALLED
unset PACKAGE_UNDER_TEST
STUB_LAUNCHABLE=0 out="$(run_launch)"; rc=$?
if ((rc == 20)) && [[ "$out" == *"could not open"* ]]; then
  ok "reports a package with no launchable activity"
else
  bad "unlaunchable package should fail clearly, got rc $rc: $out"
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — launch stops where human interaction begins."
