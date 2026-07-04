#!/usr/bin/env node
// Choose a deploy driver: config/arg override → whatever is already authed → anonymous Netlify.
// Prints DRIVER=<name> (+ NOTE=...). Probes run with hard timeouts so a hung CLI can't stall.
// Usage: pick.mjs [preferred-driver]
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const probe = (cmd, args, ms = 10000) => {
  try {
    return execFileSync(cmd, args, { encoding: 'utf8', timeout: ms, stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  } catch { return null; }
};
const has = (cmd) => !!probe(process.platform === 'win32' ? 'where' : 'which', [cmd], 3000);

let cfg = {};
try { cfg = JSON.parse(fs.readFileSync(path.join(os.homedir(), '.device-it', 'config.json'), 'utf8')); } catch {}

const checks = {
  vercel: () => has('vercel') && !!probe('vercel', ['whoami']),
  netlify: () => { if (!has('netlify')) return false; const o = probe('netlify', ['status'], 12000); return !!o && /email/i.test(o); },
  cloudflare: () => { if (!has('wrangler')) return false; const o = probe('wrangler', ['whoami'], 12000); return !!o && /associated with|account/i.test(o) && !/not authenticated/i.test(o); },
  'gh-pages': () => has('gh') && probe('gh', ['auth', 'status']) !== null,
  surge: () => !!(cfg.deploy?.surge?.token || process.env.SURGE_TOKEN),
  tunnel: () => has('cloudflared'),
  'netlify-anon': () => true, // npx-able; needs nothing but node
};

const preferred = process.argv[2] || cfg.deploy?.driver;
if (preferred) {
  if (checks[preferred]?.()) { out(preferred, 'configured/requested'); }
  console.error(`pick: preferred driver "${preferred}" unavailable or unauthed — falling back to detection`);
}

for (const d of ['vercel', 'netlify', 'cloudflare', 'gh-pages']) {
  if (checks[d]()) out(d, 'already authed on this machine');
}
out('netlify-anon', 'no deploy account found — anonymous deploy, claimable for 1 hour');

function out(driver, note) {
  console.log(`DRIVER=${driver}`);
  console.log(`NOTE=${note}`);
  process.exit(0);
}
