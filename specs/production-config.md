# Production Server Configuration

## Instance specification

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

| Parameter | Value |
|-----------|-------|
| Binary | `/home/ec2-user/website/main` |
| Source | `main.tk` (compiled with tkc) |
| Port | 443 (TLS) |
| Capability | `CAP_NET_BIND_SERVICE` (via systemd `AmbientCapabilities`) |
| Service | `toke-website.service` (systemd, `Restart=always`, `RestartSec=3`) |

## Worker configuration

| Parameter | Value | Notes |
|-----------|-------|-------|
| `TK_HTTP_WORKERS` | 8 | Set in systemd unit Environment |
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

## Virtual hosts

| Hostname | Root directory |
|----------|---------------|
| `tokelang.dev` | `sites/tokelang.dev` |
| `www.tokelang.dev` | `sites/tokelang.dev` |
| `staging.tokelang.dev` | `sites/tokelang.dev` |
| `loke.tokelang.dev` | `sites/loke.tokelang.dev` |

## Logging

| Parameter | Value |
|-----------|-------|
| Access log | `~/website/logs/access.log` |
| Max lines | 10,000 (rotation) |
| Max age | 30 days |
| Systemd journal | `journalctl -u toke-website` |
