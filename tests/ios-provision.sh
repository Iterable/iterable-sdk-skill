#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-provision-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-provision-test.*|/private/tmp/iterable-ios-provision-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$FAKEBIN" "$STATE" "$ROOT/app"

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$STATE/asc-download.p8" 2>/dev/null

cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "Xcode 18.0"
EOF

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == "simctl list devices --json" ]]; then
  if [[ -f "$ASC_TEST_STATE/use-simulator" ]]; then
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"udid":"SIM-DEVICE-1","name":"iPhone 16","state":"Booted","isAvailable":true}]}}\n'
  else
    printf '{"devices":{}}\n'
  fi
elif [[ "$*" == *"devicectl"*"list devices"* ]]; then
  if [[ -f "$ASC_TEST_STATE/physical-is-simulated" ]]; then
    printf '{"result":{"devices":[{"identifier":"00008101-SIMULATED","name":"iPhone 16","platform":"iOS","reality":"simulated","state":"available"}]}}\n'
  else
    printf '{"result":{"devices":[{"identifier":"00008101-TESTDEVICE","name":"Test iPhone","platform":"iOS","reality":"physical","state":"available"}]}}\n'
  fi
else
  exit 2
fi
EOF

cat > "$FAKEBIN/npx" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat > "$FAKEBIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
cat "$ASC_TEST_STATE/clipboard"
EOF

cat > "$FAKEBIN/pbcopy" <<'EOF'
#!/usr/bin/env bash
cat > "$ASC_TEST_STATE/clipboard"
EOF

cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
set -eu
config="$(cat)"
printf 'curl %s\n' "$*" >> "$ASC_TEST_STATE/calls"
if [[ "$*" == *push.apple.com* || "$*" == *appstoreconnect.apple.com* ]]; then
  APPLE_FAKE_STATE="${APPLE_FAKE_STATE:-$ASC_TEST_STATE}" exec __APPLE_FAKE__ "$@" <<< "$config"
fi
if grep -Eq '/api/users/(getByEmail|byUserId)' <<< "$*"; then
  printf '{"msg":"No user exists"}\n400\n'
elif grep -q 'server-key-canary' <<< "$config"; then
  if grep -q 'registerDeviceToken' <<< "$*"; then
    printf '{"msg":"Invalid parameters"}\n400\n'
  else
    printf '{"channels":[{"messageMedium":"Push"}]}\n200\n'
  fi
elif grep -q 'privilege-odd-canary' <<< "$config"; then
  if grep -q 'registerDeviceToken' <<< "$*"; then
    printf '{"msg":"Invalid parameters"}\n400\n'
  else
    printf '{"msg":"Invalid API key","code":"BadApiKey"}\n401\n'
  fi
elif grep -q 'mobile-key-canary' <<< "$config"; then
  if ! grep -q 'registerDeviceToken' <<< "$*"; then
    printf '{"msg":"API key has insufficient privileges","code":"Unauthorized"}\n401\n'
  elif [[ -f "$ASC_TEST_STATE/jwt-probe" ]]; then
    printf '{"msg":"InvalidJwtPayload: JWT required"}\n401\n'
  else
    printf '{"msg":"Invalid parameters"}\n400\n'
  fi
else
  printf '{"msg":"invalid api key"}\n401\n'
fi
EOF

# Native iOS provisioning never calls asc; this fake only proves that.
cat > "$FAKEBIN/asc" <<'EOF'
#!/usr/bin/env bash
printf 'asc %s\n' "$*" >> "$ASC_TEST_STATE/asc-calls"
exit 2
EOF

sed -i '' "s#__APPLE_FAKE__#$PWD/tests/fixtures/ios-apple-curl#" "$FAKEBIN/curl"
chmod +x "$FAKEBIN/xcodebuild" "$FAKEBIN/xcrun" "$FAKEBIN/npx" "$FAKEBIN/pbpaste" \
  "$FAKEBIN/pbcopy" "$FAKEBIN/curl" "$FAKEBIN/asc"

# macOS ships an xcodebuild shim in /usr/bin, so hide it from a copy of /usr/bin.
NO_XCODE_BIN="$ROOT/no-xcode-bin"
mkdir -p "$NO_XCODE_BIN"
for tool in /usr/bin/*; do
  [[ "${tool##*/}" == xcodebuild ]] || ln -s "$tool" "$NO_XCODE_BIN/${tool##*/}"
done
ln -sf "$(command -v node)" "$NO_XCODE_BIN/node"
ln -sf "$FAKEBIN/curl" "$NO_XCODE_BIN/curl"

NO_ASC_BIN="$ROOT/no-asc-bin"
mkdir -p "$NO_ASC_BIN"
ln -s "$(command -v node)" "$NO_ASC_BIN/node"
ln -s "$FAKEBIN/xcodebuild" "$NO_ASC_BIN/xcodebuild"
ln -s "$FAKEBIN/npx" "$NO_ASC_BIN/npx"
ln -s "$FAKEBIN/curl" "$NO_ASC_BIN/curl"

NO_NPX_BIN="$ROOT/no-npx-bin"
mkdir -p "$NO_NPX_BIN"
ln -s "$(command -v node)" "$NO_NPX_BIN/node"
ln -s "$FAKEBIN/xcodebuild" "$NO_NPX_BIN/xcodebuild"
ln -s "$FAKEBIN/curl" "$NO_NPX_BIN/curl"

run_ios() {
  env \
    PATH="$FAKEBIN:$PATH" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-provision "$@"
}

run_ios_in() {
  local workspace="$1"
  shift
  env \
    PATH="$FAKEBIN:$PATH" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$workspace" \
    bin/ios-provision "$@"
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

: > "$STATE/calls"
fresh="$(run_ios status --offline --bundle-id com.example.sampleshop)"
if [[ "$(json_value "$fresh" next.kind)" == choose_features &&
      "$(json_value "$fresh" scope.present)" == false &&
      "$(json_value "$fresh" next.question.selection)" == multiple &&
      "$(json_value "$fresh" next.question.options.0.label)" == \
        "Push notifications" &&
      "$(json_value "$fresh" next.question.options.1.label)" == \
        "Events + user profiles" &&
      "$(json_value "$fresh" next.question.options.2.label)" == \
        "Deep links" &&
      "$(json_value "$fresh" next.question.options.3.label)" == \
        "More features" &&
      "$(json_value "$fresh" next.question.free_text.hint)" == \
        *"initialization only"* &&
      ! -e "$WORKSPACE" &&
      ! -s "$STATE/calls" ]]; then
  ok "fresh iOS status starts with the compact Android-style feature selector"
else
  bad "fresh iOS status did not mirror the Android scope entry point"
fi

QUESTION_WORKSPACE="$ROOT/question-app/.iterable/ios"
question="$(
  run_ios_in "$QUESTION_WORKSPACE" question --kind choose_features
)"
if node -e '
  const question = JSON.parse(process.argv[1]);
  process.exit(
    question.header === "Features" &&
    question.selection === "multiple" &&
    question.options.length === 4 &&
    question.before_commands.length >= 4 &&
    question.free_text?.command.includes("--field features --value \u0027{{answer}}\u0027") &&
    question.options.every(option =>
      Array.isArray(option.commands) &&
      typeof option.effect === "string"
    ) &&
    question.options.find(option =>
      option.label === "Events + user profiles"
    ).commands.length === 2
      ? 0
      : 1
  );
' "$question" &&
  [[ ! -e "$QUESTION_WORKSPACE" ]]; then
  ok "iOS questions are structured selector data and do not create state"
else
  bad "iOS feature question is not renderable or wrote state"
fi

run_ios_in "$QUESTION_WORKSPACE" answer --field feature-push --value false >/dev/null
run_ios_in "$QUESTION_WORKSPACE" answer --field feature-events --value true >/dev/null
run_ios_in "$QUESTION_WORKSPACE" answer --field feature-profiles --value true >/dev/null
run_ios_in "$QUESTION_WORKSPACE" answer --field feature-deep-links --value true >/dev/null
core_features="$(
  run_ios_in "$QUESTION_WORKSPACE" answer --field feature-more --value true
)"
if [[ "$(json_value "$core_features" next.kind)" == choose_more_features &&
      "$(json_value "$core_features" next.question.selection)" == multiple &&
      "$(json_value "$core_features" next.question.options.0.label)" == \
        "In-app customization" &&
      "$(json_value "$core_features" next.question.options.2.label)" == \
        "Embedded Messages" &&
      "$(json_value "$core_features" next.question.options.length)" == 3 ]] &&
    node -e '
      const q=JSON.parse(process.argv[1]).next.question;
      process.exit(JSON.stringify(q).includes("feature-deep-links") ? 1 : 0);
    ' "$core_features"; then
  ok "the long tail is one optional follow-up instead of serial feature questions"
else
  bad "selecting more features did not open one compact follow-up"
fi

run_ios_in "$QUESTION_WORKSPACE" answer --field feature-in-app --value false >/dev/null
run_ios_in "$QUESTION_WORKSPACE" answer --field feature-inbox --value false >/dev/null
answered_features="$(
  run_ios_in "$QUESTION_WORKSPACE" answer --field feature-embedded --value false
)"
if [[ "$(json_value "$answered_features" next.kind)" == choose_identity &&
      "$(json_value "$answered_features" discovery.features)" == \
        "deep-linking,event-tracking,sdk-initialization,user-profiles" &&
      "$(stat -f '%Lp' "$QUESTION_WORKSPACE/discovery.json")" == 600 ]]; then
  ok "compact feature selectors persist securely and advance to identity"
else
  bad "compact feature selectors lost scope or did not advance"
fi

answered_identity="$(
  run_ios_in "$QUESTION_WORKSPACE" answer \
    --field identity-mode \
    --value unknown-user
)"
answered_region="$(
  run_ios_in "$QUESTION_WORKSPACE" answer \
    --field region \
    --value EU
)"
jwt_checking="$(
  run_ios_in "$QUESTION_WORKSPACE" answer --field jwt-check --value true
)"
jwt_back="$(
  run_ios_in "$QUESTION_WORKSPACE" answer --field jwt-check --clear
)"
run_ios_in "$QUESTION_WORKSPACE" answer --field jwt-check --value true >/dev/null
if [[ "$(json_value "$answered_region" next.question.recommended)" == \
        "I don't have a Mobile key yet — help me" &&
      "$(json_value "$jwt_checking" next.kind)" == check_jwt &&
      "$(json_value "$jwt_checking" next.command)" == *"question --kind check_jwt" &&
      "$(json_value "$jwt_checking" next.question.prompt)" == *"https://app.eu.iterable.com/settings/apiKeys"* &&
      "$(json_value "$jwt_back" next.kind)" == choose_jwt ]]; then
  ok "checking an existing Mobile key's JWT setting is its own step and can go back"
