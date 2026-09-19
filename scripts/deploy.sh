#!/usr/bin/env bash
# deploy.sh — Deploy toke-website to Lightsail
#
# Modes:
#   content   Rsync build/, sites/, static/, certs/ only (no binary rebuild)
#   full      Emit LLVM IR, cross-compile on server, rsync everything, restart
#   auto      Detect which mode is needed based on git changes (default)
#
# Both modes rebuild build/ and re-check every gate BEFORE anything is synced
# (story 132.17): build/ is gitignored, so without this a deploy from a clean
# checkout published whatever stale tree happened to be on the deploying
# machine, and a deploy after a template edit published the pre-edit render.
#
# Required env vars:
#   TOKE_DEPLOY_HOST  — remote host (e.g. Lightsail IP)
#   TOKE_DEPLOY_KEY   — path to SSH private key file
#
# Optional env vars:
#   TOKE_DEPLOY_USER  — remote SSH user        (default: bitnami)
#   TOKE_DEPLOY_DIR   — remote working dir     (default: ~/website)
#
# Usage:
#   # Auto-detect mode based on git changes since last deploy tag:
#   ./scripts/deploy.sh
#
#   # Content-only deploy (templates, static, sites — no binary rebuild):
#   ./scripts/deploy.sh content
#
#   # Full deploy (rebuild binary + all content):
#   ./scripts/deploy.sh full
#
# Environment shortcuts (source one before running):
#   export TOKE_DEPLOY_HOST=<host>          # never commit the real address
#   export TOKE_DEPLOY_KEY=~/.ssh/<key>.pem

set -euo pipefail

# ── Validate required env vars ───────────────────────────────────────────
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
TKC="${TKC:-tkc}"
STDLIB_SRC="/Users/matthew.watt/tk/toke/src/stdlib"

MODE="${1:-auto}"

# ── Auto-detect mode ─────────────────────────────────────────────────────
# Files that require a binary rebuild when changed:
BINARY_PATTERNS="main\.tk$|pages/.*\.tk$"

detect_mode() {
  cd "${REPO_ROOT}"

  # Find last deploy tag, or fall back to comparing against HEAD~5
  local base
  base=$(git tag -l 'deploy-*' --sort=-version:refname | head -1 2>/dev/null || true)
  if [[ -z "${base}" ]]; then
    echo "  (no deploy tag found, comparing last 5 commits)" >&2
    base="HEAD~5"
  else
    echo "  (comparing against last deploy tag: ${base})" >&2
  fi

  # Get list of changed files
  local changed
  changed=$(git diff --name-only "${base}" HEAD 2>/dev/null || true)

  if [[ -z "${changed}" ]]; then
    # No changes detected — check for uncommitted changes
    changed=$(git diff --name-only HEAD 2>/dev/null || true)
    changed+=$'\n'$(git diff --name-only --cached 2>/dev/null || true)
  fi

  if [[ -z "${changed}" ]]; then
    echo "  No changes detected. Defaulting to content deploy." >&2
    echo "content"
    return
  fi

  # Check if any binary-critical files changed
  if echo "${changed}" | grep -qE "${BINARY_PATTERNS}"; then
    echo "  Binary-critical files changed:" >&2
    echo "${changed}" | grep -E "${BINARY_PATTERNS}" | sed 's/^/    /' >&2
    echo "full"
  else
    echo "  Only content/template/static files changed." >&2
    echo "content"
  fi
}

if [[ "${MODE}" == "auto" ]]; then
  echo "==> Auto-detecting deploy mode..."
  MODE=$(detect_mode)
  echo "==> Mode: ${MODE}"
fi

# ── Validate mode ────────────────────────────────────────────────────────
if [[ "${MODE}" != "content" && "${MODE}" != "full" ]]; then
  echo "ERROR: Unknown mode '${MODE}'. Use: content, full, or auto" >&2
  exit 1
fi

echo ""
echo "=========================================="
echo "  Deploy mode: ${MODE}"
echo "  Target:      ${REMOTE}:${DEPLOY_DIR}"
echo "=========================================="
echo ""

# ── Pre-deploy gates (story 132.17) ──────────────────────────────────────
# Nothing leaves this machine until the site's own toke sources compile, the
# generated pages match their sources, and build/ has been rebuilt and proven
# newer than everything it is derived from.
echo "==> [0/n] Pre-deploy gates"
cd "${REPO_ROOT}"

make TKC="${TKC}" check-toke
make check-roadmap
make check-llms

echo "    materialising content/docs/ from the toke repo"
./scripts/sync_docs_content.sh

echo "    rebuilding build/ before sync"
./scripts/build_static.sh

# Hard stop: build/ must not be older than static/, templates/ or content/.
python3 scripts/check_build_fresh.py

