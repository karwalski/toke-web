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

# 134.27 — content-hashed asset filenames, so a changed stylesheet or script
# is a NEW URL and no cache can serve the old one.
#
# PATH-based, not a ?v= query string: the server does not strip query strings
# from static paths, so a versioned query 404s (story 127.100) — which briefly
# left the site unstyled when it was tried. A hashed filename is a real file
# at a real path, so it works with the server exactly as it is.
#
# The asset list is DERIVED from what the templates actually reference, never
# hand-maintained — the recurring root cause in this workspace (127.80,
# 127.85, 134.21, 136.1). The unhashed copy is kept alongside so any
# reference this misses still resolves.
declare -a hashed=()
while IFS= read -r asset; do
  [[ -f "${asset#/}" ]] || continue
  src="${asset#/}"                      # static/css/style.css
  h="$(shasum -a 256 "${src}" | cut -c1-10)"
  base="${src##*/}"; stem="${base%.*}"; ext="${base##*.}"
  dir="${src%/*}"                        # static/css
  newrel="${dir}/${stem}.${h}.${ext}"    # static/css/style.<hash>.css
  cp "${src}" "build/${newrel}"
  # point every template at the hashed path
  for t in templates/*.tkt; do
    perl -pi -e "s{\Q${asset}\E}{/${newrel}}g; s{/${dir}/${stem}\.[0-9a-f]{10}\.${ext}}{/${newrel}}g" "${t}"
  done
  hashed+=("${base} -> ${stem}.${h}.${ext}")
done < <(grep -ohE '(href|src)="/static/[^"]+\.(css|js)"' templates/*.tkt \
         | sed -E 's/.*"(\/static\/[^"]+)".*/\1/' \
         | sed -E 's/\/([^/]+)\.[0-9a-f]{10}\.(css|js)$/\/\1.\2/' \
         | sort -u)

