#!/usr/bin/env bash
# ios-prove against scrubbed real Simulator recordings: a real APNs delivery,
# a simctl injection, a foreground suppression, and the send-failure paths.

set -uo pipefail
cd "$(dirname "$0")/.." || exit
REPO="$PWD"

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  [[ $# -lt 2 ]] || printf '  %s\n' "$2"
  FAILED=1
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-prove.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-prove.*|/private/tmp/iterable-ios-prove.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap '[[ -z "${APNS_PID:-}" ]] || { kill "$APNS_PID" 2>/dev/null; wait "$APNS_PID" 2>/dev/null; }; rm -rf "$ROOT"' EXIT

APP="$ROOT/DogShelter"
WORKSPACE="$APP/.iterable/ios"
FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
DEVICES="$ROOT/devices"
SIMULATE="$REPO/tests/fixtures/ios-prove/simulate"
mkdir -p "$APP" "$FAKEBIN"

cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
printf 'Xcode 27.0\nBuild version 27A266a\n'
EOF
cat > "$FAKEBIN/sw_vers" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -productVersion ]] && printf '26.7.1\n'
EOF
cat > "$FAKEBIN/uname" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -m ]] && printf 'arm64\n'
EOF
cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PROVE_STATE/xcrun-calls"
case "$*" in
  "simctl list runtimes -j")
    if [[ -f "$PROVE_STATE/runtimes.json" ]]; then
      cat "$PROVE_STATE/runtimes.json"
    else
      printf '%s\n' '{"runtimes":[{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-26-2","runtimeRoot":"/Library/Developer/CoreSimulator/Volumes/iOS_23C54/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.2.simruntime/Contents/Resources/RuntimeRoot","isAvailable":true}]}'
    fi
    ;;
  "simctl list devices --json")
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[{"udid":"SIM-PROVE-1","name":"iPhone 17","state":"Booted","isAvailable":true}]}}\n'
    ;;
  "simctl get_app_container SIM-PROVE-1 com.example.dogshelter app")
    [[ ! -f "$PROVE_STATE/not-installed" ]] || exit 2
    printf '/tmp/DogShelter.app\n'
    ;;
  "simctl terminate SIM-PROVE-1 com.example.dogshelter"|"simctl launch SIM-PROVE-1 com.apple.Preferences") ;;
  *"--predicate process == \"apsd\" OR process == \"SpringBoard\""*)
    [[ -f "$PROVE_STATE/log-dead" ]] ||
      printf '{"timestamp":"%s","processImagePath":"/usr/libexec/apsd","subsystem":"com.apple.apsd","eventMessage":"keep alive"}\n' "$(date -u '+%Y-%m-%d %H:%M:%S.000000+0000')"
    printf '{"count":1,"finished":1}\n'
    ;;
  "simctl spawn SIM-PROVE-1 log show "*)
    [[ ! -f "$PROVE_STATE/main-fails" ]] || exit 1
    [[ ! -f "$PROVE_STATE/stale.ndjson" ]] || cat "$PROVE_STATE/stale.ndjson"
    [[ -f "$PROVE_STATE/log-dead" ]] || { [[ -f "$PROVE_STATE/log.ndjson" ]] && cat "$PROVE_STATE/log.ndjson"; }
    printf '{"count":0,"finished":1}\n'
    ;;
  *) exit 2 ;;
