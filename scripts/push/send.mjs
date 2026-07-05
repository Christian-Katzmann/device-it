#!/usr/bin/env node
// Send a Web Push notification to an installed app — no Apple cert, no MDM, works on
// iOS 16.4+ (installed PWAs), Android, and desktop. Wraps the web-push CLI so callers
// deal in subscription JSON files, not endpoint/key/auth flags.
//
// One-time keys: npx --yes web-push generate-vapid-keys --json > ~/.device-it/webpush.json
// Usage:  send.mjs --sub subscription.json --title "Title" --body "Body" [--url https://open.me]
//         (subscription.json = the JSON the page got from pushManager.subscribe — see references/web-push.md)
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, '')] = process.argv[i + 1];
for (const k of ['sub', 'title', 'body']) if (!args[k]) fail(`missing --${k}`);

const keysPath = path.join(os.homedir(), '.device-it', 'webpush.json');
let keys;
try { keys = JSON.parse(fs.readFileSync(keysPath, 'utf8')); }
catch { fail(`no VAPID keys at ${keysPath} — run: npx --yes web-push generate-vapid-keys --json > ${keysPath}`); }

let sub;
try { sub = JSON.parse(fs.readFileSync(args.sub, 'utf8')); }
catch { fail(`could not read subscription JSON at ${args.sub}`); }
const { endpoint, keys: { p256dh, auth } = {} } = sub;
if (!endpoint || !p256dh || !auth) fail('subscription JSON must contain endpoint + keys.p256dh + keys.auth');

const payload = JSON.stringify({ title: args.title, body: args.body, url: args.url || '/' });
execFileSync('npx', ['--yes', 'web-push', 'send-notification',
  `--endpoint=${endpoint}`, `--key=${p256dh}`, `--auth=${auth}`,
  `--vapid-subject=mailto:device-it@localhost`,
  `--vapid-pubkey=${keys.publicKey}`, `--vapid-pvtkey=${keys.privateKey}`,
  `--payload=${payload}`,
], { stdio: 'inherit' });
console.log(JSON.stringify({ ok: true, endpoint: endpoint.slice(0, 60) + '…' }));

function fail(msg) { console.error(`push/send: ${msg}`); process.exit(1); }
