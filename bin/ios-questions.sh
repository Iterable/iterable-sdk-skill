#!/usr/bin/env bash
#
# Native iOS questions as data. The agent renders these; it does not rewrite
# them. Every selected option carries the command that records that answer.

IOS_PROOF_ACTOR="${IOS_PROOF_ACTOR:-$BIN/ios-prepare-proof}"

ios_q_arr() {
  local sep="" line
  printf '['
  while IFS= read -r line; do
    printf '%s%s' "$sep" "$(jstr "$line")"
    sep=","
  done
  printf ']'
}

ios_q_opt() {
  local label="$1" description="$2" effect="$3" sep="" command
  shift 3
  printf '{"label":%s,"description":%s,"effect":%s,"relay":"","commands":[' \
    "$(jstr "$label")" "$(jstr "$description")" "$(jstr "$effect")"
  for command in "$@"; do
    printf '%s%s' "$sep" "$(jstr "$command")"
    sep=","
  done
  printf ']}'
}

ios_q_relay_opt() {
  printf '{"label":%s,"description":%s,"effect":%s,"relay":%s,"commands":[]}' \
    "$(jstr "$1")" "$(jstr "$2")" "$(jstr "$3")" "$(jstr "$4")"
}

ios_q_free_text() {
  printf '{"hint":%s,"effect":%s,"command":%s}' \
    "$(jstr "$1")" "$(jstr "$2")" "$(jstr "$3")"
}

ios_q_step0_skill() {
  case "$1" in
    react-native-step0) printf 'React Native skill' ;;
    ios-step0) printf 'iOS skill' ;;
  esac
}

ios_q_import_android() {
  local summary="$1" features="${2:-}" identity="${3:-}"
  local skill="${4:-React Native skill}"
  local scope_note="Feature scope is still asked, because the Android setup does not record it."
  local reuse_description="Copies the Android Mobile and Server-side keys into the ignored iOS workspace and where the app reads them, without printing them."
  local reuse_effect="keys, region, and No JWT recorded for iOS; the feature questions come next"
  local reuse_command="$BIN/ios-provision import-from-android --confirm"
  if [[ -n "$features" ]]; then
    scope_note="Reusing also proposes the feature scope confirmed in the $skill: ${features//,/, }.${identity:+ It also proposes the identity $identity confirmed there.} It is recorded only after you confirm it on the scope screen, and Change the answers there asks it again."
    reuse_description="Copies the Android Mobile and Server-side keys into the ignored iOS workspace and where the app reads them, without printing them, and proposes the features ${features//,/, }${identity:+ and the identity $identity}."
    reuse_effect="keys, region, No JWT, and the proposed features recorded for iOS; the scope confirmation comes next"
    reuse_command="$reuse_command --features $features"
  elif [[ -n "$identity" ]]; then
    scope_note="Reusing also proposes the identity $identity confirmed in the $skill. Feature scope is still asked, because the Android setup does not record it."
    reuse_description="$reuse_description It also proposes the identity $identity."
  fi
  reuse_command="$reuse_command${identity:+ --identity $identity}"
  printf '{"header":"Android","prompt":%s,"selection":"single",' \
    "$(jstr "Reuse the Iterable keys and region the Android setup already recorded for this app?")"
  printf '"context":%s,' "$(printf '%s\n\n%s\n' "$summary" \
    "One Mobile key and one Server-side key serve both platforms. Reusing them skips the region and JWT questions and the key-copy steps; the keys are still validated again for iOS. The Android setup requires Require JWT off, so iOS records No JWT. $scope_note" | ios_q_arr)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Reuse the Android setup")"
  ios_q_opt "Reuse the Android setup" \
    "$reuse_description" \
    "$reuse_effect" \
    "$reuse_command"
  printf ','
  ios_q_opt "Set up iOS separately" \
    "Ask every iOS question and capture keys again, for example when iOS should use a different Iterable project." \
    "nothing imported; the feature questions come next" \
    "$BIN/ios-provision answer --field android-import --value skip"
  printf ']}'
}

ios_q_fix_expo_gitignore() {
  local root="$1"
  printf '{"header":"Expo env","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $root/.gitignore.
2. Add the line .env*.local (the Expo template keeps it under # local env files).
3. Save the file.

Add .env*.local to .gitignore so the Mobile key in .env.local is never committed — done?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
This Expo app reads the Mobile key from EXPO_PUBLIC_ITERABLE_API_KEY in .env.local. The tool writes it there only when git already ignores that file.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Done — check again")"
  ios_q_opt "Done — check again" \
    "Re-reads .gitignore and continues once .env.local is ignored." \
    "status runs again" \
    "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Help me — add it to .gitignore for me" \
    "Appends .env*.local under # local env files in $root/.gitignore, then checks git ignores .env.local." \
    ".gitignore updated; the Mobile key screen comes next" \
    "$BIN/ios-provision ignore-expo-env --confirm"
  printf ','
  ios_q_opt "Stop here" \
    "No key is written into the project." \
    "the Mobile key stays out of the app"
  printf ']}'
}

ios_q_choose_features() {
  printf '{"header":"Features","prompt":%s,"selection":"multiple",' \
    "$(jstr "Which Iterable features should this integration include?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Initialization, user identification, and the Iterable SDK default in-app message handling are included automatically.

Select the product capabilities this app needs. Event tracking and user profiles are grouped like the Android flow. Choose Deep links when the app opens universal links or custom URL schemes, including links opened from push and in-app messages. Choose More features only when you need custom in-app behavior, Mobile Inbox, or Embedded Messages; one compact follow-up will ask which ones.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":['
  local sep="" command
  for command in \
    "$BIN/ios-provision answer --field feature-push --value false" \
    "$BIN/ios-provision answer --field feature-events --value false" \
    "$BIN/ios-provision answer --field feature-profiles --value false" \
    "$BIN/ios-provision answer --field feature-deep-links --value false" \
    "$BIN/ios-provision answer --field feature-more --value false" \
    "$BIN/ios-provision answer --field feature-in-app --clear" \
    "$BIN/ios-provision answer --field feature-inbox --clear" \
    "$BIN/ios-provision answer --field feature-embedded --clear"
  do
    printf '%s%s' "$sep" "$(jstr "$command")"
    sep=","
  done
  printf '],"options":['
  ios_q_opt "Push notifications" \
    "Configure Apple signing, APNs, notification permission, delivery, and account-switch behavior." \
    "records push notifications as selected" \
    "$BIN/ios-provision answer --field feature-push --value true"
  printf ','
  ios_q_opt "Events + user profiles" \
    "Track accepted product actions and send only product-approved profile fields." \
    "records event tracking and user profile updates as selected" \
    "$BIN/ios-provision answer --field feature-events --value true" \
    "$BIN/ios-provision answer --field feature-profiles --value true"
  printf ','
  ios_q_opt "Deep links" \
    "Universal links and custom URL schemes, including links opened from push and in-app messages." \
    "records Iterable deep-link handling as selected" \
    "$BIN/ios-provision answer --field feature-deep-links --value true"
  printf ','
  ios_q_opt "More features" \
    "Choose custom in-app behavior, Mobile Inbox, or Embedded Messages on one follow-up screen." \
    "opens the additional feature selector" \
    "$BIN/ios-provision answer --field feature-more --value true"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "For the basic path, enter: initialization only" \
    "records the Android init-and-identify-only scope" \
    "$BIN/ios-provision answer --field features --value '{{answer}}'")"
}

ios_q_choose_more_features() {
  printf '{"header":"More","prompt":%s,"selection":"multiple",' \
    "$(jstr "Which additional Iterable features should this integration include?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Default in-app message display is already part of an initialized, identified Iterable app. Select In-app customization only when the app needs filtering, deferral, custom rendering, or another behavior beyond that default.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":['
  local sep="" command
  for command in \
    "$BIN/ios-provision answer --field feature-in-app --value false" \
    "$BIN/ios-provision answer --field feature-inbox --value false" \
    "$BIN/ios-provision answer --field feature-embedded --value false"
  do
    printf '%s%s' "$sep" "$(jstr "$command")"
    sep=","
  done
  printf '],"options":['
  ios_q_opt "In-app customization" \
    "Add and test behavior beyond Iterable's default in-app message display." \
    "records custom in-app message behavior as selected" \
    "$BIN/ios-provision answer --field feature-in-app --value true"
  printf ','
  ios_q_opt "Mobile Inbox" \
    "Add inbox loading, display, selection, and the agreed read or delete behavior." \
    "records Mobile Inbox as selected" \
    "$BIN/ios-provision answer --field feature-inbox --value true"
  printf ','
  ios_q_opt "Embedded Messages" \
    "Use the real placement ID and add feature-specific rendering and engagement evidence." \
    "records Embedded Messages as selected" \
    "$BIN/ios-provision answer --field feature-embedded --value true"
  printf ']}'
}

ios_q_choose_identity() {
  printf '{"header":"Identity","prompt":%s,"selection":"single",' \
    "$(jstr "How should Iterable identify this app's users?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Use an identity already owned by the app when one exists. If the app does not know a user yet, choose Unknown user; do not invent an identifier from developer or device account details. An email-entry screen is identification, not authentication.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Email" \
    "Use the account email already supplied by the app with setEmail." \
    "records email identity" \
    "$BIN/ios-provision answer --field identity-mode --value email"
  printf ','
  ios_q_opt "User ID" \
    "Use the app's stable account identifier with setUserId." \
    "records user-ID identity" \
    "$BIN/ios-provision answer --field identity-mode --value user-id"
  printf ','
  ios_q_opt "Unknown user" \
    "Start with Iterable Unknown User Activation. Reconcile identity later only if and when the app learns a real email or user ID." \
    "records unknown-user identity and enables Unknown User Activation" \
    "$BIN/ios-provision answer --field identity-mode --value unknown-user"
  printf ','
  ios_q_opt "I'm not sure — help me decide" \
    "Shows the one question that decides it, with the answer for each case." \
    "opens the identity guide; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_identity"
  printf ']}'
}

ios_q_choose_region() {
  printf '{"header":"Region","prompt":%s,"selection":"single",' \
    "$(jstr "Which Iterable project region does this app use?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
The Mobile API key and SDK data region must match the selected Iterable project. A US key cannot be treated as an EU key, or the reverse.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "US project" \
    "Use the standard Iterable US API endpoints." \
    "records US as the data region" \
    "$BIN/ios-provision answer --field region --value US"
  printf ','
  ios_q_opt "EU project" \
    "Configure IterableDataRegion.EU and use the EU project key." \
    "records EU as the data region" \
    "$BIN/ios-provision answer --field region --value EU"
  printf ','
  ios_q_opt "I'm not sure — help me find out" \
    "Shows how to read the region from the project address, and what to do with no project yet." \
    "opens the region guide; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_region"
  printf ']}'
}

ios_q_jwt_keys_url() {
  if [[ "${1:-}" == EU ]]; then
    printf 'https://app.eu.iterable.com/settings/apiKeys'
  else
    printf 'https://app.iterable.com/settings/apiKeys'
  fi
}

