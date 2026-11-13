#!/usr/bin/env python3
"""check_doc_titles.py — every rendered /docs page carries its source's title (132.148).

The front-matter parser in ooke kept YAML quotes and, in older builds, cut a
value at its first ":", so toke docs/about/canonical.md
(`title: "Canonical facts: how toke is described"`) went out with the <title>
`"Canonical facts — toke docs`.  Ten more pages had no front matter at all and
rendered an empty <title> and <h1> (132.147).  Nothing looked: the build
checked that pages rendered, never what they were called.

For every page under build/docs/ that is not a redirect stub this checks:

  * the <title> is not empty -- the text before the " — toke" suffix the
    templates append;
  * neither the <title> nor the first <h1> starts or ends with a quote mark
    (a YAML quote the parser kept);
  * when the page comes from content/docs/, the <title> is the front-matter
    `title` as YAML reads it -- so a value cut short at a colon, or a page
    rendered by an ooke without the quote fix, fails too -- and so is its
    <h1>, which is the page's ONLY <h1>: the front-matter title is the single
    heading, so a body H1 left in the markdown is a second one (132.150;
    the pages that still have one are listed in KNOWN_EXTRA_H1, story 132.151);
  * every section page template, templates/docs/*/[slug].tkt, renders
    `<h1>{= title =}</h1>`.  There is no exception: the reference template was
    one, so 15 reference pages had no <h1> and 9 had a body H1 that disagreed
    with their title, until 132.150 aligned it with the rest.

Usage:
  check_doc_titles.py             check build/ (needs `make build`)
  check_doc_titles.py --selftest  negative controls on a synthetic tree
"""
import html
import pathlib
import re
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
REDIRECT = re.compile(r"<meta[^>]+http-equiv=[\"']?refresh", re.I)
TITLE = re.compile(r"<title[^>]*>(.*?)</title>", re.I | re.S)
H1 = re.compile(r"<h1[^>]*>(.*?)</h1>", re.I | re.S)
TAG = re.compile(r"<[^>]+>")
SUFFIX = re.compile(r"(?:^|\s+)—\s+toke(?: docs)?\s*$")
FRONT = re.compile(r"\A---\n(.*?)\n---\n", re.S)
QUOTES = ("\"", "'", "“", "”", "‘", "’")


def yaml_scalar(raw):
    """A front-matter value as YAML reads a one-line scalar (ooke 132.148)."""
    v = raw.strip()
    if len(v) > 1 and v[0] == v[-1] == "\"":
        return "\\".join(p.replace("\\\"", "\"") for p in v[1:-1].split("\\\\"))
    if len(v) > 1 and v[0] == v[-1] == "'":
        return v[1:-1].replace("''", "'")
    return v


def front_matter(text):
    m = FRONT.match(text)
    out = {}
    for line in (m.group(1).split("\n") if m else []):
        line = line.strip()
        if ": " in line:
            k, _, v = line.partition(": ")
        elif line.endswith(":"):
            k, v = line[:-1], ""
        else:
            continue
        if k.strip():
            out[k.strip()] = yaml_scalar(v)
    return out


def sources(root):
    """{"docs/<section>/<slug>": title or None} from content/docs/."""
    out = {}
    base = root / "content" / "docs"
    for md in sorted(base.rglob("*.md")):
        fm = front_matter(md.read_text(encoding="utf-8", errors="replace"))
        slug = fm.get("slug") or md.stem
        out["docs/%s/%s" % (md.relative_to(base).parts[0], slug)] = (
            md.relative_to(root), fm.get("title"))
    return out


# Pages whose toke source still carries a body H1 under its front-matter title,
# so they render two <h1>s.  Found 2026-11-13 when 132.150 made the extra H1 a
# finding; fixing them at the source is story 132.151.  This list only shrinks:
# a listed page that renders one <h1> fails until its entry is deleted.
KNOWN_EXTRA_H1 = {
    "/docs/about/canonical", "/docs/about/kern-2026-08",
    "/docs/about/landscape-2026-09", "/docs/about/positioning-2026-09",
    "/docs/about/registry-descriptions", "/docs/compiler/build-deps",
    "/docs/security/threat-model", "/docs/spec/capabilities",
    "/docs/spec/memory-model", "/docs/spec/oke-namespace",
    "/docs/spec/toke-spec-v0.4", "/docs/stdlib/webview",
    "/docs/tutorials/cross-platform", "/docs/tutorials/data-pipeline",
}

