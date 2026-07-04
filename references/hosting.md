# Hosting drivers

Contract: `deploy/<driver>.sh <dist> <slug>` → prints `URL=` (stable across redeploys) and
`PROJECT=`; optionally `CLAIM_URL=`, `CLAIM_CLI=`, `PASSWORD=`, `EPHEMERAL=`, `NOTE=`.
The web clip and service worker point at URL forever; per-deploy hash URLs are never used.

`deploy/pick.mjs [preferred]` chooses: config/arg override → first authed of
vercel → netlify → cloudflare → gh-pages → fallback netlify-anon. All probes have hard
timeouts. `surge` and `tunnel` are reachable only by explicit `--driver`.

## vercel
Project `deviceit-<slug>`, URL `https://deviceit-<slug>.vercel.app` (falls back to the
CLI-printed production URL if the pretty name is taken). Stage dir `~/.device-it/stage/`
keeps the `.vercel` link. Remove: `vercel remove deviceit-<slug> --yes`.

## netlify (authed)
Site `deviceit-<slug>` found-or-created via API, `netlify deploy --prod --site <id>`.
Multi-team accounts may need one manual `netlify sites:create` (the driver says so).

## cloudflare
`wrangler pages project create` + `wrangler pages deploy` → `deviceit-<slug>.pages.dev`.

## gh-pages
Repo `deviceit-<slug>` (**public — the built bundle is world-readable; disclose!**),
force-pushed `gh-pages` branch, SPA 404.html + .nojekyll, polls until the page serves.
URL `https://<user>.github.io/deviceit-<slug>/` — our `--base ./` builds handle the subpath.

## netlify-anon (the no-account lane — live-verified behavior)
`npx netlify-cli@26 deploy --allow-anonymous --prod` from a scratch dir. Facts:
- Claimable for **60 minutes**, then deleted. Claim URL + CLI claim command are parsed and
  surfaced; run.sh auto-opens the claim page on this computer (usually one GitHub-SSO click).
- **Password-gated until claimed** (password parsed and reported). So the flow is CLAIM FIRST,
  then install. HTTP verification is deferred on this lane (would 401 pre-claim).
- **Daily anonymous-deploy limit per machine** — the driver detects it and suggests logging
  into any host or `--driver tunnel`.
- After claiming, the site belongs to the USER's account; future updates need `netlify login`.
- The claim banner (pwaify `--claim-banner 1`, auto-set by run.sh) rides the QR target as
  `#claim=<url>`; iOS storage partitioning means it works in the browser visit — where
  claiming happens anyway.

## surge (explicit only)
`deviceit-<slug>.surge.sh`. Needs SURGE creds in env or config.deploy.surge. One-time account
creation is inline in the CLI (`npx surge`: email+password, no browser) — agent-guided.
Adds 200.html SPA fallback.

## tunnel (explicit only, last resort)
`npx serve` + `cloudflared` quick tunnel. EPHEMERAL: lives while this machine runs the two
processes (pidfiles in `~/.device-it/tunnel/`). SW keeps the installed app alive offline, but
cache eviction while the machine is off breaks it — say so.

## Notes
- Vite builds get `--base ./` (subpath-safe everywhere). CRA: `PUBLIC_URL=.`. Next: static
  export only.
- Wrap mode (`run.sh --url`) skips hosting entirely — web clip + QR around an existing URL.
- Public URL = public app; gh-pages also means public source. Auth walls break offline —
  don't add one unless asked.
- Custom domains: CNAME via the user's DNS (e.g. Simply MCP) + the host's domains command.