ios_q_choose_jwt() {
  printf '{"header":"JWT","prompt":%s,"selection":"single",' \
    "$(jstr "Unless your app already has a backend that issues user-specific Iterable JWTs, choose No JWT. Should the Mobile key you create or pick in a later step require JWT?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
You do not need a Mobile API key yet. A later step creates one in Iterable, or picks the one you already have, and its Require JWT setting must match this answer.

Choose JWT only when the app already runs a backend that issues user-specific Iterable JWTs. The app then asks that backend for each token and never mints one itself. A new app without such a backend should choose No JWT.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I don't have a Mobile key yet — help me")"
  ios_q_opt "I don't have a Mobile key yet — help me" \
    "Records No JWT, right for an app without a JWT backend. The next Iterable step walks you through creating the Mobile key with Require JWT Off." \
    "records JWT as disabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value false"
  printf ','
  ios_q_opt "I already have a Mobile key — check its setting" \
    "Shows where to read the existing key's Require JWT setting, then you answer from what it shows." \
    "opens the steps for reading the existing Mobile key's JWT setting" \
    "$BIN/ios-provision answer --field jwt-check --value true"
  printf ','
  ios_q_opt "I'm not sure — help me decide" \
    "Explains the one fact that decides it; for most apps the answer is No JWT." \
    "opens the JWT guide; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_jwt"
  printf ','
  ios_q_opt "JWT required — we run a JWT backend" \
    "Only when a backend already issues user-specific Iterable JWTs; the integration adds an auth handler that calls it." \
    "records JWT as enabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value true"
  printf ']}'
}

ios_q_check_jwt() {
  local region="${1:-}" url
  url="$(ios_q_jwt_keys_url "$region")"
  printf '{"header":"JWT check","prompt":%s,"selection":"single",' \
    "$(jstr "Read the setting on the Mobile key this app will use:
1. Open $url (or go to Integrations > API Keys).
2. Find the key whose type is Mobile. If there are several, use the one this app will ship with.
3. Read its JWT column, or open the key and read Require JWT.
4. Answer below with what it shows.

In Iterable → Integrations → API Keys, read your Mobile key's Require JWT setting — is it on or off?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Nothing is copied here; the key itself is captured securely in a later step. If there is no Mobile key, go back and choose for the new one.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Require JWT is off" \
    "The existing Mobile key does not require JWT." \
    "records JWT as disabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value false"
  printf ','
  ios_q_opt "Require JWT is on" \
    "The existing Mobile key requires JWT, so the app needs a backend that issues user-specific Iterable JWTs." \
    "records JWT as enabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value true"
  printf ','
  ios_q_opt "Show these steps again" \
    "Re-prints the steps, with the link, without recording anything." \
    "the JWT check stays open" \
    "$BIN/ios-provision question --kind check_jwt"
  printf ','
  ios_q_opt "I don't have a Mobile key — No JWT" \
    "Records No JWT; the next Iterable step walks you through creating the key with Require JWT Off." \
    "records JWT as disabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value false"
  printf ']}'
}

ios_q_carry_scope() {
  local features="$1" identity="$2" source="$3" skill confirmed="" skipped remaining
  skill="$(ios_q_step0_skill "$source")"
  [[ -z "$features" ]] || confirmed="features ${features//,/, }"
  [[ -z "$identity" ]] || confirmed="${confirmed:+$confirmed; }identity $identity"
  if [[ -n "$features" && -n "$identity" ]]; then
    skipped="the feature and identity questions"
    remaining="Region and JWT are"
  elif [[ -n "$features" ]]; then
    skipped="the feature questions"
    remaining="Identity, region, and JWT are"
  else
    skipped="the identity question"
    remaining="The feature questions, region, and JWT are"
  fi
  printf '{"header":"Scope","prompt":%s,"selection":"single",' \
    "$(jstr "Confirmed in the $skill: $confirmed. Record these answers instead of asking them again?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
The $skill already asked these with the app in view. Recording them skips $skipped here.

$remaining still asked, and the final scope screen shows every answer, marked with where it came from, before anything is confirmed.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Use these answers")"
  ios_q_opt "Use these answers" \
    "Proposes exactly the answers above, attributed to the $skill. Nothing is confirmed until the final scope screen." \
    "the answers above are proposed from the $skill; the remaining scope questions come next" \
    "$BIN/ios-provision carry-scope${features:+ --features $features}${identity:+ --identity $identity} --confirm"
  printf ','
  ios_q_opt "Change the answers" \
    "Asks $skipped here instead; nothing from the $skill is recorded." \
    "nothing proposed from the $skill; the scope questions come next" \
    "$BIN/ios-provision answer --field step0-scope --value skip"
  printf ']}'
}

ios_q_confirm_scope() {
  local features="$1" identity="$2" region="$3" jwt="$4" source="${5:-}"
  local identity_source="${6:-}" origin="" identity_origin="" skill
  skill="$(ios_q_step0_skill "$source")"
  [[ -z "$skill" ]] || origin=" (the scope confirmed in the $skill)"
  skill="$(ios_q_step0_skill "$identity_source")"
  [[ -z "$skill" ]] || identity_origin=" (confirmed in the $skill)"
  local next_description="secure Mobile API-key capture"
  local option_description="Writes the confirmed non-secret decisions to the ignored iOS workspace, then continues to Mobile API-key setup."
  local option_effect="scope.json recorded; Mobile API-key setup becomes the next state"
  if [[ ",$features," == *,push-notifications,* ]]; then
    next_description="Apple and APNs prerequisite setup; Iterable credentials come afterward"
    option_description="Writes the confirmed non-secret decisions to the ignored iOS workspace, then starts the Apple and APNs prerequisite flow."
    option_effect="scope.json recorded; Apple and APNs setup becomes the next state"
  fi
  printf '{"header":"Confirm","prompt":%s,"selection":"single",' \
    "$(jstr "Use this Iterable integration scope?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Features: $features$origin
Identity: $identity$identity_origin
Region: $region
JWT required: $jwt

Recording this scope unlocks $next_description. It does not edit the app or change Apple or Iterable by itself.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Record this scope and continue")"
  ios_q_opt "Record this scope and continue" \
    "$option_description" \
    "$option_effect" \
    "$BIN/ios-provision record-scope --from-answers --confirm"
  printf ','
  ios_q_opt "Change the answers" \
    "Clears the proposed answers and returns to feature selection. No confirmed scope exists yet." \
    "proposed scope cleared" \
    "$BIN/ios-provision answer --clear"
  printf ','
  ios_q_opt "Stop here" \
    "Nothing is recorded as confirmed and the app remains unchanged." \
    "scope remains unconfirmed"
  printf ']}'
}

ios_q_configure_iterable() {
  local region="$1" jwt="$2"
  printf '{"header":"Mobile key","prompt":%s,"selection":"single",' \
    "$(jstr "The Mobile API key comes from $(ios_q_jwt_keys_url "$region") — how should we continue with it?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
This integration needs a real client-side Mobile API key from the $region project with JWT set to $jwt.

Iterable shows a new key once. Copy it in the dashboard, but never paste it into this conversation. The capture command reads the clipboard into ignored mode-0600 files and clears it.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I don't have a Mobile key yet — show me how")"
  ios_q_opt "I don't have a Mobile key yet — show me how" \
    "Shows the exact Iterable steps to create it. You do the browser clicks, then the capture command moves the copied key into mode-0600 local files." \
    "enters the guided Mobile-key step; no Iterable change is made yet" \
    "$BIN/ios-provision record-iterable-setup --driver guided --confirm"
  printf ','
  ios_q_opt "The Mobile key is copied" \
    "Capture the copied value securely, clear the clipboard, then validate its key type and region." \
    "the Mobile key enters the ignored workspace; validation becomes next" \
    "$BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  printf ','
  ios_q_relay_opt "I'll use my terminal" \
    "Finish the same browser step yourself, then run the secure capture command locally." \
    "the agent waits; no key enters the conversation" \
    "1. Open $(ios_q_jwt_keys_url "$region") and create a Mobile key with Require JWT $([[ "$jwt" == true ]] && echo On || echo Off). 2. Copy it. 3. Run: $BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  printf ','
  ios_q_opt "I already have a Mobile key — show me how to copy it" \
    "Shows where to copy an existing Mobile key with the matching JWT setting, then captures it." \
    "opens the steps for reusing an existing Mobile key; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_copy_mobile_key"
  printf ']}'
}

ios_q_capture_iterable() {
  local region="$1" jwt="$2"
  local dashboard_url="https://app.iterable.com/settings/apiKeys"
  local jwt_label="Off"
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/settings/apiKeys"
  [[ "$jwt" != true ]] || jwt_label="On"
  printf '{"header":"Mobile key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url (or go to Integrations > API Keys).
2. Select New API Key, then choose Mobile.
3. Set Require JWT to $jwt_label.
4. Create the key and copy it.

In Iterable → Integrations → API Keys, create a Mobile key with Require JWT $jwt_label and copy it — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 1 of 1 — Create the Mobile API key

Already have a Mobile key with Require JWT $jwt_label? Copy that one instead of creating another.

Iterable shows a new key once. Do not paste it into this conversation. The capture option reads it from the clipboard into ignored mode-0600 files, clears the clipboard, and prints only a status message.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied the Mobile key")"
  ios_q_opt "I've copied the Mobile key" \
    "Capture the copied value securely and continue to live key validation." \
    "the Mobile key enters the ignored workspace; validation becomes next" \
    "$BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  printf ','
  ios_q_opt "Help me — I can't create the key" \
    "Shows the common blockers: permissions, region, key type, and a key shown only once." \
    "opens the Mobile-key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_mobile_key"
  printf ','
  ios_q_opt "I already have a Mobile key — show me how to copy it" \
    "Shows where to copy an existing Mobile key with Require JWT $jwt_label, then captures it." \
    "opens the steps for reusing an existing Mobile key; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_copy_mobile_key"
  printf ','
  ios_q_relay_opt "I'll finish in my terminal" \
    "Complete the same browser step and run the secure capture command yourself." \
    "the agent waits; no key enters the conversation" \
    "1. Open $dashboard_url and copy a Mobile key with Require JWT $jwt_label. 2. Run: $BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  printf ']}'
}

ios_q_configure_server() {
  local region="$1"
  local verification_only="${2:-false}"
  local dashboard_url="https://app.iterable.com/settings/apiKeys"
  local opening
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/settings/apiKeys"
  if [[ "$verification_only" == true ]]; then
    opening="An existing iOS integration was detected. We are preparing only the separate verification credential needed to read its Iterable state and send one marked proof push; Apple, APNs, Mobile-key, and app setup will not be replayed."
  else
    opening="The Mobile key is ready. We are now preparing the separate verification credential so the completed integration can be proved without returning to setup later."
  fi
  
  printf '{"header":"Server key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url (or go to Integrations > API Keys).
2. Select New API Key.
3. Choose Server-side.
4. Name it for local SDK verification, create it, and copy the value.

In Iterable → Integrations → API Keys, create a Server-side key and copy it — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
$opening

This Server-side key lets the verifier read the Iterable profile and device registration for the selected test identity and lets the sender create a campaign-free proof push. It never enters the iOS app or Xcode configuration.

Already have a Server-side key for this project? Copy that one instead of creating another.

Iterable shows a new key once. Do not paste it into this conversation. The capture option reads it from the clipboard into the ignored mode-0600 verification workspace and clears the clipboard.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied the Server-side key")"
  ios_q_opt "I've copied the Server-side key" \
    "Capture the copied value securely and continue to live key validation." \
    "the Server-side key enters only the ignored verification workspace; validation becomes next" \
    "$BIN/ios-provision capture-server --confirm"
  printf ','
  ios_q_opt "Help me — I can't create the key" \
    "Shows the common blockers: permissions, region, key type, and a key shown only once." \
    "opens the Server-side key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_server_key"
  printf ','
  ios_q_opt "I already have a Server-side key — show me how to copy it" \
    "Shows where to copy an existing Server-side key, then captures it." \
    "opens the steps for reusing an existing Server-side key; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_copy_server_key"
  printf ','
  ios_q_opt "Stop before verification credentials" \
    "Keep application provisioning incomplete without capturing a Server-side key." \
    "verification credential remains missing"
  printf ']}'
}

