# Production Server Configuration

> **Read this first (story 132.55a, 2026-09-24).** This file mixes three kinds of
> statement, and until now did not say which was which. Each row below is now
> marked:
>
> - **repo** — confirmed from this repository or the toke stdlib it links
>   (`main.tk`, `scripts/deploy.sh`, `toke/src/stdlib/`), with the line cited;
> - **recorded** — a measurement or setting written down on the date given and
>   not re-checked since;
> - **owner** — only the server can say. Nothing in any repository confirms it,
>   and nobody with repository access alone should act on it during an
>   incident without checking first. Listed together at the end (§ Owner
>   checks, story 134.38).

## Instance specification

Recorded 2026-04 (the soak-test period); not re-checked.

| Parameter | Value |
|-----------|-------|
| Provider | AWS Lightsail |
| Region | ap-southeast-2 (Sydney) |
| OS | Amazon Linux 2023, x86_64 |
| vCPU | 2 |
| RAM | 420 MB |
| Swap | 420 MB (zram) |
| Disk | 20 GB NVMe |
| Static IP | (Lightsail static IP assigned) |

## Server binary

| Parameter | Value | Basis |
|-----------|-------|-------|
| Source | `main.tk` (module `website`), compiled with `tkc --emit-llvm`, linked on the server with clang-15 | **repo** — `scripts/deploy.sh` full mode |
| Port | 443, TLS from `certs/cert.pem` + `certs/key.pem`; `--port N` overrides; `--http` serves plain HTTP with 2 workers instead | **repo** — `main.tk` `main()` |
| Binary name and path | **Unconfirmed.** This file said `/home/ec2-user/website/main`; other ops notes (134.9 backups) say `website`. `deploy.sh` deliberately does not assume either: it stages `website-new` and tells the operator to read `ExecStart` from the unit | **owner** |
| Service | `toke-website.service` — the name `deploy.sh` assumes (`TOKE_DEPLOY_SERVICE` overrides). **The unit file is not in any repository**, so its contents below are unverified | **owner** |
| Unit settings | `Restart=always`, `RestartSec=3`, `AmbientCapabilities=CAP_NET_BIND_SERVICE`, `Environment=TK_HTTP_WORKERS=8` | **owner** |
| SSH user | **Contradictory in the repo.** `deploy.sh` defaults `TOKE_DEPLOY_USER` to `bitnami`; this file names Amazon Linux 2023, whose default user is `ec2-user`. Set `TOKE_DEPLOY_USER` explicitly until the owner records which | **owner** |

## Worker configuration

`TK_HTTP_WORKERS` is read by the stdlib's server loop (**repo** —
`toke/src/stdlib/http.c`; default is the CPU count). That it is set to 8 in the
unit is **owner**. The rest of this section is **recorded** 2026-04.

| Parameter | Value | Notes |
|-----------|-------|-------|
| `TK_HTTP_WORKERS` | 8 | Set in systemd unit Environment (owner) |
| Process count | 9 | 1 master + 8 workers |
| Per-worker RSS | ~13 MB | Observed under load |
| Total server RSS | ~110 MB | 9 processes at steady state |

### Memory headroom

| Component | Approximate usage |
|-----------|-------------------|
| OS + systemd | ~90 MB |
| toke server (8 workers) | ~110 MB |
| Buffers/cache | ~100 MB |
| **Available headroom** | **~120 MB + 420 MB swap** |

With 16 workers, steady-state RSS was ~217 MB leaving insufficient headroom. Two OOM kills occurred during the 72-hour soak test under sustained load. Reducing to 8 workers provides ~120 MB free RAM before swap is touched.

**Rule of thumb:** `workers * 15 MB + 90 MB` should be less than 70% of total RAM to avoid OOM under load spikes.

## Soak test results (72-hour, 2026-04-18 to 2026-04-21)

| Metric | Value |
|--------|-------|
| Duration | 72h 0m |
| Total requests | 33,632 |
| Successful | 33,090 |
| Errors | 542 |
| Slow (>1s) | 138 |
| Error rate | 1.6% |
| Availability | 98.4% |

### Test methodology

- Client: a separate Lightsail instance running `soak_test.sh` (address deliberately not recorded here — no infrastructure addresses in a public repo)
- Interval: every 30 seconds, 4 requests per cycle (`/health`, `/`, `/docs/learn/04-collections`, `/api/version`)
- Hourly summary reports logged
- 10-second curl timeout per request

### Error analysis

All 542 errors concentrated around two OOM-kill events:

