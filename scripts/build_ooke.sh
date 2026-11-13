#!/usr/bin/env bash
# build_ooke.sh — build the ooke that renders /docs, from the commit OOKE_REF pins
# (story 132.149).
#
# `ooke build` renders every /docs/<section>/<slug> page (scripts/build_static.sh),
# so the ooke version decides what those pages say: an ooke without the 132.148
# front-matter fix publishes /docs/about/canonical titled '"Canonical facts'.
# Until this script, the build used whatever binary sat at
# ~/tk/toke-ooke/ooke-toke -- a feature-branch build from 2026-09-20 -- and the
# GitHub workflow had no ooke at all. Now one file, OOKE_REF, names the commit,
# and this script builds exactly that commit.
#
# How: the pinned commit is exported with `git archive` from OOKE_SRC (any clone
# of karwalski/ooke that has the commit) into a cache directory, and built there
# with ooke's own Makefile. OOKE_SRC's working tree, index and branches are never
# touched -- `git archive` only reads objects -- so it can be a checkout another
# branch is being worked on in. A finished build is reused while the ooke commit,
# the toke checkout and the compiler are all unchanged (a stamp file records the
# three); change any of them and it is rebuilt.
#
# Usage:
#   scripts/build_ooke.sh              build if needed; print the binary's path last
#   scripts/build_ooke.sh --print-ref  print the pinned commit and exit
#
# Environment:
#   OOKE_SRC    a git clone of karwalski/ooke holding the pinned commit
#               (default: ~/tk/toke-ooke; CI: the checkout at the pinned ref)
#   TOKE_ROOT   the toke checkout ooke compiles against (default: ~/tk/toke)
#   TKC         the compiler (default: $TOKE_ROOT/tkc)
#   OOKE_CACHE  where builds are kept (default: ${XDG_CACHE_HOME:-~/.cache}/toke-website/ooke)
#   OOKE_JOBS   make -j for the ooke build (default: 2)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }

# The pin: the one line of OOKE_REF that is a full 40-character sha.
pinned_ref() {
  local f="${REPO_ROOT}/OOKE_REF" ref
  [[ -f "${f}" ]] || die "OOKE_REF is missing at ${f} (story 132.149)"
  ref="$(grep -E '^[0-9a-f]{40}$' "${f}" || true)"
  [[ "$(printf '%s\n' "${ref}" | grep -c .)" == 1 ]] ||
    die "OOKE_REF must hold exactly one full 40-character commit sha (found: ${ref:-none})"
  printf '%s\n' "${ref}"
}

REF="$(pinned_ref)"
if [[ "${1:-}" == "--print-ref" ]]; then
  echo "${REF}"
  exit 0
fi

OOKE_SRC="${OOKE_SRC:-${HOME}/tk/toke-ooke}"
TOKE_ROOT="${TOKE_ROOT:-${HOME}/tk/toke}"
TKC="${TKC:-${TOKE_ROOT}/tkc}"
OOKE_CACHE="${OOKE_CACHE:-${XDG_CACHE_HOME:-${HOME}/.cache}/toke-website/ooke}"
OOKE_JOBS="${OOKE_JOBS:-2}"

[[ -d "${TOKE_ROOT}/src/stdlib" ]] ||
  die "no toke checkout at TOKE_ROOT='${TOKE_ROOT}' (no src/stdlib). Set TOKE_ROOT=/path/to/toke."
if [[ "${TKC}" != */* ]] && command -v "${TKC}" >/dev/null 2>&1; then
  TKC="$(command -v "${TKC}")"          # a bare name, as deploy.sh passes (TKC=tkc)
fi
if [[ ! -x "${TKC}" ]]; then
  die "no compiler at TKC='${TKC}'. Build it (make -C ${TOKE_ROOT}) or set TKC=/path/to/tkc."
fi
TKC="$(cd "$(dirname "${TKC}")" && pwd)/$(basename "${TKC}")"
TOKE_ROOT="$(cd "${TOKE_ROOT}" && pwd)"

toke_rev="$(git -C "${TOKE_ROOT}" rev-parse HEAD 2>/dev/null || echo none)"
tkc_sum="$(shasum -a 256 "${TKC}" | cut -c1-16)"
stamp_want="$(printf 'ooke=%s\ntoke=%s\ntkc=%s\n' "${REF}" "${toke_rev}" "${tkc_sum}")"

dest="${OOKE_CACHE}/${REF}"
bin="${dest}/ooke-toke"
if [[ -x "${bin}" && -f "${dest}/.ooke-ref" && "$(cat "${dest}/.ooke-ref")" == "${stamp_want}" ]]; then
  echo "==> ooke ${REF:0:12} (pinned in OOKE_REF): using the cached build" >&2
  echo "${bin}"
  exit 0
fi

git -C "${OOKE_SRC}" rev-parse --git-dir >/dev/null 2>&1 ||
  die "OOKE_SRC='${OOKE_SRC}' is not a git clone of karwalski/ooke. Set OOKE_SRC=/path/to/ooke."
if ! git -C "${OOKE_SRC}" cat-file -e "${REF}^{commit}" 2>/dev/null; then
  echo "ERROR: ooke ${REF} (pinned in OOKE_REF) is not in OOKE_SRC='${OOKE_SRC}'." >&2
  echo "       Fetch it there (git -C ${OOKE_SRC} fetch origin main), or point OOKE_SRC" >&2
  echo "       at a clone of karwalski/ooke that has it." >&2
  exit 1
fi

echo "==> Building ooke ${REF:0:12} (pinned in OOKE_REF) from ${OOKE_SRC}" >&2
echo "    toke ${toke_rev:0:12} at ${TOKE_ROOT}; tkc ${TKC}" >&2
mkdir -p "${OOKE_CACHE}"
work="$(mktemp -d "${OOKE_CACHE}/.build-XXXXXX")"
trap 'rm -rf "${work}"' EXIT
git -C "${OOKE_SRC}" archive --format=tar "${REF}" | tar -x -C "${work}"
if ! make -C "${work}" -j"${OOKE_JOBS}" TOKE_ROOT="${TOKE_ROOT}" TKC="${TKC}" >"${work}.log" 2>&1; then
  tail -40 "${work}.log" >&2
  echo "ERROR: building ooke ${REF:0:12} failed (full log: ${work}.log)" >&2
  exit 1
fi
rm -f "${work}.log"
[[ -x "${work}/ooke-toke" ]] || die "the ooke build made no ooke-toke binary"
printf '%s\n' "${stamp_want}" > "${work}/.ooke-ref"
rm -rf "${dest}"
mv "${work}" "${dest}"
trap - EXIT
echo "    built: ${bin} ($("${bin}" --version))" >&2
echo "${bin}"
