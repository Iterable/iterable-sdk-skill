#!/usr/bin/env bash
# Step 0 on Android and React Native Android: preflight routes to `scope` ahead of
# provisioning and code until the developer's answers are on disk, the scope screens record
# only what their options say, and the recorded identity reaches the test-identity step.
#
# No network: gcloud, curl, adb and firebase are stubs that record any call.

set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/stub"; mkdir -p "$STUB"
for c in gcloud curl adb firebase; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/calls"\nexit 1\n' "$c" "$TMP" > "$STUB/$c"; chmod +x "$STUB/$c"
done
export PATH="$STUB:$PATH"

MOBILE=0123456789abcdef0123456789abcdef
SERVER=fedcba9876543210fedcba9876543210

rn_app() { # <dir> — a bare React Native app with no push of its own
  rm -rf "$1"; mkdir -p "$1/android/app"
  ( cd "$1" && git init -q )
  printf '{"dependencies":{"react-native":"0.76.0"}}\n' > "$1/package.json"
}
native_app() { # <dir> — a native Android app whose own service shows order pushes
  rm -rf "$1"; mkdir -p "$1/app/src/main/java/com/example/app"
  ( cd "$1" && git init -q )
  printf 'android { defaultConfig { applicationId "com.example.app" } }\n' > "$1/app/build.gradle"
  cat > "$1/app/src/main/java/com/example/app/OrdersService.kt" <<'KT'
package com.example.app
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
class OrdersService : FirebaseMessagingService() {
  override fun onMessageReceived(message: RemoteMessage) { showOrderUpdate(message.data) }
}
KT
}
proven() { # <dir> — provisioning proven, nothing placed in the app yet
  mkdir -p "$1/.iterable/artifacts"
  printf '{"project_info":{"project_id":"real-project"}}\n' > "$1/.iterable/artifacts/google-services.json"
  printf 'ITBL_MOBILE_KEY=%s\nITBL_SERVER_KEY=%s\n' "$MOBILE" "$SERVER" > "$1/.iterable/.env"
  printf 'G10\tgreen\thuman\tIterable API keys work\t\nG12\tunverifiable\thuman\tPush integration configured\t\nG13\tpending\thuman\tApp installed with the SDK\t\n' > "$1/.iterable/state.tsv"
}
recorded() { # <dir> <features> <identity>
  mkdir -p "$1/.iterable"
  printf 'SCOPE_FEATURES=%s\nSCOPE_IDENTITY=%s\n' "$2" "$3" >> "$1/.iterable/resolved.env"
}
in_app() { local d="$1"; shift; ( cd "$d" && "$ROOT/bin/agent" "$@" 2>/dev/null ); }
field() { node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);const v=process.argv[1].split(".").reduce((o,k)=>o?.[k],j);process.stdout.write(typeof v==="object"?JSON.stringify(v):String(v))})' "$1"; }
cmds() { node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{for(const o of JSON.parse(d).options)console.log(o.label+"\t"+o.commands.join(" ; "))})'; }
rec() { sed -n "s/^$2=//p" "$1/.iterable/resolved.env" 2>/dev/null; }

cat > "$TMP/shape.js" <<'JS'
let s = ""; process.stdin.on("data", d => s += d).on("end", () => {
  let q; try { q = JSON.parse(s) } catch (e) { console.log("not JSON"); process.exit(1) }
  const errs = [];
  for (const f of ["header", "prompt", "context", "requires", "recommended", "options"])
    if (!(f in q)) errs.push("missing " + f);
  if (q.recommended != null && !(q.options || []).some(o => o.label === q.recommended)) errs.push("recommends a missing option");
  if (!q.header || q.header.length > 12) errs.push("header over 12");
  if (!/\?$/.test(q.prompt || "")) errs.push("prompt is not a question");
  if (!Array.isArray(q.context) || !q.context.length) errs.push("no context");
  if (!Array.isArray(q.options) || q.options.length < 2 || q.options.length > 4) errs.push("options not 2-4");
  for (const o of q.options || [])
    if (!o.label || !o.description || !o.effect || !Array.isArray(o.commands) || typeof o.relay !== "string")
      errs.push("incomplete option " + o.label);
  if (errs.length) { console.log(errs.join("; ")); process.exit(1) }
});
JS
shape() { node "$TMP/shape.js"; }

