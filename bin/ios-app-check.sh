#!/usr/bin/env bash
# Integrity reads of an installed or recorded .app: does it carry the Iterable
# SDK and the push entitlement, is it the recorded build, and was it built
# after the latest source edit. Needs ios-project.sh and ios-simulator.sh.

# Prints the evidence of the native SDK, or fails. The SDK loads its Core Data
# model from its resource bundle, so every build that links it ships one.
ios_app_sdk_signal() {
  local app="$1" candidate
  for candidate in IterableSDKResources.bundle IterableSDK_IterableSDK.bundle \
      Frameworks/IterableSDK.framework; do
    [[ ! -d "$app/$candidate" ]] || { printf '%s' "$candidate"; return 0; }
  done
  return 1
}

# The JavaScript package reaches native code only through this TurboModule
# name, so it survives minification and Hermes compilation.
ios_app_js_has_sdk() {
  LC_ALL=C grep -aFq RNIterableAPI "$1/main.jsbundle" 2>/dev/null
}

ios_app_executable() {
  local name
  name="$(plutil -extract CFBundleExecutable raw -o - "$1/Info.plist" 2>/dev/null)" &&
    [[ -n "$name" && -f "$1/$name" ]] || return 1
  printf '%s' "$1/$name"
}

ios_app_simulator_aps_environment() {
  local executable entitlements
  executable="$(ios_app_executable "$1")" || return 1
  entitlements="$(ios_simulator_executable_entitlements "$executable")" || return 1
  printf '%s' "$entitlements" | plutil -extract aps-environment raw -o - - 2>/dev/null
}

ios_app_time() {
  date -u -r "$1" '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null || printf '%s' "$1"
}

# The newest native binary in the app. An edit to an extension's or embedded
# framework's source relinks only that binary, not the main executable.
ios_app_newest_binary() {
  local app="$1" main
  main="$(ios_app_executable "$app")" || return 1
  { printf '%s\0' "$main"
    find "$app/PlugIns" "$app/Frameworks" -mindepth 2 -maxdepth 2 -type f -perm -100 -print0 2>/dev/null
  } | xargs -0 stat -f '%m%t%N' 2>/dev/null | sort -n | tail -1 | cut -f2-
}

