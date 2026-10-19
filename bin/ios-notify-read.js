#!/usr/bin/env node
// Reads a Simulator's own notification records and judges one proof send.
//
//   ios-notify-read.js store <devices-root> <udid> <bundle-id>
//   ios-notify-read.js log <bundle-id> --root <runtime-root> | --device [--since ISO]   (ndjson on stdin)
//   ios-notify-read.js judge                      (JSON {expect, store, events} on stdin)
//   ios-notify-read.js predicate <bundle-id>
//   ios-notify-read.js corroborate                (JSON {events, not_before} on stdin)
//   ios-notify-read.js readback-new | readback-check <code> <salt> <hash>
//
// Output never carries raw device tokens, nonces, or payload identities: only
// their SHA-256 digests, so the result can be written to a receipt as is.

"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");
const { execFileSync } = require("child_process");

const sha256 = value => crypto.createHash("sha256").update(String(value)).digest("hex");

function notificationDigest(identifier) {
  const hex = crypto.createHash("sha1").update(String(identifier)).digest("hex").toUpperCase();
  return `${hex.slice(0, 4)}-${hex.slice(4, 8)}`;
}

function readPlistXml(file) {
  const head = fs.readFileSync(file).subarray(0, 64).toString("utf8");
  if (head.startsWith("<?xml") || head.startsWith("<plist")) return fs.readFileSync(file, "utf8");
  return execFileSync("plutil", ["-convert", "xml1", "-o", "-", file], {
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
    stdio: ["ignore", "pipe", "ignore"]
  });
}

function decodeEntities(text) {
  return text.replace(/&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos);/gi, (_, entity) => {
    const named = { amp: "&", lt: "<", gt: ">", quot: '"', apos: "'" }[entity.toLowerCase()];
    if (named) return named;
    const code = entity[1] === "x" || entity[1] === "X"
      ? parseInt(entity.slice(2), 16)
      : parseInt(entity.slice(1), 10);
    return String.fromCodePoint(code);
  });
}

function parsePlistXml(xml) {
  const tokens = xml.match(/<\/?[A-Za-z]+[^>]*?\/?>|[^<]+/g) || [];
  let index = 0;
  const skip = () => {
    while (index < tokens.length &&
      (!tokens[index].startsWith("<") || /^<\?|^<!|^<plist|^<\/plist/.test(tokens[index]))) {
      index++;
    }
  };
  const text = closing => {
    let out = "";
    while (index < tokens.length && tokens[index] !== closing) out += tokens[index++];
    index++;
    return decodeEntities(out);
  };
  const value = () => {
    skip();
    const tag = tokens[index++];
    if (tag === "<dict/>") return {};
    if (tag === "<array/>") return [];
    if (tag === "<string/>") return "";
    if (tag === "<true/>") return true;
    if (tag === "<false/>") return false;
    if (tag === "<dict>") {
      const out = {};
      for (;;) {
        skip();
        if (tokens[index] === "</dict>") { index++; return out; }
        if (tokens[index] !== "<key>") throw new Error(`unexpected ${tokens[index]} in dict`);
        index++;
        const key = text("</key>");
        out[key] = value();
      }
    }
    if (tag === "<array>") {
      const out = [];
      for (;;) {
        skip();
        if (tokens[index] === "</array>") { index++; return out; }
        out.push(value());
      }
    }
    if (tag === "<string>") return text("</string>");
    if (tag === "<integer>") return Number(text("</integer>").trim());
    if (tag === "<real>") return Number(text("</real>").trim());
    if (tag === "<date>") return new Date(text("</date>").trim());
    if (tag === "<data>") return Buffer.from(text("</data>").replace(/\s+/g, ""), "base64");
    throw new Error(`unsupported plist element ${tag}`);
  };
  return value();
}

