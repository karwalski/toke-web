#!/usr/bin/env bash
# deploy.sh — Deploy toke-website to Lightsail
#
# Modes:
#   content   Rsync build/, sites/, static/, certs/ only (no binary rebuild)
#   full      Emit LLVM IR, rsync everything, cross-compile on server to a
#             STAGED binary, and stop. It never restarts anything (134.29).
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
#   # Full deploy (rebuild binary + all content; stops at the staged binary):
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
# Root of the toke checkout the stdlib C sources come from. Override with
# TOKE_ROOT when deploying from a different clone.
TOKE_ROOT="${TOKE_ROOT:-$(cd "${REPO_ROOT}/../toke" && pwd)}"

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
  # 134.29: the live server listens on 443 with TLS (specs/production-config.md),
  # not on the development port 8081 this used to probe, so the old check
  # could only ever report failure.
  HEALTH=$(ssh ${SSH_OPTS} "${REMOTE}" \
    'curl --fail --silent --show-error -k --max-time 8 https://localhost/health' 2>/dev/null || true)

  if [[ -n "${HEALTH}" ]]; then
    echo "    ${HEALTH}"
    echo ""
    echo "Content deploy complete. Server is running; edited templates and build/"
    echo "files are live now. A template ADDED or REMOVED, llms.txt, or certs/ only"
    echo "take effect after a restart (specs/production-config.md, 132.55a)."
  else
    echo "    WARNING: Health check failed or server not running."
    echo "    Content was synced but the server may need a restart:"
    echo "      sudo systemctl restart toke-website.service   (on the server; never nohup a copy)"
  fi
  exit 0
fi

# ── Full deploy ──────────────────────────────────────────────────────────
echo "==> [1/4] Emitting LLVM IR from main.tk"
cd "${REPO_ROOT}"
"${TKC}" --emit-llvm --out main.ll main.tk
echo "    main.ll written ($(wc -c < main.ll) bytes)"

# ── The stdlib source list, asked for rather than guessed (story 134.28) ──
#
# This used to be `rsync ${STDLIB_SRC}/` followed by `clang-15 main.ll
# stdlib/*.c` — a shell glob over every .c file that happened to sit in toke's
# stdlib directory. On 2026-09-20 that glob picked up two files carrying
# duplicate definitions and the link aborted mid-deploy; the deploy only
# finished because the two files were excluded by hand.
#
# Story 127.99 made `src/stdlib_deps.c` the authoritative manifest of which C
# sources each import pulls in, and taught the compiler to print it. So the set
# is now derived from main.tk's own imports: 68 sources for this program, not
# the ~124 files in the directory.
#
# `tkc --emit-deps <program>` prints one absolute C source path per line, then
# a line containing only `---`, then one linker flag per line.
echo "==> [2/4] Resolving stdlib sources via --emit-deps"

DEPS_RAW="$(mktemp)"
trap 'rm -f "${DEPS_RAW}"' EXIT
TKC_STDLIB_DIR="${TOKE_ROOT}/src/stdlib" "${TKC}" --emit-deps main.tk >"${DEPS_RAW}" 2>/dev/null

# ── The one place the output is massaged for the Linux build ─────────────
# Two transformations, and only these two:
#
#   1. Absolute -> repo-relative -> remote-relative. The compiler prints host
#      absolute paths rooted at TOKE_ROOT. The remote build needs the same
#      tree under ${DEPLOY_DIR}/toke/, because the stdlib .c files include
#      their vendored dependencies by relative path ("../../stdlib/vendor/...")
#      and so only compile if the layout around them matches.
#   2. `..` segments collapsed. The vendor entries arrive spelled through the
#      stdlib directory (src/stdlib/../../stdlib/vendor/tomlc99/toml.c);
#      rsync --files-from will not accept that, so it is normalised to
#      stdlib/vendor/tomlc99/toml.c.
#
# Nothing else is filtered, added, or reordered: the manifest is authoritative
# and a deploy that disagrees with it is the bug this story removes.
SRC_REL="$(mktemp)"; LINK_FLAGS="$(mktemp)"
trap 'rm -f "${DEPS_RAW}" "${SRC_REL}" "${LINK_FLAGS}"' EXIT

TOKE_ROOT="${TOKE_ROOT}" python3 - "${DEPS_RAW}" "${SRC_REL}" "${LINK_FLAGS}" <<'PYNORM'
import os, posixpath, sys
raw, srcs_out, flags_out = sys.argv[1], sys.argv[2], sys.argv[3]
root = os.environ["TOKE_ROOT"].rstrip("/") + "/"
lines = [l.strip() for l in open(raw) if l.strip()]
sep = lines.index("---")
srcs, flags = lines[:sep], lines[sep + 1:]
rel = []
for s in srcs:
    if not s.startswith(root):
        sys.exit("emit-deps path outside TOKE_ROOT: " + s)
    rel.append(posixpath.normpath(s[len(root):]))   # collapses the ../..
