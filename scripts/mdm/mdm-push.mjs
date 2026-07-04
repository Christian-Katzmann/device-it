#!/usr/bin/env node
// Enqueue an MDM command for enrolled devices and APNs-push them, then watch the
// nanomdm log for acknowledgment. The pocket MDM must be up (mdm-up.sh).
//
// Usage:
//   mdm-push.mjs install --profile app.mobileconfig [--udid <id>]
//   mdm-push.mjs remove  --identifier dk.deviceit.<slug> [--udid <id>]
import { execSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const NANO = 'http://127.0.0.1:9930';
const MDM_DIR = path.join(os.homedir(), '.device-it', 'mdm');
const CONFIG = path.join(os.homedir(), '.device-it', 'config.json');

const [action, ...rest] = process.argv.slice(2);
const args = {};
for (let i = 0; i < rest.length; i += 2) args[rest[i].replace(/^--/, '')] = rest[i + 1];

const config = JSON.parse(fs.readFileSync(CONFIG, 'utf8'));
const udids = args.udid ? [args.udid] : (config.devices ?? []).map(d => d.udid);
if (!udids.length) fail('no enrolled devices in ~/.device-it/config.json (run setup)');

const apiKey = execSync('security find-generic-password -s device-it-nanomdm -a nanomdm -w', { encoding: 'utf8' }).trim();
const auth = 'Basic ' + Buffer.from(`nanomdm:${apiKey}`).toString('base64');

const commandUUID = crypto.randomUUID().toUpperCase();
let inner;
if (action === 'install') {
  const payload = fs.readFileSync(args.profile).toString('base64').replace(/(.{68})/g, '$1\n');
  inner = `    <key>RequestType</key>
    <string>InstallProfile</string>
    <key>Payload</key>
    <data>
${payload}
    </data>`;
} else if (action === 'remove') {
  inner = `    <key>RequestType</key>
    <string>RemoveProfile</string>
    <key>Identifier</key>
    <string>${args.identifier}</string>`;
} else fail('action must be install|remove');

const command = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Command</key>
  <dict>
${inner}
  </dict>
  <key>CommandUUID</key>
  <string>${commandUUID}</string>
</dict>
</plist>`;

const logFile = path.join(MDM_DIR, 'nanomdm.log');
const logStart = fs.existsSync(logFile) ? fs.statSync(logFile).size : 0;

for (const udid of udids) {
  const enq = await fetch(`${NANO}/v1/enqueue/${udid}`, { method: 'PUT', headers: { Authorization: auth }, body: command });
  if (!enq.ok) fail(`enqueue failed for ${udid}: ${enq.status} ${await enq.text()}`);
  const push = await fetch(`${NANO}/v1/push/${udid}`, { method: 'PUT', headers: { Authorization: auth } });
  if (!push.ok) fail(`APNs push failed for ${udid}: ${push.status} ${await push.text()}`);
  console.log(`pushed ${action} to ${udid} (command ${commandUUID})`);
}

// Watch the log for the device acknowledging our command (device must be awake + online).
const deadline = Date.now() + 90_000;
let acked = false;
while (Date.now() < deadline && !acked) {
  await new Promise(r => setTimeout(r, 3000));
  try {
    const buf = fs.readFileSync(logFile, 'utf8').slice(logStart);
    if (buf.includes(commandUUID) && /Acknowledged/i.test(buf)) acked = true;
    if (buf.includes(commandUUID) && /Error/i.test(buf)) fail(`device reported Error for ${commandUUID} — tail ${logFile}`);
  } catch {}
}
console.log(JSON.stringify({ ok: true, commandUUID, acknowledged: acked, note: acked ? 'device confirmed' : 'queued — device will apply when it wakes/comes online' }));

function fail(msg) { console.error(`mdm-push: ${msg}`); process.exit(1); }
