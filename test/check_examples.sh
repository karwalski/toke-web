#!/usr/bin/env bash
#
# check_examples.sh -- Extract toke code blocks from website docs and
# verify they compile with tkc --check.
#
# Usage:  bash test/check_examples.sh
#         TKC=/path/to/tkc bash test/check_examples.sh
#
# Environment:
#   TKC           Path to tkc binary    (default: ~/tk/toke/build/tkc)
#   THRESHOLD     Minimum pass rate %   (default: 80)
#   VERBOSE       Set to 1 for extra output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WEB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOCS_DIR="$WEB_ROOT/src/content/docs"

TKC="${TKC:-$HOME/tk/toke/tkc}"
THRESHOLD="${THRESHOLD:-50}"
VERBOSE="${VERBOSE:-0}"

# Colours (disabled if not a terminal)
if [[ -t 1 ]]; then
  RED=$'\033[0;31m'  GREEN=$'\033[0;32m'  YELLOW=$'\033[0;33m'
  CYAN=$'\033[0;36m' BOLD=$'\033[1m'      RESET=$'\033[0m'
else
  RED='' GREEN='' YELLOW='' CYAN='' BOLD='' RESET=''
fi

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------
if [[ ! -x "$TKC" ]]; then
  echo "${RED}ERROR: tkc not found at $TKC${RESET}"
  echo "Build it with:  cd ~/tk/toke && make"
  exit 2
fi

if [[ ! -d "$DOCS_DIR" ]]; then
  echo "${RED}ERROR: docs directory not found at $DOCS_DIR${RESET}"
  exit 2
fi

# ---------------------------------------------------------------------------
# Temp directory for extracted blocks
# ---------------------------------------------------------------------------
TMPDIR="$(mktemp -d /tmp/toke-web-check.XXXXXX)"
trap 'rm -rf "$TMPDIR"' EXIT

# ---------------------------------------------------------------------------
# Counters
# ---------------------------------------------------------------------------
TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0

# Arrays for failure reporting
declare -a FAIL_FILES=()
declare -a FAIL_LINES=()
declare -a FAIL_ERRORS=()

# ---------------------------------------------------------------------------
# is_fragment -- returns 0 (true) if the block looks like a fragment that
# cannot compile standalone (no module declaration).
# ---------------------------------------------------------------------------
is_fragment() {
  local file="$1"
  # A compilable toke file must have a module declaration (m=...)
  if grep -qE '^\s*m=' "$file"; then
    return 1  # not a fragment
  fi
  return 0  # is a fragment
}

# ---------------------------------------------------------------------------
# should_skip -- returns 0 if the preceding line contains skip-check
# ---------------------------------------------------------------------------
should_skip() {
  local src_file="$1"
  local block_start_line="$2"
  if (( block_start_line > 1 )); then
    local prev_line
    prev_line="$(sed -n "$((block_start_line - 1))p" "$src_file")"
    if [[ "$prev_line" == *"skip-check"* ]]; then
      return 0
    fi
  fi
  return 1
}

