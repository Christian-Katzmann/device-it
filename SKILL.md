---
name: device-it
description: >-
  Put a local web project on a device Home Screen / launcher as a launchable,
  fullscreen, offline-capable app with its own icon and name — iPhone, iPad,
  Android, or desktop browser. Use when the user says device-it, "put this on
  my phone/iPad/tablet", "make this an installable app", "install on my
  device", "home screen app", or wants the on-device sibling of app-it (which
  makes a Mac Dock app). Builds the project, applies a PWA transform (manifest,
  icons, service worker) to the built output only, deploys to a stable HTTPS
  URL, and installs via the pocket MDM on Apple devices (zero-touch: icon just
  appears) or a QR/Add-to-Home-Screen link everywhere. Also handles update,
  remove, list, doctor, and one-time setup/enrollment. Legacy alias: ipad-it.
---

# device-it — a web project as a real app on any of your devices

Sibling to app-it: app-it makes a **macOS Dock** app; device-it makes a **Home Screen /
launcher** app on the devices you carry. One PWA build serves them all —

- **iPhone / iPad / Android / desktop Chrome-Edge**: the **scan lane** installs a fullscreen,
  offline app with its own icon everywhere. Android/desktop get an even cleaner native install
  than iOS. This lane needs no accounts and works today.
