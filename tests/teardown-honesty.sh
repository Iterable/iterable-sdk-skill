#!/usr/bin/env bash
# Offline: teardown never reports a state it did not manage to read.
#
# Every failing gcloud call looks the same from inside a shell — a non-zero exit and
# some text. Read carelessly, "you are signed out" becomes "the account is already
# gone", and the script then deletes the local key while a live service account it
# cannot see still exists. That happened on a real run, and the run *said* the Google
# side was back at its original state.
#
# gcloud is stubbed. No network, no credentials, nothing removed anywhere real.

set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-48s %s\n' "$1" "$2"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
STUB="$TMP/bin"; mkdir -p "$STUB"
for c in node adb curl; do printf '#!/bin/sh\nexit 0\n' > "$STUB/$c"; chmod +x "$STUB/$c"; done
export PATH="$STUB:/usr/bin:/bin"

# MODE is read by the stub at call time, so one stub covers every case.
cat > "$STUB/gcloud" <<'STUBEOF'
#!/usr/bin/env bash
case "$1 $2" in
  "auth print-access-token")
    [[ "$MODE" == signedout ]] && { echo "Reauthentication failed." >&2; exit 1; }
    echo "ya29.stub-token" ;;
  "config get-value") echo "stub@example.com" ;;
  "iam service-accounts")
    case "$3" in
      # Absence is an empty success, never an error: a deleted account answers
      # `describe` with PERMISSION_DENIED rather than NOT_FOUND, so the old code read
      # "GCP won't say" as "it's gone". Measured against real GCP on 2026-09-22.
      list)
        case "$MODE" in
          gone)   exit 0 ;;
          denied) echo "PERMISSION_DENIED: caller lacks iam.serviceAccounts.list" >&2; exit 1 ;;
          *)      echo "itbl-onboard-fcm@stub-project.iam.gserviceaccount.com" ;;
        esac ;;
      describe) echo "PERMISSION_DENIED: nothing should be asking this" >&2; exit 1 ;;
      delete)
        [[ "$MODE" == deletefail ]] \
          && { echo "PERMISSION_DENIED: caller lacks iam.serviceAccounts.delete" >&2; exit 1; }
        echo "deleted" ;;
    esac ;;
  *) exit 0 ;;
esac
STUBEOF
chmod +x "$STUB/gcloud"

# A workspace with the artifacts a real run leaves behind, rebuilt per case.
fresh_ws() {
  rm -rf "$TMP/ws"; mkdir -p "$TMP/ws/artifacts"
  printf 'PID=stub-project\n' > "$TMP/ws/resolved.env"
  printf '{}\n' > "$TMP/ws/artifacts/sa-key.json"
  printf 'G6\tgreen\ttool\tService account exists\tstub\n' > "$TMP/ws/state.tsv"
}

run_teardown() { ( cd "$TMP" && MODE="$1" WS="$TMP/ws" NON_INTERACTIVE=1 \
  "$ROOT/bin/teardown" --yes 2>&1 | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g' ); }

echo
echo "  teardown — what it claims is what it checked"
echo

# ------------------------------------------------------------------- signed out
fresh_ws
out="$(run_teardown signedout)"
grep -qi 'not signed in' <<< "$out" \
  && ok "signed out is named as signed out" \
  || bad "signed out was not reported" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"

grep -qi 'already gone' <<< "$out" \
  && bad "it called the account gone" "it never managed to ask" \
  || ok "and not mistaken for an account that is gone"

[[ -f "$TMP/ws/artifacts/sa-key.json" ]] \
  && ok "the local key survives a check that never happened" \
  || bad "the key was deleted while signed out" "a live account would now be invisible"

grep -qF 'gcloud auth login' <<< "$out" \
  && ok "and it says what to run" \
  || bad "no remedy printed" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"

# ------------------------------------------------------- readable, but refused
fresh_ws
out="$(run_teardown denied)"
grep -qi 'could not check' <<< "$out" \
  && ok "a refused read is reported as a refused read" \
  || bad "PERMISSION_DENIED was swallowed" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"
grep -qi 'PERMISSION_DENIED' <<< "$out" \
  && ok "and the reason survives to the screen" \
  || bad "the error text was dropped" "nothing on screen says why"
[[ -f "$TMP/ws/artifacts/sa-key.json" ]] \
  && ok "nothing local is removed on an unread cloud state" \
  || bad "artifacts removed after a failed check" "orphans whatever is still up there"

# --------------------------------------------------------- genuinely not there
fresh_ws
out="$(run_teardown gone)"
grep -qi 'already gone' <<< "$out" \
  && ok "an empty successful list is the one thing that means gone" \
  || bad "an absent account was not recognised" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"
[[ ! -f "$TMP/ws/artifacts/sa-key.json" ]] \
  && ok "and then the local artifacts do go" \
  || bad "artifacts kept when the account is confirmed gone" "nothing left to protect"

# ------------------------------------------------------------ a live account
fresh_ws
out="$(run_teardown present)"
grep -qF 'deleted' <<< "$out" \
  && ok "an account that is there gets deleted" \
  || bad "a present account was not deleted" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"

# The actor does not grade itself. Saying the ladder "will now show" a state is a
# verdict, and teardown has no standing to give one.
if grep -qiE 'will now show|back at its original state\.$' <<< "$out"; then
  bad "teardown graded its own work" "the ladder is the verifier, not the actor"
else
  ok "it points at the ladder instead of claiming the result"
fi
grep -qE 'gates' <<< "$out" \
  && ok "and names the check by a command that resolves" \
  || bad "no verifier named" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"

# -------------------------------------------------- a live account it cannot delete
# The branch above this one refuses for exactly this reason when the *read* fails.
# The delete failing is the same situation arrived at one step later, and it used to
# fall straight through to `rm -rf artifacts/` — losing the only copy of a key whose
# account is still up there.
fresh_ws
out="$(run_teardown deletefail)"; rc=$?
[[ -f "$TMP/ws/artifacts/sa-key.json" ]] \
  && ok "a delete that failed leaves the local key alone" \
  || bad "artifacts removed after a failed delete" "the account is still live and unreachable"
((rc != 0)) \
  && ok "and exits non-zero rather than reporting a teardown" \
  || bad "exit 0 after a failed delete" "a caller would read that as done"
grep -qiE 'could not delete' <<< "$out" \
  && ok "and says which half failed" \
  || bad "the failed delete was not named" "$(tr -s '\n ' ' ' <<< "$out" | cut -c1-90)"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — every claim it makes, it checked."
