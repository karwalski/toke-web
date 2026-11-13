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
#
# 132.113 — the server checked must be the one this script started. It used to
# serve on a fixed port 8099 and `sleep 2`: when anything else (another
# worktree's site) already listened there, ./website failed to bind, curl
# tested the other server, and the gate went green without testing this build.
# Now:
#   - with no [port], a free port is picked; a [port] that is already in use is
#     refused with an error rather than shared;
#   - readiness is polled (bounded by CHECK_ROUTES_TIMEOUT seconds, default 30)
#     instead of slept, and a server that exits early fails the check;
#   - before any route is tested, every process listening on the port must be
#     the started server or one of its forked workers (lsof, or ss on Linux).

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

PORT="${1:-}"
TIMEOUT="${CHECK_ROUTES_TIMEOUT:-30}"

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
  # 132.144 — and its trailing-slash form, which build_static.sh answers with
  # a redirect stub (200). /docs/learn/, /docs/reference/ and /docs/tutorials/
  # 404ed while their routes answered, because the stub list was derived from
  # templates/<x>.tkt only; nothing here looked at the slash form.
  [[ "$r" != "/" ]] && routes+=("$r/")
done < <(find templates -name '*.tkt' | sort)

routes+=(/health /api/health /api/version /llms.txt)
routes+=(/library.html /tokenizer.html /tokens.html /library/index.json /static/css/style.css)
routes+=(/robots.txt /sitemap.xml /favicon.ico /favicon.svg)

# PIDs listening on TCP port $1, one per line (empty if none).
listeners() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$1" -sTCP:LISTEN -t 2>/dev/null | sort -u
  elif command -v ss >/dev/null 2>&1; then
    ss -Hltnp "sport = :$1" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2 | sort -u
  else
    echo "ERROR: neither lsof nor ss is available to verify who owns port $1" >&2
    return 2
  fi
}

# Is anything answering, or listening, on port $1?
port_in_use() {
  [[ -n "$(listeners "$1")" ]] && return 0
  local c
  c=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://127.0.0.1:$1/" 2>/dev/null)
  [[ -n "$c" && "$c" != "000" ]]
}

if [[ -z "${PORT}" ]]; then
  PORT=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])') || {
    echo "ERROR: could not pick a free port" >&2; exit 1; }
fi
if ! [[ "${PORT}" =~ ^[0-9]+$ ]]; then
  echo "ERROR: port must be a number, got '${PORT}'" >&2; exit 1
fi
if port_in_use "${PORT}"; then
  echo "ERROR: port ${PORT} is already in use (pids: $(listeners "${PORT}" | tr '\n' ' '))." >&2
  echo "       check-routes would be testing that server, not this build." >&2
  echo "       Stop it, or run without a port argument to use a free one." >&2
  exit 1
fi

LOG=$(mktemp "${TMPDIR:-/tmp}/toke-website-routecheck.XXXXXX")
./website --http --port "${PORT}" > "${LOG}" 2>&1 &
SERVER_PID=$!
stop_server() {
  local kids
  kids=$(pgrep -P "${SERVER_PID}" 2>/dev/null || true)
  kill "${SERVER_PID}" ${kids} 2>/dev/null || true
}
trap 'stop_server; rm -f "${LOG}"' EXIT

# Every listener on the port is SERVER_PID or a worker it forked.
ours_only() {
  local pids p
  pids=$(listeners "${PORT}") || return 2
  [[ -n "${pids}" ]] || return 1
  for p in ${pids}; do
    [[ "${p}" == "${SERVER_PID}" ]] && continue
    [[ "$(ps -o ppid= -p "${p}" 2>/dev/null | tr -d ' ')" == "${SERVER_PID}" ]] && continue
    echo "${p}"; return 1
  done
  return 0
}

echo "check-routes: ./website pid ${SERVER_PID} on port ${PORT}"
deadline=$(( $(date +%s) + TIMEOUT ))
ready=0
while (( $(date +%s) < deadline )); do
  if ! kill -0 "${SERVER_PID}" 2>/dev/null; then
    echo "ERROR: ./website exited before it was ready; its log:" >&2
    sed 's/^/    /' "${LOG}" >&2
    exit 1
  fi
  code=$(curl -s -o /dev/null -m 2 -w '%{http_code}' "http://127.0.0.1:${PORT}/health" 2>/dev/null)
  if [[ "${code}" == "200" ]]; then ready=1; break; fi
  sleep 0.2
done
if (( ! ready )); then
  echo "ERROR: ./website (pid ${SERVER_PID}) did not answer /health within ${TIMEOUT}s; its log:" >&2
  sed 's/^/    /' "${LOG}" >&2
  exit 1
fi
if ! other=$(ours_only); then
  echo "ERROR: port ${PORT} is not served only by ./website pid ${SERVER_PID}" >&2
  echo "       (listener${other:+ pid ${other}} is another process) -- refusing to test it." >&2
  exit 1
fi

fail=0
seen=""
for r in "${routes[@]}"; do
  case " ${seen} " in *" ${r} "*) continue ;; esac
  seen="${seen} ${r}"
  code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${PORT}${r}")
  printf '  %-34s %s\n' "${r}" "${code}"
  [[ "${code}" == "200" ]] || fail=1
done

echo ""
if [[ ${fail} -ne 0 ]]; then
  echo "check-routes FAILED"
  exit 1
fi
echo "check-routes passed (${#routes[@]} routes)"
