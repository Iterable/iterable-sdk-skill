#!/usr/bin/env bash
# Opt-in (network + Xcode): every Swift snippet in iterable-ios/SKILL.md, and its
# Config/ files, build verbatim against the SDK version pipeline/config/ios.yml pins.
#
# The skill's promise is that its canonical integration compiles with a brand-new
# Xcode project's defaults. Nothing else holds it to that: a snippet edited by hand,
# or an SDK release that renames an API, reads exactly as well as a working one.
#
# Builds four targets in a throwaway project: SwiftUI in Swift 6 with Default Actor
# Isolation = MainActor (a new project) and with the default nonisolated (an existing
# project moved to Swift 6), UIKit with scenes plus the legacy app-delegate URL methods
# (Swift 5), and the Notification Service Extension. Fetches the SDK from GitHub, so
# run-all.sh only runs it with --all.

set -uo pipefail
cd "$(dirname "$0")/.."
REPO="$PWD"

FAILED=0
ok()  { printf '  \033[32mPASS\033[0m %s\n' "$1"; }
bad() { printf '  \033[31mFAIL\033[0m %-52s %s\n' "$1" "$2"; FAILED=1; }

echo
echo "  iOS skill snippets — built verbatim against the pinned SDK"
echo

for tool in xcodebuild xcodegen node; do
  command -v "$tool" >/dev/null 2>&1 || { echo "  SKIP — $tool is not installed"; exit 0; }
done

SDK_TAG="$(sed -n '/^sdk:/,/^[a-z]/s/^  tag: *//p' pipeline/config/ios.yml | head -1)"
[[ -n "$SDK_TAG" ]] || { bad "no sdk.tag in pipeline/config/ios.yml" "nothing to build against"; exit 1; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

read -r -d '' EXTRACT_JS <<'JS'
const fs = require("fs");
const path = require("path");
const [skill, out] = process.argv.slice(1);
const text = fs.readFileSync(skill, "utf8");
const fenced = (lang) => [...text.matchAll(new RegExp("```" + lang + "\\n([\\s\\S]*?)```", "g"))]
  .map((m) => m[1].replace(/^ {3}/gm, ""));
const one = (list, label, pred) => {
  const hits = list.filter(pred);
  if (hits.length !== 1) { console.log(`MISSING ${label} (${hits.length} matches)`); process.exit(2); }
  return hits[0];
};
const swift = fenced("swift"), plain = fenced("text"), xml = fenced("xml");
const w = (rel, body) => { fs.mkdirSync(path.dirname(path.join(out, rel)), { recursive: true }); fs.writeFileSync(path.join(out, rel), body); };

const integration = one(swift, "IterableIntegration.swift", (b) => b.startsWith("// IterableIntegration.swift"));
const appDelegate = one(swift, "AppDelegate.swift", (b) => b.startsWith("// AppDelegate.swift"));
const swiftUIApp = one(swift, "SwiftUI entry point", (b) => b.includes("@UIApplicationDelegateAdaptor"));
const scene = one(swift, "scene delegate methods", (b) => b.includes("func scene(_ scene: UIScene, willConnectTo"));
const legacyURLs = one(swift, "app-delegate URL methods", (b) => b.includes("restorationHandler: @escaping"));
const permission = one(swift, "permission request", (b) => b.includes("func requestNotificationPermission"));
const nse = one(swift, "Notification Service Extension", (b) => b.includes("ITBNotificationServiceExtension {}"));
const events = one(swift, "events and profiles", (b) => b.startsWith("IterableAPI.track(event:"));
const base = one(plain, "Config/Base.xcconfig", (b) => b.startsWith("ITERABLE_API_KEY =\n"));
const secrets = one(plain, "Config/Secrets.xcconfig", (b) => b.startsWith("ITERABLE_API_KEY = <mobile key>"));
const info = one(xml, "Config/Info.plist", (b) => b.includes("ITERABLE_API_KEY"));
const entitlements = one(xml, "App.entitlements", (b) => b.includes("aps-environment"));

// Only what the skill tells the developer to supply themselves.
const appStubs = 'import Foundation\nenum AppRouter { static func open(_ url: URL) -> Bool { true } }\n';

w("Config/Base.xcconfig", base);
w("Config/Secrets.xcconfig", secrets.replace("<mobile key>", "snippet-check-key"));
w("Config/Info.plist", info);
w("SwiftUIApp/App.entitlements", entitlements);
w("SwiftUIApp/IterableIntegration.swift", integration);
w("SwiftUIApp/AppDelegate.swift", appDelegate);
w("SwiftUIApp/ExampleApp.swift", swiftUIApp);
w("SwiftUIApp/Permission.swift", "import UIKit\nimport UserNotifications\n\n" + permission);
w("SwiftUIApp/Events.swift", "import IterableSDK\n\nfunc sampleEvents() {\n    let product = (id: \"42\", name: \"Mug\")\n"
  + events.trim().split("\n").map((l) => "    " + l).join("\n") + "\n}\n");
w("SwiftUIApp/Stubs.swift", appStubs + 'import SwiftUI\nstruct ContentView: View { var body: some View { Text("") } }\n');

// In the class body, not an extension: a signature that only "nearly matches" a
// requirement warns there and is silent in an extension.
const legacyBody = "\n" + legacyURLs.trim().split("\n").map((l) => (l ? "    " + l : l)).join("\n") + "\n}\n";
const uikitDelegate = appDelegate.replace("final class AppDelegate: NSObject, UIApplicationDelegate,",
  "@main\nfinal class AppDelegate: UIResponder, UIApplicationDelegate,").replace(/\}\s*$/, legacyBody);
