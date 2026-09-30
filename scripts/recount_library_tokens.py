#!/usr/bin/env python3
"""recount_library_tokens.py — honest token/byte recount for the program library.

The library JSON shipped with a bogus `toke_bytes` (98% mismatched the real
solution.tk) which inflated the efficiency ratios. This recomputes, for every
program, the REAL figures from the paired corpus sources:

  toke_bytes    = size of results/solutions/<cat>/<id>/solution.tk
  python_bytes  = size of results/python-refs/<cat>/<id>/solution.py
  toke_tokens   = toke BPE v03 (16,384) token count of the toke source
  python_tokens = cl100k_base token count of the Python source
  token_ratio   = python_tokens / toke_tokens   (>1 => toke fewer tokens)
  byte_ratio    = python_bytes  / toke_bytes     (>1 => toke fewer bytes)

Aggregates (per category + index.json) are recomputed on the honest data.
These corpus solutions are auto-generated/repaired for correctness, not
hand-optimised for tokens, so the honest picture is that toke is often LARGER —
that is intentional transparency (see the methodology note on the page).
"""
import sys, json, os, glob, statistics
from pathlib import Path

# 132.56a — until this was added, nothing ran this script: it was wired into no
# make target, so no gate covered /library freshness. That is how a snapshot
# dated 2026-06-26 stayed published through the entire v0.4 language break with
# 969 of its 1,460 programs no longer compiling (132.45).
#
# The gate is --check, NOT a re-run. Wiring the WRITING mode into ci would
# repeat 132.57a exactly -- a gate that repairs its own input cannot fail. And
# per 132.45 a blind regeneration would be actively worse than the stale file:
# the generator recounts the same v0.3 sources without migrating them, so it
# would reproduce the identical stale picture under a fresh date, turning a
# visibly old snapshot into an apparently current one.
#
# So --check recomputes in memory and reports where the published JSON differs
# from what the corpus sources say today. It writes nothing.
# Two non-writing modes, because the drift here is currently KNOWN and
# accepted: 132.45 deliberately labelled the stale snapshot rather than
# regenerating it, pending an owner decision on migrating the v0.3 sources.
# A hard failure in `ci` would block every run on a state that was chosen on
# purpose, and a gate that blocks on an accepted state is a gate that gets
# switched off.
#   --report  print the drift, exit 0   (what `ci` runs today)
#   --check   print the drift, exit 1   (flip `ci` to this once 132.45 lands)
CHECK = "--check" in sys.argv
REPORT = "--report" in sys.argv
DRY = CHECK or REPORT

ROOT = Path(__file__).resolve().parent.parent          # toke-website/
LIB = ROOT / "static" / "library"
# 132.105 — the two sibling repos this reads are NAMED, not guessed from where
# this checkout happens to sit. Both used to be ROOT.parent/<repo>, which only
# holds for the main checkout at ~/tk/toke-website: from any git worktree (and in
# a CI job that checks out one repo) the tokenizer import failed with
# ModuleNotFoundError and `make ci` stopped here. The Makefile passes
# TOKE_TOKENIZER and TOKE_TEST_PROGRAMS (default ~/tk/<repo>); the fallback is
# the old sibling layout, so a direct run from the main checkout still works.
def _repo(env, name):
    return Path(os.environ.get(env) or (ROOT.parent / name)).expanduser()


TOKENIZER_REPO = _repo("TOKE_TOKENIZER", "toke-tokenizer")
CORPUS = _repo("TOKE_TEST_PROGRAMS", "toke-test-programs") / "results"
SOL = CORPUS / "solutions"
PYREF = CORPUS / "python-refs"
# The vocabulary is the site's own tracked copy -- the artefact /tokenizer
# publishes (sha256 42631f3a..., identical to toke-tokenizer's). The package's
# data/tokenizer_v03.json is not tracked in toke-tokenizer, so a fresh clone of
# it has the code but not the file its count_tokens() loads.
VOCAB = ROOT / "static" / "tokenizer_v03.json"


def _need(path, what, env):
    if not path.exists():
        sys.exit(f"recount-library: {what} not found at {path}\n"
                 f"  Set {env}=/path/to/it (make check-library {env}=...). Missing\n"
                 f"  sources are a failure, not a skip: with them absent every\n"
                 f"  program reads as unpaired and the report would describe nothing.")


_need(TOKENIZER_REPO / "python" / "toke_tokenizer" / "tokenizer.py",
      "the toke_tokenizer package", "TOKE_TOKENIZER")
_need(SOL, "the library's toke sources (results/solutions)", "TOKE_TEST_PROGRAMS")
_need(PYREF, "the library's Python references (results/python-refs)", "TOKE_TEST_PROGRAMS")
_need(VOCAB, "static/tokenizer_v03.json", "TOKE_TOKENIZER")

sys.path.insert(0, str(TOKENIZER_REPO / "python"))
from toke_tokenizer.tokenizer import TokeTokenizer  # noqa: E402
import tiktoken  # noqa: E402
CL = tiktoken.get_encoding("cl100k_base")
_TOKE = TokeTokenizer.from_file(VOCAB)


def count_tokens(text):
    return len(_TOKE.encode(text))


def round_or_none(x, n=4):
    return round(x, n) if x is not None else None


