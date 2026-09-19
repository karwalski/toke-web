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
#
# Everything else the site serves is a route: templates/*.tkt are registered as
# named routes by http.servepages in main.tk and take priority over this tree, so
# a page must never be mirrored here as well.

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

echo "    build/ rebuilt ($(find build -type f | wc -l | tr -d ' ') files)"
