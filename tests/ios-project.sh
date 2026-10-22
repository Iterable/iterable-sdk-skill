#!/usr/bin/env bash
# The shared iOS project resolver against native, bare React Native, and Expo
# trees: app root, Xcode project directory, framework, and Bundle ID.

set -uo pipefail
cd "$(dirname "$0")/.." || exit
REPO="$PWD"

FAILED=0
ok()  { printf 'PASS %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; [[ $# -lt 2 ]] || printf '  %s\n' "$2"; FAILED=1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/iterable-ios-project.XXXXXX")"
case "$ROOT" in
  "${TMPDIR:-/tmp}"/iterable-ios-project.*|/private/tmp/iterable-ios-project.*) ;;
  *) echo "refusing unexpected temporary path: $ROOT" >&2; exit 1 ;;
esac
trap 'rm -rf "$ROOT"' EXIT
ROOT="$(cd "$ROOT" && pwd -P)"

pbxproj() {
  mkdir -p "$1"
  printf '// !$*UTF8*$!\n{ buildSettings = { PRODUCT_BUNDLE_IDENTIFIER = %s; }; }\n' "$2" > "$1/project.pbxproj"
}

NATIVE="$ROOT/native"
pbxproj "$NATIVE/Native.xcodeproj" com.example.native
mkdir -p "$NATIVE/Native/Sources"
git -C "$NATIVE" init -q

RN="$ROOT/rn"
mkdir -p "$RN/ios" "$RN/src"
printf '{"name":"rnapp","dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0"}}\n' > "$RN/package.json"
pbxproj "$RN/ios/RNApp.xcodeproj" com.example.rnapp
pbxproj "$RN/node_modules/@iterable/react-native-sdk/ios/RNIterableAPI.xcodeproj" com.iterable.decoy
mkdir -p "$RN/node_modules/@iterable/react-native-sdk/ios/RNIterableAPI" "$RN/node_modules/@iterable/react-native-sdk/src"
cat > "$RN/node_modules/@iterable/react-native-sdk/ios/RNIterableAPI/ReactIterableAPI.swift" <<'EOF'
import IterableSDK
IterableAPI.initialize(apiKey: key, launchOptions: nil, config: config)
IterableAPI.email = email
IterableAPI.register(token: token)
EOF
cat > "$RN/node_modules/@iterable/react-native-sdk/src/Iterable.ts" <<'EOF'
Iterable.initialize(apiKey, config);
Iterable.setEmail(email);
EOF
cat > "$RN/src/App.tsx" <<'EOF'
import { Iterable, IterableConfig } from '@iterable/react-native-sdk';
export function start(key: string, email: string) {
  Iterable.initialize(key, new IterableConfig());
  Iterable.setEmail(email);
}
EOF
mkdir -p "$RN/ios/RNApp"
cat > "$RN/ios/RNApp/AppDelegate.swift" <<'EOF'
import IterableSDK
func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
  IterableAPI.register(token: deviceToken)
}
EOF
git -C "$RN" init -q

DECOY="$ROOT/rn-decoy"
mkdir -p "$DECOY/src" "$DECOY/ios/Decoy" "$DECOY/node_modules/@iterable/react-native-sdk/src" \
  "$DECOY/node_modules/@iterable/react-native-sdk/ios"
printf '{"dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0"}}\n' > "$DECOY/package.json"
pbxproj "$DECOY/ios/Decoy.xcodeproj" com.example.decoy
cp "$RN/node_modules/@iterable/react-native-sdk/src/Iterable.ts" "$DECOY/node_modules/@iterable/react-native-sdk/src/"
cp "$RN/node_modules/@iterable/react-native-sdk/ios/RNIterableAPI/ReactIterableAPI.swift" \
  "$DECOY/node_modules/@iterable/react-native-sdk/ios/"
cat > "$DECOY/src/SignIn.tsx" <<'EOF'
const [email, setEmail] = useState('');
setEmail(value);
setUserId(value);
  // Iterable.initialize(key, config);
   * Iterable.setUserId(id)