def recount_program(cat, p):
    tkf = SOL / cat / p["id"] / "solution.tk"
    pyf = PYREF / cat / p["id"] / "solution.py"
    if not (tkf.is_file() and pyf.is_file()):
        for k in ("toke_tokens", "python_tokens", "token_ratio"):
            p.setdefault(k, None)
        return p, None
    tsrc = tkf.read_text(errors="replace")
    psrc = pyf.read_text(errors="replace")
    tb, pb = tkf.stat().st_size, pyf.stat().st_size
    tt, pt = count_tokens(tsrc), len(CL.encode(psrc))
    p["toke_bytes"] = tb
    p["python_bytes"] = pb
    p["byte_ratio"] = round_or_none(pb / tb) if tb else None
    p["toke_tokens"] = tt
    p["python_tokens"] = pt
    p["token_ratio"] = round_or_none(pt / tt) if tt else None
    return p, p["token_ratio"]


def agg(vals):
    vals = [v for v in vals if v is not None]
    if not vals:
        return {"avg": 0, "median": 0}
    return {"avg": round(statistics.mean(vals), 4), "median": round(statistics.median(vals), 4)}


def main():
    cat_files = sorted(f for f in glob.glob(str(LIB / "*.json"))
                       if os.path.basename(f) not in ("index.json", "examples.json"))
    index = json.load(open(LIB / "index.json"))
    cat_meta = {c["key"]: c for c in index["categories"]}
    all_tr, all_tt, all_pt = [], [], []
    total = 0
    paired = 0
    drift = []

    def emit(path, obj):
        """Write the JSON, or under --check compare it with what is published."""
        text = json.dumps(obj, indent=2, ensure_ascii=False)
        if not DRY:
            with open(path, "w") as fh:
                fh.write(text)
            return
        published = open(path).read()
        if published != text:
            drift.append(os.path.basename(str(path)))
    for cf in cat_files:
        d = json.load(open(cf))
        key = os.path.basename(cf)[:-5]
        trs, tts, pts = [], [], []
        for p in d["programs"]:
            total += 1
            _, tr = recount_program(key, p)
            if tr is not None:
                paired += 1
                trs.append(tr); tts.append(p["toke_tokens"]); pts.append(p["python_tokens"])
        emit(cf, d)
        a = agg(trs)
        if key in cat_meta:
            cm = cat_meta[key]
            # 132.45: cross-tokenizer aggregates are not emitted — see above.
            cm["avg_toke_tokens"] = round(statistics.mean(tts), 1) if tts else 0
            cm["avg_python_tokens"] = round(statistics.mean(pts), 1) if pts else 0
            # keep a corrected byte ratio for reference
            brs = [p["byte_ratio"] for p in d["programs"] if p.get("byte_ratio") is not None]
            cm["avg_byte_ratio"] = round(statistics.mean(brs), 4) if brs else 0
        all_tr += trs; all_tt += tts; all_pt += pts
        print(f"{key:<22} {len(d['programs']):>4} progs  paired {len(trs):>4}  "
              f"median token_ratio {a['median']:.2f}  avg {a['avg']:.2f}")

    overall = agg(all_tr)
    # 132.45: avg_token_ratio / median_token_ratio / toke_fewer_tokens_pct
    # divide a toke-BPE count by a cl100k_base count. That ratio measures the
    # toke tokenizer's training bias, not the language, and was withdrawn by
    # story 132.13 — but only from the rendered page. The generator kept
    # computing it and index.json kept serving it (toke_fewer_tokens_pct 26.8)
    # to anyone fetching the JSON directly. It is no longer emitted. Per-side
    # token counts stay, each labelled with the tokenizer that produced it;
    # the byte ratio stays, being the one lane with no tokenizer assumption.
    index["avg_toke_tokens"] = round(statistics.mean(all_tt), 1) if all_tt else 0
    index["avg_python_tokens"] = round(statistics.mean(all_pt), 1) if all_pt else 0
    index["methodology"] = ("toke BPE v03 (16,384 vocab) vs cl100k_base, measured on the actual "
                            "solution.tk / solution.py sources. Corpus solutions are generated and "
                            "repaired for correctness, not hand-optimised for tokens.")
    emit(LIB / "index.json", index)
    print(f"\nTOTAL {total} programs, {paired} paired.")
    print("Overall median BYTE ratio %s, avg %s. Cross-tokenizer ratios are "
          "not emitted (132.13 withdrawal, 132.45)."
          % (index.get("median_byte_ratio", "n/a"),
             index.get("avg_byte_ratio", "n/a")))

    if DRY:
        if drift:
            print(f"\nrecount-library: {len(drift)} published file(s) do not match "
                  f"the corpus sources they are derived from:", file=sys.stderr)
            for f in sorted(drift):
                print(f"  {f}", file=sys.stderr)
            print("\nRegenerating is NOT automatically the fix -- see 132.45: the\n"
                  "generator recounts v0.3 sources without migrating them, so a\n"
                  "re-run restamps a stale picture with today's date. Decide which\n"
                  "it is, then either migrate the sources or run without --check.",
                  file=sys.stderr)
            if REPORT:
                print("\nrecount-library: REPORTED, not asserted -- this drift is known "
                      "and accepted under 132.45.", file=sys.stderr)
                return 0
            return 1
        print("\nrecount-library: every published library file matches its corpus sources.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
