#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  [[ $# -lt 2 ]] || printf '  %s\n' "$2"
  FAILED=1
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-verify-transitions.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-verify-transitions.*|/private/tmp/iterable-ios-verify-transitions.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

APP="$ROOT/SampleShop"
WORKSPACE="$APP/.iterable/ios"
FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
SIM_APP="$STATE/SampleShop.app"
mkdir -p "$APP/SampleShop" "$FAKEBIN" "$STATE" "$SIM_APP"

cat > "$APP/project.yml" <<'EOF'
name: SampleShop
settings:
  base:
    PRODUCT_BUNDLE_IDENTIFIER: com.example.sampleshop
EOF
cat > "$APP/SampleShop/AppDelegate.swift" <<'EOF'
import IterableSDK
IterableAPI.initialize(apiKey: mobileKey, launchOptions: nil, config: config)
IterableAPI.email = currentEmail
UIApplication.shared.registerForRemoteNotifications()
EOF
printf 'fixture\n' > "$SIM_APP/Info.plist"
printf 'linked executable\n' > "$SIM_APP/SampleShop"
mkdir -p "$SIM_APP/IterableSDKResources.bundle"
touch -t 202601011200 "$APP/SampleShop/AppDelegate.swift"
printf 'Iterable initialized\n' > "$STATE/app.log"

cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
printf 'Xcode 18.0\nBuild version 18A1\n'
EOF
cat > "$FAKEBIN/sw_vers" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -productVersion ]] && printf '15.0\n'
EOF
cat > "$FAKEBIN/uname" <<'EOF'
#!/usr/bin/env bash
[[ "${1:-}" == -m ]] && printf 'arm64\n'
EOF
cat > "$FAKEBIN/plutil" <<'EOF'
#!/usr/bin/env bash
key=""
while (($#)); do
  if [[ "$1" == -extract ]]; then key="$2"; shift 2; else shift; fi
done
case "$key" in
  CFBundleIdentifier) printf 'com.example.sampleshop\n' ;;
  CFBundleExecutable) printf 'SampleShop\n' ;;
  aps-environment) grep -q '<string>development</string>' && printf 'development\n' ;;
esac
EOF
cat > "$FAKEBIN/otool" <<'EOF'
#!/usr/bin/env bash
node -e '
  const data=Buffer.from("<plist><dict><key>aps-environment</key><string>development</string></dict></plist>");
  console.log("Contents of (__TEXT,__entitlements) section");
  for (let at=0; at<data.length; at+=16) {
    const words=[];
    for (let w=at; w<Math.min(at+16,data.length); w+=4) {
      if (w+4<=data.length) words.push(data.subarray(w,w+4).reverse().toString("hex"));
      else for (let b=w; b<data.length; b++) words.push(data.subarray(b,b+1).toString("hex"));
    }
    console.log((0x100003468+at).toString(16).padStart(16,"0")+"\t"+words.join(" "));
  }
'
EOF
cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
set -eu
if [[ "$*" == "simctl list runtimes -j" ]]; then
  printf '%s\n' '{"runtimes":[{"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-18-0","runtimeRoot":"/Library/Developer/CoreSimulator/Volumes/iOS_23C54/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.2.simruntime/Contents/Resources/RuntimeRoot","isAvailable":true}]}'
elif [[ "$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"SIM-VERIFY-1","name":"iPhone 16","state":"Booted","isAvailable":true}]}}\n'
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[]}}\n'
elif [[ "$*" == "simctl get_app_container SIM-VERIFY-1 com.example.sampleshop app" ]]; then
  printf '%s\n' "$IOS_TRANSITION_STATE/SampleShop.app"
elif [[ "$*" == "simctl launch --terminate-running-process SIM-VERIFY-1 com.example.sampleshop" ]]; then
  printf 'com.example.sampleshop: 123\n'
elif [[ "$*" == "simctl terminate SIM-VERIFY-1 com.example.sampleshop" ]]; then
  printf 'terminate\n' >> "$IOS_TRANSITION_STATE/terminations"
elif [[ "$*" == *'--predicate process == "apsd" OR process == "SpringBoard"'* ]]; then
  printf '{"timestamp":"%s","processImagePath":"/usr/libexec/apsd","subsystem":"com.apple.apsd","eventMessage":"keep alive"}\n' "$(date -u '+%Y-%m-%d %H:%M:%S.000000+0000')"
