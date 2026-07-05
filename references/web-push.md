# Web Push — notifications to installed apps, without any Apple cert

Status: **designed, not yet field-run** — verify each step works before declaring victory.

When "push" means *send something TO the installed app* (a nudge, a "new data ready"),
this is the route. It needs **no mdmcert.download, no identity.apple.com, no MDM, no Apple
account** — just a VAPID keypair generated locally. Works on iOS/iPadOS 16.4+ (ONLY for
apps added to the Home Screen), Android, and desktop. If "push" instead means *the icon
appears/updates with no taps*, that's the zero-touch lane (`onboarding.md`), not this.

## If you just want it working

```bash
# 1. Keys, once per machine:
mkdir -p ~/.device-it && npx --yes web-push generate-vapid-keys --json > ~/.device-it/webpush.json

# 2. App side: add the two snippets below (service-worker handler + page subscribe), rebuild, redeploy.

# 3. Get the subscription JSON off the device (transport recipes below), save as sub.json. Then:
node scripts/push/send.mjs --sub sub.json --title "Campaigns" --body "Step 3 finished" --url /
```

## Snippet 1 — service-worker push handler

Workbox's generated `sw.js` doesn't handle push. Append this file as `push-sw.js` in the
built output and add `importScripts: ['push-sw.js']` to the workbox config in `pwaify.mjs`
(or concatenate onto sw.js after generation — either works):

```js
self.addEventListener('push', (e) => {
  const d = e.data ? e.data.json() : {};
  e.waitUntil(self.registration.showNotification(d.title || 'Update', {
    body: d.body || '', data: { url: d.url || '/' },
  }));
});
self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil(clients.openWindow(e.notification.data.url));
});
```

## Snippet 2 — page-side subscribe (run on a user gesture; iOS requires it)

```js
async function enablePush(vapidPublicKey) {
  const reg = await navigator.serviceWorker.ready;
  if (await Notification.requestPermission() !== 'granted') return null;
  const sub = await reg.pushManager.subscribe({
    userVisibleOnly: true,
    applicationServerKey: Uint8Array.from(atob(vapidPublicKey.replace(/-/g,'+').replace(/_/g,'/')), c => c.charCodeAt(0)),
  });
  return JSON.stringify(sub); // ← this JSON is what send.mjs needs
}
```

## Getting the subscription back to the sender (pick per app shape)

- **App has a backend (VPS apps — the common case here):** POST the JSON to the backend,
  store per device. The sender reads it from there. One `app.post('/push/subscribe', …)`
  endpoint and you're done.
- **Static app, no backend:** show the JSON in-app (copy button / QR) once after subscribing;
  the human pastes it into `~/.device-it/push-subs/<slug>-<device>.json`. Clunky but one-time
  per device, and keeps the app backend-free.

## Sharp edges (known, not yet re-verified in the field)

- iOS: push works **only for Home-Screen-installed** apps, permission prompt must follow a
  user gesture, and iOS may drop subscriptions for apps unused for weeks — treat a 410 from
  send.mjs as "re-subscribe on next open".
- The VAPID keypair identifies the sender; losing it orphans every subscription. It lives in
  `~/.device-it/webpush.json` — private, never committed.
- Payloads are encrypted end-to-end by the protocol; still, don't put secrets in them.
