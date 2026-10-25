#!/usr/bin/env bash
# The wizard's questions, as data an agent can render.
#
# bin/wizard asks these with an arrow-key menu. A chat has no menu, so the agent asks
# them instead — but the agent must not be the thing that *writes* them. A model that
# composes its own consent screen writes a different one every run, and the run where
# it shortens "Data notifications" to "notifications" or drops "nothing has happened
# yet" is the run nobody can reconstruct. So the words are the tool's, the options are
# the tool's, and the agent's whole job is to show them and report which one came back.
#
# Which question comes up is next_action's decision, not the agent's — same as every
# other step. This file only says what a question looks like once the ladder has
# chosen it.
#
# Every option carries the commands that enact it, so a choice is never a note in the
# conversation: it becomes a record on disk that the gate spending it can check. That
# is the whole reason consent survives being asked in a chat window.

source "$(dirname "${BASH_SOURCE[0]}")/screen-copy.sh"

# Lines on stdin, blanks included, as a JSON array. The blanks are paragraph breaks —
# dropping them turns nine lines of context into one wall of text.
q_arr() {
  local sep="" l
  printf '['
  while IFS= read -r l; do printf '%s%s' "$sep" "$(jstr "$l")"; sep=","; done
  printf ']'
}

# q_opt <label> <description> <effect> <relay> [command ...]
#
# `effect` is what the choice does to state, in the tool's words rather than the agent's.
# `description` is what the developer reads under the label.
#
# `commands` and `relay` are two different things and the difference is the point.
# Commands are the agent's to run. A relay is a command only the developer can run —
# it prompts for a secret with the echo off, or hosts a browser sign-in — so the agent
# prints it and waits. Collapsing them into one list is how an agent ends up running the
# script that was meant to take the keys where nothing could log them. Empty when the
# option has nothing to hand over.
q_opt() {
  local label="$1" desc="$2" effect="$3" relay="$4" sep="" c; shift 4
  printf '{"label":%s,"description":%s,"effect":%s,"relay":%s,"commands":[' \
    "$(jstr "$label")" "$(jstr "$desc")" "$(jstr "$effect")" "$(jstr "$relay")"
  for c in "$@"; do printf '%s%s' "$sep" "$(jstr "$c")"; sep=","; done
  printf ']}'
}

# q_free_text <hint> <effect> <command-template> — the typed answer, for the screens
# where the options cannot be the whole truth.
#
# A developer can have twelve Firebase projects and the host draws four options, so a
# picker without this is a picker that hides the right answer from some people. The
# template carries {{answer}} where their text goes.
#
# What makes it safe to offer is at the other end: `agent set` format-checks the value
# and refuses a multi-line one, because this is the one field in the whole tool where
# text from a chat becomes a recorded setting. Never used for a secret — the two API keys
# go from the clipboard into a 0600 file by way of `iterable-keys --take`, which is the
# whole reason nothing here has to ask for one, and no free_text below ever names one.
q_free_text() {
  printf '{"hint":%s,"effect":%s,"command":%s}' \
    "$(jstr "$1")" "$(jstr "$2")" "$(jstr "$3")"
}

# ------------------------------------------------------ before anything at all
#
# The first screen, and the only one that has to be answerable with nothing on disk and
# nothing read. Every other question here is carried in a status read — and a status read
# runs the whole ladder against the developer's projects, so a question delivered that way
# arrives after the work it was meant to ask about. Two live trials ended the same way: an
# agent decided provisioning was needed, ran it, and presented a project picker. The
# picker was not a consent screen and nothing before it had been one.
#
# So this one is asked from a standing start. It spends no credentials, writes no
# workspace, and names the shape of the whole job rather than the next step of it —
# because what is being agreed to here is the job.
q_opening_context() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "{{part_map}}" ]]; then
      part_map | plain | sed 's/^  //' | sed '/^$/d'
    else
      printf '%s\n' "$line"
    fi
  done < <(screen_copy_section opening Context)
}

q_opening() {
  local id label description sep="" here
  screen_copy_validate opening "agent terminal stop" "part_map" || return 1
  here="$(screen_copy_option_scalar opening agent Label)"
  printf '{"header":%s,"prompt":%s,' \
    "$(jstr "$(screen_copy_scalar opening Header)")" \
    "$(jstr "$(screen_copy_section opening Prompt)")"
  printf '"context":%s,' "$(q_opening_context | q_arr)"
  printf '"requires":%s,' "$(screen_copy_section opening Requirements | q_arr)"
  printf '"recommended":%s,' "$(jstr "$here")"
  printf '"options":['
  # Markdown controls labels, descriptions and their order. Stable ids connect each
  # option to behavior here, so rewording or moving one cannot attach another option's
  # command to it.
  while IFS= read -r id; do
    label="$(screen_copy_option_scalar opening "$id" Label)"
    description="$(screen_copy_option_scalar opening "$id" Description)"
    printf '%s' "$sep"; sep=","
    case "$id" in
      # Records the driver, and that is not bookkeeping. A chat has no tty, so
      # provisioning refuses to run from one unless the choice is on disk.
      agent)
        q_opt "$label" "$description" \
          "DRIVER=agent recorded; ladder read; nothing changed" "" \
          "$BIN/agent set DRIVER=agent" "$BIN/agent" ;;
      terminal)
        q_opt "$label" "$description" \
          "DRIVER=developer recorded; the block to follow is printed" "" \
          "$BIN/agent set DRIVER=developer" "$BIN/handoff" ;;
      stop)
        q_opt "$label" "$description" "nothing read; nothing written" "" ;;
    esac
  done < <(screen_copy_option_ids opening)
  printf ']}'
}

# ------------------------------------------------------------- Step 0: the scope
#
# Preflight returns `scope` until these are recorded in resolved.env, so neither provisioning
# nor code starts on a scope or an identity the agent picked.

# The ids iOS's choose_features records, so the React Native iOS phase takes them as --features.
SCOPE_IDS="sdk-initialization push-notifications event-tracking user-profiles deep-linking in-app-messages mobile-inbox embedded-messaging"

scope_union() { # <recorded> <added> — comma lists; rc 1 on an id not in SCOPE_IDS
  local x out=sdk-initialization add
  add="$(printf '%s' "$2" | tr 'A-Z' 'a-z')"
  [[ "$add" == "initialization only" ]] && add=sdk-initialization
  while IFS= read -r x; do
    [[ -n "$x" ]] || continue
    [[ " $SCOPE_IDS " == *" $x "* ]] || return 1
    out+=$'\n'"$x"
  done < <(printf '%s,%s\n' "$1" "$add" | tr ', ' '\n\n')
  printf '%s\n' "$out" | sort -u | paste -sd, -
}

own_push() { # the app's own push handling, one "detail (file)" per line
  node "$BIN/existing-push.js" scan android "${PROJECT_ROOT:-$(dirname "$WS")}" 2>/dev/null |
    jqn '(Array.isArray(j) ? j : []).forEach(f => console.log(`${f.detail} (${f.file})`))' 2>/dev/null
}

# The first answer still missing. The push question exists only for an app with push of its own.
scope_missing() {
  if [[ -z "${SCOPE_FEATURES:-}" ]]; then echo features
  elif [[ -z "${SCOPE_IDENTITY:-}" ]]; then echo identity
  elif [[ -z "${SCOPE_PUSH:-}" && ",$SCOPE_FEATURES," == *,push-notifications,* && -n "$(own_push)" ]]; then
    echo existing-push
  elif [[ -z "${SCOPE_REGION:-}" ]]; then echo region
  elif [[ -z "${SCOPE_JWT:-}" && "${SCOPE_JWT_CHECK:-}" == true ]]; then echo jwt-check
  elif [[ -z "${SCOPE_JWT:-}" ]]; then echo jwt
  fi
}

# What still blocks provisioning and code: a missing answer, or the whole-scope yes.
scope_gate() {
  local m
  m="$(scope_missing)"
  [[ -n "$m" ]] && { printf '%s' "$m"; return; }
  [[ "${SCOPE_CONFIRMED:-}" == true ]] || printf confirm
}

scope_jwt_keys_url() {
  if [[ "${SCOPE_REGION:-}" == EU ]]; then
    printf 'https://app.eu.iterable.com/settings/apiKeys'
  else
    printf 'https://app.iterable.com/settings/apiKeys'
  fi
}

scope_json() { # <missing>
  printf '{"features":%s,"identity":%s,"existing_push":%s,"region":%s,"jwt":%s,"missing":%s}' \
    "$(jstr "${SCOPE_FEATURES:-}")" "$(jstr "${SCOPE_IDENTITY:-}")" "$(jstr "${SCOPE_PUSH:-}")" \
    "$(jstr "${SCOPE_REGION:-}")" "$(jstr "${SCOPE_JWT:-}")" \
    "$([[ -n "$1" ]] && jstr "$1" || printf null)"
}

