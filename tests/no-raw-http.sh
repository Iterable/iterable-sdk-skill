#!/usr/bin/env bash
# Structural test: every Google API call goes through api_get/api_post.
#
# Exists because of a real bug. api_get was fixed to send x-goog-user-project
# (firebase.googleapis.com 403s without it) but two raw `curl -X POST` calls in
# bin/provision were missed, so app registration kept failing with a 403 that
# looked like an auth problem. One wrapper per verb means one place to fix.
#
# Offline. Reads source only.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
# config.sh defines the wrappers; gates probes fcm.googleapis.com directly on
# purpose, because G9 must prove the service-account token in isolation rather
# than reuse the user-credential helpers.
ALLOWED="bin/config.sh"

while IFS= read -r hit; do
  file="${hit%%:*}"
  rest="${hit#*:}"; line="${rest%%:*}"
  [[ " $ALLOWED " == *" $file "* ]] && continue
  # The URL is usually a few lines below the curl in a wrapped command, so look at
  # the whole invocation rather than the matched line.
  window="$(sed -n "${line},$((line + 8))p" "$file" 2>/dev/null)"
  [[ "$file" == bin/gates && "$window" == *fcm.googleapis.com* ]] && continue
  printf '  \033[31mFAIL\033[0m raw HTTP call outside a wrapper:\n    %s\n' "$hit"
  FAILED=1
done < <(grep -n 'curl' bin/* 2>/dev/null | grep -i 'googleapis\.com\|iterable\.com\|ITBL_BASE\|-X POST')

if ((FAILED == 0)); then
  printf '  \033[32mPASS\033[0m all Google API calls go through api_get/api_post\n'
fi

# The wrappers themselves must actually send the header.
for fn in api_get api_post; do
  if grep -q 'x-goog-user-project' <<< "$(grep -A14 "^$fn() {" bin/config.sh)"; then
    printf '  \033[32mPASS\033[0m %s sends x-goog-user-project\n' "$fn"
  else
    printf '  \033[31mFAIL\033[0m %s does not send x-goog-user-project\n' "$fn"
    FAILED=1
  fi
done

if grep -q 'Api-Key' <<< "$(grep -A10 '^itbl_curl() {' bin/config.sh)"; then
  printf '  \033[32mPASS\033[0m itbl_curl sends Api-Key\n'
else
  printf '  \033[31mFAIL\033[0m itbl_curl does not send Api-Key\n'
  FAILED=1
fi

# And sends it on stdin. A header in argv is readable with `ps` by every process on
# this machine, while iterable-keys tells the developer in bold that a key never
# reaches an argument list — so `-H "Api-Key: …"` is the one form that makes the
# tool's own promise false. Comments are skipped: the note in curl_auth quotes the
# banned form on purpose.
argv_creds() {
  grep -rnE -- '-H +"?(Authorization|Api-Key):' bin/ 2>/dev/null \
    | grep -vE ':[0-9]+: *#'
}
if [[ -n "$(argv_creds)" ]]; then
  printf '  \033[31mFAIL\033[0m a credential is passed in argv, where ps can read it:\n    %s\n' \
    "$(argv_creds | head -1)"
  FAILED=1
else
  printf '  \033[32mPASS\033[0m no credential-bearing header is passed in argv\n'
fi

# A secret must never reach resolved.env, which is printed, diffed and read aloud.
# workspace/.env is the only place keys go.
#
# This used to ban the whole ITBL_ prefix, which is a proxy for "secret" rather
# than the thing itself — and the proxy started failing honest code: the proof
# marker and template id are values the ladder prints in its own verdict, so
# resolved.env is exactly where they belong. Match on what a credential is called.
SECRET_RE='save_resolved *[A-Za-z_]*\(KEY\|SECRET\|TOKEN\|PASS\|CREDENTIAL\)'
secret_leak() { grep -rni "$SECRET_RE" "$1" 2>/dev/null; }

if secret_leak bin/ >/dev/null; then
  printf '  \033[31mFAIL\033[0m a credential is being written to resolved.env:\n    %s\n' "$(secret_leak bin/ | head -1)"
  FAILED=1
else
  printf '  \033[32mPASS\033[0m no Iterable secrets routed to resolved.env\n'
fi

# A lint nobody has seen fail is a lint nobody knows works. Narrowing the pattern
# above is exactly the kind of change that can quietly stop matching anything.
probe="$(mktemp -d)/leak.sh"
printf 'save_resolved ITBL_SERVER_KEY "$k"\n' > "$probe"
if secret_leak "$probe" >/dev/null; then
  printf '  \033[32mPASS\033[0m the lint still catches a real key\n'
else
  printf '  \033[31mFAIL\033[0m the lint no longer catches save_resolved ITBL_SERVER_KEY\n'
  FAILED=1
fi
rm -rf "$(dirname "$probe")"

exit "$FAILED"
