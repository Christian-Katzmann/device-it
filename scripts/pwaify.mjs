#!/usr/bin/env node
// device-it PWA transform: operates on the BUILT output dir; never touches source.
// Usage: pwaify.mjs --dist <dir> --name "App Name" --icons <icon-dir> [--short-name X] [--theme "#hex"] [--bg "#hex"]
import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const args = {};
for (let i = 2; i < process.argv.length; i += 2) args[process.argv[i].replace(/^--/, '')] = process.argv[i + 1];

const dist = path.resolve(args.dist);
const name = args.name;
const iconSrc = path.resolve(args.icons);
if (!fs.existsSync(path.join(dist, 'index.html'))) fail(`no index.html in ${dist}`);
if (!name) fail('missing --name');

const shortName = (args['short-name'] || name).slice(0, 12);
const theme = args.theme || '#111111';
const bg = args.bg || '#ffffff';

// 1. Icons → dist/deviceit/
const iconDst = path.join(dist, 'deviceit');
fs.mkdirSync(iconDst, { recursive: true });
const need = ['apple-touch-icon-180.png', 'icon-192.png', 'icon-512.png', 'icon-512-maskable.png'];
for (const f of need) {
  const src = path.join(iconSrc, f);
  if (!fs.existsSync(src)) fail(`missing generated icon: ${src}`);
  fs.copyFileSync(src, path.join(iconDst, f));
}

// 2. Manifest: merge with an existing one if the build shipped it; ours fills gaps only.
const manifestPath = path.join(dist, 'manifest.webmanifest');
let existing = {};
for (const cand of ['manifest.webmanifest', 'manifest.json']) {
  const p = path.join(dist, cand);
  if (fs.existsSync(p)) { try { existing = JSON.parse(fs.readFileSync(p, 'utf8')); } catch {} break; }
}
const manifest = {
  name, short_name: shortName,
  start_url: './', scope: './',
  display: 'standalone',
  background_color: bg, theme_color: theme,
  ...existing,
  icons: (existing.icons && existing.icons.length) ? existing.icons : [
    { src: './deviceit/icon-192.png', sizes: '192x192', type: 'image/png' },
    { src: './deviceit/icon-512.png', sizes: '512x512', type: 'image/png' },
    { src: './deviceit/icon-512-maskable.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
  ],
};
fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));

// 3. Inject head block + SW registration into root-level HTML (marker-delimited, idempotent).
const HEAD_BEGIN = '<!-- deviceit:head:begin -->', HEAD_END = '<!-- deviceit:head:end -->';
const BODY_BEGIN = '<!-- deviceit:sw:begin -->', BODY_END = '<!-- deviceit:sw:end -->';
const headBlock = `${HEAD_BEGIN}
<link rel="manifest" href="./manifest.webmanifest">
<link rel="apple-touch-icon" href="./deviceit/apple-touch-icon-180.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="${escapeHtml(shortName)}">
<meta name="theme-color" content="${theme}">
${HEAD_END}`;
// Claim banner (anonymous-hosting lane only): the claim URL arrives via #claim=<url> in the
// QR target, is persisted, and the banner nags until claimed or dismissed. iOS partitions the
// installed app's storage from Safari's, so this banner does its work in the browser visit —
// which is exactly where claiming happens.
const claimSnippet = args['claim-banner'] ? `
(function(){
  var m=location.hash.match(/[#&]claim=([^&]+)/);
  if(m){try{localStorage.setItem('deviceit-claim-url',decodeURIComponent(m[1]));history.replaceState(null,'',location.pathname+location.search)}catch(e){}}
  var u=null;try{u=localStorage.getItem('deviceit-claim-url')}catch(e){}
  if(!u||localStorage.getItem('deviceit-claimed'))return;
  var b=document.createElement('div');
  b.id='deviceit-claim';
  b.innerHTML='<span><strong>Keep this app</strong> \\u2014 it\\u2019s on temporary hosting for about an hour. Claiming is free.</span><a rel="noopener" target="_blank">Claim it</a><button aria-label="claimed">\\u2713 Claimed</button>';
  b.style.cssText='position:fixed;left:50%;top:calc(10px + env(safe-area-inset-top));transform:translateX(-50%);display:flex;gap:12px;align-items:center;background:#B45309;color:#fff;font:500 14px/1.35 -apple-system,system-ui,sans-serif;padding:10px 14px;border-radius:12px;z-index:2147483647;box-shadow:0 6px 24px rgba(0,0,0,.35);max-width:94vw';
  var a=b.querySelector('a');a.href=u;a.style.cssText='background:#fff;color:#B45309;font-weight:700;text-decoration:none;padding:6px 12px;border-radius:8px;white-space:nowrap';
  var x=b.querySelector('button');x.style.cssText='background:none;border:none;color:rgba(255,255,255,.85);font-size:14px;padding:2px 4px';
  x.onclick=function(){try{localStorage.setItem('deviceit-claimed','1')}catch(e){};b.remove()};
  addEventListener('load',function(){document.body.appendChild(b)});
})();` : '';