q_scope() {
  case "$(scope_missing)" in
    features)      q_scope_features ;;
    identity)      q_scope_identity ;;
    existing-push) q_scope_push ;;
    region)        q_scope_region ;;
    jwt)           q_scope_jwt ;;
    jwt-check)     q_scope_jwt_check ;;
    *)             q_scope_recorded ;;
  esac
}

q_scope_features() {
  printf '{"header":"Features","selection":"multiple","prompt":%s,' "$(jstr "Initializing the SDK and identifying the user are always included. So are in-app messages: once a user is identified the SDK shows them on its own, and none appear until someone creates an in-app campaign in Iterable.

Pick every feature this integration should include. For initialize and identify only, answer: initialization only

Which Iterable features should this integration include?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
The answers are recorded in the workspace, which git ignores. No setup starts and no app code is written until these questions are answered.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "Push notifications" \
    "Push from Iterable, with the notification permission the app has to ask for." \
    "push-notifications added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature push-notifications"
  printf ','
  q_opt "Events + user profiles" \
    "Track the app's own events, and update fields on the user's Iterable profile." \
    "event-tracking and user-profiles added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature event-tracking,user-profiles"
  printf ','
  q_opt "Deep links" \
    "Links that open the app, including from push and in-app messages: App Links, custom URL schemes, and universal links on iOS." \
    "deep-linking added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature deep-linking"
  printf ','
  q_opt "More: inbox, embedded" \
    "Mobile Inbox, Embedded Messages, or custom in-app handling, on one follow-up screen." \
    "nothing recorded; the follow-up screen is printed" "" \
    "$BIN/agent question scope_more"
  printf '],"free_text":%s}' "$(q_free_text \
    "initialization only — initialize the SDK and identify the user, nothing else" \
    "records the initialize-and-identify-only scope" \
    "$BIN/agent scope feature {{answer}}")"
}

q_scope_more() {
  printf '{"header":"More","selection":"multiple","prompt":%s,' "$(jstr "In-app messages already show by default. Pick custom in-app handling only to filter, defer or render them differently.

Which additional features should this integration include?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Each pick is added to the features chosen on the previous screen.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "Mobile Inbox" \
    "Messages the user can open later, in the SDK's inbox screen or one of the app's own." \
    "mobile-inbox added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature mobile-inbox"
  printf ','
  q_opt "Embedded Messages" \
    "Messages shown inside the app's own screens, in placements created in Iterable." \
    "embedded-messaging added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature embedded-messaging"
  printf ','
  q_opt "Custom in-app handling" \
    "Filter, defer or render in-app messages differently from the SDK's default." \
    "in-app-messages added to SCOPE_FEATURES" "" \
    "$BIN/agent scope feature in-app-messages"
  printf ']}'
}

q_scope_identity() {
  # Each picked feature records through its own command, so show what landed before moving on.
  printf '{"header":"Identity","selection":"single","prompt":%s,' "$(jstr "Features recorded: ${SCOPE_FEATURES//,/, }. If one you picked is missing, say so before answering.

The Iterable project's type comes first, because it decides which identifier Iterable accepts (project-types-and-unique-identifiers):
· UserID-based: userId only.
· Email-based: email only. Limited availability: some older US-hosted organizations.
· Hybrid: email and userId both identify a user. Use the one every signed-in session holds, a session restored at launch included, and the one your backend or other SDKs already send to Iterable. Another value is another user.

A project's type can't be changed once it exists. Not sure, or no project yet? Choose help me: the skill reads how this app signs users in and recommends a type and an identifier.

What type is the Iterable project, and so how should this app identify users?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
The answer decides the call the app makes, setUserId or setEmail, and what the Iterable test-identity step asks for.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "User ID — setUserId" \
    "UserID-based or hybrid project. The app's own stable account ID, or a random UUID created once per account. Never an email, phone number or username (user-id-validation-in-iterable)." \
    "SCOPE_IDENTITY=user-id recorded; the test-identity step asks for a user ID" "" \
    "$BIN/agent scope identity user-id"
  printf ','
  q_opt "Email — setEmail" \
    "Email-based or hybrid project, where every signed-in session holds the account email. An app that asks for an email only at sign-up has none to pass later." \
    "SCOPE_IDENTITY=email recorded; the test-identity step asks for an email address" "" \
    "$BIN/agent scope identity email"
  printf ','
  q_opt "No known user yet" \
    "The app has no sign-in, or users stay anonymous until they sign in. Nothing is invented to stand in for a user." \
    "SCOPE_IDENTITY=unknown-user recorded" "" \
    "$BIN/agent scope identity unknown-user"
  printf ','
  q_opt "Not sure — help me" \
    "The skill reads every way this app signs a user in, a restored session included, and what its other SDKs identify users with. It recommends a project type and identifier from the bundled docs, then asks again. With no project yet, it guides creating one." \
    "nothing recorded; inspect the app's sign-in, recommend per the skill's Identity section, then ask this screen again" ""
  printf ']}'
}

q_scope_push() {
  printf '{"header":"Your push","selection":"single","prompt":%s,' "$(jstr "This app already handles push without Iterable:
$(own_push | sed 's/^/· /')

Often that is transactional push, like order updates or security codes, and it can matter more than the push being added.

Keep your app's own notifications working alongside Iterable's, or use Iterable notifications only?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Found by reading the source of the app, so it can miss a provider or name one that is no longer used.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "Keep both" \
    "The app's messaging service forwards only Iterable's pushes to Iterable, and your own notifications keep working." \
    "SCOPE_PUSH=keep-both recorded" "" \
    "$BIN/agent scope existing-push keep-both"
  printf ','
  q_opt "Iterable only" \
    "The integration diff shows how your own service and provider stop handling pushes. Nothing changes until you confirm that diff." \
    "SCOPE_PUSH=iterable-only recorded" "" \
    "$BIN/agent scope existing-push iterable-only"
  printf ','
  q_opt "Not sure — help me decide" \
    "The skill shows what each answer changes in this app, from the bundled push docs, then asks again." \
    "nothing recorded; explain both answers per the skill's Existing push decision, then ask this screen again" ""
  printf ']}'
}

q_scope_region() {
  printf '{"header":"Region","selection":"single","prompt":%s,' "$(jstr "Which Iterable project region does this app use?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
The Mobile API key and SDK data region must match the selected Iterable project. A US key cannot be treated as an EU key, or the reverse.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "US project" \
    "Use the standard Iterable US API endpoints." \
    "SCOPE_REGION=US recorded" "" \
    "$BIN/agent scope region US"
  printf ','
  q_opt "EU project" \
    "Use the EU Iterable API host for server-side calls and the EU project key." \
    "SCOPE_REGION=EU recorded; ITBL_BASE set to api.eu.iterable.com" "" \
    "$BIN/agent scope region EU"
  printf ','
  q_opt "Not sure — help me find out" \
    "Shows how to read the region from the project address, and what to do with no project yet." \
    "nothing recorded; open european-data-center and android-sdk Step 5.2 in the skill, then ask this screen again" ""
  printf ']}'
}

q_scope_jwt() {
  printf '{"header":"JWT","selection":"single","prompt":%s,' "$(jstr "Unless your app already has a backend that issues user-specific Iterable JWTs, choose No JWT. Should the Mobile key you create or pick in a later step require JWT?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
You do not need a Mobile API key yet. A later step creates one in Iterable, or picks the one you already have, and its Require JWT setting must match this answer.

Choose JWT only when the app already runs a backend that issues user-specific Iterable JWTs. The app then asks that backend for each token and never mints one itself. A new app without such a backend should choose No JWT.
EOF
)"
  printf '"requires":[],"recommended":%s,"options":[' "$(jstr "No JWT — new app or no JWT backend")"
  q_opt "No JWT — new app or no JWT backend" \
    "Records No JWT, right for an app without a JWT backend. The Iterable walk creates the Mobile key with Require JWT Off." \
    "SCOPE_JWT=false recorded" "" \
    "$BIN/agent scope jwt false"
  printf ','
  q_opt "I already have a Mobile key — check its setting" \
    "Shows where to read the existing key's Require JWT setting, then you answer from what it shows." \
    "opens the JWT check screen; nothing recorded yet" "" \
    "$BIN/agent scope jwt-check"
  printf ','
  q_opt "Not sure — help me decide" \
    "Explains the one fact that decides it; for most apps the answer is No JWT." \
    "nothing recorded; open jwt-enabled-api-keys in the skill, then ask this screen again" ""
  printf ','
  q_opt "JWT required — we run a JWT backend" \
    "Only when a backend already issues user-specific Iterable JWTs; the integration adds an auth handler that calls it." \
    "SCOPE_JWT=true recorded" "" \
    "$BIN/agent scope jwt true"
  printf ']}'
}

