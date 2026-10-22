#!/usr/bin/env bash
# The delivery judge against scrubbed real recordings and their forgeries:
# every way a record or log line could pass without being this run's APNs
# delivery must fail, and the real chain must pass.

set -uo pipefail
cd "$(dirname "$0")/.." || exit
REPO="$PWD"
READER="$REPO/bin/ios-notify-read.js"
SIMULATE="$REPO/tests/fixtures/ios-prove/simulate"

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  [[ $# -lt 2 ]] || printf '  %s\n' "$2"
  FAILED=1
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-notify-read.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-notify-read.*|/private/tmp/iterable-ios-notify-read.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

BUNDLE=com.example.sampleshop
ROOT26="/Library/Developer/CoreSimulator/Volumes/iOS_23C54/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.2.simruntime/Contents/Resources/RuntimeRoot"
MARKER=ITBL-IOS-PROOF-0A1B2C3D4E5F
NONCE="$(node -e 'process.stdout.write(require("crypto").randomBytes(32).toString("hex"))')"
NONCE_HASH="$(printf '%s' "$NONCE" | shasum -a 256 | awk '{print $1}')"

# judge <scenario> [require_record] [log_ok] -> judge JSON
judge() {
  local scenario="$1" require="${2:-true}" log_ok="${3:-true}" dir="$ROOT/$1-$RANDOM" prepared store log
  mkdir -p "$dir"
  "$SIMULATE" register "$dir/devices" SIM "$BUNDLE"
  prepared="$(node -e 'process.stdout.write(new Date(Date.now()-1000).toISOString())')"
  "$SIMULATE" deliver "$scenario" "$dir/devices" SIM "$BUNDLE" "$MARKER" "$NONCE" 424242 "$dir/log.ndjson"
  if [[ "${CLEAR_STORE:-}" == true ]]; then
    rm -f "$dir/devices/SIM/data/Library/UserNotifications/0B5E8D2A-3C1F-4E7A-9B6D-2F8C4A1E7D90/DeliveredNotifications.plist"
  fi
  [[ -z "${REROOT:-}" ]] || sed -i '' "s#${ROOT26}#${REROOT}#g" "$dir/log.ndjson"
  [[ -z "${RAWSYSTEM:-}" ]] || sed -i '' "s#\"processImagePath\": \"${ROOT26}/System/Library/CoreServices#\"processImagePath\": \"/System/Library/CoreServices#g" "$dir/log.ndjson"
  [[ -z "${DOTDOT:-}" ]] || sed -i '' "s#RuntimeRoot/System/Library/CoreServices#RuntimeRoot/System/../System/Library/CoreServices#g" "$dir/log.ndjson"
  if [[ "${WITHDRAWN:-}" == true ]]; then
    node -e '
      const fs=require("fs"), file=process.argv[1];
      const lines=fs.readFileSync(file,"utf8").split("\n").filter(Boolean);
      const req=lines.map(l=>JSON.parse(l)).find(v=>/Received remote notification request/.test(v.eventMessage||""));
      const digest=req.eventMessage.match(/request ([0-9A-F]{4}-[0-9A-F]{4})/)[1];
      const t=new Date(Date.now()+5000), p=(n,w=2)=>String(n).padStart(w,"0");
      const stamp=`${t.getUTCFullYear()}-${p(t.getUTCMonth()+1)}-${p(t.getUTCDate())} ${p(t.getUTCHours())}:${p(t.getUTCMinutes())}:${p(t.getUTCSeconds())}.${p(t.getUTCMilliseconds(),3)}000+0000`;
      fs.appendFileSync(file,JSON.stringify({timestamp:stamp,processImagePath:req.processImagePath,
        senderImagePath:"/System/Library/PrivateFrameworks/UserNotificationsServer.framework/UserNotificationsServer",
        subsystem:"com.apple.UserNotifications",category:"DataProvider",messageType:"Default",
        eventMessage:`[com.example.sampleshop] Withdrawing notification ${digest}`})+"\n");
    ' "$dir/log.ndjson"
  fi
  store="$(node "$READER" store "$dir/devices" SIM "$BUNDLE")"
  log="$(touch "$dir/log.ndjson"; node "$READER" log "$BUNDLE" --root "${RUNTIME_ROOT:-$ROOT26}" < "$dir/log.ndjson")"
  node -e '
    const [store,log,marker,nonce,prepared,require,logOk]=process.argv.slice(1);
    const l=JSON.parse(log);
    process.stdout.write(JSON.stringify({
      expect:{marker,nonce_sha256:nonce,template_id:424242,not_before:prepared},
      store:JSON.parse(store), events:l.events, log_lines:l.lines>0 ? l.lines : 50,
      log_ok:logOk==="true", require_record:require==="true",
      receipt_digest:process.argv[8]==="record" ? (JSON.parse(store).records[0]?.digest || l.events.find(e=>e.kind==="remote_request")?.digest) : null
    }));
  ' "$store" "$log" "$MARKER" "$NONCE_HASH" "$prepared" "$require" "$log_ok" "${RECEIPT:-}" | node "$READER" judge
}

field() {
  node -e '
    let v=JSON.parse(process.argv[1]);
    for (const key of process.argv[2].split(".")) v=v?.[key];
    process.stdout.write(v == null ? "" : String(v));
  ' "$1" "$2"
}

expect_pass() {
  local name="$1" out="$2"
  if [[ "$(field "$out" observed)" == true && "$(field "$out" evidence.apns_received)" == true &&
        "$(field "$out" evidence.os_stored)" == true && "$(field "$out" apns_binding)" == nonce ]]; then
    ok "$name"
  else
    bad "$name" "$out"
  fi
}

expect_fail() {
  local name="$1" out="$2" diagnosis="$3"
  if [[ "$(field "$out" observed)" == false && "$(field "$out" diagnosis)" == "$diagnosis" ]]; then
    ok "$name"
  else
    bad "$name (wanted $diagnosis)" "$out"
  fi
}

expect_pass "the real recorded chain passes: apsd nonce, joined request, saved, stored record" "$(judge apns)"
expect_pass "a stored record with no bundle string still joins through Library.plist" "$(judge nobundle)"
expect_fail "a later re-check without the record, its receipt, or a logged withdrawal does not pass" \
  "$(CLEAR_STORE=true judge apns false)" record_missing
expect_pass "a later re-check accepts the log chain when this run's receipt saw the record in the store" \
  "$(CLEAR_STORE=true RECEIPT=record judge apns false)"
expect_pass "a later re-check accepts the log chain when iOS logged withdrawing that notification" \
  "$(CLEAR_STORE=true WITHDRAWN=true judge apns false)"
expect_fail "at send time the log chain alone is not enough; the stored record is required" \
  "$(CLEAR_STORE=true judge apns true)" arrived_not_stored
expect_fail "the real recorded simctl injection (Simulator Target Bundle) is rejected" "$(judge injected)" injection_detected
expect_fail "a record with this run's marker and nonce that SpringBoard added locally is rejected" \
  "$(judge copied)" injection_detected
expect_fail "a redacted apsd payload is unverifiable, never bound by time" "$(judge redacted)" payload_redacted
expect_fail "lines for a sibling bundle (com.example.sampleshop.widget) do not count" "$(judge sibling)" unjoined_record
expect_fail "lines from a non-system process image are unattributable, not a lost push" "$(judge forged)" log_unattributable
expect_fail "Saving NO for the digest overrides the stored record" "$(judge savingno)" notifications_not_authorized
expect_fail "a suppressed foreground delivery is named" "$(judge suppressed)" suppressed_by_app
expect_fail "this run's marker already present with an earlier nonce is a duplicate" "$(judge earliernonce)" duplicate_delivery
expect_fail "a stored record from before this send does not count" "$(judge stale)" arrived_not_stored
expect_fail "a stored record that is not the request following this nonce's apsd line is not joined" \
  "$(judge unjoined)" unjoined_record
expect_fail "another push's visible payload cannot vouch for a record carrying this run's nonce" \
  "$(judge foreign)" unjoined_record
expect_fail "two deliveries of this run's push are not counted" "$(judge duplicate)" duplicate_delivery
expect_fail "a failed main log query is unavailable even when other lines exist" "$(judge apns true false)" log_unavailable
expect_fail "notifications turned off for the app are named" "$(judge notauth)" notifications_not_authorized
expect_fail "a missing aps-environment entitlement is named" "$(judge noentitlement)" missing_aps_environment
expect_fail "an app not registered for remote notifications is named" "$(judge unregistered)" app_not_registered
CUSTOM_ROOT="/Users/dev/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.2.simruntime/Contents/Resources/RuntimeRoot"
expect_pass "a runtime installed under ~/Library (or Xcode outside /Applications) is accepted at its own root" \
  "$(REROOT="$CUSTOM_ROOT" RUNTIME_ROOT="$CUSTOM_ROOT" judge apns)"
expect_fail "lines from another runtime's root are unattributable" \
  "$(RUNTIME_ROOT="/Library/Developer/CoreSimulator/Volumes/iOS_23E244/Library/Developer/CoreSimulator/Profiles/Runtimes/iOS 26.4.simruntime/Contents/Resources/RuntimeRoot" judge apns)" log_unattributable
expect_fail "a raw /System SpringBoard process is not accepted on the Simulator path" "$(RAWSYSTEM=1 judge apns)" log_unattributable
expect_fail "an image path with .. segments is rejected" "$(DOTDOT=1 judge apns)" log_unattributable
expect_fail "a system process logging through an unrelated sender image is not attributed" "$(judge forgedsender)" log_unattributable
expect_fail "SpringBoard lines for a sibling bundle cannot complete this bundle's chain" "$(judge siblingsb)" arrived_not_stored
expect_fail "another push's apsd line within two seconds makes the pairing ambiguous" "$(judge concurrent)" ambiguous_delivery
expect_fail "another notification saved NO in the window makes the pairing ambiguous" "$(judge othersuppressed)" ambiguous_delivery
stale_dir="$ROOT/stale"
mkdir -p "$stale_dir"
"$SIMULATE" register "$stale_dir/devices" SIM "$BUNDLE"
"$SIMULATE" deliver apns "$stale_dir/devices" SIM "$BUNDLE" "$MARKER" "$NONCE" 424242 "$stale_dir/now.ndjson"
"$SIMULATE" deliver apns "$stale_dir/devices" SIM "$BUNDLE" ITBL-IOS-PROOF-111111111111 "$NONCE" 424242 "$stale_dir/old-raw.ndjson"
node -e '
  const fs=require("fs");
  const shift=v=>{const d=new Date(Date.now()-7200000), p=(n,w=2)=>String(n).padStart(w,"0");
    v.timestamp=`${d.getUTCFullYear()}-${p(d.getUTCMonth()+1)}-${p(d.getUTCDate())} ${p(d.getUTCHours())}:${p(d.getUTCMinutes())}:${p(d.getUTCSeconds())}.000000+0000`; return v;};
  const old=fs.readFileSync(process.argv[1],"utf8").split("\n").filter(Boolean).map(l=>JSON.stringify(shift(JSON.parse(l))));
  fs.writeFileSync(process.argv[2],old.join("\n")+"\n"+fs.readFileSync(process.argv[3],"utf8"));
' "$stale_dir/old-raw.ndjson" "$stale_dir/mixed.ndjson" "$stale_dir/now.ndjson"
since="$(node -e 'process.stdout.write(new Date(Date.now()-60000).toISOString())')"
windowed="$(node "$READER" log "$BUNDLE" --root "$ROOT26" --since "$since" < "$stale_dir/mixed.ndjson")"
all="$(node "$READER" log "$BUNDLE" --root "$ROOT26" < "$stale_dir/mixed.ndjson")"
if [[ "$(field "$windowed" lines)" -eq "$(grep -c eventMessage "$stale_dir/now.ndjson")" &&
      "$(field "$all" lines)" -gt "$(field "$windowed" lines)" ]]; then
  ok "--since keeps only the proof window even when the log query returns older lines"
else
  bad "--since did not bound the window" "windowed=$(field "$windowed" lines) all=$(field "$all" lines)"
fi

expect_fail "nothing in the window is a push that never reached the Simulator" "$(judge never)" never_reached_simulator

((FAILED)) && exit 1
exit 0