const swBlock = `${BODY_BEGIN}<script>if('serviceWorker' in navigator){addEventListener('load',()=>navigator.serviceWorker.register('./sw.js'))}${claimSnippet}
(function(){
  var ua=navigator.userAgent,iOS=/iPad|iPhone|iPod/.test(ua)||(navigator.platform==='MacIntel'&&navigator.maxTouchPoints>1);
  var standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone===true;
  if(!iOS||standalone||localStorage.getItem('deviceit-hint-dismissed'))return;
  var b=document.createElement('div');
  b.id='deviceit-hint';
  b.innerHTML='<span>Install: tap <svg width="15" height="19" viewBox="0 0 15 19" fill="none" style="vertical-align:-3px"><path d="M7.5 1v11M4 4l3.5-3L11 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/><rect x="1" y="7" width="13" height="11" rx="2" stroke="currentColor" stroke-width="1.6"/></svg> then \\u201cAdd to Home Screen\\u201d</span><button aria-label="dismiss">\\u2715</button>';
  b.style.cssText='position:fixed;left:50%;bottom:calc(14px + env(safe-area-inset-bottom));transform:translateX(-50%);display:flex;gap:14px;align-items:center;background:rgba(20,22,26,.94);color:#fff;font:500 15px/1.3 -apple-system,system-ui,sans-serif;padding:12px 16px;border-radius:14px;z-index:2147483647;box-shadow:0 6px 24px rgba(0,0,0,.35);max-width:92vw;-webkit-backdrop-filter:blur(10px)';
  b.querySelector('button').style.cssText='background:none;border:none;color:#9aa0a8;font-size:15px;padding:2px 4px';
  b.querySelector('button').onclick=function(){localStorage.setItem('deviceit-hint-dismissed','1');b.remove()};
  addEventListener('load',function(){document.body.appendChild(b)});
})()</script>${BODY_END}`;

const htmlFiles = fs.readdirSync(dist).filter(f => f.endsWith('.html'));
for (const f of htmlFiles) {
  const p = path.join(dist, f);
  let html = fs.readFileSync(p, 'utf8');
  html = stripBetween(html, HEAD_BEGIN, HEAD_END);
  html = stripBetween(html, BODY_BEGIN, BODY_END);

  // viewport: ensure viewport-fit=cover for edge-to-edge on iPad
  if (/<meta[^>]+name=["']viewport["'][^>]*>/i.test(html)) {
    html = html.replace(/(<meta[^>]+name=["']viewport["'][^>]+content=["'])([^"']*)(["'])/i,
      (m, a, content, c) => content.includes('viewport-fit') ? m : `${a}${content}, viewport-fit=cover${c}`);
  } else {
    html = html.replace(/<head([^>]*)>/i, `<head$1>\n<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`);
  }

  html = html.replace(/<\/head>/i, `${headBlock}\n</head>`);
  html = html.replace(/<\/body>/i, `${swBlock}\n</body>`);
  fs.writeFileSync(p, html);
}

// 4. Service worker via workbox generateSW (precache + SPA navigation fallback).
const wbConfig = path.join(os.tmpdir(), `deviceit-workbox-${Date.now()}.cjs`);
fs.writeFileSync(wbConfig, `module.exports = {
  globDirectory: ${JSON.stringify(dist)},
  globPatterns: ['**/*.{html,js,css,png,jpg,jpeg,svg,gif,webp,ico,json,webmanifest,woff,woff2,ttf,txt,wasm,mp3}'],
  globIgnores: ['sw.js', 'workbox-*.js'],
  swDest: ${JSON.stringify(path.join(dist, 'sw.js'))},
  skipWaiting: true,
  clientsClaim: true,
  cleanupOutdatedCaches: true,
  navigateFallback: 'index.html',
  navigateFallbackDenylist: [/^\\/api\\//],
  maximumFileSizeToCacheInBytes: 8 * 1024 * 1024,
  runtimeCaching: [{
    urlPattern: /^https:\\/\\//,
    handler: 'StaleWhileRevalidate',
    options: { cacheName: 'deviceit-runtime', expiration: { maxEntries: 200, maxAgeSeconds: 2592000 } },
  }],
};`);
execFileSync('npx', ['--yes', 'workbox-cli@7.3.0', 'generateSW', wbConfig], { stdio: 'inherit' });
fs.rmSync(wbConfig, { force: true });

// 5. Self-check
const problems = [];
if (!fs.existsSync(path.join(dist, 'sw.js'))) problems.push('sw.js missing');
try { JSON.parse(fs.readFileSync(manifestPath, 'utf8')); } catch { problems.push('manifest unparsable'); }
for (const f of need) if (!fs.existsSync(path.join(iconDst, f))) problems.push(`icon missing: ${f}`);
const idx = fs.readFileSync(path.join(dist, 'index.html'), 'utf8');
if (!idx.includes('rel="manifest"')) problems.push('manifest link not injected');
if (!idx.includes('serviceWorker')) problems.push('sw registration not injected');
if (problems.length) fail(problems.join('; '));

console.log(JSON.stringify({ ok: true, dist, manifest: 'manifest.webmanifest', sw: 'sw.js', htmlPatched: htmlFiles }, null, 2));

function stripBetween(s, a, b) {
  const i = s.indexOf(a); if (i === -1) return s;
  const j = s.indexOf(b, i); if (j === -1) return s;
  return s.slice(0, i) + s.slice(j + b.length);
}
function escapeHtml(s) { return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/"/g, '&quot;'); }
function fail(msg) { console.error(`pwaify: ${msg}`); process.exit(1); }
