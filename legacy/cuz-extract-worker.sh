#!/usr/bin/env bash
# DEPRECATED detached worker (see legacy/README.md). Extracts knowledge from the
# new tail of one transcript and appends it to the inbox. Backgrounded by
# cuz-capture.sh so it never blocks session end or compaction.
# Args: <transcript_path> <session_id> <cwd> <event_name>
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../bin/_cuz-env.sh"
ENGINE="$(cd "$HERE/.." && pwd)"
INBOX="$CUZ_HOME/INBOX.md"
CACHE="$CUZ_CACHE"; WM_DIR="$CACHE/wm"; LOG="$CACHE/capture.log"
mkdir -p "$WM_DIR"

TRANSCRIPT="$1"; SID="$2"; CWD="$3"; EVENT="$4"
stamp() { date '+%Y-%m-%d %H:%M:%S'; }
[ -f "$TRANSCRIPT" ] || exit 0
[ -n "$SID" ] || exit 0

# One worker per session at a time (portable lock — no flock on macOS).
LOCK="$CACHE/lock-$SID"
mkdir "$LOCK" 2>/dev/null || exit 0
trap 'rmdir "$LOCK" 2>/dev/null' EXIT

WM="$WM_DIR/$SID"
last=$(cat "$WM" 2>/dev/null || echo 0)
total=$(wc -l < "$TRANSCRIPT" | tr -d ' ')
[ "$total" -le "$last" ] && exit 0

out=$("$ENGINE/bin/extract.sh" "$TRANSCRIPT" 80000 "$last" 2>>"$LOG") || true
echo "$total" > "$WM"   # advance watermark even if empty — that tail is judged

[ -z "$out" ] && { printf '%s  %s %s -> nothing\n' "$(stamp)" "$(basename "$CWD")" "${SID:0:8}" >>"$LOG"; exit 0; }

proj=$(basename "$CWD")
{
  echo
  echo "<!-- $(date '+%Y-%m-%d %H:%M') · $proj · ${SID:0:8} · $EVENT -->"
  echo "$out"
} >> "$INBOX"
printf '%s  %s %s -> %d lines\n' "$(stamp)" "$proj" "${SID:0:8}" "$(printf '%s\n' "$out" | grep -c '^#')" >>"$LOG"