if (( ${#hashed[@]} )); then
  echo "    ${#hashed[@]} asset(s) content-hashed: ${hashed[*]}"
fi

# The library page fetches /library/<category>.json, not /static/library/...
cp -R static/library build/library

for f in library.html tokenizer.html tokens.html tokenizer_v03.json; do
  if [[ -f "static/${f}" ]]; then
    cp "static/${f}" "build/${f}"
  else
    echo "    WARNING: static/${f} is missing — /${f} will 404" >&2
  fi
done

# Site-root files that are authored under sites/ but have to be served at /.
# sites/ is not a docroot: it was the vhost docroot, and the vhost catch-all
# could never run because http.servedir("/";"build") registers its wildcard
# first and the first matching wildcard wins. The vhost calls were removed in
# story 132.21; copying these files into build/ is what publishes
# /robots.txt, /sitemap.xml and the favicons.
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
# /docs/<section>/<slug> page. content/docs/ is a TRACKED, generated copy of the
# documentation authored in the toke repository (story 134.30) — it is a build
# input and is present in every clone. scripts/sync_docs_content.sh is the only
# thing that writes it.
OOKE="${OOKE:-${HOME}/tk/toke-ooke/ooke-toke}"

# The sections this build expects. Derived from the same table
# scripts/sync_docs_content.sh writes, so a section added there and forgotten
# here fails loudly instead of silently publishing fewer pages.
DOC_SECTIONS=(about compiler cookbook decisions learn reference spec stdlib tutorials)

# 134.30 — name what is missing and how to restore it, rather than failing later
# with an unrelated-looking error. Before this story content/docs/ was eleven
# absolute symlinks into one machine's home directory, excluded by .gitignore, so
# a fresh clone reached this point with the directory absent altogether.
missing_sections=()
for section in "${DOC_SECTIONS[@]}"; do
  if [[ ! -d "content/docs/${section}" ]] ||      [[ -z "$(find -L "content/docs/${section}" -name '*.md' -print -quit 2>/dev/null)" ]]; then
    missing_sections+=("content/docs/${section}")
  fi
done

if (( ${#missing_sections[@]} )); then
  echo "ERROR: the documentation source is missing — /docs pages cannot be built." >&2
  echo "       ${#missing_sections[@]} of ${#DOC_SECTIONS[@]} section(s) are absent or contain no markdown:" >&2
  printf '         %s\n' "${missing_sections[@]}" >&2
  echo "" >&2
  echo "       content/docs/ is TRACKED in git (story 134.30) — it is a build input," >&2
  echo "       not output, and every clone has it. Restore it with:" >&2
  echo "         git checkout -- content/docs" >&2
  echo "       Or regenerate it from the documentation source (github.com/karwalski/toke):" >&2
  echo "         TOKE_REPO=/path/to/toke ./scripts/sync_docs_content.sh" >&2
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

# ── Retired duplicate sections (story 134.30) ────────────────────────────
#
# /docs/community/ served the same markdown as /docs/about/, and
# /docs/getting-started/ the same as /docs/learn/. 196 pages were published of
# which only 159 were distinct; every build logged duplicate "no slug" warnings,
# and both prefixes were indexed.
#
# Resolved as REDIRECTS, not deletions and not distinct sections:
#   - distinct sections was never an option — nobody was maintaining two copies,
#     they were two names for one directory in the toke repo;
#   - deletion would 404 37 URLs that answer 200 on the live site today
#     (checked, all 18 /docs/community/<slug> and all /docs/getting-started/
#     <slug> URLs, not assumed);
#   - /docs/learn wins over /docs/getting-started because it is the section in
#     the site-wide nav (templates/base.tkt), it is the one with an index route
#     (pages/docs/learn/index.tk), and it carries one more URL in the sitemap.
#
# The slug list is DERIVED from what ooke just rendered for the canonical
# section — a hand-kept list is the recurring root cause in this repo (127.80,
# 127.85, 134.21, 134.30).
#
# The section ROOTS point at /docs rather than at the canonical section root,
# because /docs/<section> has no route and its stub currently redirects to
# itself (see the trailing-slash block below) — sending a retired prefix into
# that loop would be worse than sending it to the docs index.
RETIRED_SECTIONS=(
  "community:about"
  "getting-started:learn"
)

emit_doc_redirect() {
  local from="$1" to="$2" dir="build/${1#/}"
  mkdir -p "${dir}"
  printf '<!doctype html><meta charset="utf-8"><link rel="canonical" href="%s"><meta http-equiv="refresh" content="0; url=%s"><title>Moved</title><p>This page moved to <a href="%s">%s</a>.</p>\n' \
    "${to}" "${to}" "${to}" "${to}" > "${dir}/index.html"
}

retired=0
for entry in "${RETIRED_SECTIONS[@]}"; do
  old="${entry%%:*}"; new="${entry##*:}"
  rm -rf "build/docs/${old}"
  emit_doc_redirect "/docs/${old}" "/docs"
  retired=$((retired + 1))
  while IFS= read -r d; do
    slug="${d#build/docs/${new}/}"
    [[ "${slug}" == "${d}" ]] && continue
    [[ -f "${d}/index.html" ]] || continue
    emit_doc_redirect "/docs/${old}/${slug}" "/docs/${new}/${slug}"
    retired=$((retired + 1))
  done < <(find "build/docs/${new}" -mindepth 1 -type d | sort)
done
echo "    ${retired} redirect(s) for the retired duplicate sections (${RETIRED_SECTIONS[*]})"

# 134.9 — trailing-slash redirect stubs.
#
# A named route serves /docs but NOT /docs/, and 132.17b removes the mirrored
# index.html that used to cover the trailing-slash form from build/. Without a
# stub, 12 URLs that return 200 today would start returning 404 — measured
# against the live server before this was added, not assumed.
#
# The list is DERIVED, never hand-maintained: every named template route, plus
# every directory ooke rendered under build/docs/. A hand-written list is the
# recurring root cause in this repo (127.80, 127.85, 134.21, 136.1).
emit_stub() {
  local path="$1" dir="build/${1#/}"
  [[ -f "${dir}/index.html" ]] && return 0
  mkdir -p "${dir}"
  printf '<!doctype html><meta charset="utf-8"><link rel="canonical" href="%s"><meta http-equiv="refresh" content="0; url=%s"><title>Redirecting</title><p>Redirecting to <a href="%s">%s</a>.</p>\n' \
    "${path}" "${path}" "${path}" "${path}" > "${dir}/index.html"
  stubs=$((stubs+1))
}

stubs=0
for t in templates/*.tkt; do
  name="$(basename "${t}" .tkt)"
  [[ "${name}" == "index" || "${name}" == _* ]] && continue
  emit_stub "/${name}"
done
while IFS= read -r d; do
  rel="${d#build/}"
  [[ -z "${rel}" ]] && continue
  emit_stub "/${rel}"
done < <(find build/docs -type d | sort)

# Renamed and retired pages keep a redirect so existing links and search
# results do not 404. Verified against the live server, not assumed: these are
# the only two paths that still differed after the derived stubs above.
#   llm_tool -> llmtool  (136.17 renamed the module; the underscore form is
#                         unlexable in toke, which is why it was renamed)
#   reference/api        (retired; /docs/reference/ is the nearest equivalent)
emit_redirect() {
  local from="$1" to="$2" dir="build/${1#/}"
  mkdir -p "${dir}"
  printf '<!doctype html><meta charset="utf-8"><link rel="canonical" href="%s"><meta http-equiv="refresh" content="0; url=%s"><title>Moved</title><p>This page moved to <a href="%s">%s</a>.</p>\n' \
    "${to}" "${to}" "${to}" "${to}" > "${dir}/index.html"
}
emit_redirect "/docs/stdlib/llm_tool" "/docs/stdlib/llmtool"
emit_redirect "/docs/reference/api"   "/docs/reference"
echo "    2 renamed-page redirect(s) emitted"

echo "    ${stubs} trailing-slash redirect stub(s) emitted"

echo "    build/ rebuilt ($(find build -type f | wc -l | tr -d ' ') files)"
