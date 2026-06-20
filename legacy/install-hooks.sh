#!/usr/bin/env bash
# DEPRECATED (see legacy/README.md). Installs the per-event capture hook
# (SessionEnd + PreCompact) into every Claude config dir, merging into existing
# settings.json without clobbering. Idempotent. --dry-run previews, --uninstall
# removes. The modern path is the hourly sweep (bin/cuz-sweep.sh); use this only
# if you deliberately want event-driven capture.
set -euo pipefail
MODE="${1:-install}"
HERE="$(cd "$(dirname "$0")" && pwd)"
CMD="bash \"$HERE/cuz-capture.sh\""

python3 - "$MODE" "$CMD" <<'PY'
import json, os, sys, glob

mode, cmd = sys.argv[1].lstrip("-"), sys.argv[2]   # accept --uninstall / --dry-run / install
home = os.path.expanduser("~")
EVENTS = ["SessionEnd", "PreCompact"]

candidates = [home + "/.claude"] + sorted(glob.glob(home + "/.claude-*"))
targets = []
for d in candidates:
    if not os.path.isdir(d) or d.endswith(".lock"):
        continue
    if os.path.exists(d + "/settings.json") or os.path.isdir(d + "/projects"):
        targets.append(d)

def load(p):
    if not os.path.exists(p):
        return {}
    try:
        return json.load(open(p))
    except Exception:
        return {}

def has_cmd(groups):
    return any(h.get("command") == cmd for g in groups for h in g.get("hooks", []))

for d in targets:
    sp = d + "/settings.json"
    data = load(sp)
    hooks = data.setdefault("hooks", {})
    changed = False
    for ev in EVENTS:
        groups = hooks.setdefault(ev, [])
        present = has_cmd(groups)
        if mode == "uninstall":
            if present:
                for g in groups:
                    g["hooks"] = [h for h in g.get("hooks", []) if h.get("command") != cmd]
                hooks[ev] = [g for g in groups if g.get("hooks")]
                changed = True
        else:
            if not present:
                groups.append({"hooks": [{"type": "command", "command": cmd, "timeout": 15}]})
                changed = True
    action = "skip (already)" if not changed else ("REMOVE" if mode == "uninstall" else "ADD")
    name = os.path.basename(d)
    if mode == "dry-run":
        print(f"  [dry] {name:32s} would {'skip' if not changed else 'add'}")
        continue
    if changed:
        os.makedirs(d, exist_ok=True)
        json.dump(data, open(sp, "w"), indent=2)
    print(f"  {name:32s} {action}")

print(f"\n{len(targets)} config dirs targeted.")
PY
