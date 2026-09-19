#!/usr/bin/env python3
"""
gen_llms.py — generate /llms.txt from the canonical facts block (story 132.2).

Source:   ~/tk/toke/docs/about/canonical.json   (override with TOKE_DOCS)
Target:   sites/tokelang.dev/llms.txt           (served at /llms.txt by main.tk)

llms.txt is the file an agent reads to learn what toke is. It must therefore be
useful rather than promotional: what the language is, what it is not, the facts
it needs to generate toke, the honest state of the project, and where to read
the normative documents.

Every verbatim block (the one-liner, the paragraph, the disambiguation line, the
sub-project line, the token-efficiency short form) is copied out of
canonical.json by this script, so it cannot drift by hand. `make check-canonical`
in the toke repo re-checks the result from the other side.

Usage:
    python3 scripts/gen_llms.py            # write the file
    python3 scripts/gen_llms.py --check    # exit 1 if the file is stale
"""

import json
import os
import sys
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = Path(os.environ.get("TOKE_DOCS", os.path.expanduser("~/tk/toke/docs")))
CANON = DOCS / "about" / "canonical.json"
TARGET = ROOT / "sites" / "tokelang.dev" / "llms.txt"

WIDTH = 88


def wrap(text, width=WIDTH, indent=""):
    body = "\n".join(textwrap.wrap(text, width - len(indent),
                                   break_on_hyphens=False, break_long_words=False))
    if indent:
        body = "\n".join(indent + line if i else line
                         for i, line in enumerate(body.split("\n")))
    return body


def bullet(label, text):
    """A '- Label. body' bullet, wrapped and hanging-indented by two spaces."""
    return textwrap.fill("- %s %s" % (label, text), WIDTH, subsequent_indent="  ",
                         break_on_hyphens=False, break_long_words=False)


def cont(text):
    """A continuation paragraph inside a bullet."""
    return textwrap.fill(text, WIDTH, initial_indent="  ", subsequent_indent="  ",
                         break_on_hyphens=False, break_long_words=False)


def plain(text):
    """canonical.json carries a little Markdown emphasis; llms.txt is prose."""
    return text.replace("**", "").replace("*", "")