echo "    gates passed"
echo ""

# ── Helper: rsync content to server ──────────────────────────────────────
rsync_content() {
  local step_prefix="$1"

  echo "==> ${step_prefix} Rsyncing build output to server..."

  # Ensure remote directories exist
  # shellcheck disable=SC2029
  ssh ${SSH_OPTS} "${REMOTE}" "mkdir -p ${DEPLOY_DIR}/build ${DEPLOY_DIR}/sites ${DEPLOY_DIR}/logs"

  # Rsync build/ (the static tree served at / by http.servedir).
  #
  # --delete is correct again as of story 134.8. It was disabled because the
  # ~110 per-slug /docs/<section>/<slug> pages were served from a May-era render
  # that no tool in the tree could reproduce (`ooke build` aborted with RT005),
  # so deleting them would have taken them off the site — at the cost of letting
  # that stale render survive every deploy, still carrying claims Epic 132 had
  # withdrawn. scripts/build_static.sh now renders those pages from
  # content/docs/ on every build, so build/ owns every file it syncs and an
  # orphan here is a real orphan.
  rsync -az --delete -e "ssh ${SSH_OPTS}" \
    "${REPO_ROOT}/build/" \
    "${REMOTE}:${DEPLOY_DIR}/build/"
  echo "    build/ synced (--delete: orphans are removed)"

  # Rsync sites/. It is no longer a docroot the server reads per host — the
  # vhost mechanism was removed in story 132.21 — but main.tk still reads
  # sites/tokelang.dev/llms.txt at startup, so it must be present remotely.
  rsync -az --delete -e "ssh ${SSH_OPTS}" \
    "${REPO_ROOT}/sites/" \
    "${REMOTE}:${DEPLOY_DIR}/sites/"
  echo "    sites/ synced"

  # Rsync certs/ (TLS certificates)
  if [[ -d "${REPO_ROOT}/certs" ]]; then
    rsync -az -e "ssh ${SSH_OPTS}" \
      "${REPO_ROOT}/certs/" \
      "${REMOTE}:${DEPLOY_DIR}/certs/"
    echo "    certs/ synced"
  fi

  # Rsync static/ (CSS, images, tokenizer data)
  rsync -az --delete -e "ssh ${SSH_OPTS}" \
    "${REPO_ROOT}/static/" \
    "${REMOTE}:${DEPLOY_DIR}/static/"
  echo "    static/ synced"

  # Rsync templates/ (.tkt pages — rendered dynamically by http.servepages).
  # The server reads these per-request, so template edits ship on a content
  # deploy with no rebuild/restart.
  rsync -az --delete -e "ssh ${SSH_OPTS}" \
    "${REPO_ROOT}/templates/" \
    "${REMOTE}:${DEPLOY_DIR}/templates/"
  echo "    templates/ synced"
}

# ── Content-only deploy ──────────────────────────────────────────────────
if [[ "${MODE}" == "content" ]]; then
  rsync_content "[1/2]"

  echo "==> [2/2] Smoke test: GET /health on remote"
  sleep 1
  # shellcheck disable=SC2029
  HEALTH=$(ssh ${SSH_OPTS} "${REMOTE}" \
    'curl --fail --silent --show-error http://localhost:8081/health' 2>/dev/null || true)

  if [[ -n "${HEALTH}" ]]; then
    echo "    ${HEALTH}"
    echo ""
    echo "Content deploy complete. Server is running (no restart needed)."
  else
    echo "    WARNING: Health check failed or server not running."
    echo "    Content was synced but server may need a restart (use 'full' mode)."
  fi
  exit 0
fi

# ── Full deploy ──────────────────────────────────────────────────────────
echo "==> [1/6] Emitting LLVM IR from main.tk"
cd "${REPO_ROOT}"
"${TKC}" --emit-llvm --out main.ll main.tk
echo "    main.ll written ($(wc -c < main.ll) bytes)"

echo "==> [2/6] Rsyncing IR + stdlib C sources to server"

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

echo "    IR + stdlib synced"

rsync_content "[3/6]"

echo "==> [4/6] Compiling website_server binary on remote (clang-15)"
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" bash <<ENDSSH
set -euo pipefail
cd "${DEPLOY_DIR}"
clang-15 main.ll stdlib/*.c -o website_server -lpthread -lm
echo "    Compiled OK: \$(ls -lh website_server | awk '{print \$5, \$9}')"
ENDSSH

echo "==> [5/6] Restarting website_server on remote"
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

echo "==> [6/6] Smoke test: GET /health on remote"
sleep 2
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" \
  'curl --fail --silent --show-error http://localhost:8081/health'

echo ""
echo "Full deploy complete."