else
  bad "the JWT check did not open its own step or could not return to the choice"
fi

answered_jwt="$(
  run_ios_in "$QUESTION_WORKSPACE" answer \
    --field jwt-enabled \
    --value true
)"
if [[ "$(json_value "$answered_identity" next.kind)" == choose_region &&
      "$(json_value "$answered_region" next.kind)" == choose_jwt &&
      "$(json_value "$answered_jwt" next.kind)" == confirm_scope &&
      -z "$(grep jwt_check "$QUESTION_WORKSPACE/discovery.json")" &&
      "$(json_value "$answered_jwt" next.question.selection)" == single ]] &&
    node -e '
      const status = JSON.parse(process.argv[1]);
      const question = status.next.question;
      process.exit(
        question.prompt.split("\n").includes("Region: EU") &&
        question.prompt.split("\n").includes("JWT required: true") &&
        question.prompt.split("\n").pop()==="Use this Iterable integration scope?" &&
        !question.context.join("\n").includes("Region:") &&
        question.options[0].commands.some(command =>
          command.includes("record-scope --from-answers --confirm")
        ) ? 0 : 1
      );
    ' "$answered_jwt"; then
  ok "identity, region, and JWT selectors advance to a generated confirmation"
else
  bad "selector answers did not produce the expected confirmation state"
fi

standalone_confirmation="$(
  run_ios_in "$QUESTION_WORKSPACE" question --kind confirm_scope
)"
if node -e '
  const question=JSON.parse(process.argv[1]);
  const text=question.prompt;
  process.exit(
    text.includes("deep-linking") &&
    text.includes("event-tracking") &&
    text.includes("sdk-initialization") &&
    text.includes("user-profiles") &&
    text.includes("Region: EU") &&
    text.includes("JWT required: true") ? 0 : 1
  );
' "$standalone_confirmation"; then
  ok "standalone scope confirmation preserves independent feature answers"
else
  bad "standalone scope confirmation dropped feature choices"
fi

confirmed_scope="$(
  run_ios_in "$QUESTION_WORKSPACE" record-scope --from-answers --confirm
)"
if [[ "$(json_value "$confirmed_scope" scope.valid)" == true &&
      "$(json_value "$confirmed_scope" scope.identity_mode)" == unknown-user &&
      "$(json_value "$confirmed_scope" scope.data_region)" == EU &&
      "$(json_value "$confirmed_scope" scope.jwt_enabled)" == true &&
      "$(json_value "$confirmed_scope" next.kind)" == configure_iterable &&
      ! -e "$QUESTION_WORKSPACE/discovery.json" ]] &&
    node -e '
      const scope = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
      process.exit(
        scope.features.includes("sdk-initialization") &&
        scope.features.includes("unknown-user-activation") ? 0 : 1
      );
    ' "$QUESTION_WORKSPACE/scope.json"; then
  ok "confirmation records one durable scope and clears partial answers"
else
  bad "confirmed selector answers did not become the final scope"
fi

guided_setup="$(
  run_ios_in "$QUESTION_WORKSPACE" record-iterable-setup \
    --driver guided \
    --confirm
)"
if [[ "$(json_value "$guided_setup" iterable.setup_valid)" == true &&
      "$(json_value "$guided_setup" iterable.setup_driver)" == guided &&
      "$(json_value "$guided_setup" next.kind)" == capture_iterable &&
      "$(json_value "$guided_setup" next.owner)" == human &&
      "$(json_value "$guided_setup" next.question.header)" == "Mobile key" &&
      "$(json_value "$guided_setup" next.question.options.0.label)" == \
        "I've copied the Mobile key" &&
      "$(stat -f '%Lp' "$QUESTION_WORKSPACE/iterable-setup.json")" == 600 ]]; then
  ok "guided Mobile-key setup keeps browser actions with the developer"
else
  bad "iOS did not enter the Android-style guided dashboard step"
fi

MANUAL_WORKSPACE="$ROOT/manual-app/.iterable/ios"
run_ios_in "$MANUAL_WORKSPACE" record-scope \
  --features event-tracking,user-profiles \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
manual_setup="$(
  run_ios_in "$MANUAL_WORKSPACE" record-iterable-setup \
    --driver developer \
    --confirm
)"
if [[ "$(json_value "$manual_setup" iterable.setup_valid)" == true &&
      "$(json_value "$manual_setup" iterable.setup_driver)" == developer &&
      "$(json_value "$manual_setup" next.kind)" == capture_iterable &&
      "$(json_value "$manual_setup" next.owner)" == human &&
      "$(json_value "$manual_setup" next.question.options.0.label)" == \
        "I've copied the Mobile key" ]]; then
  ok "manual dashboard ownership returns to secure key capture"
else
  bad "manual Iterable setup did not preserve a guided path back into the tool"
fi

changed_setup="$(
  run_ios_in "$MANUAL_WORKSPACE" record-iterable-setup \
    --driver guided \
    --confirm
)"
if [[ "$(json_value "$changed_setup" iterable.setup_driver)" == guided &&
      "$(json_value "$changed_setup" next.kind)" == capture_iterable &&
      "$(json_value "$changed_setup" next.owner)" == human ]] &&
    node -e '
      const status=JSON.parse(process.argv[1]);
      process.exit("delegate" in status.next ? 1 : 0);
    ' "$changed_setup"; then
  ok "an explicit later selector choice can change provisioning ownership"
else
  bad "guided setup retained browser-agent ownership"
fi

: > "$STATE/calls"
run_ios record-scope \
  --features user-profiles,event-tracking,push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  >"$ROOT/unconfirmed-scope.out" 2>"$ROOT/unconfirmed-scope.err"
unconfirmed_scope_rc=$?
if [[ "$unconfirmed_scope_rc" -eq 2 && ! -e "$WORKSPACE/scope.json" ]]; then
  ok "integration scope cannot be recorded without confirmation"
else
  bad "integration scope was recorded without confirmation"
fi

: > "$STATE/calls"
run_ios record-scope \
  --features user-profiles,not-a-feature \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >"$ROOT/invalid-scope.out" 2>"$ROOT/invalid-scope.err"
invalid_scope_rc=$?
if [[ "$invalid_scope_rc" -eq 2 && ! -e "$WORKSPACE/scope.json" ]]; then
  ok "integration scope rejects unknown features"
else
  bad "integration scope accepted an unknown feature"
fi

: > "$STATE/calls"
scoped="$(run_ios record-scope \
  --features push-notifications,event-tracking,user-profiles,event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm)"
if [[ "$(json_value "$scoped" scope.present)" == true &&
      "$(json_value "$scoped" scope.valid)" == true &&
      "$(json_value "$scoped" scope.push_required)" == true &&
      "$(json_value "$scoped" next.kind)" == choose_bundle &&
      "$(stat -f '%Lp' "$WORKSPACE/scope.json")" == 600 ]] &&
    ! grep -q '^curl \\|^bundle-ids ' "$STATE/calls"; then
  ok "recorded push scope routes to Apple prerequisites before Iterable credentials"
else
  bad "recorded scope did not produce secure, feature-aware routing"
fi

run_ios record-iterable-setup --driver guided --confirm \
  >"$ROOT/early-iterable-setup.out" 2>"$ROOT/early-iterable-setup.err"
early_iterable_setup_rc=$?
if [[ "$early_iterable_setup_rc" -eq 2 &&
      ! -e "$WORKSPACE/iterable-setup.json" ]] &&
    grep -q "choose_bundle.*is next" "$ROOT/early-iterable-setup.err"; then
  ok "push flow refuses to open Iterable setup before Apple and APNs"
else
  bad "Iterable setup could bypass the provider-first state"
fi

run_ios question --kind capture_iterable \
  >"$ROOT/early-mobile-question.out" 2>"$ROOT/early-mobile-question.err"
early_mobile_question_rc=$?
if [[ "$early_mobile_question_rc" -eq 2 &&
      ! -s "$ROOT/early-mobile-question.out" ]] &&
    grep -q "choose_bundle.*is next" "$ROOT/early-mobile-question.err"; then
  ok "Mobile-key navigation cannot be generated before its current state"
else
  bad "Mobile-key navigation bypassed the current provisioning state"
fi

mobile_canary="mobile-key-canary-1234567890"
printf '%s' "$mobile_canary" > "$STATE/clipboard"
run_ios capture-mobile --region US --jwt-enabled false --confirm \
  >"$ROOT/early-mobile-capture.out" 2>"$ROOT/early-mobile-capture.err"
early_mobile_capture_rc=$?
if [[ "$early_mobile_capture_rc" -eq 2 &&
      ! -f "$WORKSPACE/.env" &&
      "$(cat "$STATE/clipboard")" == "$mobile_canary" ]] &&
    grep -q "choose_bundle.*is next" "$ROOT/early-mobile-capture.err"; then
  ok "Mobile-key capture cannot skip Apple and APNs"
else
  bad "Mobile-key capture ran independently of the state machine"
fi

flag_only="$(run_ios status --bundle-id com.example.sampleshop)"
run_ios record-apple-setup --strategy guided-manual --confirm \
  >"$ROOT/flag-only-apple.out" 2>"$ROOT/flag-only-apple.err"
flag_only_apple_rc=$?
run_ios record-target --bundle-id com.example.sampleshop --confirm \
  >"$ROOT/no-name.out" 2>"$ROOT/no-name.err"
no_name_rc=$?
if [[ "$(json_value "$flag_only" next.kind)" == choose_bundle &&
      "$(json_value "$flag_only" target.recorded)" == false &&
      "$(json_value "$flag_only" next.question.free_text.command)" == \
        *"record-target --bundle-id '{{answer}}' --confirm" &&
      "$flag_only_apple_rc" -eq 2 && "$no_name_rc" -eq 2 &&
      ! -e "$WORKSPACE/target.json" ]] &&
    grep -q "choose_bundle.*is next\|exact iOS target" "$ROOT/flag-only-apple.err" &&
    grep -q -- "--name" "$ROOT/no-name.err"; then
  ok "status --bundle-id still asks for the target, and a target needs a real product name"
else
  bad "status --bundle-id skipped the target step or recorded a placeholder name"
fi

targeted="$(
  run_ios record-target \
    --bundle-id com.example.sampleshop \
    --name 'Sample Shop' \
    --confirm
)"
if [[ "$(json_value "$targeted" next.kind)" == choose_apple_setup &&
      "$(json_value "$targeted" next.question.selection)" == single ]]; then
  ok "push target selection opens the Apple setup strategy selector"
