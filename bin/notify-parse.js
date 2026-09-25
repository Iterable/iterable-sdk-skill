#!/usr/bin/env node
// Verdict on whether a push actually appeared on the device, read from
// `dumpsys notification` on stdin. Pure, so tests/device-notify.sh runs it
// against recorded dumps with no device attached.
//
// Usage: notify-parse.js <package> [marker] [sent-at-epoch-ms]
//
//   0  a push from this package is in the notification list
//   1  never returned: the notification service has nothing to say about a push
//      that was sent and did not arrive, so "absent" is not "broken"
//   2  nothing has arrived yet
//
// Why the OS and not the app: the notification service is neither the sender nor
// the receiver, so it can be fooled by neither, and reading it needs no code in
// the developer's app at all.
//
// Two ways to tell an Iterable push from a notification the app posted itself.
// A marker, when the tool sent the proof itself and knows what it wrote; failing
// that, the channel — the SDK posts to a channel of its own, named from
// `iterable_notification_channel_name`, which defaults to "iterable channel".
//
// `mArchive=Archive (0 notifications)` on a stock emulator: dismissing the
// notification erases this evidence, which is why absence returns 2 forever
// rather than ever going red.

const [PKG, MARKER = "", SENT_AT = "0"] = process.argv.slice(2);
const sentAt = Number(SENT_AT) || 0;

let input = "";
process.stdin.on("data", (c) => (input += c)).on("end", () => {
  const lines = input.split("\n");
  const records = [];
  let cur = null;

  for (const line of lines) {
    if (/^\s*NotificationRecord\(/.test(line)) {
      cur = { pkg: "", channel: "", channelName: "", when: 0, title: "", text: "", redacted: false, silent: false };
      records.push(cur);
      cur.pkg = (/pkg=(\S+)/.exec(line) || [])[1] || "";
      cur.channel = (/channel=(\S+)/.exec(line) || [])[1] || "";
      // Android groups a second notification from the same app with the first and
      // marks the children SILENT: it arrived, and nothing appeared on screen.
      cur.silent = /flags=[A-Z_|]*\bSILENT\b/.test(line);
      continue;
    }
    // A record block ends at the next section header, which sits at a shallower
    // indent than the record's own fields.
    if (cur && /^ {0,2}\S/.test(line)) cur = null;
    if (!cur) continue;

    const when = /\bwhen=(\d+)/.exec(line);
    if (when) cur.when = Number(when[1]);
    const title = /android\.title=String \((.*)\)\s*$/.exec(line);
    if (title) cur.title = title[1];
    const text = /android\.text=String \((.*)\)\s*$/.exec(line);
    if (text) cur.text = text[1];
    // Without --noredact the extras print their length instead of their content.
    if (/android\.(title|text)=String \[length=/.test(line)) cur.redacted = true;
    const chan = /effectiveNotificationChannel=NotificationChannel\{mId='[^']*', mName=([^,]*),/.exec(line);
    if (chan) cur.channelName = chan[1];
  }

  const mine = records.filter((r) => r.pkg === PKG);

  // The service counts what it refused to show. A push that arrived and was
  // suppressed is the single most confusing G16 failure, and this is the only
  // place that distinguishes it from one that never arrived.
  let blocked = 0;
  const statsAt = input.indexOf(`key='${PKG}',`);
  if (statsAt >= 0) {
    const block = input.slice(statsAt, statsAt + 1500);
    blocked = Number((/numBlocked=(\d+)/.exec(block) || [])[1] || 0);
  }
  const hint = blocked > 0 ? `; the service reports numBlocked=${blocked} for this package` : "";

  const verdict = (code, msg) => {
    console.log(msg + (code === 0 ? "" : hint));
    process.exit(code);
  };

  const describe = (r) => {
    const when = r.when ? new Date(r.when).toLocaleTimeString() : "unknown time";
    const what = r.title || r.text ? `"${r.title}${r.text ? " / " + r.text : ""}"` : "content redacted";
    return `${what} at ${when}`;
  };

  if (!mine.length) {
    verdict(2, `nothing from ${PKG} in the notification list yet`);
  }

  if (MARKER) {
    const carries = (r) => (r.title + " " + r.text).includes(MARKER);
    const fresh = (r) => !sentAt || !r.when || r.when >= sentAt - 5000;
    const hit = mine.find((r) => carries(r) && fresh(r));
    if (hit) {
      // Re-running the ladder does not re-send, so say how old the arrival is every
      // time. Read without an age, a green about a two-hour-old push reads as a push
      // that just landed — and someone watching the device sees nothing happen and
      // concludes the gate is lying. Only the text is quoted, not the title too:
      // it carries the marker, and the line has to survive brief()'s 100 characters.
      const at = hit.when ? new Date(hit.when).toLocaleTimeString() : "unknown time";
      const lag = sentAt && hit.when ? `, ${Math.round((hit.when - sentAt) / 1000)}s after send` : "";
      const mins = hit.when ? Math.round((Date.now() - hit.when) / 60000) : null;
      const age = !mins ? "" : mins < 60 ? `, ${mins}m ago` : `, ${Math.round(mins / 60)}h ago`;
      const quiet = hit.silent ? " — SILENT, no banner" : "";
      verdict(0, `"${hit.text || hit.title}" at ${at}${lag}${age}${quiet}`);
    }
    if (mine.some((r) => r.redacted)) {
      verdict(2, `${mine.length} notification(s) from ${PKG}, content redacted — cannot match the marker`);
    }
    verdict(2, `${mine.length} notification(s) from ${PKG}, none carrying the proof marker`);
  }

  // No marker: only the channel can tell an Iterable push from one the app posted.
  const viaIterable = mine.find((r) => /iterable/i.test(r.channelName));
  if (viaIterable) {
    verdict(0, `${describe(viaIterable)} on channel "${viaIterable.channelName}"`);
  }
  verdict(
    2,
    `${mine.length} notification(s) from ${PKG}, none on an Iterable channel` +
      " — and no proof send was recorded to match against"
  );
});
