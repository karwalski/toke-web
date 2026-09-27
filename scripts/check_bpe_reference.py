#!/usr/bin/env python3
"""check_bpe_reference.py — the /tokenizer page's BPE is the real tokenizer (132.52a).

The /tokenizer page encodes in the browser with its own `BPETokenizer` class.
Until 132.52a it disagreed with the `tokenizers` library on the very artefact
it loads: FizzBuzz came out 68 on the page and 65 in the library. The cause
was out-of-vocabulary characters — the artefact has `unk_token: null`, so the
library DROPS a character it has no entry for and lets its neighbours merge,
while the page kept each one as a token.

This gate runs the page's ACTUAL JavaScript — `normalizeToke` and
`BPETokenizer`, cut out of each page that ships them — under node, and
compares it token for token and id for id with the `tokenizers` library
loading the same `static/tokenizer_v03.json`, on:

  * every preset of each page, after the page's own normalisation (what a
    visitor sees on clicking the preset), and the textarea default;
  * every /tokens gallery program and every home-page toke panel, both as
    published and after the page's normalisation (what a visitor sees on
    pasting it);
  * a handful of probes for the three behaviours the old encoder got wrong:
    dropped characters, "\\n" as its own pre-token, and the added tokens.

It also holds the Python mirror in verify_site_examples.py (which derives
the published toke counts) to the same reference, and checks that the page's
`dropped` list accounts for exactly the characters the library dropped.

Needs node and the `tokenizers` Python package. Either missing is a failure,
not a skip: a gate that passes because it could not look is not a gate.

    python3 scripts/check_bpe_reference.py [--page PATH ...]
"""

import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "scripts"))
import verify_site_examples as vse  # noqa: E402

PAGES = [os.path.join(ROOT, "templates", "tokenizer.tkt")]
# 132.100: static/tokenizer.html was a second, still-served copy of /tokenizer
# with its own encoder, and it did not receive 132.53a's fix until 132.52a. It
# is now a redirect stub to /tokenizer. It must stay one: a stub that grows a
# script again is a second encoder this gate does not check.
STUB = os.path.join(ROOT, "static", "tokenizer.html")


def stub_findings(path=STUB):
    if not os.path.exists(path):
        return []
    src = open(path, encoding="utf-8").read()
    out = []
    if re.search(r"<script\b", src, re.I) or "BPETokenizer" in src:
        out.append("%s: carries a script -- a second copy of the /tokenizer "
                   "encoder; it must stay a redirect stub" % os.path.relpath(path, ROOT))
    if not re.search(r'http-equiv="refresh"[^>]*url=/tokenizer"', src):
        out.append("%s: does not redirect to /tokenizer" % os.path.relpath(path, ROOT))
    return out

# Probes for the behaviours that differ from naive BPE on this artefact.
PROBES = [
    "l\\e",                   # a dropped character its neighbours merge across
    "io.println(\"Fizz\")",   # `F` is not in the vocabulary
    "a\nb", "le\nle", "\n",   # "\n" is Isolated: its own token, no merging across
    "x<pad>y", "<|endoftext|>", "a<newline>b<pad>",   # added tokens
    "café \U0001F600 ok",  # non-ASCII and astral characters
    "", "F", "#'?^`~",        # nothing survives
]

NODE_HARNESS = r"""
const fs = require('fs');
%(page_js)s
const data = JSON.parse(fs.readFileSync(%(tok_json)s, 'utf8'));
const bpe = new BPETokenizer(data.model.vocab, data.model.merges, data.added_tokens);
const inp = JSON.parse(fs.readFileSync(0, 'utf8'));
const presets = Object.entries(PRESETS).map(([k, v]) => [k, v.code]);
const run = t => { const r = bpe.encode(t); return { text: t, tokens: r.tokens, ids: r.ids, dropped: (r.dropped || []).map(d => d.ch), before: (r.dropped || []).map(d => d.before) }; };
const out = { presets: [], raw: [], norm: [] };
for (const [k, code] of presets.concat(inp.extra_presets)) out.presets.push(Object.assign({ name: k }, run(normalizeToke(code))));
for (const t of inp.texts) { out.raw.push(run(t)); out.norm.push(run(normalizeToke(t))); }
process.stdout.write(JSON.stringify(out));
"""


def cut(src, start, end_marker, what, page):
    a = src.find(start)
    if a < 0:
        raise SystemExit("ERROR: %s not found in %s" % (what, page))
    b = src.index(end_marker, a) + len(end_marker)
    return src[a:b]