esac
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
config="$(cat)"
url="$(sed -n 's/^url = "\(.*\)"$/\1/p' <<< "$config")"
data="$(sed -n 's/^data = "\(.*\)"$/\1/p' <<< "$config" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
printf '%s\n' "$url" >> "$PROVE_STATE/curl-calls"
token="$(node -e 'process.stdout.write(Buffer.alloc(80,0x11).toString("hex"))')"
[[ ! -f "$PROVE_STATE/stale-token" ]] || token="$(node -e 'process.stdout.write(Buffer.alloc(80,0x22).toString("hex"))')"
case "$url" in
  */api/users/getByEmail*)
    [[ ! -f "$PROVE_STATE/slow" ]] || sleep "$(cat "$PROVE_STATE/slow")"
    printf '{"user":{"email":"dogs@example.com","dataFields":{"devices":[{"appPackageName":"com.example.dogshelter","endpointEnabled":true,"notificationsEnabled":true,"platform":"APNS_SANDBOX","token":"%s"}]}}}\n200\n' "$token"
    ;;
  */api/templates/push/upsert)
    printf '%s' "$data" > "$PROVE_STATE/upsert.json"
    printf '{"msg":"Upserted 1 templates with IDs: 424242"}\n200\n'
    ;;
  */api/templates/push/proof)
    printf '%s' "$data" > "$PROVE_STATE/proof.json"
    code="$(cat "$PROVE_STATE/proof-code" 2>/dev/null || printf 200)"
    if [[ "$code" == 200 || "$code" == 5* ]]; then
      marker="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).payload.iterableProofMarker)' "$PROVE_STATE/upsert.json")"
      nonce="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).payload.iterableProofNonce)' "$PROVE_STATE/upsert.json")"
      printf '%s' "$nonce" > "$PROVE_STATE/nonce"
      "$PROVE_SIMULATE" deliver "$(cat "$PROVE_STATE/scenario")" "$PROVE_DEVICES" SIM-PROVE-1 \
        com.example.dogshelter "$marker" "$nonce" 424242 "$PROVE_STATE/log.ndjson"
    fi
    if [[ "$code" == 200 ]]; then
      printf '{"msg":"Push proof sent"}\n200\n'
    else
      printf '{"msg":"Template is missing a recipient"}\n%s\n' "$code"
    fi
    ;;
  *) printf '{"msg":"unexpected"}\n500\n' ;;