echo
echo "  Step 0 — recorded before provisioning or code"
echo

A="$TMP/rn"; rn_app "$A"
OUT="$(in_app "$A" preflight)"
[[ "$(field next.kind <<< "$OUT")" == scope && "$(field next.commands.0 <<< "$OUT")" == "$ROOT/bin/agent question scope" \
   && "$(field next.open <<< "$OUT")" == null && ! -e "$A/.iterable" ]] \
  && ok "a fresh React Native app routes to scope, names the scope screen, and writes no workspace" \
  || bad "a fresh app did not route to scope: $OUT"

N="$TMP/native"; native_app "$N"
[[ "$(in_app "$N" preflight | field next.kind)" == scope ]] \
  && ok "a fresh native Android app routes to scope too" || bad "native Android skipped the scope"

Q="$(in_app "$A" question scope)"
[[ "$(field header <<< "$Q")" == Features && "$(field selection <<< "$Q")" == multiple && ! -e "$A/.iterable" ]] \
  && grep -qF $'Push notifications\t'"$ROOT/bin/agent scope feature push-notifications" <<< "$(cmds <<< "$Q")" \
  && grep -qF $'Events + user profiles\t'"$ROOT/bin/agent scope feature event-tracking,user-profiles" <<< "$(cmds <<< "$Q")" \
  && grep -qF $'Deep links\t'"$ROOT/bin/agent scope feature deep-linking" <<< "$(cmds <<< "$Q")" \
  && ok "the first screen is the features multi-select, each option recording its own ids, and it writes nothing" \
  || bad "the features screen is wrong: $Q"
grep -qF "none appear until someone creates an in-app campaign" <<< "$(field prompt <<< "$Q")" \
  && [[ "$(field free_text.command <<< "$Q")" == "$ROOT/bin/agent scope feature {{answer}}" ]] \
  && ok "its prompt says in-app is included, and the typed answer records initialization only" \
  || bad "the features prompt or free text is wrong: $Q"

for opt in "Push notifications" "Events + user profiles"; do
  c="$(cmds <<< "$Q" | awk -F'\t' -v l="$opt" '$1==l{print $2}')"
  o="$(cd "$A" && eval "$c" 2>/dev/null)"
done
[[ "$(rec "$A" SCOPE_FEATURES)" == event-tracking,push-notifications,sdk-initialization,user-profiles \
   && "$(field next.command <<< "$o")" == "$ROOT/bin/agent question scope" ]] \
  && ok "two picks add up, sdk-initialization included, and the next command is the next screen" \
  || bad "the picks recorded '$(rec "$A" SCOPE_FEATURES)', next: $o"

[[ "$(in_app "$A" preflight | field next.kind)" == scope ]] \
  && ok "features alone still route to scope: the identity is missing" || bad "preflight moved on without an identity"

I="$(in_app "$A" question scope)"
P="$(field prompt <<< "$I")"
if [[ "$(field header <<< "$I")" == Identity ]] && grep -qF "project-types-and-unique-identifiers" <<< "$P" \
   && grep -qF "UserID-based" <<< "$P" && grep -qF "Email-based" <<< "$P" && grep -qF "Hybrid" <<< "$P" \
   && grep -qF "can't be changed" <<< "$P" && grep -qF "help me" <<< "$P"; then
  ok "the identity screen puts the project type first, and the help-me path, in its prompt"
else
  bad "the identity prompt lacks the project-type rule or the help-me path: $P"
fi
IC="$(cmds <<< "$I")"
grep -qF "$ROOT/bin/agent scope identity user-id" <<< "$IC" && grep -qF "$ROOT/bin/agent scope identity email" <<< "$IC" \
  && grep -qF "$ROOT/bin/agent scope identity unknown-user" <<< "$IC" \
  && grep -qE $'help me\t$' <<< "$IC" \
  && ok "it records user-id, email or unknown-user, and help me records nothing" \
  || bad "the identity options are wrong: $IC"