q_scope_jwt_check() {
  local url; url="$(scope_jwt_keys_url)"
  printf '{"header":"JWT check","selection":"single","prompt":%s,' "$(jstr "Read the setting on the Mobile key this app will use:
1. Open $url (or go to Integrations > API Keys).
2. Find the key whose type is Mobile. If there are several, use the one this app will ship with.
3. Read its JWT column, or open the key and read Require JWT.
4. Answer below with what it shows.

In Iterable → Integrations → API Keys, read your Mobile key's Require JWT setting — is it on or off?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Nothing is copied here; the key itself is captured securely in a later step. If there is no Mobile key, go back and choose for the new one.
EOF
)"
  printf '"requires":[],"recommended":null,"options":['
  q_opt "Require JWT is off" \
    "The existing Mobile key does not require JWT." \
    "SCOPE_JWT=false recorded" "" \
    "$BIN/agent scope jwt false"
  printf ','
  q_opt "Require JWT is on" \
    "The existing Mobile key requires JWT; the integration must add an IterableAuthHandler backed by your backend." \
    "SCOPE_JWT=true recorded" "" \
    "$BIN/agent scope jwt true"
  printf ','
  q_opt "Show the JWT question again" \
    "Returns to the JWT screen without recording an answer yet." \
    "SCOPE_JWT_CHECK cleared" "" \
    "$BIN/agent scope jwt-check-clear"
  printf ']}'
}

q_scope_recorded() {
  local jwt_label="not recorded"
  [[ "${SCOPE_JWT:-}" == true ]] && jwt_label="required"
  [[ "${SCOPE_JWT:-}" == false ]] && jwt_label="not required"
  printf '{"header":"Scope","selection":"single","prompt":%s,' "$(jstr "Recorded for this app:
· Features: ${SCOPE_FEATURES//,/, }
· Identity: $SCOPE_IDENTITY
· The app's own push: ${SCOPE_PUSH:-not asked, because none was found or push is not in scope}
· Region: ${SCOPE_REGION:-not recorded}
· JWT: $jwt_label

Keep these answers?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Changing them clears every recorded scope answer, and the questions are asked again from the first.
EOF
)"
  printf '"requires":[],"recommended":%s,"options":[' "$(jstr "Keep these answers")"
  q_opt "Keep these answers" \
    "Records the whole scope, then preflight names the next step." \
    "SCOPE_CONFIRMED recorded" "" \
    "$BIN/agent scope confirm"
  printf ','
  q_opt "Change the answers" \
    "Clears the recorded answers, and the features screen comes back." \
    "all scope fields cleared" "" \
    "$BIN/agent scope clear"
  printf ']}'
}

# --------------------------------------------------------- the door: may I look
#
# The first thing this tool spends the developer's Google credentials on is a read: list
# the Firebase projects, list the Android apps in each. Nothing is written, and the
# approval gate below is about changes, so for a long time nothing asked about this at
# all — an agent went from "provisioning is installed" to printing somebody's whole
# Firebase estate into a chat window without a word.
#
# A read is not a mutation and this is not the provisioning banner: asking for the full
# yes here would be asking it before there is anything true to list, because
# firebase_plan names no changes until a project is chosen. So it is its own small
# question, and its honesty is about scope rather than consequence.
q_look_context() {
  echo "To find the project this app belongs to, the skill lists the Firebase projects your gcloud account can see and the Android apps registered in each."
  echo ""
  echo "That is a read. It writes nothing, creates nothing, and changes nothing — and it is the first task that uses your Google credentials."
  echo ""
  echo "Project names, ids, and package names are what is returned. If you don't want this information in this conversation, use the second option and name the project yourself."
  echo ""
  echo "This question isn't asking to change anything. A later question lists each change by name before anything in your Google project is changed."
}

# The one screen that writes something when it is rendered, and the reason is in the
# command below: a one-time token, so the yes cannot be recorded by anybody who never put
# this in front of the developer. Every other question here touches no state at all.
q_choose_target() {
  local look="Yes — list my Firebase projects" tok
  tok="$(ask_for choose_target)" || tok=""
  printf '{"header":"Discover","prompt":%s,' \
    "$(jstr "The skill lists the Firebase projects your gcloud account can see and the Android apps in each. This is a read: nothing is created or changed.

List your Firebase projects?")"
  printf '"context":%s,' "$(q_look_context | q_arr)"
  printf '"requires":%s,' "$(q_approve_requires | q_arr)"
  printf '"recommended":%s,' "$(jstr "$look")"
  printf '"options":['
  # Two commands, and the first one is the point: the read refuses until a yes is on
  # disk, so this option is how the listing becomes possible at all rather than a
  # convenience wrapper around a command that would have worked anyway. The token is the
  # only place it appears, and it is spent the first time it is used.
  q_opt "$look" \
    "Lists the projects and their registered Android apps. If a project already has your package, it can be offered, and that path creates nothing." \
    "reads your project and app list; writes nothing" "" \
    "$BIN/agent approve list --asked $tok" "$BIN/agent discover"
  printf ','
  q_opt "No — I'll name the project myself" \
    "Nothing gets listed. Tell me the Firebase project id and the Android package, so they are recorded as your choice." \
    "nothing read; waiting for a project id and package to record" ""
  printf ','
  q_opt "Abort the setup" \
    "Nothing is read and nothing is recorded. Your Google account is not touched." \
    "nothing read; nothing recorded" ""
  printf ']}'
}

# ------------------------------------------------------------------ signing in
#
# The wizard's first screen. In a chat it can only ever be a relay: `gcloud auth login`
# opens a browser and holds the session, and the whole promise of this tool is that the
# password happens between the developer and Google with nothing in between.
q_sign_in() {
  # Labelled for what it does, not for who does it, because both front ends show this
  # screen and only one of them can host gcloud: a chat hands over the command, the
  # wizard runs it in the terminal it already has. What varies goes in the option's
  # description, which the chat shows and the terminal menu does not.
  local go="Sign in with gcloud"
  printf '{"header":"Sign in","prompt":%s,' "$(jstr "Sign in with this command in your own terminal. It opens your browser, and the password stays between you and Google:

gcloud auth login

Ready to sign in to Google?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Nothing here reads your Google projects until gcloud has a session with your sign-in: this action opens your browser, and neither the tool nor the skill ever see the password.

If you are already signed into the right account, use the second option and the skill will check rather than ask again.
EOF
)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$(jstr "$go")"
  printf '"options":['
  q_opt "$go" \
    "One command in your own terminal. You run it, your browser handles it — come back when it says you are signed in." \
    "nothing changed; waiting for you to sign in" "gcloud auth login"
  printf ','
  q_opt "I'm already signed in — check again" \
    "Re-reads the ladder. If the session is there, the skill stops asking this question; if it isn't there, this continues to be the first step." \
    "ladder re-read; nothing changed" "" \
    "$BIN/agent"
  printf ','
  q_opt "Abort the setup" \
    "Nothing is read and nothing is recorded." \
    "nothing read; nothing recorded" ""
  printf ']}'
}

# ----------------------------------------------------- the remembered choice
#
# A project and package are already on record. Always offered rather than assumed —
# the same rule the wizard follows: a remembered choice is a default to confirm, not a
# decision already made on somebody's behalf. A run that silently reuses last week's
# project is how the wrong account gets provisioned.
q_keep_target() {
  local keep="Yes — use $PID / $PACKAGE" again="No — let me pick again"
  printf '{"header":"Target","prompt":%s,' "$(jstr "On record from an earlier run: project $PID, package $PACKAGE. From here on, the skill reads and changes this project only.

Still the same project and app?")"
  printf '"context":%s,' "$(q_arr <<EOF
Already on record from an earlier run:

project   $PID
package   $PACKAGE

From here on, the skill reads and changes this project only. Confirm the project and app before you continue. You can switch projects now. Nothing has been set up in this one yet.
EOF
)"
  printf '"requires":[],'
  # A remembered choice is a default to confirm — unless it has already failed. This
  # screen is also where a project that does not answer lands, and recommending "carry
  # on with it" there recommends the one thing known not to work.
  if [[ "$(gate_status G2)" == green ]]; then
    printf '"recommended":%s,' "$(jstr "$keep")"
  else
    printf '"recommended":%s,' "$(jstr "$again")"
  fi
  printf '"options":['
  q_opt "$keep" \
    "Carries on with the remembered choice." \
    "target unchanged; ladder re-read" "" \
    "$BIN/agent"
  printf ','
  q_opt "$again" \
    "The skill lists your projects again and asks which one to use. It clears the previous project and app, so a later check can't pass based on that app." \
    "target cleared; your projects listed again" "" \
    "$BIN/agent discover" "$BIN/agent question pick_project"
  printf ','
  q_opt "Abort the setup" \
    "Nothing changes and the remembered choice is left as it is." \
    "nothing changed" ""
  printf ']}'
}

