#!/usr/bin/env bash
# React Native and Expo on the iOS provisioning path: where the Mobile key is
# delivered for each framework, and reusing the keys an Android setup recorded.
# Fakes only: clipboard, curl. Fixture trees stand in for native, bare RN, Expo.

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

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-rn-provision.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-rn-provision.*|/private/tmp/iterable-ios-rn-provision.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
mkdir -p "$FAKEBIN" "$STATE"
cat > "$FAKEBIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
cat "$RN_STATE/clipboard"
EOF
cat > "$FAKEBIN/pbcopy" <<'EOF'
#!/usr/bin/env bash
cat > "$RN_STATE/clipboard"
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
config="$(cat)"
printf 'curl %s\n' "$*" >> "$RN_STATE/calls"
key="$(sed -n 's/^header = "Api-Key: \(.*\)"$/\1/p' <<< "$config")"
case "$key" in
  mobile-key-canary-*)
    if [[ "$*" == *registerDeviceToken* ]]; then
      printf '{"msg":"Invalid parameters"}\n400\n'
    else
      printf '{"msg":"API key has insufficient privileges","code":"Unauthorized"}\n401\n'
    fi
    ;;
  server-key-canary-*)
    if [[ "$*" == *registerDeviceToken* ]]; then
      printf '{"msg":"Invalid parameters"}\n400\n'
    else
      printf '{"channels":[{"messageMedium":"Push"}]}\n200\n'
    fi
    ;;
  *) printf '{"msg":"invalid api key"}\n401\n' ;;
