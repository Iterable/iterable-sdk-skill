#!/usr/bin/env bash
# Simulator builds keep their entitlements in __TEXT,__entitlements. otool
# prints that section as little-endian 32-bit words and, when the size is not a
# multiple of four, ends with single bytes; all of them must be read back.

set -uo pipefail
cd "$(dirname "$0")/.." || exit
REPO="$PWD"

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; [[ $# -lt 2 ]] || printf '  %s\n' "$2"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-entitlements.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-entitlements.*|/private/tmp/iterable-ios-entitlements.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT
mkdir -p "$ROOT/bin"
cat > "$ROOT/bin/otool" <<'OTOOL'
#!/usr/bin/env bash
node -e '
  const data=require("fs").readFileSync(process.argv[1]);
  console.log("/tmp/App.app/App:\nContents of (__TEXT,__entitlements) section");
  for (let at=0; at<data.length; at+=16) {
    const words=[];
    for (let w=at; w<Math.min(at+16,data.length); w+=4) {
      if (w+4<=data.length) words.push(data.subarray(w,w+4).reverse().toString("hex"));
      else for (let b=w; b<data.length; b++) words.push(data.subarray(b,b+1).toString("hex"));
    }
    console.log((0x100003468+at).toString(16).padStart(16,"0")+"\t"+words.join(" ")+" ");
  }
' "$IOS_ENTITLEMENTS_FIXTURE"
OTOOL
cat > "$ROOT/bin/uname" <<'UNAME'
#!/usr/bin/env bash
[[ "${1:-}" == -m ]] && printf 'arm64\n'
UNAME
chmod +x "$ROOT/bin/otool" "$ROOT/bin/uname"
touch "$ROOT/App"

for pad in "" "x" "xx" "xxx"; do
  node -e '
    const pad=process.argv[2];
    require("fs").writeFileSync(process.argv[1],
      `<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n\t<key>application-identifier</key>\n\t<string>TEAM123456.com.example.dogshelter${pad}</string>\n\t<key>aps-environment</key>\n\t<string>development</string>\n</dict>\n</plist>\n`);
  ' "$ROOT/entitlements.plist" "$pad"
  size="$(wc -c < "$ROOT/entitlements.plist" | tr -d ' ')"
  out="$(env PATH="$ROOT/bin:$PATH" IOS_ENTITLEMENTS_FIXTURE="$ROOT/entitlements.plist" \
    bash -c 'source "$1/bin/ios-simulator.sh"; ios_simulator_executable_entitlements "$2"' _ "$REPO" "$ROOT/App" | od -An -tx1 | tr -d ' \n')"
  want="$(od -An -tx1 < "$ROOT/entitlements.plist" | tr -d ' \n')"
  if [[ "$out" == "$want" ]]; then
    ok "a $size-byte section (size mod 4 = $((size % 4))) is read back byte for byte"
  else
    bad "a $size-byte section (size mod 4 = $((size % 4))) was truncated or reordered"
  fi
done

((FAILED)) && exit 1
exit 0