# -------------------------------------------------------------- the pickers
#
# The three wizard menus that had no chat equivalent, which is the whole reason an agent
# reaching this point either invented a picker in its own words or handed the entire job
# to a terminal. Both were observed live.
#
# Drawn from what `bin/agent discover` already fetched and left in the workspace, never
# from a read of its own: the listing is the thing the developer agreed to at the door,
# and a picker that re-reads their account is a second helping of a one-time yes.

# id \t display name \t app count \t carries our package \t packages — best first.
# Exact package matches are the zero-mutation answer, so they come first. Discovery
# already returns projects newest first, and the stable tie-break keeps that order
# within the matching and non-matching groups.
ranked_projects() {
  [[ -s "$WS/discovered.json" ]] || return 1
  PKG="${PACKAGE:-}" node -e '
    let s=""; process.stdin.on("data", d => s += d).on("end", () => {
      const want = process.env.PKG || "", d = JSON.parse(s);
      const matches = p => !!want && (p.apps || []).some(a => a.package === want);
      (d.projects || []).map((p, i) => ({ p, i, match: matches(p) }))
        .sort((a, b) => Number(b.match) - Number(a.match) || a.i - b.i)
        .forEach(({ p, match }) => console.log([
          p.id, p.name || "", (p.apps || []).length, match ? 1 : 0,
          (p.apps || []).map(a => a.package).join(", "),
        ].join("\t")));
    });' < "$WS/discovered.json" 2>/dev/null
}

apps_of_chosen() {
  [[ -s "$WS/discovered.json" ]] || return 1
  PROJ="$PID" node -e '
    let s=""; process.stdin.on("data", d => s += d).on("end", () => {
      const d = JSON.parse(s), p = (d.projects || []).find(p => p.id === process.env.PROJ);
      (p ? p.apps || [] : []).forEach(a => console.log([a.package, a.appId || ""].join("\t")));
    });' < "$WS/discovered.json" 2>/dev/null
}

# Whether the listing the developer agreed to actually covered this project. The whole
# difference between "there is no app for it" and "nobody has looked" — and a project id
# typed in by hand has never been looked at.
listed_project() {
  local id
  while IFS=$'\t' read -r id _; do
    [[ "$id" == "$PID" ]] && return 0
  done <<< "$(ranked_projects)"
  return 1
}

discovered_account() {
  [[ -s "$WS/discovered.json" ]] || return 1
  node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{
    try { process.stdout.write(JSON.parse(s).account || "") } catch (e) {}
  })' < "$WS/discovered.json" 2>/dev/null
}

# Three, and then a place to type. The host draws four options, so a developer with
# twelve projects cannot be given twelve — and a picker that quietly omits the right
# answer is worse than one that admits it only has room for the likely ones.
Q_PICK_MAX=3

# "1 app" / "3 apps". These screens are read by a person, and "1 app(s)" is how a screen
# announces that nobody looked at it.
plz() {
  if [[ "$1" == 1 ]]; then printf '%s %s' "$1" "$2"; else printf '%s %s' "$1" "$3"; fi
}

q_pick_project_context() { # <rows>
  local rows="$1" n matched acct id name napps mine pkgs
  n="$(printf '%s\n' "$rows" | grep -c .)"
  matched="$(printf '%s\n' "$rows" | awk -F'\t' '$4==1' | grep -c . || true)"
  acct="$(discovered_account)"
  echo "$(plz "$n" "Firebase project" "Firebase projects"), read with ${acct:-your gcloud account}. Nothing has been changed."
  echo ""
  if ((matched == 1)); then
    echo "One of them already has $PACKAGE registered, and it is first. That is the path where nothing gets created on the Firebase side — the app already exists, so its google-services.json is a download."
  elif ((matched > 1)); then
    echo "$matched of them already have $PACKAGE registered, shown first. Picking one of those means nothing gets created on the Firebase side — the app already exists, so its google-services.json is a download. Only you can tell which of them is yours."
  elif [[ -n "$PACKAGE" ]]; then
    echo "None of them has $PACKAGE registered yet, so the app has to be registered in whichever one you pick — you'll be asked about this separately, before anything is created."
  fi
  echo ""
  printf '%s\n' "$rows" | head -n "$Q_PICK_MAX" | while IFS=$'\t' read -r id name napps mine pkgs; do
    if ((napps == 0)); then
      echo "$id — ${name:-no display name} · no Android app registered"
    else
      echo "$id — ${name:-no display name} · $pkgs"
    fi
  done
  if ((n > Q_PICK_MAX)); then
    echo ""
    echo "$((n - Q_PICK_MAX)) more not shown. If the one you want is missing, type its project id (not the display name)."
  fi
}

q_pick_project() {
  local rows sep="" i=0 id name napps mine pkgs
  rows="$(ranked_projects)" || return 1
  [[ -n "$rows" ]] || return 1

  printf '{"header":"Project","prompt":%s,' "$(jstr "Which Firebase project is this app in?")"
  printf '"context":%s,' "$(q_pick_project_context "$rows" | q_arr)"
  printf '"requires":[],'
  # No recommendation. Which project an app belongs to is the developer's knowledge, not
  # a ranking — and the top row is the likeliest, not the right one.
  printf '"recommended":null,'
  printf '"options":['
  while IFS=$'\t' read -r id name napps mine pkgs; do
    ((i < Q_PICK_MAX)) || break
    printf '%s' "$sep"; sep=","; i=$((i + 1))
    if [[ "$mine" == 1 ]]; then
      q_opt "$id" \
        "${name:-$id} — already has $PACKAGE registered, so nothing is created. Choose this if it is the right project." \
        "project recorded as $id, package as $PACKAGE; ladder re-read" "" \
        "$BIN/agent set PID=$id PACKAGE=$PACKAGE" "$BIN/agent"
    elif ((napps > 0)); then
      q_opt "$id" \
        "${name:-$id} — has $(plz "$napps" "registered app" "registered apps"): $pkgs. The skill asks which one this is." \
        "project recorded as $id; the app picker comes next" "" \
        "$BIN/agent set PID=$id" "$BIN/agent question pick_app"
    else
      q_opt "$id" \
        "${name:-$id} — no Android app is registered yet, so one has to be created. You'll be asked about this before any action is taken." \
        "project recorded as $id; registering an app is asked next" "" \
        "$BIN/agent set PID=$id" "$BIN/agent question register_app"
    fi
  done <<< "$rows"
  printf ','
  q_opt "None of these — I'll give you the project id" \
    "Type it, and the skill records it as your choice. Use the project id, which is lowercase with hyphens; this is NOT the display name." \
    "nothing recorded yet; waiting for a project id" ""
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "the Firebase project id, lowercase with hyphens" \
    "records it as the project everything from here on reads and changes" \
    "$BIN/agent set PID={{answer}}")"
}

q_pick_app_context() { # <rows>
  local n; n="$(printf '%s\n' "$1" | grep -c .)"
  echo "$PID has $(plz "$n" "Android app" "Android apps") registered. Which of them is the app that's in this repository?"
  echo ""
  echo "Check the package name against the applicationId in build.gradle instead of picking an app name you recognize. A google-services.json file for a different package will still build, but will cause the app to fail when it runs. The resulting error mentions Firebase instead of the package mismatch, making it difficult to troubleshoot."
  if ((n > Q_PICK_MAX)); then
    echo ""
    echo "$((n - Q_PICK_MAX)) more not shown — type the package if it is not listed."
  fi
}

q_pick_app() {
  local rows sep="" i=0 pkg appid detected source rec=null
  rows="$(apps_of_chosen)" || return 1
  [[ -n "$rows" ]] || return 1
  IFS=$'\t' read -r detected source <<< "$(project_package)"
  if [[ -n "$detected" ]] && cut -f1 <<< "$rows" | head -"$Q_PICK_MAX" | grep -qxF "$detected"; then
    rec="$(jstr "$detected")"
  fi

  local ask="Which Android app is in this repository?"
  [[ -z "$detected" ]] || ask="This repository builds $detected (read from $source). Pick the app with that exact package.

$ask"
  printf '{"header":"App","prompt":%s,' "$(jstr "$ask")"
  printf '"context":%s,' "$( { q_pick_app_context "$rows"
    [[ -z "$detected" ]] || { echo ""; echo "This repository builds $detected (read from $source)."; }; } | q_arr)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$rec"
  printf '"options":['
  while IFS=$'\t' read -r pkg appid; do
    ((i < Q_PICK_MAX)) || break
    printf '%s' "$sep"; sep=","; i=$((i + 1))
    q_opt "$pkg" \
      "Registered in $PID as $appid. Nothing is created — its google-services.json is a download." \
      "package recorded as $pkg; ladder re-read" "" \
      "$BIN/agent set PACKAGE=$pkg" "$BIN/agent"
  done <<< "$rows"
  printf ','
  q_opt "None of these — register a new one" \
    "Registering an app changes your Firebase project, so the next screen asks you before anything is created." \
    "nothing recorded; the registration question comes next" "" \
    "$BIN/agent question register_app"
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "the Android package name from your build.gradle" \
    "records it as the app this setup is for" \
    "$BIN/agent set PACKAGE={{answer}}")"
}

