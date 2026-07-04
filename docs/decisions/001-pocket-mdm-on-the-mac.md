# 001 — Run the MDM on the user's own machine, on demand

**Status:** accepted (2026-07-04)

## Context

Zero-touch install ("the icon just appears, no taps") is only possible on Apple devices
through the MDM protocol: a managed web clip pushed to an enrolled device. Every obvious
way to get an MDM costs something: hosted services charge per device per month
(SimpleMDM ≈ $2.50/device/mo), and self-hosting normally means renting a server and
babysitting it.

## Decision

Run [nanomdm](https://github.com/micromdm/nanomdm) **on the user's own machine, started
only while an install is being pushed**, exposed through a Tailscale Funnel (stable
public HTTPS hostname, free), with a free APNs push certificate via mdmcert.download.

The insight that makes this sound: **the MDM server only needs to be reachable at the
moment a push happens — and pushes only ever originate from this same machine running
device-it.** The apps themselves live on real static hosting and cache offline; the MDM
is just the delivery courier. A courier that only exists during deliveries costs nothing
between them.

## Consequences

- $0/month; no third-party service holds device-management power over the user's devices.
- The funnel hostname is baked into the enrollment profile — changing tailnets means a
  one-minute re-enroll.
- Apple requires yearly renewal of the push certificate (~3 min; `doctor` warns 30 days
  ahead). Renewing with the same Apple ID keeps the topic stable; creating a *new* cert
  instead would force re-enrollment.
- If the device is asleep during a push, APNs delivers on wake — device-it reports
  "pushed", never falsely "installed".

## Alternatives considered

Hosted MDM (rejected — see [REJECTED/simplemdm-managed-mdm.md](REJECTED/simplemdm-managed-mdm.md)),
a rented VPS (recurring cost, permanent attack surface, still needs the same push cert),
and no MDM at all (leaves QR-only installs; kept as the universal lane, but it can't
reach zero taps).