else
  bad "push target selection skipped the Apple setup strategy"
fi

run_ios import-apns \
  --file "$STATE/asc-download.p8" \
  --key-id APNSKEY001 \
  --team-id TEAMID0001 \
  --confirm >"$ROOT/early-apns.out" 2>"$ROOT/early-apns.err"
early_apns_rc=$?
run_ios record-iterable-push \
  --bundle-id com.example.sampleshop \
  --confirm >"$ROOT/early-push.out" 2>"$ROOT/early-push.err"
early_push_rc=$?
run_ios record-iterable-app \
  --bundle-id com.example.sampleshop \
  --source created \
  --confirm >"$ROOT/early-app.out" 2>"$ROOT/early-app.err"
early_app_rc=$?
if [[ "$early_apns_rc" -eq 2 &&
      "$early_push_rc" -eq 2 &&
      "$early_app_rc" -eq 2 &&
      ! -e "$WORKSPACE/apns.json" &&
      ! -e "$WORKSPACE/iterable-app.json" &&
      ! -e "$WORKSPACE/iterable-push.json" ]] &&
    grep -q "choose_apple_setup.*is next" "$ROOT/early-apns.err" &&
    grep -q "choose_apple_setup.*is next" "$ROOT/early-push.err" &&
    grep -q "choose_apple_setup.*is next" "$ROOT/early-app.err"; then
  ok "later Apple and Iterable records cannot bypass the current next action"
else
  bad "a later provisioning command bypassed the Apple setup strategy gate"
fi

YML_APP="$ROOT/yml-app"
mkdir -p "$YML_APP"
cat > "$YML_APP/project.yml" <<'EOF'
name: Shelter Finder
targets:
  ShelterFinder:
    type: application
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.example.shelterfinder
        DEVELOPMENT_TEAM: TEAMID0002
EOF
run_ios_in "$YML_APP/.iterable/ios" record-scope \
  --features push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
yml_status="$(run_ios_in "$YML_APP/.iterable/ios" status)"
yml_command="$(json_value "$yml_status" next.question.options.0.commands.0)"
if [[ "$(json_value "$yml_status" next.kind)" == choose_bundle &&
      "$(json_value "$yml_status" target.detected_bundle_id)" == com.example.shelterfinder &&
      "$(json_value "$yml_status" target.detected_name)" == "Shelter Finder" &&
      "$(json_value "$yml_status" target.detected_source)" == project &&
      "$(json_value "$yml_status" next.question.recommended)" == "Use the detected app target" &&
      "$yml_command" == *"record-target --bundle-id com.example.shelterfinder --name Shelter\ Finder --confirm" ]] &&
    yml_targeted="$(cd "$YML_APP" && env PATH="$FAKEBIN:$PATH" ASC_TEST_STATE="$STATE" \
      IOS_WORKSPACE="$YML_APP/.iterable/ios" bash -c "$yml_command")" &&
    [[ "$(json_value "$yml_targeted" next.kind)" == choose_apple_setup &&
       "$(json_value "$yml_targeted" target.name)" == "Shelter Finder" ]]; then
  ok "choose_bundle offers the detected Bundle ID and product name as a runnable record-target"
else
  bad "choose_bundle did not offer a runnable detected target"
fi

EXISTING_APPLE_WORKSPACE="$ROOT/existing-apple-app/.iterable/ios"
: >"$STATE/calls"
run_ios_in "$EXISTING_APPLE_WORKSPACE" record-scope \
  --features push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$EXISTING_APPLE_WORKSPACE" record-target \
  --bundle-id com.example.existing \
  --name 'Existing App' \
  --confirm >/dev/null
existing_selected="$(
  env \
    PATH="$NO_ASC_BIN:/usr/bin:/bin" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$EXISTING_APPLE_WORKSPACE" \
    bin/ios-provision record-apple-setup \
      --strategy existing-ready \
      --confirm
)"
existing_ready="$(
  env \
    PATH="$NO_ASC_BIN:/usr/bin:/bin" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$EXISTING_APPLE_WORKSPACE" \
    bin/ios-provision record-apple-readiness \
      --strategy existing-ready \
      --confirm
)"
if [[ "$(json_value "$existing_selected" next.kind)" == confirm_existing_apple &&
      "$(json_value "$existing_ready" next.kind)" == import_apns &&
      "$(json_value "$existing_ready" apple_setup.strategy)" == existing-ready &&
      "$(json_value "$existing_ready" apple_setup.evidence_level)" == developer_observed &&
      "$(json_value "$existing_ready" tools.asc)" == undefined &&
      "$(json_value "$existing_ready" apple)" == undefined ]] &&
    node -e '
      const value=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      const confirmed=value.developer_confirmed||{};
      process.exit(
        !("checks" in value) &&
        value.tool_verified===false &&
        value.evidence_level==="developer_observed" &&
        confirmed.explicit_bundle_id===true &&
        confirmed.push_capability_enabled===true &&
        confirmed.signing_refreshed===true &&
        confirmed.apns_key_owner_identified===true ? 0 : 1
      );
    ' "$EXISTING_APPLE_WORKSPACE/apple-readiness.json"; then
  ok "existing Apple setup proceeds without asc and records developer-confirmed, not tool-verified, fields"
else
  bad "existing Apple setup still requires privileged automation or overstates evidence"
fi

removed_rc=0
for removed in "plan --bundle-id com.example.existing" \
    "apply --bundle-id com.example.existing --name Existing --confirm" \
    "approve --scope apple-read --bundle-id com.example.existing" \
    "experimental-asc-plan --experimental --confirm-read --apple-id developer@example.com --name Key" \
    "record-apple-setup --strategy team-api --confirm"; do
  # shellcheck disable=SC2086
  run_ios_in "$EXISTING_APPLE_WORKSPACE" $removed >/dev/null 2>&1 && removed_rc=1
done
legacy_question_rc=0
for kind in inspect_apple approve_apple authenticate; do
  run_ios_in "$EXISTING_APPLE_WORKSPACE" question --kind "$kind" \
    --bundle-id com.example.existing >/dev/null 2>&1 && legacy_question_rc=1
done
if [[ "$removed_rc" -eq 0 && "$legacy_question_rc" -eq 0 &&
      ! -s "$STATE/asc-calls" ]] &&
    ! grep -q 'team-api' "$EXISTING_APPLE_WORKSPACE/apple-setup.json"; then
  ok "the Team API path is gone: no plan, apply, approval, asc screen, or team-api strategy"
else
  bad "a Team API-key command, screen, or strategy is still reachable"
fi

MANUAL_APPLE_WORKSPACE="$ROOT/manual-apple-app/.iterable/ios"
run_ios_in "$MANUAL_APPLE_WORKSPACE" record-scope \
  --features push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$MANUAL_APPLE_WORKSPACE" record-target \
  --bundle-id com.example.manual \
  --name 'Manual App' \
  --confirm >/dev/null
manual_selected="$(
  run_ios_in "$MANUAL_APPLE_WORKSPACE" record-apple-setup \
    --strategy guided-manual \
    --confirm
)"
manual_resumed="$(run_ios_in "$MANUAL_APPLE_WORKSPACE" status --offline)"
manual_ready="$(
  run_ios_in "$MANUAL_APPLE_WORKSPACE" record-apple-readiness \
    --strategy guided-manual \
    --confirm
)"
if [[ "$(json_value "$manual_selected" next.kind)" == confirm_manual_apple &&
      "$(json_value "$manual_resumed" next.kind)" == confirm_manual_apple &&
      "$(json_value "$manual_ready" next.kind)" == import_apns &&
      "$(json_value "$manual_ready" apple_setup.evidence_level)" == developer_observed ]]; then
  ok "guided manual Apple setup is resumable and never called verified"
else
  bad "guided manual Apple setup lost its handoff or evidence boundary"
fi

GUIDE_WORKSPACE="$ROOT/guided-apple-app/.iterable/ios"
run_ios_in "$GUIDE_WORKSPACE" record-scope \
  --features push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$GUIDE_WORKSPACE" record-target \
  --bundle-id com.example.guided \
  --name 'Guided App' \
  --confirm >/dev/null
run_ios_in "$GUIDE_WORKSPACE" record-apple-setup \
  --strategy guided-manual --confirm >/dev/null
run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step push --confirm \
  >/dev/null 2>"$ROOT/guide-early.err"
guide_early_rc=$?
guide_started="$(run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step start --confirm)"
guide_app_id="$(run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step app-id --confirm)"
guide_resumed="$(run_ios_in "$GUIDE_WORKSPACE" status)"
run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step apns-key --confirm \
  >/dev/null 2>"$ROOT/guide-skip.err"
guide_skip_rc=$?
guide_push="$(run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step push --confirm)"
if [[ "$guide_early_rc" -eq 2 && "$guide_skip_rc" -eq 2 &&
      "$(json_value "$guide_started" next.kind)" == apple_step_app_id &&
      "$(json_value "$guide_started" next.question.header)" == "Apple 1 of 3" &&
      "$(json_value "$guide_started" next.question.prompt)" == *"App ID com.example.guided"* &&
      "$(json_value "$guide_app_id" next.kind)" == apple_step_push &&
      "$(json_value "$guide_resumed" next.kind)" == apple_step_push &&
      "$(json_value "$guide_resumed" apple_setup.guide_steps)" == app-id &&
      "$(json_value "$guide_push" next.kind)" == apple_step_apns_key &&
      "$(json_value "$guide_push" next.question.prompt)" == *"https://developer.apple.com/account/resources/authkeys/list"*"In Apple Developer → Keys"* &&
      "$(stat -f '%Lp' "$GUIDE_WORKSPACE/apple-guide.json")" == 600 &&
      ! -e "$GUIDE_WORKSPACE/apple-readiness.json" ]] &&
    grep -q "confirm_manual_apple.*is next" "$ROOT/guide-early.err" &&
    grep -q "apple_step_push.*is next" "$ROOT/guide-skip.err"; then
  ok "the guided Apple walkthrough resumes at its step and refuses to skip one"
else
  bad "the guided Apple walkthrough lost its place or let a step be skipped"
fi

guide_cleared="$(run_ios_in "$GUIDE_WORKSPACE" clear-apple-setup --confirm)"
run_ios_in "$GUIDE_WORKSPACE" record-apple-setup \
  --strategy guided-manual --confirm >/dev/null
guide_restarted="$(run_ios_in "$GUIDE_WORKSPACE" status)"
for step in start app-id push; do
  run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step "$step" --confirm >/dev/null
