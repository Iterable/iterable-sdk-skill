#!/usr/bin/env bash
# Whether every native iOS provisioning state can be left. Each walk starts from an
# empty app, reads `ios-provision status`, renders the screen its `next.command`
# names, takes the developer's answer (the screen's recommendation unless the walk
# scripts a choice), runs exactly the commands that answer carries, and reads status
# again. A human step without a question, a step with nothing to run, or a step that
# comes back unchanged fails: those are the dead ends a conducted session gets stuck in.
#
# No network and no credentials: curl, xcodebuild, and the clipboard are fakes.

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

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-provision-walk.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-provision-walk.*|/private/tmp/iterable-ios-provision-walk.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
STATE="$ROOT/state"
KEYS="$ROOT/keys"
mkdir -p "$FAKEBIN" "$STATE" "$KEYS"

openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$KEYS/AuthKey_APNSKEY001.p8" 2>/dev/null
APNS_PATH="$(cd "$KEYS" && pwd -P)/AuthKey_APNSKEY001.p8"
openssl ecparam -name prime256v1 -genkey -noout 2>/dev/null |
  openssl pkcs8 -topk8 -nocrypt -out "$KEYS/AuthKey_ASCKEY0001.p8" 2>/dev/null
ASC_KEY_PATH="$(cd "$KEYS" && pwd -P)/AuthKey_ASCKEY0001.p8"

cat > "$FAKEBIN/xcodebuild" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" -showBuildSettings "* ]]; then
  app='{"target":"SampleShop","action":"build","buildSettings":{"PRODUCT_TYPE":"com.apple.product-type.application","PLATFORM_NAME":"iphoneos","PRODUCT_BUNDLE_IDENTIFIER":"com.example.sampleshop","PRODUCT_NAME":"Sample Shop","DEVELOPMENT_TEAM":"TEAMID0001"}}'
  ext='{"target":"NotificationService","action":"build","buildSettings":{"PRODUCT_TYPE":"com.apple.product-type.app-extension","PLATFORM_NAME":"iphoneos","PRODUCT_BUNDLE_IDENTIFIER":"com.example.sampleshop.NotificationService","PRODUCT_NAME":"NotificationService","DEVELOPMENT_TEAM":"TEAMID0001"}}'
  printf '[%s,%s,%s]\n' "$app" "$ext" "$app"
  exit 0
fi
echo "Xcode 18.0"
EOF
cat > "$FAKEBIN/pbpaste" <<'EOF'
#!/usr/bin/env bash
cat "$WALK_STATE/clipboard"
EOF
cat > "$FAKEBIN/pbcopy" <<'EOF'
#!/usr/bin/env bash
cat > "$WALK_STATE/clipboard"
EOF
# Mobile keys get Iterable's insufficient-privileges 401 on /api/channels;
# Server-side keys read it unless rotated.
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
config="$(cat)"
printf 'curl %s\n' "$*" >> "$WALK_STATE/calls"
if [[ "$*" == *push.apple.com* || "$*" == *appstoreconnect.apple.com* ]]; then
  APPLE_FAKE_STATE="$WALK_STATE" exec __APPLE_FAKE__ "$@" <<< "$config"
fi
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
    if [[ -f "$WALK_STATE/rotated-$key" ]]; then
      printf '{"msg":"invalid api key"}\n401\n'
    elif [[ "$*" == *registerDeviceToken* ]]; then
      printf '{"msg":"Invalid parameters"}\n400\n'
    else
      printf '{"channels":[{"messageMedium":"Push"}]}\n200\n'
    fi
    ;;
  *)
    printf '{"msg":"invalid api key"}\n401\n'
    ;;
