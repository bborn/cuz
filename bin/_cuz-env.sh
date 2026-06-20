#!/usr/bin/env bash
# Shared environment for every cuz engine script. Source this near the top:
#     HERE="$(cd "$(dirname "$0")" && pwd)"; . "$HERE/_cuz-env.sh"
#
# It resolves WHERE your brain lives (CUZ_HOME) and the cache/index names, and
# fixes PATH for the tools the engine shells out to (claude, qmd, mise shims).
#
# Resolution order for CUZ_HOME: explicit env var > $CUZ_CONFIG file >
# ~/.config/cuz/config. The engine code is generic; everything personal lives in
# your brain (CUZ_HOME) and your config — never in this repo.
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

: "${CUZ_CONFIG:=$HOME/.config/cuz/config}"
# shellcheck disable=SC1090
[ -f "$CUZ_CONFIG" ] && . "$CUZ_CONFIG"

: "${CUZ_CACHE:=$HOME/.cache/cuz}"   # logs, watermarks, usage ledger, locks
: "${CUZ_INDEX:=cuz}"                # qmd index name (reads ~/.config/qmd/$CUZ_INDEX.yml)

if [ -z "${CUZ_HOME:-}" ]; then
  echo "cuz: CUZ_HOME is not set. Run 'cuz init <dir>' or set it in $CUZ_CONFIG." >&2
  exit 1
fi
export CUZ_HOME CUZ_CACHE CUZ_INDEX
