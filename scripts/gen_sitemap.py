#!/usr/bin/env python3
"""gen_sitemap.py — build/sitemap.xml, generated from the built page set (132.138).

sites/tokelang.dev/sitemap.xml was kept by hand: it listed 109 URLs while the
build rendered about 195 /docs pages, and it listed redirects (/ecosystem/, the
trailing-slash stubs) in place of the pages they point at.  It is now written
by `make build` (scripts/build_static.sh) from what the build actually serves:

  * every named route: templates/**.tkt, as http.servepages registers them
    (the layout templates and parameter routes excluded, as in
    scripts/check_routes.sh), at the path the route answers -- "/" for
    index.tkt, "/roadmap" for roadmap.tkt, "/docs/learn" for
    templates/docs/learn/index.tkt;
  * every page under build/docs/: build/docs/<path>/index.html at
    /docs/<path> (the form the site's own links use);
  * every standalone page at the top of build/ (build/<name>.html) that no
    route already serves.

A page is left out when it is not meant to be indexed: a redirect (a
`http-equiv="refresh"` stub -- the retired sections, the trailing-slash stubs,
renamed pages), a page whose robots meta says noindex, an error page (404.html
and friends), or a page whose source front matter says `draft: true`.

`lastmod` is the date of the last commit that touched the page's source (the
content/docs/ markdown for a /docs page, the template for a route, the static/
file for a standalone page) -- never the build time, so two builds of one
checkout write the same bytes.  A source git does not know has no lastmod.

Usage:
  gen_sitemap.py --write      write build/sitemap.xml (build_static.sh runs this)
  gen_sitemap.py --check      fail (1) unless build/sitemap.xml is exactly what
                              the build serves, every URL in it maps to a page
                              that is served and indexable, and every content/
                              docs page that is not a draft is in it
  gen_sitemap.py --selftest   negative controls on a synthetic tree (no build/)
  gen_sitemap.py --routes     print every named route's path, one per line (no
                              build/ needed); build_static.sh derives its
                              trailing-slash stubs from this list (132.144)
"""
import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
SITE = "https://tokelang.dev"
LAYOUTS = {"base.tkt", "docs.tkt", "doc-page.tkt"}       # as check_routes.sh
ERROR_PAGES = re.compile(r"^(?:\d{3}|error)\.html$")
REDIRECT = re.compile(r"<meta[^>]+http-equiv=[\"']?refresh", re.I)
NOINDEX = re.compile(r"<meta[^>]+name=[\"']?robots[\"']?[^>]*noindex"
                     r"|<meta[^>]+content=[\"'][^\"']*noindex[^>]*name=[\"']?robots", re.I)
FRONT = re.compile(r"\A---\n(.*?)\n---\n", re.S)


# ----------------------------------------------------------------- sources ----
def front_matter(path):
    try:
        m = FRONT.match(path.read_text(encoding="utf-8", errors="replace"))
    except OSError:
        return {}
    out = {}
    for line in (m.group(1).split("\n") if m else []):
        k, sep, v = line.partition(":")
        if sep:
            out[k.strip()] = v.strip().strip("\"'")
    return out


def docs_sources(root):
    """{"/docs/<section>/<slug>": (source path, is_draft)} from content/docs/.
    The slug is the front matter's, else the file name's, as ooke renders it."""
    out = {}
    base = root / "content" / "docs"
    for md in sorted(base.rglob("*.md")):       # nested files too (about/reviews/)
        fm = front_matter(md)
        slug = fm.get("slug") or md.stem
        out["/docs/%s/%s" % (md.relative_to(base).parts[0], slug)] = (
            md, fm.get("draft", "").lower() in ("true", "yes", "1"))
    return out