H1_FROM_TITLE = re.compile(r"<h1>\s*\{=\s*title\s*=\}\s*</h1>")


def templates_without_h1(root):
    """Section page templates that do not render the front-matter title as <h1>."""
    out = []
    for t in sorted((root / "templates" / "docs").glob("*/[[]slug[]].tkt")):
        if not H1_FROM_TITLE.search(t.read_text(encoding="utf-8", errors="replace")):
            out.append(t.relative_to(root).as_posix())
    return out


def text_of(m):
    return html.unescape(TAG.sub("", m.group(1))).strip() if m else None


def problems(root, known_extra_h1=frozenset(KNOWN_EXTRA_H1)):
    out = ["%s: renders no <h1>{= title =}</h1> -- every section's page "
           "template must (132.150)" % t for t in templates_without_h1(root)]
    src = sources(root)
    pages = sorted((root / "build" / "docs").rglob("index.html"))
    checked = 0
    for page in pages:
        body = page.read_text(encoding="utf-8", errors="replace")
        if REDIRECT.search(body):
            continue
        checked += 1
        rel = page.parent.relative_to(root / "build").as_posix()
        url = "/" + rel
        full = text_of(TITLE.search(body))
        if full is None:
            out.append("%s: no <title>" % url)
            continue
        title = SUFFIX.sub("", full).strip()
        h1s = H1.findall(body)
        h1 = text_of(H1.search(body))
        if not title:
            out.append("%s: empty <title> (%r)" % (url, full))
        for name, val in (("<title>", title), ("<h1>", h1)):
            if val and (val.startswith(QUOTES) or val.endswith(QUOTES)):
                out.append("%s: %s has a stray quote: %r" % (url, name, val))
        if rel in src:
            path, want = src[rel]
            if not want:
                out.append("%s: %s has no front-matter title" % (url, path))
                continue
            if title and title != want:
                out.append("%s: <title> %r is not the front-matter title %r (%s)"
                           % (url, title, want, path))
            if h1 != want:
                out.append("%s: <h1> %r is not the front-matter title %r (%s)"
                           % (url, h1, want, path))
            if url in known_extra_h1:
                if len(h1s) < 2:
                    out.append("%s: renders one <h1> now -- delete it from "
                               "KNOWN_EXTRA_H1 (132.151)" % url)
            elif len(h1s) > 1:
                out.append("%s: %d <h1>s -- the front-matter title is the only "
                           "heading; drop the body H1 at the source (%s): %s"
                           % (url, len(h1s), path,
                              ", ".join(repr(html.unescape(TAG.sub("", x)).strip())
                                        for x in h1s[1:])))
    return checked, out


PAGE = ('<!doctype html><html><head><title>%s — toke docs</title></head>'
        '<body><h1>%s</h1>%s</body></html>')
TPL_H1 = ('{! block("title") !}{= title =} — toke docs{! end !}\n'
          '<h1>{= title =}</h1>\n{= body | md =}\n')
TPL_NO_H1 = '{! block("title") !}{= title =} — toke docs{! end !}\n{= body | md =}\n'
STUB = '<!doctype html><meta http-equiv="refresh" content="0; url=/x"><title></title>'