EOF
printf '    // IterableAPI.register(token: deviceToken)\n' > "$DECOY/ios/Decoy/AppDelegate.swift"
git -C "$DECOY" init -q

OBJC="$ROOT/rn-objc"
mkdir -p "$OBJC/ios/ObjC" "$OBJC/ios/ObjC.xcworkspace"
printf '{"dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0"}}\n' > "$OBJC/package.json"
pbxproj "$OBJC/ios/ObjC.xcodeproj" com.example.objc
printf '  [IterableAPI registerToken:deviceToken];\n' > "$OBJC/ios/ObjC/AppDelegate.mm"
printf 'await Iterable.initialize(key, config);\n' > "$OBJC/index.js"
git -C "$OBJC" init -q

EXPO="$ROOT/expo"
mkdir -p "$EXPO"
printf '{"name":"expoapp","dependencies":{"expo":"58.0.0","react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0","@iterable/expo-plugin":"1.0.0"}}\n' > "$EXPO/package.json"
printf '{"expo":{"name":"ExpoApp","ios":{"bundleIdentifier":"com.example.expoapp"},"plugins":[["@iterable/expo-plugin",{}]]}}\n' > "$EXPO/app.json"
printf "import { Iterable } from '@iterable/react-native-sdk';\nIterable.initialize(key, config);\n" > "$EXPO/App.tsx"
git -C "$EXPO" init -q

EXPO_OFF="$ROOT/expo-manual-push"
mkdir -p "$EXPO_OFF"
cp "$EXPO/package.json" "$EXPO/App.tsx" "$EXPO_OFF/"
printf '{"expo":{"ios":{"bundleIdentifier":"com.example.expooff"},"plugins":[["@iterable/expo-plugin",{"autoConfigurePushNotifications":false}]]}}\n' > "$EXPO_OFF/app.json"
git -C "$EXPO_OFF" init -q

PLAIN="$ROOT/plain-rn"
mkdir -p "$PLAIN/ios"
printf '{"dependencies":{"react-native":"0.88.0"}}\n' > "$PLAIN/package.json"
pbxproj "$PLAIN/ios/Plain.xcodeproj" com.example.plain

MONO="$ROOT/mono"
mkdir -p "$MONO/packages/mobile/ios"
printf '{"private":true,"workspaces":["packages/*"]}\n' > "$MONO/package.json"
printf '{"dependencies":{"react-native":"0.88.0"}}\n' > "$MONO/packages/mobile/package.json"
pbxproj "$MONO/packages/mobile/ios/Mobile.xcodeproj" com.example.mobile
git -C "$MONO" init -q

resolve() {
  (cd "$1" && bash -c 'source "$1/bin/ios-project.sh"; ios_project_json "$PWD"' _ "$REPO")
}
field() {
  node -e 'const v=JSON.parse(process.argv[1]); const f=v[process.argv[2]]; process.stdout.write(f==null?"":String(f))' "$1" "$2"
}
expect() {
  local name="$1" json="$2" root="$3" ios_dir="$4" framework="$5" bundle="${6:-}"
  if [[ "$(field "$json" app_root)" == "$root" && "$(field "$json" ios_dir)" == "$ios_dir" &&
        "$(field "$json" framework)" == "$framework" && "$(field "$json" expo_bundle_id)" == "$bundle" &&
        "$(field "$json" workspace)" == "$root/.iterable/ios" ]]; then
    ok "$name"
  else
    bad "$name" "$json"
  fi
}

expect "a native app resolves to its own root" "$(resolve "$NATIVE")" "$NATIVE" "$NATIVE" native
expect "a native app resolves from a source subdirectory" "$(resolve "$NATIVE/Native/Sources")" "$NATIVE" "$NATIVE" native
expect "a bare React Native app keeps its root and finds the project in ios/" "$(resolve "$RN")" "$RN" "$RN/ios" react-native
expect "starting inside ios/ resolves to the React Native root" "$(resolve "$RN/ios")" "$RN" "$RN/ios" react-native
expect "an Expo app with no ios/ uses app.json for its Bundle ID" "$(resolve "$EXPO")" "$EXPO" "" expo com.example.expoapp
expect "outside git, ios/ of a React Native app still resolves to its parent" "$(resolve "$PLAIN/ios")" "$PLAIN" "$PLAIN/ios" react-native
expect "a React Native package inside a monorepo resolves to the package" \
  "$(resolve "$MONO/packages/mobile/ios")" "$MONO/packages/mobile" "$MONO/packages/mobile/ios" react-native