ios_q_replace_mobile_key() {
  local region="$1" jwt="$2" reason="$3"
  local dashboard_url="https://app.iterable.com/settings/apiKeys" jwt_label="Off"
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/settings/apiKeys"
  [[ "$jwt" != true ]] || jwt_label="On"
  printf '{"header":"Mobile key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url (or go to Integrations > API Keys).
2. Copy an existing Mobile key, or select New API Key and choose Mobile.
3. Require JWT must be $jwt_label for this integration.
4. Copy the key. Do not paste it into this conversation.

In Iterable → Integrations → API Keys, copy a working Mobile key (Require JWT $jwt_label) to replace the rejected one — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
$reason

The replace option reads the clipboard into the ignored mode-0600 files, keeps the Server-side key, clears the clipboard, and validates again next.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied the correct Mobile key")"
  ios_q_opt "I've copied the correct Mobile key" \
    "Replace the captured value securely, then validate it again." \
    "the rejected Mobile key is replaced; validation becomes next" \
    "$BIN/ios-provision capture-mobile --replace --region $region --jwt-enabled $jwt --confirm"
  printf ','
  ios_q_opt "Validate the same key again" \
    "Use this only after changing the key's settings in Iterable, such as its JWT requirement." \
    "the same key is probed again" \
    "$BIN/ios-provision validate-mobile"
  printf ','
  ios_q_opt "Help me — it keeps failing" \
    "Shows the common causes: wrong key type, wrong region, or the wrong JWT setting." \
    "opens the Mobile-key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_mobile_key --replace"
  printf ','
  ios_q_opt "Stop here" \
    "Keep the rejected key out of the app; Iterable setup remains incomplete." \
    "Mobile key remains rejected"
  printf ']}'
}

ios_q_replace_server_key() {
  local region="$1" reason="$2"
  local dashboard_url="https://app.iterable.com/settings/apiKeys"
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/settings/apiKeys"
  printf '{"header":"Server key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url (or go to Integrations > API Keys).
2. Select New API Key.
3. Choose Server-side.
4. Name it for local SDK verification, create it, and copy the value.

In Iterable → Integrations → API Keys, create a new Server-side key and copy it to replace the rejected one — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
$reason

Iterable shows a new key once. Do not paste it into this conversation. The replace option swaps only the verification credential in the ignored mode-0600 workspace, clears the clipboard, and validates again next. It never enters the app.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied a new Server-side key")"
  ios_q_opt "I've copied a new Server-side key" \
    "Replace the captured verification key securely, then validate it again." \
    "the rejected Server-side key is replaced; validation becomes next" \
    "$BIN/ios-provision capture-server --replace --confirm"
  printf ','
  ios_q_opt "Validate the same key again" \
    "Use this only if the earlier rejection may have been temporary." \
    "the same key is probed again" \
    "$BIN/ios-provision validate-server"
  printf ','
  ios_q_opt "Help me — it keeps failing" \
    "Shows the common causes: wrong key type, wrong region, or a deleted key." \
    "opens the Server-side key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_server_key --replace"
  printf ','
  ios_q_opt "Stop here" \
    "Verification cannot read Iterable or send the proof push until a working key is captured." \
    "Server-side key remains rejected"
  printf ']}'
}

ios_q_choose_bundle() {
  local bundle_id="${1:-}" app_name="${2:-}" source="${3:-}" quoted_name detected
  local where="the app target's effective build settings"
  [[ "$source" != project ]] || where="the project file"
  printf '{"header":"Bundle ID","prompt":%s,"selection":"single",' \
    "$(jstr "Which explicit iOS Bundle ID should this integration use?")"
  if [[ -n "$bundle_id" && -n "$app_name" ]]; then
    detected="Detected from $where:
   Bundle ID: $bundle_id
   Product name: $app_name
"
  else
    detected="No single application target could be read from this project. Open it in Xcode, select the app target, and read General > Identity > Bundle Identifier.
"
  fi
  printf '"context":%s,' "$(ios_q_arr <<EOF
$detected
Use the exact effective bundle identifier for the application target. Apple App ID, signing, Iterable mobile app, APNs credential, installed build, and verifier must all use the same value. The product name becomes the Iterable mobile app name.
EOF
)"
  if [[ -n "$bundle_id" && -n "$app_name" ]]; then
    printf -v quoted_name '%q' "$app_name"
    printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
      "$(jstr "Use the detected app target")"
    ios_q_opt "Use the detected app target" \
      "Record $bundle_id as \"$app_name\" for every later Apple and Iterable step." \
      "target.json recorded; the Apple setup choice becomes next" \
      "$BIN/ios-provision record-target --bundle-id $bundle_id --name $quoted_name --confirm"
    printf ','
    ios_q_opt "I'm not sure — help me pick the target" \
      "Shows how to find the right app target and its Bundle Identifier in Xcode." \
      "opens the Bundle ID guide; nothing is recorded yet" \
      "$BIN/ios-provision question --kind help_bundle"
  else
    printf '"requires":[],"recommended":null,"before_commands":[],"options":['
    ios_q_opt "I don't know the Bundle ID — help me find it" \
      "Shows where Xcode lists it, then you answer with the exact value." \
      "opens the Bundle ID guide; nothing is recorded yet" \
      "$BIN/ios-provision question --kind help_bundle"
    printf ','
    ios_q_relay_opt "I'll look it up in Xcode myself" \
      "Read it in Xcode, then answer with it in the free-text field." \
      "the agent waits for the Bundle ID" \
      "1. In Xcode, select the app target, not an extension or test target. 2. Open General > Identity and copy Bundle Identifier. 3. Answer this same question with that exact value."
  fi
  printf '],'
  printf '"free_text":%s}' "$(ios_q_free_text \
    "Enter the exact explicit Bundle ID, for example com.example.app" \
    "records that iOS target, with its product name read from the Xcode project" \
    "$BIN/ios-provision record-target --bundle-id '{{answer}}' --confirm")"
}

ios_q_choose_apple_setup() {
  printf '{"header":"Apple setup","prompt":%s,"selection":"single",' \
    "$(jstr "How should the Apple push prerequisites be completed?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Choose the path that matches this application. With the first two, you or the Account Holder or Admin do the Apple Developer clicks and the tool records what you confirm. With an App Store Connect Team API key, the tool registers the App ID and enables Push Notifications itself, after showing you the exact plan.

Every path ends with the same exact Bundle ID, Push Notifications capability, and an available APNs authentication key. The later delivery test still decides whether push works.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I don't have it set up yet — walk me through it")"
  ios_q_opt "I don't have it set up yet — walk me through it" \
    "Walks the App ID, Push Notifications, and APNs key steps in Apple Developer one screen at a time. Steps already done take one click." \
    "records the guided walkthrough; its first screen is next" \
    "$BIN/ios-provision record-apple-setup --strategy guided-manual --confirm"
  printf ','
  ios_q_opt "It's already set up — I'll confirm it" \
    "The app already sends push: confirm its App ID, Push Notifications, signing, and APNs key, then reuse them." \
    "records the existing-ready strategy without reading or changing Apple" \
    "$BIN/ios-provision record-apple-setup --strategy existing-ready --confirm"
  printf ','
  ios_q_opt "I have an App Store Connect Team API key (Admin) — set up the App ID and Push for me" \
    "Uses your Team key to read the App ID, then shows exactly what it will create before changing anything. The APNs key still comes from you." \
    "records the Team-key path; the key and Issuer ID are asked next" \
    "$BIN/ios-provision record-apple-setup --strategy team-key --confirm"
  printf ']}'
}

ios_q_asc_walk_opt() {
  ios_q_opt "Walk me through it in Apple Developer instead" \
    "Leave the Team-key path and do the App ID and Push Notifications steps yourself, one screen at a time." \
    "the guided Apple walkthrough starts at step 1 of 3" \
    "$BIN/ios-provision clear-apple-setup --confirm" \
    "$BIN/ios-provision record-apple-setup --strategy guided-manual --confirm" \
    "$BIN/ios-provision record-apple-step --step start --confirm"
}

ios_q_asc_key() {
  printf '{"header":"ASC key","prompt":%s,"selection":"single",' \
    "$(jstr "This is your App Store Connect API key, not the APNs key. Both download as AuthKey_<KEYID>.p8.
1. Open https://appstoreconnect.apple.com/access/integrations/api and select Team Keys.
2. Use a key whose access is Admin or App Manager; Individual keys cannot register App IDs.
3. Find the AuthKey_<KEYID>.p8 you downloaded when that key was created. The Key ID is read from its name.

Open App Store Connect → Users and Access → Integrations, find this Team key's .p8, and answer with its path — which file?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Only the path enters the conversation, never the contents of the file. The tool keeps the path in an ignored mode-0600 file, restricts the key to mode 0600, and does not copy it.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I don't have a Team API key — help me" \
    "Shows how an Admin creates a Team key and where the Issuer ID is." \
    "opens the App Store Connect key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_asc_key"
  printf ','
  ios_q_asc_walk_opt
  printf ','
  ios_q_opt "Choose another path" \
    "Return to the Apple setup selector." \
    "removes only the local Apple strategy" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the absolute path to the App Store Connect AuthKey_<KEYID>.p8 (the path only)" \
    "records the App Store Connect key path; the Issuer ID is next" \
    "$BIN/ios-provision record-asc-key --file '{{answer}}' --confirm")"
}

ios_q_asc_issuer() {
  printf '{"header":"Issuer ID","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open https://appstoreconnect.apple.com/access/integrations/api.
2. Under Team Keys, copy the Issuer ID shown above the list. It looks like 57246542-96fe-1a63-e053-0824d011072a.

Copy the Issuer ID for this Team key — what is it?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
The Issuer ID identifies your team to App Store Connect. It is not secret, but it must belong to the same team as the key.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I don't have the Issuer ID — help me" \
    "Shows where the Team Keys list and its Issuer ID live, and who can see them." \
    "opens the App Store Connect key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_asc_key"
  printf ','
  ios_q_asc_walk_opt
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the Issuer ID, for example 57246542-96fe-1a63-e053-0824d011072a" \
    "records the Issuer ID; the tool then reads the App ID" \
    "$BIN/ios-provision record-asc-key --issuer-id '{{answer}}' --confirm")"
}

ios_q_asc_plan() {
  local bundle_id="$1" actions="$3" name="$4" steps="" n=1
  if [[ ",$actions," == *,create-bundle-id,* ]]; then
    steps="$n. Register the explicit App ID $bundle_id, named $name, for iOS."
    n=$((n + 1))
  fi
  if [[ ",$actions," == *,enable-push,* ]]; then
    steps="${steps:+$steps
}$n. Enable Push Notifications on $bundle_id."
  fi
  printf '{"header":"ASC plan","prompt":%s,"selection":"single",' \
    "$(jstr "App Store Connect will make exactly these changes:
$steps

Set up $bundle_id with exactly this plan?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Nothing else is created, changed, or revoked: no certificates, provisioning profiles, or keys. The tool reads the App ID back afterwards. Enabling a capability can invalidate provisioning profiles for this App ID; Xcode automatic signing regenerates them on the next device build.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Apply this plan")"
  ios_q_opt "Apply this plan" \
    "Make only the listed changes in App Store Connect, then read them back." \
    "the App ID and Push Notifications are created and verified; the APNs key step is next" \
    "$BIN/ios-provision asc-apply --confirm"
  printf ','
  ios_q_asc_walk_opt
  printf ','
  ios_q_opt "Choose another path" \
    "Change nothing in App Store Connect and return to the Apple setup selector." \
    "removes only the local Apple strategy" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf ']}'
}

