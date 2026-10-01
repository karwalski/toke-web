#!/usr/bin/env python3
"""
check_deploy_posture.py — the deploy path of this PUBLIC repository keeps the
posture toke story 121.27 set (audit-120 DEP-01, DEP-03, DEP-06).

Rules, over every file git tracks:

  host-key   No ssh option that turns host-key checking off:
             StrictHostKeyChecking=no, UserKnownHostsFile=/dev/null, or
             GlobalKnownHostsFile=/dev/null. The deploy sends the build inputs
             that become the live binary; an unverified host receives them.
  tls-key    No shell command that rsyncs or scps certs/. The origin's TLS key
             is provisioned on the server and never leaves it (DEP-03).
  key-file   No private key material ("BEGIN ... PRIVATE KEY"), and no path to
             a real key file under ~/.ssh other than an obvious placeholder
             (<key>, your-key).
  address    No IPv4 literal that could be infrastructure: anything outside
             loopback, the private ranges, 0.0.0.0, the RFC 5737 documentation
             ranges and the short list of well-known public examples below.
             Cloudflare's published edge ranges are allowed only as CIDRs in
             specs/production-config.md, where the firewall rule lists them.

Usage:  python3 scripts/check_deploy_posture.py [--selftest] [ROOT]
Exit:   0 clean, 1 findings (each printed as file:line: rule: text).

--selftest plants one instance of every rule in a scratch repository and
fails unless each is reported: a gate that has never been seen to fail is not
evidence.
"""
import ipaddress
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HOSTKEY_OFF = re.compile(
    r"StrictHostKeyChecking\s*=?\s*no\b|(?:User|Global)KnownHostsFile\s*=?\s*/dev/null",
    re.I)
PRIVATE_KEY = re.compile(r"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----")
SSH_KEY_PATH = re.compile(r"\.ssh/([A-Za-z0-9_.<>-]+\.(?:pem|key))|\.ssh/(id_[a-z0-9]+)\b")
PLACEHOLDER = re.compile(r"<|your|example|placeholder", re.I)
IPV4 = re.compile(r"(?<![\d.])((?:\d{1,3}\.){3}\d{1,3})(/\d{1,2})?(?![\d.])")

# Public addresses that appear in examples and are nobody's infrastructure.
ALLOWED_PUBLIC = {
    "1.1.1.1", "8.8.8.8", "8.8.4.4", "9.9.9.9",   # public resolvers
    "1.2.3.4", "5.6.7.8",                         # stock example addresses
}
CIDR_FILE = "specs/production-config.md"          # Cloudflare edge ranges
SELF = "scripts/check_deploy_posture.py"          # its own patterns and plants


def tracked(root):
    out = subprocess.run(["git", "-C", str(root), "ls-files", "-z"],
                         capture_output=True, check=True).stdout
    return [p for p in out.decode("utf-8", "replace").split("\0") if p]


def logical_lines(text):
    """Shell logical lines: backslash-newline continuations joined."""
    lines, cur, start = [], "", 1
    for n, raw in enumerate(text.split("\n"), 1):
        if not cur:
            start = n
        if raw.rstrip().endswith("\\"):
            cur += raw.rstrip()[:-1] + " "
            continue
        lines.append((start, cur + raw))
        cur = ""
    if cur:
        lines.append((start, cur))
    return lines


def benign_ip(addr, cidr, path):
    try:
        ip = ipaddress.IPv4Address(addr)
    except ValueError:
        return True                   # 999.1.2.3 — a version string, not an IP
    if cidr and path == CIDR_FILE:
        return True
    if (ip.is_loopback or ip.is_private or ip.is_unspecified or ip.is_multicast
            or ip.is_link_local or ip.is_reserved):
        return True                   # is_private covers 10/8, 172.16/12,
                                      # 192.168/16 and RFC 5737 TEST-NETs
    return addr in ALLOWED_PUBLIC