- **Apple devices, once enrolled**: the **zero-touch lane** pushes the icon so it just appears,
  no taps. Apple-only (it rides Apple's MDM); Android/desktop always use the scan lane.

Lane decided by one check: if `~/.device-it/config.json` exists, an Apple device is enrolled
→ **zero-touch lane: push the web clip, the icon appears with no taps.** Otherwise → **scan lane:
QR/iMessage link + Add to Home Screen (≈2 taps; Android/desktop show a native install prompt)**,
and mention that `/device-it setup` (~10 min, once) upgrades Apple devices to zero-touch. Never
block the scan lane on setup — it's the universal one.

## Install routes — match the situation BEFORE you start

The default pipeline below is right most of the time. But check this table **first** (the
situation often makes a different route strictly easier), and check it **again** whenever the
default hits friction. These are field-solved routes — don't re-derive what's already here.

| Situation | Route | Doc | Status |
|---|---|---|---|
| App already hosted (VPS, live backend, existing URL) | **Wrap mode** — skip build+deploy entirely: `run.sh --url …` | `zero-touch-edge-cases.md` | ✅ field-run |
| Own 1–2 devices, main worry is updates | **Scan once** — the service worker auto-updates every launch; MDM adds nothing here | this file | ✅ field-run |
| Icons must appear/update/vanish with NO taps (Apple) | **Zero-touch lane** — pocket MDM | `onboarding.md` | ✅ field-run |
| Many devices, remote devices, or VPS-hosted app + MDM | **Full APNs cert flow** — the verified sequence | `zero-touch-edge-cases.md` | ✅ field-run |
| No hosting account anywhere | **Claim-first deploy** — live before any signup | `hosting.md` | ✅ field-run |
| Send notifications TO the installed app | **Web Push (VAPID)** — no Apple cert at all | `web-push.md` | ◐ designed |
| Enrollment profile onto a nearby Apple device | **AirDrop it** — no server, no funnel | `onboarding.md` §7 | ◐ designed |

This table is NOT exhaustive. If the situation matches nothing here, adapt the closest route
or invent a new one — we have definitely not thought of every use case. When an invented route
works, write it into `references/` so the next run doesn't re-derive it.

## Non-negotiables

1. Run `scripts/inspect.sh` from the project root first; trust its output over docs.
2. Never modify project source. The PWA transform operates on the BUILT output dir only.
3. Decide defaults yourself (name from package.json, icon by discovery); ask only when
   truly ambiguous. Missing icon → generate a clean monogram placeholder and say so.
4. The web clip URL must be the STABLE production URL, never a per-deploy hash URL.
5. Same slug = same Vercel project, same profile PayloadIdentifier — updates are in-place.
6. Verify before declaring victory: HTTP truth always, offline truth via Playwright when
   available, device truth via MDM acknowledgment. Report honestly what was not verifiable.
7. Clean up what you start: temp servers down, funnel closed after enrollment flows
   (`mdm-down.sh` after pushes; the MDM's default posture is OFF between installs).
8. Public URL = public app. Don't add auth walls (they break offline) unless asked.

## Pipeline (default invocation)

One command does everything — inspect, build, icons, PWA transform, deploy-driver
auto-pick, deploy, verify, web clip, then the zero-touch lane (MDM push) or the
scan lane (QR+iMessage), plus registry bookkeeping:

```bash
bash /path/to/skills/device-it/scripts/run.sh <project-dir> [--icon img] [--name "Name"] [--slug slug] [--driver name]
bash /path/to/skills/device-it/scripts/run.sh --url https://already-hosted.app --name "Name"   # wrap an existing site
bash /path/to/skills/device-it/scripts/run.sh remove <slug>
```

Deploy needs NO specific vendor: `deploy/pick.mjs` uses whatever is already authed
(vercel → netlify → cloudflare → gh-pages) and otherwise falls back to an **anonymous
Netlify deploy** — no account, claimable for 1 hour (run.sh auto-opens the claim page;
one GitHub-SSO click makes it permanent and free). Anonymous sites are password-gated
until claimed (password is printed) — tell the user to CLAIM FIRST, then install.
See `references/hosting.md` for all drivers and their live-verified quirks.

Icon discovery order (run.sh does this itself): `--icon` → inspect's ICON_CANDIDATES →
the app-it Mac app's `.icns` for the same project root → generated monogram (never blocks).
Read run.sh output: URL, VERIFY, LANE (`zero-touch` or `scan`), PROFILE — relay per report-template.
Individual stages remain callable (`inspect.sh`, `icons.sh`, `pwaify.mjs`, `deploy/vercel.sh`,
`verify.mjs`, `webclip.mjs`, `mdm/*`, `qr.sh`, `registry.mjs`) for debugging or partial reruns.

The PWA transform also injects a dismissible iOS-only "tap Share → Add to Home Screen"
hint that renders only in Safari (never in the installed app) — scan-lane users see their
own install instructions on screen.

## Other verbs

- **update**: rerun the pipeline; skip webclip+push unless name/icon/URL changed (SW
  delivers content updates on next launch by itself).
- **remove <slug>**: `mdm-push.mjs remove --identifier dk.deviceit.<slug>` (icon vanishes),
  optionally `vercel remove deviceit-<slug> --yes`, then `registry.mjs remove`.
- **list**: `registry.mjs list`.
- **doctor**: `scripts/doctor.sh` — toolchain, deploy auth, MDM health, push-cert expiry.
- **setup**: one-time enrollment. Follow `references/onboarding.md` exactly; it marks the
  four [HUMAN] moments. Ends by writing `~/.device-it/config.json` (the setup-done flag).

## Reference map

- `references/onboarding.md` — one-time zero-touch-lane setup wizard (agent-driven; use
  connected email/browser MCPs to shrink the cert dance to two human touches).
- `references/zero-touch-edge-cases.md` — battle-tested field notes: VPS apps, the verified
  APNs cert sequence, funnel hardening, profile serving, gitignored private state.
- `references/web-push.md` — notifications to installed apps without any Apple cert (VAPID).
- `references/mdm-protocol.md` — nanomdm endpoints, command plists, lifecycle, renewal.
- `references/hosting.md` — deploy driver contract, vercel details, custom domains, caveats.
- `references/report-template.md` — the exact final report to give the user.

## Honest limits (state them, don't hide them)

- Offline starts after the FIRST launch (SW caches then) — no lane can launch the app for you.
- Backend-dependent apps: shell works offline, API calls need their backend.
- The zero-touch lane is Apple-only. Android/desktop always use the scan lane (1-tap install
  there, so no real loss). Non-Apple devices never need setup.
- Apple device asleep during push → icon appears when it wakes ("pushed", not "confirmed").
- Yearly APNs cert renewal (~3 min); doctor warns 30 days out.