E="$(in_app "$A" scope identity phone)"; rc=$?
E2="$(in_app "$A" scope feature inbox)"; rc2=$?
((rc == 30 && rc2 == 30)) && grep -qF "email, user-id or unknown-user" <<< "$E" && grep -qF "mobile-inbox" <<< "$E2" \
  && [[ -z "$(rec "$A" SCOPE_IDENTITY)" && "$(rec "$A" SCOPE_FEATURES)" != *inbox* ]] \
  && ok "a value no screen offers is refused with the allowed ones, and nothing is recorded" \
  || bad "an unoffered value: rc $rc '$E', rc $rc2 '$E2'"

o="$(in_app "$A" scope identity user-id)"
OUT="$(in_app "$A" preflight)"
[[ "$(field next.command <<< "$o")" == "$ROOT/bin/agent preflight" && "$(field next.kind <<< "$OUT")" == provision \
   && "$(field next.commands.0 <<< "$OUT")" == "$ROOT/bin/agent question opening" \
   && "$(field scope.identity <<< "$OUT")" == user-id ]] \
  && ok "with features and identity recorded, the next command is preflight, and it routes to provisioning" \
  || bad "the recorded scope did not hand on to provisioning: $o / $OUT"
grep -qF "not even while the developer works in a dashboard" <<< "$(field next.summary <<< "$OUT")" \
  && ok "and the provisioning summary forbids code while a dashboard step is open" \
  || bad "the provision summary still allows code during the dashboard steps"

R="$(in_app "$A" question scope)"
[[ "$(field header <<< "$R")" == Scope ]] && grep -qF "Identity: user-id" <<< "$(field prompt <<< "$R")" \
  && grep -qF "$ROOT/bin/agent scope clear" <<< "$(cmds <<< "$R")" \
  && ok "once recorded, the scope screen shows the answers and offers to change them" \
  || bad "no way to see or change the recorded answers: $R"
in_app "$A" scope clear >/dev/null
[[ -z "$(rec "$A" SCOPE_FEATURES)$(rec "$A" SCOPE_IDENTITY)" && "$(in_app "$A" preflight | field next.kind)" == scope ]] \
  && ok "changing them clears all three and routes back to scope" || bad "clear left: $(cat "$A/.iterable/resolved.env")"

ft="$(field free_text.command <<< "$Q")"
( cd "$A" && eval "${ft//\{\{answer\}\}/initialization only}" >/dev/null 2>&1 )
[[ "$(rec "$A" SCOPE_FEATURES)" == sdk-initialization ]] \
  && ok "typing 'initialization only' records the initialize-and-identify scope" \
  || bad "initialization only recorded '$(rec "$A" SCOPE_FEATURES)'"

M="$(in_app "$A" question scope_more)"
MC="$(cmds <<< "$M")"
grep -qF "scope feature mobile-inbox" <<< "$MC" && grep -qF "scope feature embedded-messaging" <<< "$MC" \
  && grep -qF "scope feature in-app-messages" <<< "$MC" && [[ "$(field selection <<< "$M")" == multiple ]] \
  && grep -qF "question scope_more" <<< "$(cmds <<< "$Q")" \
  && ok "More opens a follow-up that records inbox, embedded and custom in-app" \
  || bad "the More follow-up is wrong: $M"

echo
echo "  The app's own push — asked only when it exists and push is in scope"
echo

in_app "$N" scope feature push-notifications >/dev/null
o="$(in_app "$N" scope identity email)"
X="$(in_app "$N" question scope)"
[[ "$(field recorded.missing <<< "$o")" == existing-push && "$(in_app "$N" preflight | field next.kind)" == scope \
   && "$(field header <<< "$X")" == "Your push" ]] \
  && grep -qF "OrdersService handles onMessageReceived itself" <<< "$(field prompt <<< "$X")" \
  && grep -qF "app/src/main/java/com/example/app/OrdersService.kt" <<< "$(field prompt <<< "$X")" \
  && ok "an app with its own messaging service is asked about it, naming the service and its file" \
  || bad "the existing push was not asked: $o / $X"
