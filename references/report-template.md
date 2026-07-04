# Final report format

Lead with the outcome, then only what changes what the user does next.

## Zero-touch lane (MDM push — Apple devices)
> **Done. "<Name>" is on your <device>.** (icon: <icon>, url: <url>)
> Tap it once while online and it's offline-capable from then on.
> Update: rerun /device-it here. Remove: /device-it remove <slug>.

Use the enrolled device's real name (iPad / iPhone). If it hasn't acknowledged yet: say
"pushed — it appears the moment the device wakes", never pretend it's confirmed.

## Scan lane (QR/link — any device)
> **Ready.** On the device, scan this QR (or tap the link I texted you), then:
> - **iPhone/iPad**: Share → Add to Home Screen (≈2 taps).
> - **Android / desktop Chrome-Edge**: tap the browser's Install prompt (1 tap).
> Name and icon are pre-set; fullscreen + offline after first open. On-page hint guides iOS users.

Show terminal QR + saved PNG path.

## Always include
- Verification table: build / manifest+icons / sw / deploy 200s / offline reload / device ack —
  each ✓ or an honest ✗ with one-line cause.
- Backend caveat when inspect found API calls.
- Anything skipped (e.g. Playwright unavailable → offline check deferred).
