#!/usr/bin/env python3
"""check_doc_links.py — every link inside a rendered /docs page must resolve (132.89).

Why this exists
---------------
The docs are authored in the toke repository and rendered here, so a link that
is correct in the toke tree can point at nothing on the site. Two shipped:

- `reference/tki-quarantine.md` linked `../../scripts/check_tki_skiplist.txt`,
  a file in the toke repository that the site does not serve;
- `stdlib/index.md` linked every module as `/docs/reference/stdlib/<mod>/`,
  while the build serves stdlib pages at `/docs/stdlib/<mod>/` — 54 dead links
  on the page that is meant to be the way into the standard library.

Nothing noticed, because the site build had no link check at all: it verified
that pages RENDERED, never that what they link to EXISTS.

What it checks
--------------
Every `href`/`src` in `build/docs/**/*.html` that points inside the site — an
absolute path (`/docs/...`) or a relative one (`../x`) — must name something
the server answers:

- a file under `build/`, or a directory there with an `index.html`;
- a named route: one per `templates/**.tkt` (not a layout, not a `[param]`
  template), exactly as `scripts/check_routes.sh` derives them from `main.tk`'s
  `http.servepages`;
- one of the routes `main.tk` registers by hand (`/llms.txt`, `/health`, ...).

External links (`https:`, `mailto:`), fragments and the query string are not
checked; neither are the redirect stubs the build writes (they are one link
each, to a target this script has already checked is served).

Known dead links
----------------
The first full run found 227 dead links. 174 were one site-owned link (the
docs layout's "Language Spec" pointed at /docs/spec/toke-spec-v02, which no
build has produced) and are fixed here. The rest are links in pages authored
in the toke repository, fixed THERE and re-synced, not here. Until then each
one is listed, with a date and a story, in scripts/check_doc_links_known.txt.
The list only shrinks: a dead link NOT on it fails, and an entry that has
started to resolve also fails ("stale"), so it cannot outlive its fix.

Usage:  python3 scripts/check_doc_links.py [--build DIR] [--selftest]
Exit:   0 when every in-site link resolves or is a listed known dead link,
        1 on a new dead link or a stale list entry, 2 when build/ is absent.
"""
import html
import os
import re
import sys
import tempfile
from urllib.parse import unquote, urljoin, urlsplit

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# main.tk registers these by hand (http.getstatic / getstaticmime).
FIXED_ROUTES = {"/", "/llms.txt", "/health", "/api/health", "/api/version"}
# templates/ holds the layouts too; servepages registers them, but they are not pages.
LAYOUTS = {"base", "docs", "doc-page"}

LINK = re.compile(r"""\b(?:href|src)\s*=\s*(["'])(.*?)\1""", re.I | re.S)
REDIRECT_STUB = re.compile(r'<meta http-equiv="refresh"', re.I)
KNOWN = os.path.join(REPO, "scripts", "check_doc_links_known.txt")
KNOWN_LINE = re.compile(r"^(?P<page>\S+)\t(?P<link>\S+)\t(?P<date>\d{4}-\d{2}-\d{2})\t(?P<story>\S+)$")


