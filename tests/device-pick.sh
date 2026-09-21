#!/usr/bin/env bash
# Pins which device the ladder decides to read, with a stubbed adb and no hardware.
#
# Worth pinning because every device gate inherits this one answer, and the failure
# mode is silent: a serial for a device that isn't there makes `adb -s` print
# nothing, and a gate that greps that output concludes the app isn't installed —
# a false red about a device nobody was asking about.
#
# The stub speaks the three adb dialects the resolver uses: `devices`,
# `-s X emu avd name`, and `-s X shell getprop`.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

STUB="$(mktemp -d)"; mkdir -p "$STUB/ws"
trap 'rm -rf "$STUB"' EXIT

cat > "$STUB/adb" <<'ADB'
#!/usr/bin/env bash
# STUB_DEVICES is "serial=avd serial=avd"; an empty avd means a physical phone.
# A device that appears part-way through a run (one being booted) is expressed by
# the emulator stub appending to STUB_STATE, which wins when it exists.
devs="${STUB_DEVICES:-}"
[[ -n "${STUB_STATE:-}" && -s "${STUB_STATE:-/nonexistent}" ]] && devs="$devs $(cat "$STUB_STATE")"
if [[ "$1" == devices ]]; then
  echo "List of devices attached"
  for pair in $devs; do printf '%s\tdevice\n' "${pair%%=*}"; done
  exit 0
fi
[[ "$1" == -s ]] || exit 1
serial="$2"; shift 2
avd=""
for pair in $devs; do
  [[ "${pair%%=*}" == "$serial" ]] && avd="${pair#*=}"
done
case "$*" in
  "emu avd name")               [[ -n "$avd" ]] && echo "$avd"; exit 0 ;;
  "shell getprop ro.product.model") echo "Pixel 7"; exit 0 ;;
  # A booting emulator answers adb long before the OS is up, which is the whole
  # reason boot_avd waits on this property instead of on the port.
  "shell getprop sys.boot_completed") [[ -f "${STUB_BOOTED:-/nonexistent}" ]] && echo 1; exit 0 ;;
  "logcat -d") [[ -n "${STUB_LOGCAT:-}" ]] && cat "$STUB_LOGCAT"; exit 0 ;;
esac
exit 0
ADB
chmod +x "$STUB/adb"

# STUB_BOOTS decides what starting an AVD does: "port" attaches but never finishes
# booting, "full" also sets boot_completed, anything else attaches nothing.
cat > "$STUB/emulator" <<'EMU'
#!/usr/bin/env bash
[[ "$1" == -list-avds ]] && { printf '%s\n' ${STUB_AVDS:-}; exit 0; }
[[ "$1" == -avd ]] || exit 1
case "${STUB_BOOTS:-none}" in
  port) printf 'emulator-5580=%s' "$2" > "$STUB_STATE" ;;
  full) printf 'emulator-5580=%s' "$2" > "$STUB_STATE"; : > "$STUB_BOOTED" ;;
esac
exit 0
EMU
chmod +x "$STUB/emulator"

# resolves <label> <STUB_DEVICES> <ANDROID_SERIAL> <TARGET_DEVICE> <expect-rc> <must-mention>
resolves() {
  local label="$1" devs="$2" as="$3" td="$4" want="$5" mention="${6:-}" out rc
  out="$(PATH="$STUB:$PATH" WS="$STUB/ws" STUB_DEVICES="$devs" ANDROID_SERIAL="$as" TARGET_DEVICE="$td" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; device_serial' 2>&1)"; rc=$?
  if ((rc != want)); then
    bad "$label — expected rc $want, got $rc ($out)"; return
  fi
  if [[ -n "$mention" && "$out" != *"$mention"* ]]; then
    bad "$label — rc $rc is right but the answer never says '$mention': $out"; return
  fi
  ok "$label → ${out:-<empty>}"
}

echo
echo "  Which device the gates read"
echo

A=emulator-5554; B=emulator-5556
resolves "one emulator, nothing remembered" "$A=Pixel_9_Pro" "" "" 0 "$A"
resolves "two attached — refuses to guess"  "$A=Medium_Phone $B=Pixel_9_Pro" "" "" 1 "2 devices attached"
# The port number is the part a human cannot recognise, so the ask has to name both AVDs.
resolves "...and names both AVDs"           "$A=Medium_Phone $B=Pixel_9_Pro" "" "" 1 "Pixel_9_Pro"
resolves "no device at all"                 "" "" "" 1 "no device"

resolves "ANDROID_SERIAL wins when present" "$A=Medium_Phone $B=Pixel_9_Pro" "$B" "" 0 "$B"
# The bug this file exists for: a serial that isn't connected must be a refusal,
# never a serial the gates go on to read nothing from.
resolves "ANDROID_SERIAL that isn't there"  "$A=Medium_Phone" emulator-9999 "" 1 "is not connected"

