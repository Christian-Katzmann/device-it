# Rejected: native-app lanes as defaults (Capacitor/TestFlight, AltStore/sideloading)

**What was proposed.** Wrap projects in Capacitor and ship real native binaries — via
TestFlight (paid developer account) or free-provisioning sideloading (AltStore-style).

**What made it attractive.** "Real" apps: full native API access, App Store-grade
presence, no PWA caveats.

**Why it was wrong for this project.** Every native path imports Apple's ceremony:
TestFlight means $99/year, per-app App Store Connect setup, and review friction;
free provisioning means 7-day expiring signatures, a 3-app limit, and re-sign
babysitting — strictly worse than a PWA for the actual use case (personal web projects
on your own devices). The web platform already delivers the target experience: icon,
fullscreen, offline.

**When it might become right.** The moment a project genuinely needs native APIs the web
can't reach (HealthKit, deep camera control, background audio). That would be a separate
opt-in lane (`--native`), not a default — the ceremony should be priced only by those
who need it.
