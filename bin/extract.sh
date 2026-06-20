#!/usr/bin/env bash
# Extract durable knowledge from one transcript.
# Usage: extract.sh <transcript.jsonl> [tail_chars] [since_line]
# Prints clean inbox lines (or nothing). Instruction goes AFTER the transcript
# so it stays salient on long inputs — burying it at the top makes the model
# continue the conversation instead of extracting.
#
# Model: $CUZ_MODEL (default haiku — cheap; set to a Sonnet id for higher recall).
# Every call is metered into $CUZ_CACHE/usage-ledger.jsonl (cost + tokens),
# which the sweep reads to enforce the daily budget.
# The extraction PROMPT lives in your brain ($CUZ_HOME/prompts/extract.md) so it
# carries your identity/context — the engine ships only a generic template.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"
export CUZ_EXTRACTING=1   # marks the extraction's own claude -p session so the capture hook skips it
MODEL="${CUZ_MODEL:-claude-haiku-4-5-20251001}"
LEDGER="$CUZ_CACHE/usage-ledger.jsonl"
mkdir -p "$CUZ_CACHE"

T="$1"; TAIL="${2:-120000}"; SINCE="${3:-0}"
PROMPT="$CUZ_HOME/prompts/extract.md"

BODY=$(python3 "$HERE/transcript_to_text.py" "$T" --tail-chars "$TAIL" --since-line "$SINCE")
[ -z "$BODY" ] && exit 0

RAW=$({
  echo "TRANSCRIPT OF ONE CLAUDE CODE SESSION (between ===BEGIN/===END):"
  echo "===BEGIN"
  echo "$BODY"
  echo "===END"
  echo
  cat "$PROMPT"
} | command claude -p --model "$MODEL" --output-format json 2>/dev/null) || exit 0

# Parse result text + usage; meter to the ledger; emit only the tagged lines.
printf '%s' "$RAW" | LEDGER="$LEDGER" TODAY="$(date '+%Y-%m-%d')" MODEL="$MODEL" python3 -c "
import json, os, sys, re
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
u = d.get('usage', {}) or {}
tokens = (u.get('input_tokens',0) + u.get('output_tokens',0)
          + u.get('cache_creation_input_tokens',0) + u.get('cache_read_input_tokens',0))
rec = {'date': os.environ['TODAY'], 'model': os.environ['MODEL'],
       'cost_usd': d.get('total_cost_usd', 0), 'tokens': tokens}
with open(os.environ['LEDGER'], 'a') as f:
    f.write(json.dumps(rec) + '\n')
for line in (d.get('result','') or '').splitlines():
    if re.match(r'^#(procedure|fact|pattern|decision) \|', line):
        print(line)
"