if (!uikitDelegate.includes("@main") || !uikitDelegate.includes("restorationHandler")) {
  console.log("MISSING the AppDelegate declaration the UIKit variant rewrites"); process.exit(2);
}
const sceneBody = scene.trim().split("\n").map((l) => (l ? "    " + l : l)).join("\n")
  .replace("    // ...window setup...", "        guard let windowScene = scene as? UIWindowScene else { return }\n"
    + "        window = UIWindow(windowScene: windowScene)\n        window?.rootViewController = UIViewController()\n        window?.makeKeyAndVisible()");
w("UIKitApp/IterableIntegration.swift", integration);
w("UIKitApp/AppDelegate.swift", uikitDelegate);
w("UIKitApp/SceneDelegate.swift", "import UIKit\nimport IterableSDK\n\nfinal class SceneDelegate: UIResponder, UIWindowSceneDelegate {\n    var window: UIWindow?\n\n" + sceneBody + "\n}\n");
w("UIKitApp/Stubs.swift", appStubs);
w("NotificationService/NotificationService.swift", nse);
console.log("OK");
JS

EXTRACTED="$(node -e "$EXTRACT_JS" "$REPO/iterable-ios/SKILL.md" "$WORK")"
if [[ "$EXTRACTED" == OK ]]; then
  ok "$(printf '%-52s %s' "every snippet the check builds is in SKILL.md" "SDK $SDK_TAG")"
else
  bad "a snippet the check builds is missing" "$EXTRACTED"; echo; echo "  FAILED"; exit 1
fi

plist_dict() {
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">\n<plist version="1.0">\n<dict>\n%s\n</dict>\n</plist>\n' "$1"
}
mkdir -p "$WORK/UIKitConfig" "$WORK/NSEConfig"
plist_dict '<key>UIApplicationSceneManifest</key><dict><key>UIApplicationSupportsMultipleScenes</key><false/><key>UISceneConfigurations</key><dict><key>UIWindowSceneSessionRoleApplication</key><array><dict><key>UISceneConfigurationName</key><string>Default Configuration</string><key>UISceneDelegateClassName</key><string>$(PRODUCT_MODULE_NAME).SceneDelegate</string></dict></array></dict></dict>' \
  > "$WORK/UIKitConfig/Info.plist"
plist_dict '<key>NSExtension</key><dict><key>NSExtensionPointIdentifier</key><string>com.apple.usernotifications.service</string><key>NSExtensionPrincipalClass</key><string>$(PRODUCT_MODULE_NAME).NotificationService</string></dict>' \
  > "$WORK/NSEConfig/Info.plist"

cat > "$WORK/project.yml" <<EOF
name: SnippetCheck
options:
  bundleIdPrefix: com.example.snippetcheck
  deploymentTarget:
    iOS: "17.0"
packages:
  IterableSDK:
    url: https://github.com/Iterable/iterable-swift-sdk
    exactVersion: "$SDK_TAG"
settings:
  base:
    CODE_SIGNING_ALLOWED: "NO"
    GENERATE_INFOPLIST_FILE: "YES"
