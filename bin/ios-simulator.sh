#!/usr/bin/env bash

# Shared eligibility checks for Apple's real APNs-to-Simulator path.
# Apple supports this for iOS 16+ Simulator on macOS 13+ with Xcode 14+,
# on Apple silicon or an Intel Mac with a T2 security chip.

ios_simulator_host_supports_apns() {
  local macos_version xcode_version architecture
  command -v sw_vers >/dev/null 2>&1 || return 1
  command -v xcodebuild >/dev/null 2>&1 || return 1
  macos_version="$(sw_vers -productVersion 2>/dev/null)" || return 1
  xcode_version="$(xcodebuild -version 2>/dev/null |
    sed -n 's/^Xcode \([0-9][0-9]*\).*/\1/p' | head -1)"
  [[ "${macos_version%%.*}" =~ ^[0-9]+$ ]] || return 1
  [[ "$xcode_version" =~ ^[0-9]+$ ]] || return 1
  (( ${macos_version%%.*} >= 13 && xcode_version >= 14 )) || return 1
  architecture="$(uname -m 2>/dev/null)" || return 1
  [[ "$architecture" == arm64 ]] && return 0
  command -v system_profiler >/dev/null 2>&1 || return 1
  system_profiler SPiBridgeDataType 2>/dev/null |
    grep -qi 'Apple T2 Security Chip'
}

ios_simulator_device_supports_apns() {
  local devices_json="$1" wanted="$2"
  printf '%s' "$devices_json" | node -e '
    let input="";
    process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
      let root; try { root=JSON.parse(input) } catch { process.exit(1) }
      const wanted=process.argv[1];
      for (const [runtime,devices] of Object.entries(root.devices||{})) {
        for (const device of devices||[]) {
          if (device.udid!==wanted || device.state!=="Booted" ||
              device.isAvailable===false) continue;
          const identifier=String(device.runtimeIdentifier||runtime);
          const match=identifier.match(/(?:^|[.-])iOS[-.]?(\d+)/i);
          process.exit(match && Number(match[1])>=16 ? 0 : 1);
        }
      }
      process.exit(1);
    });
  ' "$wanted"
}

ios_simulator_device_runtime() {
  local devices_json="$1" wanted="$2"
  printf '%s' "$devices_json" | node -e '
    let input="";
    process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
      let root; try { root=JSON.parse(input) } catch { process.exit(1) }
      const wanted=process.argv[1];
      for (const [runtime,devices] of Object.entries(root.devices||{})) {
        const device=(devices||[]).find(candidate=>
          candidate.udid===wanted && candidate.state==="Booted"
        );
        if (device) {
          process.stdout.write(String(device.runtimeIdentifier||runtime));
          return;
        }
      }
      process.exit(1);
    });
  ' "$wanted"
}

# Simulator applications are ad-hoc signed. Xcode puts their runtime
# entitlements in the executable's __TEXT,__entitlements Mach-O section rather
# than in the code-signature entitlement blob used by physical-device builds.
ios_simulator_executable_entitlements() {
  local executable="$1"
  local architecture entitlement_section
  [[ -f "$executable" ]] || return 1
  command -v node >/dev/null 2>&1 || return 1
  command -v otool >/dev/null 2>&1 || return 1
  architecture="$(uname -m 2>/dev/null)" || return 1
  entitlement_section="$(
    otool -arch "$architecture" -s __TEXT __entitlements "$executable" 2>/dev/null
  )" || entitlement_section="$(
    otool -s __TEXT __entitlements "$executable" 2>/dev/null
  )" || return 1
  printf '%s\n' "$entitlement_section" |
    node -e '
      let input="";
      process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
        const bytes=[];
        for (const line of input.split(/\r?\n/)) {
          const fields=line.trim().split(/\s+/);
          if (fields.length<2 || !/^[0-9a-f]+$/i.test(fields[0])) continue;
          for (const word of fields.slice(1)) {
            // A section whose size is not a multiple of four ends in single bytes.
            if (/^[0-9a-f]{2}$/i.test(word)) { bytes.push(Number.parseInt(word,16)); continue; }
            if (!/^[0-9a-f]{8}$/i.test(word)) continue;
            for (let offset=6; offset>=0; offset-=2) {
              bytes.push(Number.parseInt(word.slice(offset,offset+2),16));
            }
          }
        }
        while (bytes.at(-1)===0) bytes.pop();
        if (!bytes.length) process.exit(1);
        process.stdout.write(Buffer.from(bytes));
      });
    '
}