esac
EOF
chmod +x "$FAKEBIN"/*


# A fake APNs for the Apple check, used only by the cases that import a key.
APNS_PID=""
printf 200 > "$ROOT/apns-scenario"
node "$REPO/tests/fixtures/ios-prove/fake-apns.js" "$ROOT/apns-port" "$ROOT/apns-scenario" "$ROOT/apns-requests" &
APNS_PID=$!
for _ in $(seq 1 50); do [[ -s "$ROOT/apns-port" ]] && break; sleep 0.1; done
APNS_ORIGIN="http://127.0.0.1:$(cat "$ROOT/apns-port")"
import_apns_key() {
  node -e '
    const crypto=require("crypto"), fs=require("fs"), dir=process.argv[1];
    const {privateKey}=crypto.generateKeyPairSync("ec",{namedCurve:"P-256"});
    fs.writeFileSync(`${dir}/AuthKey_ABC123DEFG.p8`,privateKey.export({type:"pkcs8",format:"pem"}),{mode:0o600});
    fs.writeFileSync(`${dir}/apns.json`,JSON.stringify({key_path:`${dir}/AuthKey_ABC123DEFG.p8`,key_id:"ABC123DEFG",team_id:"TEAM123456"},null,2)+"\n",{mode:0o600});
  ' "$1"
}

fresh() {
  rm -rf "$WORKSPACE" "$STATE" "$DEVICES"
  mkdir -p "$WORKSPACE" "$STATE" "$DEVICES"
  chmod 700 "$WORKSPACE"
  printf '%s' "${1:-apns}" > "$STATE/scenario"
  printf 'ITERABLE_SERVER_KEY=server-prove-key-1234567890\nITERABLE_DATA_REGION=US\n' > "$WORKSPACE/.env"
  chmod 600 "$WORKSPACE/.env"
  node -e '
    const fs=require("fs");
    fs.writeFileSync(process.argv[1],JSON.stringify({
      proof_mode:"behavioral",
      bundle_id:"com.example.dogshelter",
      identity_type:"email",
      identity:"dogs@example.com",
      device:"SIM-PROVE-1",
      device_kind:"simulator",
      simulator_runtime:"com.apple.CoreSimulator.SimRuntime.iOS-26-2",
      environment:"development",
      apns_environment:"sandbox",
      run_id:"run-prove-1",
      markers:{user_targeted:"ITBL-IOS-PROOF-0A1B2C3D4E5F"},
      started_at:new Date(Date.now()-60000).toISOString()
    },null,2)+"\n",{mode:0o600});
  ' "$WORKSPACE/proof-target.json"
  "$SIMULATE" register "$DEVICES" SIM-PROVE-1 com.example.dogshelter
}

prove() {
  (
    cd "$APP" || exit
    env PATH="$FAKEBIN:$PATH" PROVE_STATE="$STATE" PROVE_DEVICES="$DEVICES" \
      PROVE_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$DEVICES" \
      IOS_APNS_PROBE_ORIGIN="$APNS_ORIGIN" \
      IOS_WORKSPACE="$WORKSPACE" "$REPO/bin/ios-prove" --confirm "$@"
  )
}

field() {
  node -e '
    let v; try { v=JSON.parse(process.argv[1]) } catch { process.exit(0) }
    for (const key of process.argv[2].split(".")) v=v?.[key];
    process.stdout.write(v == null ? "" : String(v));
  ' "$1" "$2"
}

manifest() { field "$(cat "$WORKSPACE/sends/development/user-targeted.json" 2>/dev/null)" "$1"; }
proof_calls() { awk '/\/api\/templates\/push\/proof/{n++} END{print n+0}' "$STATE/curl-calls" 2>/dev/null || printf 0; }

# A real APNs delivery, recorded on iOS 26.2.
fresh apns
out="$(prove --timeout 10 2>"$ROOT/err")"
rc=$?
if [[ "$rc" -eq 0 && "$(field "$out" observed)" == true &&
      "$(field "$out" evidence.apns_received)" == true &&
      "$(field "$out" evidence.os_stored)" == true &&
      "$(field "$out" evidence.os_displayed)" == true &&
      "$(field "$out" apns_binding)" == nonce &&
      "$(field "$out" token_match)" == true &&
      -f "$WORKSPACE/proof/development/user-targeted.json" &&
      "$(manifest state)" == sent && "$(manifest contract)" == 4 ]]; then
  ok "a real APNs delivery is proved from the Simulator's store and log"
else
  bad "a real APNs delivery was not proved" "rc=$rc $out $(cat "$ROOT/err")"
fi
nonce="$(cat "$STATE/nonce")"
if ! grep -rqF -- "$nonce" "$WORKSPACE" && ! grep -rq 'dogs@example.com' "$WORKSPACE/sends" "$WORKSPACE/proof" "$WORKSPACE/observations"; then
  ok "no raw nonce or identity is written to the workspace"
else
  bad "the workspace retained a raw nonce or identity"
fi
if [[ "$(field "$(cat "$STATE/upsert.json")" clientTemplateId)" == itbl-ios-proof-com-example-dogshelter &&
      "$(field "$(cat "$STATE/upsert.json")" payload.recipientEmail)" == "" ]]; then
  ok "one stable template per app, and the payload carries no identity"
else
  bad "the proof template is per-run or the payload carries the identity"
fi
record_created="$(node "$REPO/bin/ios-notify-read.js" store "$DEVICES" SIM-PROVE-1 com.example.dogshelter |
  node -e 'let i="";process.stdin.on("data",c=>i+=c).on("end",()=>process.stdout.write(JSON.parse(i).records[0].created))')"
if [[ -n "$record_created" ]] && node -e '
    process.exit(Date.parse(process.argv[1]) < Date.parse(process.argv[2]) &&
      Date.parse(process.argv[1]) >= Date.parse(process.argv[3]) - 2000 ? 0 : 1)
  ' "$record_created" "$(manifest sent_at)" "$(manifest prepared_at)"; then
  ok "an arrival recorded before sent_at but after prepared_at still counts"
else
  bad "arrival timing was judged against the wrong boundary"
fi
second="$(prove --timeout 5 2>&1)"
second_rc=$?
if [[ "$second_rc" -eq 30 && "$(proof_calls)" -eq 1 && "$second" == *"never sends twice"* ]]; then
  ok "a second ios-prove for the same run refuses to send"
else
  bad "ios-prove sent twice for one run" "rc=$second_rc calls=$(proof_calls)"
fi

fresh nobundle
out="$(prove --timeout 10 2>/dev/null)"
if [[ "$(field "$out" observed)" == true ]]; then
  ok "a stored record that carries no bundle string is still matched through Library.plist"
else
  bad "a record without a bundle string was missed" "$out"
fi

fresh injected
out="$(prove --timeout 6 2>/dev/null)"
rc=$?
if [[ "$rc" -eq 40 && "$(field "$out" diagnosis)" == injection_detected &&
      ! -f "$WORKSPACE/proof/development/user-targeted.json" ]]; then
  ok "a locally injected record with the right marker and nonce is rejected"
else
  bad "a simctl-style injection was accepted" "rc=$rc $out"
fi

fresh copied
out="$(prove --timeout 6 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == injection_detected ]]; then
  ok "a record carrying this run's marker and nonce that was added locally is rejected"
else
  bad "a copied-payload local add was accepted" "$out"
fi

fresh apns
touch "$STATE/main-fails"
out="$(prove --timeout 6 2>/dev/null)"
if [[ "$(field "$out" observed)" == false && "$(field "$out" diagnosis)" == log_unavailable ]]; then
  ok "a failed main log query is reported unavailable even while the apsd canary answers"
else
  bad "a failed log query was judged from partial evidence" "$out"
fi

fresh apns
mkdir -p "$WORKSPACE/observations/runs/run-prove-1/user-targeted"
out="$(prove --timeout 5 2>&1)"
if [[ "$out" == *"earlier attempt"* && "$(proof_calls)" -eq 0 ]]; then
  ok "evidence from an earlier attempt of this run blocks a new send"
else
  bad "ios-prove sent into a run that already held evidence" "$out"
fi

fresh apns
printf 2 > "$STATE/slow"
prove --timeout 8 > "$ROOT/first.out" 2>&1 &
first_pid=$!
sleep 0.4
second="$(prove --timeout 8 2>&1)"
wait "$first_pid"
if [[ "$(proof_calls)" -eq 1 && "$second" == *"already running"* ]]; then
  ok "two concurrent ios-prove runs send exactly once"
else
  bad "concurrent ios-prove runs sent more than once" "calls=$(proof_calls) second=$second"
fi
rm -f "$STATE/slow"

fresh apns
mv "$DEVICES/SIM-PROVE-1/data/Library/UserNotifications/Library.plist" "$ROOT/Library.plist.saved"
prove --timeout 5 >/dev/null 2>&1
mv "$ROOT/Library.plist.saved" "$DEVICES/SIM-PROVE-1/data/Library/UserNotifications/Library.plist"
retry="$(prove --timeout 10 2>/dev/null)"
if [[ "$(field "$retry" observed)" == true && "$(proof_calls)" -eq 1 ]]; then
  ok "a failed precondition leaves no lock or evidence behind, so the next attempt can send"
else
  bad "a precondition failure blocked the later valid attempt" "$retry"
fi

if [[ "$(bash -c 'source bin/ios-simulator.sh; IOS_CORE_SIMULATOR_DEVICES_ROOT=/tmp/forged ios_simulator_devices_root')" == "$HOME/Library/Developer/CoreSimulator/Devices" &&
      "$(bash -c 'source bin/ios-simulator.sh; ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT=/tmp/forged ios_simulator_devices_root')" == /tmp/forged ]]; then
  ok "the devices-root override is honoured only in test mode"
else
  bad "the devices-root override works outside the test harness"
fi

fresh apns
node -e '
  const root=process.argv[1], t=new Date(Date.now()-3600000), p=(n,w=2)=>String(n).padStart(w,"0");
  const stamp=`${t.getUTCFullYear()}-${p(t.getUTCMonth()+1)}-${p(t.getUTCDate())} ${p(t.getUTCHours())}:${p(t.getUTCMinutes())}:${p(t.getUTCSeconds())}.000000+0000`;
  const sb=`${root}/System/Library/CoreServices/SpringBoard.app/SpringBoard`;
  const core="/System/Library/PrivateFrameworks/UserNotificationsCore.framework/UserNotificationsCore";
  const out=[];
  for (let i=0;i<20000;i++) out.push(JSON.stringify({timestamp:stamp,processImagePath:sb,senderImagePath:core,subsystem:"com.apple.UserNotifications",category:"DataStore",
    eventMessage:"[com.example.dogshelter] Saving notification 1111-2222: NO [ hasAlertContent: YES, shouldPresentAlert: NO settingsShouldSave: YES pipelineState: completed]"}));
  process.stdout.write(out.join("\n")+"\n");
' "/Library/Developer/CoreSimulator/Volumes/iOS_23C54/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.2.simruntime/Contents/Resources/RuntimeRoot" > "$STATE/stale.ndjson"
out="$(prove --timeout 10 2>/dev/null)"
if [[ "$(field "$out" observed)" == true ]]; then
  ok "a log query that ignores --start and returns hours of older lines still judges only this run's window"
else
  bad "older log lines from an ignored --start changed the verdict" "$out"
fi

fresh apns
import_apns_key "$WORKSPACE"
printf '400 TopicDisallowed' > "$ROOT/apns-scenario"
out="$(prove --timeout 5 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == apple_app_id_push_disabled && "$(proof_calls)" -eq 0 &&
      ! -e "$WORKSPACE/sends/development/user-targeted.json" &&
      "$(field "$out" apple_check.steps)" == *"tick Push Notifications"* ]]; then
  ok "Apple's TopicDisallowed stops the run before Iterable is asked to send, and names the fix"
else
  bad "a TopicDisallowed app still reached the Iterable send" "$out"
fi

fresh apns
import_apns_key "$WORKSPACE"
printf 200 > "$ROOT/apns-scenario"
out="$(prove --timeout 10 2>/dev/null)"
if [[ "$(field "$out" observed)" == true && "$(proof_calls)" -eq 1 &&
      "$(field "$out" apple_check.status)" == ready ]]; then
  ok "Apple's 200 lets the single Iterable send through"
else
  bad "a ready Apple check did not lead to the proof send" "$out"
fi

fresh wrongnonce
out="$(prove --timeout 6 2>/dev/null)"
if [[ "$(field "$out" observed)" == false && "$(field "$out" diagnosis)" == duplicate_delivery ]]; then
  ok "this run's marker with a different nonce is flagged as a duplicate, not counted"
else
  bad "a record with the wrong nonce was accepted" "$out"
fi

fresh suppressed
start=$SECONDS
out="$(prove --timeout 30 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == suppressed_by_app && $((SECONDS - start)) -lt 20 &&
      "$(field "$out" evidence.apns_received)" == true ]]; then
  ok "a foreground suppression is named early instead of timing out"
else
  bad "a foreground suppression was not diagnosed" "$out"
fi

fresh never
out="$(prove --timeout 5 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == never_reached_simulator && "$(manifest state)" == sent ]]; then
  ok "no APNs line in the log reports that the push never reached the Simulator"
else
  bad "a missing delivery was not diagnosed" "$out"
fi

fresh never
touch "$STATE/log-dead"
out="$(prove --timeout 5 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == log_unavailable ]]; then
  ok "an unreadable Simulator log is reported as inconclusive, not as a lost push"
else
  bad "a dead log was read as a missing delivery" "$out"
fi

fresh duplicate
out="$(prove --timeout 8 2>/dev/null)"
if [[ "$(field "$out" observed)" == false && "$(field "$out" diagnosis)" == duplicate_delivery ]]; then
  ok "a duplicate delivery of one run's push is not counted"
else
  bad "a duplicate delivery passed" "$out"
fi

fresh apns
printf 400 > "$STATE/proof-code"
out="$(prove --timeout 5 2>/dev/null)"
rc=$?
if [[ "$rc" -eq 30 && "$(manifest state)" == failed && "$(field "$out" diagnosis)" == send_rejected &&
      "$(field "$out" summary)" == *"HTTP 400"* ]]; then
  ok "a 4xx proof response is recorded as failed, not pending"
else
  bad "a rejected send looked pending" "rc=$rc $out"
fi

fresh apns
printf 503 > "$STATE/proof-code"
out="$(prove --timeout 10 2>/dev/null)"
if [[ "$(field "$out" observed)" == true && "$(manifest state)" == uncertain && "$(proof_calls)" -eq 1 ]]; then
  ok "an uncertain send is observed without resending"
else
  bad "an uncertain send was resent or not observed" "$out"
fi

fresh apns
touch "$STATE/stale-token"
out="$(prove --timeout 5 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == stale_device_token && "$(proof_calls)" -eq 0 &&
      ! -f "$WORKSPACE/sends/development/user-targeted.json" ]]; then
  ok "a stale Iterable device token stops the run before any send"
else
  bad "a send went to a token this Simulator no longer has" "$out"
fi

fresh apns
rm -f "$DEVICES/SIM-PROVE-1/data/Library/UserNotifications/Library.plist"
out="$(prove --timeout 5 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == app_never_registered_notifications && "$(proof_calls)" -eq 0 ]]; then
  ok "an app with no notification record on the Simulator is stopped before sending"
else
  bad "ios-prove sent without the app having registered" "$out"
fi

((FAILED)) && exit 1
exit 0
