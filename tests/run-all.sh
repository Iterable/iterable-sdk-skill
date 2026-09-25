#!/usr/bin/env bash
# Every suite in here, in one command, with an exit code CI can gate on.
#
# Written because there were nineteen test files and nothing that ran them: the suites
# were only ever run one at a time, by hand, by whoever had just written one. Three of
# them were not even executable, which is invisible until a runner loops over the
# directory — so this invokes `bash "$t"` rather than "$t", and reports the missing bit
# separately instead of letting a mode silently drop a suite.
#
# A suite that skips is reported as skipped, never as a pass. Several here need a live
# project, a device or the network, and "nothing ran" reading as green is the failure
# that let an undeliverable release ship.
#
# Offline suites only, unless --all: the network ones are the slow, flaky minority and
# CI should not go red because a spec host was down.

set -uo pipefail
cd "$(dirname "$0")/.."

ALL=0
[[ "${1:-}" == --all ]] && ALL=1

# Needs the network (Iterable's published spec). Skips on its own when it cannot
# reach it, so --all is about being deliberate, not about it being unsafe.
NETWORK_SUITES=" key-types-match-spec.sh "

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }
dim()   { printf '\033[2m%s\033[0m' "$1"; }

PASSED=0 FAILED=0 SKIPPED=0 EXCLUDED=0 ASSERTIONS=0
FAILED_NAMES=() UNEXEC=()

run_suite() {
  local t="$1" name out rc p f
  name="$(basename "$t")"

  if [[ "$ALL" == 0 && "$NETWORK_SUITES" == *" $name "* ]]; then
    printf '  %-30s %s\n' "$name" "$(dim 'not run (needs the network; --all)')"
    ((EXCLUDED++)); return 0
  fi
  [[ -x "$t" ]] || UNEXEC+=("$name")

  case "$t" in
    *.exp) out="$(expect -f "$t" 2>&1)"; rc=$? ;;
    *)     out="$(bash "$t" 2>&1)";     rc=$? ;;
  esac

  p="$(grep -c 'PASS' <<< "$out")"; f="$(grep -c 'FAIL' <<< "$out")"
  ((ASSERTIONS += p))

  if ((rc != 0)) || ((f > 0)); then
    printf '  %-30s %s\n' "$name" "$(red "FAILED") $(dim "($f of $((p + f)), rc $rc)")"
    printf '%s\n' "$out" | grep 'FAIL' | sed 's/^/      /'
    FAILED_NAMES+=("$name"); ((FAILED++))
  elif ((p == 0)); then
    # Its own words for why, because "skipped" without a reason is how a suite that
    # has quietly stopped testing anything passes for one that is waiting on a device.
    printf '  %-30s %s\n' "$name" "$(dim "skipped — $(grep -m1 -i 'skip' <<< "$out" \
      | sed 's/^[[:space:]]*//; s/^SKIP[^[:alnum:]]*//' | cut -c1-44)")"
    ((SKIPPED++))
  else
    printf '  %-30s %s %s\n' "$name" "$(green ok)" "$(dim "$p checks")"
    ((PASSED++))
  fi
}

echo
echo "  Shell suites"
echo
for t in tests/*.sh; do
  [[ "$(basename "$t")" == "$(basename "$0")" ]] && continue
  run_suite "$t"
done

echo
if command -v expect >/dev/null 2>&1; then
  echo "  Interactive suites (expect)"
  echo
  for t in tests/*.exp; do run_suite "$t"; done
else
  # Named rather than silently absent: these are the only coverage of the wizard's
  # prompts, so a machine without expect is testing less than it looks like it is.
  _exp=(tests/*.exp)
  printf '  %s\n' "$(dim "expect not installed — the ${#_exp[@]} interactive suites did not run")"
  ((EXCLUDED += ${#_exp[@]}))
fi

echo
if ((${#UNEXEC[@]})); then
  printf '  %s %s\n' "$(red 'not executable:')" "${UNEXEC[*]}"
  printf '  %s\n' "$(dim 'ran anyway via bash, but `./tests/<name>` would not work — chmod +x')"
  echo
fi

printf '  %d suites ok (%d checks), %d failed, %d skipped, %d not run\n' \
  "$PASSED" "$ASSERTIONS" "$FAILED" "$SKIPPED" "$EXCLUDED"

if ((FAILED)); then
  printf '  %s %s\n\n' "$(red 'FAILED:')" "${FAILED_NAMES[*]}"
  exit 1
fi
echo