def git_dates(root):
    """{repo-relative path: YYYY-MM-DD of the last commit touching it}, or {}."""
    try:
        p = subprocess.run(["git", "-C", str(root), "log", "--format=%x00%cs", "--name-only",
                            "--", "content/docs", "templates", "static"],
                           capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    if p.returncode != 0:
        return {}
    dates, cur = {}, None
    for line in p.stdout.split("\n"):
        if line.startswith("\0"):
            cur = line[1:]
        elif line and cur:
            dates.setdefault(line, cur)                   # newest commit first
    return dates


def route_paths(root):
    """{url path: template} for every named route."""
    out = {}
    tdir = root / "templates"
    for t in sorted(tdir.rglob("*.tkt")):
        rel = t.relative_to(tdir).as_posix()
        if rel in LAYOUTS or "[" in rel or t.name.startswith("_"):
            continue
        r = "/" + rel[:-len(".tkt")]
        if r == "/index":
            r = "/"
        elif r.endswith("/index"):
            r = r[:-len("/index")]
        out.setdefault(r, t)
    return out


def indexable(html):
    return not REDIRECT.search(html) and not NOINDEX.search(html)


def page_set(root, build):
    """[(url path, source path or None)], sorted, of every indexable page served."""
    routes = route_paths(root)
    docs = docs_sources(root)
    pages = {}
    for r, t in routes.items():
        if NOINDEX.search(t.read_text(encoding="utf-8", errors="replace")):
            continue
        pages[r] = t
    for f in sorted((build / "docs").rglob("index.html")):
        rel = f.parent.relative_to(build).as_posix()
        path = "/" + rel
        if path in pages:
            continue
        if not indexable(f.read_text(encoding="utf-8", errors="replace")):
            continue
        src, draft = docs.get(path, (None, False))
        if draft:
            continue
        pages[path] = src
    for f in sorted(build.glob("*.html")):
        if ERROR_PAGES.match(f.name) or "/" + f.stem in routes:
            continue                                       # an error page, or a route's copy
        if not indexable(f.read_text(encoding="utf-8", errors="replace")):
            continue
        src = root / "static" / f.name
        pages["/" + f.name] = src if src.exists() else None
    return sorted(pages.items(), key=lambda kv: (kv[0] != "/", kv[0]))


def render(pages, root, dates):
    out = ['<?xml version="1.0" encoding="UTF-8"?>',
           '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">']
    for path, src in pages:
        d = dates.get(src.relative_to(root).as_posix()) if src else None
        if d:
            out.append("<url><loc>%s%s</loc><lastmod>%s</lastmod></url>" % (SITE, path, d))
        else:
            out.append("<url><loc>%s%s</loc></url>" % (SITE, path))
    out.append("</urlset>")
    return "\n".join(out) + "\n"


def generate(root):
    build = root / "build"
    return render(page_set(root, build), root, git_dates(root))


# ------------------------------------------------------------------- check ----
LOC = re.compile(r"<loc>([^<]*)</loc>")


def problems(root, text):
    """Reasons the sitemap `text` is wrong for the tree at `root` (empty: right).
    Besides the byte comparison, each URL is checked against the served tree on
    its own terms, and the /docs URLs against content/docs/, which the build
    reads but this check does not take from the build."""
    build = root / "build"
    out = []
    want = generate(root)
    if text != want:
        got_l, want_l = text.split("\n"), want.split("\n")
        for i, (g, w) in enumerate(zip(got_l, want_l)):
            if g != w:
                out.append("line %d: sitemap has %r, the build gives %r" % (i + 1, g, w))
                break
        else:
            out.append("sitemap has %d lines, the build gives %d" % (len(got_l), len(want_l)))
    urls = [u for u in LOC.findall(text)]
    if len(set(urls)) != len(urls):
        out.append("duplicate URLs")
    routes = route_paths(root)
    listed = set()
    for u in urls:
        if not u.startswith(SITE + "/"):
            out.append("%s is not on %s" % (u, SITE))
            continue
        path = u[len(SITE):]
        listed.add(path)
        if path in routes:
            continue
        f = build / path.lstrip("/") / "index.html" if not path.endswith(".html") \
            else build / path.lstrip("/")
        if not f.is_file():
            out.append("%s is not served (no route, no %s)" % (u, f.relative_to(root)))
        elif not indexable(f.read_text(encoding="utf-8", errors="replace")):
            out.append("%s is a redirect or noindex page" % u)
    for path, (src, draft) in sorted(docs_sources(root).items()):
        if draft and path in listed:
            out.append("%s is a draft (%s)" % (path, src.relative_to(root)))
        elif not draft and path not in listed and path not in routes:
            f = build / path.lstrip("/") / "index.html"
            if f.is_file() and not indexable(f.read_text(encoding="utf-8", errors="replace")):
                continue                                   # rendered as noindex: rightly absent
            out.append("%s (%s) is missing from the sitemap" % (path, src.relative_to(root)))
    return out


# ---------------------------------------------------------------- selftest ----
PAGE = "<!doctype html><title>p</title><p>page</p>\n"
STUB = '<!doctype html><meta http-equiv="refresh" content="0; url=/x"><title>Moved</title>\n'
NOIDX = '<!doctype html><meta name="robots" content="noindex"><title>n</title>\n'


def _tree(tmp):
    root = pathlib.Path(tmp)
    files = {
        "templates/base.tkt": "layout", "templates/index.tkt": "home",
        "templates/roadmap.tkt": "roadmap", "templates/docs/learn/index.tkt": "learn",
        "templates/docs/learn/[slug].tkt": "param",
        "content/docs/learn/hello.md": "---\ntitle: Hello\nslug: hello\n---\nbody\n",
        "content/docs/learn/02-x.md": "---\ntitle: X\n---\nbody\n",
        "content/docs/learn/sub/nested.md": "---\ntitle: N\nslug: nested\n---\nbody\n",
        "build/docs/learn/nested/index.html": PAGE,
        "content/docs/learn/wip.md": "---\ntitle: W\nslug: wip\ndraft: true\n---\nbody\n",
        "static/library.html": PAGE,
        "build/docs/learn/hello/index.html": PAGE,
        "build/docs/learn/02-x/index.html": PAGE,
        "build/docs/learn/wip/index.html": PAGE,
        "build/docs/community/hello/index.html": STUB,
        "build/docs/learn/hidden/index.html": NOIDX,
        "build/roadmap/index.html": STUB,
        "build/library.html": PAGE, "build/roadmap.html": PAGE, "build/404.html": PAGE,
        "build/tokens.html": STUB,
    }
    for rel, body in files.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(body)
    env = dict(os.environ, GIT_AUTHOR_DATE="2026-01-02T03:04:05Z",
               GIT_COMMITTER_DATE="2026-01-02T03:04:05Z")
    for c in (["init", "-q"], ["add", "-A"],
              ["-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "t"]):
        subprocess.run(["git", "-C", str(root)] + c, env=env, check=True,
                       capture_output=True)
    return root


def selftest():
    bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        root = _tree(tmp)
        got = generate(root)
        want = ("<url><loc>https://tokelang.dev/</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/docs/learn</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/docs/learn/02-x</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/docs/learn/hello</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/docs/learn/nested</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/library.html</loc><lastmod>2026-01-02</lastmod></url>",
                "<url><loc>https://tokelang.dev/roadmap</loc><lastmod>2026-01-02</lastmod></url>")
        lines = [l for l in got.split("\n") if l.startswith("<url>")]
        if tuple(lines) != want:
            bad += 1
            print("SELFTEST FAIL generated:\n  " + "\n  ".join(lines))
        if generate(root) != got:
            bad += 1
            print("SELFTEST FAIL two generations differ (lastmod must not be the build time)")
        hello = "<url><loc>https://tokelang.dev/docs/learn/hello</loc><lastmod>2026-01-02</lastmod></url>\n"
        cases = [
            (True, "the generated sitemap", got),
            (False, "a page dropped", got.replace(hello, "")),
            (False, "a redirect listed",
             got.replace("</urlset>", "<url><loc>https://tokelang.dev/docs/community/hello</loc></url>\n</urlset>")),
            (False, "a noindex page listed",
             got.replace("</urlset>", "<url><loc>https://tokelang.dev/docs/learn/hidden</loc></url>\n</urlset>")),
            (False, "a draft listed",
             got.replace("</urlset>", "<url><loc>https://tokelang.dev/docs/learn/wip</loc></url>\n</urlset>")),
            (False, "an error page listed",
             got.replace("</urlset>", "<url><loc>https://tokelang.dev/404.html</loc></url>\n</urlset>")),
            (False, "a URL nothing serves",
             got.replace("</urlset>", "<url><loc>https://tokelang.dev/docs/learn/gone</loc></url>\n</urlset>")),
            (False, "a lastmod changed", got.replace("2026-01-02", "2026-11-13", 1)),
            (False, "the hand-kept slash form of a route",
             got.replace("tokelang.dev/roadmap<", "tokelang.dev/roadmap/<")),
        ]
        for ok, name, text in cases:
            why = problems(root, text)
            if (not why) != ok:
                bad += 1
                print("SELFTEST FAIL [%s] %s: %s" % ("accept" if ok else "reject", name,
                                                     "; ".join(why) or "not flagged"))
        # The /docs cross-check against content/docs/ is independent of the
        # byte comparison: a page the build failed to render is caught even
        # when the sitemap was generated from that same short build.
        (root / "build/docs/learn/02-x/index.html").unlink()
        why = problems(root, generate(root))
        if not any("02-x" in w and "missing" in w for w in why):
            bad += 1
            print("SELFTEST FAIL a page missing from the build was not flagged: %s" % why)
    n = 3 + len(cases)
    if bad:
        print("gen_sitemap selftest: %d of %d cases wrong" % (bad, n))
        return 1
    print("gen_sitemap selftest: %d cases OK (generation, reproducibility, %d drifts "
          "caught, missing-render cross-check)" % (n, len(cases) - 1))
    return 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if "--routes" in argv:
        # 132.144: the one derivation of the named routes. build_static.sh
        # used its own (templates/<x>.tkt only), so the routes served from
        # templates/docs/<x>/index.tkt got no trailing-slash stub and their
        # slash form 404ed.
        for r in sorted(route_paths(ROOT)):
            print(r)
        return 0
    target = ROOT / "build" / "sitemap.xml"
    if not (ROOT / "build" / "docs").is_dir():
        print("gen_sitemap: build/docs/ is missing -- run: make build", file=sys.stderr)
        return 1
    if "--write" in argv:
        text = generate(ROOT)
        target.write_text(text)
        print("    sitemap.xml: %d URL(s) from the built page set" % text.count("<url>"))
        return 0
    if "--check" in argv:
        if not target.is_file():
            print("check-sitemap: build/sitemap.xml is missing -- run: make build")
            return 1
        why = problems(ROOT, target.read_text())
        if why:
            print("check-sitemap: build/sitemap.xml does not match the page set:")
            for w in why[:20]:
                print("  " + w)
            print("Regenerate: make build")
            return 1
        print("check-sitemap: build/sitemap.xml matches the page set (%d URLs)"
              % target.read_text().count("<url>"))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
