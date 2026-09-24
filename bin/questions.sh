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
  echo "You need a google-services.json and the Iterable side set up. Neither can be invented, so this is the part that produces them — and none of it starts until you say so."
  echo ""
  part_map | plain | sed 's/^  //' | sed '/^$/d'
  echo ""
  echo "What it reads: your Firebase projects and the Android apps in each, your app's build files, and a connected device or emulator. Reading happens with the gcloud account you are already signed in as."
  echo ""
  echo "What it changes in your Google project: nothing yet. When it gets there you are asked again, on a screen that lists every change by name, and no is a complete answer to it."
  echo ""
  echo "What it never does: ask for a password, take an API key through this conversation, or write a placeholder google-services.json to make a build go green. If something is missing it says so and stops."
  echo ""
  echo "Part 2 is yours because Iterable has no API for it — no endpoint creates an API key, a mobile app, or a push integration. I walk you through those four steps and check what each one produced."
}

q_opening() {
  local here="Yes — set it up with me here"
  printf '{"header":"Setup","prompt":%s,' \
    "$(jstr "Do you wish to proceed?")"
  printf '"context":%s,' "$(q_opening_context | q_arr)"
  printf '"requires":%s,' "$(q_arr <<'EOF'
You sign in to Google yourself. If 'gcloud auth login' has not been run in your terminal, that is the first thing you do, and neither this tool nor the agent ever sees your password.
EOF
)"
  printf '"recommended":%s,' "$(jstr "$here")"
  printf '"options":['
  # Records the driver, and that is not bookkeeping. A chat has no tty, so provisioning
  # refuses to run from one unless the choice is on disk — say yes here without recording
  # it and the run walks up to the first change and hands the developer a terminal block,
  # which is the answer they just declined.
  q_opt "$here" \
    "I conduct the whole thing here: every screen the terminal wizard shows, as a question in this conversation. Nothing changes without its own yes first, and the two Iterable API keys go from your clipboard into a 0600 file without passing through this conversation — I never see one." \
    "DRIVER=agent recorded; ladder read; nothing changed" "" \
    "$BIN/agent set DRIVER=agent" "$BIN/agent"
  printf ','
  q_opt "I'd rather run the whole setup in my own terminal" \
    "Fallback, and a real one: the same work and the same questions as a terminal menu, with the Google sign-in hosted in the same session and every prompt answered by arrow keys instead of by relaying. Worth it if you would rather these choices were not in a chat at all." \
    "DRIVER=developer recorded; the block to follow is printed" "" \
    "$BIN/agent set DRIVER=developer" "$BIN/handoff"
  printf ','
  q_opt "No — stop here" \
    "Nothing runs, nothing is read, and nothing is written — not even a workspace directory in your repository." \
    "nothing read; nothing written" ""
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
  echo "To find the project this app belongs to, I need to list the Firebase projects your gcloud account can see, and the Android apps registered in each."
  echo ""
  echo "That is a read. It writes nothing, creates nothing, and changes nothing — and it is the first thing here that uses your Google credentials at all."
  echo ""
  echo "What comes back is project names, ids and package names. If any of that is not something you want in this conversation, take the second option and name the project yourself."
  echo ""
  echo "Changing anything is a separate question, asked later, with the list of changes in it. This is not that question."
}