# The one screen on the Google side that asks to *create* something, and the reason the
# limits can promise an app is never registered "unless you ask outright". Its yes is
# recorded under its own scope, so the provisioning approval does not quietly include it
# and a yes in one project cannot be spent in another.
q_register_app_context() {
  if [[ -z "$PACKAGE" ]]; then
    # "has no app" and "nothing has looked" are different sentences, and this screen is
    # reachable in both states — from G4, which checked, and from a project chosen with
    # no listing behind it. Saying the first when the second is true is the tool
    # asserting a fact it does not have.
    if listed_project; then
      echo "$PID has no Android app that matches this repository, and the skill doesn't have the package name yet."
    else
      echo "Nothing has listed $PID's Android apps yet, and the skill doesn't have this repository's package name either, so it can't tell whether an app already exists."
    fi
    echo ""
    echo "Type the applicationId from your build.gradle. The skill asks again once that package name is filled in."
    return 0
  fi
  if ! listed_project; then
    echo "Nothing has listed $PID's apps, so the skill can't tell whether $PACKAGE is already registered there. Reading the list is one call and changes nothing. Approving a new app before that check could ask you to create an app that already exists."
    return 0
  fi
  echo "$PID has no Android app for $PACKAGE, so there is no google-services.json file to download. Registering an app is the way forward. A placeholder file lets the build succeed, and the push never arrives."
  echo ""
  echo "This changes your Firebase project. The skill never makes this change unless you ask for it here."
  echo ""
  echo "What it would create:"
  echo "  · one Android app in $PID, package $PACKAGE, display name $APP_DISPLAY_NAME"
  echo ""
  echo "Nothing else is created, and nothing that already exists is changed. You can remove the app later in the Firebase console. $BIN/teardown does not remove it, because it is your app."
}

q_register_app() {
  local yes="Yes — register $PACKAGE in $PID" prompt="Register this Android app in $PID?"
  local detected source rec=null
  [[ -n "$PACKAGE" ]] || IFS=$'\t' read -r detected source <<< "$(project_package)"
  [[ -z "$detected" ]] || rec="$(jstr "Use $detected from $source")"
  # The listing is also what makes "pick a different project" a working answer: with no
  # cache behind it the picker has nothing to draw, so that option has to fetch first.
  local -a back=("$BIN/agent question pick_project")
  listed_project || back=("$BIN/agent discover" "$BIN/agent question pick_project")
  listed_project || [[ -z "$PACKAGE" ]] || prompt="Look before creating anything in $PID?"
  [[ -n "$PACKAGE" ]] && listed_project && prompt="This creates one Android app in Firebase project $PID: package $PACKAGE, display name $APP_DISPLAY_NAME. Nothing else is created or changed.

$prompt"
  printf '{"header":"New app","prompt":%s,' "$(jstr "$prompt")"
  printf '"context":%s,' "$(q_register_app_context | q_arr)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$rec"
  printf '"options":['
  if [[ -n "$PACKAGE" ]] && ! listed_project; then
    q_opt "Check whether it already exists first" \
      "Lists the Android apps in $PID. If $PACKAGE is already there, nothing needs to be created. Its google-services.json file is a download." \
      "nothing created; the apps listed, then this asked again with an answer behind it" "" \
      "$BIN/agent discover" "$BIN/agent question pick_app"
  elif [[ -n "$PACKAGE" ]]; then
    q_opt "$yes" \
      "Records your approval for $PID and nothing more. The provisioning step creates the app, and that step asks for its own approval first." \
      "app registration approved for $PID; ladder re-read" "" \
      "$BIN/agent approve create-app" "$BIN/agent"
  elif [[ -n "$detected" ]]; then
    q_opt "Use $detected from $source" \
      "Records the applicationId this repository builds. Naming the package doesn't create anything. This screen comes back with the package named, and you still choose whether to approve it." \
      "package recorded as $detected; ladder re-read" "" \
      "$BIN/agent set PACKAGE=$detected" "$BIN/agent"
  else
    q_opt "I'll give you the package name" \
      "Type the applicationId from build.gradle. Naming the package doesn't create anything. This screen comes back with the package named, and you still choose whether to approve it." \
      "nothing approved; waiting for a package name" ""
  fi
  printf ','
  q_opt "No — let me pick a different project" \
    "Goes back to the project list. A project that already has this app registered doesn't need a new app." \
    "nothing approved; your projects listed again" "" \
    "${back[@]}"
  printf ','
  q_opt "Abort the setup" \
    "Nothing is approved, nothing is created, and nothing in your project changes." \
    "nothing approved; no calls made" ""
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "the Android package name from your build.gradle" \
    "records which app would be registered — registering it is still a separate yes" \
    "$BIN/agent set PACKAGE={{answer}}")"
}

# The device the proof runs on. Asked even when there is exactly one, because a phone
# left plugged in to charge and yesterday's emulator are both connected and neither is
# the device somebody is watching.
q_pick_device_context() {
  echo "Part 3 sends a real push to a real device and reads that device's notification records to confirm the push arrived. Every later check reads the device you pick, so pick the one you're watching."
  echo ""
  echo "You can choose an emulator that isn't running yet. Setup starts it. A physical phone needs to be plugged in and authorised for adb."
}

q_pick_device() {
  local rows sep="" i=0 name rest
  rows="$(device_options 2>/dev/null)"
  [[ -n "$rows" ]] || return 1
  printf '{"header":"Device","prompt":%s,' "$(jstr "Which device should receive the test push?")"
  printf '"context":%s,' "$(q_pick_device_context | q_arr)"
  printf '"requires":[],'
  printf '"recommended":null,'
  printf '"options":['
  local desc
  while read -r name rest; do
    [[ -n "$name" ]] || continue
    ((i < Q_PICK_MAX)) || break
    printf '%s' "$sep"; sep=","; i=$((i + 1))
    # device_options says what a menu row needs; a chat option needs a sentence. The
    # format it emits is the wizard's, so the reading happens here rather than there.
    case "$rest" in
      "not running"*) desc="Not running yet. Choosing it starts it. You don't need to start it first." ;;
      *"·"*)          desc="Plugged in and running: ${rest##*· }. A physical phone gives the strongest proof." ;;
      *)              desc="Running now, so the checks can read it as soon as your app is installed." ;;
    esac
    q_opt "$name" "$desc" \
      "device recorded as $name; ladder re-read" "" \
      "$BIN/agent set TARGET_DEVICE=$name" "$BIN/agent"
  done <<< "$rows"
  printf ','
  q_opt "None of these" \
    "Start the emulator you want, or plug the phone in and authorise it. Then tell the skill to look again." \
    "nothing recorded; waiting for a device" ""
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "an AVD name, or the adb serial of a phone" \
    "records which device the push gets proved on" \
    "$BIN/agent set TARGET_DEVICE={{answer}}")"
}

# ------------------------------------------------------ part 3: the app's own turn
#
# The verifier opens the selected app, but signing in and answering the notification
# dialog happen inside it, behind whatever login it has. Neither is work an agent can do
# honestly: it has to guess which field is which, and a wrong guess is indistinguishable
# from a screen that was slow.
# The permission dialog is worse than slow — it is a question Android asks *the person*,
# and a tool that taps Allow has answered it on their behalf.
#
# So this asks, and it is the ladder that asks it. Until 2026-09-24 a recorded device left
# this kind with no question at all, and what filled the silence was an agent trying to
# work the emulator by itself, every run, slowly, with no way to tell whether it had.
q_run_app_context() {
  echo "The app has to run once on ${TARGET_DEVICE:-the device} with you signed in. The SDK asks Iterable for a device token at sign-in, so a push has nowhere to go until that happens."
  echo ""
  echo "Two things, both inside your own app:"
  echo ""
  if [[ -n "${ITBL_EMAIL:-}" ]]; then
    echo "  1. Sign in as $ITBL_EMAIL  ← that exact address"
  elif [[ -n "${ITBL_USER_ID:-}" ]]; then
    echo "  1. Sign in as the user whose ID is $ITBL_USER_ID  ← the exact ID the app passes to setUserId()"
  else
    echo "  1. Sign in, then tell the skill which email or user ID you used. The token is stored under it."
  fi
  echo "  2. Allow notifications when Android asks"
  echo ""
  echo "The skill opens the selected app and stops there. It doesn't tap, type, sign in, or grant permission. A guessed tap looks the same as a slow screen, and only you can tap Allow."
  echo ""
  echo "When you've done both, say so below. Every device check runs again."
}