done
guide_done="$(run_ios_in "$GUIDE_WORKSPACE" record-apple-step --step apns-key --confirm)"
if [[ "$(json_value "$guide_cleared" next.kind)" == choose_apple_setup &&
      "$(json_value "$guide_restarted" next.kind)" == confirm_manual_apple &&
      "$(json_value "$guide_done" next.kind)" == import_apns &&
      "$(json_value "$guide_done" apple_setup.evidence_level)" == developer_observed ]] &&
    node -e '
      const value=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.exit(value.via==="walkthrough" && value.tool_verified===false &&
        value.developer_confirmed.push_capability_enabled===true ? 0 : 1);
    ' "$GUIDE_WORKSPACE/apple-readiness.json"; then
  ok "finishing the walkthrough records developer-confirmed readiness and hands off to the APNs import"
else
  bad "the guided Apple walkthrough did not hand off to the APNs import"
fi

touch "$MANUAL_APPLE_WORKSPACE/iterable-push.json" \
  "$MANUAL_APPLE_WORKSPACE/iterable-app.json" \
  "$MANUAL_APPLE_WORKSPACE/apple-guide.json" \
  "$MANUAL_APPLE_WORKSPACE/proof-target.json"
mkdir -p "$MANUAL_APPLE_WORKSPACE/proof" \
  "$MANUAL_APPLE_WORKSPACE/launches"
retargeted="$(
  run_ios_in "$MANUAL_APPLE_WORKSPACE" record-target \
    --bundle-id com.example.manual.changed \
    --name 'Manual App Changed' \
    --confirm
)"
if [[ "$(json_value "$retargeted" next.kind)" == choose_apple_setup &&
      ! -e "$MANUAL_APPLE_WORKSPACE/apple-setup.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/apple-readiness.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/apple-guide.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/iterable-app.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/iterable-push.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/proof-target.json" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/proof" &&
      ! -e "$MANUAL_APPLE_WORKSPACE/launches" ]]; then
  ok "changing the Bundle ID invalidates incompatible local downstream state"
else
  bad "changing the Bundle ID preserved incompatible Apple or proof state"
fi

main_selected="$(
  run_ios record-apple-setup \
    --strategy guided-manual \
    --confirm
)"
main_ready="$(
  run_ios record-apple-readiness \
    --strategy guided-manual \
    --confirm
)"
if [[ "$(json_value "$main_selected" next.kind)" == confirm_manual_apple &&
      "$(json_value "$main_ready" next.kind)" == import_apns &&
      "$(json_value "$main_ready" apple_setup.evidence_level)" == developer_observed ]]; then
  ok "the manual Apple handoff is the path to APNs import"
else
  bad "the manual Apple handoff did not lead to APNs import"
fi

MOBILE_WORKSPACE="$ROOT/mobile-app/.iterable/ios"
run_ios_in "$MOBILE_WORKSPACE" record-scope \
  --features event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null

printf '%s' "$mobile_canary" > "$STATE/clipboard"
run_ios_in "$MOBILE_WORKSPACE" capture-mobile --region US --confirm \
  >"$ROOT/mobile-no-jwt.out" 2>"$ROOT/mobile-no-jwt.err"
mobile_no_jwt_rc=$?
if [[ "$mobile_no_jwt_rc" -eq 2 && ! -f "$MOBILE_WORKSPACE/.env" ]]; then
  ok "Mobile key capture requires an explicit JWT decision"
else
  bad "Mobile key capture guessed the JWT policy"
fi

printf '%s' "$mobile_canary" > "$STATE/clipboard"
run_ios_in "$MOBILE_WORKSPACE" capture-mobile \
  --region EU --jwt-enabled false --confirm \
  >"$ROOT/mobile-wrong-scope.out" 2>"$ROOT/mobile-wrong-scope.err"
mobile_wrong_scope_rc=$?
if [[ "$mobile_wrong_scope_rc" -eq 2 && ! -f "$MOBILE_WORKSPACE/.env" ]]; then
  ok "Mobile key capture cannot contradict the recorded region or JWT policy"
else
  bad "Mobile key capture ignored the recorded integration scope"
fi

printf '%s' "$mobile_canary" > "$STATE/clipboard"
captured_mobile="$(
  run_ios_in "$MOBILE_WORKSPACE" capture-mobile \
    --region US --jwt-enabled false --confirm
)"
if [[ "$(stat -f '%Lp' "$MOBILE_WORKSPACE/.env")" == 600 &&
      "$(stat -f '%Lp' "$MOBILE_WORKSPACE/IterableSecrets.xcconfig")" == 600 &&
      "$(json_value "$captured_mobile" iterable.mobile_key_present)" == true &&
      "$(json_value "$captured_mobile" iterable.mobile_key_validated)" == false &&
      "$(json_value "$captured_mobile" iterable.xcconfig_present)" == true &&
      "$(json_value "$captured_mobile" next.kind)" == validate_iterable &&
      "$(json_value "$captured_mobile" iterable.data_region)" == US &&
      "$(json_value "$captured_mobile" iterable.jwt_enabled)" == false &&
      ! -s "$STATE/clipboard" ]] &&
    grep -q '^ITERABLE_API_KEY = mobile-key-canary-' \
      "$MOBILE_WORKSPACE/IterableSecrets.xcconfig" &&
    ! grep -q "$mobile_canary" <<< "$captured_mobile"; then
  ok "Mobile key becomes usable ignored Xcode configuration without leaking it"
else
  bad "Mobile key capture did not produce secure runtime configuration"
fi

: > "$STATE/calls"
validated_mobile="$(run_ios_in "$MOBILE_WORKSPACE" validate-mobile)"
if [[ "$(json_value "$validated_mobile" iterable.mobile_key_validated)" == true &&
      "$(json_value "$validated_mobile" iterable.validation_classification)" == \
        authenticated-mobile-key &&
      "$(json_value "$validated_mobile" next.kind)" == configure_server &&
      "$(json_value "$validated_mobile" next.question.header)" == "Server key" &&
      "$(json_value "$validated_mobile" iterable.mobile_key_rejected)" == false &&
      "$(stat -f '%Lp' "$MOBILE_WORKSPACE/mobile-validation.json")" == 600 &&
      "$(grep -c '^curl ' "$STATE/calls")" -eq 3 &&
      "$(grep -c '/api/channels' "$STATE/calls")" -eq 1 ]] &&
    grep -q '"server_access_refused": true' "$MOBILE_WORKSPACE/mobile-validation.json" &&
    ! grep -q "$mobile_canary" "$MOBILE_WORKSPACE/mobile-validation.json"; then
  ok "Mobile key is distinguished from an invalid control and refused Server-side access, without disclosure"
else
  bad "Mobile key validation did not produce independent credential evidence"
fi

server_canary="server-key-canary-1234567890"
printf '%s' "$server_canary" > "$STATE/clipboard"
captured_server="$(run_ios_in "$MOBILE_WORKSPACE" capture-server --confirm)"
if [[ "$(json_value "$captured_server" iterable.server_key_present)" == true &&
      "$(json_value "$captured_server" iterable.server_key_validated)" == false &&
      "$(json_value "$captured_server" next.kind)" == validate_server &&
      ! -s "$STATE/clipboard" ]] &&
    ! grep -q "$server_canary" <<< "$captured_server"; then
  ok "Server-side verification key is captured separately without entering the app config"
else
  bad "Server-side verification key capture leaked or misclassified the credential"
fi

: > "$STATE/calls"
validated_server="$(run_ios_in "$MOBILE_WORKSPACE" validate-server)"
if [[ "$(json_value "$validated_server" iterable.server_key_validated)" == true &&
      "$(json_value "$validated_server" iterable.server_validation_classification)" == \
        authenticated-server-key &&
      "$(json_value "$validated_server" next.kind)" == integrate_app &&
      "$(stat -f '%Lp' "$MOBILE_WORKSPACE/server-validation.json")" == 600 &&
      "$(grep -c '^curl ' "$STATE/calls")" -eq 2 ]] &&
    ! grep -q "$server_canary" "$MOBILE_WORKSPACE/server-validation.json"; then
  ok "Server-side key is distinguished live from an invalid control without disclosure"
else
  bad "Server-side key validation did not produce independent credential evidence"
fi

printf '%s' "server-key-canary-rotated-0987654321" > "$STATE/clipboard"
run_ios_in "$MOBILE_WORKSPACE" capture-server --confirm \
  >"$ROOT/server-overwrite.out" 2>"$ROOT/server-overwrite.err"
server_overwrite_rc=$?
replaced_server="$(run_ios_in "$MOBILE_WORKSPACE" capture-server --replace --confirm)"
: > "$STATE/calls"
revalidated_server="$(run_ios_in "$MOBILE_WORKSPACE" validate-server)"
again_server="$(run_ios_in "$MOBILE_WORKSPACE" validate-server)"
if [[ "$server_overwrite_rc" -eq 2 &&
      "$(json_value "$replaced_server" iterable.server_key_validated)" == false &&
      "$(json_value "$replaced_server" next.kind)" == validate_server &&
      "$(json_value "$revalidated_server" iterable.server_key_validated)" == true &&
      "$(json_value "$again_server" next.kind)" == integrate_app &&
      "$(grep -c '^ITERABLE_SERVER_KEY=' "$MOBILE_WORKSPACE/.env")" -eq 1 &&
      "$(grep -c '^ITERABLE_API_KEY=mobile-key-canary-' "$MOBILE_WORKSPACE/.env")" -eq 1 &&
      ! -s "$STATE/clipboard" ]] &&
    grep -q 'capture-server --replace --confirm' "$ROOT/server-overwrite.err" &&
    grep -q '^ITERABLE_SERVER_KEY=server-key-canary-rotated-' "$MOBILE_WORKSPACE/.env"; then
  ok "a rotated Server-side key is replaced explicitly and validate-server runs after setup"
else
  bad "a rotated Server-side key could not be replaced or re-validated"
fi

SAME_KEY_WORKSPACE="$ROOT/same-key-app/.iterable/ios"
mkdir -p "$SAME_KEY_WORKSPACE"
cp -p "$MOBILE_WORKSPACE"/scope.json "$MOBILE_WORKSPACE"/.env \
  "$MOBILE_WORKSPACE"/IterableSecrets.xcconfig \
  "$MOBILE_WORKSPACE"/mobile-validation.json \
  "$MOBILE_WORKSPACE"/server-validation.json "$SAME_KEY_WORKSPACE/"
sed -i '' "s/^ITERABLE_SERVER_KEY=.*/ITERABLE_SERVER_KEY=$mobile_canary/" \
  "$SAME_KEY_WORKSPACE/.env"
