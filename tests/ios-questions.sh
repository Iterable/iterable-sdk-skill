#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; [[ $# -lt 2 ]] || printf '  %s\n' "$2"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-questions-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-questions-test.*|/private/tmp/iterable-ios-questions-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

WORKSPACE="$ROOT/app/.iterable/ios"
mkdir -p "$ROOT/app"
BIN="$(pwd)/bin"

jstr() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' -- "$1"
}

# Most questions are previewed through ios-provision. The two final dashboard
# questions require completed credential state, so their pure renderers are
# exercised directly here and their state gates are covered in ios-provision.sh.
source bin/ios-questions.sh

question() {
  local kind="$1" bundle="${2:-}"
  case "$kind" in
    configure_server)
      ios_q_configure_server "${bundle:-US}"
      return
      ;;
    configure_iterable_app)
      ios_q_configure_iterable_app \
        "${bundle:-com.example.sampleshop}" "Sample Shop" US
      return
      ;;
    configure_iterable_push)
      ios_q_configure_iterable_push \
        "${bundle:-com.example.sampleshop}" US \
        "/secure/AuthKey_APNSKEY001.p8" APNSKEY001 TEAMID0001
      return
      ;;
    install_tools)
      ios_q_install_tools "xcodebuild, node"
      return
      ;;
    replace_mobile_key)
      ios_q_replace_mobile_key US false \
        "This key can read the project's channel list, which a Mobile key cannot."
      return
      ;;
    replace_server_key)
      ios_q_replace_server_key EU \
        "The Server-side key probe answered HTTP 401 without the project's channel list."
      return
      ;;
    choose_bundle_detected)
      ios_q_choose_bundle com.example.sampleshop "Sample Shop" xcodebuild
      return
      ;;
    import_apns_team)
      ios_q_import_apns TEAMID0001
      return
      ;;
    apple_step_app_id|apple_step_apns_key)
      "ios_q_$kind" "${bundle:-com.example.sampleshop}" "Sample Shop"
      return
      ;;
    apple_step_push)
      ios_q_apple_step_push "${bundle:-com.example.sampleshop}"
      return
      ;;
    import_android)
      ios_q_import_android "Android setup: Mobile key, Server-side key, EU region."
      return
      ;;
    carry_scope)
      ios_q_carry_scope push-notifications,sdk-initialization user-id ios-step0
      return
      ;;
    fix_expo_gitignore)
      ios_q_fix_expo_gitignore "$ROOT/expo-app"
      return
      ;;
    check_jwt)
      ios_q_check_jwt "${bundle:-US}"
      return
      ;;
  esac
  local -a args=(question --kind "$kind")
  [[ -z "$bundle" ]] || args+=(--bundle-id "$bundle")
  env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision "${args[@]}"
}

cat > "$ROOT/shape.js" <<'JS'
let input = "";
process.stdin.on("data", chunk => input += chunk).on("end", () => {
  const question = JSON.parse(input);
  const errors = [];
  for (const field of [
    "header", "prompt", "selection", "context", "requires",
    "recommended", "before_commands", "options"
  ]) {
    if (!(field in question)) errors.push(`missing ${field}`);
  }
  if (String(question.header || "").length > 12) errors.push("header exceeds 12 characters");
  if (!String(question.prompt || "").endsWith("?")) errors.push("prompt is not a question");
  if (!["single", "multiple"].includes(question.selection)) errors.push("invalid selection");
  if (!Array.isArray(question.context) || question.context.length === 0) errors.push("missing context");
  if (!Array.isArray(question.requires)) errors.push("requires is not an array");
  if (!Array.isArray(question.before_commands)) errors.push("before_commands is not an array");
  if (!Array.isArray(question.options) ||
      question.options.length < 2 ||
      question.options.length > 4) {
    errors.push("options must number 2-4");
  }
  if (question.recommended !== null &&
      !question.options.some(option => option.label === question.recommended)) {
    errors.push("recommended label is not an option");
  }
  for (const [index, option] of (question.options || []).entries()) {
    for (const field of ["label", "description", "effect", "relay", "commands"]) {
      if (!(field in option)) errors.push(`option ${index + 1} missing ${field}`);
    }
    if (!Array.isArray(option.commands)) errors.push(`option ${index + 1} commands is not an array`);
    if (typeof option.relay !== "string") errors.push(`option ${index + 1} relay is not a string`);
    if (option.relay && option.commands.length) errors.push(`option ${index + 1} both relays and runs`);
  }
  if (question.selection === "multiple" && question.before_commands.length === 0) {
    errors.push("multiple selector cannot reset its prior proposal");
  }
  if (question.free_text &&
      (!question.free_text.hint ||
       !question.free_text.effect ||
       !String(question.free_text.command || "").includes("{{answer}}"))) {
    errors.push("free_text is not executable");
  }
  if (errors.length) {
    console.error(errors.join("; "));
    process.exit(1);
  }
  process.stdout.write(`${question.selection}, ${question.options.length} options`);
});
JS

