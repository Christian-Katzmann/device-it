# Rejected: SimpleMDM (hosted MDM) as the zero-touch backbone

**What was proposed.** Use SimpleMDM as the MDM: hosted, API-first, zero maintenance —
upload a web-clip profile via REST, assign to device, done. It was the original design's
Tier-1 lane.

**What made it attractive.** Genuinely the cleanest API in the MDM space; no push-cert
dance, no server to run; the 30-day trial would have validated the whole zero-touch UX
before any commitment.

**Why it was wrong for this project.** ≈$2.50/device/month forever, plus an account
signup as a *hard prerequisite* — for a skill whose entire promise became "works out of
the box for everyone, $0". A recurring fee to install your own hobby apps on your own
iPad fails the sniff test, and the onboarding friction contradicted plug-and-play.

**When it might become right.** If mdmcert.download (the free push-cert signer, a
community service) ever disappears, or for a user managing many devices who values
zero-maintenance over $30/year — the pocket-MDM scripts are driver-shaped enough that a
SimpleMDM driver could be added back without touching the pipeline.