targets:
  SwiftUIApp:
    type: application
    platform: iOS
    sources: [SwiftUIApp]
    configFiles:
      Debug: Config/Base.xcconfig
      Release: Config/Base.xcconfig
    settings:
      base:
        SWIFT_VERSION: "6.0"
        SWIFT_DEFAULT_ACTOR_ISOLATION: MainActor
        SWIFT_APPROACHABLE_CONCURRENCY: "YES"
        SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY: "YES"
        INFOPLIST_FILE: Config/Info.plist
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: "YES"
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
        CODE_SIGN_ENTITLEMENTS: SwiftUIApp/App.entitlements
    dependencies:
      - package: IterableSDK
        product: IterableSDK
      - target: NotificationService
  SwiftUINonisolated:
    type: application
    platform: iOS
    sources: [SwiftUIApp]
    configFiles:
      Debug: Config/Base.xcconfig
      Release: Config/Base.xcconfig
    settings:
      base:
        SWIFT_VERSION: "6.0"
        INFOPLIST_FILE: Config/Info.plist
        INFOPLIST_KEY_UIApplicationSceneManifest_Generation: "YES"
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
    dependencies:
      - package: IterableSDK
        product: IterableSDK
  UIKitApp:
    type: application
    platform: iOS
    sources: [UIKitApp]
    settings:
      base:
        SWIFT_VERSION: "5.0"
        INFOPLIST_FILE: UIKitConfig/Info.plist
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
    dependencies:
      - package: IterableSDK
        product: IterableSDK
  NotificationService:
    type: app-extension
    platform: iOS
    sources: [NotificationService]
    settings:
      base:
        SWIFT_VERSION: "5.0"
        INFOPLIST_FILE: NSEConfig/Info.plist
        PRODUCT_BUNDLE_IDENTIFIER: com.example.snippetcheck.SwiftUIApp.NotificationService
    dependencies:
      - package: IterableSDK
        product: IterableAppExtensions
EOF

(cd "$WORK" && xcodegen generate --quiet) >/dev/null 2>&1 \
  || { bad "the throwaway project did not generate" "xcodegen failed"; echo; echo "  FAILED"; exit 1; }

build() {
  (cd "$WORK" && xcodebuild -project SnippetCheck.xcodeproj -scheme "$1" \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$WORK/dd" -clonedSourcePackagesDirPath "$WORK/spm" build) > "$WORK/$1.log" 2>&1
}
first_errors() { grep -E 'error:' "$WORK/$1.log" | grep -v '/spm/checkouts/' | sort -u | head -3; }

if build SwiftUIApp; then
  ok "SwiftUI app + NSE build (Swift 6, MainActor isolation)"
else
  bad "the SwiftUI snippets do not build" "Swift 6, MainActor isolation"
  first_errors SwiftUIApp | sed 's/^/        /'
fi

if build SwiftUINonisolated; then
  ok "SwiftUI app builds (Swift 6, default nonisolated)"
else
  bad "the SwiftUI snippets do not build" "Swift 6, default nonisolated"
  first_errors SwiftUINonisolated | sed 's/^/        /'
fi

if build UIKitApp; then
  ok "UIKit app with scenes and app-delegate URL methods builds"
else
  bad "the UIKit snippets do not build" "Swift 5, scenes"
  first_errors UIKitApp | sed 's/^/        /'
fi

# The build passes either way; the warning is the only sign UIKit will never call it.
nearly="$(grep -h 'nearly matches' "$WORK"/*.log | grep -v '/spm/checkouts/' | sort -u | head -3)"
if [[ -z "$nearly" ]]; then
  ok "no snippet only \"nearly matches\" a delegate requirement"
else
  bad "a snippet only nearly matches a requirement" "UIKit will never call it"
  printf '%s\n' "$nearly" | sed 's/^/        /'
fi

APP="$WORK/dd/Build/Products/Debug-iphonesimulator/SwiftUIApp.app"
if [[ -d "$APP/PlugIns/NotificationService.appex" ]]; then
  ok "the Notification Service Extension is embedded"
else
  bad "no NotificationService.appex in the app" "the NSE snippet did not ship"
fi

read_plist() { plutil -extract "$2" raw -o - "$1/Info.plist" 2>/dev/null; }
[[ "$(read_plist "$APP" ITERABLE_API_KEY)" == snippet-check-key ]] \
  && ok "the key reaches Info.plist from Config/Secrets.xcconfig" \
  || bad "ITERABLE_API_KEY did not reach Info.plist" "got '$(read_plist "$APP" ITERABLE_API_KEY)'"
[[ "$(read_plist "$APP" UIBackgroundModes.0)" == remote-notification ]] \
  && ok "UIBackgroundModes is merged from the partial Info.plist" \
  || bad "remote-notification is not in UIBackgroundModes" "the partial plist was not merged"

# A fresh clone has no Secrets.xcconfig; it must still build, with no key.
rm -f "$WORK/Config/Secrets.xcconfig"
if build SwiftUIApp && [[ -z "$(read_plist "$APP" ITERABLE_API_KEY)" ]]; then
  ok "a clone without Secrets.xcconfig builds with an empty key"
else
  bad "a clone without Secrets.xcconfig fails or keeps a key" "#include? should make it optional"
fi

echo
((FAILED)) && { echo "  FAILED"; exit 1; }
echo "  All good — the skill's snippets build as written."