q_run_app() {
  local who="Sign in, then tell the skill which email or user ID you used"
  [[ -z "${ITBL_USER_ID:-}" ]] || who="Sign in as the user whose ID is $ITBL_USER_ID, the exact ID the app passes to setUserId()"
  [[ -z "${ITBL_EMAIL:-}" ]] || who="Sign in as $ITBL_EMAIL, that exact address"
  printf '{"header":"Your app","prompt":%s,' \
    "$(jstr "In your app on ${TARGET_DEVICE:-the device}:
1. $who
2. Allow notifications when Android asks

Signed in on ${TARGET_DEVICE:-the device}, with notifications allowed?")"
  printf '"context":%s,' "$(q_run_app_context | q_arr)"
  printf '"requires":[],'
  # Nothing out here can see their screen, so nothing out here gets to nudge "done" — the
  # same rule as the dashboard steps. A recommendation on an answer the tool cannot check
  # is an invitation to click past the one step that has to actually have happened.
  printf '"recommended":null,'
  printf '"options":['
  q_opt "Done — signed in, notifications allowed" \
    "The checks read the device again. They look for the token Iterable accepted in the log, and for the notification permission Android recorded." \
    "nothing changed; the device half is re-read" "" \
    "$BIN/agent"
  printf ','
  q_opt "It has no sign-in yet" \
    "Then the app never calls setEmail or setUserId, and no token can exist for any user. That is code in your app, not a setting. The app's integration code is what identifies the user." \
    "nothing changed; no identity for a token to be filed under" ""
  printf ','
  q_opt "Android never asked about notifications" \
    "From Android 13 on, the app has to request POST_NOTIFICATIONS itself, at runtime. Without that, the push arrives and is never shown, which looks like a broken integration. This is code, not a setting." \
    "nothing changed; the permission was never put to you" ""
  printf '],'
  # The identity, because a mismatch here is the most common way a working integration
  # looks broken: the token is filed under one address and the proof push goes to another.
  printf '"free_text":%s}' "$(q_free_text \
    "the email or user ID your app actually signs in as" \
    "records ITBL_EMAIL, or ITBL_USER_ID when it is not an email address — the identity the proof push is sent to" \
    "$BIN/agent set ITBL_IDENTITY={{answer}}")"
}

# ------------------------------------------------------- part 1: the Google consent
#
# The same two lists the terminal banner prints, from the same two functions. A second
# copy would be a second thing to keep true, and the one that goes stale is whichever
# the developer happens to be reading.
q_approve_context() {
  echo "Setting up the Google part changes your Cloud project, so it needs your approval first. Nothing has happened yet."
  echo ""
  echo "project   ${PID:-<none chosen yet>}"
  echo "package   ${PACKAGE:-<none chosen yet>}"
  echo ""
  echo "What it would do:"
  firebase_plan | plan_bulleted | while IFS= read -r l; do echo "  $l"; done
  echo ""
  echo "What it will not do:"
  firebase_limits | while IFS= read -r l; do echo "  · $l"; done
  echo ""
  echo "The JSON key this creates stays valid until you delete it. $BIN/teardown removes everything this step adds."
}

# Named only while it is still outstanding. A prerequisite listed after it has been met
# reads as a step the developer still owes, on the one screen where the whole point is
# an accurate account of what is about to happen.
q_approve_requires() {
  [[ "$(gate_status G1)" == green ]] && return 0
  echo "Sign in to Google yourself. Run 'gcloud auth login' in your terminal. Setup never sees your password."
}

# The changes themselves, because the prompt is the one part of a screen every host shows.
q_approve_prompt() {
  echo "Setting up the Google part changes Firebase project ${PID:-<none chosen yet>}, package ${PACKAGE:-<none chosen yet>}. Nothing has happened yet. It would:"
  firebase_plan | awk '/^ / { sub(/^ +/, ""); cur = cur " " $0; next } { if (cur != "") print cur; cur = "· " $0 } END { if (cur != "") print cur }' \
    | sed 's/  */ /g'
  echo ""
  echo "Do you want to proceed?"
}

q_approve_firebase() {
  # The recommendation comes out of the same variable as the label it points at, because
  # a recommendation naming an option that has since been reworded recommends nothing.
  # It follows the driver they already chose, and this screen is only reached once they
  # have: unanswered, the ladder reports choose_driver and the opening screen asks. So the
  # recommendation here is "carry on the way you said", not an opinion about which is better.
  local manual="No — I want to do this manually" yes="Yes — the tool does it, and I agree"
  printf '{"header":"Firebase","prompt":%s,' "$(jstr "$(q_approve_prompt)")"
  printf '"context":%s,' "$(q_approve_context | q_arr)"
  printf '"requires":%s,' "$(q_approve_requires | q_arr)"
  # Follows what they already said. Somebody who answered the opening question with "set
  # it up with me here" is being contradicted by a screen that recommends the terminal,
  # and a recommendation that argues with the developer's own last answer reads as the
  # tool not having heard it.
  if agent_driven; then
    printf '"recommended":%s,' "$(jstr "$yes")"
  else
    printf '"recommended":%s,' "$(jstr "$manual")"
  fi
  printf '"options":['
  q_opt "$yes" \
    "Records your approval for ${PID:-this project} and hands the Google steps to the skill. Only the changes this question lists are made, and nothing that's already working is redone." \
    "approval recorded against ${PID:-<no project>}; DRIVER=agent recorded" "" \
    "$BIN/agent approve firebase" "$BIN/agent set DRIVER=agent" "$BIN/agent"
  printf ','
  q_opt "$manual" \
    "You run the same setup in your own terminal. Google sign-in stays in that terminal session instead of being handed back to this chat." \
    "nothing approved; DRIVER=developer recorded; the block to follow is printed" "" \
    "$BIN/agent set DRIVER=developer" "$BIN/handoff"
  printf ','
  q_opt "Abort the setup" \
    "Nothing is recorded, and nothing in your project changes. You can come back later. Setup reads the current state again from the start." \
    "nothing recorded; no calls made" ""
  printf ']}'
}

# ------------------------------------------------------ part 2: the Iterable walk
q_iterable_context() {
  echo "Part 1 is done and verified: the service-account key exists, and FCM accepted it."
  echo ""
  echo "Part 2 is four steps that you complete in Iterable, in your browser. Iterable has no API to create an API key, a mobile app, or a push integration, so this setup can't do those steps for you."
  echo ""
  echo "This takes about five minutes. You do one step at a time, and each step is checked by what it produced."
  echo ""
  echo "The keys never come through this conversation. You copy a key in Iterable, and the skill reads it from your clipboard into a file with mode 0600, then clears the clipboard. The key is not printed back. A key pasted into a chat stays in the transcript and in logs, and that can't be undone."
  echo ""
  echo "Until the keys are stored, your app has no mobile key, so the device checks have nothing to find. Those unfinished rows mean part 2 hasn't started. Part 1 succeeded, and your app is fine."
}

q_iterable_entry() {
  local start="Start — step 1 of 4"
  printf '{"header":"Iterable","prompt":%s,' \
    "$(jstr "Four steps in the Iterable dashboard, about five minutes. Iterable has no API for them, so you click and the skill checks each result. The keys go from your clipboard into a mode-0600 file, never into this conversation.

Start the four Iterable steps now?")"
  printf '"context":%s,' "$(q_iterable_context | q_arr)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$(jstr "$start")"
  printf '"options":['
  q_opt "$start" \
    "The skill shows step 1. You complete the clicks, and the keys go from your clipboard into the 0600 file. Each step is shown on its own." \
    "walk entered at step 1; nothing recorded yet" "" \
    "$BIN/iterable-keys --step 1" "$BIN/agent question iterable_step 1"
  printf ','
  # Asked here rather than on a screen of its own, because it is one word of an answer
  # and the wrong one is expensive: a US key against the EU host comes back 401, which
  # is indistinguishable from a bad key and sends everybody looking at the wrong thing.
  q_opt "Start — and this is an EU (EDC) project" \
    "Same steps, using api.eu.iterable.com. Choose this if you sign in at app.eu.iterable.com. A key from one data centre returns 401 from the other, which looks like a wrong key." \
    "ITBL_BASE recorded as the EU host; walk entered at step 1" "" \
    "$BIN/agent set ITBL_BASE=https://api.eu.iterable.com" \
    "$BIN/iterable-keys --step 1" "$BIN/agent question iterable_step 1"
  printf ','
  q_opt "I'll run the walk in my own terminal" \
    "You complete the same four steps in your terminal. You type both keys with echo off, instead of using the clipboard. Setup runs the checks when you finish." \
    "walk handed to the developer's terminal; the agent waits" \
    "$(cmd_path iterable-keys)"
  printf ','
  q_opt "Not now — tell me where I stand" \
    "The Iterable steps stay unstarted, and you see the current check results. Nothing here expires." \
    "walk not entered; ladder re-read" "" \
    "$BIN/agent"
  printf ']}'
}

