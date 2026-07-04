# Pocket MDM internals (nanomdm)

Pinned facts (from nanomdm operations guide; re-verify with `nanomdm -help` after upgrades):

- Device traffic: single endpoint `/mdm` (ServerURL). We do not use the split `-checkin` mode.
- API (HTTP Basic, user `nanomdm`, password = API key from keychain `device-it-nanomdm`):
  - `PUT /v1/enqueue/<udid>` — body = command plist → queues an MDM command.
  - `PUT /v1/push/<udid>` — fires the APNs poke; device then connects to `/mdm` and drains its queue.
  - `PUT /v1/pushcert` — body = concatenated PEM push cert + private key.
- Storage: `-storage filekv -storage-dsn ~/.device-it/mdm/dbkv` (file-backed, zero deps).
- Identity verification: TLS terminates at the Tailscale Funnel, so nanomdm cannot see a client
  cert. It falls back to parsing the `Mdm-Signature` header — REQUIRES `SignMessage=true` in the
  enrollment profile (templates/enroll.mobileconfig.tpl sets it). `-ca` must point at our CA.

## Commands we send

InstallProfile (web clip install/update — same PayloadIdentifier = in-place update):

```xml
<dict>
  <key>Command</key>
  <dict>
    <key>RequestType</key><string>InstallProfile</string>
    <key>Payload</key><data>BASE64-OF-MOBILECONFIG</data>
  </dict>
  <key>CommandUUID</key><string>UUID</string>
</dict>
```

RemoveProfile (zero-touch uninstall):

```xml
<key>RequestType</key><string>RemoveProfile</string>
<key>Identifier</key><string>dk.deviceit.&lt;slug&gt;</string>
```

Result verification: nanomdm logs each device connect with the CommandUUID and status
(`Acknowledged` / `Error`). `mdm-push.mjs` tails `~/.device-it/mdm/nanomdm.log` for 90s;
"queued" (not acked) usually just means the iPad is asleep — APNs delivers on wake.

## Lifecycle

- Server only needs to be up during pushes and at enrollment. `mdm-up.sh` / `mdm-down.sh`.
  Leaving it down between installs is fine and is the default posture.
- Yearly: APNs push cert renewal (doctor warns; see onboarding.md §4 RENEWAL).
- The funnel hostname is baked into enrollments. Keep the tailnet name stable; if it ever
  changes, re-enroll the iPad (1 minute) and update `serverUrl` in config.

## Security posture (solo-dev calibrated)

The MDM has device-management powers over the enrolled iPad; everything that matters lives in
`~/.device-it/mdm/` (CA key, push cert) and the login keychain (API key). The API listens on
127.0.0.1 only — the funnel exposes just what nanomdm serves; enqueue/push endpoints still
require the key. Good enough for one human managing their own device; don't reuse this CA for
anything else.
