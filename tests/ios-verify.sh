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

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-verify-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-verify-test.*|/private/tmp/iterable-ios-verify-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT
VERIFIER="$PWD/bin/ios-verify"

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE"
APNS_TOKEN="00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff"
OTHER_APNS_TOKEN="ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100ffeeddccbbaa99887766554433221100"
APNS_TOKEN_HASH="$(node -e '
  const crypto=require("crypto");
  process.stdout.write(
    crypto.createHash("sha256").update(Buffer.from(process.argv[1],"hex")).digest("hex")
  );
' "$APNS_TOKEN")"
RUN_ID="11111111-2222-4333-8444-555555555555"
iso_offset() {
  node -e '
    process.stdout.write(new Date(Date.now()+Number(process.argv[1])*1000).toISOString())
  ' -- "$1"
}
BASELINE_AT="$(iso_offset -600)"
STARTED_AT="$(iso_offset -540)"
INITIAL_1="$(iso_offset -539)"
INITIAL_2="$(iso_offset -538)"
INITIAL_3="$(iso_offset -537)"
INITIAL_4="$(iso_offset -536)"
INITIAL_5="$(iso_offset -535)"
INITIAL_6="$(iso_offset -534)"
SENT_AT="$(iso_offset -420)"
OBSERVED_AT="$(iso_offset -300)"
PUSH_1="$(iso_offset -299)"
PUSH_2="$(iso_offset -298)"
PUSH_3="$(iso_offset -297)"
RESTORE_AT="$(iso_offset -240)"
RESTORE_1="$(iso_offset -239)"
RESTORE_2="$(iso_offset -238)"
LOGOUT_1="$(iso_offset -180)"
LOGOUT_2="$(iso_offset -179)"
LOGOUT_3="$(iso_offset -178)"
LOGOUT_4="$(iso_offset -177)"
EXPIRES_AT="$(iso_offset 3600)"
STALE_AT="$(iso_offset -660)"

cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "Xcode 18.0"
EOF
cat > "$FAKEBIN/npx" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
config="$(cat)"
printf '%s\n' "$config" >> "$IOS_VERIFY_STATE/curl-configs"
if grep -q 'verify-invalid' <<< "$config"; then
  printf '{"msg":"invalid api key"}\n401\n'
elif grep -q 'mobile-live-key' <<< "$config"; then
  [[ ! -f "$IOS_VERIFY_STATE/revoke-mobile" ]] || {
    printf '{"msg":"invalid api key"}\n401\n'
    exit 0
  }
  printf '{"msg":"Invalid parameters"}\n400\n'
elif grep -q '/api/channels' <<< "$config"; then
  [[ ! -f "$IOS_VERIFY_STATE/revoke-server" ]] || {
    printf '{"msg":"invalid api key"}\n401\n'
    exit 0
  }
  printf '{"channels":[{"messageMedium":"Push"}]}\n200\n'
elif grep -q '/api/users/getByEmail' <<< "$config"; then
  if [[ -f "$IOS_VERIFY_STATE/no-user" ]]; then
    printf '{"msg":"No user exists"}\n400\n'
  elif grep -q 'ios-proof-b%40example.com' <<< "$config"; then
    if [[ -f "$IOS_VERIFY_STATE/switched" ]]; then
      token="$IOS_VERIFY_APNS_TOKEN"
      [[ ! -f "$IOS_VERIFY_STATE/b-wrong-tested-token" ]] ||
        token="$IOS_VERIFY_OTHER_APNS_TOKEN"
      printf '{"user":{"email":"ios-proof-b@example.com","dataFields":{"devices":[{"appPackageName":"com.example.dogshelter","token":"%s","endpointEnabled":true,"notificationsEnabled":true}]}}}\n200\n' "$token"
    else
      printf '{"msg":"No user exists"}\n400\n'
    fi
  elif [[ -f "$IOS_VERIFY_STATE/switched" ]]; then
    tested_enabled=false
    [[ ! -f "$IOS_VERIFY_STATE/a-retains-tested-token" ]] || tested_enabled=true
    printf '{"user":{"email":"ios-proof@example.com","dataFields":{"favoriteDogIds":[1,2],"devices":[{"appPackageName":"com.example.dogshelter","token":"%s","endpointEnabled":%s,"notificationsEnabled":true}]}}}\n200\n' \
      "$IOS_VERIFY_APNS_TOKEN" "$tested_enabled"
  else
    token="$IOS_VERIFY_APNS_TOKEN"
    [[ ! -f "$IOS_VERIFY_STATE/wrong-registration-token" ]] ||
      token="$IOS_VERIFY_OTHER_APNS_TOKEN"
    printf '{"user":{"email":"ios-proof@example.com","dataFields":{"favoriteDogIds":[1,2],"devices":[{"appPackageName":"com.example.dogshelter","token":"%s","endpointEnabled":true,"notificationsEnabled":true}]}}}\n200\n' "$token"
  fi
elif grep -q '/api/events/' <<< "$config"; then
  if [[ -f "$IOS_VERIFY_STATE/duplicate-event" ]]; then
    printf '{"events":[{"eventName":"favoriteUpdated","createdAt":"%s"},{"eventName":"favoriteUpdated","createdAt":"%s"}]}\n200\n' \
      "$IOS_VERIFY_EVENT_AT" "$IOS_VERIFY_EVENT_AT"
  else
    printf '{"events":[{"eventName":"favoriteUpdated","createdAt":"%s"}]}\n200\n' \
      "$IOS_VERIFY_EVENT_AT"
  fi
else
  printf '{"msg":"unexpected request"}\n500\n'
fi
EOF
cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_VERIFY_STATE/xcrun-calls"
if [[ "$*" == "simctl list devices --json" ]]; then
  if [[ -f "$IOS_VERIFY_STATE/use-simulator" ]]; then
    if [[ -f "$IOS_VERIFY_STATE/simulator-shutdown" ]]; then
      printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"SIM-DEVICE-1","name":"iPhone 16","state":"Shutdown","isAvailable":true}]}}\n'
    else
      printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"SIM-DEVICE-1","name":"iPhone 16","state":"Booted","isAvailable":true}]}}\n'
    fi
  else
    printf '{"devices":{}}\n'
  fi
elif [[ "$*" == vtool\ -show-build* ]]; then
  if [[ -f "$IOS_VERIFY_STATE/simulator-artifact" ]]; then
    printf 'platform IOSSIMULATOR\n'
  else
    printf 'platform IOS\n'
  fi
elif [[ "$*" == "simctl get_app_container SIM-DEVICE-1 com.example.dogshelter app" ]]; then
  printf '%s\n' "$IOS_VERIFY_STATE/sim-app"
elif [[ "$*" == "simctl get_app_container SIM-DEVICE-1 com.example.dogshelter data" ]]; then
  printf '%s\n' "$IOS_VERIFY_STATE/sim-data"
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[{"identifier":"00008101-TESTDEVICE","name":"Test iPhone","state":"available"}]}}\n'
elif [[ "$*" == *"device info apps"* ]]; then
  printf '{"result":{"apps":[{"bundleIdentifier":"com.example.dogshelter","version":"1.0","bundleVersion":"42"}]}}\n'