same_key="$(run_ios_in "$SAME_KEY_WORKSPACE" status)"
: > "$STATE/calls"
run_ios_in "$SAME_KEY_WORKSPACE" validate-server \
  >"$ROOT/same-key.out" 2>"$ROOT/same-key.err"
same_key_rc=$?
if [[ "$(json_value "$same_key" iterable.keys_identical)" == true &&
      "$(json_value "$same_key" iterable.mobile_key_validated)" == false &&
      "$(json_value "$same_key" iterable.server_key_validated)" == false &&
      "$(json_value "$same_key" next.kind)" == replace_mobile_key &&
      "$(json_value "$same_key" next.question.options.0.commands.0)" == \
        *"capture-mobile --replace --region US --jwt-enabled false --confirm" &&
      "$same_key_rc" -eq 2 &&
      ! -s "$STATE/calls" ]] &&
    ! grep -q "$mobile_canary" <<< "$same_key"; then
  ok "the same key in the Mobile and Server-side slots invalidates both and offers a replacement"
else
  bad "matching Mobile and Server-side keys were still treated as validated"
fi

ODD_WORKSPACE="$ROOT/odd-privilege/.iterable/ios"
run_ios_in "$ODD_WORKSPACE" record-scope \
  --features event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
printf '%s' "privilege-odd-canary-1234567890" > "$STATE/clipboard"
run_ios_in "$ODD_WORKSPACE" capture-mobile \
  --region US --jwt-enabled false --confirm >/dev/null
run_ios_in "$ODD_WORKSPACE" validate-mobile \
  >"$ROOT/odd.out" 2>"$ROOT/odd.err"
odd_rc=$?
odd_status="$(run_ios_in "$ODD_WORKSPACE" status)"
if [[ "$odd_rc" -eq 2 &&
      "$(json_value "$odd_status" iterable.mobile_key_validated)" == false &&
      "$(json_value "$odd_status" next.kind)" == replace_mobile_key &&
      "$(json_value "$odd_status" iterable.mobile_rejection_reason)" == *"not validated"* ]] &&
    grep -q '"valid": false' "$ODD_WORKSPACE/mobile-validation.json" &&
    ! grep -q 'privilege-odd-canary' "$ODD_WORKSPACE/mobile-validation.json"; then
  ok "a 401 without the insufficient-privileges refusal leaves the Mobile key unvalidated"
else
  bad "a 401 that is not the Mobile-key refusal was accepted as a Mobile key"
fi

SLOT_WORKSPACE="$ROOT/server-in-mobile-slot/.iterable/ios"
run_ios_in "$SLOT_WORKSPACE" record-scope \
  --features event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
printf '%s' "$server_canary" > "$STATE/clipboard"
run_ios_in "$SLOT_WORKSPACE" capture-mobile \
  --region US --jwt-enabled false --confirm >/dev/null
: > "$STATE/calls"
run_ios_in "$SLOT_WORKSPACE" validate-mobile \
  >"$ROOT/slot.out" 2>"$ROOT/slot.err"
slot_rc=$?
slot_status="$(run_ios_in "$SLOT_WORKSPACE" status)"
if [[ "$slot_rc" -eq 2 &&
      "$(grep -c '/api/channels' "$STATE/calls")" -eq 1 &&
      "$(json_value "$slot_status" iterable.mobile_key_validated)" == false &&
      "$(json_value "$slot_status" iterable.mobile_key_rejected)" == true &&
      "$(json_value "$slot_status" next.kind)" == replace_mobile_key &&
      "$(json_value "$slot_status" next.owner)" == human ]] &&
    grep -q 'Server-side key was captured in the Mobile slot' "$ROOT/slot.err" &&
    grep -q '"valid": false' "$SLOT_WORKSPACE/mobile-validation.json" &&
    ! grep -q "$server_canary" "$SLOT_WORKSPACE/mobile-validation.json"; then
  ok "a Server-side key in the Mobile slot is refused by the channel probe and routed to replacement"
else
  bad "a Server-side key in the Mobile slot was accepted or left a dead end"
fi

invalid_workspace="$ROOT/invalid-mobile/.iterable/ios"
run_ios_in "$invalid_workspace" record-scope \
  --features event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
printf '%s' "wrong-key-canary-1234567890" > "$STATE/clipboard"
run_ios_in "$invalid_workspace" capture-mobile \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$invalid_workspace" validate-mobile \
  >"$ROOT/invalid-mobile.out" 2>"$ROOT/invalid-mobile.err"
invalid_mobile_rc=$?
invalid_status="$(run_ios_in "$invalid_workspace" status)"
if [[ "$invalid_mobile_rc" -eq 2 &&
      "$(json_value "$invalid_status" iterable.mobile_key_validated)" == false &&
      "$(json_value "$invalid_status" next.kind)" == replace_mobile_key ]] &&
    grep -q '"valid": false' "$invalid_workspace/mobile-validation.json" &&
    ! grep -q 'wrong-key-canary' "$invalid_workspace/mobile-validation.json"; then
  ok "a plausible but rejected value is never validated and routes to a replacement screen"
else
  bad "Mobile key validation accepted a rejected credential"
fi

: > "$STATE/calls"
missing_xcode="$(
  env \
    PATH="$NO_XCODE_BIN:/bin" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$WORKSPACE" \
    bin/ios-provision status
)"
if [[ "$(json_value "$missing_xcode" next.kind)" == install_tools &&
      "$(json_value "$missing_xcode" next.summary)" == *xcodebuild* &&
      "$(json_value "$missing_xcode" next.command)" == *"question --kind install_tools" &&
      "$(json_value "$missing_xcode" next.question.options.0.relay)" == *xcodebuild* &&
      "$(json_value "$missing_xcode" next.question.options.1.commands.0)" == *"ios-provision status" ]]; then
  ok "missing tools get a relay to install them and a re-check that runs status"
else
  bad "missing tools left a step with nothing to run"
fi

: > "$STATE/calls"
online="$(run_ios status --bundle-id com.example.sampleshop)"
if [[ "$(json_value "$online" next.kind)" == import_apns &&
      "$(json_value "$online" next.question.free_text.command)" == \
        *"import-apns --file '{{answer}}' --confirm" &&
      "$(json_value "$online" next.question.options.1.relay)" == *"/bin/ios-provision import-apns --file"* &&
      ! -s "$STATE/calls" && ! -s "$STATE/asc-calls" ]]; then
  ok "push status reads nothing remote and offers an executable APNs import"
else
  bad "push status reached a network tool or offered no runnable APNs import"
fi

nonpush_workspace="$ROOT/nonpush-app/.iterable/ios"
run_ios_in "$nonpush_workspace" record-scope \
  --features user-profiles,event-tracking \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
printf '%s' "$mobile_canary" > "$STATE/clipboard"
run_ios_in "$nonpush_workspace" capture-mobile \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$nonpush_workspace" validate-mobile >/dev/null
printf '%s' "$server_canary" > "$STATE/clipboard"
run_ios_in "$nonpush_workspace" capture-server --confirm >/dev/null
run_ios_in "$nonpush_workspace" validate-server >/dev/null
nonpush="$(
  env \
    PATH="$NO_ASC_BIN:/usr/bin:/bin" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$nonpush_workspace" \
    bin/ios-provision status --offline --bundle-id com.example.sampleshop
)"
if [[ "$(json_value "$nonpush" next.kind)" == integrate_app &&
      "$(json_value "$nonpush" scope.push_required)" == false &&
      "$(json_value "$nonpush" next.summary)" == *"ios-verify inspect"* &&
      "$(json_value "$nonpush" next.summary)" == *"already validated"* ]] &&
    ! grep -q '^auth status\\|^bundle-ids ' "$STATE/calls"; then
  ok "non-push integration reaches app wiring without Apple or APNs"
else
  bad "non-push integration was incorrectly routed through Apple provisioning"
fi

without_npx="$(
  env \
    PATH="$NO_NPX_BIN:/usr/bin:/bin" \
    ASC_TEST_STATE="$STATE" \
    IOS_WORKSPACE="$nonpush_workspace" \
    bin/ios-provision status --offline --bundle-id com.example.sampleshop
)"
if [[ "$(json_value "$without_npx" next.kind)" == integrate_app &&
      "$(json_value "$without_npx" tools.npx)" == false ]]; then
  ok "guided native iOS setup does not require the browser operator's npx"
else
  bad "native iOS remained coupled to browser-automation tooling"
fi

: > "$STATE/calls"
nested_project="$PWD/eval/fixtures/ios/basic-swiftui"
nested_status="$(
  cd "$nested_project" &&
    env \
      PATH="$FAKEBIN:$PATH" \
      ASC_TEST_STATE="$STATE" \
      "$OLDPWD/bin/ios-provision" status --offline \
        --bundle-id com.example.sampleshop
)"
nested_workspace="$(json_value "$nested_status" workspace)"
if [[ "$nested_workspace" == "$nested_project/.iterable/ios" ]]; then
  ok "a nested iOS project gets its own local credential workspace"
else
  bad "a nested iOS project was mistaken for the skill repository"
fi

: > "$STATE/calls"
env \
  PATH="$FAKEBIN:$PATH" \
  ASC_TEST_STATE="$STATE" \
  bin/ios-provision status --offline --bundle-id com.example.sampleshop \
  >"$ROOT/tool-root.out" 2>"$ROOT/tool-root.err"
tool_root_rc=$?
if [[ "$tool_root_rc" -eq 30 && ! -s "$ROOT/tool-root.out" ]]; then
  ok "running from the skill root refuses cleanly without continuing"
else
  bad "skill-root refusal did not stop execution"
fi

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_APNSKEY001.p8" 2>/dev/null

run_ios import-apns \
  --file "$ROOT/AuthKey_APNSKEY001.p8" \
  --confirm >"$ROOT/no-team.out" 2>"$ROOT/no-team.err"
no_team_rc=$?
if [[ "$no_team_rc" -eq 2 && ! -e "$WORKSPACE/apns.json" ]] &&
    grep -q 'pass --team-id' "$ROOT/no-team.err"; then
  ok "APNs import names --team-id when DEVELOPMENT_TEAM cannot be read"
else
  bad "APNs import guessed or silently dropped the Team ID"
fi
imported="$(run_ios import-apns \
  --file "$ROOT/AuthKey_APNSKEY001.p8" \
  --team-id TEAMID0001 \
  --confirm)"
canonical_apns_path="$(cd "$ROOT" && pwd -P)/AuthKey_APNSKEY001.p8"