ios_q_asc_rejected() {
  local reason="$2"
  printf '{"header":"ASC key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open https://appstoreconnect.apple.com/access/integrations/api and check the key is under Team Keys, active, with Admin or App Manager access.
2. Check the Issuer ID above that list matches the one you entered.
3. Check the .p8 is this App Store Connect key, not the APNs key; both are named AuthKey_<KEYID>.p8.

Check the key, Issuer ID, and access in App Store Connect — then try again?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
$reason
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Try again" \
    "Read the App ID again with the same key and Issuer ID." \
    "the read is repeated; nothing is changed" \
    "$BIN/ios-provision asc-read"
  printf ','
  ios_q_opt "Enter a different Issuer ID" \
    "Forget the recorded Issuer ID and ask for it again." \
    "the Issuer ID question is next" \
    "$BIN/ios-provision record-asc-key --clear --confirm"
  printf ','
  ios_q_opt "I'm not sure what is wrong — help me" \
    "Shows how Team keys, their access, and the Issuer ID fit together." \
    "opens the App Store Connect key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_asc_key"
  printf ','
  ios_q_asc_walk_opt
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the path to a different App Store Connect AuthKey_<KEYID>.p8" \
    "records the new key path and reads again" \
    "$BIN/ios-provision record-asc-key --file '{{answer}}' --confirm")"
}

ios_q_asc_conflict() {
  local bundle_id="$1" reason="$2"
  printf '{"header":"App ID taken","prompt":%s,"selection":"single",' \
    "$(jstr "1. Apple Bundle IDs are unique across all teams, so another team may already own $bundle_id.
2. If your organization owns it on another team, use that team's key or walk through Apple Developer signed in to that team.
3. Otherwise change the Bundle Identifier in Xcode, for example by adding a suffix, and answer with the new value.

Check who owns $bundle_id, or choose a new Bundle ID — which one?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
$reason
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Help me — what does this mean" \
    "Shows the common App ID blockers, including an identifier another team owns." \
    "opens the App ID help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_app_id --bundle-id $bundle_id"
  printf ','
  ios_q_asc_walk_opt
  printf ','
  ios_q_opt "Choose another path" \
    "Return to the Apple setup selector." \
    "removes only the local Apple strategy" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the new Bundle ID you set in Xcode" \
    "records the new iOS target; Apple setup restarts for it" \
    "$BIN/ios-provision record-target --bundle-id '{{answer}}' --confirm")"
}

ios_q_help_asc_key() {
  printf '{"header":"ASC key help","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open https://appstoreconnect.apple.com/access/integrations/api. If it offers Request Access, the Account Holder must request API access once.
2. Select Team Keys, then + to generate a key. Name it, and choose Admin access; App Manager also works for App IDs.
3. Select Generate, then Download API Key. Apple allows this download once; keep AuthKey_<KEYID>.p8 outside the repository.
4. Note the Issuer ID shown above the Team Keys list.
5. Individual keys cannot use the provisioning endpoints, and only an Account Holder or Admin can create Team keys.

Create or find a Team key in App Store Connect — then continue with its .p8?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
This key only manages App IDs and capabilities here. It is different from the APNs key, which still comes from Apple Developer > Keys.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_back_opt "Back to the App Store Connect key step" "$BIN/ios-provision status"
  printf ','
  ios_q_asc_walk_opt
  printf ','
  ios_q_opt "Choose another path" \
    "Return to the Apple setup selector." \
    "removes only the local Apple strategy" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf ']}'
}

ios_q_confirm_existing_apple() {
  local bundle_id="$1"
  printf '{"header":"Apple ready","prompt":%s,"selection":"single",' \
    "$(jstr "Read the existing configuration back before continuing:
1. Confirm the application target uses the exact Bundle ID $bundle_id.
2. In Apple Developer, confirm that explicit App ID has Push Notifications enabled.
3. Confirm the selected Apple team and signing workflow can produce the correct aps-environment entitlement.
4. Confirm the account owner has retained a suitable APNs authentication key and its one-time .p8 download, or can deliberately create one.

In Apple Developer, check that $bundle_id has Push Notifications and an APNs key whose .p8 you still hold — all true?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Recording this checklist is developer-observed evidence. It makes no Apple request and does not prove APNs or Iterable delivery.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Record existing setup" \
    "Record the values you read back and continue to secure APNs-key import." \
    "records developer-observed Apple readiness; nothing is called tool-verified" \
    "$BIN/ios-provision record-apple-readiness --strategy existing-ready --confirm"
  printf ','
  ios_q_opt "I'm not sure it's all there — walk me through it" \
    "Switch to the step-by-step walkthrough; steps that are already done take one click each." \
    "the guided Apple walkthrough starts at step 1 of 3" \
    "$BIN/ios-provision clear-apple-setup --confirm" \
    "$BIN/ios-provision record-apple-setup --strategy guided-manual --confirm" \
    "$BIN/ios-provision record-apple-step --step start --confirm"
  printf ','
  ios_q_relay_opt "I'll check Apple myself first" \
    "Check it yourself, then come back and record it." \
    "Apple readiness remains incomplete until the read-back is done" \
    "1. In Xcode, confirm the app target Bundle Identifier is $bundle_id. 2. At https://developer.apple.com/account/resources/identifiers/list, open $bundle_id and confirm Push Notifications is ticked. 3. At https://developer.apple.com/account/resources/authkeys/list, confirm an APNs key exists whose .p8 you still hold. Then answer this same question."
  printf ','
  ios_q_opt "Choose another path" \
    "Clear this local strategy and return to the Apple setup selector." \
    "removes only the local Apple strategy and its readiness record" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf ']}'
}

ios_q_confirm_manual_apple() {
  local bundle_id="$1"
  printf '{"header":"Apple setup","prompt":%s,"selection":"single",' \
    "$(jstr "Push for $bundle_id needs three things in Apple Developer. The walkthrough shows one at a time, with the exact clicks:
1. Register the explicit App ID $bundle_id.
2. Enable Push Notifications on it.
3. Reuse or create an APNs authentication key and keep its .p8 file.

Set up $bundle_id in Apple Developer (App ID, Push Notifications, APNs key) one step at a time?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Each needs an Account Holder or Admin of the Apple team. If one already did all three for this exact Bundle ID, record it directly instead. The tool records your answers as developer-confirmed; it never signs in to Apple.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I don't have these yet — walk me through it")"
  ios_q_opt "I don't have these yet — walk me through it" \
    "Show the three Apple Developer steps one at a time, starting with the App ID." \
    "the guided Apple walkthrough starts at step 1 of 3" \
    "$BIN/ios-provision record-apple-step --step start --confirm"
  printf ','
  ios_q_opt "Record manual setup" \
    "An Account Holder or Admin already did all three steps for this exact Bundle ID." \
    "records developer-observed Apple readiness; nothing is called tool-verified" \
    "$BIN/ios-provision record-apple-readiness --strategy guided-manual --confirm"
  printf ','
  ios_q_relay_opt "Ask my Account Holder or Admin to do it" \
    "Hand the three steps to the account owner and come back when they are done." \
    "nothing changes until the account owner finishes" \
    "Send the Account Holder or an Admin of the Apple team these steps for $bundle_id: 1. At https://developer.apple.com/account/resources/identifiers/list, register the explicit App ID $bundle_id. 2. Tick Push Notifications on it, Save, Confirm. 3. At https://developer.apple.com/account/resources/authkeys/list, create or reuse an APNs key and send the .p8 through a secure channel. When they are done, answer this same question with Record manual setup."
  printf ','
  ios_q_opt "Choose another path" \
    "Clear this local strategy and return to the Apple setup selector." \
    "removes only the local Apple strategy and its readiness record" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf ']}'
}

ios_q_apple_step_app_id() {
  local bundle_id="$1" app_name="$2"
  printf '{"header":"Apple 1 of 3","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open https://developer.apple.com/account/resources/identifiers/list and sign in as an Account Holder or Admin.
2. Look for $bundle_id in the list. If it is there, this step is already done.
3. Otherwise select + next to Identifiers, choose App IDs, Continue, then App, Continue.
4. Description: $app_name
5. Bundle ID: choose Explicit and enter $bundle_id exactly.
6. Under Capabilities, tick Push Notifications (leave its Configure button alone).
7. Select Continue, then Register.

In Apple Developer → Identifiers, register the explicit App ID $bundle_id (or find it) — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 1 of 3 — Register the explicit App ID

A Simulator-only build does not make Xcode register this App ID, so for a new app it is usually not there yet. A Simulator still needs it, with Push Notifications enabled: without Push, APNs refuses every push with TopicDisallowed while Iterable still reports the send as accepted, so nothing arrives and nothing says why. Tick Push Notifications while registering; step 2 then only reads it back.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Done — the App ID exists")"
  ios_q_opt "Done — the App ID exists" \
    "The explicit App ID $bundle_id is registered, whether you just created it or it was already there." \
    "step 1 recorded as developer-confirmed; step 2 of 3 is next" \
    "$BIN/ios-provision record-apple-step --step app-id --confirm"
  printf ','
  ios_q_opt "Help me — I can't find or create it" \
    "Shows the common blockers: Apple role, wrong team, an identifier another team owns." \
    "opens the App ID help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_app_id --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Show the steps again" \
    "Re-prints this step, with its numbered clicks and link, without recording anything." \
    "step 1 stays open" \
    "$BIN/ios-provision question --kind apple_step_app_id --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Choose another path" \
    "Leave the walkthrough and return to the Apple setup selector." \
    "removes only the local Apple strategy and walkthrough progress" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf ']}'
}

ios_q_apple_step_push() {
  local bundle_id="$1"
  printf '{"header":"Apple 2 of 3","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open https://developer.apple.com/account/resources/identifiers/list and select $bundle_id.
2. Under Capabilities, tick Push Notifications. Leave its Configure button alone; the APNs key in step 3 replaces certificates.
3. Select Save, then Confirm in the Modify App Capabilities dialog.
4. Reopen $bundle_id and read back that Push Notifications is ticked.

In Apple Developer → Identifiers → $bundle_id, tick Push Notifications and save — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 2 of 3 — Enable Push Notifications on $bundle_id

If you ticked Push Notifications while registering in step 1, this is only a read-back: open the identifier and confirm the tick. Without it, APNs answers TopicDisallowed and no push arrives even though Iterable accepts the send; ios-verify check-apple asks Apple directly.

Changing a capability can invalidate provisioning profiles that use this App ID. Xcode automatic signing regenerates them on the next device build; with manual signing, regenerate the profile. Simulator builds are unaffected.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Done — Push Notifications is on")"
  ios_q_opt "Done — Push Notifications is on" \
    "You read back Push Notifications as ticked on $bundle_id." \
    "step 2 recorded as developer-confirmed; step 3 of 3 is next" \
    "$BIN/ios-provision record-apple-step --step push --confirm"
  printf ','
  ios_q_opt "Help me — I can't enable it" \
    "Shows the common blockers: Apple role, the certificate prompt, an unsaved change." \
    "opens the Push Notifications help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_push --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Show the steps again" \
    "Re-prints this step, with its numbered clicks and link, without recording anything." \
    "step 2 stays open" \
    "$BIN/ios-provision question --kind apple_step_push --bundle-id $bundle_id"
  printf ']}'
}