function unarchive(root) {
  if (!root || root.$archiver !== "NSKeyedArchiver" || !Array.isArray(root.$objects)) return root;
  const objects = root.$objects;
  const isUid = value => value && typeof value === "object" && !Array.isArray(value) &&
    !(value instanceof Date) && !Buffer.isBuffer(value) &&
    Object.keys(value).length === 1 && Number.isInteger(value["CF$UID"]);
  const resolve = (value, depth) => {
    if (depth > 64) return null;
    if (isUid(value)) value = objects[value["CF$UID"]];
    if (value === "$null") return null;
    if (Array.isArray(value)) return value.map(item => resolve(item, depth + 1));
    if (!value || typeof value !== "object" || value instanceof Date || Buffer.isBuffer(value)) {
      return value;
    }
    if (Array.isArray(value["NS.keys"])) {
      const out = {};
      value["NS.keys"].forEach((key, i) => {
        out[String(resolve(key, depth + 1))] = resolve(value["NS.objects"][i], depth + 1);
      });
      return out;
    }
    if (Array.isArray(value["NS.objects"])) return value["NS.objects"].map(item => resolve(item, depth + 1));
    if (typeof value["NS.time"] === "number") {
      return new Date(Date.UTC(2001, 0, 1) + value["NS.time"] * 1000);
    }
    if ("NS.string" in value) return String(resolve(value["NS.string"], depth + 1));
    if ("NS.bytes" in value) return resolve(value["NS.bytes"], depth + 1);
    if ("NS.data" in value) return resolve(value["NS.data"], depth + 1);
    const out = {};
    for (const [key, child] of Object.entries(value)) {
      if (key !== "$class") out[key] = resolve(child, depth + 1);
    }
    return out;
  };
  const top = root.$top && (root.$top.root ?? Object.values(root.$top)[0]);
  return resolve(top, 0);
}

function readArchive(file) {
  return unarchive(parsePlistXml(readPlistXml(file)));
}

function summarizeRecord(record) {
  const info = record.UNNotificationUserInfo && typeof record.UNNotificationUserInfo === "object"
    ? record.UNNotificationUserInfo : {};
  const identifier = String(record.AppNotificationIdentifier || "");
  const created = record.AppNotificationCreationDate instanceof Date
    ? record.AppNotificationCreationDate.toISOString() : null;
  const nonce = typeof info.iterableProofNonce === "string" ? info.iterableProofNonce : "";
  const templateId = Number(info.itbl && info.itbl.templateId);
  return {
    identifier,
    digest: identifier ? notificationDigest(identifier) : null,
    created,
    title: typeof record.AppNotificationTitle === "string" ? record.AppNotificationTitle : "",
    body: typeof record.AppNotificationMessage === "string" ? record.AppNotificationMessage : "",
    trigger_type: record.UNNotificationTriggerType == null ? null : String(record.UNNotificationTriggerType),
    marker: typeof info.iterableProofMarker === "string" ? info.iterableProofMarker : null,
    nonce_sha256: nonce ? sha256(nonce) : null,
    template_id: Number.isFinite(templateId) ? templateId : null,
    iterable_message_id_present: Boolean(info.itbl && info.itbl.messageId),
    simulator_target_bundle: Object.prototype.hasOwnProperty.call(info, "Simulator Target Bundle")
  };
}

function commandStore(devicesRoot, udid, bundle) {
  const root = path.join(devicesRoot, udid, "data", "Library", "UserNotifications");
  const out = { mapped: false, directory: null, records: [], registration: null };
  const library = path.join(root, "Library.plist");
  if (!fs.existsSync(library)) return out;
  const mapping = readArchive(library);
  const directory = mapping && typeof mapping === "object" ? mapping[bundle] : null;
  if (typeof directory !== "string" || !/^[A-Za-z0-9-]+$/.test(directory)) return out;
  out.mapped = true;
  out.directory = directory;
  const delivered = path.join(root, directory, "DeliveredNotifications.plist");
  if (fs.existsSync(delivered)) {
    const records = readArchive(delivered);
    out.records = (Array.isArray(records) ? records : []).filter(r => r && typeof r === "object")
      .map(summarizeRecord);
  }
  const registrationFile = path.join(root, directory, "PushRegistration.plist");
  if (fs.existsSync(registrationFile)) {
    const registration = readArchive(registrationFile) || {};
    const token = Buffer.isBuffer(registration.Token) ? registration.Token : null;
    out.registration = {
      environment: registration.Environment == null ? null : String(registration.Environment),
      token_bytes: token ? token.length : 0,
      token_sha256: token ? crypto.createHash("sha256").update(token).digest("hex") : null
    };
  }
  return out;
}