elif [[ "$*" == *"device copy from"* ]]; then
  destination=""
  while (($#)); do
    if [[ "$1" == --destination ]]; then destination="$2"; break; fi
    shift
  done
  [[ -n "$destination" ]] || exit 2
  cp "$IOS_VERIFY_STATE/runtime-proof.jsonl" "$destination"
else
  exit 2
fi
EOF
cat > "$FAKEBIN/agent-device" <<'EOF'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >> "$IOS_VERIFY_STATE/agent-device-calls"
[[ ! -f "$IOS_VERIFY_STATE/observer-fails" ]] || exit 1
printf '{"ok":true}\n'
EOF
cat > "$FAKEBIN/codesign" <<'EOF'
#!/usr/bin/env bash
set -eu
if [[ "$*" == *"--entitlements :-"* ]]; then
  if [[ -f "$IOS_VERIFY_STATE/simulator-artifact" ]]; then
    printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict></dict></plist>'
    exit 0
  fi
  cat <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict><key>aps-environment</key><string>development</string></dict></plist>
PLIST
fi
exit 0
EOF
cat > "$FAKEBIN/otool" <<'EOF'
#!/usr/bin/env bash
set -eu
[[ ! -f "$IOS_VERIFY_STATE/simulator-missing-entitlements" ]] || exit 0
node <<'NODE'
const identifier = require("fs").existsSync(
  process.env.IOS_VERIFY_STATE + "/simulator-wrong-application-identifier"
) ? "TEAMID.com.example.other" : "TEAMID.com.example.dogshelter";
const plist = `<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>application-identifier</key><string>${identifier}</string>
<key>aps-environment</key><string>development</string>
</dict></plist>`;
const bytes = Buffer.from(plist);
console.log("fixture:");
console.log("Contents of (__TEXT,__entitlements) section");
for (let offset = 0; offset < bytes.length; offset += 16) {
  const words = [];
  for (let wordOffset = 0; wordOffset < 16; wordOffset += 4) {
    if (offset + wordOffset >= bytes.length) break;
    const word = Buffer.alloc(4);
    bytes.copy(
      word,
      0,
      offset + wordOffset,
      Math.min(offset + wordOffset + 4, bytes.length)
    );
    words.push(Buffer.from(word).reverse().toString("hex"));
  }
  console.log(
    (0x100000000 + offset).toString(16).padStart(16, "0") + "\t" +
    words.join(" ")
  );
}
NODE
EOF
cat > "$FAKEBIN/plutil" <<'EOF'
#!/usr/bin/env bash
set -eu
key=""
file="${@: -1}"
while (($#)); do
  if [[ "$1" == -extract ]]; then key="$2"; shift 2; else shift; fi
done
if [[ "$file" == "-" ]]; then
  input="$(cat)"
  case "$key" in
    aps-environment)
      [[ "$input" == *"<key>aps-environment</key><string>development</string>"* ]] ||
        exit 1
      printf 'development\n'
      ;;
    application-identifier)
      value="$(
        sed -n 's|.*<key>application-identifier</key><string>\([^<]*\)</string>.*|\1|p' \
          <<< "$input"
      )"
      [[ -n "$value" ]] || exit 1
      printf '%s\n' "$value"
      ;;
    *)
      exit 1
      ;;
  esac
  exit 0
fi
case "$key" in
  CFBundleIdentifier) printf 'com.example.dogshelter\n' ;;
  CFBundleShortVersionString) printf '1.0\n' ;;
  CFBundleVersion) printf '42\n' ;;
  CFBundleExecutable) printf 'DogShelter\n' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$FAKEBIN"/*

APP_PATH="$ROOT/DogShelter.app"
mkdir -p "$APP_PATH"
printf 'fixture\n' > "$APP_PATH/Info.plist"
printf 'same executable\n' > "$APP_PATH/DogShelter"
mkdir -p "$APP_PATH/IterableSDKResources.bundle"
printf 'iterable-ios-runtime-proof/1\n' > "$APP_PATH/IterableRuntimeProof.fixture"