def selftest():
    cases = [
        # (name, front matter title line, rendered title, rendered h1, ok
        #  [, more body html [, the section page template [, listed as known]]])
        ("a plain title", "title: Hello", "Hello", "Hello", True),
        ("a quoted title with a colon", 'title: "A: b"', "A: b", "A: b", True),
        ("a single-quoted title", "title: 'It''s'", "It&#39;s", "It&#39;s", True),
        ("an escaped title", 'title: "a \\"b\\" c"', "a &quot;b&quot; c", "a &quot;b&quot; c", True),
        ("the quote kept (132.148)", 'title: "A: b"', '&quot;A: b&quot;', '&quot;A: b&quot;', False),
        ("cut at the first colon", 'title: "A: b"', '&quot;A', '&quot;A', False),
        ("cut, quote stripped", 'title: "A: b"', "A", "A", False),
        ("an empty title (132.147)", "", "", "", False),
        ("a stray single quote", "title: 'x", "&#39;x", "&#39;x", False),
        ("h1 differs from title", "title: Hello", "Hello", "Other", False),
        ("an empty title on a page with no source", None, "", "", False),
        # 132.150: the front-matter title is the page's only heading, and every
        # section template renders it.
        ("a body H1 as well (132.150)", "title: Hello", "Hello", "Hello", False,
         "<h1>Hello again</h1>"),
        ("a template with no <h1> (132.150)", "title: Hello", "Hello", "", False,
         "", TPL_NO_H1),
        ("a template with no <h1>, body H1 = title", "title: Hello", "Hello",
         "Hello", False, "", TPL_NO_H1),
        ("a body H1 on a KNOWN_EXTRA_H1 page", "title: Hello", "Hello", "Hello",
         True, "<h1>Hello again</h1>", TPL_H1, True),
        ("a KNOWN_EXTRA_H1 page fixed but still listed", "title: Hello", "Hello",
         "Hello", False, "", TPL_H1, True),
    ]
    bad = 0
    for case in cases:
        name, fm, t, h, ok = case[:5]
        extra = case[5] if len(case) > 5 else ""
        tpl_text = case[6] if len(case) > 6 else TPL_H1
        known = {"/docs/learn/p"} if len(case) > 7 and case[7] else set()
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            md = root / "content/docs/learn/p.md"
            md.parent.mkdir(parents=True)
            if fm is None:                       # rendered, but not from content/docs
                md.write_text("---\ntitle: Other\nslug: other\n---\nbody\n")
            else:
                md.write_text("---\n%sslug: p\n---\nbody\n" % (fm + "\n" if fm else ""))
            tpl = root / "templates/docs/learn/[slug].tkt"
            tpl.parent.mkdir(parents=True)
            tpl.write_text(tpl_text)
            out = root / "build/docs/learn/p/index.html"
            out.parent.mkdir(parents=True)
            out.write_text(PAGE % (t, h, extra))
            stub = root / "build/docs/community/p/index.html"
            stub.parent.mkdir(parents=True)
            stub.write_text(STUB)
            n, why = problems(root, known)
            if n != 1:
                bad += 1
                print("SELFTEST FAIL [%s] %d pages checked, want 1 (stub skipped)" % (name, n))
            if (not why) != ok:
                bad += 1
                print("SELFTEST FAIL [%s] %s: %s" % ("accept" if ok else "reject", name,
                                                     "; ".join(why) or "not flagged"))
    if bad:
        print("check_doc_titles selftest: %d of %d cases wrong" % (bad, len(cases)))
        return 1
    print("check_doc_titles selftest: %d cases OK (%d accepted, %d defects caught)"
          % (len(cases), sum(c[4] for c in cases), sum(not c[4] for c in cases)))
    return 0


def main(argv):
    if "--selftest" in argv:
        return selftest()
    if not (ROOT / "build" / "docs").is_dir():
        print("check_doc_titles: build/docs/ is missing -- run: make build", file=sys.stderr)
        return 1
    n, why = problems(ROOT)
    if why:
        print("check_doc_titles: %d problem(s) in %d /docs page(s):" % (len(why), n))
        for w in why:
            print("  " + w)
        print("Fix the title at its toke source (front matter) and resync, or rebuild "
              "ooke if the source is right (OOKE=/path/to/ooke-toke).")
        return 1
    print("check_doc_titles: %d /docs pages, every <title> and <h1> is its source's title"
          % n)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