# The one screen that writes something when it is rendered, and the reason is in the
# command below: a one-time token, so the yes cannot be recorded by anybody who never put
# this in front of the developer. Every other question here touches no state at all.
q_choose_target() {
  local look="Yes — list my Firebase projects" tok
  tok="$(ask_for choose_target)" || tok=""
  printf '{"header":"Discover","prompt":%s,' \
    "$(jstr "May I look at your Firebase projects?")"
  printf '"context":%s,' "$(q_look_context | q_arr)"
  printf '"requires":%s,' "$(q_approve_requires | q_arr)"
  printf '"recommended":%s,' "$(jstr "$look")"
  printf '"options":['
  # Two commands, and the first one is the point: the read refuses until a yes is on
  # disk, so this option is how the listing becomes possible at all rather than a
  # convenience wrapper around a command that would have worked anyway. The token is the
  # only place it appears, and it is spent the first time it is used.
  q_opt "$look" \
    "Lists the projects and their registered Android apps, so a project that already has your package can be offered — that is the path that creates nothing." \
    "reads your project and app list; writes nothing" "" \
    "$BIN/agent approve list --asked $tok" "$BIN/agent discover"
  printf ','
  q_opt "No — I'll name the project myself" \
    "Nothing gets listed. Tell me the Firebase project id and the Android package, and they get recorded as your choice." \
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
  local relay="Show me the command to run"
  printf '{"header":"Sign in","prompt":%s,' "$(jstr "Ready to sign in to Google?")"
  printf '"context":%s,' "$(q_arr <<'EOF'
Nothing here can read your Google projects until gcloud has a session, and that sign-in is yours: it opens your own browser, and neither this tool nor I ever see the password.

One command in your terminal, then come back and say so. If you are already signed in as the right account, take the second option and I will check rather than ask again.
EOF
)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$(jstr "$relay")"
  printf '"options":['
  q_opt "$relay" \
    "You run it, your browser handles it. Come back when it says you are signed in." \
    "nothing changed; waiting for you to sign in" "gcloud auth login"
  printf ','
  q_opt "I'm already signed in — check again" \
    "Re-reads the ladder. If the session is there this stops being asked; if it is not, the first step is still this." \
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
  printf '{"header":"Target","prompt":%s,' "$(jstr "Still the same project and app?")"
  printf '"context":%s,' "$(q_arr <<EOF
Already on record from an earlier run:

project   $PID
package   $PACKAGE

