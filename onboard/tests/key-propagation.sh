#!/usr/bin/env bash
# Negative fixture for G9's propagation retry.
#
# A key Google has never seen produces the same "Invalid JWT Signature" as a key
# that has not propagated yet, so it exercises the retry path on demand instead of
# waiting for a real 60-second window. Two branches, opposite expectations:
#
#   young key -> retry until the deadline, then red
#   old key   -> red immediately, no waiting on a credential that is simply broken
#
# Touches no cloud resource. Moves the real key aside and always restores it.

set -uo pipefail
cd "$(dirname "$0")/.."
source bin/config.sh

FAKE=/tmp/itbl-fake-sa.json
SAVED=/tmp/itbl-real-sa.json.bak
FAILED=0

restore() { [[ -f "$SAVED" ]] && mv -f "$SAVED" "$SA_KEY"; rm -f "$FAKE"; }
trap restore EXIT INT

ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 2>/dev/null \
  | node -e '
    let d="";process.stdin.on("data",c=>d+=c).on("end",()=>{
      process.stdout.write(JSON.stringify({
        type:"service_account",
        project_id:process.argv[1],
        private_key_id:"fake0000000000000000000000000000000000000",
        private_key:d,
        client_email:process.argv[2],
        token_uri:"https://oauth2.googleapis.com/token",
      },null,2));
    })' "$PID" "$SA_EMAIL" > "$FAKE"

[[ -s "$FAKE" ]] || { echo "could not build the fixture"; exit 3; }

echo
echo "  G9 propagation retry — fabricated key, no cloud changes"
echo

# G9 only runs when G0-G8 are green; on any other project it is reported as
# blocked and this fixture would fail for a reason that has nothing to do with the
# retry. Say so instead of producing a misleading red.
# Captured, not piped into grep -q: under pipefail, grep exiting first makes gates
# take SIGPIPE and the pipeline report failure, which skipped this test on a ladder
# that was in fact green.
LADDER="$(bin/gates < /dev/null 2>&1)"
if ! grep -q 'G8.*mode 600' <<< "$LADDER"; then
  echo
  echo "  SKIP — this needs a project whose ladder is green through G8."
  echo "  Current selection: ${PID:-<none>} / ${PACKAGE:-<none>}"
  exit 0
fi

# The real gate reads $SA_KEY, so stand the fixture up in its place.
[[ -f "$SA_KEY" ]] && cp -p "$SA_KEY" "$SAVED"
mkdir -p "$ART"
cp "$FAKE" "$SA_KEY"; chmod 600 "$SA_KEY"

# --- young key: should retry, then give up at the deadline -------------------
touch "$SA_KEY"
START=$SECONDS
OUT="$(PROPAGATION_WAIT=12 QUIET_VERDICT=1 bin/gates 2>&1 | grep 'G9')"
ELAPSED=$((SECONDS - START))

grep -qi 'invalid jwt signature' <<< "$OUT" \
  && ok "young key reports the real error: $(sed 's/^ *//' <<< "$OUT" | cut -c1-70)" \
  || bad "young key: unexpected G9 output: $OUT"

((ELAPSED >= 12)) \
  && ok "young key retried for ${ELAPSED}s before going red (deadline 12s)" \
  || bad "young key gave up after ${ELAPSED}s — the retry did not run"

# --- old key: should fail immediately ----------------------------------------
touch -t 202601010000 "$SA_KEY"
START=$SECONDS
PROPAGATION_WAIT=60 QUIET_VERDICT=1 bin/gates >/dev/null 2>&1
ELAPSED=$((SECONDS - START))

((ELAPSED < 20)) \
  && ok "old key failed fast (${ELAPSED}s) — no waiting on a broken credential" \
  || bad "old key waited ${ELAPSED}s; the age guard is not working"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — G9 distinguishes 'not yet' from 'broken'."