def page_js(page):
    src = open(page, encoding="utf-8").read()
    parts = [cut(src, "function normalizeToke(", "\n}\n", "normalizeToke", page),
             cut(src, "class BPETokenizer {", "\n}\n", "BPETokenizer", page),
             cut(src, "const PRESETS = {", "\n};\n", "PRESETS", page)]
    m = vse.TEXTAREA.search(src)
    default = [["textarea default", html.unescape(m.group("code"))]] if m else []
    return "\n".join(parts), default


def published_texts():
    texts = []
    tokens = open(vse.TOKENS_TKT, encoding="utf-8").read()
    for m in vse.COMPARISON.finditer(tokens):
        texts.append(("/tokens " + m.group("title").strip(),
                      vse.strip_markup(m.group("code"))))
    index = open(vse.INDEX_TKT, encoding="utf-8").read()
    for m in vse.PANEL.finditer(index):
        if "toke" not in m.group("id"):
            continue
        cm = re.search(r"<code>(.*?)</code>", m.group("body"), re.S)
        if cm:
            texts.append(("home " + m.group("id"),
                          vse.strip_markup(cm.group(1)).replace("↵", "")))
    texts += [("probe %r" % p, p) for p in PROBES]
    return texts


def main():
    pages = PAGES
    if "--page" in sys.argv:
        pages = [a for i, a in enumerate(sys.argv) if i and sys.argv[i - 1] == "--page"]

    node = shutil.which("node")
    try:
        from tokenizers import Tokenizer
        import tokenizers
    except ImportError:
        Tokenizer = None
    if not node or Tokenizer is None:
        print("ERROR: needs node (%s) and the `tokenizers` package (%s). Not run."
              % ("found" if node else "MISSING",
                 "found" if Tokenizer else "MISSING: pip install tokenizers"))
        return 2
    ref = Tokenizer.from_file(vse.TOKENIZER_JSON)
    mirror = vse.load_toke_bpe()
    node_ver = subprocess.run([node, "--version"], capture_output=True,
                              text=True).stdout.strip()
    print("reference: tokenizers %s; page JS under node %s"
          % (tokenizers.__version__, node_ver))

    named = published_texts()
    failures, compared = stub_findings(), 0

    def compare(label, r):
        nonlocal compared
        compared += 1
        e = ref.encode(r["text"])
        if r["tokens"] != e.tokens or r["ids"] != e.ids:
            failures.append("%s: page JS gives %d tokens, tokenizers %d; "
                            "first difference at token %d"
                            % (label, len(r["tokens"]), len(e.tokens),
                               next((i for i, (a, b) in enumerate(
                                   zip(r["tokens"], e.tokens)) if a != b),
                                   min(len(r["tokens"]), len(e.tokens)))))
            return
        if mirror is not None:
            mt, mi, md = mirror(r["text"])
            if mt != e.tokens or mi != e.ids or Counter(md) != Counter(r["dropped"]):
                failures.append("%s: the Python mirror in verify_site_examples.py "
                                "disagrees with the reference" % label)
        # Every character is either inside a token or listed as dropped
        # (added tokens aside, which are whole strings).
        if Counter("".join(r["tokens"])) + Counter(r["dropped"]) != Counter(r["text"]):
            failures.append("%s: tokens + dropped do not account for the text" % label)
        if r["before"] != sorted(r["before"]):
            failures.append("%s: dropped marks are out of order" % label)

    for page in pages:
        js, default = page_js(page)
        with tempfile.NamedTemporaryFile("w", suffix=".js", delete=False) as fh:
            fh.write(NODE_HARNESS % {"page_js": js,
                                     "tok_json": json.dumps(vse.TOKENIZER_JSON)})
            harness = fh.name
        try:
            p = subprocess.run([node, harness], capture_output=True, text=True,
                               input=json.dumps({"texts": [t for _, t in named],
                                                 "extra_presets": default}))
        finally:
            os.unlink(harness)
        if p.returncode:
            failures.append("%s: node failed: %s" % (page, p.stderr.strip()[:300]))
            continue
        out = json.loads(p.stdout)
        rel = os.path.relpath(page, ROOT)
        for r in out["presets"]:
            compare("%s preset %s" % (rel, r["name"]), r)
        for (label, _), raw, norm in zip(named, out["raw"], out["norm"]):
            compare("%s %s (as published)" % (rel, label), raw)
            compare("%s %s (normalised)" % (rel, label), norm)

    if failures:
        print("FAIL: the page's BPE does not reproduce the `tokenizers` library "
              "on the artefact it loads (%d of %d encodings):"
              % (len(failures), compared))
        for f in failures:
            print("  " + f)
        return 1
    print("OK: %d encodings across %d page(s) — page JS under node, the Python "
          "mirror and the `tokenizers` library agree token for token and id "
          "for id." % (compared, len(pages)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
