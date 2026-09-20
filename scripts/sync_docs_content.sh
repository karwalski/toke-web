#!/usr/bin/env bash
# sync_docs_content.sh — regenerate content/docs/, the tracked copy of the
# documentation the /docs/<section>/<slug> pages are rendered from.
#
# Why this exists, and why the copy is TRACKED (story 134.30)
# ----------------------------------------------------------
# The ~160 /docs/<section>/<slug> pages are rendered by `ooke build` from
# markdown under content/docs/. Until 134.30 that tree was eleven ABSOLUTE
# symlinks into one developer's /Users/.../tk/toke/docs, and `.gitignore`
# excluded the whole directory, so **zero entries were tracked**: a fresh clone
# had content/docs/ missing outright and `make build` stopped at its own guard.
# The repository's own CI hit this too — the check-generated job runs
# `make build` without checking out the compiler repo at all.
#
# Same root cause as toke 127.85 (vendored sources ignored) and ooke 134.21 (the
# test helper ignored): an ignore rule written for build OUTPUT that also
# swallowed a build INPUT. Both were fixed by tracking the input, and so is this.
#
# The alternatives were rejected for the reasons 127.85 rejected submodules and
# a download step: a relative symlink is still dangling in a clone of this
# repository alone, and a sync-at-build-time step puts another checkout between
# clone and build — exactly the failure being fixed. A tracked copy is ~160
# files / ~1.6 MB and makes the build depend on nothing outside the clone.
#
# The copy is GENERATED, never hand-edited
# ----------------------------------------
# The documentation is authored in the toke repository. This script is the only
# thing that writes content/docs/.
#
#   Maintainer workflow when documentation changes:
#     1. edit the markdown in ~/tk/toke/docs (that is the canonical source)
#     2. cd ~/tk/toke-website && make docs-content     # or run this script
#     3. git commit the resulting content/docs/ change alongside the doc change
#
#   To verify the copy is in step without writing anything:
#     ./scripts/sync_docs_content.sh --check           # exit 1 on drift
#
# Without the toke repository available, both modes fall back to verifying the
# tracked copy is present and complete, and PASS — so `make ci` and `make build`
# work in a bare clone (this is also what keeps 127.88 from getting worse).
#
# The mapping below IS the site's information architecture: a /docs/<section>/
# URL prefix on the left, the directory in the toke repo that fills it on the
# right. Change it here and nowhere else.
#
# Usage:   ./scripts/sync_docs_content.sh [--check]
#          TOKE_REPO=/path/to/toke ./scripts/sync_docs_content.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

TOKE_REPO="${TOKE_REPO:-${HOME}/tk/toke}"
MODE="sync"
[[ "${1:-}" == "--check" ]] && MODE="check"

# <url section>:<dir under ${TOKE_REPO}/docs>
#
# 134.30 removed two entries that were duplicates, not sections:
#   community        served ${TOKE_REPO}/docs/about,  the same pages as /docs/about
#   getting-started  served ${TOKE_REPO}/docs/guide,  the same pages as /docs/learn
# 196 pages were published of which only 159 were distinct, every build logged
# duplicate "no slug" warnings, and both duplicate prefixes were in the sitemap.
# They are now emitted as REDIRECTS by scripts/build_static.sh, which keeps the
# 37 live URLs answering without publishing the content twice — see the
# RETIRED_SECTIONS table there.
#
# `examples` is deliberately absent: the hand-made link pointed at
# ${TOKE_REPO}/docs/examples, which does not exist, so /docs/examples/* has
# never been buildable and is not in the sitemap.
SECTIONS=(
  "about:about"
  "compiler:compiler"
  "cookbook:cookbook"
  "decisions:decisions"
  "learn:guide"
  "reference:reference"
  "spec:spec"
  "stdlib:stdlib"
  "tutorials:tutorials"
)

# Only markdown is copied. `ooke build` renders one page per *.md; the other
# files in those directories (canonical.json, grammar.ebnf, the sample programs
# and review evidence) are read by tools in the toke repo, not by this build,
# and tracking them here would mirror data this repository does not serve.
have_source=1
[[ -d "${TOKE_REPO}/docs" ]] || have_source=0

