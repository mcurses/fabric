# 07 Supported operations (draft for Max and Seppi to cut, 2026-11-02)

What a player can do to a piece of an instance or an edit cell, and what Fabric makes of it. "Keeps" means the piece
keeps its identity, so its overrides stay with it (D21, D23); "new" means delete plus a new piece (the old piece's
overrides go, D25, D27). Anything not on this list is unsupported: Fabric does not promise identity, and it should at
least tell the player when it notices (Max's lean, D26).

Evidence: **real** = a real player or robots in the game (Seppi's Mac mini, Factorio 2.1.24); **script** = scripted
engine checks (Seppi's v102 suite, or our S5 suite on 2.1.23); **none** = not tested. This list is a draft: the
"Proposal" column is for the two of you to cut; it decides nothing open.

Still open across the list: whether a piece Fabric cannot place is asked at Commit or simply becomes new (Q10).

| # | Operation | Fabric's result | Evidence | Proposal |
|---|---|---|---|---|
| 1 | Build a new entity | new piece | real, script | in |
| 2 | Cut and paste, robots or the player build it | keeps (a move) | real | in |
| 3 | Cut, save and reload, then paste | keeps | real | in |
| 4 | Cut and paste a while later from the clipboard, where the origin proof fails | new (D27) | real (the limit) | in, as "new" |
| 5 | Paste the same cut a second time | the second paste is new; the original id is never on two entities | script | in |
| 6 | Copy and paste | new piece; the original is untouched | real, script | in |
| 7 | Mine by hand, place again | new (D25) | script | in, as "new" |
| 8 | Mine, then undo | keeps | real | in |
| 9 | Undo and redo of placing and removing | keeps | real (ordinary sequences) | in; long or interrupted histories still tested |
| 10 | Fast replace by hand (faster belt, assembler 2 to 3) | keeps; a replacement override (D23) | real (belts) | in; more types to test |
| 11 | Upgrade planner, robots | keeps; a replacement override | real | in |
| 12 | Rotate in place | keeps; a settings override | none clean (Commit diff still open) | in, once tested |
| 13 | Change settings, paste settings | keeps; a settings override | none in the new prototype | in, once tested |
| 14 | Paste partly over existing buildings | free pieces keep; unclear overlaps unresolved | script | in for the free pieces; overlaps per Q10 |
| 15 | Piece destroyed (biters), rebuilt from its ghost | should keep (D13) | none | in; log a line if it does not |
| 16 | Paste rotated or mirrored, ordinary grid | keeps | script | in |
| 17 | Paste rotated or mirrored, unusual geometry (mixed grids, some tanks) | unsupported | script (the limit) | out |
| 18 | Cut and paste ghosts (not yet built) | unknown | too little | later |
| 19 | Blueprint library, import strings | copies are new; moves through the library unsupported | partial | in as copies; moves out |
| 20 | Clipboard between two diverged copies of a save | unsupported | script (the limit) | out |
| 21 | Two players working on the same pieces at once | unknown | none (needs two humans) | later; one joint session to test |
| 22 | Editor mode cut | new | real | out of required scope (Seppi) |
| 23 | Mine a car or wagon, place the same item again | keeps (unique item number) | script | later; trains in templates are a separate question |
| 24 | Tiles; entities without a unit number | not tracked | script | out |
| 25 | Fabric's own operations (Build now, template updates, free placement) | Fabric decides; keeps | design | in |

Sources: `06-spike-results.md` (S5 and Seppi's real checks), Seppi's status reports of 2026-10-31 to 2026-11-02
(v102), decisions D21, D23, D25 to D28. To be checked against Seppi's v102 source and remaining-task list once they are
handed over.