if [[ ! -e "$WORKSPACE/artifacts/apns-auth-key.p8" &&
      "$(stat -f '%Lp' "$ROOT/AuthKey_APNSKEY001.p8")" == 600 &&
      "$(stat -f '%Lp' "$WORKSPACE/apns.json")" == 600 &&
      "$(json_value "$imported" next.kind)" == validate_apns &&
      "$(json_value "$imported" next.owner)" == tool &&
      "$(json_value "$imported" next.command)" == *"ios-provision validate-apns" ]] &&
    grep -q "$canonical_apns_path" "$WORKSPACE/apns.json" &&
    grep -q '"key_id": "APNSKEY001"' "$WORKSPACE/apns.json" &&
    ! grep -q 'BEGIN PRIVATE KEY' "$WORKSPACE/apns.json"; then
  ok "APNs import records a secure external path and the Key ID from the AuthKey file name"
else
  bad "APNs import did not produce the secure local state"
fi

: > "$STATE/apple-calls"
: > "$STATE/calls"
apns_validated="$(run_ios validate-apns 2>"$ROOT/apns-validate.err")"
apns_validate_rc=$?
if [[ "$apns_validate_rc" -eq 0 &&
      "$(json_value "$apns_validated" apns.tool_verified)" == true &&
      "$(json_value "$apns_validated" next.kind)" == configure_iterable &&
      "$(grep -c 'POST api.sandbox.push.apple.com/3/device/[0-9a-f]\{64\} APNSKEY001' "$STATE/apple-calls")" -eq 1 &&
      "$(stat -f '%Lp' "$WORKSPACE/apns-validation.json")" == 600 ]] &&
    grep -q '"classification": "apns-key-accepted"' "$WORKSPACE/apns-validation.json" &&
    grep -q 'not the App ID\|does not check the App ID' "$ROOT/apns-validate.err" &&
    ! grep -qi 'bearer\|BEGIN PRIVATE' "$STATE/calls" "$WORKSPACE/apns-validation.json" &&
    ! grep -q 'eyJ' <<< "$apns_validated$(cat "$ROOT/apns-validate.err")"; then
  ok "validate-apns proves key, Key ID, and Team ID with one sandbox probe, without exposing the token"
else
  bad "validate-apns did not record a tool-verified APNs key safely"
fi

printf '%s' "$mobile_canary" > "$STATE/clipboard"
push_mobile="$(
  run_ios capture-mobile --region US --jwt-enabled false --confirm
)"
: > "$STATE/calls"
push_mobile_validated="$(run_ios validate-mobile)"
if [[ "$(json_value "$push_mobile" next.kind)" == validate_iterable &&
      "$(json_value "$push_mobile_validated" next.kind)" == configure_server &&
      "$(json_value "$push_mobile_validated" iterable.mobile_key_validated)" == true ]]; then
  ok "push flow captures and validates the Mobile key only after APNs, then requests the Server-side key"
else
  bad "push flow did not resume Iterable setup after APNs"
fi

printf '%s' "$server_canary" > "$STATE/clipboard"
push_server="$(run_ios capture-server --confirm)"
: > "$STATE/calls"
push_server_validated="$(run_ios validate-server)"
if [[ "$(json_value "$push_server" next.kind)" == validate_server &&
      "$(json_value "$push_server_validated" next.kind)" == configure_iterable_app &&
      "$(json_value "$push_server_validated" iterable.server_key_validated)" == true ]]; then
  ok "push flow validates the Server-side key before Iterable mobile-app setup"
else
  bad "push flow deferred its verification credential until the verifier"
fi

iterable_app_question="$(
  node -e '
    const value=JSON.parse(process.argv[1]);
    process.stdout.write(JSON.stringify(value.next.question));
  ' "$push_server_validated"
)"
app_recorded="$(
  run_ios record-iterable-app \
    --bundle-id com.example.sampleshop \
    --source created \
    --confirm
)"
if [[ "$(json_value "$app_recorded" next.kind)" == configure_iterable_push &&
      "$(json_value "$app_recorded" iterable_app.recorded_for_target)" == true &&
      "$(json_value "$app_recorded" iterable_app.source)" == created &&
      "$(stat -f '%Lp' "$WORKSPACE/iterable-app.json")" == 600 ]] &&
    printf '%s' "$iterable_app_question" | node -e '
      let input="";
      process.stdin.on("data", chunk => input += chunk);
      process.stdin.on("end", () => {
        const q=JSON.parse(input);
        const context=[q.prompt,...q.context].join("\n");
        process.exit(
          context.includes("Step 1 of 2 — Create the iOS mobile app") &&
          context.includes("https://app.iterable.com/integrations/mobileApps/create") &&
          context.includes("Name: Sample Shop") &&
          context.includes("Platform: iOS") &&
          context.includes("Bundle ID: com.example.sampleshop") ? 0 : 1
        );
      });
    '; then
  ok "Iterable iOS app creation is an explicit guided dashboard step"
else
  bad "Iterable iOS app creation was skipped or collapsed into APNs setup"
fi

push_dashboard_question="$(
  node -e '
    const value=JSON.parse(process.argv[1]);
    process.stdout.write(JSON.stringify(value.next.question));
  ' "$app_recorded"
)"
if printf '%s' "$push_dashboard_question" | node -e '
  let input="";
  process.stdin.on("data", chunk => input += chunk);
  process.stdin.on("end", () => {
    const q=JSON.parse(input);
    const context=[q.prompt,...q.context].join("\n");
    process.exit(
      context.includes("Step 2 of 2 — Add the APNs credential") &&
      context.includes("https://app.iterable.com/integrations/mobileApps") &&
      !context.includes("/settings/appsAndWebsites") &&
      context.includes(process.argv[1]) &&
      context.includes("Key ID: APNSKEY001") &&
      context.includes("Team ID: TEAMID0001") &&
      context.includes("Bundle ID: com.example.sampleshop") ? 0 : 1
    );
  });
' "$canonical_apns_path"; then
  ok "Iterable APNs setup receives the exact recorded credential values"
else
  bad "Iterable APNs setup omitted the upload path or Apple identifiers"
fi

mkdir -p "$STATE/SampleShop.app"
proof_app_path="$(cd "$STATE/SampleShop.app" && pwd -P)"
proof_start="$(run_ios proof-status)"
if [[ "$(json_value "$proof_start" proposed.proof_mode)" == behavioral &&
      "$(json_value "$proof_start" next.kind)" == proof_environment &&
      "$(json_value "$proof_start" next.question.header)" == "Proof env" ]]; then
  ok "proof setup automatically uses behavioral verification without a mode question"
else
  bad "proof setup exposed its internal verification mode as a user decision"
fi
run_ios proof-answer --field bundle-id --value com.example.sampleshop >/dev/null
run_ios proof-answer --field environment --value development >/dev/null
run_ios proof-answer --field identity --value ios-proof@example.com >/dev/null
touch "$STATE/use-simulator"
simulator_device_question="$(run_ios proof-status)"
run_ios proof-answer --field environment --value production >/dev/null
production_device_question="$(run_ios proof-status)"
touch "$STATE/physical-is-simulated"
misclassified_device_question="$(run_ios proof-status)"
rm "$STATE/physical-is-simulated"
run_ios proof-answer --field environment --value development >/dev/null
rm "$STATE/use-simulator"
if node -e '
  const development=JSON.parse(process.argv[1]).next.question;
  const production=JSON.parse(process.argv[2]).next.question;
  process.exit(
    development.options.some(option=>
      option.label.includes("Simulator") &&
      option.description.includes("real APNs sandbox")
    ) &&
    !production.options.some(option=>option.label.includes("Simulator"))
      ? 0
      : 1
  );
' "$simulator_device_question" "$production_device_question"; then
  ok "proof device selector offers eligible Simulator sandbox proof but excludes it from production"
else
  bad "proof device selector misclassified Simulator APNs support"
fi
if ! node -e '
  const question=JSON.parse(process.argv[1]).next.question;
  process.exit(question.options.some(option=>
    option.label.includes("(physical)") ||
    option.label.includes("SIMULATED")
  ) ? 0 : 1);
' "$misclassified_device_question"; then
  ok "CoreDevice simulated entries are not offered as physical iPhones"
else
  bad "CoreDevice simulated entries were misclassified as physical iPhones"
fi
run_ios proof-answer --field device --value 00008101-TESTDEVICE >/dev/null
proof_confirmation="$(run_ios proof-status)"
proof_target="$(
  run_ios record-proof --from-answers --confirm --app-path "$proof_app_path"
)"
if [[ "$(json_value "$proof_confirmation" next.kind)" == confirm_proof &&
      "$(json_value "$proof_confirmation" next.question.selection)" == single &&
      "$(json_value "$proof_target" proof.valid)" == true &&
      "$(json_value "$proof_target" proof.proof_mode)" == behavioral &&
      "$(json_value "$proof_target" proof.identity_type)" == email &&
      "$(json_value "$proof_target" proof.identity)" == ios-proof@example.com &&
      "$(json_value "$proof_target" proof.switch_identity)" == "" &&
      "$(json_value "$proof_target" proof.device)" == 00008101-TESTDEVICE &&
      "$(json_value "$proof_target" proof.device_kind)" == physical &&
      "$(json_value "$proof_target" proof.apns_environment)" == sandbox &&
      "$(json_value "$proof_target" proof.production_follow_up_required)" == true &&
      "$(json_value "$proof_target" proof.app_path)" == "$proof_app_path" &&
      "$(json_value "$proof_target" proof.environment)" == development &&
      -n "$(json_value "$proof_target" proof.run_id)" &&
      "$(json_value "$proof_target" proof.profile_fields)" == "" &&
      "$(json_value "$proof_target" proof.events)" == "" &&
      "$(json_value "$proof_target" proof.tap_expect)" == "" &&
      "$(json_value "$proof_target" proof.logout_expect)" == "" &&
      "$(stat -f '%Lp' "$WORKSPACE/proof-target.json")" == 600 &&
      ! -e "$WORKSPACE/proof-discovery.json" ]]; then
  ok "guided proof setup asks no app-path question, and start binds the build the agent passes"
else
  bad "guided proof setup did not preserve the independently verifiable run scope"
fi

order_workspace="$ROOT/provider-first-app/.iterable/ios"
run_ios_in "$order_workspace" record-scope \
  --features push-notifications \
  --identity-mode email \
  --region US \
  --jwt-enabled false \
  --confirm >/dev/null
run_ios_in "$order_workspace" record-target \
  --bundle-id com.example.sampleshop \
  --name 'Sample Shop' \
  --confirm >/dev/null
run_ios_in "$order_workspace" record-apple-setup \
  --strategy guided-manual \
  --confirm >/dev/null
