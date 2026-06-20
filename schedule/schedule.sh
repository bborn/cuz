#!/usr/bin/env bash
# Manage the cuz launchd agents (macOS):
#   com.cuz.sweep    — hourly capture (fills the inbox)
#   com.cuz.distill  — weekly prepare (writes a proposal to review)
# Plists are rendered from *.plist.template with your engine/cache/config paths.
# Usage: schedule.sh [install|uninstall|status|run|run-distill]
#
# On Linux (no launchd), run bin/cuz-sweep.sh hourly and bin/cuz-distill-prepare.sh
# weekly from cron instead — the scripts themselves are portable.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ENGINE="$(cd "$HERE/.." && pwd)"
. "$ENGINE/bin/_cuz-env.sh"   # resolves CUZ_CACHE/CUZ_CONFIG; fails early if no CUZ_HOME
LA="$HOME/Library/LaunchAgents"
AGENTS=(com.cuz.sweep com.cuz.distill)

render() {  # $1=label → stdout
  sed -e "s|__BASH__|/bin/bash|g" \
      -e "s|__ENGINE__|$ENGINE|g" \
      -e "s|__CACHE__|$CUZ_CACHE|g" \
      -e "s|__CONFIG__|$CUZ_CONFIG|g" \
      "$HERE/$1.plist.template"
}

case "${1:-status}" in
  install)
    mkdir -p "$LA" "$CUZ_CACHE"
    for a in "${AGENTS[@]}"; do
      render "$a" > "$LA/$a.plist"
      launchctl unload "$LA/$a.plist" 2>/dev/null || true
      launchctl load "$LA/$a.plist"
    done
    echo "installed + loaded:"; launchctl list | grep cuz || echo "  (none)"
    ;;
  uninstall)
    for a in "${AGENTS[@]}"; do
      launchctl unload "$LA/$a.plist" 2>/dev/null || true
      rm -f "$LA/$a.plist"
    done
    echo "unloaded + removed (capture + distill paused)"
    ;;
  run)         bash "$ENGINE/bin/cuz-sweep.sh"; tail -1 "$CUZ_CACHE/sweep.log" 2>/dev/null ;;
  run-distill) bash "$ENGINE/bin/cuz-distill-prepare.sh"; tail -1 "$CUZ_CACHE/distill.log" 2>/dev/null ;;
  status)
    launchctl list | grep cuz || echo "no agents loaded"
    LEDGER="$CUZ_CACHE/usage-ledger.jsonl" python3 - <<'PY'
import json,datetime,os
t=datetime.date.today().isoformat(); s=0.0
p=os.environ["LEDGER"]
try:
    for l in open(p):
        try:
            r=json.loads(l)
            if r.get("date")==t: s+=r.get("cost_usd",0) or 0
        except: pass
except FileNotFoundError: pass
print(f"today's spend: ${round(s,4)}")
PY
    ls -t "$CUZ_HOME/proposals"/*.md 2>/dev/null | head -1 | sed 's/^/latest proposal: /' || true
    ;;
  *) echo "usage: schedule.sh [install|uninstall|status|run|run-distill]"; exit 1 ;;
esac
