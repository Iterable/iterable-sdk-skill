#!/usr/bin/env bash
# The physical-iPhone proof: developer read-back of a code shown in the push,
# optional device-log corroboration collected without elevation, and the
# verifier's independent re-check. Untested on real hardware by design: the
# device log lines come from published iPhone captures (see tests/fixtures/ios-prove/simulate).

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

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-prove-physical.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-prove-physical.*|/private/tmp/iterable-ios-prove-physical.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

FAKEBIN="$ROOT/bin"
SIMULATE="$REPO/tests/fixtures/ios-prove/simulate"
DEVICE=00008101-TESTDEVICE
mkdir -p "$FAKEBIN"

cat > "$FAKEBIN/xcrun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "simctl list devices --json") printf '{"devices":{}}\n' ;;
  *devicectl*"list devices"*)
    printf '{"result":{"devices":[{"identifier":"00008101-TESTDEVICE","name":"Test iPhone","connectionProperties":{"pairingState":"paired"},"hardwareProperties":{"platform":"iOS","productType":"iPhone16,1"}}]}}\n'
    ;;
  *"device info apps"*)
    printf '{"result":{"apps":[{"bundleIdentifier":"com.example.dogshelter","version":"1.0","bundleVersion":"42"}]}}\n'
    ;;
  *) exit 2 ;;
esac
EOF
cat > "$FAKEBIN/log" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  collect)
    printf '%s\n' "$*" >> "$PHYS_STATE/log-calls"
    if [[ -f "$PHYS_STATE/log-permission" ]]; then
      echo "log: Collecting from a device must be run as root" >&2
      exit 64
    fi
    while (($#)); do [[ "$1" == --output ]] && { mkdir -p "$2"; break; }; shift; done
    ;;
  show)
    [[ -f "$PHYS_STATE/device-log.ndjson" ]] && cat "$PHYS_STATE/device-log.ndjson"
    printf '{"count":0,"finished":1}\n'
    ;;
  *) exit 2 ;;
esac
EOF
cat > "$FAKEBIN/curl" <<'EOF'
#!/usr/bin/env bash
config="$(cat)"
url="$(sed -n 's/^url = "\(.*\)"$/\1/p' <<< "$config")"
data="$(sed -n 's/^data = "\(.*\)"$/\1/p' <<< "$config" | sed -e 's/\\"/"/g' -e 's/\\\\/\\/g')"
printf '%s\n' "$url" >> "$PHYS_STATE/curl-calls"
if grep -q 'itbl-ios-deliberately-invalid-server-key\|itbl-ios-verify-invalid-server-key' <<< "$config"; then
  printf '{"msg":"invalid api key"}\n401\n'
  exit 0
fi
case "$url" in
  */api/channels) printf '{"channels":[{"messageMedium":"Push"}]}\n200\n' ;;
  */api/users/getByEmail*)
    printf '{"user":{"email":"dogs@example.com","dataFields":{"devices":[{"appPackageName":"com.example.dogshelter","endpointEnabled":true,"notificationsEnabled":true,"platform":"APNS","token":"abcd"}]}}}\n200\n'
    ;;
  */api/templates/push/upsert)
    printf '%s' "$data" > "$PHYS_STATE/upsert.json"
    printf '{"msg":"Upserted 1 templates with IDs: 434343"}\n200\n'
    ;;
  */api/templates/push/proof)
    printf '%s' "$data" > "$PHYS_STATE/proof.json"
    printf '{"msg":"Push proof sent"}\n200\n'
    ;;
  *) printf '{"msg":"unexpected"}\n500\n' ;;
