# One-time setup (zero-touch lane: no-tap installs)

Run this the first time `/device-it setup` is invoked, or when `~/.device-it/config.json`
is missing and the user wants zero-touch. The scan lane needs none of this.

Agent does everything except the four [HUMAN] moments. Total human time ≈ 10 min, once.
When finished, write `~/.device-it/config.json` — its presence is the "setup done" flag;
never run onboarding again while it exists.

## 0. Preflight
- `vercel whoami` (deploy lane), `tailscale version` (install via brew if missing).
- Create dirs: `~/.device-it/{bin,mdm,out,stage}`.
- Private state is canonical in `~/.device-it/`. If a user wants a plugin-local recovery copy,
  store it under `device-it/local-state/<case>/`; that path is gitignored and may contain
  certs, private keys, profiles, UDIDs, and field notes.

## 1. Tailscale + Funnel
1. `tailscale status` — if stopped: `tailscale up` ([HUMAN] browser sign-in on first ever login).
2. Funnel needs HTTPS + funnel enabled on the tailnet: run `tailscale funnel --bg 9930`
   once; if it errors about policy, it prints the admin-console URL to click ([HUMAN] one click).
3. Record the stable hostname: `tailscale status --json` → `.Self.DNSName` (strip trailing dot).
   This becomes SERVER_URL and is BAKED INTO the enrollment — changing it later means re-enrolling (1 min).

## 2. nanomdm binary (v0.9.0 known-good; done already on this Mac)
- `gh release download v0.9.0 -R micromdm/nanomdm -p 'nanomdm-darwin-arm64-*.zip'` — the zip
  contains a DIRECTORY `nanomdm-darwin-arm64-v0.9.0/` holding the binary plus `cmdr.py`
  (command-plist generator, handy for debugging) and a sample `enroll.mobileconfig`
  (cross-check our template against it if enrollment misbehaves).
- Copy the binary to `~/.device-it/bin/nanomdm`, `chmod +x`, `xattr -d com.apple.quarantine`.
- Smoke: `nanomdm -version`; boot with `-api testkey` and expect 401 on unauthed `/v1/push/x`.
- Pin the version in config.

## 3. API key
- `openssl rand -hex 24` → store: `security add-generic-password -s device-it-nanomdm -a nanomdm -w <key>`.

## 4. APNs MDM push certificate (the one unavoidable Apple dance)
Free via mdmcert.download (issued to organizations; a CVR/company name is fine).

**Agent, drive this — the human has only TWO real touches.** Before starting, check which
MCPs this session has and use them; the whole step collapses to minutes:
- An email MCP (Outlook, Gmail, …) that can read the org inbox → fetch the mdmcert
  verification link AND the encrypted signed-CSR attachment yourself. Human touch #1
  disappears entirely.
- A browser MCP (Chrome) → drive https://identity.apple.com/pushcert/ yourself: sign-in
  page, upload the `.req`, download the `MDM_*.pem`. The human only enters their Apple ID
  password + 2FA tap (never type credentials for them). That's human touch #2, ~30 seconds.
Without those MCPs, narrate each step and let the human click; it's the same flow, just slower.

**Route A — mdmctl (preferred):** download micromdm release (has `mdmctl`), then
1. Register email at https://mdmcert.download/registration ([HUMAN or email-MCP] verify link).
2. `mdmctl mdmcert.download -new -email=<email>` → wait for the encrypted signed CSR by email
   (save attachment to `~/.device-it/mdm/`).
3. `mdmctl mdmcert.download -decrypt=<attachment>` → produces a `.req` push CSR.
4. [HUMAN: Apple ID + 2FA only; browser-MCP does the rest] Upload the `.req` at
   https://identity.apple.com/pushcert/ → "Create a Certificate" → download `MDM_...pem`.
5. Concatenate cert + the private key from step 2 into `~/.device-it/mdm/push.pem`.
6. Note the topic: `openssl x509 -in push.pem -noout -subject` → `UID=com.apple.mgmt.External.<uuid>`.

**Route B — manual:** follow https://mdmcert.download/instructions with raw openssl (CSR upload form).
**Field-verified end to end** — the exact working sequence is in `zero-touch-edge-cases.md` §APNs.

RENEWAL: yearly, same flow, at identity.apple.com — MUST use the same Apple ID and RENEW the
existing cert (not create a new one) or the topic changes and the iPad must re-enroll.
`doctor.sh` warns 30 days ahead.

## 5. CA + enrollment profile
- `scripts/mdm/make-ca.sh https://<tailnet-host> <push-topic>` → `~/.device-it/mdm/enroll.mobileconfig`.

## 6. Start the MDM and upload the push cert
- `scripts/mdm/mdm-up.sh`
- `curl -u "nanomdm:<api-key>" -T ~/.device-it/mdm/push.pem 'http://127.0.0.1:9930/v1/pushcert'`
  (expects JSON with the topic back).

## 7. Enroll the device
Get `enroll.mobileconfig` onto the device — in this order of preference:

1. **AirDrop (default).** The device is Apple and usually within arm's reach of this Mac:
   `open -a AirDrop ~/.device-it/mdm/enroll.mobileconfig` (or Finder → share). No server,
   no funnel path, no MIME headers, nothing to tear down. iOS receives it as a profile
   directly.
2. **Ride the app's own deploy.** Copy the profile into any static deploy this skill already
   made (`cp enroll.mobileconfig <dist>/ && redeploy`), QR that URL, delete + redeploy after.
   Correct MIME for free; works when the device is remote.
3. **Funnel-served (last resort, remote + no deploy).** Fiddly: hidden-folder 500s, MIME
   issues, scanner noise. Use the field-verified recipe in `zero-touch-edge-cases.md`
   §Serving enrollment profiles — don't improvise this one.

Then: [HUMAN, once ever] On the device: open the file/URL → Settings → "Profile Downloaded" →
Install → passcode → Install. (iOS may require Safari for URL downloads.)

After install:
- Watch `~/.device-it/mdm/nanomdm.log` for the enrollment (TokenUpdate) — extract the device UDID.
- If option 2/3 was used: remove the profile from the deploy / stop the server and close its funnel path.
- Write config:
   ```json
   {
     "serverUrl": "https://<host>.<tailnet>.ts.net",
     "pushTopic": "com.apple.mgmt.External.<uuid>",
     "nanomdmVersion": "<pinned>",
     "devices": [{ "name": "iPad", "udid": "<UDID>" }],
     "deploy": { "driver": "vercel" },
     "imessage_to": ""
   }
   ```

## 8. Prove the pipe
Push a test web clip (any registry app, or the demo) via
`scripts/mdm/mdm-push.mjs install --profile <x>.mobileconfig` and confirm Acknowledged in the log
AND ask the human to confirm the icon appeared. Then remove it (`mdm-push.mjs remove --identifier ...`)
to demonstrate zero-touch uninstall. Setup complete.

## Troubleshooting
- Device never checks in after push: iPad asleep/off-wifi (APNs will retry when it wakes), funnel
  down (`mdm-up.sh`), or push cert/topic mismatch (compare profile Topic vs cert UID).
- Enrollment install fails: profile served with wrong MIME (needs download, not inline view),
  or p12 rejected → regenerate with `-legacy` (make-ca.sh already tries this).
- `Mdm-Signature` errors in log: enrollment profile must have `SignMessage=true` (ours does);
  nanomdm parses identity from that header because TLS terminates at the funnel.
- Public scanner noise in `nanomdm.log`: use the edge-case workaround in
  `zero-touch-edge-cases.md` to expose only `/mdm` and `/enroll.mobileconfig` temporarily.
