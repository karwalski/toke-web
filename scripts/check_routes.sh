#!/usr/bin/env bash
# check_routes.sh — start the site and assert every route it defines returns 200.
#
# Routes come from main.tk: http.servepages("templates";"templates") registers
# one named route per templates/**.tkt, and main.tk registers /health,
# /api/health, /api/version and /llms.txt explicitly. build/ supplies the three
# standalone pages the nav links to.
#
# Usage:  scripts/check_routes.sh [port]
# Exit:   0 if every route answered 200.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

PORT="${1:-8099}"

if [[ ! -x ./website ]]; then
  echo "ERROR: ./website not built — run: make" >&2
  exit 1
fi

# Layout templates. They live in templates/ so the template engine can find
# them by name, and servepages therefore registers a route for each, but none
# of them is a page.
is_layout() {
  case "$1" in
    templates/base.tkt|templates/docs.tkt|templates/doc-page.tkt) return 0 ;;
    *) return 1 ;;
  esac
}

routes=()
while IFS= read -r tpl; do
  is_layout "$tpl" && continue
  case "$tpl" in *'['*) continue ;; esac   # no param routes today (see 132.17)
  r="${tpl#templates}"
  r="${r%.tkt}"
  r="${r%/index}"
  [[ -z "$r" ]] && r="/"
  routes+=("$r")
done < <(find templates -name '*.tkt' | sort)

routes+=(/health /api/health /api/version /llms.txt)
routes+=(/library.html /tokenizer.html /tokens.html /library/index.json /static/css/style.css)
routes+=(/robots.txt /sitemap.xml /favicon.ico /favicon.svg)

./website --http --port "${PORT}" > /tmp/toke-website-routecheck.log 2>&1 &
SERVER_PID=$!
trap 'kill "${SERVER_PID}" 2>/dev/null || true' EXIT
sleep 2

fail=0
seen=""
for r in "${routes[@]}"; do
  case " ${seen} " in *" ${r} "*) continue ;; esac
  seen="${seen} ${r}"
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:${PORT}${r}")
  printf '  %-34s %s\n' "${r}" "${code}"
  [[ "${code}" == "200" ]] || fail=1
done

echo ""
if [[ ${fail} -ne 0 ]]; then
  echo "check-routes FAILED"
  exit 1
fi
echo "check-routes passed (${#routes[@]} routes)"
