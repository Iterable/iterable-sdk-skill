#!/usr/bin/env node
// Finds an app's own (non-Iterable) push handling in its source. Heuristic, like
// every source signal; Iterable-only wiring, including an `itbl` branch, is not one.
//
//   existing-push.js scan ios <app-root>       (NUL-separated file list on stdin)
//   existing-push.js scan android <app-root>   (walks the app root itself)
//   existing-push.js follow-up                 (a scan's JSON on stdin)
//
// `scan` prints a JSON array of {signal, file, detail}. `follow-up` prints the
// optional after-integration line for a done verdict, or nothing.
//
// iOS takes its list from ios_project_find_native so every iOS scan prunes alike.

"use strict";
const fs = require("fs");
const path = require("path");

// Comments go; string bodies stay (for "itbl") with brackets blanked so braces still pair.
function strip(src) {
  let out = "", i = 0;
  while (i < src.length) {
    if (src.startsWith("//", i)) { while (i < src.length && src[i] !== "\n") i++; continue; }
    if (src.startsWith("/*", i)) {
      const end = src.indexOf("*/", i + 2), stop = end < 0 ? src.length : end + 2;
      out += src.slice(i, stop).replace(/[^\n]/g, " "); i = stop; continue;
    }
    if (src[i] === "\"") {
      const q = src.startsWith("\"\"\"", i) ? "\"\"\"" : "\"";
      let j = i + q.length;
      while (j < src.length && !src.startsWith(q, j) && (q.length === 3 || src[j] !== "\n")) j += src[j] === "\\" ? 2 : 1;
      const closed = src.startsWith(q, j);
      out += q + src.slice(i + q.length, j).replace(/[(){}\[\]]/g, " ") + (closed ? q : "");
      i = closed ? j + q.length : j; continue;
    }
    out += src[i++];
  }
  return out;
}

function statements(body) {
  const out = []; let cur = "", depth = 0;
  for (const ch of body) {
    if (ch === "(" || ch === "[") depth++;
    else if (ch === ")" || ch === "]") depth = Math.max(0, depth - 1);
    if (depth === 0 && "\n;{}".includes(ch)) { if (cur.trim()) out.push(cur.trim()); cur = ""; continue; }
    cur += ch;
  }
  if (cur.trim()) out.push(cur.trim());
  return out;
}

