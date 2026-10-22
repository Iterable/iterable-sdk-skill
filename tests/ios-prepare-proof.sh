#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; [[ $# -lt 2 ]] || printf '  %s\n' "$2"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-prepare-proof-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-prepare-proof-test.*|/private/tmp/iterable-ios-prepare-proof-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
APP_PATH="$STATE/SampleShop.app"
mkdir -p "$FAKEBIN" "$STATE" "$WORKSPACE" "$APP_PATH"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{}}\n'
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[{"identifier":"00008101-PROOFDEVICE","name":"Proof iPhone"}]}}\n'
else
  exit 2
fi
EOF

cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
cat >/dev/null
printf '{"msg":"No user exists"}\n400\n'
EOF
chmod +x "$FAKEBIN/xcrun" "$FAKEBIN/curl"

SERVER_KEY="server-proof-key"
SERVER_HASH="$(printf '%s' "$SERVER_KEY" | shasum -a 256 | awk '{print $1}')"
cat > "$WORKSPACE/scope.json" <<'EOF'
{
  "features": [
    "event-tracking",
    "push-notifications",
    "sdk-initialization",
    "user-profiles"
  ],
  "identity_mode": "email",
  "data_region": "US",
  "jwt_enabled": false
}
EOF
cat > "$WORKSPACE/target.json" <<'EOF'
{
  "bundle_id": "com.example.sampleshop",
  "name": "Sample Shop"
}
EOF
cat > "$WORKSPACE/.env" <<EOF
ITERABLE_SERVER_KEY=$SERVER_KEY
EOF
cat > "$WORKSPACE/server-validation.json" <<EOF
{
  "valid": true,
  "key_sha256": "$SERVER_HASH",
  "data_region": "US",
  "classification": "authenticated-server-key"
}
EOF
chmod 600 \
  "$WORKSPACE/scope.json" \
  "$WORKSPACE/target.json" \
  "$WORKSPACE/.env" \
  "$WORKSPACE/server-validation.json"

run_prepare() {
  env \
    PATH="$FAKEBIN:$PATH" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-prepare-proof "$@"
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

initial="$(run_prepare status)"
if [[ "$(json_value "$initial" tool)" == iterable-ios-proof-setup &&
      "$(json_value "$initial" contract)" == 2 &&
      "$(json_value "$initial" proposed.proof_mode)" == behavioral &&
      "$(json_value "$initial" next.kind)" == proof_environment &&
      "$(json_value "$initial" next.command)" == \
        *"/ios-prepare-proof status" ]]; then
  ok "verify-only actor automatically starts behavioral proof without a mode question"
else
  bad "verify-only actor exposed an internal proof-mode decision"
fi

instrumented="$(
  run_prepare answer --field proof-mode --value instrumented
)"
if [[ "$(json_value "$instrumented" proposed.proof_mode)" == instrumented ]]; then
  ok "instrumented proof remains available as an explicit diagnostic override"
else
  bad "explicit instrumented diagnostics could not be selected"
fi
run_prepare answer --field proof-mode --clear >/dev/null
run_prepare answer --field environment --value development >/dev/null
run_prepare answer --field identity --value proof-a@example.com >/dev/null
run_prepare answer --field switch-identity --value proof-b@example.com >/dev/null
run_prepare answer --field device --value 00008101-PROOFDEVICE >/dev/null
app_question="$(
  run_prepare answer --field app-path --value "$APP_PATH"
)"
run_prepare answer --field profile-field --value favoriteDogCount=1 >/dev/null
run_prepare answer --field event --value dogFavorited=1 >/dev/null
run_prepare answer --field tap-expect --value 'Dog list' >/dev/null
confirmation="$(
  run_prepare answer --field logout-expect --value 'Signed out, then empty User B favorites'
)"
if [[ "$(json_value "$app_question" proposed.proof_mode)" == behavioral &&
      "$(json_value "$confirmation" next.kind)" == confirm_proof &&
      "$(json_value "$confirmation" next.question.options.0.commands.0)" == \
        *"/ios-prepare-proof start --confirm" ]]; then
  ok "proof answers remain inside the verify-only actor"
else
  bad "proof questions escaped into the general provisioning flow"
fi

started="$(run_prepare start --confirm)"
first_target="$(cat "$WORKSPACE/proof-target.json")"
first_run="$(json_value "$first_target" run_id)"
first_identity="$(json_value "$first_target" identity)"
first_marker="$(json_value "$first_target" markers.user_targeted)"
if [[ "$(json_value "$started" proof.valid)" == true &&
      "$(json_value "$started" proof.proof_mode)" == behavioral &&
      "$(json_value "$first_target" proof_mode)" == behavioral &&
      "$(stat -f '%Lp' "$WORKSPACE/proof-target.json")" == 600 &&
      ! -e "$WORKSPACE/proof-discovery.json" ]]; then
  ok "start records a secure behavioral proof target"
