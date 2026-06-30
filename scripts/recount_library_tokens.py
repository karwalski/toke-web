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

ROOT = Path(__file__).resolve().parent.parent          # toke-website/
LIB = ROOT / "static" / "library"
CORPUS = ROOT.parent / "toke-test-programs" / "results"
SOL = CORPUS / "solutions"
PYREF = CORPUS / "python-refs"

sys.path.insert(0, str(ROOT.parent / "toke-tokenizer" / "python"))
from toke_tokenizer.tokenizer import count_tokens
import tiktoken
CL = tiktoken.get_encoding("cl100k_base")


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
        json.dump(d, open(cf, "w"), indent=2, ensure_ascii=False)
        a = agg(trs)
        if key in cat_meta:
            cm = cat_meta[key]
            cm["avg_token_ratio"] = a["avg"]
            cm["median_token_ratio"] = a["median"]
            cm["avg_toke_tokens"] = round(statistics.mean(tts), 1) if tts else 0
            cm["avg_python_tokens"] = round(statistics.mean(pts), 1) if pts else 0
            # keep a corrected byte ratio for reference
            brs = [p["byte_ratio"] for p in d["programs"] if p.get("byte_ratio") is not None]
            cm["avg_byte_ratio"] = round(statistics.mean(brs), 4) if brs else 0
        all_tr += trs; all_tt += tts; all_pt += pts
        print(f"{key:<22} {len(d['programs']):>4} progs  paired {len(trs):>4}  "
              f"median token_ratio {a['median']:.2f}  avg {a['avg']:.2f}")

    overall = agg(all_tr)
    index["avg_token_ratio"] = overall["avg"]
    index["median_token_ratio"] = overall["median"]
    index["avg_toke_tokens"] = round(statistics.mean(all_tt), 1) if all_tt else 0
    index["avg_python_tokens"] = round(statistics.mean(all_pt), 1) if all_pt else 0
    index["toke_fewer_tokens_pct"] = round(100 * sum(1 for r in all_tr if r > 1) / len(all_tr), 1) if all_tr else 0
    index["methodology"] = ("toke BPE v03 (16,384 vocab) vs cl100k_base, measured on the actual "
                            "solution.tk / solution.py sources. Corpus solutions are generated and "
                            "repaired for correctness, not hand-optimised for tokens.")
    json.dump(index, open(LIB / "index.json", "w"), indent=2, ensure_ascii=False)
    print(f"\nTOTAL {total} programs, {paired} paired.")
    print(f"Overall median token_ratio {overall['median']:.2f}, avg {overall['avg']:.2f}, "
          f"toke fewer tokens in {index['toke_fewer_tokens_pct']:.0f}% of programs.")


if __name__ == "__main__":
    main()