def load_known(path):
    """{(page, link): line_no} from the known-dead list; malformed lines raise."""
    known = {}
    if not os.path.exists(path):
        return known
    for n, line in enumerate(open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip() or line.startswith("#"):
            continue
        m = KNOWN_LINE.match(line)
        if not m:
            raise ValueError("%s:%d: want page<TAB>link<TAB>YYYY-MM-DD<TAB>story, got %r"
                             % (path, n, line))
        known[(m.group("page"), m.group("link"))] = n
    return known


def triage(broken, known):
    """(new dead links, stale known entries). One entry covers every repeat of
    that link on that page."""
    seen = {(page, raw) for page, raw, _t in broken}
    new = [b for b in broken if (b[0], b[1]) not in known]
    stale = sorted(k for k in known if k not in seen)
    return new, stale


def template_routes(templates):
    routes = set()
    for dirpath, _dirs, files in os.walk(templates):
        for f in files:
            if not f.endswith(".tkt") or "[" in f or "[" in dirpath:
                continue
            rel = os.path.relpath(os.path.join(dirpath, f), templates)[:-4]
            if rel in LAYOUTS:
                continue
            if rel == "index":
                routes.add("/")
                continue
            if rel.endswith("/index"):
                rel = rel[:-len("/index")]
            routes.add("/" + rel)
    return routes


def served(path, build, routes):
    """True when the server answers `path` (a URL path, no query or fragment)."""
    norm = "/" + path.strip("/")
    if norm in routes:
        return True
    local = os.path.normpath(os.path.join(build, unquote(path).lstrip("/")))
    if not local.startswith(os.path.normpath(build)):
        return False            # climbed out of the site root: nothing serves it
    if os.path.isfile(local):
        return True
    return os.path.isfile(os.path.join(local, "index.html"))


def page_url(build, file):
    rel = os.path.relpath(file, build).replace(os.sep, "/")
    if rel.endswith("/index.html"):
        return "/" + rel[:-len("index.html")]
    return "/" + rel


def check(build, templates):
    routes = template_routes(templates) | FIXED_ROUTES
    broken, links, pages = [], 0, 0
    root = os.path.join(build, "docs")
    for dirpath, _dirs, files in os.walk(root):
        for f in sorted(files):
            if not f.endswith(".html"):
                continue
            file = os.path.join(dirpath, f)
            text = open(file, encoding="utf-8", errors="replace").read()
            if REDIRECT_STUB.search(text):
                continue
            pages += 1
            base = page_url(build, file)
            for m in LINK.finditer(text):
                raw = html.unescape(m.group(2).strip())
                if not raw or raw.startswith(("#", "mailto:", "tel:", "data:",
                                              "javascript:")):
                    continue
                parts = urlsplit(raw)
                if parts.scheme or parts.netloc:
                    continue      # external, or protocol-relative
                links += 1
                target = urlsplit(urljoin(base, raw)).path
                if not served(target, build, routes):
                    broken.append((os.path.relpath(file, build), raw, target))
    return broken, links, pages


def selftest():
    """The negative control: a page with one dead link of each shape must fail."""
    bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        build = os.path.join(tmp, "build")
        templates = os.path.join(tmp, "templates")
        os.makedirs(os.path.join(build, "docs", "stdlib", "str"))
        os.makedirs(os.path.join(build, "docs", "reference", "tki-quarantine"))
        os.makedirs(templates)
        open(os.path.join(templates, "roadmap.tkt"), "w").close()
        open(os.path.join(templates, "base.tkt"), "w").close()
        open(os.path.join(build, "docs", "stdlib", "str", "index.html"), "w").write("<p>str</p>")
        page = os.path.join(build, "docs", "reference", "tki-quarantine", "index.html")
        cases = [
            # (link, should resolve?)
            ("/docs/stdlib/str/", True),
            ("/docs/stdlib/str", True),
            ("../../stdlib/str/#fn", True),
            ("/roadmap", True),
            ("/llms.txt", True),
            ("https://github.com/karwalski/toke", True),
            ("#top", True),
            ("/docs/reference/stdlib/str/", False),   # the stdlib/index.md shape
            ("../../scripts/check_tki_skiplist.txt", False),  # the quarantine shape
            ("../../../../../etc/passwd", False),     # climbs out of the site
            ("/base", False),                         # a layout is not a page
        ]
        for link, ok in cases:
            open(page, "w").write('<a href="%s">x</a>' % link)
            broken, _, _ = check(build, templates)
            if bool(broken) == ok:
                bad += 1
                print("SELFTEST FAIL: %r should %s" % (link, "resolve" if ok else "be reported"))
        # the known-dead list: a listed link passes, an unlisted one does not,
        # and a listed link that now resolves is reported as stale
        open(page, "w").write('<a href="/docs/nowhere/">x</a>')
        broken, _, _ = check(build, templates)
        pg = os.path.relpath(page, build)
        for known, want_new, want_stale, what in [
                ({}, 1, 0, "an unlisted dead link fails"),
                ({(pg, "/docs/nowhere/"): 1}, 0, 0, "a listed dead link passes"),
                ({(pg, "/docs/nowhere/"): 1, (pg, "/docs/stdlib/str/"): 2}, 0, 1,
                 "a listed link that resolves is stale")]:
            new, stale = triage(broken, known)
            cases.append((what, None))
            if (len(new), len(stale)) != (want_new, want_stale):
                bad += 1
                print("SELFTEST FAIL: %s (new=%d stale=%d)" % (what, len(new), len(stale)))
    if bad:
        print("selftest: %d of %d cases wrong — the link check is not behaving as documented."
              % (bad, len(cases)))
        return 1
    print("selftest: %d cases OK — %d resolving links accepted, %d dead links reported, "
          "%d known-list cases." % (len(cases), sum(1 for c in cases if c[1] is True),
                                    sum(1 for c in cases if c[1] is False),
                                    sum(1 for c in cases if c[1] is None)))
    return 0


def main():
    if "--selftest" in sys.argv:
        return selftest()
    build = os.path.join(REPO, "build")
    if "--build" in sys.argv:
        build = os.path.abspath(sys.argv[sys.argv.index("--build") + 1])
    if not os.path.isdir(os.path.join(build, "docs")):
        print("ERROR: %s/docs not found — run `make build` first." % build)
        return 2
    broken, links, pages = check(build, os.path.join(REPO, "templates"))
    known = load_known(KNOWN)
    if "--list-known" in sys.argv:          # to (re)seed the list, reviewed by hand
        for page, raw in sorted({(p, r) for p, r, _t in broken}):
            print("%s\t%s\t%s\t%s" % (page, raw, "YYYY-MM-DD", "STORY"))
        return 0
    new, stale = triage(broken, known)
    if new or stale:
        if new:
            print("ERROR: %d link(s) in the rendered docs point at nothing the site serves:\n"
                  % len(new))
            for page, raw, target in new:
                print("  %s: %s  (resolves to %s)" % (page, raw, target))
            print("\nFix the link at its source in the toke repository (docs/ or the script "
                  "that generates the page), then re-sync content/docs (make docs-content).")
        if stale:
            print("\nERROR: %d entr(y/ies) in %s now resolve -- delete them "
                  "(the list only shrinks):" % (len(stale), os.path.relpath(KNOWN, REPO)))
            for page, raw in stale:
                print("  line %d: %s  %s" % (known[(page, raw)], page, raw))
        return 1
    print("doc links OK: %d in-site links on %d rendered /docs pages; every one resolves "
          "except %d listed known dead link(s) (%d occurrence(s)) in %s."
          % (links, pages, len(known), len(broken), os.path.relpath(KNOWN, REPO)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