cat > "$ROOT/shape-all.js" <<'JS'
// Screens that ask for something the developer may not have yet must offer a
// developer-side answer that runs something; relays must carry their own steps.
const artifact = new Set([
  "choose_identity", "choose_region", "choose_jwt", "check_jwt",
  "configure_iterable", "capture_iterable", "configure_server",
  "replace_mobile_key", "replace_server_key", "choose_bundle",
  "choose_apple_setup", "confirm_existing_apple", "confirm_manual_apple",
  "apple_step_app_id", "apple_step_push", "apple_step_apns_key", "import_apns",
  "configure_iterable_app", "configure_iterable_push", "proof_region",
  "proof_identity_type", "proof_bundle", "proof_identity",
  "proof_switch_identity", "proof_app", "asc_key", "asc_issuer",
  "asc_rejected", "asc_conflict", "replace_apns_key", "fix_expo_gitignore"
]);
const developerSide = /^(I don't have|I do not have|I don't know|I'm not sure|I am not sure|Help me)\b/;
const concrete = text => /https?:\/\//.test(text) || /(^|\s)1\.\s/.test(text) || /\/bin\/ios-/.test(text);
let input = "";
process.stdin.on("data", chunk => input += chunk).on("end", () => {
  const errors = [];
  for (const line of input.split("\n").filter(Boolean)) {
    const tab = line.indexOf("\t");
    const kind = line.slice(0, tab);
    let q;
    try { q = JSON.parse(line.slice(tab + 1)); } catch { errors.push(`${kind}: not JSON`); continue; }
    const options = q.options || [];
    if (artifact.has(kind) && !options.some(option =>
        developerSide.test(option.label) && option.commands.length > 0)) {
      errors.push(`${kind}: no developer-side help option that runs something`);
    }
    for (const option of options) {
      if (option.relay && !concrete(option.relay)) {
        errors.push(`${kind}: relay "${option.label}" has no URL, numbered steps, or command`);
      }
      if (option.relay && /^Show\b/.test(option.label)) {
        errors.push(`${kind}: "${option.label}" promises to show something but only relays`);
      }
      if (/^Show\b/.test(option.label) && option.commands.length === 0) {
        errors.push(`${kind}: "${option.label}" shows nothing`);
      }
    }
    {
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
      for (const problem of problems) errors.push(`${kind}: ${problem}`);
    }
    if (kind.startsWith("help_") && !options.some(option =>
        option.commands.some(command => /\/(ios-provision|ios-prepare-proof) status$/.test(command)))) {
      errors.push(`${kind}: help screen has no way back`);
    }
  }
  if (errors.length) { console.error(errors.join("\n")); process.exit(1); }
});
JS

shape() {
  local kind="$1" bundle="${2:-}" output
  if output="$(question "$kind" "$bundle" | node "$ROOT/shape.js")"; then
    ok "$kind has a renderable question contract ($output)"
  else
    bad "$kind does not satisfy the question contract"
  fi
}

shape choose_features
shape carry_scope
shape choose_more_features
shape choose_identity
shape choose_region
shape choose_jwt
shape check_jwt
shape check_jwt EU

env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision answer \
  --field features --value event-tracking,user-profiles >/dev/null
env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision answer \
  --field identity-mode --value email >/dev/null
env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision answer \
  --field region --value US >/dev/null
env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision answer \
  --field jwt-enabled --value false >/dev/null
shape confirm_scope
env IOS_WORKSPACE="$WORKSPACE" bin/ios-provision record-scope \
  --from-answers --confirm >/dev/null
shape configure_iterable
shape capture_iterable
shape configure_server US
shape choose_bundle
shape choose_bundle_detected
shape choose_apple_setup
shape confirm_existing_apple com.example.sampleshop
shape confirm_manual_apple com.example.sampleshop
shape apple_step_app_id
shape apple_step_push
shape apple_step_apns_key
shape import_apns
shape import_apns_team
shape install_tools
shape replace_mobile_key
shape replace_server_key
shape configure_iterable_app com.example.sampleshop
shape configure_iterable_push com.example.sampleshop

apns_question="$(question import_apns)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...(q.context || [])].join("\n");
  const imported=q.options.find(option=>option.label==="Enter the .p8 path");
  const terminal=q.options.find(option=>option.label==="I\u0027ll import it in my terminal");
  process.exit(
    context.includes("cannot prove which Apple service") &&
    context.includes("Apple Push Notification service is enabled") &&
    imported?.effect.includes("service assignment remains human-confirmed") &&
    q.free_text?.command.endsWith("/bin/ios-provision import-apns --file \u0027{{answer}}\u0027 --confirm") &&
    terminal?.relay.includes("/bin/ios-provision import-apns --file") &&
    !context.includes("BEGIN PRIVATE KEY")
      ? 0
      : 1
  );
' "$apns_question"; then
  ok "APNs import runs from a path answer and distinguishes key shape from service assignment"
else
  bad "APNs import has no runnable path or overstated what a local private-key check proves"
fi

apns_team_question="$(question import_apns_team)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...q.context].join("\n");
  process.exit(
    context.includes("Team ID: TEAMID0001") &&
    context.includes("AuthKey_<KEYID>.p8 file name") &&
    q.free_text.command.includes("--file \u0027{{answer}}\u0027 --team-id TEAMID0001 --confirm")
      ? 0
      : 1
  );
' "$apns_team_question"; then
  ok "APNs import carries the Team ID read from DEVELOPMENT_TEAM"
else
  bad "APNs import ignored the detected Team ID"
fi

bundle_question="$(question choose_bundle_detected)"
undetected_bundle_question="$(question choose_bundle)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const none=JSON.parse(process.argv[2]);
  const use=q.options.find(option=>option.label==="Use the detected app target");
  process.exit(
    q.recommended==="Use the detected app target" &&
    use?.commands[0].endsWith("record-target --bundle-id com.example.sampleshop --name Sample\\ Shop --confirm") &&
    [q.prompt,...q.context].join("\n").includes("Product name: Sample Shop") &&
    q.free_text.command.includes("--bundle-id \u0027{{answer}}\u0027 --confirm") &&
    none.recommended===null &&
    none.options.every(option=>option.relay || option.commands.length) &&
    !JSON.stringify([q, none]).includes("Iterable iOS App")
      ? 0
      : 1
  );
' "$bundle_question" "$undetected_bundle_question"; then
  ok "choose_bundle runs record-target for the detected target and never invents an app name"
else
  bad "choose_bundle has no runnable detected target or falls back to a placeholder name"
fi

tools_question="$(question install_tools)"
replace_mobile_question="$(question replace_mobile_key)"
replace_server_question="$(question replace_server_key)"
if node -e '
  const tools=JSON.parse(process.argv[1]);
  const mobile=JSON.parse(process.argv[2]);
  const server=JSON.parse(process.argv[3]);
  process.exit(
    tools.options.some(option=>option.relay.includes("xcodebuild, node")) &&
    tools.options.some(option=>option.commands.some(command=>command.endsWith("/bin/ios-provision status"))) &&
    mobile.options[0].commands[0].endsWith("capture-mobile --replace --region US --jwt-enabled false --confirm") &&
    [mobile.prompt,...mobile.context].join("\n").includes("channel list") &&
    server.options[0].commands[0].endsWith("capture-server --replace --confirm") &&
    [server.prompt,...server.context].join("\n").includes("https://app.eu.iterable.com/settings/apiKeys")
      ? 0
      : 1
  );
' "$tools_question" "$replace_mobile_question" "$replace_server_question"; then
  ok "missing tools and rejected keys each name a relay or a runnable command"
else
  bad "missing tools or rejected keys left a screen with nothing to do"
fi

apple_path_question="$(question choose_apple_setup)"
existing_apple_question="$(question confirm_existing_apple com.example.sampleshop)"
manual_apple_question="$(question confirm_manual_apple com.example.sampleshop)"
if node -e '
  const choose=JSON.parse(process.argv[1]);
  const existing=JSON.parse(process.argv[2]);
  const manual=JSON.parse(process.argv[3]);
  const labels=choose.options.map(option=>option.label);
  process.exit(
    labels.length===3 &&
    labels.includes("It\u0027s already set up \u2014 I\u0027ll confirm it") &&
    choose.recommended==="I don\u0027t have it set up yet \u2014 walk me through it" &&
    choose.options[2].label==="I have an App Store Connect Team API key (Admin) \u2014 set up the App ID and Push for me" &&
    choose.options[2].commands[0].endsWith("record-apple-setup --strategy team-key --confirm") &&
    !JSON.stringify(choose).includes("team-api") &&
    [choose.prompt,...choose.context].join("\n").includes("after showing you the exact plan") &&
    [existing.prompt,...existing.context].join("\n").includes("developer-observed evidence") &&
    [manual.prompt,...manual.context].join("\n").includes("Account Holder or Admin") &&
    manual.recommended==="I don\u0027t have these yet \u2014 walk me through it" &&
    manual.options[0].commands[0].endsWith("record-apple-step --step start --confirm") &&
    manual.options.some(option=>option.label==="Record manual setup" &&
      option.commands[0].endsWith("record-apple-readiness --strategy guided-manual --confirm"))
      ? 0
      : 1
  );
' "$apple_path_question" "$existing_apple_question" "$manual_apple_question"; then
  ok "Apple path selectors offer only existing and manual setup"
else
  bad "Apple path selectors still offer Team API-key automation"
fi

jwt_screen="$(question choose_jwt)"
jwt_check_us="$(question check_jwt US)"
jwt_check_eu="$(question check_jwt EU)"
if node -e '
  const [jwt,us,eu]=process.argv.slice(1).map(JSON.parse);
  const text=q=>[q.prompt,...q.context].join("\n");
  const runnable=q=>q.options.every(option=>!option.relay && option.commands.length>0);
  const recommended=jwt.options.find(option=>option.label===jwt.recommended);
  process.exit(
    jwt.recommended==="I don\u0027t have a Mobile key yet \u2014 help me" &&
    recommended?.description.includes("creating the Mobile key with Require JWT Off") &&
    jwt.options.find(option=>option.label==="I\u0027m not sure \u2014 help me decide")
      ?.commands[0].endsWith("question --kind help_jwt") &&
    recommended?.commands[0].endsWith("answer --field jwt-enabled --value false") &&
    runnable(jwt) &&
    /later step/.test(jwt.prompt) &&
    /backend that issues user-specific Iterable JWTs/.test(jwt.prompt) &&
    text(jwt).includes("You do not need a Mobile API key yet") &&
    text(jwt).includes("Require JWT setting must match this answer") &&
    runnable(us) && runnable(eu) &&
    text(us).includes("https://app.iterable.com/settings/apiKeys") &&
    text(eu).includes("https://app.eu.iterable.com/settings/apiKeys") &&
    us.options.some(option=>option.label==="Show these steps again" &&
      option.commands[0].endsWith("question --kind check_jwt")) &&
    us.options.some(option=>option.label.startsWith("I don\u0027t have a Mobile key") &&
      option.commands[0].endsWith("answer --field jwt-enabled --value false")) &&
    us.options.some(option=>option.commands[0].endsWith("answer --field jwt-enabled --value true")) &&
    us.options.some(option=>option.commands[0].endsWith("answer --field jwt-enabled --value false"))
      ? 0
      : 1
  );
' "$jwt_screen" "$jwt_check_us" "$jwt_check_eu"; then
  ok "the JWT screen recommends No JWT for a new app, and checking an existing key is a runnable, re-askable step"
else
  bad "the JWT screen asks about a key that does not exist yet or leaves a relay dead end"
fi

identity_verified() {
  proof_question_identity_and_confirm "Bundle: com.example.sampleshop" user-id SIM-1 \
    "$(proof_identity_steps user-id SIM-1 simulator SampleShop)" \
    "The app's proof marker logged U-1, and Iterable has this Simulator's current device token on that user." \
    U-1 "It is offered because the app's proof marker logged it." "" "" com.example.sampleshop
}
identity_unverified() {
  proof_question_identity_and_confirm "Bundle: com.example.sampleshop" user-id SIM-1 \
    "$(proof_identity_steps user-id SIM-1 simulator SampleShop)" \
    "The agent proposed U-2, but Iterable doesn't have this Simulator's token on it yet; sign in or relaunch, then check again." \
    "" "" "$BIN/ios-prepare-proof status --identity-candidate U-2" \
    "$BIN/ios-prepare-proof read-identity --confirm --identity-candidate U-2" com.example.sampleshop
}
screen_dump() {
  local kind
  for kind in choose_features choose_more_features choose_identity choose_region choose_jwt; do
    printf '%s\t%s\n' "$kind" "$(ios_question "$kind")"
  done
  printf 'check_jwt\t%s\n' "$(ios_q_check_jwt US)"
  printf 'import_android\t%s\n' "$(ios_q_import_android "Android setup: Mobile key, Server-side key, EU region.")"
  printf 'import_android\t%s\n' "$(ios_q_import_android "Android setup: Mobile key, Server-side key, EU region." push-notifications,sdk-initialization)"
  printf 'fix_expo_gitignore\t%s\n' "$(ios_q_fix_expo_gitignore /app)"
  printf 'confirm_scope\t%s\n' "$(ios_q_confirm_scope push-notifications email US false)"
  printf 'confirm_scope\t%s\n' "$(ios_q_confirm_scope push-notifications email US false react-native-step0)"
  printf 'confirm_scope\t%s\n' "$(ios_q_confirm_scope push-notifications user-id US false ios-step0 ios-step0)"
  printf 'carry_scope\t%s\n' "$(ios_q_carry_scope push-notifications,sdk-initialization user-id ios-step0)"
  printf 'carry_scope\t%s\n' "$(ios_q_carry_scope event-tracking,sdk-initialization "" react-native-step0)"
  printf 'carry_scope\t%s\n' "$(ios_q_carry_scope "" unknown-user ios-step0)"
  printf 'configure_iterable\t%s\n' "$(ios_q_configure_iterable US false)"
  printf 'capture_iterable\t%s\n' "$(ios_q_capture_iterable US false)"
  printf 'configure_server\t%s\n' "$(ios_q_configure_server US false)"
  printf 'replace_mobile_key\t%s\n' "$(ios_q_replace_mobile_key US false "Rejected.")"
  printf 'replace_server_key\t%s\n' "$(ios_q_replace_server_key US "Rejected.")"
  printf 'choose_bundle\t%s\n' "$(ios_q_choose_bundle)"
  printf 'choose_bundle\t%s\n' "$(ios_q_choose_bundle com.example.sampleshop "Sample Shop" xcodebuild)"
  printf 'choose_apple_setup\t%s\n' "$(ios_q_choose_apple_setup)"
  printf 'confirm_existing_apple\t%s\n' "$(ios_q_confirm_existing_apple com.example.sampleshop)"
  printf 'confirm_manual_apple\t%s\n' "$(ios_q_confirm_manual_apple com.example.sampleshop)"
  printf 'apple_step_app_id\t%s\n' "$(ios_q_apple_step_app_id com.example.sampleshop "Sample Shop")"
  printf 'apple_step_push\t%s\n' "$(ios_q_apple_step_push com.example.sampleshop)"
  printf 'apple_step_apns_key\t%s\n' "$(ios_q_apple_step_apns_key com.example.sampleshop "Sample Shop")"
  printf 'install_tools\t%s\n' "$(ios_q_install_tools "xcodebuild")"
  printf 'import_apns\t%s\n' "$(ios_q_import_apns)"
  printf 'import_apns\t%s\n' "$(ios_q_import_apns TEAMID0001)"
  printf 'configure_iterable_app\t%s\n' "$(ios_q_configure_iterable_app com.example.sampleshop "Sample Shop" US)"
  printf 'configure_iterable_push\t%s\n' "$(ios_q_configure_iterable_push com.example.sampleshop US /secure/AuthKey_APNSKEY001.p8 APNSKEY001 TEAMID0001)"
  for kind in proof_region proof_environment proof_identity_type proof_bundle proof_identity proof_switch_identity proof_profile proof_event proof_tap proof_logout; do
    printf '%s\t%s\n' "$kind" "$(ios_question "$kind")"
  done
  printf 'proof_app\t%s\n' "$(ios_question proof_app)"
  printf 'proof_app\t%s\n' "$(ios_question proof_app instrumented)"
  printf 'proof_device\t%s\n' "$(ios_q_proof_device '[]')"
  printf 'confirm_proof\t%s\n' "$(ios_q_confirm_proof "Bundle: com.example.sampleshop")"
  eval "$(sed -n '/^proof_question_identity_and_confirm() {/,/^}/p;/^proof_identity_steps() {/,/^}/p' bin/ios-provision)"
  printf 'proof_identity\t%s\n' "$(proof_question_identity_and_confirm "Bundle: com.example.sampleshop" email SIM-1)"
  printf 'proof_identity\t%s\n' "$(proof_question_identity_and_confirm "Bundle: com.example.sampleshop" user-id SIM-1 \
    "$(proof_identity_steps user-id SIM-1 simulator SampleShop)")"
  printf 'proof_identity\t%s\n' "$(identity_verified)"
  printf 'proof_identity\t%s\n' "$(identity_unverified)"
  printf 'proof_artifact\t%s\n' "$(ios_q_proof_artifact com.example.sampleshop \
    /dd/Build/Products/Debug-iphonesimulator/SampleShop.app 2026-10-22T09:00:00Z "not installed" build)"
  printf 'proof_device\t%s\n' "$(ios_q_proof_device '[]' 27.0)"
  for kind in help_identity help_proof_identity_type help_region help_proof_region help_jwt \
      help_bundle help_proof_bundle help_apns_key help_proof_identity \
      help_proof_switch_identity help_proof_identity_start help_proof_app; do
    printf '%s\t%s\n' "$kind" "$(ios_question "$kind")"
  done
  printf 'help_apns_import\t%s\n' "$(ios_question help_apns_import TEAMID0001)"
  printf 'help_mobile_key\t%s\n' "$(ios_q_help_mobile_key US false)"
  printf 'help_server_key\t%s\n' "$(ios_q_help_server_key EU true)"
  printf 'help_copy_mobile_key\t%s\n' "$(ios_q_help_copy_mobile_key US false)"
  printf 'help_copy_server_key\t%s\n' "$(ios_q_help_copy_server_key EU)"
  printf 'help_app_id\t%s\n' "$(ios_q_help_app_id com.example.sampleshop)"
  printf 'help_push\t%s\n' "$(ios_q_help_push com.example.sampleshop)"
  printf 'help_iterable_app\t%s\n' "$(ios_q_help_iterable_app com.example.sampleshop "Sample Shop" US)"
  printf 'help_iterable_push\t%s\n' "$(ios_q_help_iterable_push com.example.sampleshop /secure/AuthKey_APNSKEY001.p8 APNSKEY001 TEAMID0001)"
  printf 'asc_key\t%s\n' "$(ios_question asc_key)"
  printf 'asc_issuer\t%s\n' "$(ios_question asc_issuer)"
  printf 'asc_plan\t%s\n' "$(ios_question asc_plan com.example.sampleshop - create-bundle-id,enable-push "Sample Shop")"
  printf 'asc_rejected\t%s\n' "$(ios_question asc_rejected com.example.sampleshop "App Store Connect rejected the key (HTTP 401).")"
  printf 'asc_conflict\t%s\n' "$(ios_question asc_conflict com.example.sampleshop "Apple refused to create com.example.sampleshop (HTTP 409).")"
  printf 'help_asc_key\t%s\n' "$(ios_question help_asc_key)"
  printf 'replace_apns_key\t%s\n' "$(ios_question replace_apns_key "APNs rejected the provider token." APNSKEY001 TEAMID0001)"
  printf 'help_apns_replace\t%s\n' "$(ios_question help_apns_replace TEAMID0001)"
  printf 'replace_apns_key\t%s\n' "$(ios_question replace_apns_key "Apple accepted this key, but it isn't allowed to send to com.example.sampleshop." APNSKEY001 TEAMID0001 apns-key-topic-not-allowed com.example.sampleshop)"
}
if screen_dump | node "$ROOT/shape-all.js" 2>"$ROOT/shape-all.err"; then
  ok "every screen offers developer-side help, relays carry their own steps, and help screens lead back"
else
  bad "a screen leaves a developer without a help path or with a relay that has no steps" "$(cat "$ROOT/shape-all.err")"
fi

copy_paths="$(
  printf '%s\n' "$(ios_q_configure_iterable US false)" "$(ios_q_capture_iterable US false)" \
    "$(ios_q_configure_server US false)" "$(ios_q_help_copy_mobile_key EU true)" \
    "$(ios_q_help_copy_server_key US)"
)"
if printf '%s' "$copy_paths" | node -e '
  let input="";
  process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
    const [chooser,capture,server,copyMobile,copyServer]=input.trim().split("\n").map(JSON.parse);
    const leads=(q,label,kind)=>q.options.some(option=>option.label===label &&
      option.commands[0].endsWith(`question --kind ${kind}`));
    const text=q=>[q.prompt,...q.context].join("\n");
    process.exit(
      leads(chooser,"I already have a Mobile key \u2014 show me how to copy it","help_copy_mobile_key") &&
      leads(capture,"I already have a Mobile key \u2014 show me how to copy it","help_copy_mobile_key") &&
      leads(server,"I already have a Server-side key \u2014 show me how to copy it","help_copy_server_key") &&
      text(capture).includes("Copy that one instead of creating another") &&
      copyMobile.options[0].commands[0].endsWith("capture-mobile --region EU --jwt-enabled true --confirm") &&
      text(copyMobile).includes("https://app.eu.iterable.com/settings/apiKeys") &&
      text(copyMobile).includes("JWT setting is On") &&
      copyServer.options[0].commands[0].endsWith("capture-server --confirm") &&
      [copyMobile,copyServer].every(q=>q.options.some(option=>option.commands[0]?.endsWith("/ios-provision status")))
        ? 0
        : 1
    );
  });
