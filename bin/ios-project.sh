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

# The app's own push handling, as a JSON array of {signal, file, detail}: a
# notification callback that does more than forward to Iterable, a Notification
# Service Extension that hands back content itself, or another push SDK.
# Iterable-only wiring, including an `itbl` branch, is not a signal.
ios_project_existing_push() {
  local root="$1" scan_root
  scan_root="$(ios_project_ios_dir "$root")"
  [[ -n "$scan_root" || -n "$(ios_project_js_kind "$root")" ]] || scan_root="$root"
  { [[ -z "$scan_root" ]] ||
      ios_project_find_native "$scan_root" \
        -name '*.swift' -o -name '*.m' -o -name '*.mm' -o -name '*.h' -o -name 'project.pbxproj' \
        -o -name 'project.yml' -o -name 'Package.swift' -o -name 'Podfile'
    true; } |
    node -e '
      const fs=require("fs"), path=require("path"), root=process.argv[1];
      const files=fs.readFileSync(0,"utf8").split("\0").filter(Boolean);
      const found=[], seen=new Set();
      const add=(signal,file,detail)=>{
        if (seen.has(signal+detail)) return;
        seen.add(signal+detail);
        found.push({signal,file:path.relative(root,file),detail});
      };
      // Comments go; string bodies stay (for "itbl") with brackets blanked so braces still pair.
      const strip=src=>{
        let out="", i=0;
        while (i<src.length) {
          if (src.startsWith("//",i)) { while (i<src.length && src[i]!=="\n") i++; continue; }
          if (src.startsWith("/*",i)) {
            const end=src.indexOf("*/",i+2), stop=end<0 ? src.length : end+2;
            out+=src.slice(i,stop).replace(/[^\n]/g," "); i=stop; continue;
          }
          if (src[i]==="\"") {
            const q=src.startsWith("\"\"\"",i) ? "\"\"\"" : "\"";
            let j=i+q.length;
            while (j<src.length && !src.startsWith(q,j) && (q.length===3 || src[j]!=="\n")) j+=src[j]==="\\" ? 2 : 1;
            out+=q+src.slice(i+q.length,j).replace(/[(){}\[\]]/g," ")+(src.startsWith(q,j) ? q : "");
            i=src.startsWith(q,j) ? j+q.length : j; continue;
          }
          out+=src[i++];
        }
        return out;
      };
      const statements=body=>{
        const out=[]; let cur="", depth=0;
        for (const ch of body) {
          if (ch==="(" || ch==="[") depth++;
          else if (ch===")" || ch==="]") depth=Math.max(0,depth-1);
          if (depth===0 && "\n;{}".includes(ch)) { if (cur.trim()) out.push(cur.trim()); cur=""; continue; }
          cur+=ch;
        }
        if (cur.trim()) out.push(cur.trim());
        return out;
      };
      const plumbing=[
        /Iterable|\bITB|itbl/,
        /^(return\s+)?(try\s+)?(await\s+)?(self\.)?(completionHandler|completion|handler|contentHandler|reply)\s*\??\s*\(/,
        /\bcontinuation\s*\.\s*resume\b/,
        /^(return\s+)?(super\s*\.|\[\s*super\b)/,
        /^(print|debugPrint|NSLog|os_log)\s*\(/,
        /^(self\.)?log(ger)?\b/i,
        /^(return\s+)?(try\s+)?(await\s+)?(Task|DispatchQueue\.[\w.]+\.async|MainActor\.run|with(Checked|Unsafe)(Throwing)?Continuation)\b/
      ];
      const keywords=new Set(["if","while","for","switch","guard","return","catch","case","available","sizeof","await","try"]);
      const acts=s=>[...s.matchAll(/([A-Za-z_]\w*)\s*\??\s*\(/g)].some(m=>!keywords.has(m[1])) ||
        /\[\s*[A-Za-z_][\w.]*\s+[A-Za-z_]/.test(s);
      const bodyAt=(code,open)=>{
        let depth=0;
        for (let i=open; i<code.length; i++) {
          if (code[i]==="{") depth++;
          else if (code[i]==="}" && --depth===0) return code.slice(open+1,i);
        }
        return code.slice(open+1);
      };
      const callbacks=[
        [/^application$/,/\bdidRegisterForRemoteNotificationsWithDeviceToken\b/,"didRegisterForRemoteNotificationsWithDeviceToken"],
        [/^application$/,/\bdidReceiveRemoteNotification\b/,"didReceiveRemoteNotification"],
        [/^userNotificationCenter$/,/\bwillPresent(Notification)?\b/,"userNotificationCenter willPresent"],
        [/^userNotificationCenter$/,/\bdidReceive(NotificationResponse)?\b/,"userNotificationCenter didReceive"]
      ];
      const providers=[
        ["Firebase Messaging",/\bFirebaseMessaging\b|\bFirebase\/Messaging\b|\bMessaging\.messaging\s*\(/],
        ["OneSignal",/\bOneSignal/],
        ["Airship",/\bAirship(Kit|Core)\b|\bUAirship\b|\bAirship\.takeOff\b/],
        ["Braze",/\bBrazeKit\b|\bAppboy/],
        ["CleverTap",/\bCleverTap/],
        ["MoEngage",/\bMoEngage/],
        ["Pushwoosh",/\bPushwoosh/]
      ];
      for (const file of files) {
        let src; try { src=fs.readFileSync(file,"utf8") } catch { continue }
        const base=path.basename(file);
        const code=/^(Podfile|project\.yml)$/.test(base) ? src.replace(/^\s*#.*$/gm,"") : strip(src);
        for (const [name,re] of providers) if (re.test(code)) add("push_sdk",file,`${name} is linked; it may own or swizzle the notification callbacks`);
        if (!/\.(swift|mm?)$/.test(base)) continue;
        const starts=/\bfunc\s+(application|userNotificationCenter)\s*\(|^[ \t]*-\s*\([^)]*\)\s*(application|userNotificationCenter)\s*:/gm;
        for (const m of code.matchAll(starts)) {
          const open=code.indexOf("{",m.index);
          if (open<0) continue;
          const signature=code.slice(m.index,open), owner=m[1]||m[2];
          const callback=callbacks.find(([o,label])=>o.test(owner) && label.test(signature));
          if (!callback) continue;
          if (statements(bodyAt(code,open)).some(s=>!plumbing.some(p=>p.test(s)) && acts(s)))
            add("notification_callback",file,`${callback[2]} does more than forward to Iterable`);
        }
        if (/\boverride\s+func\s+didReceive\s*\(\s*_\s+\w+\s*:\s*UNNotificationRequest|-\s*\(\s*void\s*\)\s*didReceiveNotificationRequest\s*:/.test(code) &&
            /\bcontentHandler\s*\??\s*\(/.test(code))
          add("notification_service_extension",file,"a Notification Service Extension that hands back content itself, so it also handles non-Iterable payloads");
      }
      let pkg={}; try { pkg=JSON.parse(fs.readFileSync(path.join(root,"package.json"),"utf8")) } catch {}
      const deps={...pkg.dependencies,...pkg.devDependencies};
      for (const [name,dep] of [
        ["Firebase Messaging","@react-native-firebase/messaging"],["OneSignal","react-native-onesignal"],
        ["OneSignal","onesignal-expo-plugin"],["Airship","@ua/react-native-airship"],["Braze","@braze/react-native-sdk"],
        ["CleverTap","clevertap-react-native"],["MoEngage","react-native-moengage"],["Pushwoosh","pushwoosh-react-native-plugin"],
        ["push-notification-ios","@react-native-community/push-notification-ios"],
        ["react-native-push-notification","react-native-push-notification"],
        ["react-native-notifications","react-native-notifications"],["expo-notifications","expo-notifications"]
      ]) if (dep in deps) add("push_sdk",path.join(root,"package.json"),`${name} (${dep}) is a dependency; it may own or swizzle the notification callbacks`);
      process.stdout.write(JSON.stringify(found));
    ' "$root" 2>/dev/null || printf '[]'
}
