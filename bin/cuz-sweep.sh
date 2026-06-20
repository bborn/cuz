#!/usr/bin/env bash
# cuz opportunistic sweep. Runs hourly (launchd/cron). Extracts knowledge from
# transcripts touched since the last sweep — but only when there's headroom:
#
#   • Daily cost cap (ledger-enforced) — hard backstop.
#   • Time-of-day — generous overnight (cheap/idle), stingy during the day.
#   • Yield to active work — if you've used a Claude session in the last
#     ~15 min, skip this run entirely (don't compete for your quota).
#   • Per-run cap + re-check budget after every extraction.
#
# Everything is overridable via env. Defaults are conservative.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"

INBOX="$CUZ_HOME/INBOX.md"
CACHE="$CUZ_CACHE"; WM_DIR="$CACHE/wm"
LEDGER="$CACHE/usage-ledger.jsonl"; LOG="$CACHE/sweep.log"
LAST="$CACHE/.last-sweep"
mkdir -p "$WM_DIR"; : >> "$LEDGER"

DAILY_USD="${CUZ_DAILY_USD:-1.50}"               # don't spend more than this/day
MIN_DELTA_CHARS="${CUZ_MIN_DELTA_CHARS:-3000}"   # skip trivial sessions
ACTIVE_WINDOW_MIN="${CUZ_ACTIVE_WINDOW_MIN:-15}" # "you're working" if activity within this
export CUZ_MODEL="${CUZ_MODEL:-claude-haiku-4-5-20251001}"
HOUR=$(date '+%H'); HOUR=${HOUR#0}
case "$HOUR" in
  1|2|3|4|5|6) MAX_PER_RUN="${CUZ_MAX_OVERNIGHT:-25}"; OVERNIGHT=1 ;;
  *)           MAX_PER_RUN="${CUZ_MAX_DAYTIME:-6}";   OVERNIGHT=0 ;;
esac
log() { printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M')" "$*" >> "$LOG"; }

# --- budget gate -----------------------------------------------------------
spent_today() {
  TODAY="$(date '+%Y-%m-%d')" LEDGER="$LEDGER" python3 -c "
import json,os
t=os.environ['TODAY']; s=0.0
try:
    for line in open(os.environ['LEDGER']):
        try: r=json.loads(line)
        except: continue
        if r.get('date')==t: s+=r.get('cost_usd',0) or 0
except FileNotFoundError: pass
print(round(s,4))"
}
spent=$(spent_today)
if python3 -c "import sys; sys.exit(0 if float('$spent')>=float('$DAILY_USD') else 1)"; then
  log "budget spent today (\$$spent >= \$$DAILY_USD) — skip"; exit 0
fi

# --- yield to active work (daytime only) -----------------------------------
recent_activity() {
  # NB: capture to a var — `| grep -q` + pipefail misreports SIGPIPE as failure.
  local hits
  hits=$(find "$HOME"/.claude*/projects -name '*.jsonl' -type f \
         -mmin -"$ACTIVE_WINDOW_MIN" 2>/dev/null | head -1)
  [ -n "$hits" ] && echo yes || echo no
}
if [ "$OVERNIGHT" -eq 0 ] && [ "$(recent_activity)" = yes ]; then
  log "active session within ${ACTIVE_WINDOW_MIN}m and daytime — yield, skip"; exit 0
fi

# --- find candidate transcripts touched since last sweep -------------------
if [ -f "$LAST" ]; then
  candidates=$(find "$HOME"/.claude*/projects -name '*.jsonl' -type f -newer "$LAST" 2>/dev/null | sort -u)
else
  candidates=$(find "$HOME"/.claude*/projects -name '*.jsonl' -type f 2>/dev/null | sort -u)
fi
[ -z "$candidates" ] && { log "nothing new since last sweep"; touch "$LAST"; exit 0; }

count=0; wrote=0
while IFS= read -r T; do
  [ -n "$T" ] || continue
  # Only sweep INTERACTIVE sessions. Headless runs (cron automations, SDK/`-p`
  # jobs, agent daemon tasks) carry entrypoint != "cli" and only ever re-derive
  # their own runbooks — pure inbox noise. Absent field → keep (old transcripts
  # predate the stamp; don't silently drop them).
  ep=$(grep -om1 '"entrypoint":"[^"]*"' "$T" | cut -d'"' -f4)
  if [ -n "$ep" ] && [ "$ep" != "cli" ]; then continue; fi
  [ "$count" -ge "$MAX_PER_RUN" ] && { log "hit per-run cap ($MAX_PER_RUN)"; break; }
  # budget re-check after each extraction
  spent=$(spent_today)
  if python3 -c "import sys; sys.exit(0 if float('$spent')>=float('$DAILY_USD') else 1)"; then
    log "budget reached mid-run (\$$spent) — stop"; break
  fi

  sid=$(basename "$T" .jsonl)
  wm="$WM_DIR/$sid"; last_line=$(cat "$wm" 2>/dev/null || echo 0)
  total_line=$(wc -l < "$T" | tr -d ' ')
  [ "$total_line" -le "$last_line" ] && continue

  # measure new content; skip (and advance) trivial sessions
  delta_chars=$(python3 "$HERE/transcript_to_text.py" "$T" --since-line "$last_line" | wc -c | tr -d ' ')
  if [ "$delta_chars" -lt "$MIN_DELTA_CHARS" ]; then
    echo "$total_line" > "$wm"; continue
  fi

  count=$((count+1))
  # Human-readable project label from the encoded transcript dir
  # (e.g. -Users-jane-Projects-acme-web → acme-web).
  proj=$(basename "$(dirname "$(dirname "$T")")" | sed -E 's/^-(Users|home)-[^-]+-(Projects-)?//')
  out=$(bash "$HERE/extract.sh" "$T" 80000 "$last_line" 2>/dev/null) || true
  echo "$total_line" > "$wm"
  [ -z "$out" ] && continue
  {
    echo
    echo "<!-- $(date '+%Y-%m-%d %H:%M') · $proj · ${sid:0:8} · sweep -->"
    echo "$out"
  } >> "$INBOX"
  wrote=$((wrote+1))
done <<< "$candidates"

touch "$LAST"
log "swept: $count extracted, $wrote with content, \$$(spent_today) spent today (cap \$$DAILY_USD, $([ $OVERNIGHT -eq 1 ] && echo overnight || echo daytime))"
