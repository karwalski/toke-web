#!/usr/bin/env python3
"""
verify_site_examples.py — compile every toke program the site publishes, and
WRITE the pass/fail badge from the result (story 132.44).

Why this exists
---------------
/tokens published fifteen toke programs, each headed by a green tick. The tick
was static HTML: it was typed by hand and derived from nothing. Two of the
fifteen used the retired v0.3 `=` as equality and were rejected outright by the
compiler the site is built with — so the page asserted, in green, a verification
that had never happened. A badge that claims a check nobody ran is worse than no
badge, because a reader cannot tell the two apart.

This script is that check. It extracts the toke source from the page's own
markup, compiles each program with `tkc --check`, and then writes the badge:
`check-ok` for a program that compiles, `check-fail` for one that does not.
`--check` (the CI mode) fails when the badges in the template disagree with what
the compiler just said, so the tick cannot drift away from the truth again.

The live-tokenizer presets in templates/tokenizer.tkt are checked the same way,
along with the program the page loads into its textarea. They carry no badge,
but they are the code a visitor runs, so they must compile; five of the twelve
presets did not, and neither did the default textarea.

What this does NOT check
------------------------
The per-token `title="token <id>"` ids and the "N tokens (toke BPE v03)" counts
on /tokens are NOT reproducible from any tokenizer artefact in this tree — not
`toke-tokenizer/tokenizer_v03.json` (id 181 is `false` there, not `m=`), not
`models/toke.model` (8K) and not `models/32k/toke.model`. The stated count does
equal the number of rendered spans, so the page is at least self-consistent, but
the ids cannot be re-derived. That is a separate defect and is filed as such;
this script deliberately does not launder it by pretending to verify it.

Usage:
    python3 scripts/verify_site_examples.py            # report
    python3 scripts/verify_site_examples.py --write    # write the badges
    python3 scripts/verify_site_examples.py --check    # CI: fail on drift or on
                                                       # a program that does not compile
Exit: 0 clean, 1 on a compile failure or a badge that disagrees with the compiler.
"""
import html
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TKC = os.environ.get("TKC", os.path.expanduser("~/tk/toke/tkc"))

TOKENS_TKT = os.path.join(ROOT, "templates", "tokens.tkt")
TOKENIZER_TKT = os.path.join(ROOT, "templates", "tokenizer.tkt")
INDEX_TKT = os.path.join(ROOT, "templates", "index.tkt")

OK_BADGE = '<span class="check-ok">&#10003;</span>'
FAIL_BADGE = '<span class="check-fail">&#10007;</span>'

# One gallery entry: <h3>Title <span class="check-*">…</span></h3> followed by the
# toke panel, whose <pre class="tokens"> holds the program as one span per token.
COMPARISON = re.compile(
    r'<h3>(?P<title>[^<]*?)\s*(?P<badge><span class="check-(?:ok|fail)">[^<]*</span>)</h3>'
    r'(?P<between>.*?)'
    r'<div class="lang-label">toke &mdash;[^<]*</div>\s*'
    r'<pre class="tokens">(?P<code>.*?)</pre>',
    re.S)

# PRESETS = { name: { code: '…', langs: {…} }, … } in the page's inline script.
PRESET = re.compile(r"^\s*(?P<name>[a-z][a-z0-9]*):\s*\{\s*$\s*"
                    r"code:\s*'(?P<code>(?:[^'\\]|\\.)*)',", re.M)

# A home-page side-by-side panel: <div class="tv-tab-panel…" id="…">…</div></div>
PANEL = re.compile(r'<div class="tv-tab-panel[^"]*" id="(?P<id>[a-z-]+)">'
                   r'(?P<body>.*?)</div>\s*</div>', re.S)

# The program the /tokenizer page is already showing when it loads.
TEXTAREA = re.compile(r'<textarea id="input"[^>]*>(?P<code>.*?)</textarea>', re.S)

TAG = re.compile(r"<[^>]+>")


def strip_markup(fragment):
    """The published program, as a reader would copy it off the page."""
    return html.unescape(TAG.sub("", fragment))


def unescape_js(literal):
    """A single-quoted JS string literal -> its value."""
    return (literal.replace("\\n", "\n").replace("\\t", "\t")
                   .replace("\\'", "'").replace('\\"', '"')
                   .replace("\\\\", "\\"))


def compiles(source):
    """(ok, first diagnostic line) for `tkc --check` on this program."""
    with tempfile.NamedTemporaryFile("w", suffix=".tk", delete=False,
                                     encoding="utf-8") as fh:
        fh.write(source)
        path = fh.name
    try:
        r = subprocess.run([TKC, "--check", "--diag-text", path],
                           capture_output=True, text=True, timeout=30)
        if r.returncode == 0:
            return True, ""
        out = ((r.stdout or "") + (r.stderr or "")).replace(path, "<program>")
        first = [ln for ln in out.strip().split("\n") if ln.strip()]
        return False, (first[0][:160] if first else "compile failed")
    finally:
        os.unlink(path)