else
  bad "start did not record proof mode and secure run state"
fi

mkdir -p \
  "$WORKSPACE/launches" \
  "$WORKSPACE/sends/development" \
  "$WORKSPACE/proof/development" \
  "$WORKSPACE/observations"
printf '{}\n' > "$WORKSPACE/launches/initial.json"
printf '{}\n' > "$WORKSPACE/sends/development/direct.json"
printf '{}\n' > "$WORKSPACE/proof/development/direct.json"
printf '{}\n' > "$WORKSPACE/observations/legacy.json"
chmod 700 \
  "$WORKSPACE/launches" \
  "$WORKSPACE/sends" \
  "$WORKSPACE/sends/development" \
  "$WORKSPACE/proof" \
  "$WORKSPACE/proof/development" \
  "$WORKSPACE/observations"
chmod 600 \
  "$WORKSPACE/launches/initial.json" \
  "$WORKSPACE/sends/development/direct.json" \
  "$WORKSPACE/proof/development/direct.json" \
  "$WORKSPACE/observations/legacy.json"

restarted="$(run_prepare restart --confirm)"
second_target="$(cat "$WORKSPACE/proof-target.json")"
second_run="$(json_value "$second_target" run_id)"
second_identity="$(json_value "$second_target" identity)"
second_marker="$(json_value "$second_target" markers.user_targeted)"
archive_dir="$(find "$WORKSPACE/archive" -mindepth 1 -maxdepth 1 -type d | head -1)"
if [[ "$(json_value "$restarted" proof.valid)" == true &&
      "$(json_value "$second_target" proof_mode)" == behavioral &&
      "$second_run" != "$first_run" &&
      "$second_identity" == "$first_identity" &&
      "$second_marker" != "$first_marker" &&
      "$(json_value "$second_target" switch_identity)" == "" &&
      "$(json_value "$second_target" profile_fields.length)" == 0 &&
      "$(json_value "$second_target" events.length)" == 0 &&
      ! -e "$WORKSPACE/launches" &&
      ! -e "$WORKSPACE/sends" &&
      ! -e "$WORKSPACE/proof" &&
      ! -e "$WORKSPACE/observations" &&
      -n "$archive_dir" &&
      "$(stat -f '%Lp' "$archive_dir")" == 700 &&
      "$(json_value "$(cat "$archive_dir/proof-target.json")" run_id)" == "$first_run" &&
      -f "$archive_dir/launches/initial.json" &&
      -f "$archive_dir/sends/development/direct.json" &&
      -f "$archive_dir/proof/development/direct.json" &&
      -f "$archive_dir/observations/legacy.json" &&
      "$(stat -f '%Lp' "$WORKSPACE/proof-target.json")" == 600 ]]; then
  ok "restart archives prior evidence while rotating only active run-scoped state"
else
  bad "restart mixed the old proof run with the fresh run"
fi

run_prepare start --confirm >"$ROOT/start-again.out" 2>"$ROOT/start-again.err"
start_again_rc=$?
if [[ "$start_again_rc" -eq 2 ]] &&
    grep -q "ios-prepare-proof restart --confirm" "$ROOT/start-again.err"; then
  ok "start refuses to overwrite an active proof run"
else
  bad "start could overwrite an active proof run without restart"
fi

existing="$(run_prepare status)"
if [[ "$(json_value "$existing" next.kind)" == existing_proof &&
      "$(json_value "$existing" next.question.options.0.commands.0)" == *"/ios-verify status" &&
      "$(json_value "$existing" next.question.options.1.commands.0)" == *"/ios-prepare-proof restart --confirm" ]]; then
  ok "status offers keep or restart for an existing run instead of a start that dies"
else
  bad "status ignored the existing proof run"
fi

SIMBIN="$ROOT/simbin"
SIMSPACE="$ROOT/simapp/.iterable/ios"
mkdir -p "$SIMBIN" "$SIMSPACE"
cat > "$SIMBIN/xcrun" <<'XEOF'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[{"udid":"SIM-PREP-1","name":"iPhone 17","state":"Booted","isAvailable":true}]}}\n'
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[]}}\n'
else
  exit 2
