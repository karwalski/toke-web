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
#     ./scripts/sync_docs_content.sh --report          # drift is a WARNING, exit 0
#
#   --report was added for story 132.51a, while content/docs/ sat ~30 files
#   adrift pending review and the GitHub workflow ran it so the drift was
#   visible without a red job (134.32). 132.51a synced and reviewed that
#   backlog and switched the workflow to --check; --report stays as a local
#   listing and no gate runs it. Only DRIFT is downgraded — a missing section
#   or missing source still exits 1.
#
# Without the toke repository available, both modes fall back to verifying the
# tracked copy is present and complete, and PASS — so `make ci` and `make build`
# work in a bare clone (this is also what keeps 127.88 from getting worse).
#
# The mapping below IS the site's information architecture: a /docs/<section>/
# URL prefix on the left, the directory in the toke repo that fills it on the
# right. Change it here and nowhere else.
#
# Usage:   ./scripts/sync_docs_content.sh [--check | --report]
#          TOKE_REPO=/path/to/toke ./scripts/sync_docs_content.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${REPO_ROOT}"

TOKE_REPO="${TOKE_REPO:-${HOME}/tk/toke}"
MODE="sync"
[[ "${1:-}" == "--check" ]] && MODE="check"
[[ "${1:-}" == "--report" ]] && MODE="report"

# <url section>:<dir under ${TOKE_REPO}/docs>[:<file>,<file>...]
#
# With no file list every *.md under the directory is published. A file list
# publishes exactly those files and nothing else from the directory (132.136):
# docs/architecture/ and docs/security/ hold public reference pages next to
# internal planning and audit records, so for them publication is opt-in, file
# by file. A listed file that does not exist fails the sync.
#
#   architecture  binary-ir-design.md (the .tkir format, --emit-tkir,
#                 --from-tkir, --read-tkir). The rest of the directory (model,
#                 corpus, tokenizer and training plans, ADR drafts) was not
#                 reviewed for publication and is not listed.
#   security      the post-quantum triage and roadmap and the threat model,
#                 each read in full before listing (no host, address,
#                 credential or key path). Not published: the dated internal
#                 audit and review records (fixture-secret-review-2026-09,
#                 which names key files; audit-120/; path-traversal-audit;
#                 static-analysis-audit; library-inventory;
#                 dependency-tracking), the harness sandbox-setup notes and the
#                 draft soc2-readiness assessment.
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
  "architecture:architecture:binary-ir-design.md"
  "security:security:pqc-hndl-triage.md,pqc-signatures-roadmap.md,threat-model.md"
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
  rest="${entry#*:}"
  dir="${rest%%:*}"
  files=""
  [[ "${rest}" == *:* ]] && files="${rest#*:}"
  src="${TOKE_REPO}/docs/${dir}"
  if [[ ! -d "${src}" ]]; then
    echo "    ERROR: ${src} does not exist (section /docs/${section}/)" >&2
    missing=$((missing + 1))
    continue
  fi
  mkdir -p "${staging}/${section}"
  if [[ -n "${files}" ]]; then
    IFS=',' read -r -a listed <<< "${files}"
    for f in "${listed[@]}"; do
      if [[ ! -f "${src}/${f}" ]]; then
        echo "    ERROR: ${src}/${f} does not exist (listed for /docs/${section}/)" >&2
        missing=$((missing + 1))
        continue
      fi
      cp "${src}/${f}" "${staging}/${section}/${f}"
    done
    continue
  fi
  (cd "${src}" && find . -name '*.md' -type f -print0) \
    | (cd "${src}" && xargs -0 -I{} sh -c 'mkdir -p "$1/$(dirname "$2")" && cp "$2" "$1/$2"' _ "${staging}/${section}" {})
done

if (( missing > 0 )); then
  echo "ERROR: ${missing} section source(s) missing under ${TOKE_REPO}/docs" >&2
  echo "       content/docs would be incomplete; refusing to write it." >&2
  exit 1
fi

if [[ "${MODE}" == "check" || "${MODE}" == "report" ]]; then
  if diff -rq "${staging}" content/docs >/dev/null 2>&1; then
    echo "==> content/docs/ matches ${TOKE_REPO}/docs ($(find content/docs -name '*.md' | wc -l | tr -d ' ') files)"
    exit 0
  fi
  if [[ "${MODE}" == "report" ]]; then
    ndrift="$({ diff -rq "${staging}" content/docs 2>&1 || true; } | wc -l | tr -d ' ')"
    echo "WARNING (report mode): content/docs/ has drifted from ${TOKE_REPO}/docs — ${ndrift} path(s):" >&2
    { diff -rq "${staging}" content/docs 2>&1 || true; } | sed "s#${staging}#<toke docs>#; s#^#       #" >&2
    [[ -n "${GITHUB_ACTIONS:-}" ]] && \
      echo "::warning title=content/docs drift::content/docs/ is ${ndrift} path(s) adrift from the toke docs. Run make check-docs-content for the strict gate."
    echo "       Not failing: report mode lists drift; make check-docs-content fails on it." >&2
    exit 0
  fi
  echo "ERROR: content/docs/ has drifted from ${TOKE_REPO}/docs." >&2
  { diff -rq "${staging}" content/docs 2>&1 || true; } | sed "s#${staging}#<toke docs>#; s#^#       #" >&2
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
