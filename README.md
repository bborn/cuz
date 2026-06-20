# cuz

**A two-speed memory layer for your AI coding sessions.** Capture is dumb, cheap,
and automatic; distill is smart, precise, and human-in-the-loop. The result is a
small library of durable facts and skills that you *own* — plain markdown in git,
not a junk drawer in someone's database.

```
  hourly sweep (automatic, frugal)            you (occasionally)
        │                                          │
  bin/cuz-sweep.sh                            /cuz-distill
        │  scans Claude transcripts                │  cluster + dedupe + cull
        │  touched since last run                  │  → skill / memory / drop / keep
        ▼                                          ▼  (auto-applies; flags hard calls)
   INBOX.md  ───────────────────────────────►  library/   (memory + skills)
   raw, high-recall buffer                      processed/  (archive of everything)
```

**Capture over-collects on purpose; distill culls.** That asymmetry is the whole
idea — the unattended sweep never authors a skill, it only fills the inbox. The
precision happens later, with you in the loop, and it's all git-tracked so any
write is one revert away.

## Is this just another AI memory tool?

Honest answer: the *store-and-retrieve* part is commoditized (mem0, Zep, and the
model vendors' own native memory all do it), and Obsidian is a better tool if you
want a **human** note-taking app. cuz is opinionated about three things those
don't emphasize:

1. **Distill discipline.** Most auto-memory greedily extracts and accretes junk.
   cuz over-collects cheaply, then *aggressively culls* to a small owned library.
2. **Skills as output.** A procedure that recurs gets promoted into an
   auto-loading `SKILL.md`, not just stored as a fact.
3. **File-first & forkable.** Markdown + git history, runtime-agnostic, no DB
   lock-in. Your brain is a private repo you control.

If you want a sprawling searchable log of everything, use something else. cuz is
for keeping a *tight* one.

## Two repos by design

- **This repo (the engine)** — code only. Identical for everyone. Contains no
  knowledge.
- **Your brain** — a separate, **private** repo (`library/`, `processed/`,
  `INBOX.md`) created by `cuz init`. This is where your facts live. Never commit a
  brain into the engine; `.gitignore` guards against it.

The engine finds your brain through one variable, `CUZ_HOME`, set in
`~/.config/cuz/config`. Think Hugo (engine) + your content repo, or Obsidian (app)
+ your vault.

## Quick start

```bash
git clone https://github.com/you/cuz && cd cuz
ln -s "$PWD/bin/cuz" /usr/local/bin/cuz          # or add bin/ to PATH

cuz init ~/cuz-brain --name "Your Name" \
  --context "what you work on — companies, products, stack"

cuz schedule install                              # hourly capture + weekly propose (macOS launchd)
ln -s "$PWD/cuz-distill" ~/.claude/skills/cuz-distill   # install the distill skill
```

Then just work. Capture fills `~/cuz-brain/INBOX.md` automatically. When it's
grown, run `/cuz-distill` inside Claude Code to fold it into your library.

**Requirements:** the `claude` CLI (Claude Code), Python 3, and
[`qmd`](https://github.com/) for search. macOS for the bundled launchd agents
(Linux: run `bin/cuz-sweep.sh` hourly and `bin/cuz-distill-prepare.sh` weekly from
cron — the scripts are portable).

## Spends only when there's headroom

The sweep runs hourly but is frugal by design (all overridable via env / the
plist):

- **Daily USD cap** (`CUZ_DAILY_USD`, default $1.50), enforced from a usage ledger.
- **Yields to active work** — if you used a session in the last 15 min, it skips.
- **Overnight-biased** — more extractions at night, few by day.
- **Skips trivial sessions**, never re-extracts one (per-session watermarks).
- **Haiku by default** (~cents/session); set `CUZ_MODEL` to Sonnet for more recall.

## Consuming the library

Distilling is pointless if nothing reads it back. Two paths:

- **Facts** are searchable via a dedicated `qmd` index:
  ```bash
  cuz search "deploy staging"        # keyword (BM25)
  cuz query  "how do we handle oauth on ios"   # hybrid + rerank
  ```
- **Skills** distilled into a project's `.claude/skills/` load automatically the
  next time that skill's triggers match.

## Commands

```
cuz init <dir>     scaffold a brain + wire it up
cuz sweep          run one capture sweep now
cuz prepare        run the weekly distill-prepare now (writes a proposal)
cuz reindex        refresh the search index
cuz search/query   search your library
cuz schedule ...   install | uninstall | status the background agents
cuz status         agents loaded? today's spend, latest proposal
```

## Layout

```
bin/            the engine (sweep, extract, prepare, reindex, init, dispatcher)
cuz-distill/    the human-in-the-loop distill skill (/cuz-distill)
schedule/       launchd templates + manager
legacy/         the retired per-event hook approach (opt-in)
templates/      what `cuz init` copies into a new brain
```

## A caveat worth stating

cuz's automatic capture can snapshot an agent's *wrong* belief from mid-session —
and the distill pass can propagate it into your library if you're not careful.
That's exactly why distill is human-in-the-loop and why the skill is told to treat
a captured "correction" of an existing fact as a hard call. Memory that maintains
itself is powerful and occasionally confidently wrong; the curation step is the
point, not an afterthought.

## License

MIT — see [LICENSE](LICENSE).