fi
XEOF
printf '#!/usr/bin/env bash\nprintf "Xcode 27.0\\nBuild version 27A1\\n"\n' > "$SIMBIN/xcodebuild"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == -productVersion ]] && printf "26.7.1\\n"\n' > "$SIMBIN/sw_vers"
printf '#!/usr/bin/env bash\n[[ "${1:-}" == -m ]] && printf "arm64\\n"\n' > "$SIMBIN/uname"
chmod +x "$SIMBIN"/*
for file in scope.json target.json .env server-validation.json; do
  cp "$WORKSPACE/$file" "$SIMSPACE/$file"
done
chmod 600 "$SIMSPACE"/scope.json "$SIMSPACE"/target.json "$SIMSPACE"/.env "$SIMSPACE"/server-validation.json
run_sim_prepare() {
  env PATH="$SIMBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$SIMSPACE" bin/ios-prepare-proof "$@"
}
sim_status="$(run_sim_prepare status)"
sim_command="$(json_value "$sim_status" next.question.free_text.command)"
if [[ "$(json_value "$sim_status" next.kind)" == confirm_proof &&
      "$(json_value "$sim_status" proposed.device)" == SIM-PREP-1 &&
      "$(json_value "$sim_status" proposed.environment)" == development &&
      "$sim_command" == *"start --confirm --identity '{{answer}}'" ]]; then
  ok "one booted Simulator is prefilled, development is derived, and identity starts the run"
else
  bad "the Simulator proof still asked for environment or device" \
    "kind=$(json_value "$sim_status" next.kind) device=$(json_value "$sim_status" proposed.device) env=$(json_value "$sim_status" proposed.environment)"
fi
sim_started="$(env PATH="$SIMBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$SIMSPACE" \
  bash -c "${sim_command//\{\{answer\}\}/proof-a@example.com}")"
sim_target="$(cat "$SIMSPACE/proof-target.json" 2>/dev/null)"
if [[ "$(json_value "$sim_started" next.command)" == *"/ios-prove --confirm" &&
      "$(json_value "$sim_target" environment)" == development &&
      "$(json_value "$sim_target" device_kind)" == simulator &&
      "$(json_value "$sim_target" identity)" == proof-a@example.com &&
      "$(json_value "$sim_target" markers.user_targeted)" == ITBL-IOS-PROOF-* &&
      "$(json_value "$sim_target" app_path)" == "" ]]; then
  ok "a standard Simulator run starts from one identity answer and points at ios-prove"
else
  bad "the one-answer Simulator start did not record a neutral development run" "$sim_started"
fi

mkdir -p "$ROOT/Fresh.app" "$ROOT/Recorded.app"
fresh_app="$(cd "$ROOT/Fresh.app" && pwd -P)"
recorded_app="$(cd "$ROOT/Recorded.app" && pwd -P)"
run_sim_prepare restart --confirm --app-path "$ROOT/Fresh.app" >/dev/null 2>&1
rebound="$(json_value "$(cat "$SIMSPACE/proof-target.json")" app_path)"
[[ "$rebound" == "$fresh_app" ]] &&
  ok "restart --app-path binds a fresh build to a run started without one" ||
  bad "restart ignored --app-path" "app_path=$rebound"

node -e '
  const fs=require("fs"), p=process.argv[1], v=JSON.parse(fs.readFileSync(p,"utf8"));
  v.app_path=process.argv[2];
  fs.writeFileSync(p,JSON.stringify(v,null,2)+"\n",{mode:0o600});
' "$SIMSPACE/proof-target.json" "$recorded_app"
run_sim_prepare restart --confirm >/dev/null 2>&1
kept="$(json_value "$(cat "$SIMSPACE/proof-target.json")" app_path)"
[[ "$kept" == "$recorded_app" ]] &&
  ok "restart without --app-path keeps the run's recorded app path" ||
  bad "restart without --app-path dropped the recorded app path" "app_path=$kept"

before_missing="$(cat "$SIMSPACE/proof-target.json")"
archives_before="$(find "$SIMSPACE/archive" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
run_sim_prepare restart --confirm --app-path "$ROOT/Missing.app" >/dev/null 2>"$ROOT/missing.err"
missing_rc=$?
archives_after="$(find "$SIMSPACE/archive" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
if [[ "$missing_rc" -ne 0 && "$(cat "$SIMSPACE/proof-target.json")" == "$before_missing" &&
      "$archives_after" == "$archives_before" ]] &&
    grep -q 'must name an existing .app bundle' "$ROOT/missing.err"; then
  ok "restart refuses an --app-path that is not an existing .app before archiving anything"
else
  bad "restart accepted a missing .app or archived the run first" \
    "rc=$missing_rc archives=$archives_before->$archives_after $(cat "$ROOT/missing.err")"
fi

MINBIN="$ROOT/minbin"
MINAPP="$ROOT/minapp"
MINSPACE="$MINAPP/.iterable/ios"
mkdir -p "$MINBIN" "$MINSPACE"
cat > "$MINBIN/xcrun" <<'XEOF'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[{"udid":"SIM-IOS26","name":"iPhone 17","state":"Booted","isAvailable":true}],"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"SIM-IOS27","name":"iPhone 17e","state":"Booted","isAvailable":true}]}}\n'
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[]}}\n'
else
  exit 2
fi
XEOF
cp "$SIMBIN/xcodebuild" "$SIMBIN/sw_vers" "$SIMBIN/uname" "$MINBIN/"
chmod +x "$MINBIN"/*
for file in scope.json target.json .env server-validation.json; do
  cp "$WORKSPACE/$file" "$MINSPACE/$file"
done
chmod 600 "$MINSPACE"/scope.json "$MINSPACE"/target.json "$MINSPACE"/.env "$MINSPACE"/server-validation.json
printf 'name: SampleApp\noptions:\n  deploymentTarget:\n    iOS: "27.0"\ntargets:\n  SampleApp:\n    platform: iOS\n' > "$MINAPP/project.yml"
min_status="$(env PATH="$MINBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$MINSPACE" bin/ios-prepare-proof status)"
if [[ "$(json_value "$min_status" proposed.device)" == SIM-IOS27 ]]; then
  ok "a deployment target of iOS 27 leaves only the iOS 27 Simulator, which is prefilled"
else
  bad "a Simulator below the app's deployment target was offered" "device=$(json_value "$min_status" proposed.device) kind=$(json_value "$min_status" next.kind)"
fi
rm "$MINAPP/project.yml"
printf 'name: SampleApp\ntargets:\n  SampleApp:\n    platform: iOS\n' > "$MINAPP/project.yml"
open_status="$(env PATH="$MINBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$MINSPACE" bin/ios-prepare-proof status)"
if [[ "$(json_value "$open_status" next.kind)" == proof_device &&
      "$(json_value "$open_status" proposed.device)" == "" ]]; then
  ok "without a known deployment target both booted Simulators stay on offer"
else
  bad "the device filter applied without a deployment target" "$(json_value "$open_status" next.kind)"
fi

# The live trial's proof defaulted to the installed copy while that copy was the
# pre-Iterable baseline. A build the workspace knows about is offered first instead.
ARTBIN="$ROOT/artbin"
ARTAPP="$ROOT/artapp"
ARTSPACE="$ARTAPP/.iterable/ios"
INSTALLED="$ROOT/installed/SampleShop.app"
BUILT="$ARTAPP/build/Build/Products/Debug-iphonesimulator/SampleShop.app"
RELEASE="$ARTAPP/build/Build/Products/Release-iphonesimulator/SampleShop.app"
mkdir -p "$ARTBIN" "$ARTSPACE" "$INSTALLED" "$BUILT/IterableSDK_IterableSDK.bundle"
printf 'name: SampleShop\ntargets:\n  SampleShop:\n    platform: iOS\n' > "$ARTAPP/project.yml"
app_bundle() { # <.app> <bundle id> <executable bytes> <touch -t stamp>
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>%s</string><key>CFBundleExecutable</key><string>SampleShop</string><key>DTPlatformName</key><string>iphonesimulator</string></dict></plist>\n' \
    "$2" > "$1/Info.plist"
  printf '%s' "$3" > "$1/SampleShop"
  chmod +x "$1/SampleShop"
  touch -t "$4" "$1/SampleShop"
}
app_bundle "$BUILT" com.example.sampleshop integrated 202610221000
app_bundle "$INSTALLED" com.example.sampleshop baseline 202610220900
BUILT="$(cd "$BUILT" && pwd -P)"
cat > "$ARTBIN/xcrun" <<XEOF
#!/usr/bin/env bash
if [[ "\$*" == "simctl list devices --json" ]]; then
  printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[{"udid":"SIM-ART-1","name":"iPhone 17","state":"Booted","isAvailable":true}]}}\n'
elif [[ "\$*" == "simctl get_app_container SIM-ART-1 com.example.sampleshop app" ]]; then
  printf '%s\n' "$INSTALLED"
elif [[ "\$*" == *"devicectl"*"list devices"* ]]; then
  printf '{"result":{"devices":[]}}\n'
else
  exit 2
fi
XEOF
cp "$SIMBIN/xcodebuild" "$SIMBIN/sw_vers" "$SIMBIN/uname" "$ARTBIN/"
chmod +x "$ARTBIN"/*
for file in scope.json target.json .env server-validation.json; do
  cp "$WORKSPACE/$file" "$ARTSPACE/$file"
done
chmod 600 "$ARTSPACE"/scope.json "$ARTSPACE"/target.json "$ARTSPACE"/.env "$ARTSPACE"/server-validation.json
run_art() { env PATH="$ARTBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$ARTSPACE" bin/ios-prepare-proof "$@"; }
run_art_line() { env PATH="$ARTBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$ARTSPACE" bash -c "$1"; }
fresh_run() { rm -rf "$ARTSPACE/proof-target.json" "$ARTSPACE/archive" "$ARTSPACE/proof-discovery.json"; }
option_command() { # <status json> <label>
  node -e '
    const q = JSON.parse(process.argv[1]).next.question;
    const o = q.options.find(item => item.label === process.argv[2]);
    process.stdout.write(o ? o.commands[0] || "" : "");
  ' "$1" "$2"
}
prompt_has() { node -e 'process.exit(JSON.parse(process.argv[1]).next.question.prompt.includes(process.argv[2]) ? 0 : 1)' "$1" "$2"; }

art="$(run_art status)"
bind_label="Use the build at Debug-iphonesimulator/SampleShop.app"
bind="$(option_command "$art" "$bind_label")"
if [[ "$(json_value "$art" next.kind)" == proof_artifact &&
      "$(json_value "$art" next.question.recommended)" == "$bind_label" &&
      "$bind" == *"/ios-prepare-proof answer --field app-path --value $BUILT" &&
      -n "$(option_command "$art" "Use the app already installed")" ]] &&
    prompt_has "$art" "Newest build: $BUILT (Debug, built" &&
    prompt_has "$art" "On the device: a copy with no Iterable SDK"; then
  ok "a build newer than a pre-integration install is the recommended artifact, and the installed app stays an option"
else
  bad "the proof did not recommend binding the build it found" \
    "kind=$(json_value "$art" next.kind) rec=$(json_value "$art" next.question.recommended)"
fi

bound="$(run_art_line "$bind")"
identity_start="$(json_value "$bound" next.question.free_text.command)"
if [[ "$(json_value "$bound" next.kind)" == confirm_proof &&
      "$(json_value "$bound" proposed.app_path)" == "$BUILT" ]] &&
    prompt_has "$bound" "App: $BUILT" &&
    prompt_has "$bound" "pgrep -f 'Devices/SIM-ART-1/.*/SampleShop\.app/SampleShop( |\$)'"; then
  ok "after binding, the identity screen names the bound build and reads the executable from it"
