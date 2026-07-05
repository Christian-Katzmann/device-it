# Zero-Touch Edge Cases

Field notes from a full setup of a local-first app hosted on a VPS, then installed on an
iPhone through the pocket MDM. **This entire flow is battle-tested end to end.**

## If you just want it working (the 5-line version)

```bash
bash scripts/run.sh --url https://app.on-your-vps.example --name "App" --slug app --icon icon.png   # VPS app → wrap mode
# cert once (agent drives; human does email-verify + Apple 2FA): onboarding.md §4, verified sequence below
bash scripts/mdm/make-ca.sh https://<tailnet-host> <push-topic>
bash scripts/mdm/mdm-up.sh          # now exposes only /mdm by default (hardening below is built in)
node scripts/mdm/mdm-push.mjs install --profile ~/.device-it/out/app.mobileconfig
```

Enrollment profile onto the phone: **AirDrop first** (no server needed — onboarding.md §7);
the funnel-served recipe below is the remote-device fallback. Everything after this line is
the detail and the sharp edges, in the order we hit them.

## VPS-hosted local-first apps

If the app is already hosted on a stable HTTPS VPS URL, use wrap mode:

```bash
bash scripts/run.sh --url https://app.example.test --name "App" --slug app --icon /path/to/icon.png
```

For markdown/file-backed apps, copy the whole local app data model or registry, not just one
current file. A phone web clip will otherwise miss new records created later. A simple sync loop
is enough: mirror the local registry/files to the VPS and pull back non-conflicting phone edits.

iOS web clips are painful behind HTTP Basic Auth because credentials are not a good app-like
experience. Prefer no auth for the installed app URL when the user accepts a public URL. If auth
must stay, use a deliberately simple credential only when the user asks for that trade-off.

## APNs MDM cert flow

The reliable path:

1. Register an organizational email at `https://mdmcert.download/registration`.
2. Generate a request with `mdmctl mdmcert.download -new -email=<org-email>`.
3. Save the encrypted signed request attachment from email.
4. Decrypt it with the same `mdmctl mdmcert.download -decrypt=<attachment>` inputs.
5. Upload the resulting `.req` to `https://identity.apple.com/pushcert/`.
6. Download the Apple `MDM_*.pem`.
7. Combine the Apple cert with the matching decrypted private key into `~/.device-it/mdm/push.pem`.
8. Extract the topic from the cert subject: `UID=com.apple.mgmt.External.<uuid>`.

Keep the Apple ID used for this certificate. Renewal must renew the same certificate, not create
a new unrelated one, or devices need re-enrollment.

## Tailscale Funnel routing

**Now the default** — `mdm-up.sh` path-scopes the funnel to `/mdm` itself; you only need this
section when running the funnel by hand. Expose only the MDM endpoint:

```bash
tailscale funnel --bg --yes --https=443 --set-path /mdm http://127.0.0.1:9930/mdm
```

Do not expose `/` to nanomdm. Public Funnel hosts get scanned quickly, and scanner traffic will
pollute logs with unrelated paths. Verify:

```bash
tailscale funnel status
curl -o /dev/null -w 'root=%{http_code}\n' https://<tailnet-host>/
curl -o /dev/null -w 'mdm=%{http_code}\n' https://<tailnet-host>/mdm
```

Expected: root `404`, MDM `400` for an unauthenticated curl.

## Serving enrollment profiles

Direct Funnel file serving may return `500` for hidden/private folders. Use a tiny local server
and map only the profile path:

```bash
cp ~/.device-it/mdm/enroll.mobileconfig /tmp/enroll.mobileconfig
python3 - <<'PY'
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
path = Path('/tmp/enroll.mobileconfig')
class Handler(BaseHTTPRequestHandler):
    def _send(self, body):
        if self.path.split('?', 1)[0] != '/enroll.mobileconfig':
            self.send_response(404); self.end_headers(); return
        data = path.read_bytes()
        self.send_response(200)
        self.send_header('Content-Type', 'application/x-apple-aspen-config')
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        if body: self.wfile.write(data)
    def do_HEAD(self): self._send(False)
    def do_GET(self): self._send(True)
HTTPServer(('127.0.0.1', 3000), Handler).serve_forever()
PY
```

In another shell:

```bash
tailscale funnel --bg --yes --https=443 --set-path /enroll.mobileconfig \
  http://127.0.0.1:3000/enroll.mobileconfig
```

Generate a QR for `https://<tailnet-host>/enroll.mobileconfig`. After the device checks in, stop
the profile server, close Funnel with `mdm-down.sh`, and delete `/tmp/enroll.mobileconfig`.

## Private state

Canonical private state lives in `~/.device-it/`:

- `~/.device-it/config.json`
- `~/.device-it/mdm/push.pem`, `push.key`, `push-topic.txt`
- `~/.device-it/mdm/enroll.mobileconfig`
- `~/.device-it/mdm/dbkv/`
- `~/.device-it/out/*.mobileconfig`

If the user asks for plugin-local recovery material, mirror it under
`device-it/local-state/<case>/`. That path is gitignored. Never stage it.