const plumbing = [
  /Iterable|\bITB|itbl/,
  /^(return\s+)?(try\s+)?(await\s+)?(self\.)?(completionHandler|completion|handler|contentHandler|reply)\s*\??\s*\(/,
  /\bcontinuation\s*\.\s*resume\b/,
  /^(return\s+)?(super\s*\.|\[\s*super\b)/,
  /^(print|debugPrint|NSLog|os_log)\s*\(/,
  /^(self\.)?(log(ger)?|timber)\b/i,
  /^(return\s+)?(try\s+)?(await\s+)?(Task|DispatchQueue\.[\w.]+\.async|MainActor\.run|with(Checked|Unsafe)(Throwing)?Continuation)\b/
];
const keywords = new Set(["if", "while", "for", "switch", "when", "guard", "return", "catch", "case",
  "available", "sizeof", "await", "try", "synchronized"]);
const acts = s => [...s.matchAll(/([A-Za-z_]\w*)\s*\??\s*\(/g)].some(m => !keywords.has(m[1])) ||
  /\[\s*[A-Za-z_][\w.]*\s+[A-Za-z_]/.test(s);
const doesMore = body => statements(body).some(s => !plumbing.some(p => p.test(s)) && acts(s));

function bodyAt(code, open) {
  let depth = 0;
  for (let i = open; i < code.length; i++) {
    if (code[i] === "{") depth++;
    else if (code[i] === "}" && --depth === 0) return code.slice(open + 1, i);
  }
  return code.slice(open + 1);
}

const providers = {
  ios: [
    ["Firebase Messaging", /\bFirebaseMessaging\b|\bFirebase\/Messaging\b|\bMessaging\.messaging\s*\(/],
    ["OneSignal", /\bOneSignal/],
    ["Airship", /\bAirship(Kit|Core)\b|\bUAirship\b|\bAirship\.takeOff\b/],
    ["Braze", /\bBrazeKit\b|\bAppboy/],
    ["CleverTap", /\bCleverTap/],
    ["MoEngage", /\bMoEngage/],
    ["Pushwoosh", /\bPushwoosh/]
  ],
  // Not firebase-messaging: Iterable's own Android SDK depends on it.
  android: [
    ["OneSignal", /\bcom\.onesignal\b/i],
    ["Braze", /\bcom\.(braze|appboy)\b/],
    ["Airship", /\bcom\.urbanairship\b/],
    ["CleverTap", /\bcom\.clevertap\b/],
    ["MoEngage", /\bcom\.moengage\b/],
    ["Pushwoosh", /\bcom\.pushwoosh\b/]
  ]
};

const jsProviders = [
  ["Firebase Messaging", "@react-native-firebase/messaging"], ["OneSignal", "react-native-onesignal"],
  ["OneSignal", "onesignal-expo-plugin"], ["Airship", "@ua/react-native-airship"], ["Braze", "@braze/react-native-sdk"],
  ["CleverTap", "clevertap-react-native"], ["MoEngage", "react-native-moengage"], ["Pushwoosh", "pushwoosh-react-native-plugin"],
  ["push-notification-ios", "@react-native-community/push-notification-ios"],
  ["react-native-push-notification", "react-native-push-notification"],
  ["react-native-notifications", "react-native-notifications"], ["expo-notifications", "expo-notifications"]
];

function collector(root) {
  const found = [], seen = new Set();
  const add = (signal, file, detail) => {
    if (seen.has(signal + detail)) return;
    seen.add(signal + detail);
    found.push({ signal, file: path.relative(root, file), detail });
  };
  return { found, add };
}

function read(file) { try { return fs.readFileSync(file, "utf8") } catch { return null } }

function packageJson(root, add) {
  let pkg = {}; try { pkg = JSON.parse(fs.readFileSync(path.join(root, "package.json"), "utf8")) } catch {}
  const deps = { ...pkg.dependencies, ...pkg.devDependencies };
  for (const [name, dep] of jsProviders) if (dep in deps)
    add("push_sdk", path.join(root, "package.json"), `${name} (${dep}) is a dependency; it may own or swizzle the notification callbacks`);
}

function scanIos(root, files) {
  const { found, add } = collector(root);
  const callbacks = [
    [/^application$/, /\bdidRegisterForRemoteNotificationsWithDeviceToken\b/, "didRegisterForRemoteNotificationsWithDeviceToken"],
    [/^application$/, /\bdidReceiveRemoteNotification\b/, "didReceiveRemoteNotification"],
    [/^userNotificationCenter$/, /\bwillPresent(Notification)?\b/, "userNotificationCenter willPresent"],
    [/^userNotificationCenter$/, /\bdidReceive(NotificationResponse)?\b/, "userNotificationCenter didReceive"]
  ];
  for (const file of files) {
    const src = read(file); if (src == null) continue;
    const base = path.basename(file);
    const code = /^(Podfile|project\.yml)$/.test(base) ? src.replace(/^\s*#.*$/gm, "") : strip(src);
    for (const [name, re] of providers.ios) if (re.test(code)) add("push_sdk", file, `${name} is linked; it may own or swizzle the notification callbacks`);
    if (!/\.(swift|mm?)$/.test(base)) continue;
    const starts = /\bfunc\s+(application|userNotificationCenter)\s*\(|^[ \t]*-\s*\([^)]*\)\s*(application|userNotificationCenter)\s*:/gm;
    for (const m of code.matchAll(starts)) {
      const open = code.indexOf("{", m.index);
      if (open < 0) continue;
      const signature = code.slice(m.index, open), owner = m[1] || m[2];
      const callback = callbacks.find(([o, label]) => o.test(owner) && label.test(signature));
      if (callback && doesMore(bodyAt(code, open))) add("notification_callback", file, `${callback[2]} does more than forward to Iterable`);
    }
    if (/\boverride\s+func\s+didReceive\s*\(\s*_\s+\w+\s*:\s*UNNotificationRequest|-\s*\(\s*void\s*\)\s*didReceiveNotificationRequest\s*:/.test(code) &&
        /\bcontentHandler\s*\??\s*\(/.test(code))
      add("notification_service_extension", file, "a Notification Service Extension that hands back content itself, so it also handles non-Iterable payloads");
  }
  packageJson(root, add);
  return found;
}

const androidPrune = new Set(["build", "node_modules", ".git", ".gradle", ".iterable", ".idea", "ios"]);
function walkAndroid(dir, out) {
  let entries; try { entries = fs.readdirSync(dir, { withFileTypes: true }) } catch { return out }
  for (const e of entries) {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      if (androidPrune.has(e.name) || (path.basename(dir) === "src" && /^(test|androidTest)/.test(e.name))) continue;
      walkAndroid(full, out);
    } else if (/\.(kt|java|gradle|gradle\.kts|toml)$/.test(e.name) || e.name === "AndroidManifest.xml") {
      out.push(full);
    }
  }
  return out;
}

// A body's opening brace after the parameter list, or an expression body (`= …`) to the end of the line.
function functionBody(code, at) {
  let i = code.indexOf("(", at), depth = 0;
  for (; i < code.length; i++) {
    if (code[i] === "(") depth++;
    else if (code[i] === ")" && --depth === 0) break;
  }
  const rest = code.slice(i + 1), lead = rest.match(/^[^{=;]*/)[0], next = rest[lead.length];
  if (next === "{") return bodyAt(code, i + 1 + lead.length);
  if (next === "=") return rest.slice(lead.length + 1).split("\n")[0];
  return "";
}

function scanAndroid(root) {
  const { found, add } = collector(root);
  const files = walkAndroid(root, []);
  const forwardOnly = new Set(), manifests = [];
  for (const file of files) {
    const src = read(file); if (src == null) continue;
    if (path.basename(file) === "AndroidManifest.xml") { manifests.push([file, src]); continue; }
    const code = file.endsWith(".toml") ? src.replace(/^\s*#.*$/gm, "") : strip(src);
    for (const [name, re] of providers.android) if (re.test(code)) add("push_sdk", file, `${name} is linked; it may own or show pushes`);
    if (!/\.(kt|java)$/.test(file)) continue;
    for (const m of code.matchAll(/\bclass\s+(\w+)[^{]*?(:|\bextends)\s*(com\.google\.firebase\.messaging\.)?FirebaseMessagingService\b/g)) {
      const own = [...code.matchAll(/\b(fun|void)\s+(onMessageReceived|onNewToken)\s*\(/g)]
        .filter(f => doesMore(functionBody(code, f.index))).map(f => f[2]);
      if (own.length) add("messaging_service", file, `${m[1]} handles ${own.join(" and ")} itself, beyond forwarding to Iterable`);
      else forwardOnly.add(m[1]);
    }
  }
  for (const [file, src] of manifests) {
    const xml = src.replace(/<!--[\s\S]*?-->/g, "");
    for (const m of xml.matchAll(/<service\b([^>]*)>([\s\S]*?)<\/service>/g)) {
      const name = (m[1].match(/android:name\s*=\s*"([^"]+)"/) || [])[1] || "";
      if (!m[2].includes("com.google.firebase.MESSAGING_EVENT")) continue;
      if (/Iterable/.test(name) || forwardOnly.has(name.split(".").pop())) continue;
      add("messaging_event_filter", file, `${name || "a service"} receives com.google.firebase.MESSAGING_EVENT`);
    }
  }
  packageJson(root, add);
  return found;
}

function followUp(found) {
  if (!Array.isArray(found) || !found.length) return "";
  return `Iterable push is proven. The app also has its own push path (${found.map(f => `${f.detail} in ${f.file}`).join("; ")}). If the developer wants, offer the optional after-integration check that the app's own notifications still show.`;
}

const [command, platform, root] = process.argv.slice(2);
const stdin = () => { try { return fs.readFileSync(0, "utf8") } catch { return "" } };
if (command === "scan" && platform === "ios" && root) {
  process.stdout.write(JSON.stringify(scanIos(root, stdin().split("\0").filter(Boolean))));
} else if (command === "scan" && platform === "android" && root) {
  process.stdout.write(JSON.stringify(scanAndroid(root)));
} else if (command === "follow-up") {
  let found = []; try { found = JSON.parse(stdin()) } catch {}
  process.stdout.write(followUp(found));
} else {
  process.stderr.write("usage: existing-push.js scan ios|android <app-root> | follow-up\n");
  process.exit(2);
}