function predicate(bundle) {
  if (!/^[A-Za-z0-9.-]+$/.test(bundle)) throw new Error("unsafe bundle identifier");
  return [
    `(process == "apsd" AND subsystem == "com.apple.apsd" AND eventMessage CONTAINS "Received message for enabled topic '${bundle}'")`,
    `(process IN {"SpringBoard","usernotificationsd"} AND subsystem BEGINSWITH "com.apple.UserNotifications" AND ` +
      `(eventMessage CONTAINS "[${bundle}] " OR eventMessage CONTAINS "topic ${bundle} at" OR ` +
      `eventMessage CONTAINS "'${bundle}'" OR eventMessage CONTAINS "app ${bundle}"))`,
    `(process == "SpringBoard" AND subsystem == "com.apple.BannerKit" AND eventMessage CONTAINS "did appear as banner")`,
    `(process == "CoreSimulatorBridge" AND eventMessage CONTAINS "[${bundle}] ")`
  ].join(" OR ");
}

function eventTime(raw) {
  const match = String(raw || "").match(
    /^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}:\d{2}(?:\.\d+)?)([+-]\d{2}):?(\d{2})$/);
  if (!match) return null;
  const fraction = match[2].replace(/(\.\d{3})\d+$/, "$1");
  const value = Date.parse(`${match[1]}T${fraction}${match[3]}:${match[4]}`);
  return Number.isNaN(value) ? null : new Date(value).toISOString();
}

// The OS image a line came from, as a path inside the OS. On a Simulator the
// process must run from the selected device's own runtime root; raw /System/...
// processes are accepted only from a physical device's log. Shared-cache
// frameworks log their sender as raw /System/... on both, so a sender may be either.
function systemImage(raw, source, sender) {
  const value = String(raw || "");
  if (!value || value.split("/").includes("..")) return null;
  if (source && source.root) {
    const root = source.root.replace(/\/+$/, "");
    if (value.startsWith(`${root}/System/`)) return value.slice(root.length);
    return sender && value.startsWith("/System/") ? value : null;
  }
  if (source && source.device) return value.startsWith("/System/") ? value : null;
  return null;
}

const APSD = "/System/Library/PrivateFrameworks/ApplePushService.framework/apsd";
const SPRINGBOARD = "/System/Library/CoreServices/SpringBoard.app/SpringBoard";
const UN_CORE = "/System/Library/PrivateFrameworks/UserNotificationsCore.framework/UserNotificationsCore";
const UN_SERVER = "/System/Library/PrivateFrameworks/UserNotificationsServer.framework/UserNotificationsServer";
const BANNERKIT = "/System/Library/PrivateFrameworks/BannerKit.framework/BannerKit";
const USERNOTIFICATIONSD = /^\/System\/Library\/PrivateFrameworks\/UserNotificationsCore\.framework\/(Support\/)?usernotificationsd$/;

// Lines whose text claims a proof step but whose images are not the selected
// device's own are reported as unattributable rather than silently dropped.
function claimsProofStep(message, bundle, subsystem) {
  const prefix = `[${bundle}] `;
  if (subsystem === "com.apple.apsd") return message.includes(`Received message for enabled topic '${bundle}'`);
  return message.startsWith(prefix) &&
    /^\S+ (Received remote notification request|Saving notification|Delivered user visible push notification)/.test(message);
}

function classify(entry, bundle, source) {
  const event = classifyAttributed(entry, bundle, source);
  if (event) return event;
  const message = String(entry.eventMessage || "");
  return claimsProofStep(message, bundle, String(entry.subsystem || ""))
    ? { kind: "unattributable", t: eventTime(entry.timestamp) } : null;
}

