#!/usr/bin/env bash

set -uo pipefail
cd "$(dirname "$0")/.."

NORMALIZER="iterable-ios/assets/normalize-xcodegen-push-capability.rb"
FAILED=0
PASSED=0

ok() {
  printf 'PASS %s\n' "$1"
  PASSED=$((PASSED + 1))
}

bad() {
  printf 'FAIL %s\n' "$1"
  FAILED=1
}

test_root="$(mktemp -d "/private/tmp/iterable-ios-normalizer.XXXXXX")"
trap 'find "$test_root" -depth -delete' EXIT

malformed="$test_root/malformed.pbxproj"
printf '%s\n' \
  'TargetAttributes = {' \
  '  SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": 1]]";' \
  '};' > "$malformed"

if ruby "$NORMALIZER" "$malformed" &&
   rg -U -q 'SystemCapabilities = \{\s+com\.apple\.Push = \{\s+enabled = 1;' "$malformed"; then
  ok "rewrites the one known serialized Push capability"
else
  bad "rewrites the one known serialized Push capability"
fi

first_hash="$(shasum -a 256 "$malformed" | awk '{print $1}')"
if ruby "$NORMALIZER" "$malformed"; then
  second_hash="$(shasum -a 256 "$malformed" | awk '{print $1}')"
  if [[ "$first_hash" == "$second_hash" ]]; then
    ok "accepts its own output without changing it"
  else
    bad "accepts its own output without changing it"
  fi
else
  bad "accepts its own output without changing it"
fi

already_correct="$test_root/already-correct.pbxproj"
printf '%s\n' \
  'TargetAttributes = {' \
  '  SystemCapabilities = {' \
  '    com.apple.Push = {' \
  '      enabled = 1;' \
  '    };' \
  '  };' \
  '};' > "$already_correct"
correct_hash="$(shasum -a 256 "$already_correct" | awk '{print $1}')"
if ruby "$NORMALIZER" "$already_correct" &&
   [[ "$correct_hash" == "$(shasum -a 256 "$already_correct" | awk '{print $1}')" ]]; then
  ok "accepts an already-correct generated dictionary"
else
  bad "accepts an already-correct generated dictionary"
fi

missing="$test_root/missing.pbxproj"
printf '%s\n' 'TargetAttributes = {' '};' > "$missing"
if ruby "$NORMALIZER" "$missing" >/dev/null 2>&1; then
  bad "rejects a missing Push capability"
else
  ok "rejects a missing Push capability"
fi

duplicate="$test_root/duplicate.pbxproj"
printf '%s\n' \
  'SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": 1]]";' \
  'SystemCapabilities = "[\"com.apple.Push\": [\"enabled\": 1]]";' > "$duplicate"
if ruby "$NORMALIZER" "$duplicate" >/dev/null 2>&1; then
  bad "rejects duplicate Push capability shapes"
else
  ok "rejects duplicate Push capability shapes"
fi

unknown="$test_root/unknown.pbxproj"
printf '%s\n' \
  'SystemCapabilities = {' \
  '  com.apple.Push = {' \
  '    enabled = 0;' \
  '  };' \
  '};' > "$unknown"
if ruby "$NORMALIZER" "$unknown" >/dev/null 2>&1; then
  bad "rejects an unknown Push capability shape"
else
  ok "rejects an unknown Push capability shape"
fi

printf '%d checks\n' "$PASSED"
exit "$FAILED"