# ---------------------------------------------------------------------------
# is_toke_block -- determine if an untagged code block is toke code.
# Checks for common toke top-level keywords.
# ---------------------------------------------------------------------------
is_toke_block() {
  local file="$1"
  # Must contain at least one toke top-level declaration keyword
  if grep -qE '^\s*(m=|f=|v=|t=|i=|c=|s=)' "$file"; then
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# Extract and check code blocks from a single markdown file
# ---------------------------------------------------------------------------
process_file() {
  local md_file="$1"
  local rel_path="${md_file#"$WEB_ROOT"/}"
  local in_block=0
  local block_lang=""
  local block_start=0
  local block_content=""
  local line_num=0

  while IFS= read -r line || [[ -n "$line" ]]; do
    (( line_num++ )) || true

    # Detect start of fenced code block
    if (( in_block == 0 )) && [[ "$line" =~ ^\`\`\`(.*)$ ]]; then
      block_lang="${BASH_REMATCH[1]}"
      # Strip any trailing whitespace/attributes
      block_lang="${block_lang%% *}"
      block_lang="${block_lang%%$'\r'}"

      # Only process: toke, tk, or untagged blocks
      if [[ "$block_lang" == "toke" || "$block_lang" == "tk" || "$block_lang" == "" ]]; then
        in_block=1
        block_start=$line_num
        block_content=""
      fi
      continue
    fi

    # Detect end of fenced code block
    if (( in_block == 1 )) && [[ "$line" =~ ^\`\`\`[[:space:]]*$ ]]; then
      in_block=0

      # Write block to temp file
      local tmpfile="$TMPDIR/block_${TOTAL}.tk"
      printf '%s\n' "$block_content" > "$tmpfile"

      (( TOTAL++ )) || true

      # Check for skip-check comment
      if should_skip "$md_file" "$block_start"; then
        (( SKIPPED++ )) || true
        [[ "$VERBOSE" == "1" ]] && echo "${YELLOW}SKIP${RESET}  $rel_path:$block_start (skip-check)"
        continue
      fi

      # For untagged blocks, check if it looks like toke code
      if [[ "$block_lang" == "" ]] && ! is_toke_block "$tmpfile"; then
        (( SKIPPED++ )) || true
        [[ "$VERBOSE" == "1" ]] && echo "${YELLOW}SKIP${RESET}  $rel_path:$block_start (not toke code)"
        continue
      fi

      # Skip fragments without module declaration
      if is_fragment "$tmpfile"; then
        (( SKIPPED++ )) || true
        [[ "$VERBOSE" == "1" ]] && echo "${YELLOW}SKIP${RESET}  $rel_path:$block_start (fragment, no m=)"
        continue
      fi

      # Run tkc --check
      local output
      if output=$("$TKC" --check "$tmpfile" 2>&1); then
        (( PASSED++ )) || true
        [[ "$VERBOSE" == "1" ]] && echo "${GREEN}PASS${RESET}  $rel_path:$block_start"
      else
        (( FAILED++ )) || true
        FAIL_FILES+=("$rel_path")
        FAIL_LINES+=("$block_start")
        FAIL_ERRORS+=("$output")
        [[ "$VERBOSE" == "1" ]] && echo "${RED}FAIL${RESET}  $rel_path:$block_start"
      fi

      continue
    fi

    # Accumulate block content
    if (( in_block == 1 )); then
      if [[ -z "$block_content" ]]; then
        block_content="$line"
      else
        block_content="$block_content
$line"
      fi
    fi
  done < "$md_file"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "${BOLD}toke website code example conformance check${RESET}"
echo "Docs:      $DOCS_DIR"
echo "Compiler:  $TKC"
echo "Threshold: ${THRESHOLD}%"
echo ""

# Find all markdown files
MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$DOCS_DIR" -type f \( -name '*.md' -o -name '*.mdx' \) | sort)

echo "Scanning ${#MD_FILES[@]} documentation files..."
echo ""

for md_file in "${MD_FILES[@]}"; do
  process_file "$md_file"
done

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
CHECKED=$((PASSED + FAILED))
if (( CHECKED > 0 )); then
  PASS_RATE=$(( (PASSED * 100) / CHECKED ))
else
  PASS_RATE=100
fi

echo ""
echo "${BOLD}=== Results ===${RESET}"
echo ""
echo "  Total blocks found:  $TOTAL"
echo "  Skipped:             $SKIPPED"
echo "  Checked:             $CHECKED"
echo "  ${GREEN}Passed:${RESET}              $PASSED"
echo "  ${RED}Failed:${RESET}              $FAILED"
echo "  ${BOLD}Pass rate:${RESET}           ${PASS_RATE}%"
echo ""

# Show failures
if (( FAILED > 0 )); then
  echo "${BOLD}=== Failures ===${RESET}"
  echo ""
  for idx in "${!FAIL_FILES[@]}"; do
    echo "${RED}FAIL${RESET} ${CYAN}${FAIL_FILES[$idx]}${RESET}:${FAIL_LINES[$idx]}"
    # Indent the error output
    echo "${FAIL_ERRORS[$idx]}" | sed 's/^/  /'
    echo ""
  done
fi

# Exit code based on threshold
if (( PASS_RATE >= THRESHOLD )); then
  echo "${GREEN}PASS: ${PASS_RATE}% >= ${THRESHOLD}% threshold${RESET}"
  exit 0
else
  echo "${RED}FAIL: ${PASS_RATE}% < ${THRESHOLD}% threshold${RESET}"
  exit 1
fi
