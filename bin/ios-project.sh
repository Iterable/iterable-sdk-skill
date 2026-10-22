#!/usr/bin/env bash
# Shared answer to "where is the app, where is its Xcode project, and what kind
# of app is it" for every iOS actor. A native app keeps its Xcode project at the
# root; React Native keeps it in ios/; Expo may have no ios/ at all until
# prebuild. The verification workspace always lives at <app root>/.iterable/ios.

ios_project_looks_like_ios() {
  local candidate="$1"
  [[ -n "$candidate" && -d "$candidate" ]] || return 1
  [[ -f "$candidate/project.yml" ]] ||
    compgen -G "$candidate/*.xcodeproj/project.pbxproj" >/dev/null ||
    compgen -G "$candidate/*.xcworkspace" >/dev/null
}

# Prints react-native, expo, or nothing for a directory's package.json/app.json.
ios_project_js_kind() {
  local dir="$1"
  [[ -f "$dir/package.json" || -f "$dir/app.json" ]] || return 0
  node -e '
    const fs=require("fs"), path=require("path"), dir=process.argv[1];
    const read=file=>{ try { return JSON.parse(fs.readFileSync(path.join(dir,file),"utf8")) } catch { return null } };
    const pkg=read("package.json")||{}, app=read("app.json");
    const deps={...pkg.dependencies,...pkg.devDependencies};
    if ("expo" in deps || (app && typeof app.expo==="object")) process.stdout.write("expo");
    else if ("react-native" in deps || "@iterable/react-native-sdk" in deps) process.stdout.write("react-native");
  ' "$dir" 2>/dev/null
}