def check_tokens_page(write):
    """Compile each gallery program; return (findings, new_text_or_None)."""
    text = open(TOKENS_TKT, encoding="utf-8").read()
    findings, out, cursor, checked = [], [], 0, 0

    for m in COMPARISON.finditer(text):
        checked += 1
        title = m.group("title").strip()
        source = strip_markup(m.group("code"))
        ok, diag = compiles(source)
        want = OK_BADGE if ok else FAIL_BADGE
        have = m.group("badge")
        if not ok:
            findings.append(("FAIL", title, diag))
        if have != want:
            findings.append(("BADGE", title,
                             "badge says %s; the compiler says %s"
                             % ("PASS" if "check-ok" in have else "FAIL",
                                "PASS" if ok else "FAIL")))
        out.append(text[cursor:m.start("badge")])
        out.append(want)
        cursor = m.end("badge")
    out.append(text[cursor:])
    return findings, checked, ("".join(out) if write else None)


def check_tokenizer_presets():
    text = open(TOKENIZER_TKT, encoding="utf-8").read()
    findings, checked = [], 0
    for m in PRESET.finditer(text):
        checked += 1
        ok, diag = compiles(unescape_js(m.group("code")))
        if not ok:
            findings.append(("FAIL", "preset %s" % m.group("name"), diag))
    m = TEXTAREA.search(text)
    if m:
        checked += 1
        ok, diag = compiles(html.unescape(m.group("code")))
        if not ok:
            findings.append(("FAIL", "textarea default", diag))
    return findings, checked


def check_home_panels():
    """The home page's side-by-side panels (story 132.44).

    Two of them are toke and must compile — both published
    `io.println(fib(10))`, which is E4031 (println takes a str). The others are
    Python/C/Java labelled with a cl100k_base count, and that count IS
    reproducible: tiktoken over the panel's own text must give the stated
    number. The Java panel shipped with an unbalanced parenthesis.
    """
    text = open(INDEX_TKT, encoding="utf-8").read()
    findings, checked = [], 0
    try:
        import tiktoken
        enc = tiktoken.get_encoding("cl100k_base")
    except Exception:
        enc = None

    for m in PANEL.finditer(text):
        pid, body = m.group("id"), m.group("body")
        cm = re.search(r"<code>(.*?)</code>", body, re.S)
        bm = re.search(r"(?P<n>\d+) tokens &mdash; (?P<lane>[^&<]*)", body)
        if not cm or not bm:
            continue
        checked += 1
        source = strip_markup(cm.group(1)).replace("↵", "")
        stated = int(bm.group("n"))
        spans = len(re.findall(r'<span class="tv-tok', cm.group(1)))
        if spans != stated:
            findings.append(("COUNT", pid, "badge says %d tokens; the panel "
                             "renders %d" % (stated, spans)))
        if "toke" in pid:
            ok, diag = compiles(source)
            if not ok:
                findings.append(("FAIL", pid, diag))
        elif enc is not None and "cl100k" in bm.group("lane"):
            n = len(enc.encode(source))
            if n != stated:
                findings.append(("COUNT", pid, "badge says %d cl100k_base "
                                 "tokens; tiktoken counts %d" % (stated, n)))
    if enc is None:
        print("note: tiktoken not installed — the cl100k_base counts on the "
              "home page were not re-derived (pip install tiktoken)")
    return findings, checked


def main():
    write = "--write" in sys.argv
    strict = "--check" in sys.argv

    if not os.path.exists(TKC):
        print("ERROR: tkc not found at %r. Set TKC=/path/to/tkc." % TKC)
        return 1
    version = subprocess.run([TKC, "--version"], capture_output=True,
                             text=True).stdout.strip()
    print("compiler: %s (%s)" % (version, TKC))

    findings, n_gallery, new_text = check_tokens_page(write)
    preset_findings, n_presets = check_tokenizer_presets()
    findings += preset_findings
    home_findings, n_home = check_home_panels()
    findings += home_findings

    if write and new_text is not None:
        with open(TOKENS_TKT, "w", encoding="utf-8") as fh:
            fh.write(new_text)
        print("wrote badges into templates/tokens.tkt")

    print("checked %d /tokens gallery programs, %d /tokenizer programs and "
          "%d home-page panels" % (n_gallery, n_presets, n_home))
    if not findings:
        print("OK: every published toke program compiles, and every badge on "
              "/tokens was written from that compile result.")
        return 0

    print("\nERROR: the site publishes toke that does not compile, a badge the "
          "compiler does not support, or a token count that does not "
          "reproduce (story 132.44):\n")
    for kind, what, detail in findings:
        print("  %-6s %-24s %s" % (kind, what, detail))
    print("\nFix the program, then re-derive the badges:\n"
          "  python3 scripts/verify_site_examples.py --write")
    return 1 if (strict or not write) else 0


if __name__ == "__main__":
    sys.exit(main())
