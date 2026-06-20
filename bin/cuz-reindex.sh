#!/usr/bin/env bash
# Refresh the cuz QMD index over your library/ — run after a distill writes new
# facts/skills so cross-project search stays current. Cheap no-op if nothing
# changed. The index ($CUZ_INDEX, default "cuz") is registered by `cuz init` to
# point at $CUZ_HOME/library, separate from any per-project default index.
#     qmd --index cuz search "..."   /   qmd --index cuz query "..."
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"

out=$(qmd --index "$CUZ_INDEX" update 2>&1) || { echo "$out"; exit 0; }
if printf '%s' "$out" | grep -q 'need vectors'; then
  qmd --index "$CUZ_INDEX" embed >/dev/null 2>&1 || true
fi
echo "cuz index refreshed"