def render(canon):
    b = canon["blocks"]
    cs = canon["language_facts"]["character_set"]
    kw = canon["language_facts"]["keywords"]
    out = []
    w = out.append

    w("# toke\n")
    w(wrap(b["one_liner"]["value"]) + "\n")
    w("Canonical source of every fact on this page: docs/about/canonical.md +")
    w("docs/about/canonical.json in github.com/karwalski/toke. Every number here comes from")
    w("docs/metrics-baseline.md and carries its tokenizer and its sample size. A toke number")
    w("quoted anywhere without both is not one this project stands behind.\n")

    w("## What toke is\n")
    w(wrap(b["paragraph"]["value"]) + "\n")

    w("## What toke is not\n")
    w(wrap(b["disambiguation"]["value"]) + "\n")
    w(wrap(
        "That last one is practical rather than decorative: the same third party holds the .com "
        "domain, the matching GitHub organisation and the matching crates.io crate name. None "
        "of them is this project. This project's own package scopes, registry names and URLs "
        "are unchanged and unrelated to it."
    ) + "\n")

    w("## Language facts\n")
    w("- Name: toke, lower case always, including sentence-initial position. Never \"Toke\",")
    w("  never \"TOKE\". \"Token-Optimised Language\" is a descriptor, never the name.")
    w(bullet("Type:", canon["type"]["value"] + ". " + canon["type"]["not"][0].upper() + canon["type"]["not"][1:] + "."))
    w("- Spec version: v0.4 — docs/spec/toke-spec-v0.4.md is normative. v0.3 is historical")
    w("  and superseded.")
    w(bullet("Keywords:", "%d — %s." % (kw["count"], " ".join(kw["list"]))))
    w(bullet("Character set:", "%d — %s." % (cs["count"], cs["composition"])))
    w("- Grammar: backtrack-free with bounded lookahead of up to 3 tokens on a small,")
    w("  enumerated set of productions (E1-E5), listed with their FIRST-sets in Appendix A")
    w("  of docs/spec/grammar.ebnf. toke is NOT LL(1): that v0.3 claim was retired on")
    w("  2026-07-02 as inaccurate for the real grammar. The mechanical argument is unchanged")
    w("  — a small backtrack-free grammar with bounded lookahead keeps the pushdown")
    w("  automaton behind a decoding mask small and the masks cheap.")
    w("- Canonical form: one per construct, chosen by measurement in a 46-entry pattern")
    w("  catalogue and reproduced by `tkc --min`.")
    w(bullet("Compiler:", canon["compiler"]["value"]))
    w("  Current version: %s. Licence %s." % (canon["compiler"]["version"], canon["compiler"]["licence"]))
    w("- Author: " + canon["author"]["value"])
    w("- Source: github.com/karwalski/toke — six repositories under github.com/karwalski.")
    w("  The site is tokelang.dev, built and served by ooke.\n")

    w("## A complete program\n")
    w("```toke")
    w("m=hello;")
    w("i=io:std.io;")
    w("")
    w("f=main():i64{")
    w("  io.println(\"Hello, world!\");")
    w("  <0;")
    w("};")
    w("```\n")
    w("`m=` declares the module, `i=` imports, `f=` declares a function, `<` returns, and")
    w("every statement ends with `;`. The declaration order m, i, t, f is enforced by the")
    w("compiler (E2001). Read the syntax card linked below before generating toke: it is")
    w("written for models and every rule in it is verified against tkc 2.8.0.\n")

    w("## Where the project actually is\n")
    w("Stated so that nothing here has to be discovered later.\n")
    w(bullet("Models.", canon["models"]["value"]))
    w(cont(canon["models"]["rule"]))
    w(bullet("Tokenizer.", canon["tokenizer"]["value"]))
    w(bullet("Benchmark.", canon["benchmark"]["value"]))
    w(cont(canon["benchmark"]["caveat"]))
    w("")
    w(wrap(plain(b["token_efficiency_short_form"]["value"])) + "\n")

    w("## Sub-projects\n")
    w(wrap(b["subprojects"]["value"]) + "\n")

    w("## Read next\n")
    w("- Specification, normative:")
    w("  https://github.com/karwalski/toke/blob/main/docs/spec/toke-spec-v0.4.md")
    w("- Machine-readable grammar:")
    w("  https://github.com/karwalski/toke/blob/main/docs/spec/grammar.ebnf")
    w("  and https://github.com/karwalski/toke/blob/main/docs/spec/toke.gbnf (GBNF, for")
    w("  constrained decoding)")
    w("- Syntax card, written for models, every rule verified against tkc 2.8.0:")
    w("  https://github.com/karwalski/toke-corpus/blob/main/regen/syntax_card.md")
    w("- Roadmap — what is done, what is running, what is compute-gated, and the benchmark")
    w("  each stage is measured against: https://tokelang.dev/roadmap")
    w("- Status — the current numbers and what they do and do not support:")
    w("  https://tokelang.dev/status")
    w("- Landscape — the evidence against our own thesis, lane by lane:")
    w("  https://github.com/karwalski/toke/blob/main/docs/about/landscape-2026-09.md")
    w("- Canonical facts, the source of this file:")
    w("  https://github.com/karwalski/toke/blob/main/docs/about/canonical.md")
    w("- Honest metrics baseline, the only source for toke numbers:")
    w("  https://github.com/karwalski/toke/blob/main/docs/metrics-baseline.md")
    w("- Documentation: https://tokelang.dev/docs\n")

    w("## If you are quoting toke\n")
    w("- Write the name lower case.")
    w("- Do not write \"LL(1)\" or \"13 keywords\". Both are retired and both are wrong.")
    w("- Do not quote \"52% fewer tokens\", \"42% reduction vs Python\", or any bare token")
    w("  percentage. Those crossed two tokenizers and are withdrawn, not requalified.")
    w("- Do not quote the Gate 2 100% compile figure without the curated set it was measured")
    w("  on, and do not present the August 2026 corpus freeze as a model gate — August")
    w("  produced a training-data quality freeze, not a gate result.")
    w("- Every number needs its tokenizer and its N. If you cannot state both, do not state")
    w("  the number.")

    return "\n".join(out) + "\n"


def main():
    if not CANON.exists():
        print("gen_llms: canonical.json not found at %s" % CANON, file=sys.stderr)
        print("          set TOKE_DOCS to the toke repo's docs/ directory", file=sys.stderr)
        return 2
    text = render(json.loads(CANON.read_text()))
    if "--check" in sys.argv:
        current = TARGET.read_text() if TARGET.exists() else ""
        if current != text:
            print("STALE: %s does not match %s" % (TARGET, CANON), file=sys.stderr)
            print("       run: python3 scripts/gen_llms.py", file=sys.stderr)
            return 1
        print("llms.txt is current against %s" % CANON)
        return 0
    TARGET.parent.mkdir(parents=True, exist_ok=True)
    TARGET.write_text(text)
    print("wrote %s (%d bytes)" % (TARGET, len(text)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
