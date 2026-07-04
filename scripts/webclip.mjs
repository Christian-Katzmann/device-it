#!/usr/bin/env node
// Generate a managed Web Clip .mobileconfig (deterministic UUIDs → idempotent re-pushes).
// Usage: webclip.mjs --slug my-app --name "My App" --url https://... --icon path/to/180.png --out out.mobileconfig
import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, '')] = process.argv[i + 1];
for (const k of ['slug', 'name', 'url', 'icon', 'out']) if (!args[k]) { console.error(`webclip: missing --${k}`); process.exit(1); }

// Deterministic UUID from a seed string (md5 → RFC-4122-shaped)
const uuidFrom = (seed) => {
  const h = crypto.createHash('md5').update(seed).digest('hex').toUpperCase();
  return `${h.slice(0, 8)}-${h.slice(8, 12)}-${h.slice(12, 16)}-${h.slice(16, 20)}-${h.slice(20, 32)}`;
};

const iconB64 = fs.readFileSync(args.icon).toString('base64').replace(/(.{68})/g, '$1\n');
const tpl = fs.readFileSync(new URL('../templates/webclip.mobileconfig.tpl', import.meta.url), 'utf8');
const out = tpl
  .replaceAll('{{SLUG}}', args.slug)
  .replaceAll('{{NAME}}', xmlEscape(args.name))
  .replaceAll('{{URL}}', xmlEscape(args.url))
  .replaceAll('{{UUID_CLIP}}', uuidFrom(`deviceit-clip-${args.slug}`))
  .replaceAll('{{UUID_PROFILE}}', uuidFrom(`deviceit-profile-${args.slug}`))
  .replaceAll('{{ICON_B64}}', iconB64.trimEnd());

fs.mkdirSync(path.dirname(path.resolve(args.out)), { recursive: true });
fs.writeFileSync(args.out, out);
try {
  execFileSync('plutil', ['-lint', args.out], { stdio: 'inherit' });
} catch (e) {
  if (e.code === 'ENOENT') console.error('webclip: plutil not found (non-macOS) — skipping lint');
  else throw e;
}
console.log(JSON.stringify({ ok: true, out: args.out, profileIdentifier: `dk.deviceit.${args.slug}` }));

function xmlEscape(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