else
  bad "the identity screen lost the bound build or the device-specific identity steps" "$(json_value "$bound" next.question.prompt)"
fi
run_art_line "${identity_start//\{\{answer\}\}/dogs@example.com}" >/dev/null 2>&1
[[ "$(json_value "$(cat "$ARTSPACE/proof-target.json" 2>/dev/null)" app_path)" == "$BUILT" ]] &&
  ok "typing the identity starts a run bound to that exact build" ||
  bad "the started run is not bound to the build" "$(cat "$ARTSPACE/proof-target.json" 2>/dev/null)"

kept="$(run_art status)"
mkdir -p "$RELEASE/IterableSDK_IterableSDK.bundle"
app_bundle "$RELEASE" com.example.sampleshop rebuilt 202610221100
RELEASE="$(cd "$RELEASE" && pwd -P)"
rebuilt="$(run_art status)"
rebind_label="Start a fresh run with the build at Release-iphonesimulator/SampleShop.app"
rebind="$(option_command "$rebuilt" "$rebind_label")"
if [[ "$(json_value "$kept" next.kind)" == existing_proof &&
      "$(json_value "$kept" next.question.recommended)" == "Keep this run" &&
      "$(json_value "$rebuilt" next.question.recommended)" == "$rebind_label" &&
      "$rebind" == *"/ios-prepare-proof restart --confirm --app-path $RELEASE" ]] &&
    prompt_has "$kept" "App: $BUILT" &&
    prompt_has "$rebuilt" "Newer build: $RELEASE"; then
  ok "an existing run keeps its build until a newer one appears, then recommends a fresh run bound to it"
