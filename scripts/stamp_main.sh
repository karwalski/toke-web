#!/usr/bin/env bash
# stamp_main.sh — write main.tk with its build identity filled in (story 132.153).
#
# /health and /api/version used to return a hard-coded "0.3.0", which a reader
# takes as the toke version and which nothing ever updated. The values are now
# stamped into the source the binary is compiled from, at the moment the IR is
# emitted, so they describe exactly that binary and cannot drift:
#
#   tokeversion()  the version `$TKC --version` prints (e.g. 3.2.0), i.e. the
#                  toke compiler that emits main.ll
#   tokebuild()    the git sha that tkc reports ("toke 3.2.0 (git a26e1e7bcdf7)"
#                  -> "a26e1e7bcdf7"), or "unknown" when it prints none, so a
#                  binary built with an unreleased toke main is told apart from
#                  one built with the release of the same version
#   sitecommit()   the short sha of this checkout's HEAD, with "-dirty" when a
#                  tracked file differs from it
#
# Usage:  TKC=/path/to/tkc scripts/stamp_main.sh OUT.tk
# OUT.tk is a build output (gitignored); main.tk itself is never rewritten, so
# `make check-toke` and `tkc --emit-deps main.tk` still read the tracked file.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TKC="${TKC:-${HOME}/tk/toke/tkc}"
OUT="${1:?usage: stamp_main.sh OUT.tk}"

# "toke 3.2.0 (git a26e1e7bcdf7)" -> "3.2.0"
raw="$("${TKC}" --version 2>/dev/null | head -1)" || {
  echo "stamp_main: '${TKC} --version' failed" >&2; exit 1; }
toke_ver="$(printf '%s\n' "${raw}" | sed -n 's/^toke \([0-9][0-9A-Za-z.+-]*\).*/\1/p')"
if [[ -z "${toke_ver}" ]]; then
  echo "stamp_main: cannot read a toke version from '${raw}'" >&2; exit 1
fi

# "toke 3.2.0 (git a26e1e7bcdf7)" -> "a26e1e7bcdf7"
toke_build="$(printf '%s\n' "${raw}" | sed -n 's/.*(git \([0-9A-Za-z.+-]*\)).*/\1/p')"
toke_build="${toke_build:-unknown}"

site="$(git -C "${REPO_ROOT}" rev-parse --short=12 HEAD 2>/dev/null || true)"
if [[ -z "${site}" ]]; then
  site="unknown"
elif ! git -C "${REPO_ROOT}" diff --quiet HEAD -- 2>/dev/null; then
  site="${site}-dirty"
fi

# Both values are [0-9A-Za-z.+-] only, so they need no escaping in a toke
# string or in the JSON it is spliced into.
for v in "${toke_ver}" "${toke_build}" "${site}"; do
  [[ "${v}" =~ ^[0-9A-Za-z.+-]+$ ]] || { echo "stamp_main: refusing value '${v}'" >&2; exit 1; }
done

src="${REPO_ROOT}/main.tk"
n_t=$(grep -c '^f=tokeversion():\$str{<"unstamped"};$' "${src}" || true)
n_b=$(grep -c '^f=tokebuild():\$str{<"unstamped"};$' "${src}" || true)
n_s=$(grep -c '^f=sitecommit():\$str{<"unstamped"};$' "${src}" || true)
if [[ "${n_t}" != 1 || "${n_b}" != 1 || "${n_s}" != 1 ]]; then
  echo "stamp_main: main.tk must define tokeversion(), tokebuild() and sitecommit() exactly" >&2
  echo "            once, each returning \"unstamped\" (found ${n_t}, ${n_b} and ${n_s})" >&2
  exit 1
fi

sed -e "s/^f=tokeversion():\\\$str{<\"unstamped\"};\$/f=tokeversion():\$str{<\"${toke_ver}\"};/" \
    -e "s/^f=tokebuild():\\\$str{<\"unstamped\"};\$/f=tokebuild():\$str{<\"${toke_build}\"};/" \
    -e "s/^f=sitecommit():\\\$str{<\"unstamped\"};\$/f=sitecommit():\$str{<\"${site}\"};/" \
    "${src}" > "${OUT}.tmp"
# Replace OUT only when it changed, so make does not re-emit the IR and relink
# the binary on every run.
if [[ -f "${OUT}" ]] && cmp -s "${OUT}.tmp" "${OUT}"; then
  rm -f "${OUT}.tmp"
else
  mv "${OUT}.tmp" "${OUT}"
fi
echo "stamp_main: ${OUT} (toke ${toke_ver} build ${toke_build}, site ${site})" >&2