# The per-step question. The step's own text comes from bin/iterable-keys, which owns
# every dashboard URL and click path in one place; this only asks what to do next, so
# the navigation never gets a second copy to drift from.
#
# Steps 1 and 4 each produce a value, so their answers hand that value over instead of
# saying "done". A walk whose only answer is "done" leaves the developer to go and put the
# thing somewhere themselves, and that detour — open a file, find the name, rename it —
# is where a five-minute walk turns into an afternoon.
# The relay instruction, not a summary of the step — and on step 1, the one rule the
# relaying agent has to follow: it has shell access, so "never handle the key" has to say
# which command handles it instead.
# The step's clicks live in the prompt, not here: agents were seen relaying the prompt and
# never printing context, which left the developer a question with no steps above it.
q_step_context() {
  echo "The step is in the prompt. Show it whole, with every value and line break. The exact strings matter. Shortening this step is the costliest mistake in setup."
  if (( $1 == 1 )); then
    echo ""
    echo "Don't ask for either key, and don't read the clipboard yourself. pbpaste and similar commands are off limits here. --take is what moves a key, and it is the only thing in this tool that ever holds one."
  fi
}

q_iterable_step() {
  local n="$1" next=$((${1:-1} + 1)) rec=null
  local prompt="Step $n of 4 — how did that go?"
  local have_server="" have_mobile=""
  [[ -n "$ITBL_SERVER_KEY" ]] && have_server=1
  [[ -n "$ITBL_MOBILE_KEY" ]] && have_mobile=1
  case "$n" in
    1) if [[ -n "$have_server" && -n "$have_mobile" ]]; then
         prompt="Both keys are stored. On to step 2?"
       else
         prompt="Which key is on your clipboard?"
       fi ;;
    4) if [[ -n "$(itbl_identity)" ]]; then
         prompt="The test identity is $(itbl_identity). Prove the whole thing now?"
       else
         case "${SCOPE_IDENTITY:-}" in
           email)   prompt="What email address does your app sign the test user in with?" ;;
           user-id) prompt="What user ID does your app pass to setUserId() for the test user?" ;;
           *)       prompt="What email or user ID does your app sign the test user in with?" ;;
         esac
       fi ;;
  esac
  prompt="$("$BIN/iterable-keys" --step "$n" --prompt 2>/dev/null)

No app code is written while these steps are open. The integration starts once they are proved.

$prompt"
  printf '{"header":%s,"prompt":%s,' "$(jstr "Step $n of 4")" "$(jstr "$prompt")"
  # The relay instruction, not a summary of the step. A model that condenses these
  # screens is how "FCM type: Data notifications" becomes "enable notifications", and
  # that one substitution breaks push in a way everything else still reports as fine.
  printf '"context":%s,' "$(q_step_context "$n" | q_arr)"
  printf '"requires":[],'
  printf '"options":['
  if ((n == 1)); then
    # One capture per option, because that is how the dashboard hands them over: it shows
    # one key at a time, behind a copy button. Whichever is already stored stops being
    # offered — an option that overwrites a good key with the same clipboard is a way to
    # lose one, and a key is shown once.
    local sep=""
    if [[ -z "$have_server" ]]; then
      rec="Server-side key — take it"
      q_opt "$rec" \
        "The skill reads the key from your clipboard into $(wsp .env) at mode 0600, clears the clipboard, and prints only a tick. If the clipboard doesn't contain a key, it says so without quoting the clipboard." \
        "ITBL_SERVER_KEY stored in .env (0600); clipboard cleared" "" \
        "$BIN/iterable-keys --take server" "$BIN/agent question iterable_step 1"
      sep=","
    fi
    if [[ -z "$have_mobile" ]]; then
      printf '%s' "$sep"; sep=","
      [[ -n "$have_server" ]] && rec="Mobile key — take it"
      q_opt "Mobile key — take it" \
        "Same steps for the key your app ships with. Copy it first. Iterable shows each key once, and this reads whatever is on the clipboard right now." \
        "ITBL_MOBILE_KEY stored in .env (0600); clipboard cleared" "" \
        "$BIN/iterable-keys --take mobile" "$BIN/agent question iterable_step 1"
    fi
    if [[ -n "$have_server" && -n "$have_mobile" ]]; then
      rec="Both are in — step 2"
      q_opt "$rec" \
        "Both keys are in the 0600 file. A later step uses them in a real Iterable call, so this step doesn't confirm that they're correct." \
        "walk advanced to step 2; keys stored but not yet proved" "" \
        "$BIN/iterable-keys --step 2" "$BIN/agent question iterable_step 2"
      sep=","
    fi
    printf '%s' "$sep"
    q_opt "Show step 1 again" \
      "The step is shown again, unchanged, including the two lines that take a key. Nothing is skipped. A missing key shows up later as a push that never sends." \
      "step 1 still open" "" \
      "$BIN/agent question iterable_step 1"
  elif ((n < 4)); then
    rec="Done — next step"
    q_opt "$rec" \
      "Moves to the next step. Your answer is what advances it. A later check still confirms this step by testing what it produced." \
      "walk advanced to step $next; nothing verified yet" "" \
      "$BIN/iterable-keys --step $next" "$BIN/agent question iterable_step $next"
    printf ','
    q_opt "It doesn't look like that" \
      "The step is shown again, unchanged, and stays open. Help stays on this step. The Iterable screens can change, but the values and what they mean do not. Nothing is skipped. A step marked done that wasn't done shows up later as a broken integration." \
      "step $n still open" "" \
      "$BIN/agent question iterable_step $n"
  else
    # The identity is not a secret, so unlike the keys it can be said out loud — and the
    # free-text answer is the point of this screen. The device knows it already when the
    # app has run and identified anybody, and offering that is how a mismatch between the
    # two gets caught here rather than three gates later.
    local seen; seen="$(app_identity 2>/dev/null | head -1)"
    local what=address call='setEmail()' key=ITBL_EMAIL
    [[ "$(itbl_identity_kind)" != user-id ]] || { what='user ID'; call='setUserId()'; key=ITBL_USER_ID; }
    if [[ -n "$(itbl_identity)" ]]; then
      rec="Done — now prove it"
      q_opt "$rec" \
        "Both keys are used in a real Iterable call, and $(itbl_identity) is looked up by name. Nothing in the last four steps is taken on trust." \
        "walk complete; ladder re-run to verify all four steps" "" \
        "$BIN/onboard"
      printf ','
      q_opt "That is the wrong $what" \
        "Type the right one below. It has to match the value the app passes to $call, character for character. If they differ, the token is stored for one user and the push goes to another." \
        "$key stays as it is until you give another" ""
    elif [[ -n "$seen" ]]; then
      rec="Use $seen"
      q_opt "$rec" \
        "This is the identity the app on the device registered. It comes from the app's own registerDeviceToken call, so it matches that registration." \
        "$(identity_key "$seen") recorded as $seen" "" \
        "$BIN/agent set $(identity_key "$seen")=$seen" "$BIN/onboard"
      printf ','
      q_opt "Show step 4 again" \
        "The step is shown again, including any identity the device has registered." \
        "step 4 still open" "" \
        "$BIN/agent question iterable_step 4"
    else
      q_opt "Show step 4 again" \
        "The step is shown again, unchanged. Enter the email or user ID below, or set ITBL_EMAIL or ITBL_USER_ID in the 0600 file." \
        "step 4 still open" "" \
        "$BIN/agent question iterable_step 4"
      printf ','
      # The way out for somebody who does not know the answer yet — the app may not sign
      # anyone in at all. Everything up to here still gets proved; the identity gate says
      # what is missing, which is a better place to be stuck than on a screen with no exit.
      q_opt "I don't know it yet — read the ladder" \
        "Runs the checks for what's done. The keys are still used in a real call. The test-identity row stays open and says what's missing, instead of this screen blocking the rest." \
        "test identity left unset; ladder re-read" "" \
        "$BIN/onboard"
    fi
  fi
  printf ','
  q_opt "I'd rather run the rest myself" \
    "You finish the remaining steps in your own terminal. You type both keys with echo off. Anything already in the 0600 file is kept." \
    "walk handed to the developer's terminal at step $n; the agent waits" \
    "$(cmd_path iterable-keys)"
  printf ']'
  # Only where the answer is a value the developer types, and never for a key. The
  # identity, an email or a user ID, belongs in the open; a key put here would be a key
  # in the transcript, which is the one thing this walk is arranged to avoid.
  if ((n == 4)); then
    local hint="the email or user ID your app signs the test user in with" key=ITBL_IDENTITY
    local recorded="records ITBL_EMAIL, or ITBL_USER_ID when it is not an email address, and re-runs the ladder"
    case "${SCOPE_IDENTITY:-}" in
      email)   hint="the email address your app signs the test user in with"; key=ITBL_EMAIL
               recorded="records ITBL_EMAIL, the identity the proof push is sent to" ;;
      user-id) hint="the user ID your app passes to setUserId() for the test user"; key=ITBL_USER_ID
               recorded="records ITBL_USER_ID, the identity the proof push is sent to" ;;
    esac
    printf ',"free_text":%s' "$(q_free_text "$hint" "$recorded" "$BIN/agent set $key={{answer}}")"
  fi
  # No recommendation on the steps that only the developer can judge: whether the click
  # landed is not something out here can know, and a tool nudging "done" from outside the
  # browser is inviting the one answer it cannot check. Where the answer is mechanical —
  # take this key, use this address — saying so is help rather than a nudge.
  printf ',"recommended":%s}' "$([[ "$rec" == null ]] && printf null || jstr "$rec")"
}

