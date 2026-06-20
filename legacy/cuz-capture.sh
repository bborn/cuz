#!/usr/bin/env bash
# DEPRECATED per-event capture hook (see legacy/README.md). Kept for reference.
# Wired as SessionEnd + PreCompact; reads the hook JSON payload from stdin, then
# detaches a background worker to extract knowledge. Returns immediately.
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../bin/_cuz-env.sh"
ENGINE="$(cd "$HERE/.." && pwd)"
CACHE="$CUZ_CACHE"; mkdir -p "$CACHE"

# Don't capture the extraction's own claude -p session (self-amplification).
[ -n "${CUZ_EXTRACTING:-}" ] && exit 0

payload_file=$(mktemp "$CACHE/payload.XXXXXX")
cat > "$payload_file"

{
  read -r TRANSCRIPT
  read -r SID
  read -r CWD
  read -r EVENT
} < <(python3 - "$payload_file" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    d = {}
print(d.get("transcript_path", ""))
print(d.get("session_id", ""))
print(d.get("cwd", ""))
print(d.get("hook_event_name", ""))
PY
)
rm -f "$payload_file"
[ -n "$TRANSCRIPT" ] || exit 0
# Skip sessions inside the brain or the engine itself (meta-noise).
case "$CWD" in "$CUZ_HOME"*|"$ENGINE"*) exit 0 ;; esac

nohup "$ENGINE/legacy/cuz-extract-worker.sh" "$TRANSCRIPT" "$SID" "$CWD" "$EVENT" \
  >/dev/null 2>>"$CACHE/capture.log" &
exit 0