mkdir -p "$ROOT/fakebin"
cat > "$ROOT/fakebin/xcrun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "simctl list devices --json") printf '{"devices":{}}\n' ;;
  *devicectl*) printf '{"result":{"devices":[]}}\n' ;;
  *) exit 2 ;;
esac
EOF
chmod +x "$ROOT/fakebin/xcrun"
proposed_bundle() {
  (cd "$1" && env PATH="$ROOT/fakebin:$PATH" IOS_WORKSPACE="$1/.iterable/ios" "$REPO/bin/ios-prepare-proof" status 2>/dev/null) |
    node -e 'let i="";process.stdin.on("data",c=>i+=c).on("end",()=>{try{process.stdout.write(String(JSON.parse(i).proposed?.bundle_id||""))}catch{}})'
}
[[ "$(proposed_bundle "$RN")" == com.example.rnapp ]] &&
  ok "React Native Bundle ID comes from ios/, not from a package in node_modules" ||
  bad "React Native Bundle ID detection" "$(proposed_bundle "$RN")"
[[ "$(proposed_bundle "$EXPO")" == com.example.expoapp ]] &&
  ok "Expo Bundle ID falls back to app.json when ios/ has not been generated" ||
  bad "Expo Bundle ID detection" "$(proposed_bundle "$EXPO")"
[[ "$(proposed_bundle "$NATIVE")" == com.example.native ]] &&
  ok "a native app's Bundle ID detection is unchanged" ||
  bad "native Bundle ID detection" "$(proposed_bundle "$NATIVE")"

inspect() {
  (cd "$1" && "$REPO/bin/ios-verify" inspect 2>/dev/null)
}
signals() {
  node -e '
    const v=JSON.parse(process.argv[1]), s=v.signals;
    process.stdout.write([v.framework,s.sdk_dependency,s.sdk_initialization,s.identity_wiring,s.push_wiring,v.next.kind].join(" "));
  ' "$1"
}
expect_signals() {
  local name="$1" json="$2" want="$3"
  [[ "$(signals "$json")" == "$want" ]] && ok "$name" || bad "$name" "got: $(signals "$json")"
}

rn_inspect="$(inspect "$RN")"
expect_signals "a React Native app's JS initialization, Iterable identity, and native token hook are all found" \
  "$rn_inspect" "react-native true true true true prepare_proof"
node -e '
  const v=JSON.parse(process.argv[1]);
  process.exit(v.project_root===process.argv[2] && v.next.summary.includes("-configuration Release -sdk iphonesimulator") &&
    v.next.summary.includes("RNApp.xcodeproj") ? 0 : 1);
' "$rn_inspect" "$RN" &&
  ok "inspect tells a React Native app the proof needs a Release Simulator build, with the command" ||
  bad "inspect did not name the Release Simulator build" "$rn_inspect"
expect_signals "the SDK's sources in node_modules, React state setters, and commented calls are not signals" \
  "$(inspect "$DECOY")" "react-native true false false false review_integration"
objc_inspect="$(inspect "$OBJC")"
[[ "$(node -e 'process.stdout.write(String(JSON.parse(process.argv[1]).signals.push_wiring))' "$objc_inspect")" == true &&
    "$objc_inspect" == *'-workspace ObjC.xcworkspace -scheme ObjC'* ]] &&
  ok "an Objective-C++ registerToken: hook counts, and the build command uses the workspace" ||
  bad "the Objective-C++ hook or workspace build command was missed" "$objc_inspect"