ios_q_apple_step_apns_key() {
  local bundle_id="$1" app_name="$2"
  printf '{"header":"Apple 3 of 3","prompt":%s,"selection":"single",' \
    "$(jstr "To reuse a key: at https://developer.apple.com/account/resources/authkeys/list find a key with Apple Push Notifications service (APNs) enabled whose AuthKey_<KEYID>.p8 file you still have.
To create a key:
1. Open https://developer.apple.com/account/resources/authkeys/list and select +.
2. Key Name: for example $app_name APNs. Tick Apple Push Notifications service (APNs).
3. If Apple asks, choose Sandbox & Production for the environment and Team Scoped (All Topics) for the restriction.
4. Select Continue, then Register.
5. Select Download, then move AuthKey_<KEYID>.p8 outside this repository. Keep the file name: the Key ID is read from it.

In Apple Developer → Keys, reuse an APNs key whose .p8 you still have, or create one and download its .p8 — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 3 of 3 — APNs authentication key

One APNs key works for every app on the team, so reuse one when you still have its .p8 file. Apple lets you download a key only once, right after creating it.

Never paste the contents of the .p8 into this conversation. The next screen asks only for its path.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I have the .p8 file")"
  ios_q_opt "I have the .p8 file" \
    "You hold AuthKey_<KEYID>.p8 for an APNs key on this team, reused or new." \
    "Apple setup recorded as developer-confirmed; the APNs key import is next" \
    "$BIN/ios-provision record-apple-step --step apns-key --confirm"
  printf ','
  ios_q_opt "I don't have a .p8 file — help me" \
    "Shows where the download goes, what to do when it is lost, and the key limit." \
    "opens the APNs key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_apns_key"
  printf ','
  ios_q_opt "Show the steps again" \
    "Re-prints this step, with its numbered clicks and link, without recording anything." \
    "step 3 stays open" \
    "$BIN/ios-provision question --kind apple_step_apns_key --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Stop before APNs" \
    "The SDK can still be integrated locally, but real Iterable-to-APNs delivery remains unproved." \
    "APNs credential remains missing"
  printf ']}'
}

ios_q_install_tools() {
  local missing="$1"
  printf '{"header":"Tools","prompt":%s,"selection":"single",' \
    "$(jstr "Install $missing (Xcode from the App Store, Node from https://nodejs.org) — are they installed now?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Missing: $missing

- xcodebuild: install Xcode from the App Store, open it once, then run xcode-select --switch /Applications/Xcode.app.
- node: install from https://nodejs.org or with brew install node.
- curl: ships with macOS; restore it from the system or Homebrew.

The provisioning tool reads build settings with xcodebuild, parses every record with node, and validates the Iterable keys with curl. It does not install anything itself.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_relay_opt "I'll install them" \
    "Install the listed tools in your own terminal, then come back to this question." \
    "the agent waits; nothing is installed for you" \
    "Install $missing in your own terminal: 1. xcodebuild: install Xcode from the App Store, open it once, then run xcode-select --switch /Applications/Xcode.app. 2. node: install from https://nodejs.org or run brew install node. 3. curl: ships with macOS. Then answer this same question with Check again."
  printf ','
  ios_q_opt "Check again" \
    "Re-read the local tools and continue if they are now present." \
    "status runs again; the next step appears once the tools are found" \
    "$BIN/ios-provision status"
  printf ']}'
}

ios_q_import_apns() {
  local team_id="${1:-}" team_flag="" team_line
  if [[ -n "$team_id" ]]; then
    team_flag=" --team-id $team_id"
    team_line="Team ID: $team_id, read from the app target's DEVELOPMENT_TEAM. If the APNs key belongs to a different Apple team, use the terminal option instead."
  else
    team_line="The Team ID could not be read from the app's DEVELOPMENT_TEAM, so the import also needs --team-id; use the terminal option."
  fi
  printf '{"header":"APNs key","prompt":%s,"selection":"single",' \
    "$(jstr "Answer with the path to your AuthKey_<KEYID>.p8 file (APNs keys are at https://developer.apple.com/account/resources/authkeys/list) — or how else should the key be supplied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Iterable needs a distinct Apple Push Notifications authentication key. Apple exposes no supported public API for creating it and allows the private .p8 download only once.

Answer with the absolute path to the downloaded file, for example /Users/you/Keys/AuthKey_ABCDE12345.p8. Only the path enters the conversation, never the contents of the file.
Key ID: read from the AuthKey_<KEYID>.p8 file name.
$team_line

The import verifies that the file is an EC P-256 private key and records its external path. Other Apple keys share that shape, so the tool cannot prove which Apple service the .p8 belongs to. Confirm in Apple Developer that Apple Push Notification service is enabled for that Key ID. The command never copies, prints, creates, revokes, or replaces the key.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Enter the .p8 path" \
    "Answer with the key file's absolute path in the free-text field; the agent runs the import." \
    "the key shape and external path are recorded; service assignment remains human-confirmed until delivery proof"
  printf ','
  ios_q_relay_opt "I'll import it in my terminal" \
    "Run the import yourself when the file was renamed, or the key belongs to a different team." \
    "the agent waits; the key path stays in your terminal" \
    "Run from this app: $BIN/ios-provision import-apns --file /secure/path/AuthKey_KEYID.p8 --key-id KEYID --team-id TEAMID --confirm. Keep the private key out of chat and the repository, then answer this same question again."
  printf ','
  ios_q_opt "I don't have a .p8 file — help me" \
    "Shows where the download goes, how to create a new key, and who can create one." \
    "opens the APNs key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_apns_import"
  printf ','
  ios_q_opt "Stop before APNs" \
    "The SDK can still be integrated locally, but real Iterable-to-APNs delivery remains unproved." \
    "APNs credential remains missing"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the absolute path to AuthKey_<KEYID>.p8 (the path only, never its contents)" \
    "imports the APNs key path with the Key ID from its file name" \
    "$BIN/ios-provision import-apns --file '{{answer}}'$team_flag --confirm")"
}

ios_q_replace_apns_key() {
  local reason="$1" key_id="$2" team_id="$3" classification="${4:-}" bundle_id="${5:-}"
  if [[ "$classification" == apns-key-topic-not-allowed ]]; then
    printf '{"header":"APNs key","prompt":%s,"selection":"single",' \
      "$(jstr "1. Open https://developer.apple.com/account/resources/authkeys/list and open Key ID $key_id.
2. If its key restriction is Topic Specific, add $bundle_id to its topics, then validate the same key again.
3. Or use a Team Scoped key, which can send to every app on the team: re-import its .p8 by answering with its path.

In Apple Developer → Keys, let Key ID $key_id send to $bundle_id, or re-import a Team Scoped key — which file?")"
    printf '"context":%s,' "$(ios_q_arr <<EOF
$reason

The key, Key ID $key_id, and Team ID $team_id are valid: APNs accepted the provider token. It refused only the topic $bundle_id, so this step is not done yet.
EOF
)"
  else
    printf '{"header":"APNs key","prompt":%s,"selection":"single",' \
      "$(jstr "1. Open https://developer.apple.com/account/resources/authkeys/list and find Key ID $key_id. If it is missing or revoked, create a new key (+, tick Apple Push Notifications service, Register, Download).
2. Check the key has Apple Push Notifications service enabled.
3. Check the team name at the top right is the team whose Team ID is $team_id; the Team ID is also shown under Membership details.
4. Re-import the .p8 that matches, answering with its path, or use the terminal option to pass a different Team ID.

In Apple Developer → Keys, check Key ID $key_id and Team ID $team_id, then re-import the matching .p8 — which file?")"
    printf '"context":%s,' "$(ios_q_arr <<EOF
$reason

The tool signed an APNs provider token with the imported key and sent one probe to a random device token in the APNs sandbox. A valid key, Key ID, and Team ID get BadDeviceToken; this key got InvalidProviderToken.
EOF
)"
  fi
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Validate the same key again" \
    "Use this after fixing the key in Apple Developer, for example re-enabling it." \
    "the same key is probed again" \
    "$BIN/ios-provision validate-apns"
  printf ','
  ios_q_relay_opt "I'll re-import it in my terminal" \
    "Pass a different Key ID or Team ID yourself." \
    "the agent waits; the key path stays in your terminal" \
    "Run from this app: $BIN/ios-provision import-apns --replace --file /secure/path/AuthKey_KEYID.p8 --key-id KEYID --team-id TEAMID --confirm, then $BIN/ios-provision validate-apns."
  printf ','
  ios_q_opt "I don't have a working .p8 — help me" \
    "Shows where the download goes, how to create a new key, and who can create one." \
    "opens the APNs key help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_apns_replace"
  printf ','
  ios_q_opt "Stop before APNs" \
    "The SDK can still be integrated locally, but real Iterable-to-APNs delivery remains unproved." \
    "APNs credential remains rejected"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the absolute path to the correct AuthKey_<KEYID>.p8 (the path only, never its contents)" \
    "replaces the imported APNs key; it is validated again next" \
    "$BIN/ios-provision import-apns --replace --file '{{answer}}' --team-id $team_id --confirm")"
}

ios_q_configure_iterable_app() {
  local bundle_id="$1" app_name="$2" region="$3"
  local dashboard_url="https://app.iterable.com/integrations/mobileApps/create"
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/integrations/mobileApps/create"
  printf '{"header":"iOS app","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url
   (or go to Settings > Apps and websites > Add a new app or website).
2. First check whether an iOS app with Bundle ID $bundle_id already exists.
3. If it does not exist, create one with:
   Name: $app_name
   Platform: iOS
   Bundle ID: $bundle_id
   Store URL: leave blank unless this app already has an App Store URL
4. Select Create app.

In Iterable → Settings → Apps and websites, create the iOS app for $bundle_id (or find it) — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 1 of 2 — Create the iOS mobile app

The Bundle ID must match character for character. Iterable files the device tokens for this app under that value. The tool cannot read this dashboard list through a public API, so only select the existing-app option after opening and checking it.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I've created the iOS app" \
    "Record the newly created app for this exact Bundle ID and continue to its APNs credential." \
    "the mobile-app creation is recorded; its APNs credential is still missing" \
    "$BIN/ios-provision record-iterable-app --bundle-id $bundle_id --source created --confirm"
  printf ','
  ios_q_opt "It already exists" \
    "Record the app only after opening it and confirming the exact iOS Bundle ID." \
    "the existing mobile app is recorded; its APNs credential is checked next" \
    "$BIN/ios-provision record-iterable-app --bundle-id $bundle_id --source existing --confirm"
  printf ','
  ios_q_opt "Help me — I can't create the app" \
    "Shows the common blockers: Iterable role, the Store URL field, an app that already exists." \
    "opens the iOS app help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_iterable_app --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Stop before creating it" \
    "No Iterable mobile app is recorded and push setup remains incomplete." \
    "Iterable mobile app remains missing"
  printf ']}'
}

ios_q_configure_iterable_push() {
  local bundle_id="$1" region="$2" key_path="$3" key_id="$4" team_id="$5"
  local dashboard_url="https://app.iterable.com/integrations/mobileApps"
  [[ "$region" != EU ]] ||
    dashboard_url="https://app.eu.iterable.com/integrations/mobileApps"
  printf '{"header":"APNs setup","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $dashboard_url
   (or go to Settings > Apps and websites).
2. Open the iOS app whose Bundle ID is $bundle_id.
3. Select Add new credential.
4. Choose .p8 Auth Key, then select Continue.
5. Upload: $key_path
6. Enter:
   Key ID: $key_id
   Team ID: $team_id
   Bundle ID: $bundle_id
7. Select Update, then read the saved values back.

In Iterable → Apps and websites → $bundle_id, add the .p8 APNs credential and read it back — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Step 2 of 2 — Add the APNs credential

If this app already uses a .p12 certificate, use Upload & Replace from the existing push integration instead of deleting that certificate. Recording this step does not prove delivery; the verifier still requires a real notification.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Configured and read back" \
    "Record the saved APNs credential for this exact iOS app and continue to application integration." \
    "the dashboard step is recorded; real delivery remains unproved" \
    "$BIN/ios-provision record-iterable-push --bundle-id $bundle_id --confirm"
  printf ','
  ios_q_opt "Help me — I can't add the credential" \
    "Shows the common blockers: the file picker, mismatched IDs, an existing .p12." \
    "opens the APNs credential help; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_iterable_push --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Show these steps again" \
    "Re-prints the dashboard steps, with the link, without recording anything." \
    "the same dashboard instructions remain next" \
    "$BIN/ios-provision question --kind configure_iterable_push --bundle-id $bundle_id"
  printf ','
  ios_q_opt "Stop before APNs setup" \
    "The app may build, but Iterable-to-APNs delivery remains incomplete." \
    "Iterable APNs configuration remains unrecorded"
  printf ']}'
}

