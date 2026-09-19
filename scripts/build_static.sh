#!/usr/bin/env bash
# build_static.sh — regenerate build/, the static tree served at / (story 132.17b).
#
# Why this exists
# ---------------
# build/ is gitignored but the deploy rsyncs it. Before this script there was no
# way to regenerate it, so a deploy from a clean checkout would have published
# whatever happened to be on the deploying machine — in practice a four-month-old
# mirror of pages that are now rendered from templates/. Those mirrors are gone:
# build/ is now derived entirely from committed sources, and `make build` remakes
# it from scratch every time.
#
# What is in build/, and why
# --------------------------
#   static/            every asset, served at /static/...
#   library/           the program-library JSON the library page fetches at /library/...
#   library.html       the three standalone pages, served at their own top-level
#   tokenizer.html     URLs (the site nav links to /library.html)
#   tokens.html
#   tokenizer_v03.json the vocabulary the tokenizer page fetches at /tokenizer_v03.json
#   docs/             the ~190 per-slug documentation pages, rendered from
#                     content/docs/ by `ooke build` (story 134.8)
#
# Everything else the site serves is a route: templates/*.tkt are registered as
# named routes by http.servepages in main.tk and take priority over this tree, so
# a page must never be mirrored here as well.
#
# The /docs/<section>/<slug> pages are the exception that proves the rule: they
# have no route, because http.servepages matches exact paths and cannot serve a
# section tree. Before story 134.8 they were served from a May-era mirror that no
# tool in the tree could regenerate, so they still carried claims Epic 132 had
# withdrawn. They are now rendered here from content/docs/ on every build. The
# section INDEX pages (/docs, /docs/learn, ...) are routes and are excluded.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

if [[ ! -d static ]]; then
  echo "ERROR: static/ not found — run this from a checkout of toke-website" >&2
  exit 1
fi

echo "==> Rebuilding build/ from static/"
rm -rf build
mkdir -p build

cp -R static build/static

# The library page fetches /library/<category>.json, not /static/library/...
cp -R static/library build/library

for f in library.html tokenizer.html tokens.html tokenizer_v03.json; do
  if [[ -f "static/${f}" ]]; then
    cp "static/${f}" "build/${f}"
  else
    echo "    WARNING: static/${f} is missing — /${f} will 404" >&2
  fi
done

# Site-root files that live in the vhost directory but have to be served for
# every host. They were 404ing: main.tk registers http.servedir("/";"build")
# before the vhost catch-all, and a wildcard route that matches wins, so
# nothing under sites/ was ever reachable. Copying them here is what actually
# publishes /robots.txt, /sitemap.xml and the favicons.
for f in robots.txt sitemap.xml favicon.ico favicon.svg; do
  if [[ -f "sites/tokelang.dev/${f}" ]]; then
    cp "sites/tokelang.dev/${f}" "build/${f}"
  else
    echo "    WARNING: sites/tokelang.dev/${f} is missing — /${f} will 404" >&2
  fi
done

# ── Per-slug documentation pages (story 134.8) ───────────────────────────
#
# `ooke build` reads pages/, templates/ and content/docs/ and renders every
# /docs/<section>/<slug> page. content/docs/ is not authored here — run
# scripts/sync_docs_content.sh first to materialise it from the toke repo.
OOKE="${OOKE:-${HOME}/tk/toke-ooke/ooke-toke}"

if [[ ! -d content/docs ]] || [[ -z "$(find -L content/docs -name '*.md' -print -quit 2>/dev/null)" ]]; then
  echo "ERROR: content/docs/ is empty — run ./scripts/sync_docs_content.sh first." >&2
  echo "       Without it the ~190 /docs/<section>/<slug> pages cannot be built." >&2
  exit 1
fi

if [[ ! -x "${OOKE}" ]]; then
  echo "ERROR: ooke not found at '${OOKE}'. Set OOKE=/path/to/ooke-toke." >&2
  echo "       Build it with: make -C \$(dirname ${OOKE})" >&2
  exit 1
fi

echo "==> Rendering /docs pages with ooke build"
rm -rf build-docs
if ! "${OOKE}" build; then
  echo "ERROR: ooke build failed — /docs pages would be missing or stale." >&2
  exit 1
fi

if [[ ! -d build-docs/docs ]]; then
  echo "ERROR: ooke build produced no build-docs/docs tree." >&2
  exit 1
fi

# A page that templates/*.tkt already serves as a named route must not also be
# mirrored under build/. Those are exactly the non-bracketed pages/docs/*.tk
# files; derive the exclusion list from the source of truth rather than a
# hand-kept list, so adding a route cannot silently create a stale mirror.
excludes=()
while IFS= read -r src; do
  rel="${src#pages/docs/}"; rel="${rel%.tk}"
  [[ "$(basename "${rel}")" == "index" ]] && rel="$(dirname "${rel}")"
  if [[ "${rel}" == "." ]]; then
    excludes+=("--exclude=/index.html")
  else
    excludes+=("--exclude=/${rel}/index.html")
  fi
done < <(find pages/docs -name '*.tk' ! -name '*[[]*' | sort)

mkdir -p build/docs
rsync -a --delete "${excludes[@]}" build-docs/docs/ build/docs/

docs_pages=$(find build/docs -name '*.html' | wc -l | tr -d ' ')
if (( docs_pages == 0 )); then
  echo "ERROR: no /docs pages were copied into build/." >&2
  exit 1
fi
echo "    ${docs_pages} /docs pages rendered from content/docs/"

echo "    build/ rebuilt ($(find build -type f | wc -l | tr -d ' ') files)"