# ------------------------------------------------------ the same words, in a terminal
#
# bin/wizard used to carry its own wording for every one of these moments, so each screen
# existed twice with nothing keeping the two in step. The sign-in moment said "I never see
# your password — gcloud opens your browser and handles it" in the terminal and "You run
# it, your browser handles it" in a chat, and neither was the other's source. One set of
# words now, two renderers: an agent gets the JSON, a person gets this.
#
# Words and labels only. The options' `commands` stay the caller's to run, exactly as they
# are on the agent path — running them in here would move consent recording into a
# renderer, and the renderer is the one place in this tool with no business deciding
# anything.
#
# q_render <question-json> — the words, and nothing that waits for an answer.
#
# Separate from ask_question so "the terminal prints what the chat is handed" is an offline
# assertion. Joined to the menu it would need a pty, and a test that needs a pty to check a
# sentence is a test that ends up skipped — which is how the wording drifted unnoticed.
q_render() {
  local q="$1" prompt
  # Paragraphs arrive unwrapped on purpose — a chat window reflows them anyway — so the
  # width belongs to whoever is drawing. Wrapped here rather than with fold, which would
  # lose the indent on every continuation line.
  local wrap='
    const W = 76, pad = "  ", out = [];
    const wrap = s => {
      if (!s) { out.push(""); return; }
      let cur = "";
      for (const word of s.split(" ")) {
        if (cur && (cur + " " + word).length > W) { out.push(pad + cur); cur = word; }
        else cur = cur ? cur + " " + word : word;
      }
      if (cur) out.push(pad + cur);
    };'
  # The prompt's last line is the question; any lines before it are the steps it asks about.
  prompt="$(printf '%s' "$q" | jqn 'process.stdout.write((j.prompt||"").split("\n").pop())')"
  echo
  printf '%s' "$q" | jqn "$wrap"'
    const lead = (j.prompt || "").split("\n").slice(0, -1);
    while (lead.length && !lead[lead.length - 1]) lead.pop();
    lead.forEach(wrap);
    if (out.length) process.stdout.write(out.join("\n") + "\n\n");
  '
  [[ -n "$prompt" ]] && printf '  %s\n\n' "$(bold "$prompt")"
  printf '%s' "$q" | jqn "$wrap"'
    (j.context  || []).forEach(wrap);
    (j.requires || []).forEach(s => { out.push(""); wrap(s); });
    process.stdout.write(out.join("\n") + "\n\n");
  '
}

# ask_question <kind> [arg] — draw a screen, return which option came back.
# Sets ASK_LABEL and ASK_INDEX (1-based, in the order the screen lists them).
#   0  something was chosen     1  cancelled     2  no screen for that kind
ask_question() {
  local q l i=0
  # Cleared before anything can fail, because the caller reads them on every return and
  # config.sh runs under `set -u`: a return 2 that left them unset would take the wizard
  # down with it rather than letting it fall back to its own prompt.
  ASK_LABEL=""; ASK_INDEX=0
  q="$(question_for "$1" "${2:-}")" || return 2

  # Everything a person reads goes to stderr, because stdout is the answer — the same
  # split menu() keeps, and what lets a caller capture one without the other.
  q_render "$q" >&2

  local labels chosen
  labels="$(printf '%s' "$q" | jqn \
    'process.stdout.write((j.options||[]).map(o=>o.label).join("\n"))')"
  [[ -n "$labels" ]] || return 1
  chosen="$(printf '%s\n' "$labels" | menu)" || return 1

  while IFS= read -r l; do
    i=$((i + 1))
    [[ "$l" == "$chosen" ]] && { ASK_INDEX=$i; ASK_LABEL="$l"; return 0; }
  done <<< "$labels"
  return 1
}

# question_for <kind> [arg] — one question object on stdout, or rc 1 and nothing at all
# when the step at hand is not a question. Silence is the honest answer for the many
# kinds that are just work to do: an agent handed a question for `run_app` would go
# asking permission to read a log.
question_for() {
  case "${1:-}" in
    scope)            q_scope ;;
    scope_more)       q_scope_more ;;
    # Provisioning asks for the test identity the scope decides, so the scope comes first
    # even when an agent enters here instead of through the platform skill's preflight.
    opening)          if [[ -n "$(scope_gate)" ]]; then q_scope; else q_opening; fi ;;
    # Two kinds, one fork. next_action reports `run_in_terminal` when the developer is
    # the driver and `approve_firebase` when the agent is, because the terminal path
    # asks for consent in person and needs no agent to collect it. Asked in a chat
    # those are the same screen: who does the Google half, and do you agree to it —
    # and "I'll do it myself" is one of the answers, so it cannot be the branch that
    # decides which question gets asked.
    #
    # `authenticate` is the ladder's own name for this step; `sign_in` is what it reads
    # as. Both, so the kind out of next_action finds a screen without anything in between
    # having to translate.
    # The fork itself, reported while it is still unanswered. Same screen as the opening
    # one because it is the same question — a second, smaller version of it would be a
    # second wording to keep true, and the one that goes stale is whichever they read.
    choose_driver)    if [[ -n "$(scope_gate)" ]]; then q_scope; else q_opening; fi ;;
    sign_in|authenticate) q_sign_in ;;
    # The door, then the picker, and they are different questions: one asks whether the
    # listing may happen, the other shows what came back. next_action calls both
    # `choose_target`, because from the ladder's side it is one unfinished step — so the
    # cache decides which screen that is. No listing yet, ask to look; listing in hand,
    # ask which one. Asking to look at what has already been looked at is noise, and a
    # picker with nothing in it is an invitation to invent one.
    choose_target)
      if [[ -n "$PID" ]]; then
        # Project settled and package not — G4 and G13 both arrive here, and the
        # question left is which app, not which project. No apps to choose from means
        # the only way on is registering one, which is its own screen and its own yes.
        [[ -n "$PACKAGE" ]] && return 1
        q_pick_app || q_register_app
      else
        q_pick_project || q_choose_target
      fi ;;
    # The named project does not answer, and re-aiming is the remedy. Which screen that
    # is depends on what is on record: with a package too, the pair is worth showing
    # before it is changed; without one, the only honest offer is to look at what this
    # account can actually see.
    project_unreachable)
      if [[ -n "$PID" && -n "$PACKAGE" ]]; then q_keep_target
      else q_pick_project || q_choose_target; fi ;;
    pick_project)     q_pick_project ;;
    pick_app)         [[ -n "$PID" ]] || return 1; q_pick_app ;;
    register_app)     [[ -n "$PID" ]] || return 1; q_register_app ;;
    keep_target)      [[ -n "$PID" && -n "$PACKAGE" ]] || return 1; q_keep_target ;;
    pick_device)      q_pick_device ;;
    # Which device is a choice even when only one is attached, and the last point where
    # it can still be made cheaply. A phone left plugged in to charge resolves as "the
    # only device", takes the proof push, and the developer watching an emulator reports
    # that nothing arrived.
    #
    # After that the two part company. Building and installing is work, and work gets no
    # question. Running the app and answering the permission dialog is the developer's
    # hands or nobody's, so it stays a question to the end.
    install_app)
      [[ -n "${TARGET_DEVICE:-}" ]] && return 1
      q_pick_device ;;
    run_app)
      # The picker's own rc when nothing is attached: with no device there is no app
      # running on one, and asking whether they signed in on it would name nothing.
      [[ -n "${TARGET_DEVICE:-}" ]] || { q_pick_device; return; }
      q_run_app ;;
    approve_firebase) q_approve_firebase ;;
    # Only while the answer is outstanding. A recorded yes re-offered as a question
    # invites a second one, and the developer has no way to tell the first was kept.
    run_in_terminal)  approved && return 1; q_approve_firebase ;;
    iterable_keys)    q_iterable_entry ;;
    iterable_step)
      case "${2:-}" in
        1|2|3|4) q_iterable_step "$2" ;;
        *) return 1 ;;
      esac ;;
    *) return 1 ;;
  esac
}
