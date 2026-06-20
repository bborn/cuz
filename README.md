# cuz

Every AI coding session starts from zero. You re-explain your stack, your
conventions, the gotcha that bit you last week — and the next session knows none
of it. Across a dozen projects, you burn real time re-teaching agents things you
already taught them.

cuz makes sessions accumulate. It quietly reads your Claude Code transcripts,
pulls out the durable stuff (facts, decisions, the procedure that finally
worked), and — with you in the loop — distills it into a small library your
future sessions can search and follow. It's plain markdown in a git repo you own.

## How it works

Two speeds, on purpose:

```
  hourly sweep (automatic, frugal)            you (occasionally)
        │                                          │
  cuz-sweep.sh                                /cuz-distill
        │  skims new transcripts                   │  cluster · dedupe · cull
        │  since last run                          │  → skill / memory / drop / keep
        ▼                                          ▼  (auto-applies; asks on hard calls)
   INBOX.md  ───────────────────────────────►  library/   (memory + skills)
   raw, high-recall buffer                      processed/  (archive of everything)
```

**Capture** is dumb and cheap. An hourly job skims new transcripts and dumps
anything that might matter into an inbox. It hoards — recall over precision — and
decides nothing.

**Distill** is the smart pass. You run `/cuz-distill` when the inbox gets heavy;
it clusters the captures, drops the noise, and writes the keepers into `library/`.
It applies the obvious calls itself and only stops to ask on the genuinely
ambiguous ones. It's all in git, so a bad write is one revert away.

The split is the point: the cheap always-on layer gets to be reckless because the
careful layer cleans up after it.

## Watch one fact move through it

Say you spend a session wrestling with a deploy. Next time the sweep runs, that
session lands in your inbox as raw, over-collected lines:

```
<!-- 2026-02-11 14:02 · acme-web · a1b2c3d4 · sweep -->
#fact | acme prod runs on Hatchbox; merging to main does NOT deploy — you have to click Deploy in the Hatchbox UI
#procedure | deploy acme-web: merge to main, open Hatchbox → acme-web → Deploy, watch the log until "Deployed"
#decision | staying on Hatchbox over Kamal for now — the team knows it, the app is small
#fact | the deploy log is at hatchbox.io/apps/acme-web/activity   <- noise, gets dropped
```

A few sessions later the same deploy facts have landed three more times. You run
`/cuz-distill`; it clusters the dupes, drops the noise, and writes the keeper into
`library/memory/acme-web.md`:

```markdown
## Deploy
- **Prod is on Hatchbox and is NOT auto-deployed.** Merging to `main` does nothing
  on its own — click Deploy in the Hatchbox UI and watch the log until it reads
  "Deployed". (Chose Hatchbox over Kamal: small app, team knows it.)
```

Because the *procedure* showed up more than once, distill also promotes it to an
auto-loading skill at `library/skills/deploy-acme/SKILL.md`:

```markdown
---
name: deploy-acme
description: Deploy acme-web to production. Use when asked to deploy, ship, or release acme-web.
---
# Deploy acme-web
1. Merge the PR to `main`.
2. Open Hatchbox → acme-web → Deploy.
3. Watch the deploy log until it reads "Deployed" — merging alone does nothing.
```

Now it pays off. Weeks later, in a fresh session:

```
$ cuz search "how do I ship acme"
qmd://cuz-library/memory/acme-web.md:12   92%
  ## Deploy
  - Prod is on Hatchbox and is NOT auto-deployed. Merging to `main` does nothing…
```

And when you just tell an agent "ship acme-web," the `deploy-acme` skill matches
on its triggers and loads itself — so the agent clicks Deploy and watches the log
instead of merging and declaring victory. The thing you debugged once is now
something every future session already knows.

## Why not just use X?

Fair question.

- **mem0 / Zep / built-in model memory** already do store-and-retrieve. If that's
  all you want, use one of those.
- **Obsidian** is a better notes app — for a *human* reading notes. cuz's reader
  is the agent.

