#!/usr/bin/env bash
# `bin/agent preflight` runs before any consent, so it must read local files only,
# write nothing, never print a key, and route a fresh app to provisioning.
#
# No network: gcloud and curl are stubs that record any call.

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

new_app() { # <dir> — a bare React Native app
  rm -rf "$1"; mkdir -p "$1/android/app"
  ( cd "$1" && git init -q )
  printf '{"dependencies":{"react-native":"0.76.0"}}\n' > "$1/package.json"
}
pf() { ( cd "$1" && "$ROOT/bin/agent" preflight 2>/dev/null ); }
field() { node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{const j=JSON.parse(d);process.stdout.write(String(process.argv[1].split(".").reduce((o,k)=>o?.[k],j)))})' "$1"; }

echo
echo "  bin/agent preflight — local files only, before any consent"
echo

# The Step 0 answers, as `agent scope` records them; tests/agent-scope.sh covers that gate.
scoped() {
  mkdir -p "$1/.iterable"
  printf 'SCOPE_FEATURES=push-notifications,sdk-initialization\nSCOPE_IDENTITY=email\nSCOPE_REGION=US\nSCOPE_JWT=false\n' >> "$1/.iterable/resolved.env"
}

A="$TMP/fresh"; new_app "$A"
OUT="$(pf "$A")"
[[ "$(field next.kind <<< "$OUT")" == scope ]] \
  && ok "nothing present routes to the Step 0 scope first" || bad "fresh app got: $OUT"
[[ ! -e "$A/.iterable" ]] && ok "and writes no workspace" || bad "preflight created $A/.iterable"
scoped "$A"
OUT="$(pf "$A")"
[[ "$(field next.kind <<< "$OUT")" == provision ]] \
  && ok "with the scope recorded, nothing present routes to provision" || bad "scoped fresh app got: $OUT"
[[ "$(field next.commands.0 <<< "$OUT")" == "$ROOT/bin/agent question opening" \
   && "$(field next.open <<< "$OUT")" == "$ROOT/iterable-provision/SKILL.md" ]] \
  && ok "and names the provisioning skill and its first command" || bad "next lacks the opening command: $OUT"

B="$TMP/ready"; new_app "$B"
mkdir -p "$B/.iterable/artifacts"
printf '{"project_info":{"project_id":"real-project"}}\n' > "$B/.iterable/artifacts/google-services.json"
printf 'ITBL_MOBILE_KEY=%s\nITBL_SERVER_KEY=%s\n' "$MOBILE" "$SERVER" > "$B/.iterable/.env"
printf 'G10\tgreen\thuman\tIterable API keys work\t\nG12\tunverifiable\thuman\tPush integration configured\t\nG13\tpending\thuman\tApp installed with the SDK\t\n' > "$B/.iterable/state.tsv"
scoped "$B"
OUT="$(pf "$B")"
[[ "$(field next.kind <<< "$OUT")" == integrate ]] \
  && ok "proven prerequisites route to integrate" || bad "ready app got: $OUT"
grep -qF "import-from-android --confirm" <<< "$OUT" && grep -qF "android/app/google-services.json" <<< "$OUT" \
  && ok "and say how the key file and google-services.json reach the app" || bad "integrate lacks the delivery commands: $OUT"
grep -qF -e "$MOBILE" -e "$SERVER" <<< "$OUT" \
  && bad "a key value appears in the output" || ok "no key value in the output"

cp "$B/.iterable/artifacts/google-services.json" "$B/android/app/"
mkdir -p "$B/.iterable/rn"
printf 'export const ITERABLE_API_KEY = "%s";\n' "$MOBILE" > "$B/.iterable/rn/iterable.local.ts"
node -e 'const f=process.argv[1],p=require(f);p.dependencies["@iterable/react-native-sdk"]="2.0.0";require("fs").writeFileSync(f,JSON.stringify(p))' "$B/package.json"
OUT="$(pf "$B")"
[[ "$(field next.kind <<< "$OUT")" == verify ]] \
  && ok "everything placed routes to verify" || bad "integrated app got: $OUT"
grep -qF "$MOBILE" <<< "$OUT" && bad "the delivered key appears in the output" || ok "and still prints no key"

printf 'export const ITERABLE_API_KEY = "YOUR_API_KEY";\n' > "$B/.iterable/rn/iterable.local.ts"
OUT="$(pf "$B")"
[[ "$(field present.app_key_file <<< "$OUT")" == false && "$(field next.kind <<< "$OUT")" == integrate ]] \
  && grep -qF "iterable.local.ts" <<< "$(field placeholders <<< "$OUT")" \
  && ok "a placeholder key file is flagged and treated as missing" || bad "placeholder not flagged: $OUT"

rm "$B/.iterable/rn/iterable.local.ts"
printf 'export const ITERABLE_API_KEY = "";\n' > "$B/.iterable/rn/iterable.local.ts.example"
OUT="$(pf "$B")"
grep -qF "iterable.local.ts.example" <<< "$(field placeholders <<< "$OUT")" \
  && ok "an .example key file is flagged" || bad ".example not flagged: $OUT"

printf 'ITBL_MOBILE_KEY=YOUR_MOBILE_KEY\nITBL_SERVER_KEY=%s\n' "$SERVER" > "$B/.iterable/.env"
OUT="$(pf "$B")"
[[ "$(field next.kind <<< "$OUT")" == provision && "$(field present.mobile_key <<< "$OUT")" == false ]] \
  && ok "a placeholder Mobile key routes back to provision" || bad "placeholder Mobile key accepted: $OUT"

[[ ! -s "$TMP/calls" ]] && ok "no gcloud, curl, adb or firebase call was made" \
  || bad "network tools were called: $(tr '\n' ';' < "$TMP/calls")"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — preflight is local, silent about secrets, and routes in order."