XC="$(cmds <<< "$X")"
grep -qF "scope existing-push keep-both" <<< "$XC" && grep -qF "scope existing-push iterable-only" <<< "$XC" \
  && in_app "$N" scope existing-push keep-both >/dev/null && [[ "$(rec "$N" SCOPE_PUSH)" == keep-both ]] \
  && [[ "$(in_app "$N" preflight | field next.kind)" == provision ]] \
  && ok "keep both or Iterable only is recorded, and then provisioning comes next" \
  || bad "the push answer did not record or route: $XC"

N2="$TMP/native-no-push-scope"; native_app "$N2"
in_app "$N2" scope feature event-tracking,user-profiles >/dev/null
[[ "$(in_app "$N2" scope identity email | field recorded.missing)" == null ]] \
  && ok "with push out of scope the app's own push is not asked about" || bad "push asked about while out of scope"

echo
echo "  The other routes"
echo

B="$TMP/proven"; rn_app "$B"; proven "$B"
[[ "$(in_app "$B" preflight | field next.kind)" == scope ]] \
  && { recorded "$B" push-notifications,sdk-initialization user-id; [[ "$(in_app "$B" preflight | field next.kind)" == integrate ]]; } \
  && ok "proven prerequisites still wait for the scope, then route to integrate" \
  || bad "integrate was reached without a recorded scope"

V="$TMP/verify"; rn_app "$V"; proven "$V"
cp "$V/.iterable/artifacts/google-services.json" "$V/android/app/"
mkdir -p "$V/.iterable/rn"; printf 'export const ITERABLE_API_KEY = "%s";\n' "$MOBILE" > "$V/.iterable/rn/iterable.local.ts"
node -e 'const f=process.argv[1],p=require(f);p.dependencies["@iterable/react-native-sdk"]="2.0.0";require("fs").writeFileSync(f,JSON.stringify(p))' "$V/package.json"
OUT="$(in_app "$V" preflight)"
[[ "$(field next.kind <<< "$OUT")" == verify && "$(field scope.missing <<< "$OUT")" == features ]] \
  && ok "an app already integrated goes to verify, ungated, and preflight reports the scope as unrecorded" \
  || bad "the integrated app: $OUT"

printf 'G16\tgreen\ttool\tPush arrives on device\t\n' >> "$V/.iterable/state.tsv"
recorded "$V" deep-linking,push-notifications,sdk-initialization email
IOS="$(in_app "$V" preflight | field next.commands.0)"
[[ "$IOS" == "$ROOT/bin/ios-provision status --features deep-linking,push-notifications,sdk-initialization --identity email" ]] \
  && ok "a finished React Native Android hands iOS the recorded scope as --features and --identity" \
  || bad "the iOS command lacks the recorded scope: $IOS"
printf '#!/bin/sh\necho "Xcode 18.0"\n' > "$STUB/xcodebuild"; chmod +x "$STUB/xcodebuild"
O="$(cd "$V" && IOS_WORKSPACE="$V/.iterable/ios" eval "$IOS" 2>/dev/null)"
[[ "$(field next.command <<< "$O")" == *"question --kind import_android --features deep-linking,push-notifications,sdk-initialization --identity email" ]] \
  && ok "and ios-provision takes that command as is, proposing the scope on its first screen" \
  || bad "ios-provision did not carry the recorded scope: $(field next <<< "$O")"

[[ ! -s "$TMP/calls" ]] && ok "and nothing in the scope flow called gcloud, curl, adb or firebase" \
  || bad "the scope flow called: $(tr '\n' ';' < "$TMP/calls")"

echo
echo "  The test-identity step follows the recorded identity"
echo