'; then
  ok "the Mobile and Server-side key screens offer copying an existing key next to creating one"
else
  bad "a developer who already has a key is only told to create a new one"
fi

asc_screens="$(printf '%s\n' \
  "$(ios_question asc_key)" \
  "$(ios_question asc_plan com.example.sampleshop - enable-push "Sample Shop")" \
  "$(ios_question replace_apns_key "APNs rejected the provider token." APNSKEY001 TEAMID0001)")"
if printf '%s' "$asc_screens" | node -e '
  let input="";
  process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
    const [key, plan, apns]=input.trim().split("\n").map(JSON.parse);
    process.exit(
      key.prompt.startsWith("This is your App Store Connect API key, not the APNs key.") &&
      key.prompt.includes("https://appstoreconnect.apple.com/access/integrations/api") &&
      key.prompt.includes("Individual keys cannot register App IDs") &&
      key.free_text.command.endsWith("record-asc-key --file \u0027{{answer}}\u0027 --confirm") &&
      plan.prompt.includes("1. Enable Push Notifications on com.example.sampleshop.") &&
      !plan.prompt.includes("Register the explicit App ID") &&
      plan.recommended==="Apply this plan" &&
      plan.options[0].commands[0].endsWith("asc-apply --confirm") &&
      apns.free_text.command.includes("import-apns --replace --file") &&
      apns.options.some(option=>option.commands[0]?.endsWith("validate-apns"))
        ? 0
        : 1
    );
  });