ios_q_proof_text() {
  local header="$1" prompt="$2" context="$3" hint="$4" field="$5"
  local help_label="${6:-}" help_kind="${7:-}"
  printf '{"header":%s,"prompt":%s,"selection":"single",' \
    "$(jstr "$header")" "$(jstr "$prompt")"
  printf '"context":%s,' "$(printf '%s\n' "$context" | ios_q_arr)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Enter a value" \
    "Use the free-text response for this exact run value." \
    "records the supplied value after validation"
  printf ','
  if [[ -n "$help_label" ]]; then
    ios_q_opt "$help_label" \
      "Shows where to find or create it, then you answer with the exact value." \
      "opens the guide for this value; nothing is recorded yet" \
      "$BIN/ios-provision question --kind $help_kind"
    printf ','
  fi
  ios_q_opt "Stop here" \
    "Keep the current proof proposal without starting a run." \
    "proof setup remains incomplete"
  printf '],"free_text":%s}' "$(ios_q_free_text "$hint" \
    "records this exact proof input" \
    "$IOS_PROOF_ACTOR answer --field $field --value '{{answer}}'")"
}

ios_q_proof_environment() {
  printf '{"header":"Proof env","prompt":%s,"selection":"single",' \
    "$(jstr "Which build environment should this run prove?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Development proves a sandbox-signed build. Production proves a distribution-signed build separately; one result never stands in for the other.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Development — APNs sandbox" \
    "Use a development-signed app and the sandbox APNs environment." \
    "records development for this proof run" \
    "$IOS_PROOF_ACTOR answer --field environment --value development"
  printf ','
  ios_q_opt "Production — TestFlight/App Store" \
    "Use a distribution-signed app and the production APNs environment." \
    "records production for this proof run" \
    "$IOS_PROOF_ACTOR answer --field environment --value production"
  printf ']}'
}

ios_q_proof_region() {
  printf '{"header":"Iterable","prompt":%s,"selection":"single",' \
    "$(jstr "Which Iterable project region should verification read?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Verification needs the project region only to read the exact test identity and send the marked proof notification. It does not replay Apple setup or change the app.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "US project" \
    "Use Iterable's US API for verification reads and the proof send." \
    "records US for this verification workspace" \
    "$IOS_PROOF_ACTOR answer --field region --value US"
  printf ','
  ios_q_opt "EU project" \
    "Use Iterable's EU API for verification reads and the proof send." \
    "records EU for this verification workspace" \
    "$IOS_PROOF_ACTOR answer --field region --value EU"
  printf ','
  ios_q_opt "I'm not sure — help me find out" \
    "Shows how to read the region from the project address." \
    "opens the region guide; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_proof_region"
  printf ']}'
}

ios_q_proof_identity_type() {
  printf '{"header":"Proof user","prompt":%s,"selection":"single",' \
    "$(jstr "How does this app identify the user being verified?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Choose the same identity type the existing app passes to Iterable. Verification does not create or change the application authentication model.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Email" "Verify the exact email already used by the app." \
    "records email as the proof identity type" \
    "$IOS_PROOF_ACTOR answer --field identity-type --value email"
  printf ','
  ios_q_opt "User ID" "Verify the exact stable user ID already used by the app." \
    "records user-id as the proof identity type" \
    "$IOS_PROOF_ACTOR answer --field identity-type --value user-id"
  printf ','
  ios_q_opt "I'm not sure — help me decide" \
    "Shows the one question that decides it." \
    "opens the identity guide; nothing is recorded yet" \
    "$BIN/ios-provision question --kind help_proof_identity_type"
  printf ']}'
}

ios_q_proof_device() {
  local devices_json="$1"
  printf '{"header":"Device","prompt":%s,"selection":"single",' \
    "$(jstr "Which iOS device should run this proof?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Choose the device you will watch and operate. Development APNs delivery can use an eligible booted iOS 16+ Simulator or a physical iPhone. Production/TestFlight proof requires a physical iPhone.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":'
  node -e '
    const [raw,bin]=process.argv.slice(1);
    const devices=JSON.parse(raw).slice(0,3);
    const options=devices.map(device=>({
      label:device.label.slice(0,80),
      description:device.description,
      effect:`records ${device.id} as the exact proof device`,
      relay:"",
      commands:[`${bin}/ios-prepare-proof answer --field device --value ${device.id}`]
    }));
    if (options.length<2) {
      options.push({
        label:options.length ? "Stop here" : "Refresh devices",
        description:options.length
          ? "Keep the proof proposal without selecting a different device."
          : "Run discovery again after booting a Simulator or connecting an iPhone.",
        effect:"device selection remains incomplete",
        relay:"",
        commands:options.length ? [] : [`${bin}/ios-prepare-proof status`]
      });
    }
    if (options.length<2) {
      options.push({
        label:"Stop here",
        description:"Keep the current proof proposal.",
        effect:"proof setup remains incomplete",
        relay:"",
        commands:[]
      });
    }
    process.stdout.write(JSON.stringify(options));
  ' "$devices_json" "$BIN"
  printf ',"free_text":%s}' "$(ios_q_free_text \
    "Enter an exact CoreDevice identifier or booted Simulator UDID not listed above" \
    "records the exact proof device" \
    "$IOS_PROOF_ACTOR answer --field device --value '{{answer}}'")"
}

ios_q_confirm_proof() {
  local summary="$1"
  printf '{"header":"Proof run","prompt":%s,"selection":"single",' \
    "$(jstr "Start this exact Iterable proof run?")"
  printf '"context":%s,' "$(printf '%s\n' "$summary" | ios_q_arr)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "Start this run")"
  ios_q_opt "Start this run" \
    "Records the exact target and generates a unique marker. Instrumented evaluations also check fresh User A and User B baselines." \
    "creates proof-target.json without marking any outcome passed" \
    "$IOS_PROOF_ACTOR start --confirm"
  printf ','
  ios_q_opt "Change answers" \
    "Clears the proposed proof inputs without changing the confirmed integration scope." \
    "returns to the first proof question" \
    "$IOS_PROOF_ACTOR answer --clear"
  printf ','
  ios_q_opt "Stop here" \
    "No proof target is created." \
    "the integration remains unproved"
  printf ']}'
}

ios_q_back_opt() {
  local label="$1" command="$2"
  ios_q_opt "$label" \
    "Return to the step this help came from, unchanged." \
    "the original step is shown again" \
    "$command"
}

ios_q_help_identity() {
  local mode="${1:-provision}" actor="$BIN/ios-provision" field="identity-mode"
  local user_id_value="user-id" back="$BIN/ios-provision status"
  if [[ "$mode" == proof ]]; then
    actor="$IOS_PROOF_ACTOR"
    field="identity-type"
    back="$IOS_PROOF_ACTOR status"
  fi
  printf '{"header":"Identity","prompt":%s,"selection":"single",' \
    "$(jstr "1. Users sign in with an email address, or the app asks for one: choose Email.
2. Users sign in with an account ID from your own backend: choose User ID.
3. There is no sign-in yet, or users stay anonymous: choose Unknown user.

Check how a user signs in to this app — which of these matches?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
One question decides this: what does the app already know about the person using it?

Never invent an identifier from device or developer account details.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "They sign in with an email — Email" \
    "Identify users by the email the app already has." \
    "records email identity" \
    "$actor answer --field $field --value email"
  printf ','
  ios_q_opt "They have an account ID — User ID" \
    "Identify users by the stable account ID the app already has." \
    "records user-ID identity" \
    "$actor answer --field $field --value $user_id_value"
  printf ','
  if [[ "$mode" != proof ]]; then
    ios_q_opt "No sign-in yet — Unknown user" \
      "Start with Unknown User Activation and identify users later, if the app ever learns who they are." \
      "records unknown-user identity" \
      "$actor answer --field $field --value unknown-user"
    printf ','
  fi
  ios_q_back_opt "Back to the identity question" "$back"
  printf ']}'
}

ios_q_help_region() {
  local mode="${1:-provision}" actor="$BIN/ios-provision" back="$BIN/ios-provision status"
  if [[ "$mode" == proof ]]; then
    actor="$IOS_PROOF_ACTOR"
    back="$IOS_PROOF_ACTOR status"
  fi
  printf '{"header":"Region","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open the Iterable project this app will send data to, at https://app.iterable.com or https://app.eu.iterable.com.
2. Look at the address bar after you sign in: app.eu.iterable.com is an EU project; app.iterable.com is a US project.

Open your Iterable project in the browser and check its address — which region is it?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
No Iterable project yet? Someone with Iterable access has to create one or invite you to it before setup can continue; this tool cannot create one. A project region is fixed when the project is created.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "It shows app.iterable.com — US" \
    "Use the US API endpoints and a US Mobile key." \
    "records US as the data region" \
    "$actor answer --field region --value US"
  printf ','
  ios_q_opt "It shows app.eu.iterable.com — EU" \
    "Use the EU API endpoints and an EU Mobile key." \
    "records EU as the data region" \
    "$actor answer --field region --value EU"
  printf ','
  ios_q_opt "We have no Iterable project yet — stop here" \
    "Setup waits until someone creates the project or invites you to it." \
    "region remains unanswered; nothing is recorded"
  printf ','
  ios_q_back_opt "Back to the region question" "$back"
  printf ']}'
}

ios_q_help_jwt() {
  printf '{"header":"JWT","prompt":%s,"selection":"single",' \
    "$(jstr "Check one fact: does your app already have a backend that issues user-specific Iterable JWTs?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
One fact decides this.

JWT is for apps whose own backend signs a short-lived token for each signed-in user with the Iterable project JWT secret, and hands it to the app. If nobody on your team built that endpoint, the answer is no.

Without that backend, choose No JWT: the next Iterable step creates the Mobile key with Require JWT Off, and the app works without any token code.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "No such backend — No JWT")"
  ios_q_opt "No such backend — No JWT" \
    "The next Iterable step creates the Mobile key with Require JWT Off." \
    "records JWT as disabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value false"
  printf ','
  ios_q_opt "Our backend issues them — JWT required" \
    "The integration adds an auth handler that asks your backend for each token." \
    "records JWT as enabled" \
    "$BIN/ios-provision answer --field jwt-enabled --value true"
  printf ','
  ios_q_back_opt "Back to the JWT question" "$BIN/ios-provision status"
  printf ']}'
}