expo_inspect="$(inspect "$EXPO")"
expect_signals "an Expo app's @iterable/expo-plugin entry counts as its native push wiring" \
  "$expo_inspect" "expo true true false true prepare_proof"
expect_signals "an Expo plugin with autoConfigurePushNotifications false is not push wiring" \
  "$(inspect "$EXPO_OFF")" "expo true true false false prepare_proof"
[[ "$expo_inspect" == *'npx expo prebuild --platform ios'* ]] &&
  ok "an Expo app with no ios/ is told to prebuild before the Release build" ||
  bad "the Expo prebuild step is missing" "$expo_inspect"
warning_kinds() {
  node -e 'process.stdout.write(JSON.parse(process.argv[1]).warnings.map(w=>w.kind).join(","))' "$1"
}
[[ "$(warning_kinds "$expo_inspect")" == expo_push_permission_not_requested &&
    "$expo_inspect" == *'PITFALLS.md#14'* ]] &&
  ok "an Expo plugin that never asks for notification permission is warned about, naming pitfall 14" ||
  bad "the Expo permission warning is missing" "$expo_inspect"
EXPO_ASKS="$ROOT/expo-plugin-asks"
mkdir -p "$EXPO_ASKS"
cp "$EXPO/package.json" "$EXPO/App.tsx" "$EXPO_ASKS/"
printf '{"expo":{"ios":{"bundleIdentifier":"com.example.expoasks"},"plugins":[["@iterable/expo-plugin",{"requestPermissionsForPushNotifications":true}]]}}\n' > "$EXPO_ASKS/app.json"
git -C "$EXPO_ASKS" init -q
[[ -z "$(warning_kinds "$(inspect "$EXPO_ASKS")")" ]] &&
  ok "no permission warning when the Expo plugin is set to ask" ||
  bad "the permission warning fired although the plugin asks" "$(inspect "$EXPO_ASKS")"
EXPO_JS_ASKS="$ROOT/expo-js-asks"
mkdir -p "$EXPO_JS_ASKS/src" "$EXPO_JS_ASKS/node_modules/expo-notifications"
cp "$EXPO/package.json" "$EXPO/app.json" "$EXPO/App.tsx" "$EXPO_JS_ASKS/"
printf 'await Notifications.requestPermissionsAsync();\n' > "$EXPO_JS_ASKS/node_modules/expo-notifications/index.js"
git -C "$EXPO_JS_ASKS" init -q
[[ "$(warning_kinds "$(inspect "$EXPO_JS_ASKS")")" == expo_push_permission_not_requested ]] &&
  ok "a permission request inside node_modules does not silence the warning" ||
  bad "node_modules silenced the permission warning" "$(inspect "$EXPO_JS_ASKS")"
printf "const { status } = await Notifications.requestPermissionsAsync();\n" > "$EXPO_JS_ASKS/src/permissions.ts"
[[ -z "$(warning_kinds "$(inspect "$EXPO_JS_ASKS")")" ]] &&
  ok "no permission warning when the app's own JavaScript requests permission" ||
  bad "the permission warning ignored the app's own request call" "$(inspect "$EXPO_JS_ASKS")"
[[ -z "$(warning_kinds "$rn_inspect")" ]] &&
  ok "a bare React Native app gets no Expo permission warning" ||
  bad "a bare React Native app got the Expo permission warning" "$rn_inspect"

push_paths() {
  node -e '
    const v=JSON.parse(process.argv[1]), w=v.warnings.find(w=>w.kind==="existing_push_path");
    process.stdout.write([String(v.signals.existing_push_path),...(w?.evidence||[]).map(e=>`${e.signal}:${e.file}`).sort()].join(" "));
  ' "$1"
}
expect_push_paths() {
  local name="$1" json="$2" want="$3"
  [[ "$(push_paths "$json")" == "$want" ]] && ok "$name" || bad "$name" "got: $(push_paths "$json")"
}
skill_app_delegate() {
  awk '/^```swift$/{getline line; if (line ~ /^\/\/ AppDelegate\.swift/) {f=1; print line}; next} /^```$/{f=0} f' "$1"
}