cat > "$WORKSPACE/scope.json" <<'EOF'
{
  "features": [
    "sdk-initialization",
    "user-profiles",
    "event-tracking",
    "push-notifications"
  ],
  "identity_mode": "email",
  "data_region": "US",
  "jwt_enabled": false
}
EOF
cat > "$WORKSPACE/.env" <<'EOF'
ITERABLE_API_KEY=mobile-live-key-1234567890
ITERABLE_DATA_REGION=US
ITERABLE_JWT_ENABLED=false
ITERABLE_SERVER_KEY=server-live-key-1234567890
EOF
cat > "$WORKSPACE/IterableSecrets.xcconfig" <<'EOF'
ITERABLE_API_KEY = mobile-live-key-1234567890
ITERABLE_DATA_REGION = US
ITERABLE_JWT_ENABLED = false
EOF
mobile_hash="$(printf '%s' 'mobile-live-key-1234567890' | shasum -a 256 | awk '{print $1}')"
server_hash="$(printf '%s' 'server-live-key-1234567890' | shasum -a 256 | awk '{print $1}')"
cat > "$WORKSPACE/mobile-validation.json" <<EOF
{"valid":true,"key_sha256":"$mobile_hash","data_region":"US","jwt_enabled":false,"classification":"authenticated-mobile-key"}
EOF
cat > "$WORKSPACE/server-validation.json" <<EOF
{"valid":true,"key_sha256":"$server_hash","data_region":"US","classification":"authenticated-server-key"}
EOF
cat > "$WORKSPACE/proof-target.json" <<EOF
{
  "bundle_id": "com.example.dogshelter",
  "identity_type": "email",
  "identity": "ios-proof@example.com",
  "switch_identity": "ios-proof-b@example.com",
  "device": "00008101-TESTDEVICE",
  "device_kind": "physical",
  "simulator_runtime": null,
  "app_path": "$APP_PATH",
  "environment": "development",
  "proof_mode": "instrumented",
  "apns_environment": "sandbox",
  "production_follow_up_required": true,
  "profile_fields": ["favoriteDogIds"],
  "events": ["favoriteUpdated"],
  "run_id": "$RUN_ID",
  "baseline": {
    "identity_exists": false,
    "switch_identity_exists": false,
    "checked_at": "$BASELINE_AT"
  },
  "markers": {
    "direct": "ITBL-IOS-DIRECT-A1B2C3",
    "user_targeted": "ITBL-IOS-USER-A-A1B2C3",
    "user_targeted_switch": "ITBL-IOS-USER-B-A1B2C3"
  },
  "expectations": {
    "tap_route": "Dog details",
    "logout_switch": "Signed in as User B"
  },
  "started_at": "$STARTED_AT"
}
EOF
chmod 600 "$WORKSPACE"/*.json "$WORKSPACE/.env" "$WORKSPACE/IterableSecrets.xcconfig"

mkdir -p "$WORKSPACE/launches"
cat > "$WORKSPACE/launches/initial.json" <<EOF
{"launched":true,"phase":"initial","bundle_id":"com.example.dogshelter","device":"00008101-TESTDEVICE","device_kind":"physical","run_id":"$RUN_ID","launched_at":"$STARTED_AT","expires_at":"$EXPIRES_AT"}
EOF
cat > "$WORKSPACE/launches/restore.json" <<EOF
{"launched":true,"phase":"restore","bundle_id":"com.example.dogshelter","device":"00008101-TESTDEVICE","device_kind":"physical","run_id":"$RUN_ID","launched_at":"$RESTORE_AT","expires_at":"$EXPIRES_AT"}
EOF
chmod 700 "$WORKSPACE/launches"
chmod 600 "$WORKSPACE/launches"/*.json

a_hmac="$(node -e 'const c=require("crypto");process.stdout.write(c.createHmac("sha256",process.argv[1]).update("ios-proof@example.com").digest("hex"))' "$RUN_ID")"
b_hmac="$(node -e 'const c=require("crypto");process.stdout.write(c.createHmac("sha256",process.argv[1]).update("ios-proof-b@example.com").digest("hex"))' "$RUN_ID")"
target_marker_hash="$(printf '%s' 'ITBL-IOS-USER-A-A1B2C3' | shasum -a 256 | awk '{print $1}')"
target_nonce="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
target_nonce_hash="$(printf '%s' "$target_nonce" | shasum -a 256 | awk '{print $1}')"
cat > "$STATE/runtime-proof.jsonl" <<EOF
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_1","process_launch_id":"launch-1","proof_phase":"initial","sequence":1,"event":"application_did_finish_launching","bundle_id":"com.example.dogshelter","version":"1.0","build":"42","environment":"development"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_2","process_launch_id":"launch-1","proof_phase":"initial","sequence":2,"event":"sdk_initialize_returned","region":"US","jwt_required":false,"auto_push_registration":true}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_3","process_launch_id":"launch-1","proof_phase":"initial","sequence":3,"event":"iterable_identity_set_invoked","identity_kind":"email","identity_hmac":"$a_hmac","source":"login","session_generation":1}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_4","process_launch_id":"launch-1","proof_phase":"initial","sequence":4,"event":"notification_settings_observed","authorization_status":2,"alert_setting":2,"badge_setting":2,"sound_setting":2,"source":"after-request"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_5","process_launch_id":"launch-1","proof_phase":"initial","sequence":5,"event":"apns_registration_callback","token_sha256":"$APNS_TOKEN_HASH","token_bytes":48}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$INITIAL_6","process_launch_id":"launch-1","proof_phase":"initial","sequence":6,"event":"iterable_register_invoked","token_sha256":"$APNS_TOKEN_HASH"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$PUSH_1","process_launch_id":"launch-1","proof_phase":"initial","sequence":7,"event":"notification_response_callback","marker_sha256":"$target_marker_hash","delivery_nonce_sha256":"$target_nonce_hash","template_id":424242,"message_id_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","action_identifier":"com.apple.UNNotificationDefaultActionIdentifier"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$PUSH_2","process_launch_id":"launch-1","proof_phase":"initial","sequence":8,"event":"iterable_push_forward_invoked","marker_sha256":"$target_marker_hash","delivery_nonce_sha256":"$target_nonce_hash","template_id":424242,"message_id_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","action_identifier":"com.apple.UNNotificationDefaultActionIdentifier"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$PUSH_3","process_launch_id":"launch-1","proof_phase":"initial","sequence":9,"event":"notification_response_completion","marker_sha256":"$target_marker_hash","delivery_nonce_sha256":"$target_nonce_hash","template_id":424242,"message_id_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","action_identifier":"com.apple.UNNotificationDefaultActionIdentifier"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$RESTORE_1","process_launch_id":"launch-2","proof_phase":"restore","sequence":1,"event":"application_did_finish_launching","bundle_id":"com.example.dogshelter","version":"1.0","build":"42","environment":"development"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$RESTORE_2","process_launch_id":"launch-2","proof_phase":"restore","sequence":2,"event":"iterable_identity_set_invoked","identity_kind":"email","identity_hmac":"$a_hmac","source":"restore","session_generation":1}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$LOGOUT_1","process_launch_id":"launch-2","proof_phase":"restore","sequence":3,"event":"local_personalized_state_cleared","session_generation":2}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$LOGOUT_2","process_launch_id":"launch-2","proof_phase":"restore","sequence":4,"event":"iterable_logout_invoked","session_generation":2}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$LOGOUT_3","process_launch_id":"launch-2","proof_phase":"restore","sequence":5,"event":"iterable_logout_callback","result":"success"}
{"schema":"iterable-ios-runtime-proof/1","run_id":"$RUN_ID","recorded_at":"$LOGOUT_4","process_launch_id":"launch-2","proof_phase":"restore","sequence":6,"event":"iterable_identity_set_invoked","identity_kind":"email","identity_hmac":"$b_hmac","source":"login","session_generation":3}
EOF

mkdir -p "$WORKSPACE/sends/development"
chmod 700 "$WORKSPACE/sends" "$WORKSPACE/sends/development"
for spec in \
  'direct|ITBL-IOS-DIRECT-A1B2C3|iterable-dashboard-test-push|ios-proof@example.com' \
  'user-targeted|ITBL-IOS-USER-A-A1B2C3|iterable-api-template-proof|ios-proof@example.com' \
  'user-targeted-switch|ITBL-IOS-USER-B-A1B2C3|iterable-api-template-proof|ios-proof-b@example.com'; do
  IFS='|' read -r send_kind marker source identity <<< "$spec"
  marker_hash="$(printf '%s' "$marker" | shasum -a 256 | awk '{print $1}')"
  identity_hash="$(printf '%s' "$identity" | shasum -a 256 | awk '{print $1}')"
  cat > "$WORKSPACE/sends/development/$send_kind.json" <<EOF
{"contract":2,"sent":true,"kind":"$send_kind","source":"$source","bundle_id":"com.example.dogshelter","device":"00008101-TESTDEVICE","device_kind":"physical","environment":"development","run_id":"$RUN_ID","marker_sha256":"$marker_hash","recipient_sha256":"$identity_hash","template_id":424242,"delivery_nonce_sha256":"$target_nonce_hash","payload_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","sent_at":"$SENT_AT"}
EOF
  chmod 600 "$WORKSPACE/sends/development/$send_kind.json"
done

run_verify() {
  env \
    PATH="$FAKEBIN:$PATH" \
    IOS_VERIFY_STATE="$STATE" \
    IOS_VERIFY_APNS_TOKEN="$APNS_TOKEN" \
    IOS_VERIFY_OTHER_APNS_TOKEN="$OTHER_APNS_TOKEN" \
    IOS_VERIFY_EVENT_AT="$SENT_AT" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-verify status "$@"
}

json_value() {
  node -e '
    const value = process.argv[2].split(".").reduce(
      (object, key) => object == null ? object : object[key],
      JSON.parse(process.argv[1])
    );
    process.stdout.write(String(value));
  ' "$1" "$2"
}

INSPECT_PROJECT="$ROOT/inspect-app"
mkdir -p "$INSPECT_PROJECT/DogShelter"
cat > "$INSPECT_PROJECT/project.yml" <<'EOF'
name: DogShelter
EOF
cat > "$INSPECT_PROJECT/DogShelter/AppDelegate.swift" <<'EOF'
import IterableSDK
IterableAPI.initialize(apiKey: mobileKey, launchOptions: nil, config: config)
IterableAPI.email = currentEmail
UIApplication.shared.registerForRemoteNotifications()
EOF
inspect_out="$(
  cd "$INSPECT_PROJECT" &&
    PATH="$FAKEBIN:$PATH" "$VERIFIER" inspect 2>/dev/null
)"
if [[ "$(json_value "$inspect_out" read_only)" == true &&
      "$(json_value "$inspect_out" signals.sdk_dependency)" == true &&
      "$(json_value "$inspect_out" signals.sdk_initialization)" == true &&
      "$(json_value "$inspect_out" next.kind)" == prepare_proof &&
      ! -e "$INSPECT_PROJECT/.iterable" ]]; then
  ok "clean verification can inspect an existing integration without provisioning or writing state"
else
  bad "verify-only inspection replayed setup or missed an existing integration"
fi

COMMENT_PROJECT="$ROOT/comment-only-app"
mkdir -p "$COMMENT_PROJECT/App" "$COMMENT_PROJECT/AppTests"
cat > "$COMMENT_PROJECT/project.yml" <<'EOF'
name: CommentOnly
EOF
cat > "$COMMENT_PROJECT/App/App.swift" <<'EOF'
// IterableSDK and IterableAPI.initialize(apiKey: "not-real")
struct App {}
EOF
cat > "$COMMENT_PROJECT/AppTests/IterableTests.swift" <<'EOF'
import IterableSDK
func fixture() {
    IterableAPI.initialize(apiKey: "test-only")
}
EOF
comment_inspect="$(
  cd "$COMMENT_PROJECT" &&
    PATH="$FAKEBIN:$PATH" "$VERIFIER" inspect 2>/dev/null
)"
if [[ "$(json_value "$comment_inspect" signals.sdk_initialization)" == false &&
      "$(json_value "$comment_inspect" next.kind)" == review_integration ]]; then
  ok "verification discovery ignores comments and test-only Iterable calls"
else
  bad "verification discovery treated comments or tests as the application target"
fi

EMPTY="$ROOT/empty/.iterable/ios"
mkdir -p "$(dirname "$EMPTY")"
empty_out="$(
  env PATH="$FAKEBIN:$PATH" IOS_VERIFY_STATE="$STATE" IOS_WORKSPACE="$EMPTY" \
    bin/ios-verify status --offline 2>/dev/null
)"
empty_rc=$?
if [[ "$empty_rc" -eq 40 &&
      "$(json_value "$empty_out" verdict)" == pending &&
      "$(json_value "$empty_out" gates.0.status)" == pending &&
      ! -e "$EMPTY" ]]; then
  ok "a fresh app is pending, not defective, and verification writes no workspace"
else
  bad "fresh verification produced a false defect or wrote state"
fi

: > "$STATE/curl-configs"
without_observations="$(run_verify 2>/dev/null)"
without_observations_rc=$?
if [[ "$without_observations_rc" -eq 40 &&
      "$(json_value "$without_observations" verdict)" == pending &&
      "$(json_value "$without_observations" next.kind)" == observe_user_targeted &&
      "$(json_value "$without_observations" push_proven)" == false ]] &&
    [[ "$(grep -c 'url = ' "$STATE/curl-configs")" -ge 6 ]]; then
  ok "live local, credential, identity, profile, event, device, and install reads precede delivery"
else
  bad "verifier skipped live reads or claimed push before observation"
fi

if ! grep -q 'mobile-live-key\\|server-live-key' <<< "$without_observations"; then
  ok "verifier output contains no Iterable credential values"
else
  bad "verifier leaked an Iterable credential"
fi

node -e '
  const fs=require("fs"), p=process.argv[1];
  const v=JSON.parse(fs.readFileSync(p,"utf8"));
  delete v.contract;
  fs.writeFileSync(p,JSON.stringify(v)+"\n");
' "$WORKSPACE/sends/development/user-targeted.json"
legacy_send="$(run_verify 2>/dev/null)"
legacy_send_rc=$?
node -e '
  const fs=require("fs"), p=process.argv[1];
  const v=JSON.parse(fs.readFileSync(p,"utf8"));
  v.contract=2;
  fs.writeFileSync(p,JSON.stringify(v)+"\n");
' "$WORKSPACE/sends/development/user-targeted.json"
if [[ "$legacy_send_rc" -ne 0 &&
      "$(json_value "$legacy_send" next.kind)" == restart_proof &&
      "$(json_value "$legacy_send" next.command)" == *"/ios-prepare-proof restart --confirm" ]]; then
  ok "an older proof payload restarts instead of trapping the sender behind its manifest"
else
  bad "an older proof payload did not route to a fresh run"
fi

touch "$STATE/wrong-registration-token"
wrong_registration="$(run_verify 2>/dev/null)"
wrong_registration_rc=$?
rm "$STATE/wrong-registration-token"
if [[ "$wrong_registration_rc" -ne 0 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I12")?.status!=="green" ? 0 : 1);
    ' "$wrong_registration"; then
  ok "device registration requires the exact runtime APNs token"
else
  bad "a same-bundle device with the wrong APNs token passed registration"
fi

touch "$STATE/revoke-mobile"
revoked_mobile="$(run_verify 2>/dev/null)"
revoked_mobile_rc=$?
rm "$STATE/revoke-mobile"
if [[ "$revoked_mobile_rc" -ne 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.some(g=>g.id==="I2") ? 1 : 0);
    ' "$revoked_mobile"; then
  ok "verification does not revalidate or depend on the app's Mobile key"
else
  bad "verifier incorrectly took ownership of Mobile-key validation"
fi

touch "$STATE/revoke-server"
revoked_server="$(run_verify 2>/dev/null)"
revoked_server_rc=$?
rm "$STATE/revoke-server"
if [[ "$revoked_server_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I3")?.status==="red" ? 0 : 1);
    ' "$revoked_server"; then
  ok "a stale Server validation receipt cannot hide a revoked live credential"
else
  bad "verifier trusted historical Server validation over a live rejection"
fi

mkdir -p "$WORKSPACE/proof/development"
for spec in \
  'direct|ITBL-IOS-DIRECT-A1B2C3' \
  'user-targeted|ITBL-IOS-USER-A-A1B2C3' \
  'tap-route|Dog details' \
  'logout-switch|Signed in as User B' \
  'user-targeted-switch|ITBL-IOS-USER-B-A1B2C3'; do
  kind="${spec%%|*}"
  expectation="${spec#*|}"
  expectation_hash="$(printf '%s' "$expectation" | shasum -a 256 | awk '{print $1}')"
  mkdir -p "$WORKSPACE/proof/development"
  cat > "$WORKSPACE/proof/development/$kind.json" <<EOF
{"observed":true,"kind":"$kind","bundle_id":"com.example.dogshelter","device":"00008101-TESTDEVICE","device_kind":"physical","environment":"development","run_id":"$RUN_ID","expectation_sha256":"$expectation_hash","observed_at":"$OBSERVED_AT"}
EOF
  chmod 600 "$WORKSPACE/proof/development/$kind.json"
done
touch "$STATE/switched"
complete="$(run_verify 2>/dev/null)"
complete_rc=$?
if [[ "$complete_rc" -eq 0 &&
      "$(json_value "$complete" verdict)" == done &&
      "$(json_value "$complete" integration_complete)" == true &&
      "$(json_value "$complete" push_proven)" == true &&
      "$(json_value "$complete" next.kind)" == done ]]; then
  ok "all current independent evidence produces one explicit done verdict"
else
  bad "complete proof did not reach the terminal verifier state"
fi

mkdir -p "$ROOT/app/App"
cat > "$ROOT/app/App/AppDelegate.swift" <<'EOF'
import IterableSDK
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        IterableAPI.register(token: deviceToken)
        PushRelay.shared.register(deviceToken)
    }
}
EOF
coexisting="$(run_verify 2>/dev/null)"
coexisting_rc=$?
if [[ "$coexisting_rc" -eq 0 &&
      "$(json_value "$coexisting" verdict)" == done &&
      "$(json_value "$coexisting" integration_complete)" == false ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.feature_evidence_required.includes("existing-push-coexistence") &&
        v.next.summary.includes("App/AppDelegate.swift") &&
        v.next.summary.includes("triggers a notification the app itself sends") ? 0 : 1);
    ' "$coexisting"; then
  ok "done keeps the app's own push path as evidence still required, naming what the developer does"
else
  bad "done read as complete although the app has its own push path" "$coexisting"
fi
cat > "$ROOT/app/App/AppDelegate.swift" <<'EOF'
import IterableSDK
extension AppDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        IterableAPI.register(token: deviceToken)
    }
}
EOF
iterable_only="$(run_verify 2>/dev/null)"
if [[ "$(json_value "$iterable_only" integration_complete)" == true &&
      "$iterable_only" != *existing-push-coexistence* ]]; then
  ok "an Iterable-only token callback does not add existing-push evidence"
else
  bad "an Iterable-only integration was asked to prove another push path" "$iterable_only"
fi
rm -rf "$ROOT/app/App"

mv "$APP_PATH/IterableRuntimeProof.fixture" "$STATE/IterableRuntimeProof.fixture"
node -e '
  const fs=require("fs"), path=process.argv[1];
  const value=JSON.parse(fs.readFileSync(path,"utf8"));
  value.proof_mode="behavioral";
  fs.writeFileSync(path,JSON.stringify(value,null,2)+"\n");
' "$WORKSPACE/proof-target.json"
cp "$WORKSPACE/sends/development/user-targeted.json" "$STATE/instrumented-manifest.json"
cp "$WORKSPACE/proof/development/user-targeted.json" "$STATE/instrumented-receipt.json"
readback="$(node bin/ios-notify-read.js readback-new)"
node -e '
  const fs=require("fs"), [manifest,receipt,raw]=process.argv.slice(1);
  const r=JSON.parse(raw), m=JSON.parse(fs.readFileSync(manifest,"utf8"));
  Object.assign(m,{contract:4,state:"sent",sent:true,device_kind:"physical",prepared_at:m.prepared_at||m.sent_at,readback:{salt:r.salt,hash:r.hash,kdf:r.kdf}});
  fs.writeFileSync(manifest,JSON.stringify(m,null,2)+"\n",{mode:0o600});
  fs.writeFileSync(receipt,JSON.stringify({
    observed:true,contract:3,kind:"user-targeted",bundle_id:m.bundle_id,device:m.device,
    device_kind:"physical",environment:m.environment,run_id:m.run_id,observed_at:new Date().toISOString(),
    observer:"developer read-back",verification_tier:"developer-observed",readback_matched:true,
    corroboration:{status:"skipped",reason:"the host would not collect the iPhone log without elevated permissions"}
  },null,2)+"\n",{mode:0o600});
  fs.mkdirSync(require("path").dirname(process.argv[4]),{recursive:true,mode:0o700});
  fs.writeFileSync(process.argv[4],JSON.stringify({contract:2,run_id:m.run_id,attempts:0,locked:false,not_seen:false,matched:true},null,2)+"\n",{mode:0o600});
' "$WORKSPACE/sends/development/user-targeted.json" "$WORKSPACE/proof/development/user-targeted.json" "$readback" "$WORKSPACE/observations/readback.json"
behavioral_complete="$(run_verify 2>/dev/null)"
behavioral_complete_rc=$?
cp "$STATE/instrumented-manifest.json" "$WORKSPACE/sends/development/user-targeted.json"
cp "$STATE/instrumented-receipt.json" "$WORKSPACE/proof/development/user-targeted.json"
chmod 600 "$WORKSPACE/sends/development/user-targeted.json" "$WORKSPACE/proof/development/user-targeted.json"
if [[ "$behavioral_complete_rc" -eq 0 &&
      "$(json_value "$behavioral_complete" verdict)" == done &&
      "$(json_value "$behavioral_complete" verification_level)" == behavioral &&
      "$(json_value "$behavioral_complete" verification_subject)" == exact-recorded-artifact &&
      "$(json_value "$behavioral_complete" source_build_linked)" == true &&
      "$(json_value "$behavioral_complete" integration_complete)" == false ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const ids=new Set(v.gates.map(g=>g.id));
      process.exit(
        !ids.has("I9") &&
        !ids.has("I10") &&
        !ids.has("I11") &&
        !ids.has("I15") &&
        !ids.has("I16") &&
        !ids.has("I17") &&
        v.verification_limitations.includes("sdk-callback-ordering") &&
        v.verification_tier==="developer-observed" &&
        v.verification_limitations.includes("physical-path-untested-by-maintainers") &&
        v.feature_evidence_required.includes("user-profiles") &&
        v.feature_evidence_required.includes("event-tracking") ? 0 : 1
      );
    ' "$behavioral_complete"; then
  ok "behavioral core proof completes without app instrumentation and states its limits"
else
  bad "behavioral proof still required the evaluation runtime harness"
fi
mv "$STATE/IterableRuntimeProof.fixture" "$APP_PATH/IterableRuntimeProof.fixture"
node -e '
  const fs=require("fs"), path=process.argv[1];
  const value=JSON.parse(fs.readFileSync(path,"utf8"));
  value.proof_mode="instrumented";
  fs.writeFileSync(path,JSON.stringify(value,null,2)+"\n");
' "$WORKSPACE/proof-target.json"

mv "$APP_PATH/IterableRuntimeProof.fixture" "$STATE/IterableRuntimeProof.fixture"
missing_harness="$(run_verify 2>/dev/null)"
missing_harness_rc=$?
mv "$STATE/IterableRuntimeProof.fixture" "$APP_PATH/IterableRuntimeProof.fixture"
if [[ "$missing_harness_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(g=>g.id==="I5");
      process.exit(
        gate?.status==="red" &&
        gate.detail.includes("does not contain the Iterable runtime-proof harness") ? 0 : 1
      );
    ' "$missing_harness"; then
  ok "instrumented proof detects a missing runtime harness before launch"
else
  bad "instrumented proof reached launch without its runtime harness"
fi

touch "$STATE/duplicate-event"
duplicate_event="$(run_verify 2>/dev/null)"
duplicate_event_rc=$?
rm "$STATE/duplicate-event"
if [[ "$duplicate_event_rc" -eq 40 &&
      "$(json_value "$duplicate_event" next.kind)" == restart_proof ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(g=>g.id==="I10");
      process.exit(
        gate?.status==="pending" &&
        v.next.command.includes("ios-prepare-proof restart") ? 0 : 1
      );
    ' "$duplicate_event"; then
  ok "an event overcount restarts the contaminated proof before blaming app code"
else
  bad "a contaminated event count was reported as an integration defect"
fi

touch "$STATE/a-retains-tested-token"
a_retains_token="$(run_verify 2>/dev/null)"
a_retains_token_rc=$?
rm "$STATE/a-retains-tested-token"
if [[ "$a_retains_token_rc" -ne 0 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I16")?.status!=="green" ? 0 : 1);
    ' "$a_retains_token"; then
  ok "logout proof rejects the tested APNs token while User A still owns it"
else
  bad "User A retained the tested APNs token behind a false logout green"
fi

touch "$STATE/b-wrong-tested-token"
b_wrong_token="$(run_verify 2>/dev/null)"
b_wrong_token_rc=$?
rm "$STATE/b-wrong-tested-token"
if [[ "$b_wrong_token_rc" -ne 0 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I16")?.status!=="green" ? 0 : 1);
    ' "$b_wrong_token"; then
  ok "logout proof requires User B to own the tested APNs token"
else
  bad "an unrelated User B device produced a false logout ownership green"
fi

mkdir -p "$STATE/sim-app"
printf 'fixture\n' > "$STATE/sim-app/Info.plist"
printf 'same executable\n' > "$STATE/sim-app/DogShelter"
mkdir -p "$STATE/sim-app/IterableSDKResources.bundle"
mkdir -p "$STATE/sim-data/Library/Application Support/IterableProof/runs"
cp "$STATE/runtime-proof.jsonl" \
  "$STATE/sim-data/Library/Application Support/IterableProof/runs/$RUN_ID.jsonl"
touch "$STATE/use-simulator"
touch "$STATE/simulator-artifact"
node -e '
  const fs=require("fs");
  const scopePath=process.argv[1], targetPath=process.argv[2];
  const scope=JSON.parse(fs.readFileSync(scopePath,"utf8"));
  scope.features=scope.features.filter(feature=>feature!=="push-notifications");
  fs.writeFileSync(scopePath,JSON.stringify(scope,null,2)+"\n");
  const target=JSON.parse(fs.readFileSync(targetPath,"utf8"));
  target.device="SIM-DEVICE-1";
  target.device_kind="simulator";
  target.simulator_runtime="com.apple.CoreSimulator.SimRuntime.iOS-18-0";
  fs.writeFileSync(targetPath,JSON.stringify(target,null,2)+"\n");
' "$WORKSPACE/scope.json" "$WORKSPACE/proof-target.json"
for receipt in "$WORKSPACE/launches/initial.json" \
  "$WORKSPACE/launches/restore.json"; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="SIM-DEVICE-1";
    value.device_kind="simulator";
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt"
done
rm -f "$WORKSPACE/proof/development/logout-switch.json"
: > "$STATE/agent-device-calls"
env \
  PATH="$FAKEBIN:$PATH" \
  IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
  IOS_VERIFY_STATE="$STATE" \
  IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-observe app --kind logout-switch --timeout 1000 >/dev/null
simulator_observe_rc=$?
simulator_complete="$(run_verify 2>/dev/null)"
simulator_complete_rc=$?
if [[ "$simulator_observe_rc" -eq 0 &&
      "$simulator_complete_rc" -eq 0 &&
      "$(json_value "$simulator_complete" verdict)" == done &&
      "$(json_value "$simulator_complete" integration_complete)" == true &&
      "$(json_value "$simulator_complete" push_required)" == false &&
      "$(json_value "$simulator_complete" push_proven)" == false ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const ids=new Set(v.gates.map(g=>g.id));
      process.exit(
        v.gates.find(g=>g.id==="I4")?.status==="green" &&
        !["I12","I13","I14","I15","I17"].some(id=>ids.has(id)) ? 0 : 1
      );
    ' "$simulator_complete" &&
    grep -q 'open com.example.dogshelter .*--udid SIM-DEVICE-1' \
      "$STATE/agent-device-calls"; then
  ok "a non-push scope can complete honestly through the Simulator observation actor"
else
  bad "the verifier did not preserve the supported non-push Simulator path"
fi
mkdir -p "$ROOT/app/App"
printf 'func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {\n    PushRelay.shared.register(deviceToken)\n}\n' \
  > "$ROOT/app/App/AppDelegate.swift"
non_push_coexisting="$(run_verify 2>/dev/null)"
rm -rf "$ROOT/app/App"
if [[ "$(json_value "$non_push_coexisting" integration_complete)" == true &&
      "$non_push_coexisting" != *existing-push-coexistence* ]]; then
  ok "without push in scope, the app's own push path is not Iterable's evidence to collect"
else
  bad "a non-push scope was asked to prove the app's own push path" "$non_push_coexisting"
fi

touch "$STATE/simulator-shutdown"
shutdown_simulator="$(run_verify 2>/dev/null)"
shutdown_simulator_rc=$?
rm "$STATE/simulator-shutdown"
if [[ "$shutdown_simulator_rc" -eq 40 &&
      "$(json_value "$shutdown_simulator" verdict)" == pending &&
      "$(json_value "$shutdown_simulator" next.kind)" == boot_device &&
      "$(json_value "$shutdown_simulator" next.command)" == *"/ios-device boot" ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I4")?.status==="pending" ? 0 : 1);
    ' "$shutdown_simulator"; then
  ok "a known shut-down Simulator becomes tool-owned boot work, not a defect"
else
  bad "a shut-down Simulator was mislabeled as an integration defect"
fi

node -e '
  const fs=require("fs"), path=process.argv[1];
  const scope=JSON.parse(fs.readFileSync(path,"utf8"));
  if (!scope.features.includes("push-notifications")) {
    scope.features.push("push-notifications");
  }
  fs.writeFileSync(path,JSON.stringify(scope,null,2)+"\n");
' "$WORKSPACE/scope.json"
for receipt in "$WORKSPACE/sends/development"/*.json; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="SIM-DEVICE-1";
    value.device_kind="simulator";
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt"
done
for receipt in "$WORKSPACE/proof/development"/*.json; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="SIM-DEVICE-1";
    value.device_kind="simulator";
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt"
done

rm "$STATE/use-simulator"
simulator_temporarily_unavailable="$(run_verify 2>/dev/null)"
simulator_temporarily_unavailable_rc=$?
touch "$STATE/use-simulator"
if [[ "$simulator_temporarily_unavailable_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const device=v.gates.find(candidate=>candidate.id==="I4");
      const artifact=v.gates.find(candidate=>candidate.id==="I5");
      process.exit(
        device?.status==="red" &&
        artifact?.status==="green" &&
        artifact.detail.includes("platform=IOSSIMULATOR") ? 0 : 1
      );
    ' "$simulator_temporarily_unavailable"; then
  ok "Simulator artifact classification does not depend on live device availability"
else
  bad "an unavailable Simulator caused its artifact to be inspected as a physical-device build"
fi

simulator_push_complete="$(run_verify 2>/dev/null)"
simulator_push_rc=$?
if [[ "$simulator_push_rc" -eq 0 &&
      "$(json_value "$simulator_push_complete" verdict)" == done &&
      "$(json_value "$simulator_push_complete" push_required)" == true &&
      "$(json_value "$simulator_push_complete" push_proven)" == true ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I4")?.detail.includes("real APNs sandbox") &&
        v.gates.find(g=>g.id==="I15")?.detail.includes("sender-only nonce") ? 0 : 1);
    ' "$simulator_push_complete"; then
  ok "an eligible Simulator can complete a real APNs sandbox proof"
else
  bad "the verifier did not accept the fully correlated Simulator APNs path" \
    "$(node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(candidate=>candidate.id==="I5");
      process.stdout.write(`rc=${process.argv[2]}; I5=${gate?.status}: ${gate?.detail}; next=${v.next?.kind}`);
    ' "$simulator_push_complete" "$simulator_push_rc")"
fi

[[ "$(json_value "$simulator_push_complete" framework)" == native ]] &&
  ok "the verifier reports a native app's framework" ||
  bad "the verifier reported the wrong framework for a native app"

printf '{"dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.1.0"}}\n' > "$ROOT/app/package.json"
mkdir -p "$ROOT/app/ios/DogShelter.xcworkspace"
rn_debug="$(run_verify 2>/dev/null)"
rn_debug_rc=$?
if [[ "$rn_debug_rc" -eq 20 && "$(json_value "$rn_debug" framework)" == react-native ]] &&
    node -e '
      const gate=JSON.parse(process.argv[1]).gates.find(g=>g.id==="I5");
      process.exit(gate?.status==="red" && gate.detail.includes("no embedded main.jsbundle") &&
        gate.detail.includes("-workspace DogShelter.xcworkspace -scheme DogShelter -configuration Release -sdk iphonesimulator") ? 0 : 1);
    ' "$rn_debug"; then
  ok "a React Native Debug build without main.jsbundle is refused with the Release Simulator build command"
else
  bad "a React Native Debug build was accepted as the proof artifact" \
    "rc=$rn_debug_rc $(node -e 'const g=JSON.parse(process.argv[1]).gates.find(g=>g.id==="I5");process.stdout.write(`${g?.status}: ${g?.detail}`)' "$rn_debug")"
fi
printf 'RNIterableAPI\n' > "$APP_PATH/main.jsbundle"
cp "$APP_PATH/main.jsbundle" "$STATE/sim-app/main.jsbundle"
rn_release="$(run_verify 2>/dev/null)"
rn_release_rc=$?
if [[ "$rn_release_rc" -eq 0 && "$(json_value "$rn_release" verdict)" == done ]]; then
  ok "a React Native Release build with its embedded main.jsbundle completes the Simulator proof"
else
  bad "a React Native Release build was not accepted" "rc=$rn_release_rc $(json_value "$rn_release" next.summary)"
fi
rm "$STATE/sim-app/main.jsbundle"
cp "$WORKSPACE/proof-target.json" "$ROOT/proof-target.with-app-path"
node -e '
  const fs=require("fs"), path=process.argv[1];
  const t=JSON.parse(fs.readFileSync(path,"utf8"));
  Object.assign(t,{app_path:"",proof_mode:"behavioral"});
  fs.writeFileSync(path,JSON.stringify(t,null,2)+"\n",{mode:0o600});
' "$WORKSPACE/proof-target.json"
installed_gate() {
  node -e '
    const g=JSON.parse(process.argv[1]).gates.find(g=>g.id==="I6");
    process.stdout.write(`${g?.status}: ${g?.detail}`);
  ' "$1"
}
rn_installed_debug="$(installed_gate "$(run_verify 2>/dev/null)")"
[[ "$rn_installed_debug" == red:*'installed react-native app has no embedded main.jsbundle'*'-configuration Release -sdk iphonesimulator'* ]] &&
  ok "an installed React Native Debug build is refused with the Release Simulator build command" ||
  bad "an installed React Native Debug build was accepted" "$rn_installed_debug"
printf 'RNIterableAPI\n' > "$STATE/sim-app/main.jsbundle"
rn_installed_release="$(installed_gate "$(run_verify 2>/dev/null)")"
[[ "$rn_installed_release" == green:*'IterableSDKResources.bundle and RNIterableAPI in main.jsbundle; aps-environment=development'* ]] &&
  ok "a fresh installed React Native Release build with the SDK, bundle marker and entitlement passes" ||
  bad "an installed React Native Release build was refused" "$rn_installed_release"
printf 'bundle without the package\n' > "$STATE/sim-app/main.jsbundle"
rn_installed_no_js_sdk="$(run_verify 2>/dev/null)"
[[ "$(installed_gate "$rn_installed_no_js_sdk")" == "red: "installed_app_without_sdk:*'never references RNIterableAPI'* &&
    "$(json_value "$rn_installed_no_js_sdk" next.kind)" == build_app ]] &&
  ok "an installed React Native app whose bundle lacks the Iterable package is refused" ||
  bad "an installed React Native bundle without the Iterable package was accepted" "$(installed_gate "$rn_installed_no_js_sdk")"
printf 'RNIterableAPI\n' > "$STATE/sim-app/main.jsbundle"
touch -t 202601011200 "$STATE/sim-app/main.jsbundle"
printf 'Iterable.initialize(key, config)\n' > "$ROOT/app/App.tsx"
rn_installed_stale_js="$(installed_gate "$(run_verify 2>/dev/null)")"
rm "$ROOT/app/App.tsx"
[[ "$rn_installed_stale_js" == "red: "installed_app_older_than_source:*'main.jsbundle was built at 2026-01-01'*"$ROOT/app/App.tsx changed at"* ]] &&
  ok "an installed React Native bundle older than a JavaScript edit is refused, naming the file and both times" ||
  bad "a stale installed React Native bundle was accepted" "$rn_installed_stale_js"
rm "$STATE/sim-app/main.jsbundle"
rm -rf "$ROOT/app/package.json" "$ROOT/app/ios" "$APP_PATH/main.jsbundle"
native_installed="$(installed_gate "$(run_verify 2>/dev/null)")"
[[ "$native_installed" == green:*'Iterable SDK via IterableSDKResources.bundle; aps-environment=development'* &&
    "$native_installed" != *RNIterableAPI* ]] &&
  ok "an installed native app with the SDK passes without any React Native rule" ||
  bad "an installed native app was held to the React Native rule" "$native_installed"
mv "$STATE/sim-app/IterableSDKResources.bundle" "$STATE/sim-app.sdk"
no_sdk="$(run_verify 2>/dev/null)"
mv "$STATE/sim-app.sdk" "$STATE/sim-app/IterableSDKResources.bundle"
[[ "$(installed_gate "$no_sdk")" == "red: "installed_app_without_sdk:*'no Iterable iOS SDK'*'never CODE_SIGNING_ALLOWED=NO'*'ios-prepare-proof restart --confirm --app-path'* &&
    "$(json_value "$no_sdk" next.kind)" == build_app ]] &&
  ok "an installed app without the Iterable SDK is red with the rebuild-and-record fix" ||
  bad "an installed app without the Iterable SDK was accepted" "$(installed_gate "$no_sdk")"
touch "$STATE/simulator-missing-entitlements"
no_aps="$(installed_gate "$(run_verify 2>/dev/null)")"
rm "$STATE/simulator-missing-entitlements"
[[ "$no_aps" == "red: "installed_app_missing_aps_environment:*'no aps-environment entitlement'*'CODE_SIGNING_ALLOWED=NO'* ]] &&
  ok "an installed app missing aps-environment is red" ||
  bad "an installed app without aps-environment was accepted" "$no_aps"
printf 'name: DogShelter\n' > "$ROOT/app/project.yml"
mkdir -p "$ROOT/app/DogShelter"
touch -t 202601011200 "$STATE/sim-app/DogShelter"
printf 'IterableAPI.initialize(apiKey: key)\n' > "$ROOT/app/DogShelter/AppDelegate.swift"
stale_native="$(installed_gate "$(run_verify 2>/dev/null)")"
rm -rf "$ROOT/app/project.yml" "$ROOT/app/DogShelter"
touch "$STATE/sim-app/DogShelter"
[[ "$stale_native" == "red: "installed_app_older_than_source:*'DogShelter was built at 2026-01-01'*"$ROOT/app/DogShelter/AppDelegate.swift changed at"* ]] &&
  ok "an installed app older than a source edit is red, naming the file and both times" ||
  bad "an installed app older than its source was accepted" "$stale_native"
cp "$ROOT/proof-target.with-app-path" "$WORKSPACE/proof-target.json"
chmod 600 "$WORKSPACE/proof-target.json"
printf 'an older executable\n' > "$STATE/sim-app/DogShelter"
differs="$(run_verify 2>/dev/null)"
printf 'same executable\n' > "$STATE/sim-app/DogShelter"
[[ "$(installed_gate "$differs")" == "red: "installed_app_differs_from_recorded_build:*'not byte-identical'* &&
    "$(json_value "$differs" next.kind)" == install_app ]] &&
  ok "an installed app that differs from the recorded build is red and reinstalls the recorded one" ||
  bad "an installed app that differs from the recorded build was accepted" "$(installed_gate "$differs")"
printf 'name: DogShelter\n' > "$ROOT/app/project.yml"
mkdir -p "$ROOT/app/DogShelter"
touch -t 202601011200 "$STATE/sim-app/DogShelter" "$APP_PATH/DogShelter"
printf 'IterableAPI.initialize(apiKey: key)\n' > "$ROOT/app/DogShelter/AppDelegate.swift"
recorded_stale="$(run_verify 2>/dev/null)"
rm -rf "$ROOT/app/project.yml" "$ROOT/app/DogShelter"
touch "$STATE/sim-app/DogShelter" "$APP_PATH/DogShelter"
[[ "$(installed_gate "$recorded_stale")" == "red: "installed_app_older_than_source:* &&
    "$(json_value "$recorded_stale" next.kind)" == build_app ]] &&
  ok "a stale recorded build asks for a rebuild, not a reinstall of the same build" ||
  bad "a stale recorded build was routed to reinstall" "$(json_value "$recorded_stale" next.kind) $(installed_gate "$recorded_stale")"
mv "$APP_PATH/IterableSDKResources.bundle" "$STATE/artifact.sdk"
artifact_no_sdk="$(run_verify 2>/dev/null)"
mv "$STATE/artifact.sdk" "$APP_PATH/IterableSDKResources.bundle"
node -e '
  const v=JSON.parse(process.argv[1]), g=v.gates.find(g=>g.id==="I5");
  process.exit(g?.status==="red" && g.detail.includes("recorded .app has no Iterable iOS SDK") &&
    g.detail.includes("CODE_SIGNING_ALLOWED=NO") && v.gates.find(g=>g.id==="I6")?.status==="blocked" ? 0 : 1);
' "$artifact_no_sdk" &&
  ok "a recorded artifact without the Iterable SDK is refused before install" ||
  bad "a recorded artifact without the Iterable SDK was accepted"

touch "$STATE/simulator-missing-entitlements"
simulator_without_entitlements="$(run_verify 2>/dev/null)"
simulator_without_entitlements_rc=$?
rm "$STATE/simulator-missing-entitlements"
if [[ "$simulator_without_entitlements_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(candidate=>candidate.id==="I5");
      process.exit(
        gate?.status==="red" &&
        gate.detail.includes("__TEXT,__entitlements") ? 0 : 1
      );
    ' "$simulator_without_entitlements"; then
  ok "Simulator proof reads Xcode simulated entitlements instead of the ad-hoc signature"
else
  bad "a Simulator artifact without embedded simulated entitlements was accepted"
fi

touch "$STATE/simulator-wrong-application-identifier"
simulator_wrong_identifier="$(run_verify 2>/dev/null)"
simulator_wrong_identifier_rc=$?
rm "$STATE/simulator-wrong-application-identifier"
if [[ "$simulator_wrong_identifier_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(candidate=>candidate.id==="I5");
      process.exit(
        gate?.status==="red" &&
        gate.detail.includes("does not match") ? 0 : 1
      );
    ' "$simulator_wrong_identifier"; then
  ok "Simulator proof requires its simulated application identifier to match the bundle"
else
  bad "a mismatched Simulator application identifier was accepted" \
    "$(node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(candidate=>candidate.id==="I5");
      process.stdout.write(`rc=${process.argv[2]}; I5=${gate?.status}: ${gate?.detail}; next=${v.next?.kind}`);
    ' "$simulator_wrong_identifier" "$simulator_wrong_identifier_rc")"
fi

node -e '
  const fs=require("fs"), path=process.argv[1];
  const target=JSON.parse(fs.readFileSync(path,"utf8"));
  target.environment="production";
  target.apns_environment="production";
  target.production_follow_up_required=false;
  fs.writeFileSync(path,JSON.stringify(target,null,2)+"\n");
' "$WORKSPACE/proof-target.json"
simulator_production="$(run_verify 2>/dev/null)"
simulator_production_rc=$?
if [[ "$simulator_production_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I4")?.status==="red" ? 0 : 1);
    ' "$simulator_production"; then
  ok "Simulator proof is rejected for the production APNs environment"
else
  bad "a Simulator was allowed to stand in for production APNs proof"
fi
node -e '
  const fs=require("fs"), path=process.argv[1];
  const target=JSON.parse(fs.readFileSync(path,"utf8"));
  target.environment="development";
  target.apns_environment="sandbox";
  target.production_follow_up_required=true;
  fs.writeFileSync(path,JSON.stringify(target,null,2)+"\n");
' "$WORKSPACE/proof-target.json"

rm "$STATE/use-simulator" "$STATE/simulator-artifact"
node -e '
  const fs=require("fs");
  const scopePath=process.argv[1], targetPath=process.argv[2];
  const scope=JSON.parse(fs.readFileSync(scopePath,"utf8"));
  if (!scope.features.includes("push-notifications")) {
    scope.features.push("push-notifications");
  }
  fs.writeFileSync(scopePath,JSON.stringify(scope,null,2)+"\n");
  const target=JSON.parse(fs.readFileSync(targetPath,"utf8"));
  target.device="00008101-TESTDEVICE";
  target.device_kind="physical";
  target.simulator_runtime=null;
  fs.writeFileSync(targetPath,JSON.stringify(target,null,2)+"\n");
' "$WORKSPACE/scope.json" "$WORKSPACE/proof-target.json"
for receipt in "$WORKSPACE/launches/initial.json" \
  "$WORKSPACE/launches/restore.json"; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="00008101-TESTDEVICE";
    value.device_kind="physical";
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt"
done
for receipt in "$WORKSPACE/sends/development"/*.json; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="00008101-TESTDEVICE";
    value.device_kind="physical";
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt"
done
for receipt in "$WORKSPACE/proof/development"/*.json; do
  node -e '
    const fs=require("fs"), path=process.argv[1];
    const value=JSON.parse(fs.readFileSync(path,"utf8"));
    value.device="00008101-TESTDEVICE";
    value.device_kind="physical";
    value.observed_at=process.argv[2];
    fs.writeFileSync(path,JSON.stringify(value)+"\n");
  ' "$receipt" "$OBSERVED_AT"
done

cp "$STATE/runtime-proof.jsonl" "$STATE/runtime-proof.valid.jsonl"
node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").trim().split("\n").map(JSON.parse);
  for (const row of rows) {
    if (row.marker_sha256 && row.event.includes("notification_") ||
        row.event==="iterable_push_forward_invoked") {
      delete row.delivery_nonce_sha256;
    }
  }
  fs.writeFileSync(p,rows.map(JSON.stringify).join("\n")+"\n");
' "$STATE/runtime-proof.jsonl"
injected_marker="$(run_verify 2>/dev/null)"
injected_marker_rc=$?
if [[ "$injected_marker_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I15")?.status==="red" ? 0 : 1);
    ' "$injected_marker"; then
  ok "a copied marker injected without the sender-only nonce cannot prove delivery"
else
  bad "a local marker injection could satisfy the real APNs proof"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").trim().split("\n");
  const init=rows.findIndex(row=>row.includes("\"sdk_initialize_returned\""));
  const identity=rows.findIndex(row=>
    row.includes("\"iterable_identity_set_invoked\"") &&
    row.includes("\"source\":\"login\"")
  );
  [rows[init],rows[identity]]=[rows[identity],rows[init]];
  fs.writeFileSync(p,rows.join("\n")+"\n");
' "$STATE/runtime-proof.jsonl"
wrong_order="$(run_verify 2>/dev/null)"
wrong_order_rc=$?
if [[ "$wrong_order_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I7")?.status==="red" ? 0 : 1);
    ' "$wrong_order"; then
  ok "runtime facts cannot pass when identity precedes SDK initialization"
else
  bad "out-of-order runtime facts produced a false green"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").trim().split("\n").map(JSON.parse);
  const settingsIndex=rows.findIndex(row=>row.event==="notification_settings_observed");
  const [settings]=rows.splice(settingsIndex,1);
  const registerIndex=rows.findIndex(row=>row.event==="iterable_register_invoked");
  rows.splice(registerIndex+1,0,settings);
  fs.writeFileSync(p,rows.map(JSON.stringify).join("\n")+"\n");
' "$STATE/runtime-proof.jsonl"
settings_after_registration="$(run_verify 2>/dev/null)"
settings_after_registration_rc=$?
if [[ "$settings_after_registration_rc" -eq 0 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I7")?.status==="green" ? 0 : 1);
    ' "$settings_after_registration"; then
  ok "existing notification authorization may be observed after token registration"
else
  bad "verifier imposed an invalid permission-before-token ordering"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").trim().split("\n").map(JSON.parse);
  const forwarded=rows.find(row=>row.event==="iterable_push_forward_invoked");
  forwarded.process_launch_id="launch-other";
  fs.writeFileSync(p,rows.map(JSON.stringify).join("\n")+"\n");
' "$STATE/runtime-proof.jsonl"
cross_process_push="$(run_verify 2>/dev/null)"
cross_process_push_rc=$?
if [[ "$cross_process_push_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I15")?.status==="red" ? 0 : 1);
    ' "$cross_process_push"; then
  ok "push-open proof requires one current process"
else
  bad "cross-process push callbacks produced a false green"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").trim().split("\n").map(JSON.parse);
  const completed=rows.find(row=>row.event==="notification_response_completion");
  completed.recorded_at=process.argv[2];
  fs.writeFileSync(p,rows.map(JSON.stringify).join("\n")+"\n");
' "$STATE/runtime-proof.jsonl" "$PUSH_1"
reordered_push="$(run_verify 2>/dev/null)"
reordered_push_rc=$?
if [[ "$reordered_push_rc" -eq 20 ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I15")?.status==="red" ? 0 : 1);
    ' "$reordered_push"; then
  ok "push-open proof requires callback, forwarding, and completion order"
else
  bad "reordered push callbacks produced a false green"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const rows=fs.readFileSync(p,"utf8").split("\n")
    .filter(row=>!row.includes("\"iterable_logout_callback\""));
  fs.writeFileSync(p,rows.join("\n"));
' "$STATE/runtime-proof.jsonl"
missing_logout_callback="$(run_verify 2>/dev/null)"
missing_logout_callback_rc=$?
if [[ "$missing_logout_callback_rc" -eq 10 &&
      "$(json_value "$missing_logout_callback" next.kind)" == review_instrumentation ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(
        v.gates.find(g=>g.id==="I16")?.status==="pending" &&
        v.next.summary.includes("Do not repeat") ? 0 : 1
      );
    ' "$missing_logout_callback"; then
  ok "missing logout callbacks do not cause a repeated logout request"
else
  bad "missing logout completion produced a false green" \
    "$(node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(candidate=>candidate.id==="I16");
      process.stdout.write(
        `rc=${process.argv[2]}; mode=${v.proof_mode}; I16=${gate?.status}: ${gate?.detail}; next=${v.next?.kind}`
      );
    ' "$missing_logout_callback" "$missing_logout_callback_rc")"
fi
cp "$STATE/runtime-proof.valid.jsonl" "$STATE/runtime-proof.jsonl"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const v=JSON.parse(fs.readFileSync(p,"utf8"));
  v.features.push("deep-linking");
  fs.writeFileSync(p,JSON.stringify(v,null,2)+"\n");
' "$WORKSPACE/scope.json"
feature_outstanding="$(run_verify 2>/dev/null)"
feature_outstanding_rc=$?
if [[ "$feature_outstanding_rc" -eq 0 &&
      "$(json_value "$feature_outstanding" verdict)" == done &&
      "$(json_value "$feature_outstanding" integration_complete)" == false ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.feature_evidence_required.includes("deep-linking") ? 0 : 1);
    ' "$feature_outstanding"; then
  ok "a green core verifier cannot silently complete an unproved selected feature"
else
  bad "selected feature evidence disappeared behind a green core verifier"
fi
node -e '
  const fs=require("fs"), p=process.argv[1];
  const v=JSON.parse(fs.readFileSync(p,"utf8"));
  v.features=v.features.filter(feature=>feature!=="deep-linking");
  fs.writeFileSync(p,JSON.stringify(v,null,2)+"\n");
' "$WORKSPACE/scope.json"

node -e '
  const fs=require("fs"), p=process.argv[1];
  const v=JSON.parse(fs.readFileSync(p,"utf8"));
  v.observed_at=process.argv[2];
  fs.writeFileSync(p,JSON.stringify(v)+"\n");
' "$WORKSPACE/proof/development/user-targeted.json" "$STALE_AT"
stale="$(run_verify 2>/dev/null)"
stale_rc=$?
if [[ "$stale_rc" -eq 20 &&
      "$(json_value "$stale" push_proven)" == false ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      process.exit(v.gates.find(g=>g.id==="I14")?.status!=="green" ? 0 : 1);
    ' "$stale"; then
  ok "a stale delivery receipt cannot satisfy the current proof run"
else
  bad "stale physical evidence became a false green"
fi

env \
  IOS_AGENT_DEVICE="$FAKEBIN/agent-device" \
  IOS_VERIFY_STATE="$STATE" \
  IOS_WORKSPACE="$WORKSPACE" \
  bin/ios-observe delivery \
    --kind direct \
    --timeout 1000 >/dev/null
observe_rc=$?
if [[ "$observe_rc" -eq 0 &&
      "$(stat -f '%Lp' "$WORKSPACE/proof/development/direct.json")" == 600 ]] &&
    grep -q 'open com.apple.springboard' "$STATE/agent-device-calls" &&
    grep -q 'wait text ITBL-IOS-DIRECT-A1B2C3' "$STATE/agent-device-calls" &&
    ! grep -Eq '(^| )(press|click|fill|type)( |$)' "$STATE/agent-device-calls"; then
  ok "the observation actor reads one marker without operating the app or notification"
else
  bad "physical observation did not preserve the read-only interaction boundary"
fi

grep -En 'templates/push|push/proof|campaigns/trigger|registerDeviceToken.*token' \
  bin/ios-verify bin/ios-observe bin/ios-notify-read.js >/dev/null
send_path_rc=$?
if [[ "$send_path_rc" -eq 1 ]]; then
  ok "neither verifier nor observer contains a push-sending path"
else
  bad "a verification actor can manufacture its own push"
fi

touch "$STATE/use-simulator" "$STATE/simulator-artifact"
node -e '
  const fs=require("fs"), crypto=require("crypto");
  const [targetPath,sendsDir,proofDir]=process.argv.slice(1);
  const sha=v=>crypto.createHash("sha256").update(String(v)).digest("hex");
  const t=JSON.parse(fs.readFileSync(targetPath,"utf8"));
  Object.assign(t,{proof_mode:"behavioral",device:"SIM-DEVICE-1",device_kind:"simulator",
    simulator_runtime:"com.apple.CoreSimulator.SimRuntime.iOS-18-0",environment:"development",apns_environment:"sandbox"});
  fs.writeFileSync(targetPath,JSON.stringify(t,null,2)+"\n",{mode:0o600});
  fs.writeFileSync(`${sendsDir}/user-targeted.json`,JSON.stringify({
    contract:4,state:"sent",sent:true,kind:"user-targeted",source:"iterable-api-template-proof",sender:"ios-prove",
    bundle_id:t.bundle_id,device:t.device,device_kind:"simulator",environment:"development",run_id:t.run_id,
    marker_sha256:sha(t.markers.user_targeted),recipient_sha256:sha(t.identity),template_id:424242,
    delivery_nonce_sha256:sha("not-a-delivered-nonce"),payload_sha256:sha("p"),
    prepared_at:new Date().toISOString(),sent_at:new Date().toISOString(),http_code:"200"
  },null,2)+"\n",{mode:0o600});
  fs.writeFileSync(`${proofDir}/user-targeted.json`,JSON.stringify({
    observed:true,contract:3,kind:"user-targeted",bundle_id:t.bundle_id,device:t.device,device_kind:"simulator",
    environment:"development",run_id:t.run_id,observed_at:new Date().toISOString(),
    observer:"ios-prove simulator store and log",evidence:{apns_received:true,os_stored:true,os_displayed:true},
    record_digest:"AAAA-BBBB",nonce_sha256:sha("not-a-delivered-nonce")
  },null,2)+"\n",{mode:0o600});
' "$WORKSPACE/proof-target.json" "$WORKSPACE/sends/development" "$WORKSPACE/proof/development"
sim_standard="$(run_verify 2>/dev/null)"
if [[ "$(json_value "$sim_standard" verdict)" != done ]] &&
    node -e '
      const v=JSON.parse(process.argv[1]);
      const gate=v.gates.find(g=>g.id==="I14");
      process.exit(gate && gate.status!=="green" && gate.status!=="blocked" ? 0 : 1);
    ' "$sim_standard"; then
  ok "a standard Simulator run with a send and a receipt but no Simulator evidence is not proved"
else
  bad "the verifier proved a Simulator push from a receipt alone" \
    "$(json_value "$sim_standard" verdict) $(json_value "$sim_standard" next.summary)"
fi

((FAILED)) && exit 1
exit 0
