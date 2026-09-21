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
# No exemptions. There was one — a model-facing summary that quoted `bin/agent set …`
# because no other form was short enough to survive being wrapped inside a banner. Then
# the shim gave us a form that is, and the summary turned out to be printed in a box a
# person reads, so the exemption had been protecting a real bug.
hits="$(grep -n 'bin/' "${SCRIPTS[@]}" \
  | grep -v '^[^:]*:[0-9]*:[[:space:]]*#' \
  | grep -v '\$BIN/' | grep -v 'run_line' | grep -v 'BASH_SOURCE' \
  | grep -v 'cmd_path\|SHIM_CMDS' || true)"
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

# ---------------------------------------------------------------- the shim itself
# What makes the short form possible. Worth pinning offline because the failure mode is
# silent: a shim that points at a version directory the host has replaced still looks
# like a working command, and the whole reason it exists is that hosts keep old versions
# on disk and a stale path runs last month's code without saying so.
echo
echo "  The workspace shims — what makes a short command possible"
echo

ROOT="$PWD"
SW="$(mktemp -d)/proj"; mkdir -p "$SW"
( cd "$SW" && WS="$SW/.iterable" bash -c "source '$ROOT/bin/config.sh'; ws_init" ) >/dev/null 2>&1

missing=""
for c in onboard teardown discover gates agent iterable-keys proof-push; do
  [[ -x "$SW/.iterable/$c" ]] || missing="$missing $c"
done
[[ -z "$missing" ]] && ok "every entry point a developer is told to run gets one" \
                    || bad "no shim for:$missing"

[[ -f "$SW/.iterable/.gitignore" ]] && grep -q '^\*$' "$SW/.iterable/.gitignore" \
  && ok "gitignored, so a machine-specific path cannot be committed" \
  || bad "the workspace does not ignore itself — the shims would show up in git status"

# The one that matters: point a shim at something that no longer exists and it has to
# say so, not fail with a bare exec error nobody can act on.
sed 's|^target=.*|target="/nonexistent/bin/onboard"|' "$SW/.iterable/onboard" > "$SW/.iterable/stale"
chmod +x "$SW/.iterable/stale"
stale_out="$("$SW/.iterable/stale" 2>&1)"; stale_rc=$?
if ((stale_rc == 127)) && grep -qi 'updated\|moved' <<< "$stale_out"; then
  ok "a shim left behind by a plugin update explains itself"
else
  bad "stale shim gave rc $stale_rc and no explanation: $(tr -s '\n ' ' ' <<< "$stale_out" | cut -c1-60)"
fi
rm -rf "${SW%/proj}"

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — nothing on screen is untypeable."
