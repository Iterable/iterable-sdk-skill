#!/usr/bin/env bash
# Shared config for the G0-G9 walk. Override any of these in the environment.

set -uo pipefail

BIN="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WS="$(cd "$BIN/.." && pwd)/workspace"

# Anything resolved from live state (the project's existing package name, app id)
# is cached here so the verifier and the actor agree on what they are talking about.
#
# Sourced key by key rather than with `source`, because a cache must not outrank
# the caller: `PID=other bin/gates` was silently reading the remembered project
# and reporting gates about an app nobody asked about. Whatever is already in the
# environment wins.
if [[ -f "$WS/resolved.env" ]]; then
  while IFS='=' read -r _k _v; do
    [[ "$_k" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
    [[ -n "${!_k:-}" ]] && continue
    export "$_k=$_v"
  done < "$WS/resolved.env"
  unset _k _v
fi

: "${PID:=}"
: "${PACKAGE:=}"
: "${SA_ID:=itbl-onboard-fcm}"
: "${APP_DISPLAY_NAME:=Iterable Onboard Test}"

# Creating a project is opt-in. A tool that runs against a customer's account
# should never invent cloud resources at that scale unless asked outright.
: "${CREATE_PROJECT:=0}"
: "${CREATE_APP:=0}"

ART="$WS/artifacts"
GS_JSON="$ART/google-services.json"
SA_KEY="$ART/sa-key.json"
FCM_ROLE="roles/firebasecloudmessaging.admin"

# The wizard picks PID mid-run, so anything derived from it has to be
# recomputable rather than fixed at source time.
refresh_derived() { SA_EMAIL="$SA_ID@$PID.iam.gserviceaccount.com"; }
refresh_derived

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }
bold()  { printf '\033[1m%s\033[0m' "$1"; }

interactive() { [[ -t 0 && -t 1 && "${NON_INTERACTIVE:-0}" != 1 ]]; }

tok() { gcloud auth print-access-token 2>/dev/null; }

# firebase.googleapis.com rejects user credentials with 403 unless a quota
# project is attached. The gcloud CLI sends one implicitly, which is why
# `gcloud projects list` works while a raw curl with the same token does not.
# Resolution order: the project we're working on, gcloud's configured project,
# then whatever ADC has recorded.
quota_project() {
  if [[ -n "${QP:-}" ]]; then printf '%s' "$QP"; return; fi
  if [[ -n "$PID" ]]; then printf '%s' "$PID"; return; fi
  # Written only after a call actually succeeded with it — see firebase_projects.
  [[ -s "$WS/.quota" ]] && { tr -d '\n' < "$WS/.quota"; return; }
  local p
  p="$(gcloud config get-value project 2>/dev/null)"
  [[ -n "$p" && "$p" != "(unset)" ]] && { printf '%s' "$p"; return; }
  node -e 'try{process.stdout.write(require(process.env.HOME+"/.config/gcloud/application_default_credentials.json").quota_project_id||"")}catch(e){}' 2>/dev/null
}

# Quota-project candidates for the project *list*, which runs before any project
# is chosen. Best guess first; duplicates dropped.
quota_candidates() {
  {
    [[ -s "$WS/.quota" ]] && { tr -d '\n' < "$WS/.quota"; echo; }
    local p
    p="$(gcloud config get-value project 2>/dev/null)"
    [[ -n "$p" && "$p" != "(unset)" ]] && echo "$p"
    node -e 'try{const q=require(process.env.HOME+"/.config/gcloud/application_default_credentials.json").quota_project_id;if(q)console.log(q)}catch(e){}' 2>/dev/null
    gcloud projects list --format='value(projectId)' --limit="${LIMIT:-50}" 2>/dev/null
  } | awk 'NF && !seen[$0]++'
}

# Single writer for resolved.env, so the wizard and the actor cannot drift in how
# they record a choice. An empty value deletes the key — used to drop a derived
# value like APP_ID that a new project invalidates.
save_resolved() {
  mkdir -p "$WS"; touch "$WS/resolved.env"
  grep -v "^$1=" "$WS/resolved.env" > "$WS/.resolved.tmp" 2>/dev/null || true
  mv "$WS/.resolved.tmp" "$WS/resolved.env"
  [[ -n "${2:-}" ]] && echo "$1=$2" >> "$WS/resolved.env"
  return 0
}

# POST with the same auth and quota-project handling as api_get. Every call to
# firebase.googleapis.com needs the quota header, not just the reads — leaving it
# off the writes is exactly how the 403 came back after api_get was fixed.
api_post() {
  local url="$1" data="${2:-}" body code qp
  [[ -n "$data" ]] || data='{}'
  qp="$(quota_project)"
  body="$(curl -sS -w $'\n%{http_code}' -X POST \
    -H "Authorization: Bearer $(tok)" \
    -H 'Content-Type: application/json' \
    ${qp:+-H "x-goog-user-project: $qp"} \
    -d "$data" "$url" 2>&1)"
  code="${body##*$'\n'}"
  printf '%s' "${body%$'\n'*}"
  [[ "$code" =~ ^2 ]]
}

# GET a URL with the user's token; echoes body, returns non-zero on non-2xx.
api_get() {
  local url="$1" body code qp
  qp="$(quota_project)"
  body="$(curl -sS -w $'\n%{http_code}' \
    -H "Authorization: Bearer $(tok)" \
    ${qp:+-H "x-goog-user-project: $qp"} \
    "$url" 2>&1)"
  code="${body##*$'\n'}"
  printf '%s' "${body%$'\n'*}"
  [[ "$code" =~ ^2 ]]
}

jqn() { local s="$1"; shift; node -e "let d='';process.stdin.on('data',c=>d+=c).on('end',()=>{const j=JSON.parse(d||'{}');$s})" "$@"; }

# Verdict on an FCM messages:send response, split out as a pure function so the
# three-way judgement can be tested against recorded bodies without a network.
#   0 = proves the credential authenticates
#   1 = a real failure
#   2 = eventually consistent, ask again shortly
classify_fcm_response() {
  local code="$1" body="$2"
  case "$code" in
    200) echo "FCM accepted validate_only send"; return 0 ;;
    # A 400 on the placeholder token still proves auth: FCM authenticated us and
    # then rejected the fake registration token, which is exactly what we want.
    400) grep -qiE 'registration.token|INVALID_ARGUMENT' <<< "$body" \
           && { echo "authenticated (400 on placeholder token, as expected)"; return 0; }
         echo "HTTP 400: $(api_err "$body")"; return 1 ;;
    # IAM takes ~75s to make a new binding effective, so this 403 arrives even
    # though G7 is green and the binding really is in the policy.
    403) grep -q 'cloudmessaging.messages.create' <<< "$body" \
           && { echo "role not effective yet (cloudmessaging.messages.create denied)"; return 2; }
         echo "HTTP 403: $(api_err "$body")"; return 1 ;;
    *)   echo "HTTP $code: $(api_err "$body")"; return 1 ;;
  esac
}