'; then
  ok "the Team-key screens name which key they want, and the plan lists only the changes it will make"
else
  bad "the Team-key or APNs replace screens are missing their key identity, plan, or re-import path"
fi

step_app_id="$(question apple_step_app_id)"
step_push="$(question apple_step_push)"
step_key="$(question apple_step_apns_key)"
if node -e '
  const [a,p,k]=process.argv.slice(1).map(JSON.parse);
  const text=q=>[q.prompt,...q.context].join("\n");
  const done=(q,step)=>q.options.find(option=>option.label===q.recommended)
    ?.commands[0].endsWith(`record-apple-step --step ${step} --confirm`);
  process.exit(
    a.header==="Apple 1 of 3" && p.header==="Apple 2 of 3" && k.header==="Apple 3 of 3" &&
    a.prompt.includes("Apple Developer → Identifiers") &&
    a.prompt.startsWith("1. Open https://developer.apple.com/account/resources/identifiers/list") &&
    p.prompt.includes("https://developer.apple.com/account/resources/identifiers/list") &&
    k.prompt.includes("https://developer.apple.com/account/resources/authkeys/list") &&
    [a,p,k].every(q=>q.prompt.split("\n").pop().endsWith("\u2014 done?") &&
      q.options.some(option=>option.label==="Show the steps again" &&
        option.description.startsWith("Re-prints") &&
        option.commands[0].includes("question --kind apple_step_"))) &&
    a.prompt.includes("App ID com.example.sampleshop") &&
    p.prompt.includes("com.example.sampleshop") && p.prompt.includes("Push Notifications") &&
    k.prompt.includes("Apple Developer → Keys") && k.prompt.includes(".p8") &&
    text(a).includes("https://developer.apple.com/account/resources/identifiers/list") &&
    text(a).includes("App IDs, Continue, then App") &&
    text(a).includes("Description: Sample Shop") &&
    text(a).includes("Explicit and enter com.example.sampleshop exactly") &&
    text(a).includes("Simulator-only build does not make Xcode register this App ID") &&
    text(p).includes("tick Push Notifications") &&
    text(p).includes("read back") &&
    text(k).includes("One APNs key works for every app on the team") &&
    text(k).includes("https://developer.apple.com/account/resources/authkeys/list") &&
    text(k).includes("outside this repository") &&
    done(a,"app-id") && done(p,"push") && done(k,"apns-key")
      ? 0
      : 1
  );