# Prints "<epoch>\t<source>" for the newest source newer than the reference
# file, or nothing.
ios_app_newer_source() {
  local root="$1" reference="$2" kind="$3" scan_root
  if [[ "$kind" == js ]]; then
    ios_project_find_js "$root" \
      \( -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \) -newer "$reference"
  else
    scan_root="$(ios_project_ios_dir "$root")"
    [[ -z "$scan_root" ]] ||
      ios_project_find_native "$scan_root" \
        \( -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.c' -o -name '*.cc' -o -name '*.cpp' \) \
        -newer "$reference"
  fi | xargs -0 stat -f '%m%t%N' 2>/dev/null | sort -n | tail -1
}

ios_app_rebuild_fix() {
  local root="$1" bin="$2"
  printf 'Build Release with signing on (never CODE_SIGNING_ALLOWED=NO, which drops the aps-environment entitlement push needs): %s. Then record that exact .app with %s/ios-prepare-proof restart --confirm --app-path <that .app> and install it with %s/ios-install.' \
    "$(ios_project_release_build_hint "$root" iphonesimulator)" "$bin" "$bin"
}

# ios_app_installed_integrity <installed .app> <app root> <framework>
#   <environment> <recorded .app or ""> <check aps: true|false> <bin dir>
# On failure prints "<diagnosis>\t<summary>" and returns 1; on success prints
# the evidence.
ios_app_installed_integrity() {
  local app="$1" root="$2" framework="$3" environment="$4" recorded="$5"
  local check_aps="$6" bin="$7" fix sdk aps="" kind built newer
  local installed_executable recorded_executable
  fix="$(ios_app_rebuild_fix "$root" "$bin")"
  if [[ -n "$recorded" ]]; then
    installed_executable="$(ios_app_executable "$app")" || installed_executable=""
    recorded_executable="$(ios_app_executable "$recorded")" || {
      printf 'installed_app_differs_from_recorded_build\tThe recorded build %s has no readable executable, so the installed app cannot be tied to it. %s\n' \
        "$recorded" "$fix"
      return 1
    }
    if [[ -z "$installed_executable" ||
          "${installed_executable##*/}" != "${recorded_executable##*/}" ||
          "$(shasum -a 256 < "$installed_executable")" != "$(shasum -a 256 < "$recorded_executable")" ]] ||
        { [[ "$framework" != native ]] &&
          [[ "$(shasum -a 256 < "$app/main.jsbundle" 2>/dev/null)" != "$(shasum -a 256 < "$recorded/main.jsbundle" 2>/dev/null)" ]]; }; then
      printf 'installed_app_differs_from_recorded_build\tThe app installed on the Simulator is not byte-identical to the recorded build %s. Install the recorded build with %s/ios-install; if that build is not current either: %s\n' \
        "$recorded" "$bin" "$fix"
      return 1
    fi
  fi
  sdk="$(ios_app_sdk_signal "$app")" || {
    printf 'installed_app_without_sdk\tThe app installed on the Simulator has no Iterable iOS SDK (no IterableSDKResources.bundle, IterableSDK_IterableSDK.bundle, or Frameworks/IterableSDK.framework), so it is a build from before the integration. %s\n' \
      "$fix"
    return 1
  }
  if [[ "$framework" != native && ! -f "$app/main.jsbundle" ]]; then
    printf 'installed_app_without_sdk\tThe installed app has no embedded main.jsbundle, so it is a Debug build that runs only while Metro serves its JavaScript. %s\n' \
      "$fix"
    return 1
  fi
  if [[ "$framework" != native ]] && ! ios_app_js_has_sdk "$app"; then
    printf 'installed_app_without_sdk\tThe installed app'"'"'s main.jsbundle never references RNIterableAPI, so its JavaScript was bundled without @iterable/react-native-sdk; it is a build from before the integration. %s\n' \
      "$fix"
    return 1
  fi
  if [[ "$check_aps" == true ]]; then
    aps="$(ios_app_simulator_aps_environment "$app")" || {
      printf 'installed_app_missing_aps_environment\tThe app installed on the Simulator has no aps-environment entitlement, so iOS cannot register it for push; a build made with CODE_SIGNING_ALLOWED=NO or without the Push Notifications capability lacks it. %s\n' \
        "$fix"
      return 1
    }
    [[ "$aps" == "$environment" ]] || {
      printf 'installed_app_missing_aps_environment\tThe app installed on the Simulator uses aps-environment=%s, not %s. %s\n' \
        "$aps" "$environment" "$fix"
      return 1
    }
  fi
  for kind in native js; do
    if [[ "$kind" == native ]]; then
      built="$(ios_app_newest_binary "$app")"
    else
      [[ "$framework" != native ]] || continue
      built="$app/main.jsbundle"
    fi
    [[ -n "$built" && -f "$built" ]] || continue
    newer="$(ios_app_newer_source "$root" "$built" "$kind")"
    [[ -n "$newer" ]] || continue
    printf 'installed_app_older_than_source\tThe installed app is older than its source: %s was built at %s, but %s changed at %s. %s\n' \
      "${built#"$app"/}" "$(ios_app_time "$(stat -f '%m' "$built")")" \
      "${newer#*$'\t'}" "$(ios_app_time "${newer%%$'\t'*}")" "$fix"
    return 1
  done
  printf 'Iterable SDK via %s' "$sdk"
  [[ "$framework" == native ]] || printf ' and RNIterableAPI in main.jsbundle'
  [[ "$check_aps" != true ]] || printf '; aps-environment=%s' "$aps"
  printf '; built after the latest source edit\n'
}

# The same SDK read for a recorded artifact, before it is installed. Prints
# the reason and succeeds when the SDK is missing.
ios_app_artifact_without_sdk() {
  local app="$1" root="$2" framework="$3" sdk="$4" bin="$5" fix
  printf -v fix 'rebuild it with signing on (never CODE_SIGNING_ALLOWED=NO): %s, then record it with %s/ios-prepare-proof restart --confirm --app-path <that .app>' \
    "$(ios_project_release_build_hint "$root" "$sdk")" "$bin"
  if ! ios_app_sdk_signal "$app" >/dev/null; then
    printf 'the recorded .app has no Iterable iOS SDK (no IterableSDKResources.bundle, IterableSDK_IterableSDK.bundle, or Frameworks/IterableSDK.framework), so it was built before the integration; %s\n' "$fix"
  elif [[ "$framework" != native ]] && ! ios_app_js_has_sdk "$app"; then
    printf 'the recorded .app'"'"'s main.jsbundle never references RNIterableAPI, so its JavaScript was bundled without @iterable/react-native-sdk; %s\n' "$fix"
  else
    return 1
  fi
}