Everything from here on reads and changes that project and no other, so it is worth a look before it is spent. Changing it now costs nothing — nothing has been provisioned against it yet.
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
    "Lists your projects again and asks which one. Anything derived from the old choice is dropped, so no check can come back green about the previous app." \
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
# Ranked so the zero-mutation answer is the first thing read: a project that already has
# this package needs nothing created in it at all.
ranked_projects() {
  [[ -s "$WS/discovered.json" ]] || return 1
  PKG="${PACKAGE:-}" node -e '
    let s=""; process.stdin.on("data", d => s += d).on("end", () => {
      const want = process.env.PKG || "", d = JSON.parse(s);
      const tier = p => (p.apps || []).some(a => a.package === want) ? 0 : ((p.apps || []).length ? 1 : 2);
      (d.projects || []).map((p, i) => ({ p, i, t: tier(p) }))
        .sort((a, b) => a.t - b.t || a.i - b.i)
        .forEach(({ p, t }) => console.log([
          p.id, p.name || "", (p.apps || []).length, t === 0 ? 1 : 0,
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
    echo "One of them already has $PACKAGE registered, and it is first. That is the path where nothing gets created on the Firebase side at all — the app already exists, so its google-services.json is a download."
  elif ((matched > 1)); then
    echo "$matched of them already have $PACKAGE registered, shown first. Picking one of those means nothing gets created on the Firebase side at all — the app already exists, so its google-services.json is a download. Which of them is yours is something only you know."
  elif [[ -n "$PACKAGE" ]]; then
    echo "None of them has $PACKAGE registered yet, so whichever you pick, the app has to be registered in it — and that is asked separately, before anything is created."
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
    echo "$((n - Q_PICK_MAX)) more not shown. If the one you want is missing, type its project id — the id, not the display name."
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
        "${name:-$id} — already has $PACKAGE registered, so nothing is created here. This is the cheapest and safest answer if it is the right project." \
        "project recorded as $id, package as $PACKAGE; ladder re-read" "" \
        "$BIN/agent set PID=$id PACKAGE=$PACKAGE" "$BIN/agent"
    elif ((napps > 0)); then
      q_opt "$id" \
        "${name:-$id} — has $(plz "$napps" "registered app" "registered apps"): $pkgs. I will ask which one this is." \
        "project recorded as $id; the app picker comes next" "" \
        "$BIN/agent set PID=$id" "$BIN/agent question pick_app"
    else
      q_opt "$id" \
        "${name:-$id} — no Android app registered yet, so one has to be created in it. That gets its own question before anything happens." \
        "project recorded as $id; registering an app is asked next" "" \
        "$BIN/agent set PID=$id" "$BIN/agent question register_app"
    fi
  done <<< "$rows"
  printf ','
  q_opt "None of these — I'll give you the project id" \
    "Type it and I record it as your choice. Use the project id, which is lowercase with hyphens; the display name is not it." \
    "nothing recorded yet; waiting for a project id" ""
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "the Firebase project id, lowercase with hyphens" \
    "records it as the project everything from here on reads and changes" \
    "$BIN/agent set PID={{answer}}")"
}

q_pick_app_context() { # <rows>
  local n; n="$(printf '%s\n' "$1" | grep -c .)"
  echo "$PID has $(plz "$n" "Android app" "Android apps") registered. Which of them is the app in this repository?"
  echo ""
  echo "This has to be the applicationId your build actually ships. A google-services.json downloaded for a different package is accepted by the build and then fails at runtime, where the error names Firebase rather than the mismatch — so it is worth checking against build.gradle rather than recognising the name."
  if ((n > Q_PICK_MAX)); then
    echo ""
    echo "$((n - Q_PICK_MAX)) more not shown — type the package if it is not listed."
  fi
}

q_pick_app() {
  local rows sep="" i=0 pkg appid
  rows="$(apps_of_chosen)" || return 1
  [[ -n "$rows" ]] || return 1

  printf '{"header":"App","prompt":%s,' "$(jstr "Which Android app is this one?")"
  printf '"context":%s,' "$(q_pick_app_context "$rows" | q_arr)"
  printf '"requires":[],'
  printf '"recommended":null,'
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
    "Registering an app changes your Firebase project, so it is asked outright on the next screen rather than done here." \
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
      echo "$PID has no Android app that matches this repository, and I do not have the package name yet."
    else
      echo "Nothing has listed $PID's Android apps yet, and I do not have this repository's package name either — so I cannot tell you whether one already exists."
    fi
    echo ""
    echo "Type the applicationId from your build.gradle and I will ask again with it named."
    return 0
  fi
  if ! listed_project; then
    echo "Nothing has listed $PID's apps, so I cannot tell you whether $PACKAGE is already registered there. Reading the list first costs one call and changes nothing; asking you to approve a creation on an unchecked guess would be asking for the wrong thing."
    return 0
  fi
  echo "$PID has no Android app for $PACKAGE, so there is no google-services.json to download for it. Registering one is the only honest way forward: a placeholder file makes the build pass and the push never arrive."
  echo ""
  echo "This is a change to your Firebase project — the one change this tool promises never to make unless you ask for it outright. This is that asking."
  echo ""
  echo "What it would create:"
  echo "  · one Android app in $PID, package $PACKAGE, display name $APP_DISPLAY_NAME"
  echo ""
  echo "Nothing else, and nothing existing is touched. It is removable in the Firebase console afterwards; $BIN/teardown does not remove it, because it is your app rather than something this tool needs."
}

q_register_app() {
  local yes="Yes — register $PACKAGE in $PID" prompt="Register this Android app in $PID?"
  # The listing is also what makes "pick a different project" a working answer: with no
  # cache behind it the picker has nothing to draw, so that option has to fetch first.
  local -a back=("$BIN/agent question pick_project")
  listed_project || back=("$BIN/agent discover" "$BIN/agent question pick_project")
  listed_project || [[ -z "$PACKAGE" ]] || prompt="Look before creating anything in $PID?"
  printf '{"header":"New app","prompt":%s,' "$(jstr "$prompt")"
  printf '"context":%s,' "$(q_register_app_context | q_arr)"
  printf '"requires":[],'
  printf '"recommended":null,'
  printf '"options":['
  if [[ -n "$PACKAGE" ]] && ! listed_project; then
    q_opt "Check whether it already exists first" \
      "Lists the Android apps in $PID. If $PACKAGE is among them nothing needs creating at all — its google-services.json is a download." \
      "nothing created; the apps listed, then this asked again with an answer behind it" "" \
      "$BIN/agent discover" "$BIN/agent question pick_app"
  elif [[ -n "$PACKAGE" ]]; then
    q_opt "$yes" \
      "Records the yes against $PID and nothing more — the app is created by the provisioning step, which asks for its own approval first." \
      "app registration approved for $PID; ladder re-read" "" \
      "$BIN/agent approve create-app" "$BIN/agent"
  else
    q_opt "I'll give you the package name" \
      "Type the applicationId from build.gradle. Nothing is created by telling me — this screen comes back with the package named, and the yes is still yours to give." \
      "nothing approved; waiting for a package name" ""
  fi
  printf ','
  q_opt "No — let me pick a different project" \
    "Back to the list. A project that already has this app registered needs nothing created at all." \
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
  echo "Part 3 lands a real push on a real device and reads the device's own notification records to prove it arrived. Every check from here on reads the one you pick, so it should be the one you are watching."
  echo ""
  echo "An emulator that is not running can still be chosen — it gets started. A physical phone needs to be plugged in and authorised for adb."
}

q_pick_device() {
  local rows sep="" i=0 name rest
  rows="$(device_options 2>/dev/null)"
  [[ -n "$rows" ]] || return 1
  printf '{"header":"Device","prompt":%s,' "$(jstr "Which device should the push be proved on?")"
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
      "not running"*) desc="Not running yet. Choosing it starts it — that is part of the check, not something to do first." ;;
      *"·"*)          desc="Plugged in and running: ${rest##*· }. A real handset is the strongest proof available." ;;
      *)              desc="Running now, so the checks can read it as soon as your app is installed." ;;
    esac
    q_opt "$name" "$desc" \
      "device recorded as $name; ladder re-read" "" \
      "$BIN/agent set TARGET_DEVICE=$name" "$BIN/agent"
  done <<< "$rows"
  printf ','
  q_opt "None of these" \
    "Start the emulator you want, or plug the phone in and authorise it, then say so and I will look again." \
    "nothing recorded; waiting for a device" ""
  printf '],'
  printf '"free_text":%s}' "$(q_free_text \
    "an AVD name, or the adb serial of a phone" \
    "records which device the push gets proved on" \
    "$BIN/agent set TARGET_DEVICE={{answer}}")"
}

# ------------------------------------------------------- part 1: the Google consent
#
# The same two lists the terminal banner prints, from the same two functions. A second
# copy would be a second thing to keep true, and the one that goes stale is whichever
# the developer happens to be reading.
q_approve_context() {
  echo "Setting up the Google half changes your own Cloud project, so it needs your yes first. Nothing has happened yet."
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
  echo "The JSON key it creates is a long-lived credential until you delete it. Everything it adds comes back out with $BIN/teardown."
}

# Named only while it is still outstanding. A prerequisite listed after it has been met
# reads as a step the developer still owes, on the one screen where the whole point is
# an accurate account of what is about to happen.
q_approve_requires() {
  [[ "$(gate_status G1)" == green ]] && return 0
  echo "You sign in to Google yourself: run 'gcloud auth login' in your own terminal. Neither this tool nor the agent ever sees your password."
}

q_approve_firebase() {
  # The recommendation comes out of the same variable as the label it points at, because
  # a recommendation naming an option that has since been reworded recommends nothing.
  # It follows the driver they already chose, and this screen is only reached once they
  # have: unanswered, the ladder reports choose_driver and the opening screen asks. So the
  # recommendation here is "carry on the way you said", not an opinion about which is better.
  local manual="No — I want to do this manually" yes="Yes — the tool does it, and I agree"
  printf '{"header":"Firebase","prompt":%s,' \
    "$(jstr "Do you wish to proceed?")"
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
    "Records your yes against ${PID:-this project} and hands the Google steps to your agent. Only the changes listed above, and nothing already working gets redone." \
    "approval recorded against ${PID:-<no project>}; DRIVER=agent recorded" "" \
    "$BIN/agent approve firebase" "$BIN/agent set DRIVER=agent" "$BIN/agent"
  printf ','
  q_opt "$manual" \
    "Fallback: you run the same setup in your own terminal, which is the one path that can host the Google sign-in in the same session instead of relaying it." \
    "nothing approved; DRIVER=developer recorded; the block to follow is printed" "" \
    "$BIN/agent set DRIVER=developer" "$BIN/handoff"
  printf ','
  q_opt "Abort the setup" \
    "Nothing is recorded and nothing in your project changes. Coming back later costs nothing — the ladder re-reads everything from scratch." \
    "nothing recorded; no calls made" ""
  printf ']}'
}

# ------------------------------------------------------ part 2: the Iterable walk
q_iterable_context() {
  echo "Part 1 is done and verified: the service-account key exists, and FCM accepted it."
  echo ""
  echo "Part 2 is four steps in the Iterable dashboard, in your browser — Iterable has no API for creating an API key, a mobile app, or a push integration, so there is nothing out here that can do them for you."
  echo ""
  echo "About five minutes. One step at a time, and each one is checked by what it produced."
  echo ""
  echo "The keys never come through this conversation. You copy one in the dashboard and I take it off your clipboard straight into a 0600 file, then clear the clipboard — nothing prints it back. A key pasted into a chat is in a transcript and in every log along the way, and that cannot be undone."
  echo ""
  echo "Until they are in, your app has no mobile key, so the device checks have nothing to find. That is all the unfinished rows are saying, and none of it is a fault in your app."
}

q_iterable_entry() {
  local start="Start — step 1 of 4"
  printf '{"header":"Iterable","prompt":%s,' \
    "$(jstr "Start the four Iterable steps now?")"
  printf '"context":%s,' "$(q_iterable_context | q_arr)"
  printf '"requires":[],'
  printf '"recommended":%s,' "$(jstr "$start")"
  printf '"options":['
  q_opt "$start" \
    "I show step 1, you click, and the keys go from your clipboard into the 0600 file. Somebody on step 2 wants step 2, not all four at once." \
    "walk entered at step 1; nothing recorded yet" "" \
    "$BIN/iterable-keys --step 1" "$BIN/agent question iterable_step 1"
  printf ','
  # Asked here rather than on a screen of its own, because it is one word of an answer
  # and the wrong one is expensive: a US key against the EU host comes back 401, which
  # is indistinguishable from a bad key and sends everybody looking at the wrong thing.
  q_opt "Start — and this is an EU (EDC) project" \
    "Same walk, against api.eu.iterable.com. Pick this if you sign in at app.eu.iterable.com: a key from one data centre returns 401 against the other, and that reads exactly like a wrong key." \
    "ITBL_BASE recorded as the EU host; walk entered at step 1" "" \
    "$BIN/agent set ITBL_BASE=https://api.eu.iterable.com" \
    "$BIN/iterable-keys --step 1" "$BIN/agent question iterable_step 1"
  printf ','
  q_opt "I'll run the walk in my own terminal" \
    "Fallback: the same four steps as a terminal walk, which takes both keys with the echo off instead of off the clipboard. It ends by running the ladder." \
    "walk handed to the developer's terminal; the agent waits" \
    "$(cmd_path iterable-keys)"
  printf ','
  q_opt "Not now — tell me where I stand" \
    "The walk stays unstarted and you get the ladder as it is. Nothing here expires." \
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
q_step_context() {
  # The step itself, not a reference to one. This used to open with "the block above is
  # step N" — an assertion about output a *second* command had to have produced first, and
  # an option carrying two commands is an ordering an agent can get wrong. Run only the
  # question and the developer gets the right choices with no instructions above them, and
  # a line pointing at a block that was never printed. So one call carries both, and the
  # cheapest thing to do is also the whole screen.
  # Dedented by two, because the terminal's left margin inside a chat message is just a
  # ragged edge; the leading blank goes because q_arr keeps every line it is given.
  "$BIN/iterable-keys" --step "$1" --relay 2>/dev/null | plain | sed 's/^  //' \
    | sed '1{/^[[:space:]]*$/d;}'
  echo "Show the clicks above as they came out, values and all — the exact strings matter here, and a shortened version of this step is the most expensive mistake in the whole setup."
  if (( $1 == 1 )); then
    echo ""
    echo "Do not ask for either key, and do not read the clipboard yourself — pbpaste and its kin are off limits here. --take is what moves a key, and it is the only thing in this tool that ever holds one."
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
    4) [[ -n "$ITBL_EMAIL" ]] \
         && prompt="The test identity is $ITBL_EMAIL. Prove the whole thing now?" \
         || prompt="What address does your app sign in as?" ;;
  esac
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
        "I read it off your clipboard into $(wsp .env) at mode 0600, clear the clipboard, and print nothing but a tick. If what is on the clipboard is not a key, it says so without quoting it." \
        "ITBL_SERVER_KEY stored in .env (0600); clipboard cleared" "" \
        "$BIN/iterable-keys --take server" "$BIN/agent question iterable_step 1"
      sep=","
    fi
    if [[ -z "$have_mobile" ]]; then
      printf '%s' "$sep"; sep=","
      [[ -n "$have_server" ]] && rec="Mobile key — take it"
      q_opt "Mobile key — take it" \
        "Same thing for the key your app ships with. Copy it first: Iterable shows each key once, and this reads whatever is on the clipboard right now." \
        "ITBL_MOBILE_KEY stored in .env (0600); clipboard cleared" "" \
        "$BIN/iterable-keys --take mobile" "$BIN/agent question iterable_step 1"
    fi
    if [[ -n "$have_server" && -n "$have_mobile" ]]; then
      rec="Both are in — step 2"
      q_opt "$rec" \
        "Both keys are in the 0600 file. They get spent on a real Iterable call at the end, so this is not where they are declared correct." \
        "walk advanced to step 2; keys stored but not yet proved" "" \
        "$BIN/iterable-keys --step 2" "$BIN/agent question iterable_step 2"
      sep=","
    fi
    printf '%s' "$sep"
    q_opt "Show step 1 again" \
      "The step is printed again, unchanged, with the two lines that take a key. Nothing is skipped past: a key that never arrives surfaces later as a push that never sends." \
      "step 1 still open" "" \
      "$BIN/iterable-keys --step 1"
  elif ((n < 4)); then
    rec="Done — next step"
    q_opt "$rec" \
      "Moves the walk on. Your word is what advances it; the gates still prove this step later by spending what it produced." \
      "walk advanced to step $next; nothing verified yet" "" \
      "$BIN/iterable-keys --step $next" "$BIN/agent question iterable_step $next"
    printf ','
    q_opt "It doesn't look like that" \
      "The step is printed again, unchanged, and stays open. Only this step gets help — the dashboard moves, the values and their meanings do not. Nothing gets skipped past: a step marked done that was not done surfaces much later as a broken integration." \
      "step $n still open" "" \
      "$BIN/iterable-keys --step $n"
  else
    # The identity is not a secret, so unlike the keys it can be said out loud — and the
    # free-text answer is the point of this screen. The device knows it already when the
    # app has run and identified anybody, and offering that is how a mismatch between the
    # two gets caught here rather than three gates later.
    local seen; seen="$(app_identity 2>/dev/null | head -1)"
    if [[ -n "$ITBL_EMAIL" ]]; then
      rec="Done — now prove it"
      q_opt "$rec" \
        "Both keys get spent on a real Iterable call and $ITBL_EMAIL is looked up by name, so nothing in the last four steps is taken on trust." \
        "walk complete; ladder re-run to verify all four steps" "" \
        "$BIN/onboard"
      printf ','
      q_opt "That is the wrong address" \
        "Type the right one below. It has to be the value the app passes to setEmail(), character for character — if they disagree, the token is filed under one user and the push goes to another." \
        "ITBL_EMAIL stays as it is until you give another" ""
    elif [[ -n "$seen" ]]; then
      rec="Use $seen"
      q_opt "$rec" \
        "This is what the app on the device actually registered as — read out of its own registerDeviceToken call, so it matches by construction." \
        "ITBL_EMAIL recorded as $seen" "" \
        "$BIN/agent set ITBL_EMAIL=$seen" "$BIN/onboard"
      printf ','
      q_opt "Show step 4 again" \
        "The step is printed again, with whatever identities the device has registered." \
        "step 4 still open" "" \
        "$BIN/iterable-keys --step 4"
    else
      q_opt "Show step 4 again" \
        "The step is printed again, unchanged. The address goes in below, or on ITBL_EMAIL in the 0600 file." \
        "step 4 still open" "" \
        "$BIN/iterable-keys --step 4"
      printf ','
      # The way out for somebody who does not know the answer yet — the app may not sign
      # anyone in at all. Everything up to here still gets proved; the identity gate says
      # what is missing, which is a better place to be stuck than on a screen with no exit.
      q_opt "I don't know it yet — read the ladder" \
        "Runs the checks on what is done. The keys still get spent for real; the test-identity row stays open and says so, rather than this screen holding everything up." \
        "ITBL_EMAIL left unset; ladder re-read" "" \
        "$BIN/onboard"
    fi
  fi
  printf ','
  q_opt "I'd rather run the rest myself" \
    "Fallback: the whole walk in your own terminal, with both keys typed where the echo is off. Anything already in the 0600 file is kept." \
    "walk handed to the developer's terminal at step $n; the agent waits" \
    "$(cmd_path iterable-keys)"
  printf ']'
  # Only where the answer is a value the developer types, and never for a key. The
  # identity is an email address and belongs in the open; a key put here would be a key
  # in the transcript, which is the one thing this walk is arranged to avoid.
  if ((n == 4)); then
    printf ',"free_text":%s' "$(q_free_text \
      "the address your app signs in with, e.g. dogshelter.test@example.com" \
      "records ITBL_EMAIL and re-runs the ladder" \
      "$BIN/agent set ITBL_EMAIL={{answer}}")"
  fi
  # No recommendation on the steps that only the developer can judge: whether the click
  # landed is not something out here can know, and a tool nudging "done" from outside the
  # browser is inviting the one answer it cannot check. Where the answer is mechanical —
  # take this key, use this address — saying so is help rather than a nudge.
  printf ',"recommended":%s}' "$([[ "$rec" == null ]] && printf null || jstr "$rec")"
}

# question_for <kind> [arg] — one question object on stdout, or rc 1 and nothing at all
# when the step at hand is not a question. Silence is the honest answer for the many
# kinds that are just work to do: an agent handed a question for `run_app` would go
# asking permission to read a log.
question_for() {
  case "${1:-}" in
    opening)          q_opening ;;
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
    choose_driver)    q_opening ;;
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
    # that nothing arrived. Once one is on record this is work rather than a question.
    install_app|run_app)
      [[ -n "${TARGET_DEVICE:-}" ]] && return 1
      q_pick_device ;;
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