' "$step_app_id" "$step_push" "$step_key"; then
  ok "guided Apple setup is three screens whose prompts carry the action and whose answers record each step"
else
  bad "guided Apple setup does not walk the App ID, Push Notifications, and APNs key steps"
fi

all_questions=""
append_question() {
  local output
  if output="$(question "$@")"; then
    all_questions="${all_questions}${output}"$'\n'
  else
    bad "question $1 failed while assembling the complete contract"
  fi
}
append_question choose_features
append_question carry_scope
append_question choose_more_features
append_question choose_identity
append_question choose_region
append_question choose_jwt
append_question check_jwt EU
append_question import_android
append_question fix_expo_gitignore
append_question configure_iterable
append_question capture_iterable
append_question configure_server US
append_question choose_bundle
append_question choose_apple_setup
append_question confirm_existing_apple com.example.sampleshop
append_question confirm_manual_apple com.example.sampleshop
append_question apple_step_app_id
append_question apple_step_push
append_question apple_step_apns_key
append_question import_apns
append_question import_apns_team
append_question choose_bundle_detected
append_question install_tools
append_question replace_mobile_key
append_question replace_server_key
append_question configure_iterable_app com.example.sampleshop
append_question configure_iterable_push com.example.sampleshop
if grep -q '/bin/ios-provision ' <<< "$all_questions" &&
    ! grep -qE '"commands":\\[[^]]*"[^"]*(API_KEY|AuthKey_|BEGIN PRIVATE KEY)' \
      <<< "$all_questions"; then
  ok "question actions use the installed program without embedding credentials"
