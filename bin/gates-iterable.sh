#!/usr/bin/env bash
# Iterable-side gate bodies, sourced by bin/gates. Read-only, like the rest of
# the verifier: every check spends a real key against a real endpoint, and none
# of them create or modify anything in the Iterable project.
#
# Three steps in this half have no read-back at all — creating API keys, creating
# the mobile app, and configuring the push integration. Iterable's public API has
# no endpoint for any of them (checked against all 131 paths in
# https://api.iterable.com/api-docs). The ladder says so out loud rather than
# reading a local file and calling it a gate.

# G10 — both keys authenticate against the endpoints they are actually for.
#
# The two key types are not interchangeable, and swapping them is a common
# mistake: a mobile key on /api/channels and a server key on registerDeviceToken
# both return 401, so this catches the swap in either direction.
g10() {
  # The remedy belongs in the message: this gate is owned by a human, and "not
  # captured yet" without the command to fix it makes them go looking.
  # rc 2: a key nobody has created yet is pending work, not a broken project.
  [[ -n "$ITBL_SERVER_KEY" ]] || { echo "no server-side key yet — the Iterable dashboard steps create it"; return 2; }
  [[ -n "$ITBL_MOBILE_KEY"  ]] || { echo "no mobile key yet — the Iterable dashboard steps create it"; return 2; }

  local out push
  itbl_get "$ITBL_SERVER_KEY" /api/channels || true
  out="$(classify_itbl_response "$ITBL_CODE" "$ITBL_BODY")" \
    || { echo "server key: $out"; return 1; }
  # A Push channel is not proof of *your* integration — nothing in the public API
  # is — but zero of them means the project cannot send push at all.
  push="$(printf '%s' "$ITBL_BODY" | jqn 'process.stdout.write(
    String((j.channels||[]).filter(c=>c.messageMedium==="Push").length))')"
  [[ "$push" == 0 ]] && { echo "server key ok, but the project has no Push channel"; return 1; }

  # Deliberately empty body: proves the key authenticates without registering a
  # device. Iterable answers 401 for a bad key and 400 for a bad payload, so the
  # two outcomes are distinguishable — and the control below proves that holds.
  itbl_post "$ITBL_MOBILE_KEY" /api/users/registerDeviceToken '{}' || true
  out="$(classify_itbl_response "$ITBL_CODE" "$ITBL_BODY" auth-only)" \
    || { echo "mobile key: $out"; return 1; }

  # Negative control. If a key we know is invalid produces the same answer as the
  # real one, the probe above proves nothing — and a gate that cannot fail is
  # worse than no gate. Better to go red on "I can't tell" than to pass.
  itbl_post "itbl-onboard-deliberately-invalid-key" /api/users/registerDeviceToken '{}' || true
  case "$ITBL_CODE" in
    401|403) ;;
    *) echo "probe not discriminating: an invalid key also answers $ITBL_CODE"; return 1 ;;
  esac

  echo "server key ok ($push push channel(s)), mobile key ok, control 401"
}

# G15 — the device token reached Iterable and is enabled for our package.
#
# Iterable's own docs send you to Audience > User Lookup for this; the same data
# is on the user profile, so it needs no dashboard.
g15() {
  [[ -n "$ITBL_EMAIL" ]] || { echo "no test user set (ITBL_EMAIL)"; return 1; }
  local out
  itbl_get "$ITBL_SERVER_KEY" "/api/users/getByEmail?email=$(urlenc "$ITBL_EMAIL")" || true
  # "No user exists" is neither a defect nor a bad key: the app has not run and
  # registered a token yet. Gate rule 2 — a not-yet state reported as a failure
  # blames the customer for work that is merely pending. Returns 2, not 1.
  # The other reading of the same answer, and the more common one: the app signs in
  # as somebody else. Naming both is the difference between a next step and a
  # mystery, and nothing on this side can tell them apart.
  if [[ "$ITBL_CODE" == 400 ]] && grep -qi 'no user exists' <<< "$ITBL_BODY"; then
    echo "no user yet — nothing has registered $ITBL_EMAIL (is that what the app signs in as?)"
    return 2
  fi
  out="$(classify_itbl_response "$ITBL_CODE" "$ITBL_BODY")" || { echo "$out"; return 1; }

  printf '%s' "$ITBL_BODY" | node -e '
    let d=""; process.stdin.on("data",c=>d+=c).on("end",()=>{
      const want = process.argv[1];
      let j; try { j = JSON.parse(d||"{}") } catch (e) { console.error("unparseable response"); process.exit(1) }
      const u = j.user;
      if (!u) { console.error("no such user in this project"); process.exit(2) }
      // Exit 2 = not yet, exit 1 = wrong. "No device registered" is the app not
      // having run; a device that exists but is disabled is a misconfiguration.
      const devices = u.dataFields?.devices ?? u.devices;
      if (!Array.isArray(devices)) { console.error("user exists, no devices registered yet"); process.exit(2) }
      const mine = devices.filter(v => v.appPackageName === want || v.applicationName === want);
      if (!mine.length) {
        console.error(`no device for ${want} yet (${devices.length} device(s) for other apps)`);
        process.exit(2);
      }
      // endpointEnabled false is the quiet killer: the token is registered, so
      // everything looks fine, and Iterable will never send to it.
      const live = mine.filter(v => v.endpointEnabled === true);
      if (!live.length) { console.error(`device for ${want} has endpointEnabled=false`); process.exit(1) }
      console.log(`${live.length} enabled device(s) for ${want}`);
    })' "$(itbl_integration)" 2>&1
}

# G17 — Iterable agrees it sent the push. Corroborates G16 from the server side:
# the device saying it arrived and Iterable saying it sent are separate claims.
g17() {
  [[ -n "$ITBL_EMAIL" ]] || { echo "no test user set (ITBL_EMAIL)"; return 1; }
  local out
  itbl_get "$ITBL_SERVER_KEY" "/api/events/$(urlenc "$ITBL_EMAIL")?limit=50" || true
  if [[ "$ITBL_CODE" == 400 ]] && grep -qi 'no user exists' <<< "$ITBL_BODY"; then
    echo "no user yet — nothing has been sent to $ITBL_EMAIL"
    return 2
  fi
  out="$(classify_itbl_response "$ITBL_CODE" "$ITBL_BODY")" || { echo "$out"; return 1; }

  printf '%s' "$ITBL_BODY" | node -e '
    let d=""; process.stdin.on("data",c=>d+=c).on("end",()=>{
      let j; try { j = JSON.parse(d||"{}") } catch (e) { console.error("unparseable response"); process.exit(1) }
      const events = j.events || [];
      // The event objects are untyped in the spec, so match on any field that
      // carries the name rather than betting on one key.
      const nameOf = e => e.eventName || e.eventType || e.messageType || "";
      const names = events.map(nameOf);
      if (names.includes("pushSend")) {
        console.log(`pushSend present (${events.length} recent event(s))`);
        process.exit(0);
      }
      // These are the informative failures: Iterable decided not to send, or
      // tried and the token was rejected. Both are different from "nothing yet".
      const bad = names.find(n => /pushSendSkip|pushBounce|pushSendFailure/.test(n));
      if (bad) { console.error(`${bad}, not pushSend — Iterable declined or the token was rejected`); process.exit(1) }
      // Nothing sent yet is not a failure to send. Only the verdicts above are.
      console.error(names.length ? `no pushSend yet (saw: ${[...new Set(names)].slice(0,5).join(", ")})`
                                 : "no events recorded for this user yet");
      process.exit(2);
    })' 2>&1
}