else
  bad "the existing-run screen ignored a newer build or recommended one that is not newer" \
    "kept=$(json_value "$kept" next.question.recommended) rebuilt=$(json_value "$rebuilt" next.question.recommended)"
fi
run_art_line "$rebind" >/dev/null 2>&1
[[ "$(json_value "$(cat "$ARTSPACE/proof-target.json")" app_path)" == "$RELEASE" ]] &&
  ok "the recommended fresh run is bound to the newer build" ||
  bad "the fresh run did not bind the newer build"

fresh_run
rm -rf "$RELEASE"
mkdir -p "$INSTALLED/IterableSDK_IterableSDK.bundle"
touch -t 202610221200 "$INSTALLED/SampleShop"
later="$(run_art status)"
installed_only="$(run_art answer --field app-source --value installed)"
if [[ "$(json_value "$later" next.question.recommended)" == "Use the app already installed" &&
      "$(json_value "$installed_only" next.kind)" == confirm_proof ]] &&
    prompt_has "$later" "On the device: a copy built" &&
    prompt_has "$installed_only" "App: the copy already installed on this device"; then
  ok "an installed copy built after the newest build stays recommended, and choosing it skips the screen"
else
  bad "a newer installed copy was passed over, or choosing it asked again" \
    "rec=$(json_value "$later" next.question.recommended) next=$(json_value "$installed_only" next.kind)"
