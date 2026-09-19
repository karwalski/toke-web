#!/usr/bin/env bash
# sync_docs_content.sh — materialise content/docs/ from the toke repo (story 134.8).
#
# Why this exists
# ---------------
# The ~110 /docs/<section>/<slug> pages are rendered by `ooke build` from
# markdown under content/docs/. That tree is gitignored, because it is not
# authored here: it is the canonical documentation in the toke repo. Until this
# script existed the links were created by hand on one machine, so a clean clone
# had no docs content and could not rebuild those pages at all — which is why
# they were served from a May-era mirror and still carried claims Epic 132 has
# since withdrawn.
#
# The mapping below IS the site's information architecture: a /docs/<section>/
# URL prefix on the left, the directory in the toke repo that fills it on the
# right. Change it here and nowhere else.
#
# Usage:   ./scripts/sync_docs_content.sh [--copy]
#          TOKE_REPO=/path/to/toke ./scripts/sync_docs_content.sh
#
# By default each section is a symlink into ${TOKE_REPO}/docs so edits there show
# up immediately. --copy materialises real files instead (for CI or a build host
# that does not have the toke repo mounted at build time).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

TOKE_REPO="${TOKE_REPO:-${HOME}/tk/toke}"
MODE="link"
[[ "${1:-}" == "--copy" ]] && MODE="copy"

if [[ ! -d "${TOKE_REPO}/docs" ]]; then
  echo "ERROR: ${TOKE_REPO}/docs not found. Set TOKE_REPO=/path/to/toke." >&2
  exit 1
fi

# <url section>:<dir under ${TOKE_REPO}/docs>
#
# NOTE (134.8): `community` and `getting-started` intentionally reproduce the
# mapping the site has been published with — community duplicates `about` and
# getting-started duplicates `guide`, so those URL prefixes serve the same
# markdown as /docs/about/ and /docs/learn/. That is duplicate content and
# should be resolved as a content decision; it is recorded here rather than
# silently changed, so the rebuild matches what is live.
#
# `examples` is deliberately absent: the hand-made link pointed at
# ${TOKE_REPO}/docs/examples, which does not exist, so /docs/examples/* has
# never been buildable and is not in the sitemap.
SECTIONS=(
  "about:about"
  "community:about"
  "compiler:compiler"
  "cookbook:cookbook"
  "decisions:decisions"
  "getting-started:guide"
  "learn:guide"
  "reference:reference"
  "spec:spec"
  "stdlib:stdlib"
  "tutorials:tutorials"
)

echo "==> Syncing content/docs/ from ${TOKE_REPO}/docs (${MODE})"
rm -rf content/docs
mkdir -p content/docs

missing=0
for entry in "${SECTIONS[@]}"; do
  section="${entry%%:*}"
  src="${TOKE_REPO}/docs/${entry##*:}"
  if [[ ! -d "${src}" ]]; then
    echo "    ERROR: ${src} does not exist (section /docs/${section}/)" >&2
    missing=$((missing + 1))
    continue
  fi
  if [[ "${MODE}" == "link" ]]; then
    ln -s "${src}" "content/docs/${section}"
  else
    cp -R "${src}" "content/docs/${section}"
  fi
done

if (( missing > 0 )); then
  echo "ERROR: ${missing} section source(s) missing — content/docs is incomplete" >&2
  exit 1
fi

echo "    content/docs/ ready ($(find -L content/docs -name '*.md' | wc -l | tr -d ' ') markdown files across ${#SECTIONS[@]} sections)"