else
  bad "question actions are missing or expose credential material"
fi

if printf '%s' "$all_questions" | node -e '
  let input="";
  process.stdin.on("data",chunk=>input+=chunk).on("end",()=>{
    const bad=[];
    for (const line of input.split("\n").filter(Boolean)) {
      const q=JSON.parse(line);
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
      if (problems.length) bad.push(`${q.header}: ${problems.join("; ")}`);
    }
    if (bad.length) { console.error(bad.join("\n")); process.exit(1); }
  });
' 2>"$ROOT/prompt-rule.err"; then
  ok "every provisioning screen carries its links and numbered steps in the prompt, question last"
else
  bad "a screen keeps a link or step only in context, or its question is not last" "$(cat "$ROOT/prompt-rule.err")"
fi

scope_question="$(question choose_features)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const labels=q.options.map(option=>option.label);
  process.exit(
    q.selection==="multiple" &&
    q.options.length===4 &&
    labels.join("|")==="Push notifications|Events + user profiles|Deep links|More features" &&
    q.options[2].commands[0].endsWith("--field feature-deep-links --value true") &&
    q.options[2].description.includes("including links opened from push and in-app") &&
    !q.options[3].description.includes("deep links") &&
    q.before_commands.some(command=>command.endsWith("--field feature-deep-links --value false")) &&
    q.options.find(option =>
      option.label==="Events + user profiles"
    ).commands.length===2 &&
    q.free_text?.hint.includes("initialization only") &&
    q.free_text.command.endsWith("--field features --value \u0027{{answer}}\u0027") &&
    q.before_commands.length>=4 ? 0 : 1
  );
' "$scope_question"; then
  ok "iOS starts with one compact Android-style feature selector"
else
  bad "iOS still asks for scope one feature at a time"
fi

push_confirm_workspace="$ROOT/push-confirm/.iterable/ios"
mkdir -p "$push_confirm_workspace"
env IOS_WORKSPACE="$push_confirm_workspace" bin/ios-provision answer \
  --field features --value push-notifications >/dev/null
env IOS_WORKSPACE="$push_confirm_workspace" bin/ios-provision answer \
  --field identity-mode --value email >/dev/null
env IOS_WORKSPACE="$push_confirm_workspace" bin/ios-provision answer \
  --field region --value US >/dev/null
env IOS_WORKSPACE="$push_confirm_workspace" bin/ios-provision answer \
  --field jwt-enabled --value false >/dev/null
push_confirmation="$(
  env IOS_WORKSPACE="$push_confirm_workspace" \
    bin/ios-provision question --kind confirm_scope
)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...q.context].join("\n");
  const proceed=q.options.find(option =>
    option.label==="Record this scope and continue"
  );
  process.exit(
    context.includes("Apple and APNs prerequisite setup") &&
    context.includes("Iterable credentials come afterward") &&
    proceed?.effect.includes("Apple and APNs setup becomes the next state")
      ? 0
      : 1
  );
' "$push_confirmation"; then
  ok "push scope confirmation explains the provider-first next step"
else
  bad "push scope confirmation still promises Iterable credentials first"
fi

key_question="$(question configure_iterable)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const setup=q.options.find(option=>option.label==="I don\u0027t have a Mobile key yet \u2014 show me how");
  process.exit(
    setup?.commands.some(command=>command.includes("record-iterable-setup --driver guided")) &&
    q.options.some(option=>option.label==="The Mobile key is copied") &&
    q.options.some(option=>
      option.label==="I\u0027ll use my terminal" &&
      option.relay.includes("capture-mobile")
    ) ? 0 : 1
  );
' "$key_question"; then
  ok "Mobile-key setup offers guided navigation, secure capture, and terminal ownership"
else
  bad "Mobile-key setup does not match Android's guided dashboard ownership"
fi

guided_key_question="$(question capture_iterable)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...q.context].join("\n");
  process.exit(
    q.header==="Mobile key" &&
    q.prompt.split("\n").pop().startsWith("In Iterable → Integrations → API Keys, create a Mobile key") &&
    q.prompt.includes("Require JWT Off") &&
    context.includes("https://app.iterable.com/settings/apiKeys") &&
    context.includes("New API Key") &&
    context.includes("choose Mobile") &&
    context.includes("Require JWT to Off") &&
    q.prompt.split("\n").filter(line => /^[1-4]\. /.test(line)).length===4 &&
    q.options[0].label==="I\u0027ve copied the Mobile key" &&
    q.options.length===4 &&
    q.recommended==="I\u0027ve copied the Mobile key" &&
    !context.includes("web-operator") ? 0 : 1
  );
' "$guided_key_question"; then
  ok "guided Mobile-key step is a readable numbered selector with all actions"
else
  bad "guided Mobile-key step can collapse into malformed prose"
fi

server_key_question="$(question configure_server US)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...q.context].join("\n");
  process.exit(
    q.header==="Server key" &&
    context.includes("The Mobile key is ready") &&
    context.includes("https://app.iterable.com/settings/apiKeys") &&
    context.includes("Choose Server-side") &&
    context.includes("never enters the iOS app or Xcode configuration") &&
    q.prompt.split("\n").filter(line => /^[1-4]\. /.test(line)).length===4 &&
    q.options[0].label==="I\u0027ve copied the Server-side key" &&
    q.options[0].commands.some(command=>command.includes("capture-server --confirm")) &&
    q.recommended==="I\u0027ve copied the Server-side key"
      ? 0
      : 1
  );
' "$server_key_question"; then
  ok "Server-side key follows Mobile setup with a readable secure-capture screen"
else
  bad "Server-side key setup is missing, malformed, or presented as an app credential"
fi

region_question="$(question choose_region)"
jwt_question="$(question choose_jwt)"
if node -e '
  const region=JSON.parse(process.argv[1]);
  const jwt=JSON.parse(process.argv[2]);
  const regionHelp=region.options.find(option=>option.label==="I\u0027m not sure \u2014 help me find out");
  const jwtCheck=jwt.options.find(option=>option.label==="I already have a Mobile key \u2014 check its setting");
  process.exit(
    regionHelp?.commands[0].endsWith("question --kind help_region") &&
    jwtCheck?.commands[0].endsWith("answer --field jwt-check --value true") &&
    !JSON.stringify(region).includes("web-operator") &&
    !JSON.stringify(jwt).includes("web-operator") ? 0 : 1
  );