# Google wraps one useful sentence in twenty lines of JSON. Pull out that sentence.
api_err() {
  printf '%s' "$1" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    let m; try { m = JSON.parse(d).error?.message } catch (e) {}
    process.stdout.write((m || d).replace(/\s+/g," ").trim().slice(0, 200));
  })' 2>/dev/null
}

android_apps() { api_get "https://firebase.googleapis.com/v1beta1/projects/$PID/androidApps"; }

# ----------------------------------------------------------------- Iterable side
# Keys live in their own file, not resolved.env: resolved.env holds choices that
# are safe to print, this holds secrets that are not.
ITBL_ENV="$WS/.env"
# shellcheck disable=SC1090
[[ -f "$ITBL_ENV" ]] && source "$ITBL_ENV"

# EDC-based Iterable projects answer on api.eu.iterable.com. A key from one data
# centre returns 401 against the other, which reads exactly like a bad key — so
# this is a knob, not a constant.
: "${ITBL_BASE:=https://api.iterable.com}"
: "${ITBL_SERVER_KEY:=}"
: "${ITBL_MOBILE_KEY:=}"
: "${ITBL_EMAIL:=}"
# Set only when the proof push was sent through a campaign. A proof send raises no
# pushSend event, so G17 can corroborate nothing without this — see the plan.
: "${ITBL_CAMPAIGN_ID:=}"
# The push integration name Iterable matches against; equals the package name
# unless the integration predates Aug 2019 or was named by hand.
itbl_integration() { printf '%s' "${ITBL_PUSH_INTEGRATION:-$PACKAGE}"; }

