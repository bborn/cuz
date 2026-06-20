#!/usr/bin/env bash
# Weekly PREPARE pass (scheduled). Reads the capture inbox and writes a distill
# PROPOSAL to $CUZ_HOME/proposals/<date>.md — then leaves it for you. It NEVER
# writes the library or trims the inbox; that only happens later via the
# /cuz-distill skill, with your approval. Read-only except the proposal file +
# the usage ledger.
# The propose PROMPT lives in your brain ($CUZ_HOME/prompts/distill-propose.md).
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"
export CUZ_EXTRACTING=1

INBOX="$CUZ_HOME/INBOX.md"
PROPOSALS="$CUZ_HOME/proposals"
PROMPT="$CUZ_HOME/prompts/distill-propose.md"
CACHE="$CUZ_CACHE"; LEDGER="$CACHE/usage-ledger.jsonl"; LOG="$CACHE/distill.log"
mkdir -p "$PROPOSALS" "$CACHE"; : >> "$LEDGER"
MODEL="${CUZ_DISTILL_MODEL:-claude-sonnet-4-6}"   # distill is the smart layer
DISTILL_USD="${CUZ_DISTILL_USD:-2.00}"            # distill's OWN cap, decoupled
                                                  # from the sweep's daily budget
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M')" "$*" >> "$LOG"; }

# budget gate — count ONLY prior distill spend today, NOT the sweep's. Distill
# runs weekly and is the high-value step; it must never be starved by the hourly
# sweep draining a shared daily cap.
spent=$(TODAY="$(date '+%Y-%m-%d')" LEDGER="$LEDGER" python3 -c "
import json,os; t=os.environ['TODAY']; s=0.0
try:
  for l in open(os.environ['LEDGER']):
    try: r=json.loads(l)
    except: continue
    if r.get('date')==t and r.get('kind')=='distill': s+=r.get('cost_usd',0) or 0
except FileNotFoundError: pass
print(round(s,4))")
if python3 -c "import sys;sys.exit(0 if float('$spent')>=float('$DISTILL_USD') else 1)"; then
  log "distill budget spent (\$$spent) — skip prepare"; exit 0
fi

# inbox entries live below the first '---'; bail if there are none
BODY=$(INBOX="$INBOX" python3 -c "
import os; s=open(os.environ['INBOX']).read().split('\n---\n',1)
print(s[1].strip() if len(s)>1 else '')")
if [ -z "$BODY" ]; then log "inbox empty — nothing to prepare"; exit 0; fi

RAW=$({ echo "$BODY"; echo; echo "---"; echo; cat "$PROMPT"; } \
  | command claude -p --model "$MODEL" --output-format json 2>/dev/null) || { log "claude failed"; exit 0; }

OUT="$PROPOSALS/$(date '+%Y-%m-%d-%H%M').md"
printf '%s' "$RAW" | LEDGER="$LEDGER" TODAY="$(date '+%Y-%m-%d')" MODEL="$MODEL" OUT="$OUT" python3 -c "
import json,os,sys
try: d=json.load(sys.stdin)
except Exception: sys.exit(0)
u=d.get('usage',{}) or {}
tok=sum(u.get(k,0) for k in ('input_tokens','output_tokens','cache_creation_input_tokens','cache_read_input_tokens'))
open(os.environ['LEDGER'],'a').write(json.dumps({'date':os.environ['TODAY'],'model':os.environ['MODEL'],'cost_usd':d.get('total_cost_usd',0),'tokens':tok,'kind':'distill'})+'\n')
text=d.get('result','') or ''
if text.strip(): open(os.environ['OUT'],'w').write(text)
"
if [ -s "$OUT" ]; then
  log "proposal written: $OUT"
  # No push notification — you're reminded at session start by cuz-pending-check.sh.
else
  log "no proposal produced"; rm -f "$OUT" 2>/dev/null
fi