cuz pushes on one thing those don't: keeping a small, owned, *curated* library
instead of an ever-growing pile. Three opinions fall out of that:

1. **Cull hard.** Capture hoards; distill is ruthless. If the library is
   sprawling, it's failing.
2. **Procedures become skills.** A recurring how-to gets promoted to an
   auto-loading `SKILL.md`, not just filed as a fact.
3. **Markdown + git, no database.** Fork it, grep it, diff it. Nothing to lock you
   in.

If you want a searchable log of everything you've ever done, this is the wrong
tool.

## Two repos

The engine is public and identical for everyone. Your knowledge is private and
yours.

- **This repo** — code only. Zero knowledge in it (a `.gitignore` refuses to let a
  brain get committed here).
- **Your brain** — a separate, private repo (`library/`, `processed/`, `INBOX.md`)
  that `cuz init` creates and wires up.

The engine finds your brain through one setting, `CUZ_HOME`. Same shape as Hugo +
your content, or Obsidian + your vault.

## Quick start

```bash
git clone https://github.com/bborn/cuz && cd cuz
ln -s "$PWD/bin/cuz" ~/.local/bin/cuz        # put `cuz` on your PATH

cuz init ~/cuz-brain --name "Your Name" \
  --context "what you work on: companies, products, stack"

cuz schedule install                          # background capture (macOS launchd)
ln -s "$PWD/cuz-distill" ~/.claude/skills/cuz-distill
cuz hooks install                             # nudge you when a proposal is waiting
```

Then just work. The inbox fills on its own. A weekly job drafts a distill proposal
and — thanks to `cuz hooks install` — your next Claude Code session reminds you to
run `/cuz-distill`. (The reminder fires once a day, on interactive sessions only,
and stays silent when nothing's pending.)

**Needs:** the `claude` CLI (Claude Code), Python 3, and `qmd` (a local markdown
search tool) for `cuz search`. The scheduled agents use macOS launchd; on Linux,
run `bin/cuz-sweep.sh` hourly and `bin/cuz-distill-prepare.sh` weekly from cron —
the scripts themselves are portable.

## It only spends when there's room

Capture runs hourly but won't blow your budget or fight you for it:

- Hard daily dollar cap (`CUZ_DAILY_USD`, default $1.50), enforced from a usage
  ledger.
- Skips entirely if you've touched a session in the last 15 minutes.
- Does more overnight, little during the day.
- Ignores trivial sessions; never re-reads one it already processed.
- Runs Haiku by default (cents per session). Point `CUZ_MODEL` at Sonnet for more
  recall.

## Getting it back out

A library nothing reads is useless. Two ways it gets consumed:

```bash
cuz search "deploy staging"                  # keyword
cuz query  "how do we handle oauth on ios"   # hybrid, reranked
```

And **skills** distilled into a project's `.claude/skills/` load themselves the
next time their triggers match — no lookup needed.

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

## It will sometimes be wrong

Worth knowing before you trust it: automatic capture can record something an agent
believed *mid-session*, before you corrected it. If distill isn't careful, that
wrong belief lands in your library and future sessions read it as fact.

Three things keep that in check:

- **Distill has a human in the loop.** It auto-applies the obvious and stops to
  ask on the ambiguous — and it treats a capture that "corrects" an existing fact
  as a flag-for-review, not an auto-apply.
- **One command fixes a bad fact.** `cuz fix` finds the offending line, opens it
  in your editor, and re-indexes the moment you save:
  ```bash
  cuz fix "acme deploys on merge"   # opens library/memory/acme-web.md at that line
  ```
  Deleting a wrong memory is just removing the line; killing a bad skill is
  deleting its file.
- **Everything is git.** Your brain is a repo and every distill is a commit, so a
  whole bad pass is one `git revert` away.

Self-maintaining memory is convenient; it's not a substitute for the review step.

## License

MIT — see [LICENSE](LICENSE).
