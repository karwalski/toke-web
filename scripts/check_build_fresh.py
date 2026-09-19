#!/usr/bin/env python3
"""
check_build_fresh.py — fail if build/ is older than the sources it comes from.

Story 132.17b. `build/` is gitignored but `scripts/deploy.sh` rsyncs it, so a
deploy from a clean checkout — or from a checkout where someone edited a
template and forgot to rebuild — would publish a stale tree. The deploy runs
this gate after rebuilding; it also runs as part of `make ci`.

The rule: the newest file under build/ must be at least as new as the newest
file under any source directory that build/ is derived from, and build/ must
contain the files the site's own navigation links to.

Usage:  python3 scripts/check_build_fresh.py
Exit:   0 fresh, 1 stale or incomplete.
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"

# Directories whose contents build/ is derived from, or whose edits must at
# least prompt a rebuild before a deploy.
#
# 134.8: `pages` joins the list because ooke derives one route per pages/*.tk,
# and `content` now feeds the ~195 /docs pages. Note that content/docs/* are
# symlinks into the toke repo and rglob does not descend symlinked directories,
# so editing a doc there does not by itself trip this gate — scripts/deploy.sh
# always rebuilds before syncing, which is what actually guarantees freshness.
SOURCES = ["static", "templates", "content", "sites", "pages"]

# Files the site links to directly, served out of build/.
REQUIRED = [
    "library.html",
    "tokenizer.html",
    "tokens.html",
    "tokenizer_v03.json",
    "static/css/style.css",
    "library/index.json",
    "robots.txt",
    "sitemap.xml",
    "favicon.ico",
    # One per-slug documentation page, so an ooke build that produced no /docs
    # tree cannot pass this gate (story 134.8).
    "docs/about/why/index.html",
]

SKIP_NAMES = {".DS_Store"}


def newest(path):
    """(mtime, file) of the newest regular file under path, or (None, None)."""
    best_t, best_f = None, None
    if not path.exists():
        return best_t, best_f
    for f in path.rglob("*"):
        if not f.is_file() or f.name in SKIP_NAMES:
            continue
        t = f.stat().st_mtime
        if best_t is None or t > best_t:
            best_t, best_f = t, f
    return best_t, best_f


def main():
    if not BUILD.is_dir():
        print("STALE: build/ does not exist — run: make build", file=sys.stderr)
        return 1

    missing = [r for r in REQUIRED if not (BUILD / r).exists()]
    if missing:
        print("INCOMPLETE: build/ is missing files the site links to:", file=sys.stderr)
        for m in missing:
            print("  build/%s" % m, file=sys.stderr)
        print("run: make build", file=sys.stderr)
        return 1

    build_t, build_f = newest(BUILD)
    if build_t is None:
        print("STALE: build/ is empty — run: make build", file=sys.stderr)
        return 1

    stale = []
    for name in SOURCES:
        src_t, src_f = newest(ROOT / name)
        if src_t is not None and src_t > build_t:
            stale.append((name, src_f))

    if stale:
        print("STALE: build/ is older than its sources.", file=sys.stderr)
        print("       newest in build/: %s" % build_f.relative_to(ROOT), file=sys.stderr)
        for name, f in stale:
            print("       newer in %s/: %s" % (name, f.relative_to(ROOT)), file=sys.stderr)
        print("       run: make build", file=sys.stderr)
        return 1

    print("build/ is current (newest: %s)" % build_f.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main())
