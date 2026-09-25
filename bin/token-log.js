#!/usr/bin/env node
// Verdict on whether the device obtained an FCM token and handed it to Iterable,
// read from a `logcat -d` dump on stdin. Pure — no adb, no network — so
// tests/device-token-log.sh can run it against recorded buffers with no device.
//
// Usage: token-log.js <package>
//
// Five exit codes, because the situations really are five:
//   0  the SDK registered a token and Iterable answered Success
//   1  a real failure: Iterable rejected the registration
//   2  no evidence the app has run since the buffer was last written. Unknowable,
//      not broken — the ring buffer rotates, so absence here proves nothing
//   3  the SDK ran and never attempted registration, with nothing in the log to say
//      why. Ask again shortly; past the caller's deadline this is outstanding work in
//      the app — nobody has identified a user — and not a defect in the integration
//   4  the SDK ran, never attempted registration, and Firebase logged an error. That
//      error is the answer, and it is the one shape of "never registered" that really
//      is something broken
//
// 3 and 4 were one code, and the caller reported both red. A developer whose app had
// simply never called setEmail got told SOMETHING IS ACTUALLY WRONG about an
// integration that was fine — which is the exact false alarm this tool exists not to
// raise. They are separate now because only one of them is a defect.
//
// The logged request body contains the device's FCM token. Nothing here reads or
// prints it: a gate message ends up in reports and terminals.

const PKG = process.argv[2] || "";

// logcat's default `threadtime` format. The tid matters: the SDK logs a request
// and its response from different threads, and other threads interleave their own
// lines in between — a response block read as "the next few lines" picks up
// another request's separator and stops early. Grouping by tid is what makes the
// read of `"code"` belong to the call we asked about.
const LINE =
  /^\d\d-\d\d \d\d:\d\d:\d\d\.\d+\s+\d+\s+(\d+)\s+([VDIWEF])\s+([^:]*):\s?(.*)$/;

const REGISTER = "/api/users/registerDeviceToken";

let input = "";
process.stdin.on("data", (c) => (input += c)).on("end", () => {
  const lines = [];
  for (const raw of input.split("\n")) {
    const m = LINE.exec(raw);
    if (m) lines.push({ tid: m[1], level: m[2], tag: m[3].trim(), msg: m[4] });
  }

  const verdict = (code, msg) => {
    console.log(msg);
    process.exit(code);
  };

  const sdkRan = lines.some((l) => /^Iterable/.test(l.tag));
  const attempted = lines.some((l) => l.msg.includes(REGISTER));

  // Read the response belonging to the *last* registration attempt: a relaunch
  // registers again, and an old failure followed by a fresh success is a pass.
  let code = null;
  let apiMsg = "";
  for (let i = lines.length - 1; i >= 0 && code === null; i--) {
    const l = lines[i];
    if (!(l.msg.includes(REGISTER) && /Response from/.test(l.msg))) continue;
    for (let j = i + 1; j < lines.length; j++) {
      if (lines[j].tid !== l.tid) continue;
      if (/={6,}/.test(lines[j].msg) || /Response from/.test(lines[j].msg)) break;
      const c = /"code"\s*:\s*"([^"]+)"/.exec(lines[j].msg);
      if (c) code = c[1];
      const m = /"msg"\s*:\s*"([^"]*)"/.exec(lines[j].msg);
      if (m && m[1]) apiMsg = m[1];
    }
  }

  // "FCM" vs "GCM" here is the legacy-transport trap: registration succeeds and
  // sends fail later, so name it while we are looking at it.
  const regType = (/"tokenRegistrationType"\s*:\s*"([^"]+)"/.exec(input) || [])[1];
  const suffix = regType ? `, tokenRegistrationType ${regType}` : "";

  if (code === "Success") {
    verdict(0, `registerDeviceToken → Success${suffix}`);
  }
  if (code) {
    verdict(1, `registerDeviceToken → ${code}${apiMsg ? `: ${apiMsg}` : ""}`);
  }
  if (attempted) {
    verdict(2, "registration request sent, no response in the buffer yet");
  }

  if (sdkRan) {
    // The SDK initialised and never asked to register. The usual causes are
    // configuration, but a launch two seconds ago produces the same reading, so
    // this is never a verdict on its own — the caller's deadline decides.
    //
    // Errors only, not warnings: Firebase logs benign warnings on every start
    // (an uncreated default channel, for one), and treating those as the cause
    // would turn a gate that was merely early into a gate that was wrong.
    //
    // Stack frames are skipped, not merely trimmed: Firebase logs an exception across
    // several lines under the same tag, so the *last* of them is a frame from somewhere
    // inside the library. Reported as the cause it reads as an internal Google file
    // nobody can act on, where the line two above it says FIS_AUTH_ERROR.
    const fcmErr = [...lines]
      .reverse()
      .find(
        (l) =>
          /Firebase/.test(l.tag) &&
          l.level === "E" &&
          !/^\s*(at |\.\.\. )/.test(l.msg)
      );
    if (fcmErr) {
      verdict(
        4,
        `no registerDeviceToken; Firebase errored first — ${fcmErr.tag}: ${fcmErr.msg.trim().slice(0, 70)}`
      );
    }
    verdict(
      3,
      "SDK ran but never called registerDeviceToken — no user identified, " +
        "or setAutoPushRegistration(false)"
    );
  }

  verdict(
    2,
    `no Iterable SDK output in the log buffer — launch ${PKG || "the app"} and re-run`
  );
});