esac
EOF
sed -i '' "s#__APPLE_FAKE__#$REPO/tests/fixtures/ios-apple-curl#" "$FAKEBIN/curl"
chmod +x "$FAKEBIN"/*

MOBILE_KEY="mobile-key-canary-1234567890"
SERVER_KEY="server-key-canary-1234567890"
ROTATED_SERVER_KEY="server-key-canary-rotated-0987654321"

new_app() {
  APP="$ROOT/$1"
  WORKSPACE="$APP/.iterable/ios"
  mkdir -p "$APP/SampleShop.xcodeproj" "$APP/SampleShop"
  cat > "$APP/SampleShop.xcodeproj/project.pbxproj" <<'EOF'
// !$*UTF8*$!
{
	objects = {
		PRODUCT_BUNDLE_IDENTIFIER = com.example.sampleshop;
		PRODUCT_BUNDLE_IDENTIFIER = com.example.sampleshop.NotificationService;
		DEVELOPMENT_TEAM = TEAMID0001;
	};
}
EOF
  : > "$STATE/calls"
  : > "$STATE/clipboard"
}

in_app() {
  (cd "$APP" && env PATH="$FAKEBIN:$PATH" WALK_STATE="$STATE" bash -c "$1")
}

field() {
  node -e '
    const value = process.argv[2].split(".").reduce(
      (object, key) => object == null ? object : object[key],
      JSON.parse(process.argv[1])
    );
    process.stdout.write(value === null ? "null" :
      typeof value === "object" ? JSON.stringify(value) : String(value ?? ""));
  ' "$1" "$2"
}

digest() {
  { find "$WORKSPACE" -type f 2>/dev/null | LC_ALL=C sort | while IFS= read -r file; do
      printf '%s ' "$file"; shasum < "$file"
    done; } | shasum | cut -c1-12
}

# A host selector shows the prompt and options but can drop the context, so every
# link and numbered step must be in the prompt, with the question as its last line.
prompt_names_action() {
  node -e '
    const q = JSON.parse(process.argv[1]);
    const urls = text => (String(text).match(/https?:\/\/[^\s)]+/g) || []).map(url => url.replace(/[.,]$/, ""));
    const prompt = String(q.prompt || "");
    const context = q.context || [];
    const promptLines = prompt.split("\n");
    const last = promptLines[promptLines.length - 1];
    const problems = [];
    for (const url of urls(context.join("\n"))) {
      if (!prompt.includes(url)) problems.push(`context link ${url} is not in the prompt`);
    }
    for (const line of context.filter(line => /^\s*\d+\.\s/.test(line))) {
      if (!prompt.includes(line.trim())) problems.push(`step "${line.trim().slice(0, 40)}" is only in context`);
    }
    if (promptLines.some(line => /^\s*\d+\.\s/.test(line))) {
      if (!last.endsWith("?")) problems.push("the prompt does not end with its question");
      if (/^(Has|Have|Is|Are|Does|Do|Did|Was|Were)\b/.test(last) ||
          !/^(In|Open|Create|Copy|Register|Enable|Tick|Reuse|Add|Check|Set up|Download|Read)\b/.test(last)) {
        problems.push(`the question line does not name the action: ${last}`);
      }
    }
    if (problems.length) { console.error(problems.join("; ")); process.exit(1); }
  ' "$1"
}

# Prints the commands an answer carries, one per line: before_commands, then the
# chosen option's commands, or the free-text command with the answer substituted.
answer_commands() {
  local question="$1" pick="$2"
  node -e '
    const q = JSON.parse(process.argv[1]);
    const pick = process.argv[2];
    const lines = [...(q.before_commands || [])];
    if (pick.startsWith("text:")) {
      if (!q.free_text) process.exit(4);
      lines.push(q.free_text.command.split("{{answer}}").join(pick.slice(5)));
    } else {
      const label = pick || q.recommended;
      const option = (q.options || []).find(item => item.label === label);
      if (!option) process.exit(5);
      if (!option.commands.length) process.exit(6);
      lines.push(...option.commands);
    }
    process.stdout.write(lines.join("\n"));
  ' "$question" "$pick"
}

# walk LABEL EXPECTED_KINDS [kind=answer ...] [clip:kind=value ...] [tolerate]
walk() {
  local label="$1" expected="$2"
  shift 2
  local -a script=("$@")
  local step status kind owner command question pick clip fp line out commands
  local visited="" tolerate=false entry seen="|"
  for entry in ${script[@]+"${script[@]}"}; do
    [[ "$entry" == tolerate ]] && tolerate=true
  done
  for ((step = 0; step < 40; step++)); do
    status="$(in_app "$REPO/bin/ios-provision status")" || {
      bad "$label" "status failed after: $visited"; return; }
    kind="$(field "$status" next.kind)"
    owner="$(field "$status" next.owner)"
    command="$(field "$status" next.command)"
    visited="${visited:+$visited }$kind"
    if [[ "$kind" == integrate_app ]]; then
      if [[ "$visited" == "$expected" ]]; then
        ok "$label reaches integrate_app ($visited)"
      else
        bad "$label took an unexpected path" "got:      $visited
  expected: $expected"
      fi
      return
    fi
    [[ -n "$command" ]] || { bad "$label" "$kind names nothing to run"; return; }
    fp="$kind:$(digest)"
    [[ "$seen" != *"|$fp|"* ]] || {
      bad "$label" "$kind comes back unchanged after its answer ($visited)"; return; }
    seen="$seen$fp|"

    pick="" clip=""
    for entry in ${script[@]+"${script[@]}"}; do
      [[ "$entry" == "$kind="* ]] && pick="${entry#*=}"
      [[ "$entry" == "clip:$kind="* ]] && clip="${entry#*=}"
    done
    [[ -z "$clip" ]] || printf '%s' "$clip" > "$STATE/clipboard"

    if [[ "$owner" == human ]]; then
      [[ "$(field "$status" next.question)" != null ]] || {
        bad "$label" "human step $kind carries no question"; return; }
      question="$(in_app "$command")" || {
        bad "$label" "$kind names a screen the tool will not render: $command"; return; }
      prompt_names_action "$question" || {
        bad "$label" "$kind: $(prompt_names_action "$question" 2>&1)"; return; }
      commands="$(answer_commands "$question" "$pick")" || {
        bad "$label" "the answer to $kind (${pick:-recommended}) carries no command"; return; }
    else
      commands="$command"
    fi
    local screen screen_kind screen_pick screen_commands
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      if [[ "$line" == *"/ios-provision question --kind "* ]]; then
        screen_kind="${line##*--kind }"
        screen_kind="${screen_kind%% *}"
        visited="$visited ($screen_kind)"
        screen="$(in_app "$line")" || {
          bad "$label" "$kind leads to a screen the tool will not render: $line"; return; }
        prompt_names_action "$screen" || {
          bad "$label" "$screen_kind: $(prompt_names_action "$screen" 2>&1)"; return; }
        screen_pick=""
        for entry in ${script[@]+"${script[@]}"}; do
          [[ "$entry" == "$screen_kind="* ]] && screen_pick="${entry#*=}"
        done
        screen_commands="$(answer_commands "$screen" "$screen_pick")" || {
          bad "$label" "the answer to $screen_kind carries no command"; return; }
        line="$screen_commands"
      fi
      while IFS= read -r line; do
        [[ -n "$line" && "$line" != *"/ios-provision status" ]] || continue
        if ! out="$(in_app "$line" 2>&1 >/dev/null)"; then
          [[ "$tolerate" == true ]] || {
            bad "$label" "$kind: '$line' failed: $out"; return; }
        fi
      done <<< "$line"
    done <<< "$commands"
  done
  bad "$label" "still provisioning after 40 steps ($visited)"
}

PUSH_FEATURES="push-notifications"
MANUAL_PATH="choose_features choose_identity choose_region choose_jwt confirm_scope choose_bundle choose_apple_setup confirm_manual_apple apple_step_app_id apple_step_push apple_step_apns_key import_apns validate_apns configure_iterable capture_iterable validate_iterable configure_server validate_server configure_iterable_app configure_iterable_push integrate_app"
EXISTING_PATH="choose_features choose_identity choose_region choose_jwt (help_jwt) confirm_scope choose_bundle choose_apple_setup confirm_existing_apple import_apns validate_apns configure_iterable capture_iterable validate_iterable configure_server validate_server configure_iterable_app configure_iterable_push integrate_app"
new_app manual-push
walk "guided manual Apple push path, one Apple Developer step per screen" "$MANUAL_PATH" \
  "choose_features=Push notifications" \
  "choose_identity=Email" \
  "choose_region=US project" \
  "choose_apple_setup=I don't have it set up yet — walk me through it" \
  "import_apns=text:$APNS_PATH" \
  "clip:capture_iterable=$MOBILE_KEY" \
  "clip:configure_server=$SERVER_KEY" \
  "configure_iterable_app=I've created the iOS app" \
  "configure_iterable_push=Configured and read back"
target_name="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).name)' "$WORKSPACE/target.json" 2>/dev/null)"
apns_meta="$(cat "$WORKSPACE/apns.json" 2>/dev/null)"
guide_steps="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).steps.join(","))' "$WORKSPACE/apple-guide.json" 2>/dev/null)"
readiness_via="$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).via)' "$WORKSPACE/apple-readiness.json" 2>/dev/null)"
if [[ "$guide_steps" == app-id,push,apns-key && "$readiness_via" == walkthrough ]]; then
  ok "the walkthrough recorded each Apple step before handing off to the APNs import"
else
  bad "the walkthrough did not record its Apple steps" "steps=$guide_steps via=$readiness_via"
fi
if [[ "$target_name" == "Sample Shop" ]] &&
    grep -q '"key_id": "APNSKEY001"' <<< "$apns_meta" &&
    grep -q '"team_id": "TEAMID0001"' <<< "$apns_meta" &&
    ! grep -rq "$MOBILE_KEY\|$SERVER_KEY" "$WORKSPACE"/*.json; then
  ok "the walk recorded the detected product name, filename Key ID, and build-setting Team ID"
else
  bad "the walk did not record the detected target and APNs identifiers"
fi

new_app existing-push
walk "existing Apple setup path" "$EXISTING_PATH" \
  "choose_features=Push notifications" \
  "choose_identity=User ID" \
  "choose_region=EU project" \
  "choose_jwt=I'm not sure — help me decide" \
  "choose_apple_setup=It's already set up — I'll confirm it" \
  "confirm_existing_apple=Record existing setup" \
  "import_apns=text:$APNS_PATH" \
  "clip:capture_iterable=$MOBILE_KEY" \
  "clip:configure_server=$SERVER_KEY" \
  "configure_iterable_app=It already exists" \
  "configure_iterable_push=Configured and read back"

new_app team-key
walk "App Store Connect Team-key path: the tool registers the App ID and Push" \
  "choose_features choose_identity choose_region choose_jwt confirm_scope choose_bundle choose_apple_setup asc_key asc_issuer asc_read asc_plan apple_step_apns_key import_apns validate_apns configure_iterable capture_iterable validate_iterable configure_server validate_server configure_iterable_app configure_iterable_push integrate_app" \
  "choose_features=Push notifications" \
  "choose_identity=Email" \
  "choose_region=US project" \
  "choose_apple_setup=I have an App Store Connect Team API key (Admin) — set up the App ID and Push for me" \
  "asc_key=text:$ASC_KEY_PATH" \
  "asc_issuer=text:57246542-96fe-1a63-e053-0824d011072a" \
  "import_apns=text:$APNS_PATH" \
  "clip:capture_iterable=$MOBILE_KEY" \
  "clip:configure_server=$SERVER_KEY" \
  "configure_iterable_app=I've created the iOS app" \
  "configure_iterable_push=Configured and read back"
if [[ "$(grep -c '^POST api.appstoreconnect.apple.com/v1/bundleIds ' "$STATE/apple-calls")" -eq 1 &&
      "$(grep -c '^POST api.appstoreconnect.apple.com/v1/bundleIdCapabilities ' "$STATE/apple-calls")" -eq 1 ]] &&
    grep -q '"tool_verified": true' "$WORKSPACE/apple-readiness.json"; then
  ok "the Team-key walk created the App ID and Push once and recorded tool-verified readiness"
else
  bad "the Team-key walk did not create the App ID and Push exactly once"
fi

new_app init-only
walk "free-text initialization only, reading an existing Mobile key's JWT setting" \
  "choose_features choose_identity choose_region choose_jwt check_jwt confirm_scope configure_iterable capture_iterable (help_copy_mobile_key) validate_iterable configure_server validate_server integrate_app" \
  "choose_features=text:initialization only" \
  "capture_iterable=I already have a Mobile key — show me how to copy it" \
  "choose_identity=Email" \
  "choose_region=US project" \
  "choose_jwt=I already have a Mobile key — check its setting" \
  "check_jwt=Require JWT is off" \
  "clip:capture_iterable=$MOBILE_KEY" \
  "clip:configure_server=$SERVER_KEY"
if [[ "$(node -e 'process.stdout.write(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).features.join(","))' "$WORKSPACE/scope.json" 2>/dev/null)" == sdk-initialization ]]; then
  ok "initialization only records the basic scope"
else
  bad "initialization only did not record the basic scope"
fi

new_app server-in-mobile-slot
walk "a Server-side key pasted into the Mobile slot is replaced, not looped on" \
  "choose_features choose_identity choose_region choose_jwt confirm_scope configure_iterable capture_iterable validate_iterable replace_mobile_key validate_iterable configure_server validate_server integrate_app" \
  "choose_features=text:initialization only" \
  "choose_identity=Email" \
  "choose_region=US project" \
  "clip:capture_iterable=$SERVER_KEY" \
  "clip:replace_mobile_key=$MOBILE_KEY" \
  "clip:configure_server=$SERVER_KEY" \
  tolerate
if grep -q '^ITERABLE_API_KEY=mobile-key-canary-' "$WORKSPACE/.env" &&
    grep -q '^ITERABLE_SERVER_KEY=server-key-canary-' "$WORKSPACE/.env" &&
    grep -q 'ITERABLE_API_KEY = mobile-key-canary-' "$WORKSPACE/IterableSecrets.xcconfig"; then
  ok "replacing the Mobile key keeps both slots distinct and the xcconfig current"
else
  bad "replacing the Mobile key left the wrong value in a slot"
fi

touch "$STATE/rotated-$SERVER_KEY"
in_app "$REPO/bin/ios-provision validate-server" >/dev/null 2>"$ROOT/rotated.err"
rotated_rc=$?
rotated_status="$(in_app "$REPO/bin/ios-provision status")"
if [[ "$rotated_rc" -eq 2 &&
      "$(field "$rotated_status" next.kind)" == replace_server_key ]] &&
    grep -q 'capture-server --replace --confirm' "$ROOT/rotated.err"; then
  ok "a rotated Server-side key is re-validated after setup and routed to replacement"
else
  bad "a rotated Server-side key could not be re-validated or replaced" "$(cat "$ROOT/rotated.err")"
fi
walk "a rotated Server-side key is replaced" \
  "replace_server_key validate_server integrate_app" \
  "clip:replace_server_key=$ROTATED_SERVER_KEY"

((FAILED)) && exit 1
exit 0
