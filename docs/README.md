# Fabric: planning docs

Fabric brings something like Unity's **prefabs** to Factorio: a design is authored once, placed many times, and every
placed copy follows the design when it changes, while keeping what belongs to that one copy. It is the successor of
Block Versions (old repo `mcurses/factorio`, folder `block-versioning/`), whose lessons are the starting point.

**Status: design only, nothing implemented.** These docs will be reviewed several times before any code is written.
The word "prefab" is a working title; the final wording is open (see `03-open-questions.md`, Q1).

| Doc | What it holds |
|---|---|
| `00-brief.md` | What the mod is for, who uses it, the main workflow, principles, scope |
| `01-requirements.md` | What the mod must do: carried over from Block Versions, plus what player placement adds |
| `02-design.md` | First design: data model, one reconcile, identity, player-placed instances, UI, determinism |
| `03-open-questions.md` | Decisions for Max (and Seppi) before the next review round |
| `04-prior-art.md` | Unity prefabs, Block Versions, bplib, 0-things: what we take from each |

Reading order for a reviewer: 00, 03, then 02; 01 and 04 as reference.

Sources these docs build on (read-only, in the old repo): `LEARNINGS.md`, `AGENTS.md`,
`block-versioning/docs/refactor/01-requirements.md`, `03-fresh-design.md`, `06-adversarial-review.md`,
`07-vnext-plan-v2.md`.