ios_q_help_mobile_key() {
  local region="$1" jwt="$2" replace="${3:-false}" url jwt_label="Off" capture
  url="$(ios_q_jwt_keys_url "$region")"
  [[ "$jwt" != true ]] || jwt_label="On"
  capture="$BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  [[ "$replace" != true ]] ||
    capture="$BIN/ios-provision capture-mobile --replace --region $region --jwt-enabled $jwt --confirm"
  printf '{"header":"Mobile key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $url. If it shows no API Keys page or no New API Key button, your Iterable role cannot manage keys: ask a project admin to create a Mobile key with Require JWT $jwt_label, or to give you that permission.
2. Check the address bar shows the $region project. A key from the other region is rejected.
3. Choose the Mobile type, not Server-side or JavaScript. Only a Mobile key belongs in the app.
4. Iterable shows a new key once. If it closed before you copied it, create another one; the old one can stay.

Check these common Mobile-key blockers, then copy the key — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Copy the key, but never paste it into this conversation.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I've copied the Mobile key" \
    "Capture the copied value securely and validate it next." \
    "the Mobile key enters the ignored workspace; validation becomes next" \
    "$capture"
  printf ','
  ios_q_back_opt "Back to the Mobile-key step" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Stop here" \
    "Iterable setup stays incomplete until a Mobile key is captured." \
    "Mobile key remains missing"
  printf ']}'
}

ios_q_help_server_key() {
  local region="$1" replace="${2:-false}" url capture="$BIN/ios-provision capture-server --confirm"
  url="$(ios_q_jwt_keys_url "$region")"
  [[ "$replace" != true ]] || capture="$BIN/ios-provision capture-server --replace --confirm"
  printf '{"header":"Server key","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $url. If it shows no API Keys page or no New API Key button, your Iterable role cannot manage keys: ask a project admin to create a Server-side key for local SDK verification, or to give you that permission.
2. Check the address bar shows the $region project. A key from the other region is rejected.
3. Choose the Server-side type, not Mobile. This key stays in the ignored workspace and never enters the app.
4. Iterable shows a new key once. If it closed before you copied it, create another one.

Check these common Server-side key blockers, then copy the key — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Copy the key, but never paste it into this conversation.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I've copied the Server-side key" \
    "Capture the copied value securely and validate it next." \
    "the Server-side key enters only the ignored workspace; validation becomes next" \
    "$capture"
  printf ','
  ios_q_back_opt "Back to the Server-side key step" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Stop here" \
    "Verification cannot read Iterable or send the proof push without this key." \
    "Server-side key remains missing"
  printf ']}'
}

ios_q_help_bundle() {
  local mode="${1:-provision}" command back
  command="$BIN/ios-provision record-target --bundle-id '{{answer}}' --confirm"
  back="$BIN/ios-provision status"
  if [[ "$mode" == proof ]]; then
    command="$IOS_PROOF_ACTOR answer --field bundle-id --value '{{answer}}'"
    back="$IOS_PROOF_ACTOR status"
  fi
  printf '{"header":"Bundle ID","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open the project in Xcode and select the project at the top of the navigator.
2. Under Targets, select the app itself, not a widget, extension, or test target.
3. Open General > Identity and read Bundle Identifier. If it differs per build configuration, use the one you build for this test.
4. Type that exact value as the answer, for example com.example.app.

Open the app target in Xcode and read its Bundle Identifier — what is it?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_back_opt "Back to the Bundle ID question" "$back"
  printf ','
  ios_q_opt "Stop here" \
    "Nothing is recorded until the exact Bundle ID is known." \
    "Bundle ID remains unanswered"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the Bundle Identifier from Xcode, for example com.example.app" \
    "records that exact Bundle ID" \
    "$command")"
}

ios_q_help_app_id() {
  local bundle_id="$1"
  printf '{"header":"App ID help","prompt":%s,"selection":"single",' \
    "$(jstr "1. No + button, or no Identifiers section: your Apple role cannot register App IDs. Ask the Account Holder or an Admin to register the explicit App ID $bundle_id at https://developer.apple.com/account/resources/identifiers/list (+, App IDs, App, Explicit), or to give you the Admin role.
2. Wrong team: the team name at the top right of the page must be the team that signs this app. Switch teams there.
3. Apple says the identifier is not available: another team already owns $bundle_id. Change the Bundle Identifier in Xcode, then answer with the new value below.
4. The App ID is missing although Xcode built the app: Simulator builds never register it, so registering it here is expected. Without it APNs answers TopicDisallowed and nothing arrives, even on a Simulator.

Check these common App ID blockers, then register $bundle_id — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Done — the App ID exists" \
    "The explicit App ID $bundle_id is registered." \
    "step 1 recorded as developer-confirmed; step 2 of 3 is next" \
    "$BIN/ios-provision record-apple-step --step app-id --confirm"
  printf ','
  ios_q_back_opt "Back to step 1" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Choose another path" \
    "Leave the walkthrough and return to the Apple setup selector." \
    "removes only the local Apple strategy and walkthrough progress" \
    "$BIN/ios-provision clear-apple-setup --confirm"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "If another team owns $bundle_id, enter the new Bundle ID you set in Xcode" \
    "records the new iOS target; Apple setup restarts for it" \
    "$BIN/ios-provision record-target --bundle-id '{{answer}}' --confirm")"
}

ios_q_help_push() {
  local bundle_id="$1"
  printf '{"header":"Push help","prompt":%s,"selection":"single",' \
    "$(jstr "1. The checkbox is missing or greyed out: your Apple role cannot edit capabilities. Ask the Account Holder or an Admin to open $bundle_id at https://developer.apple.com/account/resources/identifiers/list, tick Push Notifications, then Save and Confirm.
2. Apple offers to configure certificates: skip it. An APNs key replaces push certificates.
3. Save seemed to do nothing: confirm the Modify App Capabilities dialog, then reopen $bundle_id and check the box is still ticked.
4. A later device build reports a provisioning-profile error: Xcode automatic signing regenerates the profile on the next build. Simulator builds are unaffected.
5. A later push fails with TopicDisallowed: the App ID is not registered, or Push Notifications may still be off on it. Reopen $bundle_id and check.

Check these common Push Notifications blockers, then enable it on $bundle_id — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Done — Push Notifications is on" \
    "You read back Push Notifications as ticked on $bundle_id." \
    "step 2 recorded as developer-confirmed; step 3 of 3 is next" \
    "$BIN/ios-provision record-apple-step --step push --confirm"
  printf ','
  ios_q_back_opt "Back to step 2" "$BIN/ios-provision status"
  printf ']}'
}

ios_q_help_apns_key() {
  local origin="${1:-step}" team_id="${2:-}" team_flag=""
  [[ -z "$team_id" ]] || team_flag=" --team-id $team_id"
  printf '{"header":"APNs help","prompt":%s,"selection":"single",' \
    "$(jstr "1. Look in Downloads for a file named AuthKey_<KEYID>.p8: Apple saves it there when you select Download.
2. The key exists but its .p8 is gone: Apple cannot download it again. Create a new key at https://developer.apple.com/account/resources/authkeys/list (+, tick Apple Push Notifications service, Register, Download).
3. Apple says the team reached its APNs key limit: ask the Account Holder before revoking a key, because every app using it stops receiving push.
4. No Keys section or no + button: your Apple role cannot create keys. Ask the Account Holder or an Admin to create one and hand you the .p8 through a secure channel, never chat or email.

Check these ways to get an APNs .p8 file — do you have one now?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Keep the file outside the repository and keep its name; the Key ID is read from it.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  if [[ "$origin" == step ]]; then
    ios_q_opt "I have the .p8 file now" \
      "You hold AuthKey_<KEYID>.p8 for an APNs key on this team." \
      "Apple setup recorded as developer-confirmed; the APNs key import is next" \
      "$BIN/ios-provision record-apple-step --step apns-key --confirm"
    printf ','
  fi
  ios_q_back_opt "Back to the APNs step" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Stop before APNs" \
    "The SDK can still be integrated locally, but real Iterable-to-APNs delivery remains unproved." \
    "APNs credential remains missing"
  if [[ "$origin" == import || "$origin" == replace ]]; then
    local replace_flag=""
    [[ "$origin" != replace ]] || replace_flag=" --replace"
    printf '],"free_text":%s}' "$(ios_q_free_text \
      "Enter the absolute path to AuthKey_<KEYID>.p8 (the path only, never its contents)" \
      "imports the APNs key path with the Key ID from its file name" \
      "$BIN/ios-provision import-apns$replace_flag --file '{{answer}}'$team_flag --confirm")"
  else
    printf ']}'
  fi
}

ios_q_help_iterable_app() {
  local bundle_id="$1" app_name="$2" region="$3"
  local url="https://app.iterable.com/integrations/mobileApps/create"
  [[ "$region" != EU ]] || url="https://app.eu.iterable.com/integrations/mobileApps/create"
  printf '{"header":"iOS app help","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open $url. If there is no Apps and websites page or no way to add one, your Iterable role cannot manage apps: ask a project admin to create the iOS app $app_name with Bundle ID $bundle_id.
2. The form asks for a Store URL: leave it blank until the app is on the App Store.
3. An app with this name already exists: open it and read its Bundle ID. If it is $bundle_id, answer It already exists.
4. Check the address bar shows the $region project; an app created in another project never receives these devices.

Check these common blockers, then create the iOS app $bundle_id in Iterable — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "I've created the iOS app" \
    "Record the newly created app for this exact Bundle ID." \
    "the mobile-app creation is recorded; its APNs credential is next" \
    "$BIN/ios-provision record-iterable-app --bundle-id $bundle_id --source created --confirm"
  printf ','
  ios_q_opt "It already exists" \
    "Record the app after confirming its exact iOS Bundle ID." \
    "the existing mobile app is recorded; its APNs credential is next" \
    "$BIN/ios-provision record-iterable-app --bundle-id $bundle_id --source existing --confirm"
  printf ','
  ios_q_back_opt "Back to the iOS app step" "$BIN/ios-provision status"
  printf ']}'
}

ios_q_help_iterable_push() {
  local bundle_id="$1" key_path="$2" key_id="$3" team_id="$4"
  printf '{"header":"APNs help","prompt":%s,"selection":"single",' \
    "$(jstr "1. The upload dialog cannot see the file: press Cmd+Shift+G in the dialog and paste $key_path.
2. Iterable rejects the key: check Key ID $key_id and Team ID $team_id against the AuthKey file name and the Apple team, and that the key has Apple Push Notifications service enabled.
3. The app already has a .p12 certificate: use Upload & Replace on the existing push integration instead of deleting it.
4. No Add new credential button: your Iterable role cannot edit apps; ask a project admin to add the credential with these values.
5. A later push fails with DeviceTokenNotForTopic: the Bundle ID on this Iterable app does not match the app that registered the token. It must be exactly $bundle_id.

Check these common blockers, then add the .p8 credential to $bundle_id in Iterable — done?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_opt "Configured and read back" \
    "Record the saved APNs credential for this exact iOS app." \
    "the dashboard step is recorded; real delivery remains unproved" \
    "$BIN/ios-provision record-iterable-push --bundle-id $bundle_id --confirm"
  printf ','
  ios_q_back_opt "Back to the APNs credential step" "$BIN/ios-provision status"
  printf ']}'
}

ios_q_help_proof_identity() {
  local field="${1:-identity}" command
  command="$IOS_PROOF_ACTOR answer --field $field --value '{{answer}}'"
  [[ "$field" != start ]] || command="$IOS_PROOF_ACTOR start --confirm --identity '{{answer}}'"
  printf '{"header":"Test user","prompt":%s,"selection":"single",' \
    "$(jstr "1. Open the app on the device you will test with.
2. Sign in, or enter an email on its identification screen, with an address you control, for example a plus-address of your work email.
3. Iterable creates the user the first time the app identifies it, so no dashboard step is needed.
4. Type the exact same value as the answer. For an app that identifies users by account ID, use the ID the app passes to Iterable.

Open the app and sign in with a test identity you control — which one did you use?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_back_opt "Back to the proof question" "$IOS_PROOF_ACTOR status"
  printf ','
  ios_q_opt "Stop here" \
    "No proof run starts until the app uses a known test identity." \
    "proof setup remains incomplete"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the exact email or user ID the app is signed in with" \
    "records this exact proof identity" \
    "$command")"
}

