#!/usr/bin/env node
// Verify a deployed (or locally served) device-it app: HTTP truth always; offline truth via Playwright when available.
// Usage: verify.mjs --url https://app.example  [--skip-offline]
import fs from 'node:fs';
import { createRequire } from 'node:module';
import path from 'node:path';

const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const a = process.argv[i];
  if (a === '--skip-offline') args.skipOffline = true;
  else if (a.startsWith('--')) args[a.slice(2)] = process.argv[++i];
}
const base = args.url?.replace(/\/$/, '');
if (!base) { console.error('verify: missing --url'); process.exit(1); }

const results = [];
const check = (name, ok, note = '') => { results.push({ name, ok, note }); };

// --- HTTP truth ---
const page = await get(`${base}/`);
check('page 200', page.status === 200, `status ${page.status}`);
const html = page.body;
check('manifest link injected', /rel="manifest"/.test(html));
check('apple-touch-icon injected', /apple-touch-icon/.test(html));
check('sw registration injected', /serviceWorker/.test(html));

const man = await get(`${base}/manifest.webmanifest`);
let manifest = null;
try { manifest = JSON.parse(man.body); } catch {}
check('manifest 200 + parses', man.status === 200 && !!manifest, `status ${man.status}`);
if (manifest) {
  check('manifest display standalone', manifest.display === 'standalone', String(manifest.display));
  for (const icon of manifest.icons ?? []) {
    const r = await get(new URL(icon.src, `${base}/`).href);
    check(`icon ${icon.sizes}${icon.purpose ? ' ' + icon.purpose : ''}`, r.status === 200, `status ${r.status}`);
  }
}
const sw = await get(`${base}/sw.js`);
check('sw.js 200', sw.status === 200, `status ${sw.status}`);
check('sw.js is a workbox precache SW', /precacheAndRoute|__WB_MANIFEST|workbox/.test(sw.body));

// --- Offline truth (Playwright if resolvable from skill dir, project, or global) ---
let offline = 'skipped';
if (!args.skipOffline) {
  const pw = resolvePlaywright();
  if (!pw) {
    offline = 'unavailable (playwright not installed — HTTP checks only)';
  } else {
    try {
      const browser = await pw.chromium.launch();
      const ctx = await browser.newContext();
      const p = await ctx.newPage();
      const errors = [];
      p.on('pageerror', (e) => errors.push(String(e)));
      await p.goto(`${base}/`, { waitUntil: 'load', timeout: 30000 });
      await p.waitForFunction(() => navigator.serviceWorker?.controller != null, null, { timeout: 30000 });
      await p.waitForTimeout(1500); // let precache finish
      await ctx.setOffline(true);
      await p.reload({ waitUntil: 'load', timeout: 30000 });
      const text = await p.evaluate(() => document.body?.innerText?.trim().length ?? 0);
      const rooted = await p.evaluate(() => (document.querySelector('#root,#app,main,body')?.children.length ?? 0) > 0);
      await browser.close();
      const ok = text > 0 || rooted;
      check('offline reload renders app shell', ok, `bodyText=${text} rooted=${rooted}`);
      if (errors.length) check('no page errors offline', false, errors.slice(0, 3).join(' | '));
      offline = ok ? 'verified' : 'FAILED';
    } catch (e) {
      check('offline reload renders app shell', false, String(e).slice(0, 200));
      offline = 'FAILED';
    }
  }
}

const failed = results.filter(r => !r.ok);
console.log(JSON.stringify({ url: base, offline, ok: failed.length === 0, results }, null, 2));
process.exit(failed.length === 0 ? 0 : 1);

async function get(url) {
  try {
    const r = await fetch(url, { redirect: 'follow' });
    return { status: r.status, body: await r.text() };
  } catch (e) { return { status: 0, body: String(e) }; }
}

function resolvePlaywright() {
  const require = createRequire(import.meta.url);
  const candidates = [
    () => require('playwright'),
    () => require(path.join(new URL('..', import.meta.url).pathname, 'node_modules', 'playwright', 'index.js')),
    () => require(require('node:child_process').execSync('npm root -g', { encoding: 'utf8' }).trim() + '/playwright'),
  ];
  for (const c of candidates) { try { return c(); } catch {} }
  return null;
}
