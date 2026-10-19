#!/usr/bin/env bash
# ios-provision encodes every screen string with a pure-bash jstr and falls back
# to node only for control characters, invalid UTF-8, and strings over 1024
# characters. Every output must match
# node's JSON.stringify byte for byte, in both the C and a UTF-8 locale.

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() {
  printf 'FAIL %s\n' "$1"
  [[ $# -lt 2 ]] || printf '  %s\n' "$2"
  FAILED=1
}

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-jstr-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-jstr-test.*|/private/tmp/iterable-ios-jstr-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

sed -n '/^jstr() {/,/^}/p; /^jstr_needs_node() {/,/^}/p' bin/ios-provision > "$ROOT/jstr.sh"
grep -q '^jstr_needs_node() {' "$ROOT/jstr.sh" || {
  bad "could not extract jstr from bin/ios-provision"; exit 1; }

medium="" long=""
for ((i = 0; i < 24; i++)); do medium="${medium}seg $i \"q\" \\ \$x \`y\` é — 🐶 & %s;"; done
for ((i = 0; i < 400; i++)); do long="${long}seg $i \"q\" \\ \$x \`y\` é — 🐶 & %s;"; done

names=() values=()
add() { names+=("$1"); values+=("$2"); }
add "plain ASCII" 'Use the detected app target'
add "double quotes" 'say "hello" and ""'
add "backslashes" 'C:\path\to\file and \\ double'
add "trailing backslash" 'ends with \'
add "only backslashes" '\\\\'
add "dollar and backticks" '$HOME $(rm -rf /) `id` ${x}'
add "printf directives" '%s %d %% %q \n literal'
add "ampersand (bash 5.2 patsub)" 'a & b && c'
add "leading dash" '-- --version -e'
add "newline" $'line one\nline two\n'
add "tab" $'col\tcol'
add "carriage return" $'crlf\r\n'
add "control chars" $'bell\a back\b ff\f vt\v nul-adjacent\001 esc\033 us\037'
add "DEL" $'del\177'
add "U+2028 and U+2029" $'a\xe2\x80\xa8b\xe2\x80\xa9c'
add "emoji and non-ASCII" 'Step 1 of 2 — Créer 🐶 日本語 ﬁ'
add "invalid UTF-8" $'bad\xffbyte \xc3 lone'
add "empty string" ''
add "medium string, bash path (${#medium} chars)" "$medium"
add "long string, node path (${#long} chars)" "$long"

for locale in C en_US.UTF-8; do
  mismatches=""
  for ((i = 0; i < ${#values[@]}; i++)); do
    printf '%s' "${values[$i]}" > "$ROOT/input"
    LC_ALL="$locale" bash -c '
      source "$1"
      jstr "$(cat "$2"; printf x)" > "$3"
    ' _ "$ROOT/jstr.sh" "$ROOT/input" "$ROOT/bash.out"
    node -e '
      const fs=require("fs");
      const value=fs.readFileSync(process.argv[1]).toString("utf8")+"x";
      process.stdout.write(JSON.stringify(value));
    ' "$ROOT/input" > "$ROOT/node.out"
    cmp -s "$ROOT/bash.out" "$ROOT/node.out" ||
      mismatches="${mismatches}${names[$i]}; "
  done
  if [[ -z "$mismatches" ]]; then
    ok "jstr matches JSON.stringify byte for byte for ${#values[@]} inputs (LC_ALL=$locale)"
  else
    bad "jstr differs from JSON.stringify (LC_ALL=$locale)" "$mismatches"
  fi
done

# A trailing x keeps command substitution from eating trailing newlines above, so
# check the bare value once without it.
if [[ "$(bash -c 'source "$1"; jstr ""' _ "$ROOT/jstr.sh")" == '""' &&
      "$(bash -c 'source "$1"; jstr "$2"' _ "$ROOT/jstr.sh" 'a"b')" == '"a\"b"' ]]; then
  ok "jstr encodes the empty string and an embedded quote without the padding"
else
  bad "jstr mis-encodes the empty string or an embedded quote"
fi

no_node="$(env PATH=/usr/bin:/bin LC_ALL=en_US.UTF-8 bash -c '
  source "$1"
  command -v node >/dev/null 2>&1 && exit 9
  jstr "say \"hi\" \\ é — 🐶 & \$x"
' _ "$ROOT/jstr.sh")"
if [[ "$no_node" == '"say \"hi\" \\ é — 🐶 & $x"' ]]; then
  ok "ordinary strings, including quotes and non-ASCII, are encoded without node"
else
  bad "jstr still needs node for ordinary strings" "$no_node"
fi

LC_ALL=en_US.UTF-8 bash -c '
  source "$1"
  s="é"
  jstr "$s" >/dev/null
  [[ ${#s} -eq 1 && "$LC_ALL" == en_US.UTF-8 ]]
' _ "$ROOT/jstr.sh" &&
  ok "the C locale used for byte checks does not leak out of jstr" ||
  bad "jstr left the caller in the C locale"

((FAILED)) && exit 1
exit 0