ios_q_help_proof_app() {
  printf '{"header":"App build","prompt":%s,"selection":"single",' \
    "$(jstr "1. In Xcode, build the app for the device you will test on with Product > Build.
2. Choose Product > Show Build Folder in Finder.
3. Open Products, then Debug-iphonesimulator for a Simulator or Debug-iphoneos for an iPhone, and find the .app.
4. Drag the .app into Terminal to print its absolute path, and type that path as the answer.

Open the build folder in Xcode and find the .app you will install — what is its path?")"
  printf '"context":%s,' "$(ios_q_arr <<'EOF'
Work through the steps in the question, then pick the answer that matches.
EOF
)"
  printf '"requires":[],"recommended":null,"before_commands":[],"options":['
  ios_q_back_opt "Back to the proof question" "$IOS_PROOF_ACTOR status"
  printf ','
  ios_q_opt "Stop here" \
    "No proof run starts until the exact build is known." \
    "proof setup remains incomplete"
  printf '],"free_text":%s}' "$(ios_q_free_text \
    "Enter the absolute path ending in .app" \
    "records this exact app build" \
    "$IOS_PROOF_ACTOR answer --field app-path --value '{{answer}}'")"
}

ios_q_help_copy_mobile_key() {
  local region="$1" jwt="$2" url jwt_label="Off"
  url="$(ios_q_jwt_keys_url "$region")"
  [[ "$jwt" != true ]] || jwt_label="On"
  printf '{"header":"Mobile key","prompt":%s,"selection":"single",' \
    "$(jstr "Reuse a Mobile key that already exists for this project:
1. Open $url and find the key whose type is Mobile.
2. Check its JWT setting is $jwt_label; a key with the other setting is rejected.
3. If the page lets you copy its value, copy it there. Iterable often shows a key only once, at creation.
4. Otherwise copy it from where your team keeps it, such as another app config or a secrets manager.

Copy your existing Mobile key (Require JWT $jwt_label) — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
If nobody kept the value, create a new Mobile key instead; it does not affect the old one. Never paste the key into this conversation.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied the existing Mobile key")"
  ios_q_opt "I've copied the existing Mobile key" \
    "Capture the copied value securely and validate it next." \
    "the Mobile key enters the ignored workspace; validation becomes next" \
    "$BIN/ios-provision capture-mobile --region $region --jwt-enabled $jwt --confirm"
  printf ','
  ios_q_back_opt "Nobody kept it — back to creating a new key" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Stop here" \
    "Iterable setup stays incomplete until a Mobile key is captured." \
    "Mobile key remains missing"
  printf ']}'
}

ios_q_help_copy_server_key() {
  local region="$1" url
  url="$(ios_q_jwt_keys_url "$region")"
  printf '{"header":"Server key","prompt":%s,"selection":"single",' \
    "$(jstr "Reuse a Server-side key that already exists for this project:
1. Open $url and find the key whose type is Server-side.
2. If the page lets you copy its value, copy it there. Iterable often shows a key only once, at creation.
3. Otherwise copy it from where your team keeps it, such as a backend config or a secrets manager.

Copy your existing Server-side key — copied?")"
  printf '"context":%s,' "$(ios_q_arr <<EOF
If nobody kept the value, create a new Server-side key for local SDK verification instead. This key stays in the ignored workspace and never enters the app. Never paste it into this conversation.
EOF
)"
  printf '"requires":[],"recommended":%s,"before_commands":[],"options":[' \
    "$(jstr "I've copied the existing Server-side key")"
  ios_q_opt "I've copied the existing Server-side key" \
    "Capture the copied value securely and validate it next." \
    "the Server-side key enters only the ignored workspace; validation becomes next" \
    "$BIN/ios-provision capture-server --confirm"
  printf ','
  ios_q_back_opt "Nobody kept it — back to creating a new key" "$BIN/ios-provision status"
  printf ','
  ios_q_opt "Stop here" \
    "Verification cannot read Iterable or send the proof push without this key." \
    "Server-side key remains missing"
  printf ']}'
}

ios_question() {
  case "$1" in
    choose_features) ios_q_choose_features ;;
    import_android) ios_q_import_android "$2" "${3:-}" "${4:-}" "${5:-}" ;;
    carry_scope) ios_q_carry_scope "$2" "$3" "$4" ;;
    fix_expo_gitignore) ios_q_fix_expo_gitignore "$2" ;;
    choose_more_features) ios_q_choose_more_features ;;
    choose_identity) ios_q_choose_identity ;;
    choose_region) ios_q_choose_region ;;
    choose_jwt) ios_q_choose_jwt ;;
    check_jwt) ios_q_check_jwt "${2:-}" ;;
    confirm_scope)
      ios_q_confirm_scope "$2" "$3" "$4" "$5" "${6:-}" "${7:-}"
      ;;
    configure_iterable)
      ios_q_configure_iterable "$2" "$3"
      ;;
    capture_iterable)
      ios_q_capture_iterable "$2" "$3"
      ;;
    configure_server)
      ios_q_configure_server "$2" "${3:-false}"
      ;;
    replace_mobile_key)
      ios_q_replace_mobile_key "$2" "$3" "$4"
      ;;
    replace_server_key)
      ios_q_replace_server_key "$2" "$3"
      ;;
    choose_bundle)
      ios_q_choose_bundle "${2:-}" "${3:-}" "${4:-}"
      ;;
    choose_apple_setup)
      ios_q_choose_apple_setup
      ;;
    confirm_existing_apple)
      ios_q_confirm_existing_apple "$2"
      ;;
    confirm_manual_apple)
      ios_q_confirm_manual_apple "$2"
      ;;
    apple_step_app_id)
      ios_q_apple_step_app_id "$2" "$3"
      ;;
    asc_key) ios_q_asc_key ;;
    asc_issuer) ios_q_asc_issuer ;;
    asc_plan) ios_q_asc_plan "$2" "$3" "$4" "$5" ;;
    asc_rejected) ios_q_asc_rejected "$2" "$3" ;;
    asc_conflict) ios_q_asc_conflict "$2" "$3" ;;
    help_asc_key) ios_q_help_asc_key ;;
    apple_step_push)
      ios_q_apple_step_push "$2"
      ;;
    apple_step_apns_key)
      ios_q_apple_step_apns_key "$2" "$3"
      ;;
    install_tools)
      ios_q_install_tools "$2"
      ;;
    import_apns)
      ios_q_import_apns "${2:-}"
      ;;
    configure_iterable_push)
      ios_q_configure_iterable_push "$2" "$3" "$4" "$5" "$6"
      ;;
    configure_iterable_app)
      ios_q_configure_iterable_app "$2" "$3" "$4"
      ;;
    proof_region) ios_q_proof_region ;;
    proof_environment) ios_q_proof_environment ;;
    proof_identity_type) ios_q_proof_identity_type ;;
    proof_device) ios_q_proof_device "$2" ;;
    proof_bundle)
      ios_q_proof_text "Bundle ID" "Which exact app Bundle ID should this run prove?" \
        "Use the effective Bundle ID of the application target being built and installed." \
        "Enter the explicit Bundle ID, for example com.example.app" "bundle-id" \
        "I don't know the Bundle ID — help me find it" help_proof_bundle
      ;;
    proof_identity)
      ios_q_proof_text "Proof user" "Which exact identity is the app using for this test?" \
        "Use the identity already visible in the app. Standard verification may reuse an existing Iterable user and will not ask you to log in again when remote state already proves it." \
        "Enter the exact test email or user ID used by the app" "identity" \
        "I don't have a test user yet — help me" help_proof_identity
      ;;
    proof_switch_identity)
      ios_q_proof_text "User B" "Which different fresh identity should create User B?" \
        "User B proves logout and account switching on the same app installation." \
        "Enter a second fresh test email or user ID" "switch-identity" \
        "I don't have a second test user — help me" help_proof_switch_identity
      ;;
    proof_app)
      if [[ "${2:-}" == instrumented ]]; then
        ios_q_proof_text "App build" "Where is the exact instrumented .app bundle for this run?" \
          "Build the debug-only runtime harness configuration, then select its concrete .app output." \
          "Enter the absolute path ending in .app" "app-path" \
          "I don't know where the .app is — help me find it" help_proof_app
      else
        ios_q_proof_text "App build" "Where is the exact existing .app bundle for this run?" \
          "Select the concrete app artifact that will be installed. Behavioral proof does not require source edits or a special runtime harness." \
          "Enter the absolute path ending in .app" "app-path" \
          "I don't know where the .app is — help me find it" help_proof_app
      fi
      ;;
    proof_profile)
      ios_q_proof_text "Profile" "Which profile value must appear on User A?" \
        "Record an exact product-approved field. Use field=<JSON> when the value matters." \
        "For example plan=\"premium\"" "profile-field"
      ;;
    proof_event)
      ios_q_proof_text "Event" "Which exact custom event count must appear for User A?" \
        "The verifier isolates events created after this run starts." \
        "For example purchaseCompleted=1" "event"
      ;;
    proof_tap)
      ios_q_proof_text "Tap result" "What visible destination should the User A push tap open?" \
        "Describe one short, non-secret UI result that the observation actor can read." \
        "For example Dog details" "tap-expect"
      ;;
    proof_logout)
      ios_q_proof_text "Logout" "What visible state proves logout and User B isolation?" \
        "Describe the neutral or User B-owned state visible after local clearing, Iterable logout, and User B identification." \
        "For example Signed in as User B" "logout-expect"
      ;;
    confirm_proof) ios_q_confirm_proof "$2" ;;
    help_identity) ios_q_help_identity provision ;;
    help_proof_identity_type) ios_q_help_identity proof ;;
    help_region) ios_q_help_region provision ;;
    help_proof_region) ios_q_help_region proof ;;
    help_jwt) ios_q_help_jwt ;;
    help_mobile_key) ios_q_help_mobile_key "$2" "$3" "${4:-false}" ;;
    help_server_key) ios_q_help_server_key "$2" "${3:-false}" ;;
    help_copy_mobile_key) ios_q_help_copy_mobile_key "$2" "$3" ;;
    help_copy_server_key) ios_q_help_copy_server_key "$2" ;;
    help_bundle) ios_q_help_bundle provision ;;
    help_proof_bundle) ios_q_help_bundle proof ;;
    help_app_id) ios_q_help_app_id "$2" ;;
    help_push) ios_q_help_push "$2" ;;
    help_apns_key) ios_q_help_apns_key step ;;
    help_apns_import) ios_q_help_apns_key import "${2:-}" ;;
    help_apns_replace) ios_q_help_apns_key replace "${2:-}" ;;
    replace_apns_key) ios_q_replace_apns_key "$2" "$3" "$4" "${5:-}" "${6:-}" ;;
    help_iterable_app) ios_q_help_iterable_app "$2" "$3" "$4" ;;
    help_iterable_push) ios_q_help_iterable_push "$2" "$3" "$4" "$5" ;;
    help_proof_identity) ios_q_help_proof_identity identity ;;
    help_proof_switch_identity) ios_q_help_proof_identity switch-identity ;;
    help_proof_identity_start) ios_q_help_proof_identity start ;;
    help_proof_app) ios_q_help_proof_app ;;
    *) return 2 ;;
  esac
}