| Event | Time (UTC) | Cause | Downtime | Recovery |
|-------|------------|-------|----------|----------|
| 1 | 2026-04-19 05:51 | OOM kill (16 workers) | ~3 seconds | systemd auto-restart |
| 2 | 2026-04-20 15:28 | OOM kill (16 workers) | ~3 seconds | systemd auto-restart |

Between OOM events and outside them: **100% availability**, 0 errors, all requests <1s.

### Prior test runs

| Run | File | Duration | Outcome |
|-----|------|----------|---------|
| Pre-fix | `soak_results_pre_fix.log` | ~10h (aborted) | Server went down at hour 6, continuous 000s — initial deployment issue |
| Pre-timeout-fix | `soak_results_pre_timeout_fix.log` | ~15min (aborted) | 10s timeouts on most requests — connection handling issue |
| Final | `soak_results.log` | 72h (complete) | 98.4% availability, OOM-only errors |

## Network configuration

**Recorded** 2026-04; the firewall rules and the Cloudflare mode are **owner**.

- **Proxy:** Cloudflare (DNS proxied, orange cloud)
- **Firewall:** iptables — allow SSH (22) and HTTPS (443) from Cloudflare IPs only, plus ICMP
- **TLS:** Self-signed cert on origin; Cloudflare handles public TLS termination (Full mode)
- **Rate limiting:** Per-worker, ~200 req/min per worker (not shared memory)

## Cloudflare IP allowlist

Only Cloudflare edge servers should reach port 443. The following CIDR ranges are allowed:

### IPv4
```
173.245.48.0/20
103.21.244.0/22
103.22.200.0/22
103.31.4.0/22
141.101.64.0/18
108.162.192.0/18
190.93.240.0/20
188.114.96.0/20
197.234.240.0/22
198.41.128.0/17
162.158.0.0/15
104.16.0.0/13
104.24.0.0/14
172.64.0.0/13
131.0.72.0/22
```

### IPv6
```
2400:cb00::/32
2606:4700::/32
2803:f800::/32
2405:b500::/32
2405:8100::/32
2a06:98c0::/29
2c0f:f248::/32
```

## Routing (there are no virtual hosts)

**repo** — `main.tk`. This section used to be a virtual-host table mapping four
hostnames to directories under `sites/`. Story 132.21 removed that routing:
every host the server answers for gets the same tree. In order of registration:

1. exact paths from `main.tk`: `/llms.txt`, `/health`, `/api/health`, `/api/version`;
2. `http.servepages("templates";"templates")` — one named route per `templates/*.tkt`;
3. `http.servedir("/";"build")` — everything else, from `build/`.

`sites/` is not a docroot; `scripts/build_static.sh` copies the files under
`sites/tokelang.dev/` that must be served at `/` into `build/`.

## What a content deploy changes without a restart

**repo** — `toke/src/stdlib/tk_web_glue.c`, `main.tk`. `deploy.sh content` syncs
files and restarts nothing. From the code, that is enough for some changes and
not others:

| Change | Live without a restart? | Why |
|---|---|---|
| an edit to an existing `templates/*.tkt` | yes | pages are re-read from disk on every request |
| a file under `build/` | yes | `servedir` opens the file per request |
| a template **added or removed** | **no** | `servepages` registers its routes once, at startup |
| `sites/tokelang.dev/llms.txt` | **no** | `main.tk` reads it once, at startup |
| `certs/*.pem` | **no** | loaded when the TLS listener starts |

That the running binary was built from a stdlib with this behaviour is
**owner** (it depends on which commit the live binary was linked from).

## Logging

| Parameter | Value | Basis |
|-----------|-------|-------|
| Access log | `logs/access.log`, relative to the server's working directory (`~/website` if the unit sets it) | **repo** — `main.tk` `log.openaccess(...)`; the directory is **owner** |
| Max lines | 10,000 (rotation) | **repo** — same call |
| Max age | 30 days | **repo** — same call |
| Systemd journal | `journalctl -u toke-website` | **owner** — follows from the unit name |

## Owner checks (story 134.38)

Only the server can answer these. Each is one command there; none needs a
change to any repository unless the answer differs from what is written above.

1. `systemctl cat toke-website.service` — does the unit exist under that name?
   Its `ExecStart` gives the live binary's name and path (this file said `main`,
   other notes say `website`), its `User=` settles the `bitnami`/`ec2-user`
   question, and its `Environment=`, `Restart=`, `RestartSec=` and
   `AmbientCapabilities=` lines confirm or correct the "Unit settings" row.
2. `systemctl show -p WorkingDirectory toke-website.service` — where
   `logs/access.log` actually is.
3. Which toke commit the live binary was linked from — it decides whether the
   "without a restart" table above describes the running server.
4. The firewall and Cloudflare settings under "Network configuration".

