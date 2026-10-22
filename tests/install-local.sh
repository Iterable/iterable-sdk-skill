#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.." || exit

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-install-local-test.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-install-local-test.*|/private/tmp/iterable-install-local-test.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT

TEST_HOME="$ROOT/home"
TARGET="$ROOT/app"
mkdir -p "$TEST_HOME/.claude" "$TARGET"
cat > "$TEST_HOME/.claude/settings.json" <<'EOF'
{
  "enabledPlugins": {
    "iterable-sdk@iterable": true
  }
}
EOF

HOME="$TEST_HOME" tools/install-local "$TARGET" --force >"$ROOT/install.out" 2>&1
install_rc=$?
VERSION="$(node -e 'process.stdout.write(require("./.claude-plugin/plugin.json").version)')"
SETTINGS="$TARGET/.claude/settings.local.json"
CACHE="$TEST_HOME/.claude/plugins/cache/iterable-local/iterable-sdk/$VERSION"

if [[ "$install_rc" -eq 0 &&
      -f "$SETTINGS" ]] &&
    node -e '
      const value=require(process.argv[1]).enabledPlugins || {};
      process.exit(
        value["iterable-sdk@iterable-local"]===true &&
        value["iterable-sdk@iterable"]===false ? 0 : 1
      );
    ' "$SETTINGS"; then
  ok "project install selects the local plugin and disables the published copy"
else
  bad "project install left competing plugin copies enabled"
fi

if [[ -f "$CACHE/agents/ios-provisioner.md" &&
      -x "$CACHE/bin/ios-provision" &&
      -x "$CACHE/bin/ios-deliver" &&
      -x "$CACHE/bin/ios-verify" ]]; then
  ok "local export includes the iOS specialist and executable toolchain"
else
  bad "local export omitted an iOS runtime component"
fi

if grep -q 'start a new one to see this one' "$ROOT/install.out"; then
  ok "installer warns that an existing host session keeps its loaded build"
else
  bad "installer did not explain the session-restart boundary"
fi

((FAILED)) && exit 1
exit 0
