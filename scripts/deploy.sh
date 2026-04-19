#!/usr/bin/env bash
# deploy.sh — Cross-compile toke-website for Linux x86_64 and deploy to Lightsail
#
# Required env vars:
#   TOKE_DEPLOY_HOST  — remote host (e.g. the Lightsail instance hostname/IP)
#   TOKE_DEPLOY_KEY   — path to SSH private key file
#
# Optional env vars (have defaults):
#   TOKE_DEPLOY_USER  — remote SSH user        (default: bitnami)
#   TOKE_DEPLOY_DIR   — remote working dir     (default: ~/website)
#
# Usage:
#   TOKE_DEPLOY_HOST=my.host.example \
#   TOKE_DEPLOY_KEY=~/.ssh/my-key.pem \
#   ./scripts/deploy.sh

set -euo pipefail

# ── Validate required env vars ─────────────────────────────────────────────
if [[ -z "${TOKE_DEPLOY_HOST:-}" ]]; then
  echo "ERROR: TOKE_DEPLOY_HOST is not set" >&2
  exit 1
fi
if [[ -z "${TOKE_DEPLOY_KEY:-}" ]]; then
  echo "ERROR: TOKE_DEPLOY_KEY is not set" >&2
  exit 1
fi

DEPLOY_USER="${TOKE_DEPLOY_USER:-bitnami}"
DEPLOY_DIR="${TOKE_DEPLOY_DIR:-~/website}"
SSH_OPTS="-i ${TOKE_DEPLOY_KEY} -o StrictHostKeyChecking=no -o BatchMode=yes"
REMOTE="${DEPLOY_USER}@${TOKE_DEPLOY_HOST}"

# Paths local to this repo (script lives in scripts/, so repo root is one up)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TKC="${TKC:-tkc}"  # override with TKC=/path/to/tkc if not on PATH
STDLIB_SRC="/Users/matthew.watt/tk/toke/src/stdlib"

echo "==> [1/5] Emitting LLVM IR from main.tk on Mac"
cd "${REPO_ROOT}"
"${TKC}" --emit-llvm main.tk -o main.ll
echo "    main.ll written ($(wc -c < main.ll) bytes)"

echo "==> [2/5] Rsyncing IR, stdlib C sources, and site content to ${REMOTE}:${DEPLOY_DIR}"

# Ensure remote deploy directory exists
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" "mkdir -p ${DEPLOY_DIR}/stdlib"

# Rsync LLVM IR
rsync -az -e "ssh ${SSH_OPTS}" \
  main.ll \
  "${REMOTE}:${DEPLOY_DIR}/"

# Rsync stdlib C sources
rsync -az -e "ssh ${SSH_OPTS}" \
  "${STDLIB_SRC}/" \
  "${REMOTE}:${DEPLOY_DIR}/stdlib/"

# Rsync site content (certs, sites, logs skeleton)
rsync -az --exclude='logs/*.log' -e "ssh ${SSH_OPTS}" \
  certs/ sites/ \
  "${REMOTE}:${DEPLOY_DIR}/"

echo "==> [3/5] Compiling website_server binary on remote (clang-15)"
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" bash <<ENDSSH
set -euo pipefail
cd "${DEPLOY_DIR}"
clang-15 main.ll stdlib/*.c -o website_server -lpthread -lm
echo "    Compiled OK: \$(ls -lh website_server | awk '{print \$5, \$9}')"
ENDSSH

echo "==> [4/5] Restarting website_server on remote"
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" bash <<ENDSSH
set -euo pipefail
cd "${DEPLOY_DIR}"
pkill -f website_server || true
sleep 1
mkdir -p logs
nohup ./website_server > logs/server.out 2>&1 &
echo "    website_server started (PID \$!)"
ENDSSH

echo "==> [5/5] Smoke test: GET /health on remote"
# Allow a moment for the server to bind
sleep 2
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" \
  'curl --fail --silent --show-error http://localhost:8081/health'

echo ""
echo "Deploy complete."
