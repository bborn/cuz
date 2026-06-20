#!/usr/bin/env bash
# Claude Code SessionStart hook: if a cuz distill proposal is waiting
# (unapplied), remind you to run /cuz-distill. Reliability properties:
#
#   1. Skips headless automation runs. A midnight bot (cron/-p/SDK/daemon) must
#      not burn the once-per-day reminder mark before you open an interactive
#      session. Keyed on CLAUDE_CODE_ENTRYPOINT (interactive=cli), with a
#      process-tree fallback when the var is absent.
#   2. Delivers via a real macOS notification (terminal-notifier) when available,
#      plus a backup injected line for the model to surface in-session.
#   3. "Pending" = a bare YYYY-MM-DD-HHMM.md; once handled it gets a status
#      suffix (.applied.md / .superseded.md / ...), so it stops nagging.
#
# Capped to once per day. Silent when nothing is pending.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"
CACHE="$CUZ_CACHE"; mkdir -p "$CACHE"
MARK="$CACHE/.reminded-$(date '+%Y-%m-%d')"

# Newest pending proposal: filename is exactly a timestamp, no status suffix.
pending=$(ls -t "$CUZ_HOME/proposals/"*.md 2>/dev/null \
  | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}\.md$' | head -1)
[ -z "$pending" ] && exit 0

# Fallback when CLAUDE_CODE_ENTRYPOINT is absent: walk up from this hook's
# parent to the claude process; a `-p`/`--print` ancestor means a headless bot.
is_headless() {
  local pid="$PPID" depth=0 cmd
  while [ -n "$pid" ] && [ "$pid" -gt 1 ] && [ "$depth" -lt 6 ]; do
    cmd=$(ps -o command= -p "$pid" 2>/dev/null)
    case " $cmd " in
      *" -p "*|*" --print "*) return 0 ;;   # headless claude
    esac
    case "$cmd" in
      *claude*) return 1 ;;                  # interactive claude
    esac
    pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    depth=$((depth + 1))
  done
  return 1
}

# Headless runs have no human to remind and must NOT consume the daily mark.
case "${CLAUDE_CODE_ENTRYPOINT:-}" in
  cli) : ;;                       # interactive CLI — proceed
  "")  is_headless && exit 0 ;;   # unknown — fall back to process-tree check
  *)   exit 0 ;;                  # sdk-cli / other headless entrypoint
esac

[ -f "$MARK" ] && exit 0   # already reminded an interactive session today
touch "$MARK"
name=$(basename "$pending")

# Real notification so it reaches you independent of model relay.
if command -v terminal-notifier >/dev/null 2>&1; then
  terminal-notifier \
    -title "cuz: distill proposal pending" \
    -subtitle "$name" \
    -message "Run /cuz-distill to fold it into your library." \
    -group cuz-distill >/dev/null 2>&1 || true
fi

# Backup channel: inject a line for the model to surface in-session.
echo "[cuz] A distill proposal is waiting for review: $name. At the start of this session, tell the user plainly: \"📋 You have a cuz distill proposal pending — run /cuz-distill whenever you want to fold it into your library.\" Mention it once, briefly; don't belabor it."
exit 0