elif [[ "$*" == "simctl spawn SIM-VERIFY-1 log show "* ]]; then
  [[ ! -f "$IOS_TRANSITION_STATE/log.ndjson" ]] || cat "$IOS_TRANSITION_STATE/log.ndjson"
  printf '{"count":0,"finished":1}\n'
else
  exit 2
fi
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
config="$(cat)"
request="$config $*"
if grep -Eq 'itbl-ios-(verify|deliberately)-invalid-server-key' <<< "$request"; then
  printf '{"msg":"invalid api key"}\n401\n'
elif grep -q '/api/channels' <<< "$request"; then
  printf '{"channels":[{"messageMedium":"Push"}]}\n200\n'
elif grep -q '/api/users/getByEmail' <<< "$request"; then
  if [[ ! -f "$IOS_TRANSITION_STATE/user-exists" ]]; then
    printf '{"msg":"No user exists"}\n400\n'
  elif [[ ! -f "$IOS_TRANSITION_STATE/device-exists" ]]; then
    printf '{"user":{"email":"dogs@example.com","dataFields":{}}}\n200\n'
  else
    token=""
    [[ ! -f "$IOS_TRANSITION_STATE/token-hex" ]] || token=",\"token\":\"$(cat "$IOS_TRANSITION_STATE/token-hex")\""
    printf '{"user":{"email":"dogs@example.com","dataFields":{"devices":[{"appPackageName":"com.example.sampleshop","endpointEnabled":true,"notificationsEnabled":true%s}]}}}\n200\n' "$token"
  fi
elif grep -q '/api/templates/push/upsert' <<< "$request"; then
  sed -n 's/^data = "\(.*\)"$/\1/p' <<< "$config" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g' \
    > "$IOS_TRANSITION_STATE/upsert.json"
  printf '{"msg":"Upserted 1 templates with IDs: 424242"}\n200\n'
elif grep -q '/api/templates/push/proof' <<< "$request"; then
  printf 'proof\n' >> "$IOS_TRANSITION_STATE/proof-sends"
  read -r marker nonce < <(node -e '
    const v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
    process.stdout.write(`${v.payload.iterableProofMarker} ${v.payload.iterableProofNonce}\n`);
  ' "$IOS_TRANSITION_STATE/upsert.json")
  "$IOS_TRANSITION_SIMULATE" deliver "$(cat "$IOS_TRANSITION_STATE/scenario" 2>/dev/null || printf apns)" \
    "$IOS_TRANSITION_STATE/devices" SIM-VERIFY-1 com.example.sampleshop "$marker" "$nonce" 424242 \
    "$IOS_TRANSITION_STATE/log.ndjson"
  printf '{"msg":"Push proof sent"}\n200\n'
else
  printf '{"msg":"unexpected request"}\n500\n'
fi
EOF
cat > "$FAKEBIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
cat "$IOS_TRANSITION_STATE/clipboard"
EOF
cat > "$FAKEBIN/pbcopy" <<'EOF'
#!/usr/bin/env bash
cat > "$IOS_TRANSITION_STATE/clipboard"
EOF
cat > "$FAKEBIN/agent-device" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_TRANSITION_STATE/agent-calls"
case "$1" in
  open) printf '{"ok":true}\n' ;;
  snapshot)
    if grep -q 'open com.apple.springboard' "$IOS_TRANSITION_STATE/agent-calls"; then
      printf '{"elements":[{"text":"Notification Center"}]}\n'
    else
      printf '{"elements":[{"text":"All Dogs"},{"text":"Logout"}]}\n'
    fi
    ;;
  logs)
    [[ "${2:-}" == path ]] && printf '%s\n' "$IOS_TRANSITION_STATE/app.log"
    ;;
  wait)
    [[ ! -f "$IOS_TRANSITION_STATE/fail-wait" ]] || exit 1
    printf '{"matched":true}\n'
    ;;
  close) ;;