' "$region_question" "$jwt_question"; then
  ok "unknown region or JWT gets client navigation instead of browser automation"
else
  bad "unknown region or JWT still leaves the developer trapped on the question"
fi

iterable_app_question="$(question configure_iterable_app com.example.sampleshop)"
iterable_push_question="$(question configure_iterable_push com.example.sampleshop)"
if node -e '
  const app=JSON.parse(process.argv[1]);
  const push=JSON.parse(process.argv[2]);
  const appContext=[app.prompt,...app.context].join("\n");
  const pushContext=[push.prompt,...push.context].join("\n");
  process.exit(
    appContext.includes("Step 1 of 2 — Create the iOS mobile app") &&
    appContext.includes("https://app.iterable.com/integrations/mobileApps/create") &&
    appContext.includes("Platform: iOS") &&
    appContext.includes("Bundle ID: com.example.sampleshop") &&
    app.options.some(option=>option.label==="I\u0027ve created the iOS app") &&
    app.options.some(option=>option.label==="It already exists") &&
    pushContext.includes("Step 2 of 2 — Add the APNs credential") &&
    pushContext.includes("https://app.iterable.com/integrations/mobileApps") &&
    !pushContext.includes("/settings/appsAndWebsites") &&
    pushContext.includes("/secure/AuthKey_APNSKEY001.p8") &&
    pushContext.includes("Key ID: APNSKEY001") &&
    pushContext.includes("Team ID: TEAMID0001") &&
    pushContext.includes("Bundle ID: com.example.sampleshop") &&
    push.prompt.split("\n").filter(line => /^[1-7]\. /.test(line)).length===7
      ? 0
      : 1
  );
' "$iterable_app_question" "$iterable_push_question"; then
  ok "iOS dashboard setup separates app creation from exact APNs configuration"
else
  bad "iOS dashboard setup still collapses or omits required creation steps"
fi

eu_push_question="$(
  ios_q_configure_iterable_push \
    com.example.sampleshop EU \
    "/secure/AuthKey_APNSKEY001.p8" APNSKEY001 TEAMID0001
)"
if node -e '
  const q=JSON.parse(process.argv[1]);
  const context=[q.prompt,...q.context].join("\n");
  process.exit(
    context.includes("https://app.eu.iterable.com/integrations/mobileApps") &&
    !context.includes("/settings/appsAndWebsites") ? 0 : 1
  );
' "$eu_push_question"; then
  ok "iOS APNs setup uses the valid region-specific mobile-app listing URL"
else
  bad "iOS APNs setup generated an invalid dashboard route"
fi

# A relaying agent was seen showing only the prompt, so the summary, values and consent
# a screen asks about are in it, question last, and none of it is left only in context.
eval "$(sed -n '/^proof_question_identity_and_confirm() {/,/^}/p;/^proof_identity_steps() {/,/^}/p' bin/ios-provision)"
carries() { # <label> <question json> <fixed string>...
  local label="$1" q="$2"
  shift 2
  if node -e '
    const q = JSON.parse(process.argv[1]), wants = process.argv.slice(2);
    const prompt = String(q.prompt || ""), context = (q.context || []).join("\n");
    const lines = prompt.split("\n"), last = lines[lines.length - 1];
    const missing = wants.filter(w => !prompt.includes(w));
    const leaked = wants.filter(w => context.includes(w));
    if (missing.length || leaked.length || !last.endsWith("?") || lines.length < 3 || lines[lines.length - 2] !== "") {
      console.error(`missing: ${missing.join(" | ")}; in context: ${leaked.join(" | ")}; last: ${last}`);
      process.exit(1);
    }
  ' "$q" "$@" 2>"$ROOT/carries.err"; then
    ok "$label: the prompt carries it, the question is last, and context does not hold it"
  else
    bad "$label: the prompt does not carry what the developer acts on" "$(cat "$ROOT/carries.err")"
  fi
}
carries "confirm_scope" "$(ios_q_confirm_scope push-notifications,sdk-initialization user-id US false ios-step0 ios-step0)" \
  "Features: push-notifications,sdk-initialization (the scope confirmed in the iOS skill)" \
  "Identity: user-id (confirmed in the iOS skill)" "Region: US" "JWT required: false" \
  "It does not edit the app or change Apple or Iterable by itself."
carries "import_android" "$(ios_q_import_android "$(printf 'Android workspace: /a/.iterable\nRegion: EU\nMobile key: recorded')" \
    push-notifications,sdk-initialization user-id "iOS skill")" \
  "Android workspace: /a/.iterable" "Region: EU" "records No JWT" \
  "proposes the feature scope confirmed in the iOS skill: push-notifications, sdk-initialization"
carries "configure_iterable" "$(ios_q_configure_iterable EU true)" "from the EU project with Require JWT On"
carries "replace_mobile_key" "$(ios_q_replace_mobile_key US false "This key can read the channel list, which a Mobile key cannot.")" \
  "This key can read the channel list, which a Mobile key cannot."
carries "replace_server_key" "$(ios_q_replace_server_key EU "The Server-side key probe answered HTTP 401.")" \
  "The Server-side key probe answered HTTP 401."
carries "replace_apns_key" "$(ios_question replace_apns_key "APNs answered InvalidProviderToken." APNSKEY001 TEAMID0001)" \
  "APNs answered InvalidProviderToken."
carries "replace_apns_key (topic)" "$(ios_question replace_apns_key "APNs refused the topic." APNSKEY001 TEAMID0001 apns-key-topic-not-allowed com.example.sampleshop)" \
  "APNs refused the topic."
carries "asc_rejected" "$(ios_question asc_rejected com.example.sampleshop "App Store Connect rejected the key (HTTP 401).")" \
  "App Store Connect rejected the key (HTTP 401)."
carries "asc_conflict" "$(ios_question asc_conflict com.example.sampleshop "Apple refused to create it (HTTP 409).")" \
  "Apple refused to create it (HTTP 409)."
carries "asc_plan" "$(ios_question asc_plan com.example.sampleshop - create-bundle-id,enable-push "Sample Shop")" \
  "1. Register the explicit App ID com.example.sampleshop" "Nothing else is created, changed, or revoked" \
  "can invalidate provisioning profiles for this App ID"