# Single writer for workspace/.env, kept 0600. An empty value deletes the key.
save_env() {
  mkdir -p "$WS"; touch "$ITBL_ENV"; chmod 600 "$ITBL_ENV"
  grep -v "^$1=" "$ITBL_ENV" > "$WS/.env.tmp" 2>/dev/null || true
  mv "$WS/.env.tmp" "$ITBL_ENV"; chmod 600 "$ITBL_ENV"
  [[ -n "${2:-}" ]] && printf '%s=%s\n' "$1" "$2" >> "$ITBL_ENV"
  return 0
}

urlenc() { node -e 'process.stdout.write(encodeURIComponent(process.argv[1]))' "$1"; }

# Set by the proof sender so G16 can require the push it reads to be the one that
# was sent, rather than any notification the app happened to post.
: "${ITBL_PROOF_MARKER:=}"
: "${ITBL_PROOF_SENT_AT:=}"

# ------------------------------------------------------------------- Device side
# The developer's own app, on their own device. Everything here is a read over
# adb: the tool never builds or installs their app for them, and never sends from
# the device. How long to keep asking a device that answers "not yet".
: "${DEVICE_WAIT:=45}"

# `adb devices` also lists entries in state `offline`, `unauthorized` and
# `no permissions`, none of which answer a shell command.
adb_devices() { adb devices 2>/dev/null | awk '$2=="device"{print $1}'; }

# One serial, or the reason there isn't one. ANDROID_SERIAL wins because adb
# honours it natively, so a developer who already exports it keeps their setup.
#
# With several devices attached this deliberately does not choose. Picking the
# first one and reporting a green gate about a device the developer wasn't
# thinking of is worse than asking, and the ask is one command long.
device_serial() {
  local list n
  list="$(adb_devices)"
  # Taken on trust, a serial for a device that isn't there turns every read into a
  # silent failure: `adb -s` writes "device not found" to stderr and exits, and a
  # gate that greps the empty output concludes the app isn't installed. It is not
  # the same claim, and this is the only place that can tell them apart.
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    grep -qx -- "$ANDROID_SERIAL" <<< "$list" && { printf '%s' "$ANDROID_SERIAL"; return 0; }
    echo "ANDROID_SERIAL=$ANDROID_SERIAL is not connected (adb sees: ${list:-nothing})" | tr '\n' ' '
    return 1
  fi
  n="$(printf '%s' "$list" | grep -c '[^[:space:]]')"
  case "$n" in
    0) echo "no device — start an emulator or attach a phone, then re-run"; return 1 ;;
    1) printf '%s' "$list"; return 0 ;;
    *) echo "$n devices attached — say which: export ANDROID_SERIAL=$(printf '%s' "$list" | head -1)"
       return 1 ;;
  esac
}

: "${ITBL_CODE:=}"
: "${ITBL_BODY:=}"

# Separate from itbl_call so a test can stub the transport and prove the
# code/body split with no network. Appends the status on its own last line,
# because bodies contain newlines and the gates need the status to tell
# "wrong key" from "key fine, request rejected".
itbl_curl() {
  local method="$1" key="$2" path="$3" data="${4:-}"
  curl -sS -w $'\n%{http_code}' -X "$method" \
    -H "Api-Key: $key" -H 'Content-Type: application/json' \
    ${data:+-d "$data"} "$ITBL_BASE$path" 2>&1
}

