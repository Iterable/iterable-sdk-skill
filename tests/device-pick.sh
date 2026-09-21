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
if [[ "$1" == devices ]]; then
  echo "List of devices attached"
  for pair in ${STUB_DEVICES:-}; do printf '%s\tdevice\n' "${pair%%=*}"; done
  exit 0
fi
[[ "$1" == -s ]] || exit 1
serial="$2"; shift 2
avd=""
for pair in ${STUB_DEVICES:-}; do
  [[ "${pair%%=*}" == "$serial" ]] && avd="${pair#*=}"
done
case "$*" in
  "emu avd name")               [[ -n "$avd" ]] && echo "$avd"; exit 0 ;;
  "shell getprop ro.product.model") echo "Pixel 7"; exit 0 ;;
esac
exit 0
ADB
chmod +x "$STUB/adb"

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