# ── No toke repository: verify the tracked copy and pass ────────────────────
if (( ! have_source )); then
  missing=()
  for entry in "${SECTIONS[@]}"; do
    section="${entry%%:*}"
    [[ -d "content/docs/${section}" ]] && \
      [[ -n "$(find "content/docs/${section}" -name '*.md' -print -quit)" ]] || \
      missing+=("content/docs/${section}")
  done
  if (( ${#missing[@]} )); then
    echo "ERROR: the documentation content is missing and cannot be regenerated." >&2
    echo "       These section(s) are absent or empty:" >&2
    printf '         %s\n' "${missing[@]}" >&2
    echo "" >&2
    echo "       content/docs/ is TRACKED in git (story 134.30). Restore it with:" >&2
    echo "         git checkout -- content/docs" >&2
    echo "       To regenerate it from the documentation source instead, check out" >&2
    echo "       github.com/karwalski/toke and re-run with TOKE_REPO=/path/to/toke:" >&2
    echo "         TOKE_REPO=/path/to/toke ./scripts/sync_docs_content.sh" >&2
    echo "       (looked for the source at: ${TOKE_REPO}/docs)" >&2
    exit 1
  fi
  echo "==> content/docs/: using the tracked copy ($(find content/docs -name '*.md' | wc -l | tr -d ' ') markdown files across ${#SECTIONS[@]} sections)"
  echo "    ${TOKE_REPO}/docs is not present, so nothing was re-derived."
  exit 0
fi

# ── Toke repository present: regenerate (or compare) ────────────────────────
staging="$(mktemp -d)"
trap 'rm -rf "${staging}"' EXIT

missing=0
for entry in "${SECTIONS[@]}"; do
  section="${entry%%:*}"
  src="${TOKE_REPO}/docs/${entry##*:}"
  if [[ ! -d "${src}" ]]; then
    echo "    ERROR: ${src} does not exist (section /docs/${section}/)" >&2
    missing=$((missing + 1))
    continue
  fi
  mkdir -p "${staging}/${section}"
  (cd "${src}" && find . -name '*.md' -type f -print0) \
    | (cd "${src}" && xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "${staging}/${section}" {})
done

if (( missing > 0 )); then
  echo "ERROR: ${missing} section source(s) missing under ${TOKE_REPO}/docs" >&2
  echo "       content/docs would be incomplete; refusing to write it." >&2
  exit 1
fi

if [[ "${MODE}" == "check" ]]; then
  if diff -rq "${staging}" content/docs >/dev/null 2>&1; then
    echo "==> content/docs/ matches ${TOKE_REPO}/docs ($(find content/docs -name '*.md' | wc -l | tr -d ' ') files)"
    exit 0
  fi
  echo "ERROR: content/docs/ has drifted from ${TOKE_REPO}/docs." >&2
  diff -rq "${staging}" content/docs 2>&1 | sed "s#${staging}#<toke docs>#; s#^#       #" >&2
  echo "" >&2
  echo "       content/docs/ is a GENERATED, TRACKED copy — do not edit it by hand." >&2
  echo "       Regenerate and commit it:  make docs-content && git add content/docs" >&2
  exit 1
fi

echo "==> Syncing content/docs/ from ${TOKE_REPO}/docs"
rm -rf content/docs
mkdir -p content/docs
cp -R "${staging}/." content/docs/

count="$(find content/docs -name '*.md' | wc -l | tr -d ' ')"
echo "    content/docs/ ready (${count} markdown files across ${#SECTIONS[@]} sections)"

if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  if ! git diff --quiet -- content/docs || [[ -n "$(git ls-files --others --exclude-standard content/docs)" ]]; then
    echo "    NOTE: the tracked copy changed. Commit it, or the site will publish"
    echo "          documentation that no longer matches ${TOKE_REPO}/docs:"
    echo "            git add content/docs && git commit -m '...' -- content/docs"
  fi
fi