COEXIST="$ROOT/coexist"
mkdir -p "$COEXIST/App" "$COEXIST/NotificationService"
printf 'name: Coexist\n' > "$COEXIST/project.yml"
cat > "$COEXIST/App/AppDelegate.swift" <<'EOF'
import UIKit
import IterableSDK
extension AppDelegate: UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        IterableAPI.register(token: deviceToken)
        Task {
            PushRelay.shared.registrationStatus.send(.tokenReceived(deviceToken))
        }
    }
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if notification.request.content.userInfo["itbl"] != nil {
            completionHandler([.banner, .list, .sound])
            return
        }
        guard let push = AppPush.decode(from: notification) else { completionHandler([]); return }
        completionHandler(push.options)
    }
}
EOF
cat > "$COEXIST/NotificationService/NotificationService.swift" <<'EOF'
import UserNotifications
import IterableAppExtensions
class NotificationService: UNNotificationServiceExtension {
    private var iterable: ITBNotificationServiceExtension?
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        if request.content.userInfo["itbl"] != nil {
            let iterable = ITBNotificationServiceExtension()
            self.iterable = iterable
            iterable.didReceive(request, withContentHandler: contentHandler)
            return
        }
        let content = request.content.mutableCopy() as! UNMutableNotificationContent
        content.body = AppPush.decrypt(content.body)
        contentHandler(content)
    }
}
EOF
git -C "$COEXIST" init -q
expect_push_paths "an app's own callback handling and its own service extension are an existing push path" \
  "$(inspect "$COEXIST")" \
  "true notification_callback:App/AppDelegate.swift notification_callback:App/AppDelegate.swift notification_service_extension:NotificationService/NotificationService.swift"
coexist_warning="$(inspect "$COEXIST")"
[[ "$coexist_warning" == *'"kind":"existing_push_path"'* &&
    "$coexist_warning" == *'didRegisterForRemoteNotificationsWithDeviceToken does more than forward to Iterable'* &&
    "$coexist_warning" == *'userNotificationCenter willPresent does more than forward to Iterable'* &&
    "$coexist_warning" == *'keep these notifications alongside Iterable or use Iterable notifications only'* &&
    "$coexist_warning" == *'existing-push-coexistence in verification_limitations as an optional after-integration check'* ]] &&
  ok "the existing-push warning names each callback, the keep-or-replace question, and the optional check" ||
  bad "the existing-push warning is missing or vague" "$coexist_warning"

FCM="$ROOT/native-fcm"
mkdir -p "$FCM/App"
printf 'name: Fcm\n' > "$FCM/project.yml"
printf "target 'Fcm' do\n  pod 'Iterable-iOS-SDK'\n  pod 'Firebase/Messaging'\n  # pod 'OneSignal'\nend\n" > "$FCM/Podfile"
skill_app_delegate iterable-ios/SKILL.md > "$FCM/App/AppDelegate.swift"
git -C "$FCM" init -q
expect_push_paths "Firebase Messaging in the Podfile is an existing push path even with Iterable-only callbacks" \
  "$(inspect "$FCM")" "true push_sdk:Podfile"

RN_FCM="$ROOT/rn-fcm"
mkdir -p "$RN_FCM/ios" "$RN_FCM/src"
printf '{"dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0","@react-native-firebase/messaging":"23.0.0"}}\n' > "$RN_FCM/package.json"
pbxproj "$RN_FCM/ios/RnFcm.xcodeproj" com.example.rnfcm
cp "$RN/src/App.tsx" "$RN_FCM/src/"
git -C "$RN_FCM" init -q
expect_push_paths "@react-native-firebase/messaging in a React Native app is an existing push path" \
  "$(inspect "$RN_FCM")" "true push_sdk:package.json"