open(srcs_out, "w").write("".join(r + "\n" for r in rel))
open(flags_out, "w").write(" ".join(flags) + "\n")
PYNORM

SRC_COUNT=$(wc -l < "${SRC_REL}" | tr -d ' ')
echo "    ${SRC_COUNT} stdlib sources, link flags: $(cat "${LINK_FLAGS}")"

echo "==> [2b/4] Rsyncing IR + those sources to server"

# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" "mkdir -p ${DEPLOY_DIR}/toke"

rsync -az -e "ssh ${SSH_OPTS}" \
  main.ll \
  "${REMOTE}:${DEPLOY_DIR}/"

# Exactly the listed sources, plus the headers beside them that they include.
rsync -az --files-from="${SRC_REL}" -e "ssh ${SSH_OPTS}" \
  "${TOKE_ROOT}/" "${REMOTE}:${DEPLOY_DIR}/toke/"
rsync -az --include='*/' --include='*.h' --exclude='*' -e "ssh ${SSH_OPTS}" \
  "${TOKE_ROOT}/src/stdlib/" "${REMOTE}:${DEPLOY_DIR}/toke/src/stdlib/"
rsync -az --include='*/' --include='*.h' --exclude='*' -e "ssh ${SSH_OPTS}" \
  "${TOKE_ROOT}/stdlib/vendor/" "${REMOTE}:${DEPLOY_DIR}/toke/stdlib/vendor/"

echo "    IR + ${SRC_COUNT} sources synced"

rsync_content "[3/4]"

# ── The artefact, and where this script stops (story 134.29) ─────────────
#
# This used to compile `website_server`, then `pkill -f website_server`, start
# it again under `nohup` and health-check localhost:8081. None of that matches
# the server: the site is run by systemd (toke-website.service, Restart=always,
# see specs/production-config.md), on 443 with TLS, from a binary of a
# different name. So the tail would have started a SECOND server beside the
# supervised one — two processes, one port, and a restart loop — and then
# health-checked a port nothing listens on. Every real deploy since has gone
# through the manual staging path instead (134.9, 134.28).
#
# The script now stops at the artefact. It compiles to a STAGED name that
# nothing runs, so building never touches the live binary or the live process,
# and prints the promotion as explicit steps. Promotion is a human decision
# (every deploy is owner-approval-gated), and it is where the staged binary
# should be smoke-tested on a throwaway port first.
STAGED_BIN="${TOKE_DEPLOY_STAGED_BIN:-website-new}"
SERVICE="${TOKE_DEPLOY_SERVICE:-toke-website.service}"

echo "==> [4/4] Compiling ${STAGED_BIN} on remote (clang-15) — staged, not live"
# shellcheck disable=SC2029
REMOTE_SRCS="$(sed 's|^|toke/|' "${SRC_REL}" | tr '\n' ' ')"
REMOTE_LFLAGS="$(cat "${LINK_FLAGS}")"
# shellcheck disable=SC2029
ssh ${SSH_OPTS} "${REMOTE}" bash <<ENDSSH
set -euo pipefail
cd "${DEPLOY_DIR}"
# -x ir / -x c: clang would otherwise treat the .c files after main.ll as IR.
# -iquote toke/src/stdlib so the sources find their own headers; -I tomlc99 for
# the one vendored source in the list. Link flags come from --emit-deps, which
# is why -lssl/-lcrypto/-lz appear without this script knowing what needs them.
clang-15 -std=c99 -D_GNU_SOURCE -O1 \
  -iquote toke/src/stdlib \
  -I toke/stdlib/vendor/tomlc99 \
  -Wno-pedantic -DTK_HAVE_OPENSSL \
  -x ir main.ll -x c ${REMOTE_SRCS} \
  -o "${STAGED_BIN}" ${REMOTE_LFLAGS}
echo "    Compiled OK: \$(ls -lh "${STAGED_BIN}" | awk '{print \$5, \$9}')"
echo "    sha256: \$(sha256sum "${STAGED_BIN}" | cut -c1-16)"
ENDSSH

cat <<EOF

Full deploy STOPPED at the artefact: ${DEPLOY_DIR}/${STAGED_BIN} on the server.
Content (build/, sites/, static/, templates/) is already synced. Nothing was
restarted, and the running binary was not touched.

To promote it — an explicit, owner-approved step, run on the server:

  cd ${DEPLOY_DIR}
  systemctl cat ${SERVICE}              # read ExecStart: the live binary's name
  ./${STAGED_BIN} --port <spare-port> & # smoke-test on a throwaway port, then kill it
  cp <live-binary> <live-binary>.bak-\$(date +%Y%m%d)
  mv ${STAGED_BIN} <live-binary>
  sudo systemctl restart ${SERVICE}
  systemctl status ${SERVICE} --no-pager
  curl -sk --max-time 8 https://localhost/health

Never start the binary with nohup or kill it by hand: ${SERVICE} supervises it
with Restart=always, so a hand-started copy fights the service for the port.
EOF