function classifyAttributed(entry, bundle, source) {
  const message = String(entry.eventMessage || "");
  const processImage = systemImage(entry.processImagePath, source, false);
  const senderImage = systemImage(entry.senderImagePath, source, true);
  const processName = path.basename(String(entry.processImagePath || entry.process || ""));
  const subsystem = String(entry.subsystem || "");
  const t = eventTime(entry.timestamp);
  const quoted = bundle.replace(/\./g, "\\.");
  const prefix = `[${bundle}] `;
  const D = "([0-9A-F]{4}-[0-9A-F]{4})";
  let m;
  // Any process that logs a local add for this bundle marks the record as not from APNs.
  if (message.startsWith(prefix) &&
      (m = message.match(new RegExp(`^\\[${quoted}\\] Adding notification request ${D} to destinations`)))) {
    return { kind: "local_add", t, digest: m[1], process: processName };
  }
  if (processImage === APSD && senderImage === APSD && subsystem === "com.apple.apsd") {
    m = message.match(/Received message for enabled topic '([^']+)'/);
    if (!m || m[1] !== bundle) return null;
    const visible = /with payload '\{/.test(message);
    const marker = visible ? message.match(/iterableProofMarker = "?([^";\n]+)"?;/) : null;
    const nonce = visible ? message.match(/iterableProofNonce = "?([0-9A-Fa-f]{16,128})"?;/) : null;
    const template = visible ? message.match(/templateId = (\d+);/) : null;
    return {
      kind: "apns_received", t,
      payload_visible: visible,
      marker: marker ? marker[1] : null,
      nonce_sha256: nonce ? sha256(nonce[1]) : null,
      template_id: template ? Number(template[1]) : null
    };
  }
  const springBoard = processImage === SPRINGBOARD || USERNOTIFICATIONSD.test(processImage || "");
  if (!springBoard) return null;
  if (subsystem === "com.apple.BannerKit") {
    if (senderImage !== BANNERKIT) return null;
    m = message.match(/did appear as banner: .*?requestIdentifier: ([0-9A-Fa-f-]{36})/);
    return m ? { kind: "banner", t, identifier: m[1].toUpperCase(), digest: notificationDigest(m[1].toUpperCase()) } : null;
  }
  if (!subsystem.startsWith("com.apple.UserNotifications")) return null;
  if (senderImage === UN_CORE && message.startsWith(prefix)) {
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Received remote notification request ${D} \\[ waking: (\\d), hasAlertContent: (\\d)`)))) {
      return { kind: "remote_request", t, digest: m[1], alert: m[3] === "1" };
    }
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Saving notification ${D}: (YES|NO) \\[.*?shouldPresentAlert: (YES|NO)(?:.*?pipelineState: (\\w+))?`)))) {
      return { kind: "saved", t, digest: m[1], saved: m[2] === "YES", should_present: m[3] === "YES", pipeline: m[4] };
    }
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Delivered user visible push notification ${D}$`)))) {
      return { kind: "delivered", t, digest: m[1] };
    }
  }
  if (senderImage === UN_SERVER && message.startsWith(prefix)) {
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Received response (\\d+) for willPresentNotification for notification ${D}$`)))) {
      return { kind: "will_present", t, options: Number(m[1]), digest: m[2] };
    }
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Received response to ${D} for action com\\.apple\\.UNNotificationDefaultActionIdentifier`)))) {
      return { kind: "tapped", t, digest: m[1] };
    }
    if ((m = message.match(new RegExp(`^\\[${quoted}\\] Withdrawing notification ${D}$`)))) {
      return { kind: "withdrawn", t, digest: m[1] };
    }
  }
  if (message.startsWith(prefix) && /Not persisting notification .*not authorized/i.test(message)) {
    return { kind: "not_authorized", t };
  }
  const namesBundle = new RegExp(`(^|[^A-Za-z0-9.-])${quoted}([^A-Za-z0-9.-]|$)`).test(message);
  if (namesBundle && /Received incoming message for push (disabled|restricted) app/i.test(message)) {
    return { kind: "not_authorized", t };
  }
  if (namesBundle && /Received incoming message for (uninstalled|unregistered) app/i.test(message)) {
    return { kind: "not_registered", t };
  }
  if (message.startsWith(prefix) && /NOT delivering filtered push notification/i.test(message)) return { kind: "filtered", t };
  if (message.includes(`No valid 'aps-environment' entitlement string found for application '${bundle}'`)) {
    return { kind: "missing_entitlement", t };
  }
  if (message.startsWith(prefix) && /Content-available push notifications are only supported on-device/.test(message)) {
    return { kind: "content_available_unsupported", t };
  }
  if ((m = message.match(new RegExp(`^Received incoming message on topic ${quoted} at priority (\\d+)$`)))) {
    return { kind: "incoming", t, priority: Number(m[1]) };
  }
  return null;
}

// Streams `log show` output line by line: a long-booted Simulator can return far
// more than fits in one string. --since drops everything older than the proof
// window here too, so an ignored or misparsed --start cannot widen the window.
function commandLog(bundle, source, since) {
  const notBefore = since ? Date.parse(since) - 2000 : null;
  if (since && Number.isNaN(notBefore)) throw new Error("--since must be an ISO time");
  const events = [];
  let lines = 0;
  const rl = require("readline").createInterface({ input: process.stdin, crlfDelay: Infinity });
  rl.on("line", line => {
    if (!line.startsWith("{")) return;
    let entry;
    try { entry = JSON.parse(line); } catch { return; }
    if (!("eventMessage" in entry)) return;
    if (notBefore != null) {
      const t = eventTime(entry.timestamp);
      if (t == null || Date.parse(t) < notBefore) return;
    }
    lines++;
    const event = classify(entry, bundle, source);
    if (event) events.push(event);
  });
  return new Promise(resolve => rl.on("close", () => resolve({ lines, events })));
}

const NAMED = {
  injection_detected: "A record carrying this run's marker was added locally (simctl push or an app-scheduled notification), not delivered by APNs. It cannot prove delivery.",
  duplicate_delivery: "This run's marker arrived more than once, or with a nonce that is not this send's. Do not count it; review whether a second send happened before restarting the run.",
  suppressed_by_app: "APNs delivered this run's push, but the app was in the foreground and its willPresent handler suppressed it, so iOS neither showed nor stored it.",
  notifications_not_authorized: "APNs delivered this run's push, but notifications are not authorized for this app on the Simulator, so iOS did not show or store it.",
  arrived_not_stored: "APNs delivered this run's push to the Simulator, but iOS did not record it as saved and delivered.",
  unjoined_record: "A stored record carries this run's marker and nonce, but it is not the notification iOS created from this run's APNs delivery, so it cannot prove delivery.",
  payload_redacted: "The Simulator's apsd logged a push for this app with its payload redacted, so it cannot be tied to this run's send.",
  missing_aps_environment: "The installed app has no valid aps-environment entitlement, so the Simulator cannot receive remote pushes for it.",
  app_not_registered: "The Simulator received a push for this app while it was not registered for remote notifications.",
  never_reached_simulator: "No push for this app reached the Simulator from APNs in this window. Check that Iterable holds this Simulator's current device token, that the Iterable app's APNs push integration is the sandbox one with the right key and bundle, and that the send was accepted. If Iterable reports TopicDisallowed, the App ID is not registered for Push Notifications; DeviceTokenNotForTopic means the app's Bundle ID differs from the push integration's.",
  marker_without_nonce: "A notification carrying this run's marker arrived without this run's send nonce, so it was not produced by this run's send and cannot prove delivery.",
  ambiguous_delivery: "Another push for this app reached the Simulator alongside this run's, so the notification iOS created cannot be tied to this run's send with certainty.",
  log_unattributable: "The Simulator's log has lines for this app that do not come from the selected Simulator's own system images, so they cannot be attributed to it.",
  record_missing: "The log shows this run's delivery, but no stored record for it exists and nothing shows iOS removing it, so the stored step is unproved.",
  log_unavailable: "The Simulator's log could not be read for this window, so arrival cannot be judged from it."
};

// One chain proves one delivery: the apsd line that received this run's nonce,
// the very next SpringBoard request for the exact bundle (digest D), iOS saving
// D, and — at send time — the stored record whose identifier digests to D.
// requireRecord is false only for a later re-check, after the developer may
// have cleared Notification Center; then iOS must also have logged delivering D.
// require_record=false is the later re-check: the record may be gone only if this
// run's own receipt saw it in the store (receipt_digest) or iOS logged withdrawing it.
function judge({ expect, store, events, log_lines, log_ok, require_record, receipt_digest }) {
  const requireRecord = require_record !== false;
  const notBefore = Date.parse(expect.not_before) - 2000;
  const templateId = expect.template_id == null ? null : Number(expect.template_id);
  const inWindow = when => when != null && Date.parse(when) >= notBefore;
  const evts = (Array.isArray(events) ? events : []).filter(e => inWindow(e.t));
  const records = (store && Array.isArray(store.records) ? store.records : []);
  const carriesMarker = r => r.marker === expect.marker || r.body === expect.marker;
  const runRecords = records.filter(r => carriesMarker(r) && r.nonce_sha256 === expect.nonce_sha256 &&
    (templateId == null || r.template_id === templateId) && inWindow(r.created));
  const otherNonceRecords = records.filter(r => r.marker === expect.marker && r.nonce_sha256 !== expect.nonce_sha256);
  const apns = evts.filter(e => e.kind === "apns_received");
  const apnsForRun = apns.filter(e => e.payload_visible && e.nonce_sha256 === expect.nonce_sha256 &&
    (templateId == null || e.template_id === templateId));
  const apnsOtherNonce = apns.filter(e => e.payload_visible && e.marker === expect.marker &&
    e.nonce_sha256 !== expect.nonce_sha256);
  const byDigest = (kind, digest) => evts.filter(e => e.kind === kind && e.digest === digest);
  const requestAfter = when => evts.find(e => e.kind === "remote_request" && e.alert &&
    Date.parse(e.t) >= Date.parse(when) && Date.parse(e.t) - Date.parse(when) <= 2000);

  const result = {
    observed: false,
    evidence: { apns_received: false, os_stored: false, os_displayed: false },
    apns_binding: null,
    record: null,
    diagnosis: null,
    summary: null,
    local_injection_seen: evts.some(e => e.kind === "local_add")
  };
  const finish = diagnosis => {
    result.diagnosis = result.observed ? null : diagnosis;
    result.summary = result.observed
      ? `APNs delivered this run's push to the Simulator (payload nonce matched) and iOS stored it as ${result.record.digest}${result.evidence.os_displayed ? " and displayed it" : ""}.`
      : NAMED[result.diagnosis] || "This run's push was not observed.";
    return result;
  };

  const markerRecords = records.filter(r => carriesMarker(r) && inWindow(r.created));
  if (markerRecords.some(r => r.simulator_target_bundle || byDigest("local_add", r.digest).length)) {
    return finish("injection_detected");
  }
  if (log_ok === false) return finish("log_unavailable");
  if (runRecords.length > 1 || apnsForRun.length > 1 || otherNonceRecords.length || apnsOtherNonce.length) {
    return finish("duplicate_delivery");
  }
  if (!apnsForRun.length) {
    if (log_lines === 0) return finish("log_unavailable");
    if (evts.some(e => e.kind === "unattributable")) return finish("log_unattributable");
    if (apns.some(e => !e.payload_visible)) return finish("payload_redacted");
    if (runRecords.length) return finish("unjoined_record");
    if (markerRecords.length || apns.some(e => e.marker === expect.marker)) return finish("marker_without_nonce");
    if (evts.some(e => e.kind === "missing_entitlement")) return finish("missing_aps_environment");
    if (evts.some(e => e.kind === "not_registered")) return finish("app_not_registered");
    if (evts.some(e => e.kind === "not_authorized")) return finish("notifications_not_authorized");
    return finish("never_reached_simulator");
  }

  result.evidence.apns_received = true;
  result.apns_binding = "nonce";
  const arrival = Date.parse(apnsForRun[0].t);
  if (apns.some(e => e !== apnsForRun[0] && Math.abs(Date.parse(e.t) - arrival) <= 2000)) {
    return finish("ambiguous_delivery");
  }
  const request = requestAfter(apnsForRun[0].t);
  if (!request) {
    if (evts.some(e => e.kind === "unattributable")) return finish("log_unattributable");
    return finish(evts.some(e => e.kind === "not_authorized") ? "notifications_not_authorized" : "arrived_not_stored");
  }
  const digest = request.digest;
  if (evts.some(e => e.kind === "saved" && !e.saved && e.digest !== digest)) return finish("ambiguous_delivery");
  const record = runRecords[0];
  if (record && record.digest !== digest) return finish("unjoined_record");
  result.record = { digest, created: record ? record.created : request.t, source: record ? "store" : "log" };

  const saved = byDigest("saved", digest);
  const willPresent = byDigest("will_present", digest);
  const suppressed = saved.some(e => !e.saved) || willPresent.some(e => e.options === 0);
  const delivered = byDigest("delivered", digest).length > 0;
  result.evidence.os_displayed = !suppressed &&
    (evts.some(e => e.kind === "banner" && e.digest === digest) || delivered && saved.some(e => e.should_present));
  if (suppressed) {
    return finish(willPresent.length ? "suppressed_by_app" : "notifications_not_authorized");
  }
  const savedYes = saved.some(e => e.saved);
  const recordAccountedFor = receipt_digest === digest || byDigest("withdrawn", digest).length > 0;
  result.evidence.os_stored = savedYes && (record ? true : !requireRecord && delivered && recordAccountedFor);
  if (result.evidence.os_stored) {
    result.observed = true;
    return finish(null);
  }
  return finish(savedYes && delivered && !requireRecord ? "record_missing" : "arrived_not_stored");
}

