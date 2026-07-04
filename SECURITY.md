# Security

device-it runs entirely on your machine. It ships no telemetry, calls no home, and holds
no accounts of its own — deploys use *your* locally-authed CLIs, and the optional pocket
MDM stores its certificates in `~/.device-it/` and its API key in your macOS keychain.

Two areas deserve real scrutiny, and reports about them are especially welcome:

- **The pocket MDM** (`scripts/mdm/`, `templates/enroll.mobileconfig.tpl`) — an enrolled
  device grants management powers to material on your machine. Anything that could leak
  the device CA, push certificate, or API key, or let a third party reach the nanomdm
  API through the funnel, is a vulnerability.
- **Deploy drivers** (`scripts/deploy/`) — they execute vendor CLIs and parse their
  output. Anything that could make a driver deploy to, or claim, a site the user didn't
  intend counts.

**Reporting:** use GitHub's private vulnerability reporting on this repository
(Security → Report a vulnerability). Please don't open public issues for exploitable
problems. This is a solo-maintained project — expect an honest reply within a week, not
an enterprise SLA.