W="$TMP/ws"; mkdir -p "$W"
s4() { ( cd "$TMP" && WS="$W" "$@" "$ROOT/bin/agent" question iterable_step 4 2>/dev/null ); }
U="$(s4 env SCOPE_IDENTITY=user-id)"; EM="$(s4 env SCOPE_IDENTITY=email)"; G="$(s4 env)"
[[ "$(field prompt <<< "$U")" == *"What user ID does your app pass to setUserId() for the test user?" \
   && "$(field free_text.command <<< "$U")" == "$ROOT/bin/agent set ITBL_USER_ID={{answer}}" ]] \
  && ok "a user-id scope makes step 4 ask for a user ID and record ITBL_USER_ID" \
  || bad "step 4 with a user-id scope: $(field prompt <<< "$U" | tail -1) / $(field free_text.command <<< "$U")"
[[ "$(field prompt <<< "$EM")" == *"What email address does your app sign the test user in with?" \
   && "$(field free_text.command <<< "$EM")" == "$ROOT/bin/agent set ITBL_EMAIL={{answer}}" \
   && "$(field free_text.command <<< "$G")" == "$ROOT/bin/agent set ITBL_IDENTITY={{answer}}" ]] \
  && ok "an email scope asks for an email address, and with no scope the routed field is unchanged" \
  || bad "step 4 with an email scope: $(field free_text.command <<< "$EM"), none: $(field free_text.command <<< "$G")"

# In the prompt, because that is the part the agent has to relay whole.
NOCODE=""
for n in 1 2 3 4; do
  [[ "$( (cd "$TMP" && WS="$W" "$ROOT/bin/agent" question iterable_step "$n" 2>/dev/null) | field prompt)" \
     == *"No app code is written while these steps are open"* ]] || NOCODE="$NOCODE $n"
done
[[ -z "$NOCODE" ]] \
  && ok "every dashboard step's prompt says no app code is written while it is open" \
  || bad "the prompt says nothing about writing code meanwhile on step(s):$NOCODE"

echo
echo "  Entering through provisioning still asks the scope first"
echo

P="$TMP/provision-first"; native_app "$P"
O="$(in_app "$P" question opening)"
[[ "$(field header <<< "$O")" == Features && ! -d "$P/.iterable" ]] \
  && ok "with no scope, the provisioning skill's first question is the features screen, and nothing is written" \
  || bad "question opening with no scope: header $(field header <<< "$O")"
[[ "$(in_app "$P" question choose_driver | field header)" == Features ]] \
  && ok "the setup fork is held behind the scope too" || bad "choose_driver asked before the scope"
recorded "$P" push-notifications,sdk-initialization email
in_app "$P" scope existing-push keep-both >/dev/null
O="$(in_app "$P" question opening)"
[[ "$(field header <<< "$O")" != Features && "$(field header <<< "$O")" != Identity && -n "$(field header <<< "$O")" ]] \
  && ok "with the scope recorded, the same command is the setup question" \
  || bad "question opening with a scope: header $(field header <<< "$O")"

S="$TMP/status-first"; native_app "$S"
O="$(in_app "$S")"
[[ "$(field next.kind <<< "$O")" == scope && "$(field next.command <<< "$O")" == "$ROOT/bin/agent question scope" \
   && "$(field next.question.header <<< "$O")" == Features ]] \
  && ok "a status read before the scope reports scope, with the features screen as its question" \
  || bad "status with no scope: $(field next.kind <<< "$O") / $(field next.command <<< "$O")"
recorded "$S" push-notifications,sdk-initialization email
in_app "$S" scope existing-push keep-both >/dev/null
[[ "$(in_app "$S" | field next.kind)" != scope ]] \
  && ok "with the scope recorded, a status read routes to setup again" || bad "status still gated after the scope"

echo
echo "  Every scope screen can be drawn"
echo

SA="$TMP/shapes"; native_app "$SA"
draw() { local label="$1"; shift; local e; e="$(in_app "$SA" question "$@" | shape)" && ok "$label" || bad "$label: $e"; }
draw "features" scope
draw "more features" scope_more
in_app "$SA" scope feature push-notifications >/dev/null; draw "identity" scope
in_app "$SA" scope identity user-id >/dev/null;          draw "the app's own push" scope
in_app "$SA" scope existing-push iterable-only >/dev/null; draw "recorded answers" scope

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — Step 0 is asked, recorded, and gates provisioning and code."