order_question="$(
  run_ios_in "$order_workspace" question \
    --kind confirm_manual_apple \
    --bundle-id com.example.sampleshop
)"
run_ios_in "$order_workspace" record-apple-readiness \
  --strategy guided-manual \
  --confirm >/dev/null
provider_ready="$(
  run_ios_in "$order_workspace" status \
    --bundle-id com.example.sampleshop
)"
provider_imported="$(
  run_ios_in "$order_workspace" import-apns \
    --file "$ROOT/AuthKey_APNSKEY001.p8" \
    --key-id APNSKEY001 \
    --team-id TEAMID0001 \
    --bundle-id com.example.sampleshop \
    --confirm
)"
if [[ "$(json_value "$order_question" options.0.label)" == "I don't have these yet — walk me through it" &&
      "$(json_value "$order_question" options.1.label)" == "Record manual setup" &&
      "$(json_value "$provider_ready" next.kind)" == import_apns &&
      "$(json_value "$provider_ready" apple_setup.evidence_level)" == developer_observed &&
      "$(json_value "$provider_imported" next.kind)" == validate_apns &&
      "$(json_value "$provider_imported" iterable.mobile_key_present)" == false ]]; then
  ok "push flow asks for Iterable credentials only after Apple and APNs are ready"
else
  bad "push flow did not preserve the provider-first provisioning order"
fi

APNS_BAD_WORKSPACE="$ROOT/apns-bad-app/.iterable/ios"
run_ios_in "$APNS_BAD_WORKSPACE" record-scope --features push-notifications \
  --identity-mode email --region US --jwt-enabled false --confirm >/dev/null
run_ios_in "$APNS_BAD_WORKSPACE" record-target --bundle-id com.example.apnsbad \
  --name 'Bad Key' --confirm >/dev/null
run_ios_in "$APNS_BAD_WORKSPACE" record-apple-setup --strategy guided-manual --confirm >/dev/null
run_ios_in "$APNS_BAD_WORKSPACE" record-apple-readiness --strategy guided-manual --confirm >/dev/null
for kid in BADKEY0001 NETDOWN001; do
  openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
    openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_$kid.p8" 2>/dev/null
done
run_ios_in "$APNS_BAD_WORKSPACE" import-apns --file "$ROOT/AuthKey_NETDOWN001.p8" \
  --team-id TEAMID0001 --confirm >/dev/null
run_ios_in "$APNS_BAD_WORKSPACE" validate-apns >/dev/null 2>"$ROOT/apns-net.err"
apns_net_rc=$?
apns_net_status="$(run_ios_in "$APNS_BAD_WORKSPACE" status)"
run_ios_in "$APNS_BAD_WORKSPACE" import-apns --file "$ROOT/AuthKey_BADKEY0001.p8" \
  --team-id TEAMID0001 --confirm >/dev/null 2>"$ROOT/apns-noreplace.err"
apns_noreplace_rc=$?
run_ios_in "$APNS_BAD_WORKSPACE" import-apns --replace --file "$ROOT/AuthKey_BADKEY0001.p8" \
  --team-id TEAMID0001 --confirm >/dev/null
run_ios_in "$APNS_BAD_WORKSPACE" validate-apns >/dev/null 2>"$ROOT/apns-bad.err"
apns_bad_rc=$?
apns_bad_status="$(run_ios_in "$APNS_BAD_WORKSPACE" status)"
apns_fixed="$(run_ios_in "$APNS_BAD_WORKSPACE" import-apns --replace \
  --file "$ROOT/AuthKey_APNSKEY001.p8" --team-id TEAMID0001 --confirm)"
apns_fixed_validated="$(run_ios_in "$APNS_BAD_WORKSPACE" validate-apns 2>/dev/null)"
if [[ "$apns_net_rc" -eq 2 &&
      "$(json_value "$apns_net_status" next.kind)" == validate_apns &&
      "$apns_noreplace_rc" -eq 2 &&
      "$apns_bad_rc" -eq 2 &&
      "$(json_value "$apns_bad_status" next.kind)" == replace_apns_key &&
      "$(json_value "$apns_bad_status" apns.rejected)" == true &&
      "$(json_value "$apns_bad_status" next.question.free_text.command)" == *"import-apns --replace --file '{{answer}}' --team-id TEAMID0001 --confirm" &&
      "$(json_value "$apns_fixed" next.kind)" == validate_apns &&
      "$(json_value "$apns_fixed_validated" next.kind)" == configure_iterable ]] &&
    grep -q 'inconclusive' "$ROOT/apns-net.err" &&
    grep -q 'InvalidProviderToken\|Key ID (BADKEY0001) or Team ID' "$ROOT/apns-bad.err"; then
  ok "a rejected APNs key routes to re-import, and a network failure leaves no receipt"
else
  bad "APNs rejection or network failure was recorded wrongly or left a dead end"
fi

TOPIC_WORKSPACE="$ROOT/apns-topic-app/.iterable/ios"
run_ios_in "$TOPIC_WORKSPACE" record-scope --features push-notifications \
  --identity-mode email --region US --jwt-enabled false --confirm >/dev/null
run_ios_in "$TOPIC_WORKSPACE" record-target --bundle-id com.example.apnsbad \
  --name 'Topic Key' --confirm >/dev/null
run_ios_in "$TOPIC_WORKSPACE" record-apple-setup --strategy guided-manual --confirm >/dev/null
run_ios_in "$TOPIC_WORKSPACE" record-apple-readiness --strategy guided-manual --confirm >/dev/null
topic_results=""
for kid in TOPICKEY01 BADTOPIC01; do
  openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
    openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_$kid.p8" 2>/dev/null
  run_ios_in "$TOPIC_WORKSPACE" import-apns --replace --file "$ROOT/AuthKey_$kid.p8" \
    --team-id TEAMID0001 --confirm >/dev/null 2>&1
  run_ios_in "$TOPIC_WORKSPACE" validate-apns >/dev/null 2>"$ROOT/apns-topic.err"
  topic_rc=$?
  topic_status="$(run_ios_in "$TOPIC_WORKSPACE" status)"
  if [[ "$topic_rc" -eq 2 &&
        "$(json_value "$topic_status" next.kind)" == replace_apns_key &&
        "$(json_value "$topic_status" apns.tool_verified)" == false &&
        "$(json_value "$topic_status" apns.credentials_valid)" == true &&
        "$(json_value "$topic_status" apns.classification)" == apns-key-topic-not-allowed &&
        "$(json_value "$topic_status" apns.rejection_reason)" == *"Apple accepted this key, but it isn't allowed to send to com.example.apnsbad — it may be a topic-restricted key that doesn't include this Bundle ID. Use a Team-scoped APNs key, or add this Bundle ID to the key's topics in Apple Developer → Keys"* &&
        "$(json_value "$topic_status" next.question.prompt)" == *"Topic Specific, add com.example.apnsbad to its topics"* &&
        "$(json_value "$topic_status" next.question.options.0.commands.0)" == *"ios-provision validate-apns" ]] &&
      node -e '
        const q=JSON.parse(process.argv[1]).next.question;
        process.exit(q.options.some(option=>option.label.startsWith("I don\u0027t have a working .p8") &&
          option.commands[0].endsWith("question --kind help_apns_replace")) ? 0 : 1);
      ' "$topic_status" &&
      grep -q 'refused the topic com.example.apnsbad' "$ROOT/apns-topic.err" &&
      grep -q '"credentials_valid": true' "$TOPIC_WORKSPACE/apns-validation.json" &&
      grep -q '"valid": false' "$TOPIC_WORKSPACE/apns-validation.json"; then
    topic_results="$topic_results ok"
  else
    topic_results="$topic_results $kid-failed"
  fi
done
if [[ "$topic_results" == " ok ok" ]]; then
  ok "TopicDisallowed and BadTopic are named outcomes: valid credentials, step not done, replace screen"
else
  bad "a topic refusal from APNs was not routed to its named replace screen" "$topic_results"
fi

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_ASCKEY0001.p8" 2>/dev/null
team_key_workspace() {
  local name="$1" workspace="$ROOT/$1/.iterable/ios"
  run_ios_in "$workspace" record-scope --features push-notifications \
    --identity-mode email --region US --jwt-enabled false --confirm >/dev/null
  run_ios_in "$workspace" record-target --bundle-id "com.example.$name" \
    --name 'Team App!' --confirm >/dev/null
  run_ios_in "$workspace" record-apple-setup --strategy team-key --confirm >/dev/null
  printf '%s' "$workspace"
}
ASC_STATE="$ROOT/asc-state"
reset_asc() { rm -rf "$ASC_STATE"; mkdir -p "$ASC_STATE"; : > "$ASC_STATE/apple-calls"; }
run_asc() { APPLE_FAKE_STATE="$ASC_STATE" run_ios_in "$@"; }

reset_asc
TEAM_WORKSPACE="$(team_key_workspace teamkey)"
team_key_screen="$(run_asc "$TEAM_WORKSPACE" status)"
run_asc "$TEAM_WORKSPACE" record-asc-key --issuer-id not-a-uuid --confirm \
  >/dev/null 2>"$ROOT/asc-early.err"
asc_early_rc=$?
team_issuer="$(run_asc "$TEAM_WORKSPACE" record-asc-key --file "$ROOT/AuthKey_ASCKEY0001.p8" --confirm 2>/dev/null)"
team_read_step="$(run_asc "$TEAM_WORKSPACE" record-asc-key \
  --issuer-id 57246542-96FE-1A63-E053-0824D011072A --confirm 2>/dev/null)"