function iterableDevices(user, bundle, tokenSha256) {
  const devices = (user && user.user && (user.user.dataFields && user.user.dataFields.devices || user.user.devices)) || [];
  const mine = (Array.isArray(devices) ? devices : []).filter(d =>
    d && (d.appPackageName === bundle || d.applicationName === bundle));
  const hashOf = device => {
    const token = String(device.token || "").replace(/\s+/g, "").toLowerCase();
    if (!/^[0-9a-f]+$/.test(token) || token.length % 2 !== 0) return null;
    return crypto.createHash("sha256").update(Buffer.from(token, "hex")).digest("hex");
  };
  const enabled = mine.filter(d => d.endpointEnabled === true);
  const hashes = enabled.map(hashOf);
  return {
    devices_for_bundle: mine.length,
    enabled: enabled.length,
    notifications_enabled: enabled.some(d => d.notificationsEnabled !== false),
    token_comparable: Boolean(tokenSha256) && hashes.length > 0 && hashes.every(Boolean),
    token_match: Boolean(tokenSha256) && hashes.includes(tokenSha256)
  };
}

// A physical iPhone's apsd payload is <private>, so the device log can only say
// that one alert push for the bundle arrived, was saved, and was delivered.
function corroborate({ events, not_before }) {
  const notBefore = Date.parse(not_before) - 2000;
  const windowEvents = (Array.isArray(events) ? events : []).filter(e => e.t == null || Date.parse(e.t) >= notBefore);
  const requests = windowEvents.filter(e => e.kind === "remote_request" && e.alert);
  const digests = [...new Set(requests.map(e => e.digest))];
  const digest = digests.length === 1 ? digests[0] : null;
  const saved = digest ? windowEvents.some(e => e.kind === "saved" && e.digest === digest && e.saved) : false;
  const delivered = digest ? windowEvents.some(e => e.kind === "delivered" && e.digest === digest) : false;
  const suppressed = digest ? windowEvents.some(e => e.kind === "saved" && e.digest === digest && !e.saved) : false;
  let verdict = "corroborated";
  if (digests.length > 1) verdict = "duplicate";
  else if (!digest) verdict = "missing";
  else if (!(saved && delivered)) verdict = suppressed ? "suppressed" : "incomplete";
  return { verdict, alert_requests: digests.length, digest, saved, delivered };
}

