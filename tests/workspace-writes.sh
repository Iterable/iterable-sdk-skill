#!/usr/bin/env bash
# A write into the workspace never leaves a file worse than it found it: not readable
# by anyone else, and not half-written when the thing producing it failed.
#
# Both halves were found by an outside audit, and both hid the same way — behind code
# that ended correctly. save_env chmod'ed .env to 0600 afterwards, but built it through
# a temp file created at the caller's umask, holding every *other* key, and `mv` carries
# a mode with it. And the google-services.json fetch put its redirect on the target, so
# the truncation happened before the download it depended on.
#
# Offline. Writes only into a temp workspace.

set -uo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
WS="$TMP/proj/.iterable"

# umask 022 on purpose: it is the default nearly everywhere, so it is the condition
# under which this has to hold, not an adversarial one.
in_ws() { ( cd "$TMP" && umask 022 && WS="$WS" bash -c "source '$ROOT/bin/config.sh' >/dev/null 2>&1
$1" ); }

mode_of() { ls -l "$1" | cut -c1-10; }

echo
echo "  workspace/.env — secrets on disk, and who can read them"
echo

# The interesting mode is the one during the write, not the one left behind: the old
# code's final chmod made the end state right and hid a 0644 window at two names. So
# intercept the `mv` and read the temp file as save_env hands it over — that mode is
# both what .env.tmp had while it existed and what .env gets on arrival.
in_ws 'mv() { command ls -l "$1" | command cut -c1-10 > "'"$TMP"'/handover"; command mv "$@"; }
  save_env ITBL_SERVER_KEY aaa
  save_env ITBL_MOBILE_KEY bbb'

[[ "$(cat "$TMP/handover")" == "-rw-------" ]] \
  && ok "the temp file holding every other key is 0600 while it exists" \
  || bad "the temp file was $(cat "$TMP/handover") — a window another user could read"

[[ "$(mode_of "$WS/.env")" == "-rw-------" ]] \
  && ok "and .env is 0600 once the move lands" \
  || bad ".env is $(mode_of "$WS/.env") — another user on this machine can read the keys"

[[ ! -e "$WS/.env.tmp" ]] \
  && ok "and nothing is left at .env.tmp" \
  || bad ".env.tmp survived at $(mode_of "$WS/.env.tmp"), holding every other key"

# Two keys, because the temp file only holds anything once there is a second write:
# the first save_env copies an empty file, the second copies a file with a key in it.
[[ "$(grep -c '^ITBL_' "$WS/.env")" == 2 ]] \
  && ok "and both keys are in it — the mode fix did not cost the write" \
  || bad "expected 2 keys in .env, found $(grep -c '^ITBL_' "$WS/.env")"

# An .env left at 0644 by an older version of this tool, or by a developer creating it
# by hand. umask cannot fix a file that already exists, which is why the chmod stays.
chmod 644 "$WS/.env"
in_ws 'save_env ITBL_EMAIL a@b.example'
[[ "$(mode_of "$WS/.env")" == "-rw-------" ]] \
  && ok "and a file already sitting at 0644 is repaired, not left" \
  || bad "a pre-existing 0644 .env stayed $(mode_of "$WS/.env")"

echo
echo "  workspace/artifacts/google-services.json — a failed fetch keeps the good file"
echo

mkdir -p "$WS/artifacts"
GOOD='{"project_info":{"project_id":"real-project"}}'
printf '%s\n' "$GOOD" > "$WS/artifacts/google-services.json"

# api_get stubbed as the failure it actually is in the field — an expired token, a 403
# from the wrong quota project — rather than as a network outage.
out="$(in_ws 'api_get() { echo "{\"error\":{\"message\":\"Request had invalid authentication credentials\"}}"; return 1; }
  PID=p fetch_gs_json app-id-1 2>&1; echo "rc=$?"')"

grep -q 'rc=[^0]' <<< "$out" \
  && ok "fetch_gs_json reports the failure" \
  || bad "a failed fetch returned 0: $(tr -s '\n ' ' ' <<< "$out" | cut -c1-80)"

[[ "$(cat "$WS/artifacts/google-services.json")" == "$GOOD" ]] \
  && ok "and the config file that was already there is untouched" \
  || bad "the good google-services.json was truncated by a fetch that failed"

[[ ! -e "$WS/artifacts/google-services.json.part" ]] \
  && ok "and no half-written part file is left to be mistaken for one" \
  || bad "google-services.json.part survived the failure"

# The success path, so the fix cannot pass by never writing anything.
in_ws 'api_get() { printf "{\"configFileContents\":\"%s\"}" "$(printf "{\"project_info\":{\"project_id\":\"fetched\"}}" | base64)"; }
  PID=p fetch_gs_json app-id-1' >/dev/null 2>&1
grep -q 'fetched' "$WS/artifacts/google-services.json" \
  && ok "and a fetch that works still replaces the file, decoded" \
  || bad "the success path no longer writes: $(cut -c1-60 "$WS/artifacts/google-services.json")"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — every workspace write is private, and whole or not at all."
