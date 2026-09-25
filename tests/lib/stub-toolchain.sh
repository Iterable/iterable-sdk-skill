#!/usr/bin/env bash
# A toolchain for suites that test what the ladder *decides*, so they decide their own
# preconditions instead of inheriting whatever is installed on the machine running them.
#
# Written because two suites were green for months on a developer's laptop and failed the
# first time CI ran them on a clean runner. `REQUIRED_TOOLS=(node gcloud adb java)`, and
# `next_action` reports `install_tools` ahead of everything else when one is absent — so on
# a machine without gcloud every assertion about a later rung was testing the install
# branch instead. Not a product bug: `install_tools` is the right answer there. The suites
# simply never established the state they were asserting about.
#
# The fix is to supply the tools, not to hide them. `ending-shape.sh` had a comment
# reasoning the other way — that stubbing tools *away* would derail the branch under test,
# so PATH was left alone — which is true and still leaves the suite depending on the host.
#
# Nothing here reaches a network or a device. gcloud logs and fails on purpose: these
# suites must not call Google, and a recorded attempt is a stronger claim than an absent
# binary. Suites that test the device resolver itself want a richer adb than this and
# build their own (see device-pick.sh); this is the minimum that lets a screen be drawn.
#
# Usage:  stub_toolchain "$TMP/tools"   then   PATH="$TMP/tools:$PATH"
# Set STUB_CALLS to a file first to record any gcloud attempt.

stub_toolchain() {
  local d="$1"
  mkdir -p "$d" || return 1

  printf '#!/bin/sh\necho "gcloud $*" >> "${STUB_CALLS:-/dev/null}"\nexit 1\n' > "$d/gcloud"

  # Only has to exist; the ladder checks for a JDK and never runs it here.
  printf '#!/bin/sh\nexit 0\n' > "$d/java"

  # One booted emulator, answering the dialects the device resolver uses to name it.
  cat > "$d/adb" <<'ADB'
#!/bin/sh
echo "adb $*" >> "${STUB_CALLS:-/dev/null}"
if [ "$1" = devices ]; then
  echo "List of devices attached"
  echo "emulator-5556	device"
  exit 0
fi
# adb -s <serial> ...
shift 2 2>/dev/null || exit 0
case "$1 $2 $3" in
  "emu avd name") printf 'Test_AVD\nOK\n' ;;
  "shell getprop "*|"shell getprop") echo "sdk_gphone64_arm64" ;;
  *) : ;;
esac
exit 0
ADB

  chmod +x "$d/gcloud" "$d/java" "$d/adb"
}
