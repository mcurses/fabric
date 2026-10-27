# Fabric: planning docs

Fabric brings the idea of Unity's prefabs to Factorio (the idea, not its vocabulary): a design is authored once, placed
many times, and every placement follows the design when it changes, while keeping what belongs to that one placement. It is the successor of
Block Versions (old repo `mcurses/factorio`, folder `block-versioning/`), whose lessons are the starting point.

**Status: design only, nothing implemented.** These docs will be reviewed several times before any code is written.
Current state: round 2 (Seppi's review and Max's answers applied). *Template* and *instance* are working names; Fabric
gets its own vocabulary (`05-decisions.md` D1, `03-open-questions.md` Q1).

| Doc | What it holds |
|---|---|
| `00-brief.md` | What the mod is for, who uses it, the main workflow, principles, scope |
| `01-requirements.md` | What the mod must do: carried over from Block Versions, plus placement, overrides and removal rules |
| `02-design.md` | Design: data model, one reconcile, Commit, overrides, removal, free placement, UI, spikes |
| `03-open-questions.md` | What is still open after round 2 |
| `04-prior-art.md` | Unity prefabs, Block Versions, bplib, 0-things: what we take from each |
| `05-decisions.md` | Decision log per review round, with who decided and what was overturned |

Reading order for a reviewer: 00, 05, 03, then 02; 01 and 04 as reference.

Sources these docs build on (read-only, in the old repo): `LEARNINGS.md`, `AGENTS.md`,
`block-versioning/docs/refactor/01-requirements.md`, `03-fresh-design.md`, `06-adversarial-review.md`,
`07-vnext-plan-v2.md`.