fi

fresh_run
rm -rf "$BUILT/IterableSDK_IterableSDK.bundle"
no_sdk="$(run_art status)"
mkdir -p "$BUILT/IterableSDK_IterableSDK.bundle"
app_bundle "$BUILT" com.example.other integrated 202610221300
other="$(run_art status)"
if [[ "$(json_value "$no_sdk" next.kind)" == confirm_proof &&
      "$(json_value "$other" next.kind)" == confirm_proof ]]; then
  ok "a build without the Iterable SDK, or of another bundle, is never offered"
else
  bad "a build that cannot prove this integration was offered" \
    "no_sdk=$(json_value "$no_sdk" next.kind) other=$(json_value "$other" next.kind)"
fi

# The identity the app signed in with, from the device, offered only once Iterable
# holds this Simulator's current APNs token on that user.
IDBIN="$ROOT/idbin"
IDAPP="$ROOT/idapp"
IDSPACE="$IDAPP/.iterable/ios"
IDSTATE="$ROOT/idstate"
IDDEVICES="$ROOT/iddevices"
IDINSTALLED="$ROOT/idinstalled/SampleShop.app"
mkdir -p "$IDBIN" "$IDSPACE" "$IDSTATE" "$IDDEVICES" "$IDINSTALLED/IterableSDK_IterableSDK.bundle"
printf 'name: SampleShop\ntargets:\n  SampleShop:\n    platform: iOS\n' > "$IDAPP/project.yml"
app_bundle "$IDINSTALLED" com.example.sampleshop integrated 202610221000
bash tests/fixtures/ios-prove/simulate register "$IDDEVICES" SIM-ID-1 com.example.sampleshop development >/dev/null
cat > "$IDBIN/xcrun" <<XEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$IDSTATE/xcrun-calls"
case "\$*" in
  "simctl list devices --json")
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-26-2":[{"udid":"SIM-ID-1","name":"iPhone 17","state":"Booted","isAvailable":true}]}}\n' ;;
  "simctl get_app_container SIM-ID-1 com.example.sampleshop app") printf '%s\n' "$IDINSTALLED" ;;
  "simctl spawn SIM-ID-1 log show "*) cat "$IDSTATE/log.ndjson" 2>/dev/null; printf '{"count":0,"finished":1}\n' ;;
  "simctl launch --terminate-running-process SIM-ID-1 com.example.sampleshop -iterableProofIdentity YES")
    cat "$IDSTATE/marker.ndjson" >> "$IDSTATE/log.ndjson" 2>/dev/null; printf 'com.example.sampleshop: 4242\n' ;;
  *devicectl*) printf '{"result":{"devices":[]}}\n' ;;
  *) exit 2 ;;