# A remembered choice is an AVD name, because emulator serials are handed out in
# boot order — the same AVD is 5554 today and 5556 tomorrow.
resolves "remembered AVD, now on 5556"      "$A=Medium_Phone $B=Pixel_9_Pro" "" Pixel_9_Pro 0 "$B"
resolves "remembered AVD, moved to 5554"    "$A=Pixel_9_Pro $B=Medium_Phone" "" Pixel_9_Pro 0 "$A"
resolves "remembered AVD not running"       "$A=Medium_Phone" "" Pixel_9_Pro 1 "not running"
resolves "remembered physical serial"       "R3CN70=" "" R3CN70 0 "R3CN70"
# An explicit override outranks the remembered device, or you cannot get out of a
# bad remembered choice without editing a file.
resolves "ANDROID_SERIAL beats remembered"  "$A=Medium_Phone $B=Pixel_9_Pro" "$A" Pixel_9_Pro 0 "$A"

echo
echo "  Starting an AVD the developer picked"
echo

# boots <label> <STUB_BOOTS> <expect-rc> <must-mention>
boots() {
  local label="$1" mode="$2" want="$3" mention="$4" out rc
  rm -f "$STUB/state" "$STUB/booted"
  out="$(PATH="$STUB:$PATH" WS="$STUB/ws" STUB_DEVICES="" STUB_BOOTS="$mode" \
    STUB_STATE="$STUB/state" STUB_BOOTED="$STUB/booted" BOOT_WAIT=3 BOOT_POLL=1 \
    bash -c 'source bin/config.sh >/dev/null 2>&1; boot_avd Pixel_9_Pro' 2>&1)"; rc=$?
  if ((rc != want)); then bad "$label — expected rc $want, got $rc ($out)"; return; fi
  [[ "$out" == *"$mention"* ]] || { bad "$label — never says '$mention': $out"; return; }
  ok "$label"
}

boots "an AVD that comes up is the serial it came up on" full 0 emulator-5580
# The branch that could only be read, not run, until boot_avd moved into config.sh.
# It is the one a developer hits on a machine too slow or too full to boot an AVD,
# so "it may still come up" matters: the run is not a verdict about their project.
boots "one that never boots gives up, and says so"       port 1 "did not finish booting"
boots "one that never attaches at all also gives up"     none 1 "did not finish booting"

echo
echo "  Which identity the app registered"
echo

# identity <label> <logcat-body> <expected-output>
identity() {
  local label="$1" body="$2" want="$3" out
  printf '%s\n' "$body" > "$STUB/logcat.txt"
  out="$(PATH="$STUB:$PATH" WS="$STUB/ws" STUB_DEVICES="$A=Pixel_9_Pro" STUB_LOGCAT="$STUB/logcat.txt" \
    bash -c 'source bin/config.sh >/dev/null 2>&1; app_identity' 2>&1 | tr '\n' ' ')"
  [[ "${out% }" == "$want" ]] && ok "$label → ${out:-<empty>}" \
    || bad "$label — wanted '$want', got '${out% }'"
}

REG='V IterableRequest: URI : https://api.iterable.com/api/users/registerDeviceToken'
identity "reads the address out of the SDK's own request" \
  "$REG
V IterableRequest:   \"email\": \"test@useremail.com\"," \
  "test@useremail.com"

# A developer who changed the signed-in identity mid-session has both in the
# buffer. The newest is the one whose token is current, so it has to come first.
identity "most recent identity first when it changed" \
  "V IterableRequest:   \"email\": \"old@example.com\",
V IterableRequest:   \"email\": \"new@example.com\"," \
  "new@example.com old@example.com"

# Silence must stay silence: offering a guessed default is worse than asking.
identity "nothing registered yet says nothing" "D SomeOtherTag: hello" ""
identity "ignores addresses logged by anything else" \
  "V OtherLibrary:   \"email\": \"noise@example.com\"," ""

echo
echo "  Labels and truncation"
echo

label="$(PATH="$STUB:$PATH" STUB_DEVICES="$B=Pixel_9_Pro" \
  WS="$STUB/ws" bash -c 'source bin/config.sh >/dev/null 2>&1; device_label emulator-5556')"
[[ "$label" == "Pixel_9_Pro (emulator-5556)" ]] \
  && ok "an emulator is labelled by AVD: $label" \
  || bad "emulator label is $label"

label="$(PATH="$STUB:$PATH" STUB_DEVICES="R3CN70=" \
  WS="$STUB/ws" bash -c 'source bin/config.sh >/dev/null 2>&1; device_label R3CN70')"
[[ "$label" == "Pixel 7 (R3CN70)" ]] \
  && ok "a phone is labelled by model: $label" \
  || bad "phone label is $label"

# A verdict cut mid-word reads like the whole verdict. This is the exact string
# that lost its remedy on a live run.
long="no user yet — nothing has registered somebody.with.a.long.address@example.com and if the app signs in as a different address, set ITBL_EMAIL to that one"
out="$(printf '%s' "$long" | WS="$STUB/ws" bash -c 'source bin/config.sh >/dev/null 2>&1; brief')"
[[ "$out" == *"…" && "$out" != *"differen…" && ${#out} -le 101 ]] \
  && ok "an over-long verdict ends on a word and says it was cut" \
  || bad "brief() produced: $out"

short="no user yet — nothing has registered test@useremail.com"
[[ "$(printf '%s' "$short" | WS="$STUB/ws" bash -c 'source bin/config.sh >/dev/null 2>&1; brief')" == "$short" ]] \
  && ok "a verdict that fits is left alone" \
  || bad "brief() altered a short verdict"

echo
((FAILED)) && exit 1
echo "  All good — the resolver picks a device or says why it won't."
