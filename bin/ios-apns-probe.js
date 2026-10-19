#!/usr/bin/env node
// Asks Apple directly whether it accepts pushes for this app on this device:
// one silent (content-available) push to the app's real APNs token, signed with
// the workspace's imported APNs key. It is a diagnostic, never delivery proof:
// SpringBoard drops content-available pushes on the Simulator, so nothing shows.
//
//   ios-apns-probe.js --workspace W --devices-root R --udid U --bundle B --environment development|production
//
// Prints one JSON classification. The device token and provider token are
// never printed or passed on a command line.

"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const http2 = require("http2");
const { registrationToken } = require("./ios-notify-read.js");

const IDENTIFIERS_URL = "https://developer.apple.com/account/resources/identifiers/list";
const KEYS_URL = "https://developer.apple.com/account/resources/authkeys/list";

function args(argv) {
  const out = {};
  for (let i = 0; i < argv.length; i += 2) {
    if (!argv[i].startsWith("--")) throw new Error(`unexpected argument ${argv[i]}`);
    out[argv[i].slice(2)] = argv[i + 1];
  }
  return out;
}

function result(status, classification, summary, extra = {}) {
  return {
    tool: "iterable-ios-apns-probe",
    contract: 1,
    status,
    classification,
    summary,
    diagnostic_only: true,
    note: "A silent APNs probe; it shows Apple's answer for this app and device and is never counted as delivery.",
    ...extra
  };
}

function classify(httpStatus, reason, ctx) {
  const { bundle, team, keyId, environment } = ctx;
  const host = environment === "production" ? "production" : "sandbox";
  const base = { http_status: httpStatus, reason: reason || null, apns_environment: host };
  if (httpStatus === 200) {
    return result("ready", "apple_push_ready",
      `Apple's ${host} APNs accepted a push for ${bundle} to this device's token.`, base);
  }
  if (reason === "TopicDisallowed") {
    return result("blocked", "app_id_push_disabled",
      `App ID ${bundle} isn't enabled for Push on team ${team}, or the APNs key ${keyId} is restricted to other Bundle IDs.`,
      { ...base, urls: [IDENTIFIERS_URL, KEYS_URL], steps: [
        `Open ${IDENTIFIERS_URL} and check that the team selector (top right) shows ${team}.`,
        `Open the identifier ${bundle}, tick Push Notifications, click Save, then Confirm.`,
        `Open ${KEYS_URL}, open key ${keyId}, and check that it is not restricted to other Bundle IDs (or use a team-scoped key).`,
        "Run the Apple check again."
      ] });
  }
  if (reason === "DeviceTokenNotForTopic") {
    return result("blocked", "bundle_id_mismatch",
      `This device token was issued to an app with a different Bundle ID than ${bundle}: the installed app, the proof target, and Iterable's push integration must use the same Bundle ID.`,
      { ...base, steps: [
        `Check PRODUCT_BUNDLE_IDENTIFIER of the installed build against ${bundle}.`,
        "Rebuild and reinstall if they differ, open the app so it registers again, then run the Apple check again."
      ] });
  }
  if (reason === "BadDeviceToken") {
    return result("blocked", "apns_environment_mismatch",
      `Apple's ${host} APNs does not recognise this device token: the app's aps-environment and the APNs environment disagree (sandbox vs production).`,
      { ...base, steps: [
        environment === "production"
          ? "A production proof needs a distribution-signed build (TestFlight or App Store) on a physical iPhone."
          : "A development proof needs a development-signed build (aps-environment=development); a Simulator is always sandbox.",
        "Rebuild with the matching signing, open the app so it registers again, then run the Apple check again."
      ] });
  }
  if (reason === "Unregistered") {
    return result("blocked", "device_token_unregistered",
      "Apple says this device token is no longer active for the app (it was reinstalled or notifications were reset).",
      { ...base, steps: ["Open the app signed in so it registers a fresh token, then run the Apple check again."] });
  }
  if (reason === "BadTopic" || reason === "MissingTopic") {
    return result("blocked", "bundle_id_mismatch", `APNs refused the topic ${bundle} (${reason}).`, base);
  }
  if (reason === "InvalidProviderToken" || reason === "ExpiredProviderToken" || reason === "MissingProviderToken") {
    return result("blocked", "apns_key_rejected",
      `APNs rejected the provider token (${reason}): the APNs key, its Key ID (${keyId}), or the Team ID (${team}) is wrong, or the key was revoked.`,
      { ...base, next_command_hint: "ios-provision question --kind replace_apns_key", urls: [KEYS_URL] });
  }
  if (httpStatus === 429 || httpStatus >= 500 || !httpStatus) {
    return result("inconclusive", "apns_unavailable",
      `Apple's APNs did not give a usable answer (${httpStatus ? `HTTP ${httpStatus}` : "no response"}${reason ? `, ${reason}` : ""}); try the Apple check again shortly.`, base);
  }
  return result("blocked", "apns_refused", `Apple's APNs refused the push (HTTP ${httpStatus}${reason ? `, ${reason}` : ""}).`, base);
}