esac
EOF
cat > "$FAKEBIN/agent-device" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$PHYS_STATE/agent-calls"
exit 1
EOF
chmod +x "$FAKEBIN"/*

field() {
  node -e '
    let v; try { v=JSON.parse(process.argv[1]) } catch { process.exit(0) }
    for (const key of process.argv[2].split(".")) v=v?.[key];
    process.stdout.write(v == null ? "" : typeof v==="object" ? JSON.stringify(v) : String(v));
  ' "$1" "$2"
}

fresh() {
  APP="$ROOT/app-$1"
  WORKSPACE="$APP/.iterable/ios"
  STATE="$ROOT/state-$1"
  rm -rf "$APP" "$STATE"
  mkdir -p "$WORKSPACE" "$STATE"
  printf 'name: DogShelter\nsettings:\n  base:\n    PRODUCT_BUNDLE_IDENTIFIER: com.example.dogshelter\n' > "$APP/project.yml"
  key="server-physical-key-1234567890"
  printf 'ITERABLE_SERVER_KEY=%s\nITERABLE_DATA_REGION=US\n' "$key" > "$WORKSPACE/.env"
  node -e '
    const fs=require("fs"), crypto=require("crypto");
    const [dir,key]=process.argv.slice(1);
    fs.writeFileSync(`${dir}/scope.json`,JSON.stringify({features:["sdk-initialization","push-notifications"],identity_mode:"email",data_region:"US",jwt_enabled:false,verification_only:false},null,2)+"\n");
    fs.writeFileSync(`${dir}/target.json`,JSON.stringify({bundle_id:"com.example.dogshelter",name:"Dog Shelter"},null,2)+"\n");
    fs.writeFileSync(`${dir}/server-validation.json`,JSON.stringify({valid:true,key_sha256:crypto.createHash("sha256").update(key).digest("hex"),data_region:"US",classification:"authenticated-server-key"},null,2)+"\n");
  ' "$WORKSPACE" "$key"
  chmod 700 "$WORKSPACE"
  chmod 600 "$WORKSPACE"/.env "$WORKSPACE"/scope.json "$WORKSPACE"/target.json "$WORKSPACE"/server-validation.json
  in_app "$REPO/bin/ios-prepare-proof" answer --field environment --value production >/dev/null
  in_app "$REPO/bin/ios-prepare-proof" start --confirm --identity dogs@example.com --device "$DEVICE" >/dev/null 2>&1
}

in_app() {
  (
    cd "$APP" || exit
    env PATH="$FAKEBIN:$PATH" PHYS_STATE="$STATE" IOS_WORKSPACE="$WORKSPACE" \
      IOS_AGENT_DEVICE="$FAKEBIN/agent-device" "$@"
  )
}

# What the phone would show: the template's placeholder filled from the send's dataFields.
shown_code() {
  node -e '
    const fs=require("fs");
    const t=JSON.parse(fs.readFileSync(process.argv[1],"utf8")).message;
    const code=JSON.parse(fs.readFileSync(process.argv[2],"utf8")).dataFields?.proofCode||"";
    process.stdout.write(t==="Proof code: {{proofCode}}" && /^[A-Z0-9]{3}-[A-Z0-9]{3}$/.test(code) ? code : "");
  ' "$STATE/upsert.json" "$STATE/proof.json"
}

readback() {
  printf '%s' "$1" | in_app "$REPO/bin/ios-prove" readback --code -
}

# Send: the code is shown only on the phone.
fresh main
target="$(cat "$WORKSPACE/proof-target.json")"
before="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$target" device_kind)" == physical && "$(field "$target" environment)" == production &&
      "$(field "$before" next.kind)" == prove_push &&
      "$(field "$before" next.summary)" == *"leave the app"* ]]; then
  ok "a production run on a physical iPhone is prepared and routed to one proof send"
else
  bad "the physical production run was not routed to a proof send" \
    "kind=$(field "$target" device_kind) env=$(field "$target" environment) next=$(field "$before" next.kind)"
fi
sent="$(in_app "$REPO/bin/ios-prove" --confirm 2>/dev/null)"
sent_rc=$?
code="$(shown_code)"
if [[ "$sent_rc" -eq 40 && "$(field "$sent" next.kind)" == readback_code &&
      "$(field "$sent" next.question.free_text.command)" == "printf '%s' '{{answer}}' | "*"readback --code -" &&
      "$(field "$sent" verification_tier)" == developer-observed &&
      "$(field "$sent" notice)" == "physical path not tested by the maintainers" &&
      ${#code} -eq 7 ]]; then
  ok "the send hands back a read-back question and states the path is untested"
else
  bad "the physical send did not ask for the read-back" "rc=$sent_rc $sent"
fi
plain="${code/-/}"
if [[ -n "$plain" ]] && ! grep -rqiF -- "$plain" "$WORKSPACE" && ! grep -qiF -- "$plain" <<< "$sent$before" &&
    ! grep -qiF -- "$plain" "$STATE/upsert.json" &&
    [[ "$(field "$(cat "$WORKSPACE/sends/production/user-targeted.json")" readback.kdf)" == scrypt-* ]]; then
  ok "only a slow hash of the code is stored, the template holds a placeholder, and the tool never prints it"
else
  bad "the read-back code leaked into the workspace or the tool output"
fi
waiting="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$waiting" next.kind)" == readback_code && "$(field "$waiting" next.owner)" == human &&
      "$(field "$waiting" next.question.free_text.command)" == *"readback --code"* ]]; then
  ok "the verifier waits on the developer's read-back with the question ready"
else
  bad "the verifier did not hand the read-back to the developer" "$(field "$waiting" next.kind)"
fi
wrong="$(readback AAA-AAA 2>/dev/null)"
if [[ "$(field "$wrong" diagnosis)" == readback_mismatch && "$(field "$wrong" summary)" == *"2 attempt(s) left"* ]]; then
  ok "a wrong code is refused with the attempts left"
else
  bad "a wrong code was not refused" "$wrong"
fi
touch "$STATE/log-permission"
lower="$(printf '%s' "$code" | tr 'A-Z-' 'a-z ')"
right="$(readback "$lower" 2>/dev/null)"
right_rc=$?
if [[ "$right_rc" -eq 0 && "$(field "$right" observed)" == true &&
      "$(field "$right" corroboration.status)" == skipped &&
      "$(field "$right" corroboration.reason)" == *"does not escalate"* ]] &&
    ! grep -q sudo "$STATE/log-calls"; then
  ok "the right code passes; a log that needs root is skipped and reported, never escalated"
else
  bad "the matching read-back did not record developer-observed proof" "rc=$right_rc $right"
fi
if ! grep -rqiF -- "$plain" "$WORKSPACE"; then
  ok "the matched code is not written anywhere in the workspace"
else
  bad "the read-back code was stored after the match"
fi
done_out="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$done_out" verdict)" == done && "$(field "$done_out" verification_tier)" == developer-observed &&
      "$(field "$done_out" next.summary)" == *"developer-observed"* &&
      "$(field "$done_out" notice)" == *"physical path has not been tested by the maintainers"* &&
      "$(field "$done_out" verification_limitations)" == *physical-path-untested-by-maintainers* ]]; then
  ok "done states developer-observed proof and that the physical path is untested"
else
  bad "done did not state the physical proof tier" "$(field "$done_out" next.kind): $(field "$done_out" next.summary)"
fi
cp "$WORKSPACE/observations/readback.json" "$ROOT/readback.saved"
rm -f "$WORKSPACE/observations/readback.json"
no_state="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
node -e '
  const fs=require("fs"), v=JSON.parse(fs.readFileSync(process.argv[1],"utf8"));
  v.locked=true; fs.writeFileSync(process.argv[2],JSON.stringify(v)+"\n",{mode:0o600});
' "$ROOT/readback.saved" "$WORKSPACE/observations/readback.json"
locked_state="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
cp "$ROOT/readback.saved" "$WORKSPACE/observations/readback.json"
if [[ "$(field "$no_state" verdict)" != done && "$(field "$locked_state" verdict)" != done ]]; then
  ok "a receipt without this run's matched, open read-back record is not trusted"
else
  bad "the verifier trusted a read-back receipt alone"
fi
if [[ ! -e "$STATE/agent-calls" ]]; then
  ok "the physical proof never starts agent-device"
else
  bad "the physical proof required agent-device"
fi

fresh corroborated
in_app "$REPO/bin/ios-prove" --confirm >/dev/null 2>&1
code="$(shown_code)"
"$SIMULATE" device-log one "$STATE/device-log.ndjson"
out="$(readback "$code" 2>/dev/null)"
verified="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$out" corroboration.verdict)" == corroborated &&
      "$(field "$verified" verdict)" == done &&
      "$(field "$verified" gates)" == *"iPhone log corroborates exactly one alert push"* ]]; then
  ok "a readable device log with exactly one alert push corroborates the read-back"
else
  bad "a corroborating device log was not used" "$(field "$out" corroboration) / $(field "$verified" next.summary)"
fi
log_file="$WORKSPACE/observations/runs/$(field "$(cat "$WORKSPACE/proof-target.json")" run_id)/user-targeted/device-log.ndjson"
"$SIMULATE" device-log two "$log_file"
tampered="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$tampered" verdict)" == defect ]]; then
  ok "the verifier re-reads the saved device log instead of trusting the receipt"
else
  bad "a changed device log still passed" "$(field "$tampered" verdict)"
fi

fresh missing
in_app "$REPO/bin/ios-prove" --confirm >/dev/null 2>&1
code="$(shown_code)"
"$SIMULATE" device-log none "$STATE/device-log.ndjson"
out="$(readback "$code" 2>/dev/null)"
after="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
if [[ "$(field "$out" observed)" == false && "$(field "$out" diagnosis)" == device_log_disagrees &&
      "$(field "$after" next.kind)" == review_delivery ]]; then
  ok "a matching code that the device log contradicts is not counted"
else
  bad "a read-back the device log contradicts was accepted" "$out"
fi

fresh duplicate
in_app "$REPO/bin/ios-prove" --confirm >/dev/null 2>&1
code="$(shown_code)"
"$SIMULATE" device-log two "$STATE/device-log.ndjson"
out="$(readback "$code" 2>/dev/null)"
if [[ "$(field "$out" diagnosis)" == duplicate_delivery ]]; then
  ok "two alert pushes in the window cannot be singled out and do not pass"
else
  bad "a duplicate delivery on the device passed" "$out"
fi

fresh locked
in_app "$REPO/bin/ios-prove" --confirm >/dev/null 2>&1
code="$(shown_code)"
for guess in AAA-AAA CCC-CCC DDD-DDD; do
  last="$(readback "$guess" 2>/dev/null)"
done
late="$(in_app "$REPO/bin/ios-prove" readback --code "$code" 2>/dev/null)"
if [[ "$(field "$last" diagnosis)" == readback_locked && "$(field "$late" diagnosis)" == readback_closed &&
      ! -f "$WORKSPACE/proof/production/user-targeted.json" ]]; then
  ok "three wrong codes close the run; a right code afterwards is refused"
else
  bad "read-back guessing was not bounded" "$(field "$last" diagnosis) / $(field "$late" diagnosis)"
fi

fresh notseen
in_app "$REPO/bin/ios-prove" --confirm >/dev/null 2>&1
"$SIMULATE" device-log none "$STATE/device-log.ndjson"
out="$(in_app "$REPO/bin/ios-prove" readback --not-seen 2>/dev/null)"
after="$(in_app "$REPO/bin/ios-verify" status 2>/dev/null)"
proofs="$(awk '/push\/proof/{n++} END{print n+0}' "$STATE/curl-calls")"
if [[ "$(field "$out" diagnosis)" == not_seen_by_developer &&
      "$(field "$out" summary)" == *"never reached the device"* &&
      "$(field "$after" next.kind)" == review_delivery && "$proofs" -eq 1 ]]; then
  ok "a push the developer did not see is diagnosed from the device log and never resent"
else
  bad "a missed physical push looped or resent" "$out"
fi

((FAILED)) && exit 1
exit 0
