# 07 Supported operations (draft for Max and Seppi to cut, 2026-11-02)

What a player can do to a piece of an instance or an edit cell, and what Fabric makes of it. "Keeps" means the piece
keeps its identity, so its overrides stay with it (D21, D23); "new" means delete plus a new piece (the old piece's
overrides go). Anything not on this list is unsupported: Fabric does not promise identity, and it should at least tell
the player when it notices (Max's lean, D26).

Two result columns, kept apart on purpose:

- **Prototype now**: what Seppi's identity prototype does today, as his agent reports it. "Unresolved" means it
  refuses to guess and Commit is blocked.
- **Fabric (proposed)**: what Fabric would do under the decisions so far. Where this differs from the prototype, it is
  Max's policy (D25, D27), not yet Seppi's acceptance and not current behaviour.

Evidence labels: **native** = real player input and robots in the game; **hybrid** = native input plus scripted setup
or movement; **scripted** = engine checks driven by script; **design** = from the design, untested; **none**. Version
in brackets where it is not the latest build (v102, Factorio 2.1.24). Suite totals are not used as evidence for a row.

Still open across the list: whether an unresolved piece is asked at Commit or simply becomes new (Q10).

| # | Operation | Prototype now | Fabric (proposed) | Evidence | Proposal |
|---|---|---|---|---|---|
| 1 | Build a new entity | new; but after any mining of that item, unresolved (review 08 #5) | new | native | in |
| 2 | Cut and paste, robots build it | keeps in character mode; map view not tracked (review 08 #4) | keeps (a move) | native | in |
| 2b | Cut and paste, the player builds it by hand | to reconcile | keeps | to reconcile | in, once shown |
| 3 | Cut, save and reload, then paste | keeps | keeps | native | in |
| 4 | Cut or copy pasted later from the clipboard, where the origin proof fails | unresolved | new (D27) | native (the limit) | in, as "new" |
| 5 | Paste the same cut again; repeated fresh copies | later pastes new; the original id never on two entities | same | native (Commit showed Moved 1, Added 1, v99); hybrid for 27 fresh copies (v102); the cold variant fails | in |
| 6 | Copy and paste | new; original untouched | new | native | in |
| 7 | Mine by hand, place again (anonymous stacked items) | unresolved | new (D25) | scripted | in, as "new" |
| 8 | Mine, then undo | keeps | keeps | native | in |
| 9 | Undo and redo of placing and removing | keeps when robots rebuild; hand-built restore ghosts unresolved (review 08 #7) | keeps | native (ordinary sequences) | in; long or interrupted histories still tested |
| 10 | Fast replace by hand (faster belt) | keeps for a single click; dragging keeps only the first tile (review 08 #6) | keeps; a replacement override (D23) | native (belts) | in; other types to test |
| 11 | Upgrade planner, robots | keeps | keeps; a replacement override | native | in |
| 12 | Rotate in place | to reconcile | keeps; a settings override | to reconcile | in, once tested |
| 13 | Change settings, paste settings | to reconcile | keeps; a settings override | to reconcile | in, once tested |
| 14 | Cut and paste partly over existing buildings | free pieces keep; overlaps unresolved | same; overlaps per Q10 | native (one scenario) | in for free pieces |
| 15 | Piece destroyed (biters), rebuilt from its ghost | untested | keeps (D13); log a line if not | none | in |
| 16 | Paste rotated or mirrored, ordinary grid | to reconcile | keeps | to reconcile | in, once shown |
| 17 | Paste rotated or mirrored, unusual geometry (mixed grids, some tanks) | unsupported | unsupported | scripted (the limit) | out |
| 18 | Cut and paste ghosts (not yet built) | too little coverage | unknown | too little | later |
| 19 | Blueprint library and import strings | copies new; API import plus native paste and nested books pass | copies new; moves through the library unsupported | hybrid; the native library and import dialog are unverified | in as copies |
| 20 | Clipboard between two diverged copies of a save | fails in general; a repair covers new operations on controlled launches only | unsupported | hybrid (native cut and paste, scripted string import) | out |
| 21 | Two players on the same pieces at once | second player isolated in scripted tests | unknown | hybrid; no two-human GUI test | **in from day one (D29)**; needs a real two-player test |
| 22 | Editor mode cut | unresolved | new | native | out of required scope (Seppi) |
| 23 | Mine a car, place the same item again | keeps (unique item number), also through undo and redo | keeps | native (v42) | later |
| 23b | Wagons and trains | not established | unknown | none | out; trains in templates are a separate question |
| 24 | Tiles; entities without a unit number | not tracked; tile build, undo, redo stay outside safely | not tracked | native (tiles) | out |
| 25 | Fabric's own operations (Build now, template updates, free placement) | n/a | Fabric decides; keeps | design | in |

"To reconcile": Seppi's agent will match these rows to exact test artifacts; general suite totals are not enough.

Sources: `06-spike-results.md` (S5 and Seppi's real checks), Seppi's status reports and corrections of 2026-10-31 to
2026-11-02 (v102), decisions D21, D23, D25 to D28. To be checked against the v102 source and remaining-task list once
they are handed over.