OBJC_PUSH="$ROOT/rn-objc-push"
mkdir -p "$OBJC_PUSH/ios/App"
printf '{"dependencies":{"react-native":"0.88.0","@iterable/react-native-sdk":"3.0.0"}}\n' > "$OBJC_PUSH/package.json"
pbxproj "$OBJC_PUSH/ios/App.xcodeproj" com.example.objcpush
cat > "$OBJC_PUSH/ios/App/AppDelegate.mm" <<'EOF'
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
  [IterableAPI registerToken:deviceToken];
  [RNCPushNotificationIOS didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}
EOF
git -C "$OBJC_PUSH" init -q
expect_push_paths "an Objective-C++ token callback that also feeds another library is an existing push path" \
  "$(inspect "$OBJC_PUSH")" "true notification_callback:ios/App/AppDelegate.mm"

ONLY="$ROOT/iterable-only"
mkdir -p "$ONLY/App" "$ONLY/NotificationService" "$ONLY/RichPush"
printf 'name: Only\n' > "$ONLY/project.yml"
skill_app_delegate iterable-ios/SKILL.md > "$ONLY/App/AppDelegate.swift"
cat > "$ONLY/App/Routing.swift" <<'EOF'
// import FirebaseMessaging
extension SceneRouter {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        guard response.notification.request.content.userInfo["itbl"] != nil else { return completionHandler() }
        print("Iterable push opened")
        IterableAppIntegration.userNotificationCenter(center,
                                                      didReceive: response,
                                                      withCompletionHandler: completionHandler)
    }
}
EOF
printf 'import IterableAppExtensions\n\nclass NotificationService: ITBNotificationServiceExtension {}\n' \
  > "$ONLY/NotificationService/NotificationService.swift"
cat > "$ONLY/RichPush/NotificationService.swift" <<'EOF'
import UserNotifications
import IterableAppExtensions
class RichNotificationService: UNNotificationServiceExtension {
    private let iterable = ITBNotificationServiceExtension()
    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        iterable.didReceive(request, withContentHandler: contentHandler)
    }
    override func serviceExtensionTimeWillExpire() {
        iterable.serviceExtensionTimeWillExpire()
    }
}
EOF
git -C "$ONLY" init -q
RN_BARE="$ROOT/rn-bare-skill"
mkdir -p "$RN_BARE/ios/App"
cp "$RN/package.json" "$RN_BARE/"
pbxproj "$RN_BARE/ios/App.xcodeproj" com.example.rnbare
skill_app_delegate iterable-react-native/SKILL.md > "$RN_BARE/ios/App/AppDelegate.swift"
git -C "$RN_BARE" init -q
if grep -q didRegisterForRemoteNotificationsWithDeviceToken "$ONLY/App/AppDelegate.swift" &&
    grep -q didRegisterForRemoteNotificationsWithDeviceToken "$RN_BARE/ios/App/AppDelegate.swift"; then
  expect_push_paths "Iterable-only wiring (the skill's app delegate, an itbl branch, both extension shapes) is not an existing push path" \
    "$(inspect "$ONLY")" "false"
  expect_push_paths "the React Native skill's bare iOS app delegate is not an existing push path" \
    "$(inspect "$RN_BARE")" "false"
else
  bad "the skills' AppDelegate.swift snippets could not be extracted"
fi
expect_push_paths "a React Native Swift token hook that only forwards to Iterable is not an existing push path" \
  "$rn_inspect" "false"
expect_push_paths "an Objective-C++ registerToken: line outside a callback is not an existing push path" \
  "$objc_inspect" "false"

native_inspect="$(inspect "$NATIVE")"
[[ "$(node -e 'process.stdout.write(JSON.parse(process.argv[1]).framework)' "$native_inspect")" == native &&
    "$native_inspect" != *Release* ]] &&
  ok "a native app reports framework native and gets no React Native build advice" ||
  bad "a native app reported the wrong framework" "$native_inspect"