esac
EOF
chmod +x "$FAKEBIN"/*
printf 'server-transition-key-1234567890\n' > "$STATE/clipboard"
SIMULATE="$PWD/tests/fixtures/ios-prove/simulate"
"$SIMULATE" register "$STATE/devices" SIM-VERIFY-1 com.example.sampleshop
CALLS=0

run_prepare() {
  (
    cd "$APP" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$STATE/devices" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$WORKSPACE" \
      "$OLDPWD/bin/ios-prepare-proof" "$@"
  )
}

run_verify() {
  (
    cd "$APP" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$STATE/devices" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$WORKSPACE" \
      "$OLDPWD/bin/ios-verify" status 2>/dev/null
  )
}

run_actor() {
  local actor="$1"
  shift
  (
    cd "$APP" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$STATE/devices" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$WORKSPACE" \
      "$OLDPWD/bin/$actor" "$@"
  )
}

value() {
  node -e '
    const value=process.argv[2].split(".").reduce(
      (current,key)=>current == null ? current : current[key],
      JSON.parse(process.argv[1])
    );
    process.stdout.write(String(value));
  ' "$1" "$2"
}

first="$(run_prepare status)"
if [[ "$(value "$first" verification_only)" == true &&
      "$(value "$first" proposed.bundle_id)" == com.example.sampleshop &&
      "$(value "$first" proposed.identity_type)" == email &&
      "$(value "$first" next.kind)" == proof_region ]]; then
  ok "verification-only preparation discovers the existing iOS integration"
else
  bad "verification-only preparation replayed new-integration setup"
fi

run_prepare answer --field region --value US >/dev/null
run_prepare answer --field environment --value development >/dev/null
run_prepare answer --field identity --value dogs@example.com >/dev/null
ready="$(run_prepare answer --field device --value SIM-VERIFY-1)"
if [[ "$(value "$ready" next.kind)" == confirm_proof &&
      "$(value "$ready" proposed.app_path)" == "" &&
      "$(value "$ready" proposed.switch_identity)" == "" ]]; then
  ok "standard proof asks only for the existing identity and selected device"
else
  bad "standard proof exposed benchmark-only setup"
fi
run_prepare start --confirm >/dev/null

without_server="$(run_verify)"
server_rc=$?
if [[ "$server_rc" -eq 10 &&
      "$(value "$without_server" next.kind)" == server_key &&
      "$(value "$without_server" next.command)" == *"question --kind configure_server" ]]; then
  ok "verification-only run requests only its Server-side proof credential"
else
  bad "verification-only credentials were routed through full provisioning" \
    "rc=$server_rc next=$(value "$without_server" next.kind)"
fi

server_question="$(
  cd "$APP" &&
    env PATH="$FAKEBIN:$PATH" IOS_WORKSPACE="$WORKSPACE" \
      "$OLDPWD/bin/ios-provision" question --kind configure_server
)"
if [[ "$server_question" == *"An existing iOS integration was detected"* &&
      "$server_question" != *"The Mobile key is ready"* ]]; then
  ok "Server-key guidance explains the verification-only boundary"
else
  bad "verification-only Server-key guidance claimed Mobile-key setup ran"
fi

run_actor ios-provision capture-server --confirm >/dev/null
run_actor ios-provision validate-server >/dev/null
if [[ -f "$WORKSPACE/server-validation.json" &&
      "$(stat -f '%Lp' "$WORKSPACE/.env")" == 600 ]] &&
    grep -q '^ITERABLE_SERVER_KEY=' "$WORKSPACE/.env"; then
  ok "verification-only Server credential is captured and validated through the real narrow flow"
else
  bad "verification-only Server credential bypassed its capture or validation flow"
fi

no_relaunch="$(run_verify)"
if [[ "$(value "$no_relaunch" next.kind)" == inspect_app &&
      "$(value "$no_relaunch" gates)" != *'"id":"I7"'* ]]; then
  ok "standard proof goes straight to the identity check without a forced relaunch"
else
  bad "standard proof still relaunched the installed app" \
    "next=$(value "$no_relaunch" next.kind)"
fi

needs_inspection="$no_relaunch"
if [[ "$(value "$needs_inspection" next.kind)" == inspect_app &&
      "$(value "$needs_inspection" next.owner)" == tool ]]; then
  ok "missing identity is inspected before asking the developer to act"
else
  bad "verifier asked for login without reading app state"
fi
run_actor ios-observe inspect --kind app --purpose identity >/dev/null

needs_identity_logs="$(run_verify)"
if [[ "$(value "$needs_identity_logs" next.kind)" == inspect_identity_logs &&
      "$(value "$needs_identity_logs" next.owner)" == tool ]]; then
  ok "an already authenticated screen is inspected further instead of asking for login"
else
  bad "the verifier repeated login despite an authenticated app screen" \
    "next=$(value "$needs_identity_logs" next.kind): $(value "$needs_identity_logs" next.summary)"
fi
run_actor ios-observe inspect --kind logs --purpose identity >/dev/null

needs_identity="$(run_verify)"
if [[ "$(value "$needs_identity" next.kind)" == review_identity_state &&
      "$(value "$needs_identity" next.owner)" == human &&
      "$(value "$needs_identity" next.summary)" == *"do not log in again"* ]]; then
  ok "post-inspection identity guidance preserves the existing session"
else
  bad "post-inspection identity guidance was not specific" \
    "next=$(value "$needs_identity" next.kind): $(value "$needs_identity" next.summary)"
fi
touch "$STATE/user-exists"

needs_registration="$(run_verify)"
if [[ "$(value "$needs_registration" next.kind)" == inspect_app &&
      "$(value "$needs_registration" next.command)" == *"--purpose registration"* ]]; then
  ok "device registration gets a fresh purpose-scoped inspection"
else
  bad "device registration reused stale identity inspection state" \
    "next=$(value "$needs_registration" next.kind): $(value "$needs_registration" next.summary)"
fi
registration_summary="$(value "$needs_registration" next.summary)"
if [[ "$registration_summary" != *"registration logs"* &&
      "$registration_summary" == *"reads the device record from Iterable"* &&
      "$registration_summary" == *"no registerToken line proves nothing"* &&
      "$registration_summary" == *"Re-run ios-verify status after any app action or rebuild"* ]]; then
  ok "the registration step points at Iterable's device record, never at the app's log"
else
  bad "the registration step sends the agent to the logs to judge registration" "$registration_summary"
fi
run_actor ios-observe inspect --kind app --purpose registration >/dev/null

registration_action="$(run_verify)"
if [[ "$(value "$registration_action" next.kind)" == run_app &&
      "$(value "$registration_action" next.summary)" == *"notification"* &&
      "$(value "$registration_action" next.summary)" != *"identify as exact user"* ]]; then
  ok "device-registration guidance does not repeat a completed login"
else
  bad "device registration sent the developer back through login" \
    "next=$(value "$registration_action" next.kind): $(value "$registration_action" next.summary)"
fi
touch "$STATE/device-exists"

prove_next="$(run_verify)"
if [[ "$(value "$prove_next" next.kind)" == prove_push &&
      "$(value "$prove_next" next.owner)" == tool &&
      "$(value "$prove_next" next.command)" == *"/ios-prove --confirm" ]]; then
  ok "a registered device advances straight to one tool-owned proof send"
else
  bad "standard proof still routed through a pre-send screen read or a coordinator" \
    "next=$(value "$prove_next" next.kind): $(value "$prove_next" next.summary)"
fi
run_actor ios-prove --confirm --timeout 10 >/dev/null 2>&1
if [[ ! -s "$STATE/agent-calls" ]] || ! grep -q 'springboard' "$STATE/agent-calls"; then
  ok "delivery is observed without agent-device or a SpringBoard screen read"
else
  bad "delivery still bound SpringBoard through agent-device"
fi

complete="$(run_verify)"
if [[ "$(value "$complete" verdict)" == done &&
      "$(value "$complete" push_proven)" == true &&
      "$(value "$complete" integration_complete)" == true &&
      "$(value "$complete" verification_subject)" == existing-installed-application &&
      "$(value "$complete" source_build_linked)" == false &&
      "$(value "$complete" next.kind)" == done ]]; then
  ok "standard verification terminates after one APNs-delivered push"
else
  bad "standard verification did not reach a deterministic terminal state" \
    "next=$(value "$complete" next.kind): $(value "$complete" next.summary)"
fi
rm -f "$STATE/devices/SIM-VERIFY-1/data/Library/UserNotifications/0B5E8D2A-3C1F-4E7A-9B6D-2F8C4A1E7D90/DeliveredNotifications.plist"
still_done="$(run_verify)"
if [[ "$(value "$still_done" verdict)" == done ]]; then
  ok "the verdict survives the developer clearing Notification Center (the log still holds it)"
else
  bad "clearing the notification erased the proof" "$(value "$still_done" next.summary)"
fi

# Golden path: an integrated, provisioned app on a booted Simulator, signed in
# and registered. The agent may only run what each step hands it.
GOLD="$ROOT/Gold"
GOLD_SPACE="$GOLD/.iterable/ios"
GOLD_STATE="$ROOT/gold-state"
mkdir -p "$GOLD_SPACE" "$GOLD_STATE"
cp "$APP/project.yml" "$GOLD/project.yml"
touch "$GOLD_STATE/user-exists" "$GOLD_STATE/device-exists"
node -e 'process.stdout.write(Buffer.alloc(80,0x11).toString("hex"))' > "$GOLD_STATE/token-hex"
cp -R "$STATE/SampleShop.app" "$GOLD_STATE/SampleShop.app"
"$SIMULATE" register "$GOLD_STATE/devices" SIM-VERIFY-1 com.example.sampleshop
gold_key="server-golden-key-1234567890"
printf 'ITERABLE_SERVER_KEY=%s\nITERABLE_DATA_REGION=US\n' "$gold_key" > "$GOLD_SPACE/.env"
node -e '
  const fs=require("fs"), crypto=require("crypto");
  const [dir,key]=process.argv.slice(1);
  fs.writeFileSync(`${dir}/scope.json`,JSON.stringify({features:["sdk-initialization","push-notifications"],identity_mode:"email",data_region:"US",jwt_enabled:false,verification_only:false},null,2)+"\n");
  fs.writeFileSync(`${dir}/target.json`,JSON.stringify({bundle_id:"com.example.sampleshop",name:"Sample Shop"},null,2)+"\n");
  fs.writeFileSync(`${dir}/server-validation.json`,JSON.stringify({valid:true,key_sha256:crypto.createHash("sha256").update(key).digest("hex"),data_region:"US",classification:"authenticated-server-key"},null,2)+"\n");
' "$GOLD_SPACE" "$gold_key"
chmod 700 "$GOLD_SPACE"
chmod 600 "$GOLD_SPACE"/.env "$GOLD_SPACE"/scope.json "$GOLD_SPACE"/target.json "$GOLD_SPACE"/server-validation.json
gold() {
  printf 'call\n' >> "$GOLD_STATE/tool-calls"
  (
    cd "$GOLD" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$GOLD_STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$GOLD_STATE/devices" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$GOLD_SPACE" \
      bash -c "$1" 2>/dev/null
  )
}
step1="$(gold "$OLDPWD/bin/ios-verify status")"
answer_cmd="$(value "$step1" next.question.free_text.command)"
step2="$(gold "${answer_cmd//\{\{answer\}\}/dogs@example.com}")"
step3="$(gold "$(value "$step2" next.command) --timeout 10")"
step4="$(gold "$(value "$step3" next.command)")"
gold_calls="$(grep -c . "$GOLD_STATE/tool-calls")"
if [[ "$(value "$step1" next.kind)" == prepare_proof &&
      "$(value "$step3" observed)" == true &&
      "$(value "$step4" verdict)" == done &&
      "$gold_calls" -le 4 &&
      "$(grep -c . "$GOLD_STATE/proof-sends")" -eq 1 &&
      "$(value "$step4" verification_limitations)" != *exact-apns-token-correlation* ]]; then
  ok "golden path: integrated app on a booted Simulator reaches done in $gold_calls tool calls with one developer answer"
else
  bad "golden path exceeded its budget or did not finish" \
    "calls=$gold_calls step1=$(value "$step1" next.kind) step3=$(value "$step3" diagnosis) step4=$(value "$step4" next.kind): $(value "$step4" next.summary)"
fi
if [[ ! -e "$GOLD_STATE/agent-calls" ]]; then
  ok "golden path never starts agent-device"
else
  bad "golden path started agent-device"
fi
gold_manifest="$GOLD_SPACE/sends/development/user-targeted.json"
cp "$gold_manifest" "$ROOT/gold-manifest.json"
node -e '
  const fs=require("fs"), v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  v.delivery_nonce_sha256=require("crypto").randomBytes(32).toString("hex");
  fs.writeFileSync(process.argv[1],JSON.stringify(v,null,2)+"\n");
' "$gold_manifest"
edited="$(gold "$OLDPWD/bin/ios-verify status")"
cp "$ROOT/gold-manifest.json" "$gold_manifest"
node -e '
  const fs=require("fs"), v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  v.state="prepared"; v.sent=false; delete v.http_code; delete v.sent_at;
  fs.writeFileSync(process.argv[1],JSON.stringify(v,null,2)+"\n");
' "$gold_manifest"
interrupted="$(gold "$OLDPWD/bin/ios-verify status")"
cp "$ROOT/gold-manifest.json" "$gold_manifest"
if [[ "$(value "$interrupted" verdict)" == done ]]; then
  ok "a send interrupted before Iterable answered is still proved by the Simulator's own records"
else
  bad "a prepared-state manifest without an HTTP code was misread" "$(value "$interrupted" next.summary)"
fi
if [[ "$(value "$edited" verdict)" != done ]]; then
  ok "an edited manifest nonce is caught by the verifier's own re-read of the Simulator"
else
  bad "the verifier passed a manifest whose nonce no longer matches the delivery"
fi

# A miss is diagnosed from the log and never resent.
MISS="$ROOT/Miss"
cp -R "$GOLD" "$MISS"
rm -rf "$MISS/.iterable/ios/proof-target.json" "$MISS/.iterable/ios/sends" "$MISS/.iterable/ios/proof" "$MISS/.iterable/ios/observations"
MISS_STATE="$ROOT/miss-state"
mkdir -p "$MISS_STATE"
touch "$MISS_STATE/user-exists" "$MISS_STATE/device-exists"
cp -R "$STATE/SampleShop.app" "$MISS_STATE/SampleShop.app"
printf never > "$MISS_STATE/scenario"
"$SIMULATE" register "$MISS_STATE/devices" SIM-VERIFY-1 com.example.sampleshop
miss() {
  (
    cd "$MISS" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$MISS_STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$MISS_STATE/devices" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$MISS/.iterable/ios" \
      bash -c "$1" 2>/dev/null
  )
}
miss "$OLDPWD/bin/ios-prepare-proof start --confirm --identity dogs@example.com" >/dev/null
miss "$OLDPWD/bin/ios-prove --confirm --timeout 5" >/dev/null
missed="$(miss "$OLDPWD/bin/ios-verify status")"
missed_again="$(miss "$OLDPWD/bin/ios-verify status")"
mkdir -p "$MISS/.iterable/ios/proof/development"
node -e '
  const fs=require("fs");
  const t=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  fs.writeFileSync(process.argv[2],JSON.stringify({observed:true,contract:3,kind:"user-targeted",bundle_id:t.bundle_id,device:t.device,device_kind:"simulator",environment:"development",run_id:t.run_id,observed_at:new Date().toISOString(),observer:"ios-prove simulator store and log",evidence:{apns_received:true,os_stored:true,os_displayed:true}},null,2)+"\n",{mode:0o600});
' "$MISS/.iterable/ios/proof-target.json" "$MISS/.iterable/ios/proof/development/user-targeted.json"
forged="$(miss "$OLDPWD/bin/ios-verify status")"
if [[ "$(value "$forged" verdict)" != done ]]; then
  ok "a forged receipt does not turn a miss into a pass; the verifier ignores it"
else
  bad "the verifier trusted a receipt without Simulator evidence"
fi
if [[ "$(value "$missed" next.kind)" == review_delivery &&
      "$(value "$missed" next.owner)" == human &&
      "$(value "$missed" next.summary)" == *"never_reached_simulator"* &&
      "$(value "$missed" next.command)" == *"restart --confirm" &&
      "$(value "$missed_again" next.kind)" == review_delivery &&
      "$(grep -c . "$MISS_STATE/proof-sends")" -eq 1 ]]; then
  ok "a miss names its cause, hands the restart decision to the developer, and never resends"
else
  bad "a missed delivery looped, resent, or gave no named cause" \
    "next=$(value "$missed" next.kind): $(value "$missed" next.summary)"
fi

# The Apple check: a provisioned workspace with an imported key asks Apple first.
APPLE="$ROOT/AppleCheck"
cp -R "$GOLD" "$APPLE"
rm -rf "$APPLE/.iterable/ios/proof-target.json" "$APPLE/.iterable/ios/sends" "$APPLE/.iterable/ios/proof" "$APPLE/.iterable/ios/observations"
APPLE_STATE="$ROOT/apple-state"
mkdir -p "$APPLE_STATE"
touch "$APPLE_STATE/user-exists" "$APPLE_STATE/device-exists"
cp -R "$STATE/SampleShop.app" "$APPLE_STATE/SampleShop.app"
node -e 'process.stdout.write(Buffer.alloc(80,0x11).toString("hex"))' > "$APPLE_STATE/token-hex"
"$SIMULATE" register "$APPLE_STATE/devices" SIM-VERIFY-1 com.example.sampleshop
node -e '
  const crypto=require("crypto"), fs=require("fs"), dir=process.argv[1];
  const {privateKey}=crypto.generateKeyPairSync("ec",{namedCurve:"P-256"});
  fs.writeFileSync(`${dir}/AuthKey_ABC123DEFG.p8`,privateKey.export({type:"pkcs8",format:"pem"}),{mode:0o600});
  fs.writeFileSync(`${dir}/apns.json`,JSON.stringify({key_path:`${dir}/AuthKey_ABC123DEFG.p8`,key_id:"ABC123DEFG",team_id:"TEAM123456"},null,2)+"\n",{mode:0o600});
' "$APPLE/.iterable/ios"
printf '400 TopicDisallowed' > "$ROOT/apns-scenario"
node "$OLDPWD/tests/fixtures/ios-prove/fake-apns.js" "$ROOT/apns-port" "$ROOT/apns-scenario" "$ROOT/apns-requests" &
apns_pid=$!
for _ in $(seq 1 50); do [[ -s "$ROOT/apns-port" ]] && break; sleep 0.1; done
apple() {
  (
    cd "$APPLE" || exit
    env PATH="$FAKEBIN:$PATH" IOS_TRANSITION_STATE="$APPLE_STATE" \
      IOS_TRANSITION_SIMULATE="$SIMULATE" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$APPLE_STATE/devices" \
      IOS_APNS_PROBE_ORIGIN="http://127.0.0.1:$(cat "$ROOT/apns-port")" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" IOS_WORKSPACE="$APPLE/.iterable/ios" \
      bash -c "$1" 2>/dev/null
  )
}
apple "$OLDPWD/bin/ios-prepare-proof start --confirm --identity dogs@example.com" >/dev/null
blocked="$(apple "$OLDPWD/bin/ios-verify status")"
check_out="$(apple "$OLDPWD/bin/ios-verify check-apple")"
check_rc=$?
if [[ "$(value "$blocked" next.kind)" == fix_apple_push &&
      "$(value "$blocked" next.owner)" == human &&
      "$(value "$blocked" next.summary)" == *"isn't enabled for Push on team TEAM123456"* &&
      "$(value "$blocked" next.command)" == *"/ios-verify check-apple" &&
      "$(value "$check_out" classification)" == app_id_push_disabled && "$check_rc" -eq 20 &&
      "$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).diagnostic_only===true?"yes":"no")' "$APPLE/.iterable/ios/observations/apple-check.json")" == yes ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const g=id=>v.gates.find(x=>x.id===id)?.status;
      process.exit(g("I13")==="red" && g("I14")==="blocked" ? 0 : 1);
    ' "$blocked"; then
  ok "Apple's TopicDisallowed is a named gate with the fix, check-apple repeats it, and the receipt says diagnostic only"
else
  bad "the Apple refusal was not surfaced before the push gate" "next=$(value "$blocked" next.kind): $(value "$blocked" next.summary) check_rc=$check_rc"
fi
printf 200 > "$ROOT/apns-scenario"
ready_check="$(apple "$OLDPWD/bin/ios-verify check-apple")"
ready_rc=$?
ready="$(apple "$OLDPWD/bin/ios-verify status")"
if [[ "$ready_rc" -eq 0 && "$(value "$ready_check" status)" == ready &&
      "$(value "$ready" next.kind)" == prove_push ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(x=>x.id==="I13")?.status==="green" ? 0 : 1);
    ' "$ready"; then
  ok "once Apple accepts pushes, the run proceeds to the single proof send"
else
  bad "a ready Apple check did not lead to the proof send" "next=$(value "$ready" next.kind) rc=$ready_rc"
fi
kill "$apns_pid" 2>/dev/null
wait "$apns_pid" 2>/dev/null

((FAILED)) && exit 1
exit 0