def scan(root):
    root = Path(root)
    findings = []
    for rel in tracked(root):
        if rel == SELF:
            continue
        p = root / rel
        try:
            data = p.read_bytes()
        except OSError:
            continue
        if b"\0" in data[:8192]:
            continue                  # binary
        text = data.decode("utf-8", "replace")
        is_shell = rel.endswith((".sh", ".bash")) or rel == "Makefile" or \
            text.startswith("#!/usr/bin/env bash") or text.startswith("#!/bin/sh")
        for n, line in enumerate(text.split("\n"), 1):
            if HOSTKEY_OFF.search(line):
                findings.append((rel, n, "host-key", line.strip()))
            if PRIVATE_KEY.search(line):
                findings.append((rel, n, "key-file", "private key material"))
            for m in SSH_KEY_PATH.finditer(line):
                name = m.group(1) or m.group(2)
                if not PLACEHOLDER.search(name):
                    findings.append((rel, n, "key-file", m.group(0)))
            for m in IPV4.finditer(line):
                # A document section number such as "RFC 3986 §6.2.2.2" has
                # the shape of an address; a section sign before it says it is
                # not one.
                if line[:m.start()].rstrip().endswith("\u00a7"):
                    continue
                if not benign_ip(m.group(1), m.group(2), rel):
                    findings.append((rel, n, "address", m.group(0)))
        if is_shell:
            for n, line in logical_lines(text):
                code = line.split("#", 1)[0] if not line.lstrip().startswith("#") else ""
                if re.search(r"\b(rsync|scp)\b", code) and re.search(r"\bcerts\b", code):
                    findings.append((rel, n, "tls-key", " ".join(code.split())[:120]))
    return findings


def selftest():
    with tempfile.TemporaryDirectory() as d:
        r = Path(d)
        subprocess.run(["git", "init", "-q", str(r)], check=True)
        (r / "specs").mkdir()
        # The planted address is assembled here so that no public address
        # appears as a literal in this public file.
        planted_ip = ".".join(str(o) for o in (203, 0, 114, 9))
        (r / "deploy.sh").write_text(
            "#!/usr/bin/env bash\n"
            'SSH_OPTS="-o StrictHostKeyChecking=no"\n'
            'rsync -az -e "ssh" \\\n  "$ROOT/certs/" \\\n  "$REMOTE:certs/"\n'
            "# export TOKE_DEPLOY_KEY=~/.ssh/prod-box.pem\n"
            f"# export TOKE_DEPLOY_HOST={planted_ip}\n")
        (r / "k.txt").write_text("-----BEGIN RSA PRIVATE KEY-----\n")
        (r / "specs" / "production-config.md").write_text(
            "173.245.48.0/20\n10.0.0.1\n127.0.0.1\n1.2.3.4\n192.0.2.7\n")
        (r / "ok.sh").write_text(
            "#!/usr/bin/env bash\n# rsync certs/ is not done here\n"
            'SSH_OPTS="-o StrictHostKeyChecking=yes"\n'
            "# TOKE_DEPLOY_KEY=~/.ssh/<key>.pem ~/.ssh/your-key.pem\n"
            "echo 2.8.0.1.5\n"
            "# see RFC 3986 \u00a76.2.2.2 and \u00a7 7.1.2.3\n")
        (r / "cidr-elsewhere.md").write_text("104.16.0.0/13\n")
        subprocess.run(["git", "-C", str(r), "add", "-A"], check=True)
        got = {(f, rule) for f, _, rule, _ in scan(r)}
    want = {("deploy.sh", "host-key"), ("deploy.sh", "tls-key"),
            ("deploy.sh", "key-file"), ("deploy.sh", "address"),
            ("k.txt", "key-file"), ("cidr-elsewhere.md", "address")}
    missing, extra = want - got, got - want
    for f, rule in sorted(missing):
        print(f"selftest: FAIL -- planted {rule} in {f} was not reported")
    for f, rule in sorted(extra):
        print(f"selftest: FAIL -- clean file {f} reported as {rule}")
    if missing or extra:
        return 1
    print(f"selftest: OK -- all {len(want)} planted findings reported, 0 false positives")
    return 0


def main(argv):
    args = [a for a in argv if a != "--selftest"]
    if "--selftest" in argv and selftest() != 0:
        return 1
    root = Path(args[0]) if args else Path(__file__).resolve().parent.parent
    findings = scan(root)
    for f, n, rule, text in findings:
        print(f"{f}:{n}: {rule}: {text}")
    if findings:
        print(f"check_deploy_posture: FAIL -- {len(findings)} finding(s)")
        return 1
    print(f"check_deploy_posture: OK -- {len(tracked(root))} tracked files, no host-key, "
          "tls-key, key-file or address findings")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