# The temporary ITBL_PROOF identity marker is proof scaffolding: inspect names it
# until it is removed, in native code and in a React Native app's native code.
cat > "$NATIVE/Native/Sources/IterableProofMarker.swift" <<'EOF'
import os
func logProof(_ identity: String) { os_log("ITBL_PROOF identity=%{public}@", identity) }
EOF
marked="$(inspect "$NATIVE")"
cat > "$RN/ios/RNApp/ProofMarker.swift" <<'EOF'
import os
func logProof(_ identity: String) { os_log("ITBL_PROOF identity=%{public}@", identity) }
EOF
rn_marked="$(inspect "$RN")"
rm "$NATIVE/Native/Sources/IterableProofMarker.swift" "$RN/ios/RNApp/ProofMarker.swift"
cleared="$(inspect "$NATIVE")"
if [[ "$(warning_kinds "$marked")" == proof_identity_marker_present &&
      "$(warning_kinds "$rn_marked")" == proof_identity_marker_present &&
      "$marked" == *'Native/Sources/IterableProofMarker.swift'* &&
      "$rn_marked" == *'ios/RNApp/ProofMarker.swift'* &&
      -z "$(warning_kinds "$cleared")" ]]; then
  ok "inspect warns proof_identity_marker_present while ITBL_PROOF is in the source, and stops once it is removed"
else
  bad "the proof marker warning is missing or outlives the marker" "$(warning_kinds "$marked") / $(warning_kinds "$rn_marked") / $(warning_kinds "$cleared")"
fi

cat > "$ROOT/fakebin/xcrun" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "simctl list devices --json")
    printf '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-27-0":[{"udid":"SIM-1","name":"iPhone 17","state":"Booted","isAvailable":true}]}}\n' ;;
  *devicectl*) printf '{"result":{"devices":[]}}\n' ;;
  *) exit 2 ;;
esac
EOF
confirm_screen() {
  local app="$1" app_path="${2:-}"
  mkdir -p "$app/.iterable/ios"
  node -e '
    require("fs").writeFileSync(process.argv[1], JSON.stringify({proof_mode:"behavioral",bundle_id:"com.example.rnapp",
      data_region:"US",identity_type:"email",device:"SIM-1",environment:"development",app_path:process.argv[2]}));
  ' "$app/.iterable/ios/proof-discovery.json" "$app_path"
  (cd "$app" && env PATH="$ROOT/fakebin:$PATH" IOS_WORKSPACE="$app/.iterable/ios" "$REPO/bin/ios-prepare-proof" status 2>/dev/null)
  rm -rf "$app/.iterable"
}
installed_confirm="$(confirm_screen "$RN")"
[[ "$installed_confirm" == *'"kind":"confirm_proof"'* &&
    "$installed_confirm" == *'the installed app must be a Release build'* &&
    "$installed_confirm" == *'-configuration Release -sdk iphonesimulator'* ]] &&
  ok "the React Native confirm screen says the installed app must be a Release Simulator build" ||
  bad "the React Native confirm screen did not state the Release build requirement" "$installed_confirm"
mkdir -p "$ROOT/RNApp.app"
debug_confirm="$(confirm_screen "$RN" "$ROOT/RNApp.app")"
[[ "$debug_confirm" == *'this app has no embedded main.jsbundle'* ]] &&
  ok "the React Native confirm screen flags a chosen Debug build before the run starts" ||
  bad "the React Native confirm screen accepted a Debug build silently" "$debug_confirm"
printf 'bundle\n' > "$ROOT/RNApp.app/main.jsbundle"
release_confirm="$(confirm_screen "$RN" "$ROOT/RNApp.app")"
[[ "$release_confirm" == *'"kind":"confirm_proof"'* && "$release_confirm" != *'Release build'* ]] &&
  ok "a chosen Release build needs no extra note on the confirm screen" ||
  bad "a Release build still drew the Debug warning" "$release_confirm"
native_confirm="$(confirm_screen "$NATIVE")"
[[ "$native_confirm" == *'"kind":"confirm_proof"'* && "$native_confirm" != *'Release build'* ]] &&
  ok "a native app's confirm screen has no React Native build note" ||
  bad "a native app's confirm screen mentioned a React Native build" "$native_confirm"

((FAILED)) && exit 1
exit 0
