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
APP_PATH="$STATE/DogShelter.app"
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
  "bundle_id": "com.example.dogshelter",
  "name": "Dog Shelter"
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
printf 'name: PushCheck\noptions:\n  deploymentTarget:\n    iOS: "27.0"\ntargets:\n  PushCheck:\n    platform: iOS\n' > "$MINAPP/project.yml"
min_status="$(env PATH="$MINBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$MINSPACE" bin/ios-prepare-proof status)"
if [[ "$(json_value "$min_status" proposed.device)" == SIM-IOS27 ]]; then
  ok "a deployment target of iOS 27 leaves only the iOS 27 Simulator, which is prefilled"
else
  bad "a Simulator below the app's deployment target was offered" "device=$(json_value "$min_status" proposed.device) kind=$(json_value "$min_status" next.kind)"
fi
rm "$MINAPP/project.yml"
printf 'name: PushCheck\ntargets:\n  PushCheck:\n    platform: iOS\n' > "$MINAPP/project.yml"
open_status="$(env PATH="$MINBIN:$FAKEBIN:$PATH" IOS_WORKSPACE="$MINSPACE" bin/ios-prepare-proof status)"
if [[ "$(json_value "$open_status" next.kind)" == proof_device &&
      "$(json_value "$open_status" proposed.device)" == "" ]]; then
  ok "without a known deployment target both booted Simulators stay on offer"
else
  bad "the device filter applied without a deployment target" "$(json_value "$open_status" next.kind)"
fi

if bin/ios-prepare-proof --help | grep -q "ios-provision capture-server" &&
    ! bin/ios-prepare-proof --help | grep -q "capture-mobile"; then
  ok "verify-only help delegates credentials without exposing provisioning"
else
  bad "verify-only help mixed proof preparation with credential provisioning"
fi

((FAILED)) && exit 1
exit 0
