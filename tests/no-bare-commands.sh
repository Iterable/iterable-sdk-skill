#!/usr/bin/env bash
# Offline lint: nothing tells a developer to run `bin/something`.
#
# All of this prose was written when the tool was a repo you cd'd into, where
# `bin/onboard` was the truth. Installed as a plugin, every front end runs from the
# developer's own project — the one directory where a bare `bin/…` cannot resolve. So
# the instruction was a command that does not exist, and somebody followed it and got
# `zsh: no such file or directory`. Twice, in different messages, because the wording
# was copied around.
#
# The rule is about imperatives, not mentions: `run_line onboard` prints a path that
# resolves, and a passing reference in prose ("the four Iterable steps") is fine. What
# fails is telling somebody to type something they cannot type.

set -uo pipefail
cd "$(dirname "$0")/.."

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAILED=1; }

echo
echo "  Printed commands — every one of them resolves from the developer's project"
echo

SCRIPTS=()
for f in bin/*; do
  case "$f" in *.md|*.js|*.json) continue;; esac
  [[ -f "$f" ]] && SCRIPTS+=("$f")
done

# Imperative shapes. `$BIN/x` and run_line are the two correct forms, so neither
# appears here: both already carry the path.
for pat in 'run bin/' 'Run bin/' 'bold "bin/' 'bold '"'"'bin/'; do
  hits="$(grep -n -- "$pat" "${SCRIPTS[@]}" 2>/dev/null | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' || true)"
  if [[ -z "$hits" ]]; then
    ok "no '$pat' in anything printed"
  else
    bad "'$pat' — a command the developer cannot run:"
    printf '        %s\n' $(printf '%s\n' "$hits" | cut -d: -f1-2)
  fi
done

# The wider rule: no bare `bin/…` anywhere a person reads, whatever the sentence
# shape. The imperative patterns above missed "starting with:  bin/iterable-keys" and
# "bin/teardown removes everything it added" — not orders, but a developer types them
# all the same, and both were on the screen Franco got `no such file or directory` on.
#
# `a_summary=` lines are exempt: those go to a model, which is handed the resolved path
# in `next.command`, and an absolute path inside a wrapped banner breaks across lines
# into something genuinely unrunnable. That exemption is why the check is scoped rather
# than global.
hits="$(grep -n 'bin/' "${SCRIPTS[@]}" \
  | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' \
  | grep -v '\$BIN/' | grep -v 'run_line' | grep -v 'BASH_SOURCE' \
  | grep -v 'a_summary=' || true)"
if [[ -z "$hits" ]]; then
  ok "no bare 'bin/…' in anything a person reads"
else
  bad "a bare 'bin/…' a developer would type and get 'no such file or directory':"
  printf '        %s\n' $(printf '%s\n' "$hits" | cut -d: -f1-2)
fi

# The positive half: the ending a developer actually reads has to contain a path, or
# the box above it is the only thing on the screen they can act on and the re-run
# instruction is a dead end.
grep -q 'run_line onboard' bin/config.sh \
  && ok "the rc 40 ending prints a runnable path" \
  || bad "the rc 40 ending has no run_line — check pending_tail"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — nothing on screen is untypeable."
