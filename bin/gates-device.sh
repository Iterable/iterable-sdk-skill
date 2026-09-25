#!/usr/bin/env bash
# Device-side gate bodies, sourced by bin/gates. Read-only over adb: none of these
# builds, installs, launches or sends anything. The developer's app is theirs.
#
# Every check here reads the *device*, never the source tree. The APK on the
# device is what receives the push; a local build directory proves nothing about
# what is installed, and that is exactly the false pass this tool exists to avoid.
#
# The two parsers live in bin/token-log.js and bin/notify-parse.js so the
# judgement can be tested against recorded output with no device attached.

# `dumpsys notification` prints extras as `String [length=18]` unless asked not to.
# Arrival and the channel are visible either way; content is not, and the parser
# says so rather than reading a redacted title as a failed marker match.
notification_dump() {
  local out
  out="$(adb -s "$1" shell dumpsys notification --noredact 2>/dev/null | tr -d '\r')"
  grep -q 'Notification List:' <<< "$out" && { printf '%s' "$out"; return 0; }
  adb -s "$1" shell dumpsys notification 2>/dev/null | tr -d '\r'
}

# G13 — the app installed on the device is a build that carries the SDK.
#
# "It builds" is not the claim worth making: a developer who integrates the SDK
# and then forgets to reinstall has a green build and a device that resolves no
# Iterable components at all. PackageManager knows which it is.
g13() {
  local d dump ver updated sdk perm
  # Every way device_serial can fail is a human-action state — attach one, start the
  # AVD, or pick between two — so it is pending here and in G14/G16, not a defect.
  d="$(device_serial)" || { echo "$d"; return 2; }
  [[ -n "$PACKAGE" ]] || { echo "no package selected yet — nothing has named the app this is about"; return 2; }

  adb -s "$d" shell pm path "$PACKAGE" 2>&1 | grep -q '^package:' \
    || { echo "$PACKAGE is not installed on $d — build and install it (./gradlew installDebug)"; return 1; }

  dump="$(adb -s "$d" shell dumpsys package "$PACKAGE" 2>&1 | tr -d '\r')"
  ver="$(sed -n 's/.*versionName=\([^ ]*\).*/\1/p' <<< "$dump" | head -1)"
  updated="$(sed -n 's/.*lastUpdateTime=\(.*\)/\1/p' <<< "$dump" | head -1)"

  grep -q 'com\.iterable\.iterableapi\.IterableFirebaseMessagingService' <<< "$dump" \
    || { echo "installed v$ver resolves no Iterable messaging service — this APK predates the integration, reinstall"; return 1; }

  # POST_NOTIFICATIONS is a runtime permission from API 33. Denied and never-asked
  # both read `granted=false`, and they are not the same thing: USER_SET means
  # somebody answered the dialog, so only that one is a decision we can report.
  sdk="$(adb -s "$d" shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\r')"
  if [[ "$sdk" =~ ^[0-9]+$ ]] && ((sdk >= 33)); then
    grep -q 'android\.permission\.POST_NOTIFICATIONS' <<< "$dump" \
      || { echo "v$ver installed, but POST_NOTIFICATIONS is not declared — Android $sdk will not show the push"; return 1; }
    perm="$(grep 'android\.permission\.POST_NOTIFICATIONS: granted=' <<< "$dump" | head -1)"
    if grep -q 'granted=false' <<< "$perm"; then
      grep -q 'USER_SET' <<< "$perm" \
        && { echo "POST_NOTIFICATIONS denied — the push will arrive and never be shown"; return 1; }
      echo "v$ver installed, POST_NOTIFICATIONS not asked yet — run the app and accept the prompt"
      return 2
    fi
  fi

  echo "v$ver on $d, installed $updated, Iterable service resolves"
}

# G14 — the device got an FCM token and Iterable accepted it.
#
# The evidence is the log buffer, which rotates: this gate can prove registration
# happened but can never prove it didn't, so "no Iterable output at all" is
# pending, not red. What it *can* call red is the SDK running and never asking.
g14() {
  local d buf out rc scoped started=$SECONDS deadline=$((SECONDS + DEVICE_WAIT))
  d="$(device_serial)" || { echo "$d"; return 2; }
  while :; do
    # Dumped first, not piped: under pipefail a failing adb would overwrite the
    # parser's verdict with its own exit code.
    #
    # Narrowed to the app's uid, because every app shares one log buffer and the
    # SDK's lines are identical whoever emitted them — another app's successful
    # registration would otherwise turn this gate green for an app that has never
    # run. Where the device cannot narrow it, the unscoped read is still the best
    # evidence there is, and the verdict says which kind it is.
    if buf="$(logcat_for_package "$d")"; then scoped=1; else
      buf="$(adb -s "$d" logcat -d 2>/dev/null)" || true; scoped=0
    fi
    out="$(printf '%s\n' "$buf" | node "$BIN/token-log.js" "$PACKAGE" 2>&1)"; rc=$?
    ((scoped)) || out="$out (whole log — could not narrow it to $PACKAGE)"
    ((rc == 3)) || break
    # Nothing to wait for when the app has no key to register with.
    [[ -n "$ITBL_MOBILE_KEY" ]] || break
    ((SECONDS < deadline)) || break
    sleep 3
  done
  # "Ran and never registered", with nothing in the log to say why. Two things cause
  # it, and both are work outstanding in the developer's own app rather than a fault in
  # anything this tool built: no mobile key yet, or no user identified. So it is pending
  # either way, and only the reason changes.
  #
  # It used to go red at the deadline, and that is how a developer whose app simply
  # never calls setEmail got SOMETHING IS ACTUALLY WRONG about an integration that was
  # fine. Nothing here can tell that apart from setAutoPushRegistration(false), so it
  # does not get to call either one a defect — rc 4 is the case that is.
  if ((rc == 3)); then
    if [[ -z "$ITBL_MOBILE_KEY" ]]; then
      echo "$out — and no Iterable mobile key yet, so there is probably nothing to register with"
    else
      echo "$out — after $((SECONDS - started))s"
    fi
    return 2
  fi
  # Firebase logged an error and the SDK never asked. That error is the answer.
  ((rc == 4)) && { echo "$out"; return 1; }
  echo "$out"
  return $rc
}

# G16 — the push appeared on the device. The one gate the whole tool is for.
g16() {
  local d dump
  d="$(device_serial)" || { echo "$d"; return 2; }
  dump="$(notification_dump "$d")" || true
  printf '%s\n' "$dump" \
    | node "$BIN/notify-parse.js" "$PACKAGE" "$ITBL_PROOF_MARKER" "$ITBL_PROOF_SENT_AT" 2>&1
}