# The devices-root override exists for the test suites only.
ios_simulator_devices_root() {
  if [[ "${ITERABLE_IOS_TEST_MODE:-}" == 1 && -n "${IOS_CORE_SIMULATOR_DEVICES_ROOT:-}" ]]; then
    printf '%s' "$IOS_CORE_SIMULATOR_DEVICES_ROOT"
  else
    printf '%s' "$HOME/Library/Developer/CoreSimulator/Devices"
  fi
}

# The selected Simulator's own runtime root, from CoreSimulator; empty if unknown.
ios_simulator_runtime_root() {
  local udid="$1" devices runtimes
  devices="$(xcrun simctl list devices --json 2>/dev/null)" || return 1
  runtimes="$(xcrun simctl list runtimes -j 2>/dev/null)" || return 1
  node -e '
    const [devicesRaw,runtimesRaw,udid]=process.argv.slice(1);
    let devices, runtimes;
    try { devices=JSON.parse(devicesRaw); runtimes=JSON.parse(runtimesRaw) } catch { process.exit(1) }
    let identifier="";
    for (const [runtime,list] of Object.entries(devices.devices||{})) {
      if ((list||[]).some(d=>d.udid===udid)) identifier=runtime;
    }
    const match=(runtimes.runtimes||[]).find(r=>r.identifier===identifier);
    const root=String(match?.runtimeRoot||"");
    if (!root || !root.startsWith("/") || root.split("/").includes("..")) process.exit(1);
    process.stdout.write(root);
  ' "$devices" "$runtimes" "$udid"
}

# `log show` accepts an explicit UTC offset, which avoids local-time conversion.
ios_simulator_log_time() {
  node -e '
    const t=new Date(Date.parse(process.argv[1])-Number(process.argv[2]||0));
    const p=n=>String(n).padStart(2,"0");
    process.stdout.write(`${t.getUTCFullYear()}-${p(t.getUTCMonth()+1)}-${p(t.getUTCDate())} ${p(t.getUTCHours())}:${p(t.getUTCMinutes())}:${p(t.getUTCSeconds())}+0000`);
  ' "$1" "${2:-0}"
}

# Prints {"lines":N,"events":[...]} for one bundle since an ISO time. When the
# bundle query returns nothing, N comes from an apsd canary instead, so an
# empty but working log is not mistaken for an unreadable one.
ios_simulator_proof_log() {
  local udid="$1" bundle="$2" since="$3" reader start predicate raw rc result lines canary root
  reader="$(dirname "${BASH_SOURCE[0]}")/ios-notify-read.js"
  root="$(ios_simulator_runtime_root "$udid")" || root=""
  start="$(ios_simulator_log_time "$since" 2000)"
  predicate="$(node "$reader" predicate "$bundle")" || return 1
  raw="$(mktemp "${TMPDIR:-/tmp}/iterable-ios-proof-log.XXXXXX")" || return 1
  xcrun simctl spawn "$udid" log show --start "$start" --style ndjson \
    --predicate "$predicate" > "$raw" 2>/dev/null
  rc=$?
  if [[ -n "$root" ]]; then
    result="$(node "$reader" log "$bundle" --root "$root" --since "$since" < "$raw" 2>/dev/null)" || {
      result='{"lines":0,"events":[]}'
      rc=1
    }
  else
    result="$(node -e '
      process.stdout.write(JSON.stringify({lines:1,events:[{kind:"unattributable",t:process.argv[1]}]}));
    ' "$since")"
  fi
  rm -f "$raw"
  if ((rc != 0)); then
    node -e '
      const v=JSON.parse(process.argv[1]); v.ok=false;
      process.stdout.write(JSON.stringify(v));
    ' "$result"
    return 0
  fi
  lines="$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).lines||0))' "$result")"
  if [[ "$lines" == 0 ]]; then
    canary="$(xcrun simctl spawn "$udid" log show --start "$start" --style ndjson \
      --predicate 'process == "apsd" OR process == "SpringBoard"' 2>/dev/null |
      node "$reader" log "$bundle" --root "${root:-/}" --since "$since" 2>/dev/null |
      node -e 'let i="";process.stdin.on("data",c=>i+=c).on("end",()=>{try{process.stdout.write(String(JSON.parse(i).lines||0))}catch{process.stdout.write("0")}})')"
    result="$(node -e '
      const v=JSON.parse(process.argv[1]); v.lines=Number(process.argv[2]||0);
      process.stdout.write(JSON.stringify(v));
    ' "$result" "${canary:-0}")"
  fi
  node -e '
    const v=JSON.parse(process.argv[1]); v.ok=true;
    process.stdout.write(JSON.stringify(v));
  ' "$result"
}