const READBACK_ALPHABET = "ACDEFHJKMNPRTUVWXY3479";
const SCRYPT = { N: 1 << 17, r: 8, p: 1, maxmem: 256 * 1024 * 1024 };

function normalizeCode(code) {
  return String(code || "").toUpperCase().replace(/[\s-]+/g, "");
}

function readbackHash(code, salt) {
  return crypto.scryptSync(normalizeCode(code), Buffer.from(salt, "hex"), 32, SCRYPT).toString("hex");
}

function readbackNew() {
  let code = "";
  while (code.length < 6) code += READBACK_ALPHABET[crypto.randomInt(READBACK_ALPHABET.length)];
  const salt = crypto.randomBytes(16).toString("hex");
  return {
    code,
    display: `${code.slice(0, 3)}-${code.slice(3)}`,
    salt,
    hash: readbackHash(code, salt),
    kdf: `scrypt-N${SCRYPT.N}-r${SCRYPT.r}-p${SCRYPT.p}`
  };
}

function readStdin() {
  try { return fs.readFileSync(0, "utf8"); } catch { return ""; }
}

function main(argv) {
  const [command, ...args] = argv;
  switch (command) {
    case "store":
      if (args.length !== 3) throw new Error("store needs <devices-root> <udid> <bundle-id>");
      return commandStore(args[0], args[1], args[2]);
    case "log": {
      const rest = args.slice();
      let since = null;
      const sinceAt = rest.indexOf("--since");
      if (sinceAt >= 0) {
        since = rest[sinceAt + 1];
        rest.splice(sinceAt, 2);
      }
      const [bundle, flag, root] = rest;
      let source;
      if (flag === "--device" && rest.length === 2) source = { device: true };
      else if (flag === "--root" && rest.length === 3 && root && !root.split("/").includes("..")) source = { root };
      else throw new Error("log needs <bundle-id> --root <runtime-root> or --device");
      return commandLog(bundle, source, since);
    }
    case "judge":
      return judge(JSON.parse(readStdin()));
    case "iterable-devices":
      if (args.length < 1) throw new Error("iterable-devices needs <bundle-id> [token-sha256]");
      return iterableDevices(JSON.parse(readStdin() || "{}"), args[0], args[1] || "");
    case "corroborate":
      return corroborate(JSON.parse(readStdin()));
    case "readback-new":
      return readbackNew();
    case "readback-check": {
      const [arg, salt, hash] = args;
      const code = arg === "-" ? readStdin() : arg;
      const ok = /^[0-9a-f]{32}$/.test(String(salt)) && /^[0-9a-f]{64}$/.test(String(hash)) &&
        new RegExp(`^[${READBACK_ALPHABET}]{6}$`).test(normalizeCode(code)) &&
        crypto.timingSafeEqual(Buffer.from(readbackHash(code, salt), "hex"), Buffer.from(hash, "hex"));
      return { match: ok, normalized: normalizeCode(code) };
    }
    case "predicate":
      process.stdout.write(predicate(args[0]));
      return undefined;
    case "digest":
      process.stdout.write(notificationDigest(args[0]));
      return undefined;
    default:
      throw new Error("usage: ios-notify-read.js store|log|judge|predicate|digest");
  }
}

