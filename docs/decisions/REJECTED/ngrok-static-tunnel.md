# Rejected: ngrok free static domain as the MDM tunnel

**What was proposed.** Expose the pocket MDM through ngrok's free static domain
(`*.ngrok-free.app`) instead of Tailscale Funnel — one fewer account for users who
don't run Tailscale.

**What made it attractive.** ngrok's free tier includes one stable static domain per
account; setup is a single command; no tailnet concepts to learn.

**Why it was wrong for this project.** ngrok's free tier injects a browser interstitial
page in front of requests. An MDM check-in is a machine-to-machine plist POST from
iPadOS — an interstitial in that path is exactly the kind of silent, hard-to-debug
breakage a one-time-setup lane cannot afford. Tailscale Funnel serves clean TLS with a
stable hostname and no interception.

**When it might become right.** If ngrok drops the interstitial from machine traffic on
the free tier, it becomes a legitimate alternative tunnel driver — the enrollment
template only needs a hostname.
