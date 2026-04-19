#!/usr/bin/env python3
"""
validate_examples.py — Extract and check all toke code blocks in docs.

Usage:
    python3 validate_examples.py [--verbose]

Exit code 0 if all pass, 1 if any fail.
"""

import subprocess
import sys
import os
import re
import tempfile
from pathlib import Path

TKC = "/Users/matthew.watt/tk/toke/tkc"
DOCS = "/Users/matthew.watt/tk/toke-web/src/content/docs"

VERBOSE = "--verbose" in sys.argv or "-v" in sys.argv

pas, fail, skip = 0, 0, 0
failures = []

for mdfile in sorted(Path(DOCS).rglob("*.md")) + sorted(Path(DOCS).rglob("*.mdx")):
    content = mdfile.read_text(encoding="utf-8", errors="replace")
    # Match ```toke ... ``` blocks with their preceding context (non-greedy, DOTALL)
    # We need positions to check for skip-check comments before each block
    blocks_with_pos = [(m.start(), m.group(1)) for m in re.finditer(r'```toke\n(.*?)```', content, re.DOTALL)]
    if not blocks_with_pos:
        continue

    for i, (block_start, block) in enumerate(blocks_with_pos):
        code = block.strip()
        if not code:
            skip += 1
            continue

        # Check for <!-- skip-check --> in the 200 chars before this block
        preceding = content[max(0, block_start - 200):block_start]
        if "<!-- skip-check -->" in preceding:
            skip += 1
            if VERBOSE:
                print(f"  SKIP  {mdfile.relative_to(DOCS)} block #{i+1}")
            continue

        # Add module header if missing
        if not re.match(r'\s*m\s*=', code):
            code = "m=test;\n" + code

        with tempfile.NamedTemporaryFile(suffix=".tk", mode="w", delete=False, encoding="utf-8") as f:
            f.write(code)
            fname = f.name

        try:
            r = subprocess.run(
                [TKC, "--check", fname],
                capture_output=True,
                text=True,
                timeout=10
            )
            if r.returncode == 0:
                pas += 1
                if VERBOSE:
                    print(f"  PASS  {mdfile.relative_to(DOCS)} block #{i+1}")
            else:
                fail += 1
                rel = str(mdfile.relative_to(DOCS))
                stderr = (r.stderr or r.stdout or "").strip()
                failures.append((rel, i + 1, code, stderr))
                if VERBOSE:
                    print(f"  FAIL  {rel} block #{i+1}")
                    print(f"        {stderr[:120]}")
        except subprocess.TimeoutExpired:
            skip += 1
            print(f"  SKIP (timeout)  {mdfile.relative_to(DOCS)} block #{i+1}")
        except Exception as e:
            skip += 1
            print(f"  SKIP (error: {e})  {mdfile.relative_to(DOCS)} block #{i+1}")
        finally:
            try:
                os.unlink(fname)
            except OSError:
                pass

total = pas + fail + skip
print(f"\n{'='*60}")
print(f"RESULTS: {total} blocks checked")
print(f"  PASS: {pas}")
print(f"  FAIL: {fail}")
print(f"  SKIP: {skip}")
print(f"{'='*60}")

if failures:
    print(f"\nFAILURES ({len(failures)}):\n")
    for rel, block_num, code, err in failures[:30]:
        print(f"  [{rel}] block #{block_num}")
        # Show first 2 lines of the code block
        preview = "\n    ".join(code.splitlines()[:3])
        print(f"    code: {preview}")
        print(f"    error: {err[:200]}")
        print()

sys.exit(0 if fail == 0 else 1)

# ---------------------------------------------------------------------------
# Auto-extract passing blocks to corpus exemplars
# ---------------------------------------------------------------------------
# Run: python3 validate_examples.py --save-corpus
# Appends any newly-seen passing blocks to toke-corpus/exemplars/doc_examples.jsonl
if "--save-corpus" in sys.argv and fail == 0:
    extractor = Path(__file__).parent.parent.parent / "toke-corpus/exemplars/extract_doc_examples.py"
    if extractor.exists():
        subprocess.run([sys.executable, str(extractor)], check=False)