esac
XEOF
cat > "$IDBIN/curl" <<XEOF
#!/usr/bin/env bash
cat >/dev/null
url="\${@: -1}"
printf '%s\n' "\$url" >> "$IDSTATE/curl-calls"
device() { printf '{"user":{"userId":"%s","dataFields":{"devices":[{"appPackageName":"com.example.sampleshop","endpointEnabled":true,"token":"%s"}]}}}\n200' "\$1" "\$(node -e 'process.stdout.write(Buffer.alloc(80,Number(process.argv[1])).toString("hex"))' "\$2")"; }
case "\$url" in
  */api/users/byUserId/SIGNED-IN-1) device SIGNED-IN-1 17 ;;
  */api/users/byUserId/OTHER-PHONE-2) device OTHER-PHONE-2 34 ;;
  */api/users/byUserId/TWIN-4) device TWIN-4 17 ;;
  */api/users/byUserId/*) printf '{"msg":"No user exists with userId x","code":"BadParams"}\n400' ;;
  *) printf '{"msg":"unexpected"}\n500' ;;
esac
XEOF
cp "$SIMBIN/xcodebuild" "$SIMBIN/sw_vers" "$SIMBIN/uname" "$IDBIN/"
chmod +x "$IDBIN"/*
printf '{"features":["push-notifications","sdk-initialization"],"identity_mode":"user-id","data_region":"US","jwt_enabled":false}\n' > "$IDSPACE/scope.json"
for file in target.json .env server-validation.json; do cp "$WORKSPACE/$file" "$IDSPACE/$file"; done
chmod 600 "$IDSPACE"/scope.json "$IDSPACE"/target.json "$IDSPACE"/.env "$IDSPACE"/server-validation.json
run_id() {
  env PATH="$IDBIN:$PATH" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$IDDEVICES" \
    IOS_PROOF_IDENTITY_WAIT=0 IOS_WORKSPACE="$IDSPACE" bin/ios-prepare-proof "$@" 2>/dev/null
}
run_id_line() {
  env PATH="$IDBIN:$PATH" ITERABLE_IOS_TEST_MODE=1 IOS_CORE_SIMULATOR_DEVICES_ROOT="$IDDEVICES" \
    IOS_PROOF_IDENTITY_WAIT=0 IOS_WORKSPACE="$IDSPACE" bash -c "$1" 2>/dev/null
}
curl_calls() { [[ -f "$IDSTATE/curl-calls" ]] && wc -l < "$IDSTATE/curl-calls" | tr -d ' ' || printf 0; }
sdk_line() { # <userId>
  printf '{"timestamp":"2026-10-22 10:25:29.091000+0100","eventMessage":"❤️ 10:25:29.0910:0x13f009480:RequestProcessorUtil:attemptSend():39: No user exists with userId %s"}\n' "$1"
}
offers_identity() { grep -q 'device token on that user","description' <<< "$1"; }
use_label() { printf 'Use %s: Iterable has this Simulator'"'"'s current device token on that user' "$1"; }

quiet="$(run_id status)"
if [[ "$(json_value "$quiet" next.kind)" == confirm_proof && "$(curl_calls)" == 0 &&
      "$(json_value "$quiet" next.question.recommended)" == "Relaunch the app to read the identity it signs in with" ]] &&
    ! offers_identity "$quiet"; then
  ok "with no identity candidates the screen asks Iterable nothing and offers the relaunch"
else
  bad "no candidates still reached Iterable or offered an identity" "curl=$(curl_calls) rec=$(json_value "$quiet" next.question.recommended)"
fi

{ printf '{"eventMessage":"❤️ 10:25:29.0910:0x1:RequestProcessorUtil:attemptSend():39: No user exists with email dogs@example.com"}\n'
  printf '{"eventMessage":"Signed in. No user exists with userId SIGNED-IN-1 yet, retrying"}\n'; } > "$IDSTATE/log.ndjson"
foreign="$(run_id status)"
if [[ "$(curl_calls)" == 0 ]] && ! offers_identity "$foreign"; then
  ok "an email echoed in a user-ID app, or a line the SDK did not log, is never looked up"
else
  bad "a log line that is not the SDK's, or the other identity type, became a candidate" "curl=$(curl_calls)"
fi

sdk_line SIGNED-IN-1 > "$IDSTATE/log.ndjson"
offered="$(run_id status)"
use="$(option_command "$offered" "$(use_label SIGNED-IN-1)")"
if [[ "$(json_value "$offered" next.question.recommended)" == "$(use_label SIGNED-IN-1)" &&
      "$use" == *"/ios-prepare-proof start --confirm --identity SIGNED-IN-1" &&
      "$(curl_calls)" == 1 && ! -e "$IDSPACE/proof-target.json" ]] &&
    prompt_has "$offered" "The app's log mentions SIGNED-IN-1, and Iterable has this Simulator's current device token on that user." &&
    ! grep -q 'SIGNED-IN-1' "$IDSPACE/proof-discovery.json" 2>/dev/null; then
  ok "an SDK log line naming a user who holds this Simulator's token is offered, and nothing is recorded"
else
  bad "the SDK log identity was not offered, or was recorded without a tap" \
    "rec=$(json_value "$offered" next.question.recommended) curl=$(curl_calls)"
fi
run_id_line "$use" >/dev/null
[[ "$(json_value "$(cat "$IDSPACE/proof-target.json" 2>/dev/null)" identity)" == SIGNED-IN-1 ]] &&
  ok "choosing it starts the run with that identity, as typing would" ||
  bad "choosing the offered identity did not record it"
rm -f "$IDSPACE/proof-target.json" "$IDSPACE/proof-discovery.json"

sdk_line OTHER-PHONE-2 > "$IDSTATE/log.ndjson"
: > "$IDSTATE/curl-calls"
elsewhere="$(run_id status --identity-candidate NOBODY-3)"
check="$(option_command "$elsewhere" "Check again")"
if ! offers_identity "$elsewhere" &&
    prompt_has "$elsewhere" "The app's log mentions OTHER-PHONE-2, but Iterable doesn't have this Simulator's token on it yet; sign in or relaunch, then check again." &&
    prompt_has "$elsewhere" "The agent proposed NOBODY-3, but Iterable doesn't have this Simulator's token on it yet" &&
    [[ "$check" == *"/ios-prepare-proof status --identity-candidate NOBODY-3" && "$(curl_calls)" == 2 ]]; then
  ok "a user without this Simulator's token, or no user at all, is named but never offered, and Check again keeps the proposal"
else
  bad "a candidate Iterable cannot tie to this Simulator was offered" "$(json_value "$elsewhere" next.question.prompt)"
fi

: > "$IDSTATE/log.ndjson"
agent="$(run_id status --identity-candidate SIGNED-IN-1)"
[[ "$(json_value "$agent" next.question.recommended)" == "$(use_label SIGNED-IN-1)" ]] &&
  prompt_has "$agent" "The agent proposed SIGNED-IN-1, and Iterable has this Simulator's current device token on that user." &&
  ok "an agent's --identity-candidate is offered under the same token rule" ||
  bad "the agent's candidate skipped or failed the token check" "$(json_value "$agent" next.question.recommended)"

twins="$(run_id status --identity-candidate SIGNED-IN-1 --identity-candidate TWIN-4)"
! offers_identity "$twins" &&
  prompt_has "$twins" "Iterable has this Simulator's token on more than one of these: SIGNED-IN-1, TWIN-4. Type the one the app is signed in with." &&
  ok "when two candidates hold this Simulator's token, neither is offered" ||
  bad "an ambiguous token match offered one identity" "$(json_value "$twins" next.question.recommended)"

printf '{"eventMessage":"ITBL_PROOF identity=SIGNED-IN-1"}\n' > "$IDSTATE/marker.ndjson"
: > "$IDSTATE/xcrun-calls"
relaunch="$(option_command "$quiet" "Relaunch the app to read the identity it signs in with")"
marked="$(run_id_line "$relaunch")"
if grep -qx 'simctl launch --terminate-running-process SIM-ID-1 com.example.sampleshop -iterableProofIdentity YES' "$IDSTATE/xcrun-calls" &&
    [[ "$relaunch" == *"/ios-prepare-proof read-identity --confirm" &&
      "$(json_value "$marked" next.question.recommended)" == "$(use_label SIGNED-IN-1)" ]] &&
    prompt_has "$marked" "Relaunched com.example.sampleshop with -iterableProofIdentity YES; its proof marker logged the identity below." &&
    prompt_has "$marked" "The app's proof marker logged SIGNED-IN-1, and Iterable has this Simulator's current device token on that user."; then
  ok "the relaunch passes -iterableProofIdentity YES, and the marker's identity is offered once Iterable has the token"
else
  bad "the relaunch did not pass the proof argument or its marker was not offered" "$(grep launch "$IDSTATE/xcrun-calls")"
fi
printf '{"eventMessage":"ITBL_PROOF identity=OTHER-PHONE-2"}\n' > "$IDSTATE/log.ndjson"
unmarked="$(run_id status)"
! offers_identity "$unmarked" &&
  prompt_has "$unmarked" "The app's proof marker logged OTHER-PHONE-2, but Iterable doesn't have this Simulator's token on it yet" &&
  ok "a marker identity whose user lacks this Simulator's token is not offered" ||
  bad "a marker identity was offered without the token match"

if bin/ios-prepare-proof --help | grep -q "ios-provision capture-server" &&
    ! bin/ios-prepare-proof --help | grep -q "capture-mobile"; then
  ok "verify-only help delegates credentials without exposing provisioning"
else
  bad "verify-only help mixed proof preparation with credential provisioning"
fi

((FAILED)) && exit 1
exit 0