carries "choose_bundle" "$(ios_q_choose_bundle com.example.sampleshop "Sample Shop" xcodebuild)" \
  "Bundle ID: com.example.sampleshop" "Product name: Sample Shop"
carries "choose_bundle (undetected)" "$(ios_q_choose_bundle)" "read General > Identity > Bundle Identifier"
carries "install_tools" "$(ios_q_install_tools "xcodebuild, node")" \
  "- xcodebuild: install Xcode from the App Store" "- node: install from https://nodejs.org"
carries "import_apns" "$(ios_q_import_apns TEAMID0001)" \
  "Team ID: TEAMID0001, read from the app target's DEVELOPMENT_TEAM" "Key ID: read from the AuthKey_<KEYID>.p8 file name."
carries "confirm_proof" "$(ios_q_confirm_proof "$(printf 'Bundle: com.example.sampleshop\nDevice: SIM-1 (simulator, development)\nIdentity: dogs@example.com (email)')")" \
  "Bundle: com.example.sampleshop" "Device: SIM-1 (simulator, development)" "Identity: dogs@example.com (email)"
carries "proof identity (user ID)" "$(proof_question_identity_and_confirm \
    "$(printf 'Bundle: com.example.sampleshop\nApp: /dd/SampleShop.app')" user-id SIM-1 \
    "$(proof_identity_steps user-id SIM-1 simulator SampleShop)")" \
  "Bundle: com.example.sampleshop" "App: /dd/SampleShop.app" \
  "1. Search the app's code for IterableAPI.userId or setUserId" \
  "pgrep -f 'Devices/SIM-1/.*/SampleShop\.app/SampleShop( |\$)'" \
  "expr -l objc -O -- [NSClassFromString(@\"IterableSDK.IterableAPI\") userId]"
email_physical="$(proof_question_identity_and_confirm "Bundle: com.example.sampleshop" email 00008101-X \
  "$(proof_identity_steps email 00008101-X physical "")")"
carries "proof identity (email, iPhone)" "$email_physical" "IterableAPI.email or setEmail" "the address you signed in with"
grep -qF "lldb" <<< "$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).prompt)' "$email_physical")" \
  && bad "a physical iPhone's identity steps offer a Simulator-only debugger read" \
  || ok "a physical iPhone's identity steps leave out the Simulator-only debugger read"
artifact="$(ios_q_proof_artifact com.example.sampleshop /dd/Build/Products/Debug-iphonesimulator/SampleShop.app \
  2026-10-22T09:00:00Z "a copy with no Iterable SDK, so a build from before the integration" build)"
carries "proof_artifact" "$artifact" "Newest build: /dd/Build/Products/Debug-iphonesimulator/SampleShop.app (Debug, built 2026-10-22T09:00:00Z)" \
  "On the device: a copy with no Iterable SDK"
if node -e '
  const [built, installed] = process.argv.slice(1).map(JSON.parse);
  const by = (q, label) => q.options.find(o => o.label === label);
  const bind = by(built, "Use the build at Debug-iphonesimulator/SampleShop.app");
  const keep = by(built, "Use the app already installed");
  process.exit(built.recommended === bind?.label &&
    bind.commands[0].endsWith("/ios-prepare-proof answer --field app-path --value /dd/Build/Products/Debug-iphonesimulator/SampleShop.app") &&
    keep?.commands[0].endsWith("/ios-prepare-proof answer --field app-source --value installed") &&
    installed.recommended === "Use the app already installed" ? 0 : 1);
' "$artifact" "$(ios_q_proof_artifact com.example.sampleshop /dd/X.app 2026-10-22T09:00:00Z "a copy built later" installed)"; then
  ok "the artifact screen binds the build when it is fresher and keeps the installed app as the other option"
else
  bad "the artifact screen does not bind the newest build, or lost the installed-app option"
fi
carries "proof identity (verified)" "$(identity_verified)" \
  "The app's proof marker logged U-1, and Iterable has this Simulator's current device token on that user."
carries "proof identity (unverified)" "$(identity_unverified)" \
  "The agent proposed U-2, but Iterable doesn't have this Simulator's token on it yet"
if node -e '
  const [v, u, plain] = process.argv.slice(1).map(JSON.parse);
  const label = "Use U-1: Iterable has this Simulator\u0027s current device token on that user";
  const use = v.options.find(o => o.label === label);
  const relaunch = u.options.find(o => o.label === "Relaunch the app to read the identity it signs in with");
  const check = u.options.find(o => o.label === "Check again");
  process.exit([v, u, plain].every(q => q.options.length >= 2 && q.options.length <= 4) &&
    v.recommended === label && use.commands[0].endsWith("/ios-prepare-proof start --confirm --identity U-1") &&
    !v.options.some(o => o.label === "Check again") &&
    u.recommended === relaunch?.label && relaunch.description.includes("-iterableProofIdentity YES") &&
    check?.commands[0].endsWith("--identity-candidate U-2") &&
    plain.recommended === null && !plain.options.some(o => /^(Use U|Relaunch|Check again)/.test(o.label)) ? 0 : 1);
' "$(identity_verified)" "$(identity_unverified)" "$(proof_question_identity_and_confirm "Bundle: x" email SIM-1)"; then
  ok "the identity screen recommends only a token-verified identity, else the relaunch, and stays within four options"
else
  bad "the identity screen offered an unverified identity, or exceeded four options"
fi
carries "proof_device (deployment target)" "$(ios_q_proof_device '[]' 27.0)" \
  "Only booted Simulators on iOS 27.0 or later are offered"

# "Above" points at text only context holds, which a relaying agent may never print.
if screen_dump | node -e '
  let input = "";
  process.stdin.on("data", c => input += c).on("end", () => {
    const hits = [];
    for (const line of input.split("\n").filter(Boolean)) {
      const tab = line.indexOf("\t"), kind = line.slice(0, tab), q = JSON.parse(line.slice(tab + 1));
      for (const o of q.options || [])
        for (const text of [o.description, o.effect])
          if (/\b(above|listed)\b/i.test(text)) hits.push(`${kind}: ${o.label}`);
      if (/\b(above|listed)\b/i.test(q.free_text?.hint || "")) hits.push(`${kind}: free text`);
    }
    if (hits.length) { console.error(hits.join("; ")); process.exit(1); }
  });
' 2>"$ROOT/above.err"; then
  ok "no iOS option description, effect or free-text hint points 'above' at something it does not show"
else
  bad "an iOS option leans on text it does not show" "$(cat "$ROOT/above.err")"
fi

((FAILED)) && exit 1
exit 0
