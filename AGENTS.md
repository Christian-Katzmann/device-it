# AGENTS.md — working on device-it itself

This file is for humans and agents **changing this repo**. For *using* device-it on a
project, read [SKILL.md](SKILL.md) instead — that's the operating contract.

Safest first command: `git status --short`
Prove nothing is broken: `npm run verify` (syntax-checks every script and manifest; no
network, no deploys, safe to run anywhere).

## Do not

- **Do not test `scripts/deploy/netlify-anon.sh` with real deploys casually.** Anonymous
  deploys have a per-machine **daily quota** — burning it in tests takes the no-account
  lane away from a real run for the rest of the day. Validate the parser against the
  captured sample in the script's comments instead.
- **Do not run `scripts/mdm/mdm-push.mjs` unless a device is genuinely enrolled.** It
  queues real MDM commands against real hardware via APNs.
- **Do not modernize the bash.** Everything must run on macOS's stock bash 3.2: no
  `"${arr[@]}"` on possibly-empty arrays under `set -u` (it aborts silently), no
  associative arrays, no `mapfile`. This has bitten us once already.
- **Do not let the PWA transform touch project source.** `pwaify.mjs` operates on the
  BUILT output dir only — that contract is why device-it is safe to run on any repo.
- **Do not point web clips or QRs at per-deploy hash URLs.** The stable production URL is
  a hard contract: the installed icon and the service worker reference it forever.

## Conventions that will surprise you

- **Deploy drivers speak a line protocol.** Each `scripts/deploy/<name>.sh` prints
  `URL=`, `PROJECT=`, and optionally `CLAIM_URL=`, `PASSWORD=`, `EPHEMERAL=`, `NOTE=`.
  `run.sh` greps these lines — new drivers must follow it exactly.
- `deploy/pick.mjs` chooses the driver: config/arg override → first authed of
  vercel/netlify/cloudflare/gh-pages → anonymous Netlify. Every probe has a hard timeout
  so a hung CLI can't stall the pipeline.
- **netlify-cli is pinned to `@26`** because `netlify-anon.sh` parses its human-readable
  output (URL, claim link, password). A major bump means re-verifying the parser.
- **macOS-only tools are guarded** (`plutil`, `sips`) so the scan lane works on Linux.
  Keep the guards — CI runs on ubuntu.
- Runtime state lives in `~/.device-it/` (registry, artifacts, MDM material, staging) —
  nothing stateful in the repo. The MDM API key lives in the macOS keychain
  (`device-it-nanomdm`), never in files.
- "MDM enrolled" means `config.devices[]` is non-empty — NOT that the config file exists
  (the config also stores deploy preferences before any enrollment).
- The on-page install hint and claim banner are injected by `pwaify.mjs` between marker
  comments; re-runs strip and re-inject, so the transform is idempotent.
- `skills/device-it/SKILL.md` is a thin **Codex wrapper** around the root SKILL.md. Its
  one addition: Codex runs shell from the plugin cache root, so the project dir must be
  passed explicitly. Don't fold it into the root file — the split is the compatibility.

- **Routes are captured knowledge.** SKILL.md's install-routes table exists so agents don't
  re-derive solved problems. When you field-verify a new route (or an edge case), write it
  into `references/` and add a table row — flip ◐ to ✅ only after a real run.

## Where truth lives

- [SKILL.md](SKILL.md) — usage contract (pipeline, verbs, honest limits)
- [references/hosting.md](references/hosting.md) — driver contract + live-verified quirks
  (60-min claim window, pre-claim password gate, daily anon quota)
- [references/mdm-protocol.md](references/mdm-protocol.md) — nanomdm endpoints, command
  plists, `Mdm-Signature` identity (TLS terminates at the funnel), cert renewal
- [docs/decisions/](docs/decisions/) — architecture rationale, including REJECTED/
