---
name: cuz-distill
description: Distill the cuz capture inbox into the owned knowledge library. Reads $CUZ_HOME/INBOX.md (raw, high-recall captures from every Claude session), clusters and de-duplicates the entries, classifies each cluster (→ skill / → memory / → drop / → keep), then writes the library files, archives what was processed, and trims the inbox. Use when the user says "distill", "/cuz-distill", "process the cuz inbox", "what did we capture", or wants to turn captured knowledge into durable skills/memory. This is the smart, precise, human-in-the-loop half of cuz — the capture hooks are the dumb, high-recall half.
---

# cuz-distill — turn the capture inbox into the owned library

You are running the cuz distillation pass. The capture sweep (`bin/cuz-sweep.sh`)
has been dumping raw, high-recall knowledge into the inbox. Most of it is signal,
some is noise, much is duplicated across sessions. **Your job: turn that raw pile
into a small, precise, owned library — auto-applying the obvious and flagging only
the genuine judgment calls.**

You are the precision layer. Capture over-collects on purpose; you cull.

**cuz is meant to be ambient.** The user should not have to babysit a distill run.
Apply the high-confidence dispositions yourself; bring them ONLY the rare hard
call. Never ask a question you can resolve with a sensible default.

## Resolve paths first

Read `~/.config/cuz/config` to get `CUZ_HOME` (the brain). All paths below are
relative to it:

- **Inbox:** `$CUZ_HOME/INBOX.md` (append-only; entries tagged
  `#fact`/`#decision`/`#procedure`/`#pattern`, grouped in stamped batches
  `<!-- date · project · session · event -->`).
- **Library memory:** `$CUZ_HOME/library/memory/<topic>.md`
- **Library skills (portable):** `$CUZ_HOME/library/skills/<name>/SKILL.md`
- **Project-specific skills:** propose into that project's own
  `.claude/skills/<name>/SKILL.md` — a procedure welded to one product belongs
  with that product, not in the shared library.
- **Processed archive:** `$CUZ_HOME/processed/YYYY-MM-DD.md`
- **Engine bin** (for reindex): resolve from the cuz install, or run `cuz reindex`.

## Workflow

### 0. Check for a prepared proposal
The weekly job (`bin/cuz-distill-prepare.sh`) may have written a proposal to
`$CUZ_HOME/proposals/<date>.md`. If the newest one is recent and unapplied,
**start from it** — read it, sanity-check it, then apply it. If there's none, or
the user wants a fresh pass, do step 1 onward yourself.

### 1. Read and parse
Read the inbox. Everything below the first `---` is captured entries. If there's
nothing but the seed header, say the inbox is empty and stop.

### 2. Cluster and de-duplicate
Group entries about the same thing — including near-duplicates captured across
different sessions (the same fact often lands several times). Each cluster becomes
ONE proposed library item, merging the best wording and any extra detail.
**Dedup against what the library already contains** — read the existing target
files; never write a fact that's already there.

### 3. Classify each cluster's disposition

- **→ memory** — a durable fact or decision. Route to a topic file in
  `library/memory/` (group by subject, not by date).
- **→ skill** — a repeatable procedure seen **more than once** or clearly
  reusable. Project-specific → that project's skills dir; portable →
  `library/skills/`. Seen only once with no reuse signal → **keep**, not skill.
- **→ drop** — noise: transient status, code/impl detail, already-known facts,
  things contradicted by a later entry.
- **→ keep** — real but not yet ready. Stays in the inbox for next time.

### 4. Sort into "auto-apply" vs "hard call"
Default: **auto-apply, flag only the hard calls.**

- **Auto-apply (just do it):** any `→ memory` write, any `→ drop`, any `→ keep`,
  and any `→ skill` with a clear reuse signal. Resolve small choices yourself with
  sensible defaults (which file an update lands in, shared-vs-project skill
  placement, borderline single-occurrence procedures). Note the defaults in the
  report.
- **Hard call (flag, usually 0–2):** only genuine judgment calls a default can't
  cover — two captures flatly contradict each other, a fact looks sensitive/wrong,
  or a cluster could **invert or overwrite an existing correct library fact**
  (a captured "correction" can encode an agent's wrong mid-session belief — verify
  against the user, don't auto-apply). Surface these as ONE short yes/no.

Then apply everything — no upfront approval table. It's all git-tracked, so any
write is one revert to undo.

### 5. Apply
- **memory:** create or append to the topic file. One fact per line / tight
  sections; link related items with `[[name]]`.
- **skill:** scaffold the SKILL.md with proper frontmatter (`name`, `description`
  with trigger phrases) and the distilled procedure as steps.
- **archive:** append every processed entry (kept AND dropped) to
  `processed/YYYY-MM-DD.md` under a `## distilled <timestamp>` heading, with its
  disposition — nothing is ever truly lost.
- **trim inbox:** rewrite `INBOX.md` to the seed header plus only the `→ keep`
  entries.
- **mark proposal applied:** if you started from a `proposals/<date>.md`, rename
  it to `<date>.applied.md`.
- **refresh the index:** run `cuz reindex` (or `bin/cuz-reindex.sh`) so the new
  facts are immediately searchable via `qmd --index cuz`.

### 6. Report
Keep it short. One tight summary: N entries → M library writes, K kept, J dropped;
the defaults you picked (one line each); and "anything to undo? just say so."

## Principles
- **Precision is your job; recall was capture's.** When unsure, lean drop — it's
  archived, not destroyed.
- **The library stays small.** A handful of owned skills, a tight memory base. If
  it's sprawling, you're keeping noise.
- **Ambient by default.** Auto-apply the obvious; flag only genuine hard calls.
  The safety net is the archive + git history, not a sign-off on every line.