if (require.main === module) {
  Promise.resolve()
    .then(() => main(process.argv.slice(2)))
    .then(out => {
      if (out !== undefined) process.stdout.write(JSON.stringify(out) + "\n");
    })
    .catch(error => {
      process.stderr.write(`ios-notify-read: ${error.message}\n`);
      process.exit(1);
    });
}

// The raw APNs token iOS issued to the app on this Simulator, for the APNs
// probe only; never exposed through the command line.
function registrationToken(devicesRoot, udid, bundle) {
  const root = path.join(devicesRoot, udid, "data", "Library", "UserNotifications");
  const library = path.join(root, "Library.plist");
  if (!fs.existsSync(library)) return null;
  const mapping = readArchive(library);
  const directory = mapping && typeof mapping === "object" ? mapping[bundle] : null;
  if (typeof directory !== "string" || !/^[A-Za-z0-9-]+$/.test(directory)) return null;
  const file = path.join(root, directory, "PushRegistration.plist");
  if (!fs.existsSync(file)) return null;
  const registration = readArchive(file) || {};
  return {
    environment: registration.Environment == null ? null : String(registration.Environment),
    token: Buffer.isBuffer(registration.Token) ? registration.Token : null
  };
}

module.exports = { notificationDigest, parsePlistXml, unarchive, summarizeRecord, classify, judge, predicate, corroborate, normalizeCode, registrationToken };