function providerToken(keyPath, keyId, team) {
  const b64 = value => Buffer.from(JSON.stringify(value)).toString("base64url");
  const input = `${b64({ alg: "ES256", kid: keyId })}.${b64({ iss: team, iat: Math.floor(Date.now() / 1000) })}`;
  const key = crypto.createPrivateKey(fs.readFileSync(keyPath));
  const signature = crypto.sign("sha256", Buffer.from(input), { key, dsaEncoding: "ieee-p1363" });
  return `${input}.${signature.toString("base64url")}`;
}

function origin(environment) {
  if (process.env.ITERABLE_IOS_TEST_MODE === "1" && process.env.IOS_APNS_PROBE_ORIGIN) {
    return process.env.IOS_APNS_PROBE_ORIGIN;
  }
  return environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
}

function send(target, token, jwt, bundle) {
  return new Promise(resolve => {
    let settled = false;
    const done = value => { if (!settled) { settled = true; resolve(value); } };
    let client;
    try { client = http2.connect(target); } catch { return done({ status: 0 }); }
    const timer = setTimeout(() => { client.destroy(); done({ status: 0 }); }, 15000);
    client.on("error", () => { clearTimeout(timer); done({ status: 0 }); });
    const request = client.request({
      ":method": "POST",
      ":path": `/3/device/${token}`,
      authorization: `bearer ${jwt}`,
      "apns-topic": bundle,
      "apns-push-type": "background",
      "apns-priority": "5",
      "content-type": "application/json"
    });
    let status = 0, body = "";
    request.on("response", headers => { status = Number(headers[":status"]) || 0; });
    request.setEncoding("utf8");
    request.on("data", chunk => { body += chunk; });
    request.on("end", () => {
      clearTimeout(timer);
      client.close();
      let reason = "";
      try { reason = String(JSON.parse(body).reason || ""); } catch {}
      done({ status, reason });
    });
    request.on("error", () => { clearTimeout(timer); client.destroy(); done({ status: 0 }); });
    request.end(JSON.stringify({ aps: { "content-available": 1 } }));
  });
}

async function main() {
  const a = args(process.argv.slice(2));
  const bundle = String(a.bundle || "");
  const environment = a.environment === "production" ? "production" : "development";
  if (!/^[A-Za-z0-9.-]+$/.test(bundle)) throw new Error("unsafe bundle identifier");
  const metaPath = path.join(String(a.workspace || ""), "apns.json");
  if (!fs.existsSync(metaPath)) {
    return result("not_run", "no_apns_key", "This workspace has no imported APNs key, so Apple cannot be asked directly.");
  }
  let meta;
  try { meta = JSON.parse(fs.readFileSync(metaPath, "utf8")); } catch { meta = {}; }
  const keyId = String(meta.key_id || "");
  const team = String(meta.team_id || "");
  const keyPath = String(meta.key_path || "");
  if (!/^[A-Z0-9]{10}$/.test(keyId) || !/^[A-Z0-9]{10}$/.test(team) || !keyPath || !fs.existsSync(keyPath)) {
    return result("not_run", "apns_key_unreadable",
      "The imported APNs key, Key ID, or Team ID is missing or malformed; re-import the key before asking Apple.",
      { next_command_hint: "ios-provision question --kind replace_apns_key" });
  }
  const registration = registrationToken(String(a["devices-root"] || ""), String(a.udid || ""), bundle);
  if (!registration || !registration.token) {
    return result("not_run", "no_device_token",
      `${bundle} has not registered with APNs on this Simulator yet, so there is no token to ask Apple about. Open the app signed in with notifications allowed.`);
  }
  const ctx = { bundle, team, keyId, environment };
  let jwt;
  try { jwt = providerToken(keyPath, keyId, team); } catch {
    return result("not_run", "apns_key_unreadable", "The imported .p8 could not sign a provider token; re-import the key.",
      { next_command_hint: "ios-provision question --kind replace_apns_key" });
  }
  const answer = await send(origin(environment), registration.token.toString("hex"), jwt, bundle);
  jwt = null;
  return { ...classify(answer.status, answer.reason, ctx), probed_at: new Date().toISOString() };
}

if (require.main === module) {
  main()
    .then(out => process.stdout.write(JSON.stringify(out) + "\n"))
    .catch(error => {
      process.stderr.write(`ios-apns-probe: ${error.message}\n`);
      process.exit(1);
    });
}

module.exports = { classify };
