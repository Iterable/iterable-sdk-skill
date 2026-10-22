#!/usr/bin/env node
// A cleartext HTTP/2 stand-in for APNs. Answers each request with the scenario
// in <scenario-file> ("200" or "<status> <Reason>") and appends what it received
// to <record-file>.
"use strict";
const http2 = require("http2");
const fs = require("fs");
const [portFile, scenarioFile, recordFile] = process.argv.slice(2);
const server = http2.createServer();
server.on("stream", (stream, headers) => {
  let body = "";
  stream.setEncoding("utf8");
  stream.on("data", chunk => { body += chunk; });
  stream.on("end", () => {
    fs.appendFileSync(recordFile, JSON.stringify({
      path: headers[":path"], method: headers[":method"],
      authorization: headers.authorization, topic: headers["apns-topic"],
      push_type: headers["apns-push-type"], priority: headers["apns-priority"], body
    }) + "\n");
    const [code, reason] = String(fs.readFileSync(scenarioFile, "utf8")).trim().split(/\s+/);
    stream.respond({ ":status": Number(code), "content-type": "application/json" });
    stream.end(reason ? JSON.stringify({ reason }) : "");
  });
});
server.listen(0, "127.0.0.1", () => fs.writeFileSync(portFile, String(server.address().port)));