esac
EOF
cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "Xcode 18.0"
EOF
chmod +x "$FAKEBIN"/*

MOBILE_KEY="mobile-key-canary-1234567890"
SERVER_KEY="server-key-canary-1234567890"

run_in() {
  local app="$1"
  shift
  (cd "$app" && env PATH="$FAKEBIN:$PATH" RN_STATE="$STATE" \
    IOS_WORKSPACE="$app/.iterable/ios" "$REPO/bin/ios-provision" "$@")
}

field() {
  node -e '
    const value = process.argv[2].split(".").reduce(
      (object, key) => object == null ? object : object[key], JSON.parse(process.argv[1]));
    process.stdout.write(value === null ? "null" :
      typeof value === "object" ? JSON.stringify(value) : String(value ?? ""));
  ' "$1" "$2"
}

new_app() {
  local app="$ROOT/$1" kind="$2"
  mkdir -p "$app"
  case "$kind" in
    react-native) printf '{"dependencies":{"react-native":"0.88.0"}}\n' > "$app/package.json" ;;
    expo) printf '{"dependencies":{"expo":"~58.0.14","react-native":"0.88.0"}}\n' > "$app/package.json" ;;
  esac
  printf '%s' "$app"
}

scope_to_capture() {
  local app="$1"
  run_in "$app" record-scope --features event-tracking --identity-mode email \
    --region US --jwt-enabled false --confirm >/dev/null 2>&1
  run_in "$app" record-iterable-setup --driver guided --confirm >/dev/null 2>&1
}

capture() {
  printf '%s' "$MOBILE_KEY" > "$STATE/clipboard"
  run_in "$1" capture-mobile --region US --jwt-enabled false --confirm 2>"$STATE/capture.err"
}

# Native: the Xcode config, as before.
NATIVE="$(new_app native native)"
scope_to_capture "$NATIVE"
native_captured="$(capture "$NATIVE")"
if [[ "$(field "$native_captured" iterable.framework)" == native &&
      "$(field "$native_captured" iterable.key_delivery)" == xcconfig &&
      "$(field "$native_captured" iterable.key_delivery_ok)" == true &&
      "$(field "$native_captured" next.kind)" == validate_iterable &&
      "$(stat -f '%Lp' "$NATIVE/.iterable/ios/IterableSecrets.xcconfig")" == 600 &&
      ! -e "$NATIVE/.iterable/rn" ]]; then
  ok "a native app still gets IterableSecrets.xcconfig"
else
  bad "the native key delivery changed"
fi

# Bare React Native: an ignored TypeScript module, and no xcconfig.
RN="$(new_app rn react-native)"
scope_to_capture "$RN"
rn_captured="$(capture "$RN")"
rn_module="$RN/.iterable/rn/iterable.local.ts"
if [[ "$(field "$rn_captured" iterable.framework)" == react-native &&
      "$(field "$rn_captured" iterable.key_delivery)" == rn-module &&
      "$(field "$rn_captured" iterable.key_delivery_ok)" == true &&
      "$(field "$rn_captured" next.kind)" == validate_iterable &&
      "$(stat -f '%Lp' "$rn_module")" == 600 &&
      "$(cat "$RN/.iterable/rn/.gitignore")" == '*' &&
      ! -e "$RN/.iterable/ios/IterableSecrets.xcconfig" ]] &&
    grep -qx "export const ITERABLE_API_KEY = \"$MOBILE_KEY\";" "$rn_module" &&
    ! grep -q "$MOBILE_KEY" <<< "$rn_captured$(cat "$STATE/capture.err")"; then
  ok "bare React Native gets .iterable/rn/iterable.local.ts at 0600 and no xcconfig"
else
  bad "bare React Native key delivery is wrong"
fi

rm -f "$rn_module"
missing_module="$(run_in "$RN" status)"
redelivered="$(run_in "$RN" deliver-mobile-key 2>/dev/null)"
if [[ "$(field "$missing_module" next.kind)" == deliver_mobile_key &&
      "$(field "$missing_module" next.owner)" == tool &&
      "$(field "$redelivered" next.kind)" == validate_iterable &&
      -f "$rn_module" ]]; then
  ok "a missing React Native key module is rewritten from the workspace, not re-captured"
else
  bad "a missing React Native key module left a dead end"
fi

FROM_IOS="$(new_app from-ios react-native)"
mkdir -p "$FROM_IOS/ios/App.xcodeproj"
: > "$FROM_IOS/ios/App.xcodeproj/project.pbxproj"
from_ios="$(cd "$FROM_IOS/ios" && env PATH="$FAKEBIN:$PATH" RN_STATE="$STATE" "$REPO/bin/ios-provision" status)"
if [[ "$(field "$from_ios" workspace)" == "$(cd "$FROM_IOS" && pwd -P)/.iterable/ios" &&
      "$(field "$from_ios" iterable.framework)" == react-native &&
      "$(field "$from_ios" iterable.key_delivery_path)" == "$(cd "$FROM_IOS" && pwd -P)/.iterable/rn/iterable.local.ts" ]]; then
  ok "run from a React Native app's ios/ folder, the key still goes to the app root's module"
else
  bad "run from ios/, the React Native key delivery resolved the wrong root" \
    "$(field "$from_ios" workspace) $(field "$from_ios" iterable.key_delivery_path)"
fi

forced="$(run_in "$FROM_IOS" status --framework native)"
run_in "$FROM_IOS" status --framework flutter >/dev/null 2>"$STATE/framework.err"
forced_bad=$?
if [[ "$(field "$forced" iterable.framework)" == native &&
      "$(field "$forced" iterable.key_delivery)" == xcconfig && "$forced_bad" -eq 2 ]] &&
    grep -q 'native, react-native, or expo' "$STATE/framework.err"; then
  ok "--framework overrides the resolver, and an unknown framework is refused"
else
  bad "--framework was ignored or accepted an unknown framework"
fi

# Expo: .env.local, only when git ignores it.
EXPO="$(new_app expo expo)"
printf 'node_modules/\n' > "$EXPO/.gitignore"
printf 'OTHER_SETTING=1\n' > "$EXPO/.env.local"
scope_to_capture "$EXPO"
expo_blocked="$(run_in "$EXPO" status)"
printf '%s' "$MOBILE_KEY" > "$STATE/clipboard"
run_in "$EXPO" capture-mobile --region US --jwt-enabled false --confirm \
  >/dev/null 2>"$STATE/expo-refused.err"
expo_refused_rc=$?
if [[ "$(field "$expo_blocked" next.kind)" == fix_expo_gitignore &&
      "$(field "$expo_blocked" next.question.prompt)" == *"Add the line .env*.local"* &&
      "$expo_refused_rc" -eq 2 &&
      "$(cat "$STATE/clipboard")" == "$MOBILE_KEY" ]] &&
    ! grep -q EXPO_PUBLIC "$EXPO/.env.local" &&
    grep -q 'does not ignore' "$STATE/expo-refused.err"; then
  ok "Expo refuses to write the key until .gitignore covers .env.local"
else
  bad "Expo wrote the key into a file git would commit"
fi

printf '.env*.local\n' >> "$EXPO/.gitignore"
expo_ready="$(run_in "$EXPO" status)"
expo_captured="$(capture "$EXPO")"
if [[ "$(field "$expo_ready" next.kind)" == configure_iterable &&
      "$(field "$expo_captured" iterable.key_delivery)" == expo-env &&
      "$(field "$expo_captured" iterable.key_delivery_ok)" == true &&
      "$(stat -f '%Lp' "$EXPO/.env.local")" == 600 &&
      ! -e "$EXPO/.iterable/ios/IterableSecrets.xcconfig" ]] &&
    grep -qx "EXPO_PUBLIC_ITERABLE_API_KEY=$MOBILE_KEY" "$EXPO/.env.local" &&
    grep -qx 'OTHER_SETTING=1' "$EXPO/.env.local"; then
  ok "Expo gets EXPO_PUBLIC_ITERABLE_API_KEY in .env.local, keeping its other lines"
else
  bad "Expo key delivery is wrong"
fi

GIT_EXPO="$(new_app git-expo expo)"
git -C "$GIT_EXPO" init -q
printf '.env*.local\n.iterable/\n' > "$GIT_EXPO/.gitignore"
scope_to_capture "$GIT_EXPO"
git_expo="$(capture "$GIT_EXPO")"
if [[ "$(field "$git_expo" iterable.key_delivery_ok)" == true ]] &&
    git -C "$GIT_EXPO" check-ignore -q .env.local; then
  ok "in a git repository, Expo asks git whether .env.local is ignored"
else
  bad "Expo key delivery in a git repository is wrong"
fi

# Reusing the Android setup: the keys and region it recorded, validated again.
android_setup() {
  local app="$1" base="$2"
  mkdir -p "$app/.iterable"
  printf '*\n' > "$app/.iterable/.gitignore"
  (
    umask 077
    {
      printf 'ITBL_SERVER_KEY=%s\n' "$SERVER_KEY"
      printf 'ITBL_MOBILE_KEY=%s\n' "$MOBILE_KEY"
      printf 'ITBL_EMAIL=dev@example.com\n'
      [[ -z "$base" ]] || printf 'ITBL_BASE=%s\n' "$base"
    } > "$app/.iterable/.env"
  )
}
SHARED="$(new_app shared react-native)"
android_setup "$SHARED" https://api.eu.iterable.com
offer="$(run_in "$SHARED" status)"
imported="$(run_in "$SHARED" import-from-android --confirm 2>"$STATE/import.err")"
for answer in "feature-push false" "feature-events true" "feature-profiles true" \
    "feature-deep-links false" "feature-more false"; do
  read -r f v <<< "$answer"
  run_in "$SHARED" answer --field "$f" --value "$v" >/dev/null
done
scoped="$(run_in "$SHARED" record-scope --from-answers --confirm 2>/dev/null)"
: > "$STATE/calls"
mobile_ok="$(run_in "$SHARED" validate-mobile 2>/dev/null)"
server_ok="$(run_in "$SHARED" validate-server 2>/dev/null)"
if [[ "$(field "$offer" next.kind)" == import_android &&
      "$(field "$offer" next.question.recommended)" == "Reuse the Android setup" &&
      "$(field "$offer" next.question.options.0.commands.0)" == *"import-from-android --confirm" &&
      "$(field "$imported" next.kind)" == choose_features &&
      "$(field "$imported" discovery.data_region)" == EU &&
      "$(field "$imported" discovery.jwt_enabled)" == false &&
      "$(field "$imported" discovery.identity_mode)" == email &&
      "$(field "$imported" iterable.key_delivery_ok)" == true &&
      "$(field "$scoped" next.kind)" == validate_iterable &&
      "$(field "$mobile_ok" next.kind)" == validate_server &&
      "$(field "$server_ok" next.kind)" == integrate_app &&
      "$(grep -c 'api.eu.iterable.com' "$STATE/calls")" -ge 3 ]] &&
    grep -qx "ITERABLE_SERVER_KEY=$SERVER_KEY" "$SHARED/.iterable/ios/.env" &&
    grep -qx "export const ITERABLE_API_KEY = \"$MOBILE_KEY\";" "$SHARED/.iterable/rn/iterable.local.ts" &&
    ! grep -q "$MOBILE_KEY\|$SERVER_KEY" <<< "$offer$imported$(cat "$STATE/import.err")"; then
  ok "the Android setup's keys, EU region, and No JWT are reused, delivered, and validated again"
else
  bad "reusing the Android setup asked again, skipped validation, or exposed a key"
fi

if [[ "$(field "$offer" next.question.context)" == *"Feature scope is still asked"* &&
      "$(field "$imported" discovery.scope_source)" == "" &&
      "$(field "$scoped" scope.source)" == "" ]]; then
  ok "without --features the import proposes no scope and the feature questions are asked"
else
  bad "an import without --features proposed or recorded a feature scope"
fi

# The scope the React Native skill confirmed in Step 0, carried into iOS.
CARRY="$(new_app carry react-native)"
android_setup "$CARRY" ""
carried_ids="event-tracking,push-notifications,sdk-initialization,user-profiles"
carry_offer="$(run_in "$CARRY" status --features push-notifications,event-tracking,user-profiles)"
carry_imported="$(run_in "$CARRY" import-from-android --confirm \
  --features push-notifications,event-tracking,user-profiles 2>"$STATE/carry.err")"
carry_scoped="$(run_in "$CARRY" record-scope --from-answers --confirm 2>/dev/null)"
if [[ "$(field "$carry_offer" next.kind)" == import_android &&
      "$(field "$carry_offer" next.question.context)" == *"React Native skill: event-tracking, push-notifications, sdk-initialization, user-profiles."* &&
      "$(field "$carry_offer" next.question.options.0.description)" == *"proposes the features event-tracking, push-notifications"* &&
      "$(field "$carry_offer" next.question.options.0.commands.0)" == *"import-from-android --confirm --features $carried_ids" &&
      "$(field "$carry_offer" next.command)" == *"question --kind import_android --features $carried_ids" &&
      "$(field "$carry_imported" next.kind)" == confirm_scope &&
      "$(field "$carry_imported" discovery.features)" == "$carried_ids" &&
      "$(field "$carry_imported" discovery.scope_source)" == react-native-step0 &&
      "$(field "$carry_imported" next.question.context)" == *"Features: $carried_ids (the scope confirmed in the React Native skill)"* &&
      "$(field "$carry_scoped" scope.features)" == "$carried_ids" &&
      "$(field "$carry_scoped" scope.source)" == react-native-step0 ]] &&
    grep -q "Proposed the feature scope confirmed in the React Native skill" "$STATE/carry.err"; then
  ok "a Step 0 scope passed with --features is shown on the import and confirmation screens, skips choose_features, and keeps its source"
else
  bad "the Step 0 scope was not carried, shown, or attributed"
fi

CHANGED="$(new_app changed react-native)"
android_setup "$CHANGED" ""
run_in "$CHANGED" import-from-android --confirm --features push-notifications >/dev/null 2>&1
changed="$(run_in "$CHANGED" answer --field features --value event-tracking)"
if [[ "$(field "$changed" discovery.features)" == event-tracking,sdk-initialization &&
      "$(field "$changed" discovery.scope_source)" == "" &&
      "$(field "$changed" next.question.context)" != *"React Native skill"* ]]; then
  ok "a scope the developer changes on iOS is no longer attributed to the React Native skill"
else
  bad "a changed scope still claims it came from the React Native skill"
fi

BOGUS="$(new_app bogus react-native)"
android_setup "$BOGUS" ""
run_in "$BOGUS" status --features push-notifications,unknown-user-activation \
  >/dev/null 2>"$STATE/bogus-status.err"
bogus_status_rc=$?
run_in "$BOGUS" import-from-android --confirm --features push-notifications,inbox \
  >/dev/null 2>"$STATE/bogus.err"
bogus_rc=$?
bogus_after="$(run_in "$BOGUS" status)"
if [[ "$bogus_status_rc" -eq 2 && "$bogus_rc" -eq 2 &&
      ! -e "$BOGUS/.iterable/ios/.env" && ! -e "$BOGUS/.iterable/ios/discovery.json" &&
      ! -e "$BOGUS/.iterable/rn" &&
      "$(field "$bogus_after" next.kind)" == import_android ]] &&
    grep -q -- '--features takes the ids choose_features records' "$STATE/bogus.err" &&
    grep -q -- '--features takes the ids choose_features records' "$STATE/bogus-status.err"; then
  ok "an id choose_features does not record is refused, and nothing is written"
else
  bad "an unknown --features id was accepted or left something behind"
fi

SKIP="$(new_app skip react-native)"
android_setup "$SKIP" ""
skipped="$(run_in "$SKIP" answer --field android-import --value skip)"
if [[ "$(field "$skipped" next.kind)" == choose_features &&
      "$(field "$skipped" iterable.mobile_key_present)" == false ]]; then
  ok "setting iOS up separately asks every question again"
else
  bad "declining the Android reuse still imported something"
fi

EXPO_SHARED="$(new_app expo-shared expo)"
printf 'node_modules/\n' > "$EXPO_SHARED/.gitignore"
android_setup "$EXPO_SHARED" ""
run_in "$EXPO_SHARED" import-from-android --confirm >/dev/null 2>&1
run_in "$EXPO_SHARED" record-scope --features event-tracking --identity-mode email \
  --region US --jwt-enabled false --confirm >/dev/null 2>&1
held="$(run_in "$EXPO_SHARED" status)"
held_env=absent
[[ ! -e "$EXPO_SHARED/.env.local" ]] || held_env=present
helped="$(run_in "$EXPO_SHARED" ignore-expo-env --confirm 2>/dev/null)"
expo_delivered="$(run_in "$EXPO_SHARED" deliver-mobile-key 2>/dev/null)"
if [[ "$(field "$held" next.kind)" == fix_expo_gitignore &&
      "$(field "$held" iterable.mobile_key_present)" == true &&
      "$held_env" == absent &&
      "$(field "$helped" next.kind)" == deliver_mobile_key &&
      "$(field "$expo_delivered" next.kind)" == validate_iterable &&
      "$(field "$expo_delivered" iterable.key_delivery_ok)" == true ]] &&
    grep -qx '.env\*.local' "$EXPO_SHARED/.gitignore" &&
    grep -qx 'node_modules/' "$EXPO_SHARED/.gitignore" &&
    grep -qx "EXPO_PUBLIC_ITERABLE_API_KEY=$MOBILE_KEY" "$EXPO_SHARED/.env.local"; then
  ok "an Expo import holds the key until .env.local is ignored, and the help option ignores it"
else
  bad "an Expo import wrote the key early or the .gitignore help left a dead end"
fi

MONO="$ROOT/mono"
mkdir -p "$MONO/apps"
git -C "$MONO" init -q
android_setup "$MONO" https://api.eu.iterable.com
MONO_APP="$(new_app mono/apps/mobile react-native)"
MONO_REAL="$(cd "$MONO" && pwd -P)"
mono_offer="$(run_in "$MONO_APP" status)"
mono_imported="$(run_in "$MONO_APP" import-from-android --confirm 2>"$STATE/mono.err")"
if [[ "$(field "$mono_offer" next.kind)" == import_android &&
      "$(field "$mono_offer" next.question.context)" == *"$MONO_REAL/.iterable"* &&
      "$(field "$mono_imported" iterable.imported_from)" == "$MONO_REAL/.iterable/.env" &&
      "$(field "$(cat "$MONO_APP/.iterable/ios/discovery.json")" android_import_path)" == "$MONO_REAL/.iterable/.env" &&
      "$(field "$mono_imported" discovery.data_region)" == EU &&
      "$(field "$mono_imported" iterable.key_delivery_ok)" == true &&
      -f "$MONO_APP/.iterable/rn/iterable.local.ts" ]] &&
    grep -q "$MONO_REAL/.iterable/.env" "$STATE/mono.err" &&
    ! grep -q "$MOBILE_KEY\|$SERVER_KEY" <<< "$mono_offer$mono_imported$(cat "$STATE/mono.err")"; then
  ok "in a monorepo, the Android setup at the git root is found from the app below it and its path recorded"
else
  bad "a monorepo app did not find or record the Android setup at the git root"
fi

LOOSE="$ROOT/loose"
android_setup "$LOOSE" ""
LOOSE_APP="$(new_app loose/app react-native)"
loose="$(run_in "$LOOSE_APP" status)"
if [[ "$(field "$loose" next.kind)" == choose_features ]]; then
  ok "outside a git repository, no Android setup above the app root is picked up"
else
  bad "an Android setup outside the app's repository was offered"
fi

CLASH="$(new_app clash react-native)"
android_setup "$CLASH" ""
mkdir -p "$CLASH/.iterable/ios"
(umask 077; printf 'ITERABLE_API_KEY=mobile-key-canary-different-0000\n' > "$CLASH/.iterable/ios/.env")
run_in "$CLASH" import-from-android --confirm >/dev/null 2>"$STATE/clash.err"
clash_rc=$?
if [[ "$clash_rc" -eq 2 ]] &&
    grep -q 'mobile-key-canary-different-0000' "$CLASH/.iterable/ios/.env"; then
  ok "import refuses to replace a different iOS Mobile key"
else
  bad "import overwrote a different iOS Mobile key"
fi

((FAILED)) && exit 1
exit 0
