# legacy — deprecated per-event capture (reference only)

The original capture design: `SessionEnd` + `PreCompact` hooks installed into
every `~/.claude*` config dir, each firing a `claude -p` extraction the moment a
session ended or compacted.

**Why it was retired:** it over-fired (hundreds of times in minutes during normal
use), self-triggered (the extraction's own `claude -p` session fired the hook
again), and competed with real-work quota because it ran *during* active sessions.
It was also unnecessary — transcripts retain their full `.jsonl` history through
compaction, so there's nothing to rescue before a compaction.

Replaced by the opportunistic hourly sweep (`bin/cuz-sweep.sh`), which spends only
when there's headroom (daily cap, yields to active work, overnight-biased).

These files are kept for reference / opt-in:
- `cuz-capture.sh` — hook entrypoint (parses payload, detaches a worker)
- `cuz-extract-worker.sh` — backgrounded per-session extractor
- `install-hooks.sh` — installs/removes the hooks across all config dirs
  (`--uninstall` cleans up if any stale hooks reappear)

If you genuinely want event-driven capture, run `legacy/install-hooks.sh`. The
recommended path is the sweep, installed via `cuz schedule install`.
