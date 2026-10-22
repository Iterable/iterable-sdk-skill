#!/usr/bin/env bash
# The scope and identity a skill's Step 0 already confirmed, passed to
# ios-provision status as --features and --identity: shown on one screen,
# recorded only when the developer agrees, and never asked a second time.
# Offline: curl is a fake that records calls, and none are expected.

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

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-scope-carry.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-scope-carry.*|/private/tmp/iterable-ios-scope-carry.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
mkdir -p "$FAKEBIN" "$STATE"
: > "$STATE/calls"
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$CARRY_STATE/calls"
exit 7
EOF
cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
echo "Xcode 18.0"
EOF
chmod +x "$FAKEBIN"/*

run_in() {
  local app="$1"
  shift
  (cd "$app" && env PATH="$FAKEBIN:$PATH" CARRY_STATE="$STATE" \
    IOS_WORKSPACE="$app/.iterable/ios" "$REPO/bin/ios-provision" "$@")
}

# Runs a tool-authored command line exactly as an agent would.
run_line() {
  local app="$1"
  (cd "$app" && env PATH="$FAKEBIN:$PATH" CARRY_STATE="$STATE" \
    IOS_WORKSPACE="$app/.iterable/ios" bash -c "$2")
}

field() {
  node -e '
    const value = process.argv[2].split(".").reduce(
      (object, key) => object == null ? object : object[key], JSON.parse(process.argv[1]));
    process.stdout.write(value === null ? "null" :
      typeof value === "object" ? JSON.stringify(value) : String(value ?? ""));
  ' "$1" "$2"
}

option_by_label() {
  node -e '
    const q = JSON.parse(process.argv[1]);
    const option = q.options.find(item => item.label === process.argv[2]);
    if (!option || option.commands.length !== 1) process.exit(1);
    process.stdout.write(option.commands[0]);
  ' "$1" "$2"
}

# The scope and import screens carry their values in the prompt, the part every host shows.
prompt_of() {
  node -e 'process.stdout.write(JSON.parse(process.argv[1]).prompt)' "$1"
}

new_app() {
  local app="$ROOT/$1" kind="${2:-native}"
  mkdir -p "$app"
  [[ "$kind" != react-native ]] ||
    printf '{"dependencies":{"react-native":"0.88.0"}}\n' > "$app/package.json"
  printf '%s' "$app"
}

no_workspace_files() {
  [[ -z "$(find "$1/.iterable" -type f 2>/dev/null)" ]]
}

TRIAL_IDS="embedded-messaging,mobile-inbox,push-notifications,sdk-initialization"

# The Mastodon trial: push plus Mobile Inbox and Embedded, identity by user ID.
TRIAL="$(new_app trial)"
offer="$(run_in "$TRIAL" status --features push-notifications,mobile-inbox,embedded-messaging --identity user-id)"
offer_question="$(field "$offer" next.question)"
rendered="$(run_line "$TRIAL" "$(field "$offer" next.command)")"
use_command="$(option_by_label "$offer_question" "Use these answers")"
change_command="$(option_by_label "$offer_question" "Change the answers")"
if [[ "$(field "$offer" next.kind)" == carry_scope &&
      "$(field "$offer" next.owner)" == human &&
      "$(field "$offer" next.question.prompt)" == "Confirmed in the iOS skill: features embedded-messaging, mobile-inbox, push-notifications, sdk-initialization; identity user-id. Record these answers instead of asking them again?" &&
      "$(field "$offer" next.question.recommended)" == "Use these answers" &&
      "$use_command" == *"/bin/ios-provision carry-scope --features $TRIAL_IDS --identity user-id --confirm" &&
      "$change_command" == *"/bin/ios-provision answer --field step0-scope --value skip" &&
      "$(field "$rendered" prompt)" == "$(field "$offer" next.question.prompt)" &&
      "$(field "$rendered" options)" == "$(field "$offer" next.question.options)" ]] &&
    no_workspace_files "$TRIAL"; then
  ok "with Step 0 answers, status shows one screen naming exactly them, and writes nothing"
else
  bad "the Step 0 answers were not offered on one screen, or status wrote something" \
    "$(field "$offer" next.kind): $(field "$offer" next.question.prompt)"
fi

carried="$(run_line "$TRIAL" "$use_command" 2>"$STATE/trial.err")"
again="$(run_in "$TRIAL" status --features push-notifications,mobile-inbox,embedded-messaging --identity user-id)"
visited="carry_scope $(field "$carried" next.kind)"
regioned="$(run_in "$TRIAL" answer --field region --value US)"
visited="$visited $(field "$regioned" next.kind)"
jwted="$(run_in "$TRIAL" answer --field jwt-enabled --value false)"
visited="$visited $(field "$jwted" next.kind)"
confirm_prompt="$(prompt_of "$(field "$jwted" next.question)")"
if [[ "$visited" == "carry_scope choose_region choose_jwt confirm_scope" &&
      "$(field "$carried" discovery.scope_source)" == ios-step0 &&
      "$(field "$carried" discovery.identity_source)" == ios-step0 &&
      "$(field "$carried" discovery.identity_mode)" == user-id &&
      "$(field "$carried" discovery.mode_0600)" == true &&
      "$(field "$again" next.kind)" == choose_region ]] &&
    grep -qxF "Features: $TRIAL_IDS (the scope confirmed in the iOS skill)" <<< "$confirm_prompt" &&
    grep -qxF "Identity: user-id (confirmed in the iOS skill)" <<< "$confirm_prompt" &&
    grep -q "Proposed the answers confirmed in the iOS skill" "$STATE/trial.err"; then
  ok "using them skips choose_features, choose_more_features and choose_identity, and the final screen names their origin"
else
  bad "the carried answers were asked again or lost their origin" "visited: $visited"
fi

recorded="$(run_line "$TRIAL" "$(option_by_label "$(field "$jwted" next.question)" "Record this scope and continue")" 2>/dev/null)"
scope_file="$TRIAL/.iterable/ios/scope.json"
if [[ "$(field "$recorded" scope.features)" == "$TRIAL_IDS" &&
      "$(field "$recorded" scope.source)" == ios-step0 &&
      "$(field "$recorded" scope.identity_source)" == ios-step0 &&
      "$(field "$(cat "$scope_file")" scope_source)" == ios-step0 &&
      "$(field "$(cat "$scope_file")" identity_source)" == ios-step0 &&
      "$(field "$(cat "$scope_file")" identity_mode)" == user-id &&
      "$(field "$(cat "$scope_file")" features)" == '["embedded-messaging","mobile-inbox","push-notifications","sdk-initialization"]' &&
      "$(stat -f '%Lp' "$scope_file")" == 600 &&
      "$(field "$recorded" next.kind)" == choose_bundle ]]; then
  ok "Mobile Inbox and Embedded chosen in Step 0 survive into scope.json, recorded with scope_source ios-step0"
else
  bad "the recorded scope dropped a Step 0 feature or its source" "$(cat "$scope_file" 2>/dev/null)"
fi

FEATURES_ONLY="$(new_app features-only)"
features_offer="$(run_in "$FEATURES_ONLY" status --features event-tracking,user-profiles)"
features_carried="$(run_line "$FEATURES_ONLY" "$(option_by_label "$(field "$features_offer" next.question)" "Use these answers")" 2>/dev/null)"
run_in "$FEATURES_ONLY" answer --field identity-mode --value email >/dev/null
run_in "$FEATURES_ONLY" answer --field region --value EU >/dev/null
features_confirm="$(run_in "$FEATURES_ONLY" answer --field jwt-enabled --value false)"
features_prompt="$(prompt_of "$(field "$features_confirm" next.question)")"
if [[ "$(field "$features_offer" next.question.prompt)" == "Confirmed in the iOS skill: features event-tracking, sdk-initialization, user-profiles. Record these answers instead of asking them again?" &&
      "$(field "$features_carried" next.kind)" == choose_identity &&
      "$(field "$features_confirm" discovery.scope_source)" == ios-step0 &&
      "$(field "$features_confirm" discovery.identity_source)" == "" ]] &&
    grep -qxF "Features: event-tracking,sdk-initialization,user-profiles (the scope confirmed in the iOS skill)" <<< "$features_prompt" &&
    grep -qxF "Identity: email" <<< "$features_prompt"; then
  ok "with only --features, identity is still asked and is not attributed to the iOS skill"
else
  bad "a features-only carry skipped identity or attributed it to Step 0"
fi

REFUSED="$(new_app refused)"
refusals=""
for args in \
    "status --features push-notifications,inbox" \
    "status --features push-notifications,unknown-user-activation" \
    "status --features push-notifications --identity unknown" \
    "status --identity dev@example.com" \
    "question --kind carry_scope --identity Email" \
    "carry-scope --features push-notifications,inbox --confirm" \
    "carry-scope --features push-notifications --identity unknown --confirm"; do
  # shellcheck disable=SC2086
  run_in "$REFUSED" $args >/dev/null 2>"$STATE/refused.err"
  rc=$?
  if [[ "$args" == *--identity* ]]; then
    grep -q -- '--identity takes the values choose_identity records: email, user-id, or unknown-user' "$STATE/refused.err" || rc="$rc(no message)"
  else
    grep -q -- '--features takes the ids choose_features records' "$STATE/refused.err" || rc="$rc(no message)"
  fi
  refusals="$refusals $rc"
done
run_in "$REFUSED" carry-scope --features push-notifications >/dev/null 2>&1
unconfirmed_rc=$?
run_in "$REFUSED" answer --field step0-scope --value carried >/dev/null 2>&1
step0_answer_rc=$?
if [[ "$refusals" == " 2 2 2 2 2 2 2" && "$unconfirmed_rc" -eq 2 && "$step0_answer_rc" -eq 2 ]] &&
    no_workspace_files "$REFUSED"; then
  ok "an unknown feature id or identity value is refused with exit 2, and nothing is written"
else
  bad "an unknown Step 0 value was accepted or left something behind" \
    "exits:$refusals unconfirmed:$unconfirmed_rc step0-scope:$step0_answer_rc"
fi

scope_before="$(shasum < "$scope_file")"
run_in "$TRIAL" carry-scope --features event-tracking --identity email --confirm >/dev/null 2>&1
late_carry_rc=$?
run_in "$TRIAL" question --kind carry_scope --features event-tracking >/dev/null 2>&1
late_question_rc=$?
if [[ "$late_carry_rc" -eq 2 && "$late_question_rc" -eq 2 &&
      "$(shasum < "$scope_file")" == "$scope_before" && ! -e "$TRIAL/.iterable/ios/discovery.json" ]]; then
  ok "once the scope is recorded, carry-scope and its screen are refused and change nothing"
else
  bad "carry-scope ran out of order" "carry:$late_carry_rc question:$late_question_rc"
fi

CHANGED="$(new_app changed)"
changed_offer="$(run_in "$CHANGED" status --features push-notifications --identity user-id)"
run_line "$CHANGED" "$(option_by_label "$(field "$changed_offer" next.question)" "Use these answers")" >/dev/null 2>&1
run_in "$CHANGED" answer --field region --value US >/dev/null
run_in "$CHANGED" answer --field jwt-enabled --value false >/dev/null
identity_changed="$(run_in "$CHANGED" answer --field identity-mode --value email)"
identity_prompt="$(prompt_of "$(field "$identity_changed" next.question)")"
features_changed="$(run_in "$CHANGED" answer --field features --value event-tracking)"
features_changed_prompt="$(prompt_of "$(field "$features_changed" next.question)")"
changed_recorded="$(run_in "$CHANGED" record-scope --from-answers --confirm 2>/dev/null)"
if [[ "$(field "$identity_changed" discovery.identity_source)" == "" &&
      "$(field "$identity_changed" discovery.scope_source)" == ios-step0 &&
      "$(field "$features_changed" discovery.scope_source)" == "" &&
      "$(field "$changed_recorded" scope.source)" == "" &&
      "$(field "$changed_recorded" scope.identity_source)" == "" ]] &&
    grep -qxF "Identity: email" <<< "$identity_prompt" &&
    grep -qxF "Features: push-notifications,sdk-initialization (the scope confirmed in the iOS skill)" <<< "$identity_prompt" &&
    grep -qxF "Features: event-tracking,sdk-initialization" <<< "$features_changed_prompt" &&
    ! grep -q 'iOS skill' "$CHANGED/.iterable/ios/scope.json"; then
  ok "changing a carried answer drops that answer's source and keeps the other's"
else
  bad "a changed answer still claims it came from the iOS skill, or dropped the other's source"
fi

DECLINED="$(new_app declined)"
declined_offer="$(run_in "$DECLINED" status --features push-notifications --identity user-id)"
declined="$(run_line "$DECLINED" "$(option_by_label "$(field "$declined_offer" next.question)" "Change the answers")")"
declined_again="$(run_in "$DECLINED" status --features push-notifications --identity user-id)"
for answer in "feature-push true" "feature-events false" "feature-profiles false" \
    "feature-deep-links false" "feature-more false"; do
  read -r f v <<< "$answer"
  run_in "$DECLINED" answer --field "$f" --value "$v" >/dev/null
done
declined_identity="$(run_in "$DECLINED" status --features push-notifications --identity user-id)"
if [[ "$(field "$declined" next.kind)" == choose_features &&
      "$(field "$declined" discovery.features)" == sdk-initialization &&
      "$(field "$declined_again" next.kind)" == choose_features &&
      "$(field "$declined_identity" next.kind)" == choose_identity &&
      "$(field "$declined_identity" discovery.scope_source)" == "" ]]; then
  ok "Change the answers falls back to the normal screens and is not offered again"
else
  bad "declining the Step 0 answers recorded them or kept offering them" \
    "$(field "$declined" next.kind) $(field "$declined_again" next.kind) $(field "$declined_identity" next.kind)"
fi

PLAIN="$(new_app plain)"
plain="$(run_in "$PLAIN" status)"
run_in "$PLAIN" answer --field features --value push-notifications >/dev/null
plain_identity="$(run_in "$PLAIN" status)"
run_in "$PLAIN" answer --field identity-mode --value email >/dev/null
run_in "$PLAIN" answer --field region --value US >/dev/null
plain_confirm="$(run_in "$PLAIN" answer --field jwt-enabled --value false)"
plain_scope="$(run_in "$PLAIN" record-scope --from-answers --confirm 2>/dev/null)"
if [[ "$(field "$plain" next.kind)" == choose_features &&
      "$(field "$plain_identity" next.kind)" == choose_identity &&
      "$(field "$plain_confirm" next.kind)" == confirm_scope &&
      "$(field "$plain_scope" scope.source)" == "" &&
      "$(node -e 'process.stdout.write(Object.keys(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))).sort().join(","))' "$PLAIN/.iterable/ios/scope.json")" == data_region,features,identity_mode,jwt_enabled ]] &&
    ! grep -q 'skill' <<< "$(prompt_of "$(field "$plain_confirm" next.question)")"; then
  ok "without --features or --identity the flow and the recorded scope are unchanged"
else
  bad "status without Step 0 flags changed the flow or the recorded scope"
fi

RN_ONLY="$(new_app rn-only react-native)"
rn_offer="$(run_in "$RN_ONLY" status --features push-notifications)"
rn_carried="$(run_line "$RN_ONLY" "$(option_by_label "$(field "$rn_offer" next.question)" "Use these answers")" 2>/dev/null)"
if [[ "$(field "$rn_offer" next.kind)" == carry_scope &&
      "$(field "$rn_offer" next.question.prompt)" == "Confirmed in the React Native skill: features push-notifications, sdk-initialization. Record these answers instead of asking them again?" &&
      "$(field "$rn_carried" discovery.scope_source)" == react-native-step0 &&
      "$(field "$rn_carried" next.kind)" == choose_identity ]]; then
  ok "a React Native app with no Android setup gets the same screen, attributed to the React Native skill"
else
  bad "a React Native carry without Android was mislabeled or dropped"
fi

NEXT_TO_ANDROID="$(new_app next-to-android)"
mkdir -p "$NEXT_TO_ANDROID/.iterable"
printf '*\n' > "$NEXT_TO_ANDROID/.iterable/.gitignore"
(
  umask 077
  printf 'ITBL_MOBILE_KEY=mobile-key-canary-1234567890\nITBL_EMAIL=dev@example.com\n' \
    > "$NEXT_TO_ANDROID/.iterable/.env"
)
android_offer="$(run_in "$NEXT_TO_ANDROID" status --features push-notifications --identity user-id)"
android_prompt="$(prompt_of "$(field "$android_offer" next.question)")"
android_imported="$(run_line "$NEXT_TO_ANDROID" "$(option_by_label "$(field "$android_offer" next.question)" "Reuse the Android setup")" 2>/dev/null)"
android_confirm="$(prompt_of "$(field "$android_imported" next.question)")"
if [[ "$(field "$android_offer" next.kind)" == import_android &&
      "$android_prompt" == *"feature scope confirmed in the iOS skill: push-notifications, sdk-initialization. It also proposes the identity user-id confirmed there."* &&
      "$android_prompt" != *"React Native"* &&
      "$(field "$android_offer" next.command)" == *"question --kind import_android --features push-notifications,sdk-initialization --identity user-id" &&
      "$(field "$android_imported" discovery.identity_mode)" == user-id &&
      "$(field "$android_imported" discovery.identity_source)" == ios-step0 &&
      "$(field "$android_imported" discovery.scope_source)" == ios-step0 &&
      "$(field "$android_imported" next.kind)" == confirm_scope ]] &&
    grep -qxF "Identity: user-id (confirmed in the iOS skill)" <<< "$android_confirm"; then
  ok "next to an Android setup, the import carries the iOS skill's features and identity ahead of the Android email"
else
  bad "the Android import mislabeled the iOS skill's answers or let the Android email override the identity"
fi

if [[ ! -s "$STATE/calls" ]]; then
  ok "carrying Step 0 answers makes no network request"
else
  bad "the scope screens called the network" "$(cat "$STATE/calls")"
fi

((FAILED)) && exit 1
exit 0