team_plan="$(run_asc "$TEAM_WORKSPACE" asc-read 2>/dev/null)"
reads_before_apply="$(grep -c '^GET ' "$ASC_STATE/apple-calls")"
writes_before_apply="$(grep -c '^POST ' "$ASC_STATE/apple-calls")"
run_asc "$TEAM_WORKSPACE" asc-apply >/dev/null 2>&1
unconfirmed_apply_rc=$?
team_applied="$(run_asc "$TEAM_WORKSPACE" asc-apply --confirm 2>/dev/null)"
if [[ "$(json_value "$team_key_screen" next.kind)" == asc_key &&
      "$(json_value "$team_key_screen" next.question.prompt)" == "This is your App Store Connect API key, not the APNs key."* &&
      "$asc_early_rc" -eq 2 &&
      "$(json_value "$team_issuer" next.kind)" == asc_issuer &&
      "$(json_value "$team_read_step" next.kind)" == asc_read &&
      "$(json_value "$team_read_step" next.owner)" == tool &&
      "$(json_value "$team_plan" next.kind)" == asc_plan &&
      "$(json_value "$team_plan" apple_setup.asc_actions)" == create-bundle-id,enable-push &&
      "$(json_value "$team_plan" next.question.prompt)" == *"Register the explicit App ID com.example.teamkey, named Team App, for iOS."* &&
      "$reads_before_apply" -eq 1 &&
      "$writes_before_apply" -eq 0 &&
      "$unconfirmed_apply_rc" -eq 2 &&
      "$(json_value "$team_applied" apple_setup.evidence_level)" == tool_verified &&
      "$(json_value "$team_applied" next.kind)" == apple_step_apns_key &&
      "$(grep -c '^POST api.appstoreconnect.apple.com/v1/bundleIds ASCKEY0001' "$ASC_STATE/apple-calls")" -eq 1 &&
      "$(grep -c '^POST api.appstoreconnect.apple.com/v1/bundleIdCapabilities ASCKEY0001' "$ASC_STATE/apple-calls")" -eq 1 &&
      "$(stat -f '%Lp' "$TEAM_WORKSPACE/asc-key.json")" == 600 &&
      "$(stat -f '%Lp' "$ROOT/AuthKey_ASCKEY0001.p8")" == 600 ]] &&
    grep -q '"issuer_id": "57246542-96fe-1a63-e053-0824d011072a"' "$TEAM_WORKSPACE/asc-key.json" &&
    node -e '
      const value=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
      process.exit(value.strategy==="team-key" && value.tool_verified===true &&
        value.tool_checks.bundle_id_registered===true &&
        value.tool_checks.push_capability_enabled===true ? 0 : 1);
    ' "$TEAM_WORKSPACE/apple-readiness.json" &&
    ! grep -rq 'BEGIN PRIVATE\|eyJ' "$TEAM_WORKSPACE" "$ASC_STATE/apple-calls"; then
  ok "the Team-key path reads first, shows the exact plan, and applies only on --confirm"
else
  bad "the Team-key path changed Apple before approval or recorded the wrong evidence"
fi

reset_asc
printf 'com.example.ready' > "$ASC_STATE/asc-bundle"
touch "$ASC_STATE/asc-push"
READY_WORKSPACE="$(team_key_workspace ready)"
run_asc "$READY_WORKSPACE" record-asc-key --file "$ROOT/AuthKey_ASCKEY0001.p8" --confirm >/dev/null 2>&1
run_asc "$READY_WORKSPACE" record-asc-key --issuer-id 57246542-96fe-1a63-e053-0824d011072a --confirm >/dev/null 2>&1
ready_read="$(run_asc "$READY_WORKSPACE" asc-read 2>/dev/null)"
if [[ "$(json_value "$ready_read" next.kind)" == apple_step_apns_key &&
      "$(json_value "$ready_read" apple_setup.evidence_level)" == tool_verified &&
      "$(grep -c '^POST ' "$ASC_STATE/apple-calls")" -eq 0 ]]; then
  ok "an App ID that already has Push Notifications is verified without any write"
else
  bad "an already-ready App ID was changed or not verified"
fi

asc_failure() {
  local name="$1" marker="$2"
  reset_asc
  local workspace
  workspace="$(team_key_workspace "$name")"
  run_asc "$workspace" record-asc-key --file "$ROOT/AuthKey_ASCKEY0001.p8" --confirm >/dev/null 2>&1
  run_asc "$workspace" record-asc-key --issuer-id 57246542-96fe-1a63-e053-0824d011072a --confirm >/dev/null 2>&1
  [[ -z "$marker" ]] || touch "$ASC_STATE/$marker"
  printf '%s' "$workspace"
}
AUTH_WORKSPACE="$(asc_failure auth401 asc-401)"
run_asc "$AUTH_WORKSPACE" asc-read >/dev/null 2>"$ROOT/asc-401.err"
asc_401_rc=$?
auth_401="$(run_asc "$AUTH_WORKSPACE" status)"
FORBID_WORKSPACE="$(asc_failure auth403 asc-403)"
run_asc "$FORBID_WORKSPACE" asc-read >/dev/null 2>&1
auth_403="$(run_asc "$FORBID_WORKSPACE" status)"
CONFLICT_WORKSPACE="$(asc_failure conflict "")"
run_asc "$CONFLICT_WORKSPACE" asc-read >/dev/null 2>&1
touch "$ASC_STATE/asc-409"
run_asc "$CONFLICT_WORKSPACE" asc-apply --confirm >/dev/null 2>&1
asc_409_rc=$?
conflict="$(run_asc "$CONFLICT_WORKSPACE" status)"
if [[ "$asc_401_rc" -eq 2 &&
      "$(json_value "$auth_401" next.kind)" == asc_rejected &&
      "$(json_value "$auth_401" next.summary)" == *"HTTP 401"* &&
      "$(json_value "$auth_403" next.kind)" == asc_rejected &&
      "$(json_value "$auth_403" next.summary)" == *"Team key with the Admin or App Manager role"* &&
      "$asc_409_rc" -eq 2 &&
      "$(json_value "$conflict" next.kind)" == asc_conflict &&
      "$(json_value "$conflict" next.question.free_text.command)" == *"record-target --bundle-id '{{answer}}' --confirm" ]] &&
    grep -q 'HTTP 401' "$ROOT/asc-401.err"; then
  ok "App Store Connect 401, 403, and 409 answers each route to a named screen with a way forward"
else
  bad "an App Store Connect refusal was not routed to its named screen"
fi

reset_asc
DRIFT_WORKSPACE="$(asc_failure drift "")"
run_asc "$DRIFT_WORKSPACE" asc-read >/dev/null 2>&1
printf 'com.example.drift' > "$ASC_STATE/asc-bundle"
run_asc "$DRIFT_WORKSPACE" asc-apply --confirm >/dev/null 2>"$ROOT/asc-drift.err"
asc_drift_rc=$?
drift="$(run_asc "$DRIFT_WORKSPACE" status)"
if [[ "$asc_drift_rc" -eq 2 &&
      "$(grep -c '^POST ' "$ASC_STATE/apple-calls")" -eq 0 &&
      "$(json_value "$drift" next.kind)" == asc_read ]] &&
    grep -q 'changed since the plan' "$ROOT/asc-drift.err"; then
  ok "asc-apply refuses a plan that no longer matches App Store Connect"
else
  bad "asc-apply wrote against a stale plan"
fi

push_recorded="$(
  run_ios record-iterable-push \
    --bundle-id com.example.sampleshop \
    --confirm
)"
if [[ "$(json_value "$push_recorded" iterable_push.recorded_for_target)" == true &&
      "$(json_value "$push_recorded" iterable_push.read_back_verifiable)" == false &&
      "$(json_value "$push_recorded" next.kind)" == integrate_app &&
      "$(stat -f '%Lp' "$WORKSPACE/iterable-push.json")" == 600 ]]; then
  ok "unreadable Iterable dashboard setup advances without being mislabeled verified"
else
  bad "Iterable push setup record either stalled the flow or claimed remote proof"
fi

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_OTHERKEY1.p8" 2>/dev/null
chmod 644 "$ROOT/AuthKey_OTHERKEY1.p8"
before_hash="$(shasum -a 256 "$ROOT/AuthKey_APNSKEY001.p8" | awk '{print $1}')"
run_ios import-apns \
  --file "$ROOT/AuthKey_OTHERKEY1.p8" \
  --key-id OTHERKEY01 \
  --team-id TEAMID0001 \
  --confirm >"$ROOT/replace.out" 2>"$ROOT/replace.err"
replace_rc=$?
after_hash="$(shasum -a 256 "$ROOT/AuthKey_APNSKEY001.p8" | awk '{print $1}')"
if [[ "$replace_rc" -eq 2 && "$before_hash" == "$after_hash" &&
      "$(stat -f '%Lp' "$ROOT/AuthKey_OTHERKEY1.p8")" == 644 ]]; then
  ok "APNs import refuses a different key path without mutating that file"
else
  bad "APNs import changed a rejected key or replaced the existing selection"
fi

ROTATE_WORKSPACE="$ROOT/rotate-workspace"
cp -R "$WORKSPACE" "$ROTATE_WORKSPACE"
openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$ROOT/AuthKey_ROTATEKEY1.p8" 2>/dev/null
chmod 600 "$ROOT/AuthKey_ROTATEKEY1.p8"
rotate_before="$(run_ios_in "$ROTATE_WORKSPACE" status)"
run_ios_in "$ROTATE_WORKSPACE" import-apns --replace --file "$ROOT/AuthKey_ROTATEKEY1.p8" \
  --team-id TEAMID0001 --confirm >/dev/null 2>"$ROOT/rotate.err"
rotate_rc=$?
if [[ "$(json_value "$rotate_before" next.kind)" == integrate_app && "$rotate_rc" -eq 0 &&
      "$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).key_id)' "$ROTATE_WORKSPACE/apns.json")" == ROTATEKEY1 ]]; then
  ok "a validated APNs key can still be rotated with import-apns --replace after setup"
else
  bad "import-apns --replace was refused once setup reached app integration" "$(cat "$ROOT/rotate.err")"
fi

cp "$ROOT/AuthKey_APNSKEY001.p8" "$ROOT/AuthKey_APNSKEY001.backup"
printf 'not a private key\n' > "$ROOT/AuthKey_APNSKEY001.p8"
chmod 600 "$ROOT/AuthKey_APNSKEY001.p8"
invalidated="$(run_ios status --bundle-id com.example.sampleshop)"
mv "$ROOT/AuthKey_APNSKEY001.backup" "$ROOT/AuthKey_APNSKEY001.p8"
if [[ "$(json_value "$invalidated" apns.private_key_valid)" == false &&
      "$(json_value "$invalidated" next.kind)" == import_apns ]]; then
  ok "status revalidates recorded APNs material instead of trusting import time"
else
  bad "status trusted a recorded APNs path after its contents changed"
fi

cp "$ROOT/AuthKey_APNSKEY001.p8" "$ROOT/AuthKey_APNSKEY001.backup"
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 \
  -out "$ROOT/AuthKey_APNSKEY001.p8" 2>/dev/null
chmod 600 "$ROOT/AuthKey_APNSKEY001.p8"
rsa_invalidated="$(run_ios status --bundle-id com.example.sampleshop)"
mv "$ROOT/AuthKey_APNSKEY001.backup" "$ROOT/AuthKey_APNSKEY001.p8"
if [[ "$(json_value "$rsa_invalidated" apns.private_key_valid)" == false &&
      "$(json_value "$rsa_invalidated" next.kind)" == import_apns ]]; then
  ok "status rejects a readable RSA key where APNs requires EC P-256"
else
  bad "status accepted a non-P-256 private key as an APNs authentication key"
fi

((FAILED)) && exit 1
exit 0
