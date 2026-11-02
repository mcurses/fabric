# 08 Review of Seppi's identity prototype v102 (2026-11-02)

Source review of `identity/handoff-v102` (commit a2bc9ca, source hash a98e38d1…), read-only, by two independent
reviewers on Max's side; nothing was run. API checked against Factorio 2.1.23 docs (the source targets 2.1.24).
"Checked" means the finding was re-read in the source after the review; "reported" means a reviewer's reading, not yet
re-checked. No finding is a tested reproduction yet.

## Wrong identity (worst class)

1. **Competing undo restores are first come, first served** (history.lua:230, :284, :476; control.lua:59). A waiting
   restore takes the id as soon as the current holder is gone. Repro (two players): A marks X for deconstruction; B
   cancels, cuts and pastes X to Q; A presses Undo (a ghost at the old spot waits); B moves or deletes the piece at Q.
   The rebuilt X at the old spot then takes the id (B's later paste fails), or brings back a deleted id. Expected: the
   two continuations are ambiguous. Reported, likely.
2. **Two sources with one id in a single cut: the last one wins** (cut.lua:493-496). Needs a duplicate to exist first,
   so the trigger is speculative; the code path is certain. Reported.
3. **A move recorded as a copy** (cut.lua:464-469): cut versus copy comes from the last linked build press, with no
   freshness check. Repro: paste an ordinary blueprint, cut in map view (see 4), paste in character mode: the move
   becomes Removed plus Added with nothing to resolve. Checked (code path); needs one native run.

## Provable cases that end unresolved, or "keeps" rows that do not hold

4. **Cut and paste in map view (remote controller) is never tracked** (cut.lua:447 returns unless the player is a
   character). Map-view moves with robots are the normal way to move things in a large base. Checked.
5. **Hand placement after any mining is unresolved forever** (mined-items.lua:98-100, :155-182). Every mined or
   robot-deconstructed tracked entity stays in a pool unless its id is live elsewhere; afterwards every hand placement
   of that item without an item number is unresolved and blocks Commit, including freshly crafted items. Row 1 of
   `07-supported-operations.md` ("build new: new") stops holding after the first mining. Checked.
6. **Fast replace by dragging keeps the id only for the first tile** (replacement.lua:12 needs the build press within
   one tick). Tiles 2 and on become removed plus added, with overrides dropped, and are not shown as unresolved.
   Row 10 holds for single clicks only. Checked.
7. **A restore ghost built by hand never gets its id** (control.lua:226-231, direct-placement.lua:57): undo keeps
   identity only when robots rebuild. Row 9. Reported, likely.
8. **A destination ghost built by hand after a cut stays unresolved** (cut.lua:609-621). Row 2b. Reported, likely.
9. **Another player can cancel a move** (cut.lua:443, :372, :515, :280): B cutting or deconstructing A's ghost,
   cancelling A's source deconstruction or mining A's source. Conservative (no duplicate), but README check 1 holds only
   for B's pastes. Reported, certain from the code.
10. **Any build of the same prototype anywhere spoils a moved ghost batch** (cut.lua:142-151, :377) and stamps A's ids
    as candidates on unrelated entities. Frequent in a busy multiplayer base. Reported.
11. **"Accept unresolved as new" covers the whole surface** (control.lua:95 counts every ghost as unresolved;
    :147-160 invalidates them all): one player's Accept turns another's in-flight move, death-ghost revivals and undo
    restores into new pieces. Reported, certain from the code.

## Multiplayer and desync

12. **The per-launch issuer is written into the mod's own files** (session-issuer.lua): every server launch changes the
    mod, so clients cannot join without receiving the new file. Blocks D29 as packaged. Checked.
13. **Module-level state outside `storage`** (eligibility.lua:3, `seeded` and `contextual`): a joining client or a
    reload re-seeds the blueprint domain table the server seeded long before, so storage can differ between peers
    (desync). Checked for `seeded`; for `contextual` the reviewers disagree (one says it is recomputed before every
    read).
14. **Probable crash with a blueprint from "My blueprints"** (cut.lua:427-436 writes tags into a read-only record); in
    multiplayer an error stops the game for everyone. Records in the shared game library get rewritten with tags by
    whoever presses build first. Reported, likely.
15. **World namespace from `math.random`** (cut.lua:8) is probably the same in every new game; same-seed maps and forks
    share it. Reported, speculative.

## Performance (likely causes of the earlier 15 ticks/s)

All certain from the code, magnitudes estimated:

- whole-registry scans per transfer, per waiting restore per tick, per hand placement (runtime-owners.lua:12-16,
  mined-items.lua:163);
- undo and redo stacks read three times per tick while a frame exists, and O(N^2) binding after a paste of N ghosts
  (history.lua:443-466, :64-67);
- per-tick loops over action ledgers, op pieces, placements and cut refs that are never pruned (history.lua:471-475,
  cut.lua:547-551, :716-718, :33, robot-jobs.lua:4-17);
- a full-surface snapshot per connected player every second (control.lua:215);
- `table.remove(trace,1)` on 8,192-entry traces for every log line, with a probe that wraps 22 events and is always
  on (cut.lua:26, history.lua:15, replacement.lua:6, coverage-probe.lua:31);
- O(N^2) blueprint reads on settings paste and on re-cutting an area (cut.lua:652, :493, :100-106).

## Ordering assumptions (fail closed if the engine changes)

- Mining binds to the undo action at +0 or +1 tick only (history.lua:436, :450), measured, not documented.
- Undo matching assumes ghost builds arrive between the undo input and `on_undo_applied` in the same tick
  (history.lua:248-280).
- The replacement window does not check the cursor position (replacement.lua:12); minor.

## Claims the source does not support

- "No fixture automation or hooks active": the coverage probe runs unconditionally (control.lua:277).
- "No fixture remote interfaces survive": control.lua registers fixture, campaign, range, perf and probe interfaces
  (:259, :266-279, :300-304); range tests create surfaces and entities.

## What held up

- No path found where the cut transfer itself puts one id on two live entities; every assignment checks for a live
  owner first.
- History state is keyed per player; no same-tick crossing of one player's undo into another's was found.
- No `on_load` mutation, no player-local data in game logic, no handler overwrites (shared events are chained).