# Sets ITBL_CODE and ITBL_BODY in the caller. Returns non-zero on non-2xx.
#
# Deliberately not "echo the body, set the code": `body="$(itbl_get …)"` runs the
# function in a subshell, so the status it assigns dies with that subshell and the
# next line reads an unset variable. Both values come back through globals, and
# the only subshell is the one inside this function.
itbl_call() {
  local out
  out="$(itbl_curl "$@")"
  ITBL_CODE="${out##*$'\n'}"
  ITBL_BODY="${out%$'\n'*}"
  [[ "$ITBL_CODE" =~ ^2 ]]
}
itbl_get()  { itbl_call GET  "$1" "$2"; }
itbl_post() { itbl_call POST "$1" "$2" "${3:-}"; }

# Iterable wraps errors as {"msg":…,"code":…,"params":…}.
itbl_err() {
  printf '%s' "$1" | node -e 'let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
    let m; try { const j=JSON.parse(d); m=j.msg||j.error } catch (e) {}
    process.stdout.write((m || d).replace(/\s+/g," ").trim().slice(0, 200));
  })' 2>/dev/null
}

# Verdict on an Iterable API response, pure so it can be tested against recorded
# bodies. mode=auth-only means a 400 still counts: we sent a deliberately invalid
# body to prove the key authenticates without creating anything.
#   0 = the key authenticated, 1 = a real failure
classify_itbl_response() {
  local code="$1" body="$2" mode="${3:-strict}"
  case "$code" in
    200|201)
      echo "HTTP $code"; return 0 ;;
    400)
      [[ "$mode" == auth-only ]] \
        && { echo "authenticated (400 on a deliberately empty body, as expected)"; return 0; }
      echo "HTTP 400: $(itbl_err "$body")"; return 1 ;;
    401|403)
      # A JWT-enabled key fails closed without a JWT. The fix is a different key
      # or the shared secret, not a different call — so name it.
      grep -q 'InvalidJwtPayload\|JWT' <<< "$body" \
        && { echo "key needs a JWT ($(itbl_err "$body"))"; return 1; }
      echo "key rejected (HTTP $code) — wrong key type, wrong data centre, or revoked"; return 1 ;;
    429)
      echo "rate limited (429)"; return 1 ;;
    *)
      echo "HTTP $code: $(itbl_err "$body")"; return 1 ;;
  esac
}

# Every Firebase-enabled project, in one call — no per-project probing.
#
# The catch: this call needs a quota project that has firebase.googleapis.com
# enabled. A project you merely have access to is not enough — it answers 403
# SERVICE_DISABLED. Every Firebase project qualifies by definition, so rather
# than guess we try candidates against the real call and keep the first that
# answers. That makes the cached quota project one we have proven, not assumed.
firebase_projects() {
  local url='https://firebase.googleapis.com/v1beta1/projects?pageSize=100' body p
  while read -r p; do
    body="$(QP="$p" api_get "$url" 2>/dev/null)" || continue
    mkdir -p "$WS"; printf '%s' "$p" > "$WS/.quota"
    printf '%s' "$body" | jqn 'process.stdout.write((j.results||[])
      .filter(p=>!p.state||p.state==="ACTIVE")
      .map(p=>[p.projectId,p.displayName||""].join("\t")).join("\n"))'
    return 0
  done <<< "$(quota_candidates)"
  return 1
}

android_apps_of() {
  QP="$1" PID="$1" api_get "https://firebase.googleapis.com/v1beta1/projects/$1/androidApps" \
    | jqn 'process.stdout.write((j.apps||[])
             .map(a=>[a.packageName,a.appId].join("\t")).join("\n"))'
}

app_id_for_package() {
  android_apps 2>/dev/null | jqn '
    const a=(j.apps||[]).find(a=>a.packageName===process.argv[1]);
    process.stdout.write(a?a.appId:"")' "$1"
}

require_pid() {
  [[ -n "$PID" ]] && return 0
  cat >&2 <<'EOF'
No project selected. Pick one with:

    bin/discover              # lists your Firebase projects and their Android apps
    echo 'PID=your-project-id' >> workspace/resolved.env
EOF
  return 1
}