ios_physical_device_connected() {
  local wanted="$1" devices
  devices="$(xcrun devicectl --timeout 10 --quiet --json-output - list devices 2>/dev/null)" || return 1
  printf '%s' "$devices" | node -e '
    let input="";
    process.stdin.on("data",c=>input+=c).on("end",()=>{
      let root; try { root=JSON.parse(input) } catch { process.exit(1) }
      const wanted=process.argv[1];
      const strings=(v,pattern,out=[])=>{
        if (!v || typeof v!=="object") return out;
        for (const [key,child] of Object.entries(v)) {
          if (pattern.test(key) && ["string","number","boolean"].includes(typeof child)) out.push(String(child));
          else strings(child,pattern,out);
        }
        return out;
      };
      let found=false;
      const visit=v=>{
        if (found || !v || typeof v!=="object") return;
        if (!Array.isArray(v) && Object.entries(v).some(([key,value])=>
            /^(identifier|udid|deviceId|deviceIdentifier)$/i.test(key) && value===wanted)) {
          const descriptive=strings(v,/(name|platform|productType|deviceClass|deviceFamily|hardwareModel|reality)/i).join(" ").toLowerCase();
          const connection=strings(v,/(connectionState|connectionStatus|state|visibility|pairingState)/i).join(" ").toLowerCase();
          found=!/\bsimulat(?:ed|or)\b|\bvirtual\b/.test(descriptive) &&
            !/\b(disconnected|unavailable|offline|unpaired)\b/.test(connection);
          if (found) return;
        }
        for (const child of Object.values(v)) visit(child);
      };
      visit(root);
      process.exit(found ? 0 : 1);
    });
  ' "$wanted"
}

# Collects a paired iPhone's log since an ISO time without elevating, keeping
# only the lines the proof predicate selects. Prints {"status":...,"reason":...}:
# ok, permission (the host refused without sudo; never escalated), or failed.
ios_device_log_collect() {
  local udid="$1" bundle="$2" since="$3" out="$4" reader scratch err pid watchdog rc start
  reader="$(dirname "${BASH_SOURCE[0]}")/ios-notify-read.js"
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-device-log.XXXXXX")" || {
    printf '{"status":"failed","reason":"could not create a scratch directory"}'
    return 1
  }
  start="$(ios_simulator_log_time "$since" 2000)"
  err="$scratch/collect.err"
  log collect --device-udid "$udid" --start "$start" --output "$scratch/device.logarchive" \
    >/dev/null 2>"$err" &
  pid=$!
  ( sleep "${IOS_DEVICE_LOG_TIMEOUT:-180}" && kill "$pid" 2>/dev/null ) >/dev/null 2>&1 &
  watchdog=$!
  wait "$pid"
  rc=$?
  pkill -P "$watchdog" 2>/dev/null
  kill "$watchdog" 2>/dev/null
  wait "$watchdog" 2>/dev/null
  if ((rc != 0)) || [[ ! -d "$scratch/device.logarchive" ]]; then
    local reason
    reason="$(head -c 300 "$err" | tr '\n\t' '  ')"
    rm -rf "$scratch"
    if grep -Eqi 'root|sudo|permission|not permitted|privilege|authoriz' <<< "$reason"; then
      node -e 'process.stdout.write(JSON.stringify({status:"permission",reason:process.argv[1]||"log collect needs elevated permissions"}))' "$reason"
    else
      node -e 'process.stdout.write(JSON.stringify({status:"failed",reason:process.argv[1]||"log collect did not produce an archive"}))' "$reason"
    fi
    return 1
  fi
  log show "$scratch/device.logarchive" --style ndjson \
    --predicate "$(node "$reader" predicate "$bundle")" > "$out" 2>/dev/null
  rc=$?
  rm -rf "$scratch"
  if ((rc != 0)); then
    printf '{"status":"failed","reason":"log show could not read the collected archive"}'
    return 1
  fi
  chmod 600 "$out" 2>/dev/null
  printf '{"status":"ok","reason":""}'
}

# One silent APNs probe for the app's real Simulator token (diagnostic only).
# Prints the probe's JSON; never retried here.
ios_apns_probe() {
  local workspace="$1" udid="$2" bundle="$3" environment="$4"
  node "$(dirname "${BASH_SOURCE[0]}")/ios-apns-probe.js" --workspace "$workspace" \
    --devices-root "$(ios_simulator_devices_root)" --udid "$udid" --bundle "$bundle" \
    --environment "$environment" 2>/dev/null ||
    printf '{"status":"inconclusive","classification":"probe_failed","summary":"The Apple check could not run.","diagnostic_only":true}'
}