# The app root: walking up from the start directory (no further than the git
# toplevel), the nearest React Native/Expo root, or the nearest iOS project
# that is not the ios/ folder of one.
ios_project_app_root() {
  local start="${1:-$PWD}" stop dir parent
  start="$(cd "$start" 2>/dev/null && pwd -P)" || return 1
  stop="$(cd "$start" && git rev-parse --show-toplevel 2>/dev/null)" || stop="/"
  stop="$(cd "$stop" 2>/dev/null && pwd -P)" || stop="/"
  dir="$start"
  while :; do
    if [[ -n "$(ios_project_js_kind "$dir")" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    if ios_project_looks_like_ios "$dir"; then
      parent="$(dirname "$dir")"
      if [[ "$(basename "$dir")" == ios && -n "$(ios_project_js_kind "$parent")" ]]; then
        printf '%s' "$parent"
      else
        printf '%s' "$dir"
      fi
      return 0
    fi
    [[ "$dir" != "$stop" && "$dir" != / ]] || break
    dir="$(dirname "$dir")"
  done
  [[ "$stop" != / ]] && printf '%s' "$stop" || printf '%s' "$start"
}

# The directory holding the Xcode or XcodeGen project: the app root itself, or
# its ios/ folder. Empty for an Expo app that has not been prebuilt.
ios_project_ios_dir() {
  local root="$1"
  if ios_project_looks_like_ios "$root"; then
    printf '%s' "$root"
  elif ios_project_looks_like_ios "$root/ios"; then
    printf '%s' "$root/ios"
  fi
}

ios_project_framework() {
  local kind
  kind="$(ios_project_js_kind "$1")"
  printf '%s' "${kind:-native}"
}

# Expo's ios/ is regenerated and often gitignored, so app.json is the source of
# its Bundle ID.
ios_project_expo_bundle_id() {
  local root="$1"
  [[ -f "$root/app.json" ]] || return 0
  node -e '
    let v; try { v=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")) } catch { process.exit(0) }
    const id=String(v?.expo?.ios?.bundleIdentifier||"");
    if (/^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/.test(id)) process.stdout.write(id);
  ' "$root/app.json" 2>/dev/null
}

ios_project_json() {
  local root ios_dir framework bundle
  root="$(ios_project_app_root "${1:-$PWD}")" || return 1
  ios_dir="$(ios_project_ios_dir "$root")"
  framework="$(ios_project_framework "$root")"
  bundle=""
  [[ "$framework" != expo ]] || bundle="$(ios_project_expo_bundle_id "$root")"
  node -e '
    const [root,iosDir,framework,bundle]=process.argv.slice(1);
    process.stdout.write(JSON.stringify({app_root:root,ios_dir:iosDir||null,framework,
      expo_bundle_id:bundle||null,workspace:`${root}/.iterable/ios`}));
  ' "$root" "$ios_dir" "$framework" "$bundle"
}

# A Debug React Native build for the Simulator skips embedding main.jsbundle
# and needs Metro; a Release build runs on its own.
ios_project_release_build_hint() {
  local root="$1" sdk="${2:-iphonesimulator}" ios_dir container flag name
  ios_dir="$(ios_project_ios_dir "$root")"
  if [[ -z "$ios_dir" ]]; then
    printf 'cd %q && npx expo prebuild --platform ios, then xcodebuild -workspace ios/<App>.xcworkspace -scheme <App> -configuration Release -sdk %s -derivedDataPath ios/build build' \
      "$root" "$sdk"
    return
  fi
  container="$(compgen -G "$ios_dir/*.xcworkspace" | head -1)"
  flag=-workspace
  if [[ -z "$container" ]]; then
    container="$(compgen -G "$ios_dir/*.xcodeproj" | head -1)"
    flag=-project
  fi
  name="$(basename "${container%.*}")"
  printf 'cd %q && xcodebuild %s %q -scheme %q -configuration Release -sdk %s -derivedDataPath build build (the app is %s/build/Build/Products/Release-%s/%s.app)' \
    "$ios_dir" "$flag" "$(basename "$container")" "$name" "$sdk" "$ios_dir" "$sdk" "$name"
}

# Source walks skip dependencies, build output, tests, and the verification
# workspace; inspect and the installed-app freshness check share them. The
# arguments are find predicates for the files wanted.
ios_project_find_native() {
  local root="$1"
  shift
  find "$root" \
    \( -path '*/.git' -o -path '*/.derived-data' -o -path '*/DerivedData' \
       -o -path '*/Pods' -o -path '*/.build' -o -path '*/node_modules' -o -path '*/build' \
       -o -path '*/.iterable' \
       -o -path '*/*Tests' -o -path '*/*Tests/*' \
       -o -path '*/*UITests' -o -path '*/*UITests/*' \) -prune -o \
    \( "$@" \) -type f -print0 2>/dev/null
}

ios_project_find_js() {
  local root="$1"
  shift
  find "$root" \
    \( -path "$root/ios" -o -path "$root/android" -o -path '*/node_modules' \
       -o -path '*/.git' -o -path '*/.expo' -o -path '*/build' -o -path '*/dist' \
       -o -path '*/.iterable' \
       -o -path '*/coverage' -o -path '*/__tests__' -o -path '*/__mocks__' -o -path '*/e2e' \) -prune -o \
    \( "$@" \) ! -name '*.test.*' ! -name '*.spec.*' -type f -print0 2>/dev/null
}

# The app's own push handling, as a JSON array of {signal, file, detail}; see
# existing-push.js for the signals.
ios_project_existing_push() {
  local root="$1" scan_root
  scan_root="$(ios_project_ios_dir "$root")"
  [[ -n "$scan_root" || -n "$(ios_project_js_kind "$root")" ]] || scan_root="$root"
  { [[ -z "$scan_root" ]] ||
      ios_project_find_native "$scan_root" \
        -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name 'project.pbxproj' \
        -o -name 'project.yml' -o -name 'Package.swift' -o -name 'Podfile'
    true; } |
    node "$(dirname "${BASH_SOURCE[0]}")/existing-push.js" scan ios "$root" 2>/dev/null || printf '[]'
}
