# 06 Spike results (2026-10-29, S5 2026-10-30)

Spikes S1, S2 and S4 from `02-design.md` §8, agreed with Seppi (S3, free placement, is his, in the frontend prototype).
All ran on a local headless Factorio 2.1.23 with Space Age, Cybersyn 2 0.5.1 and 0-things 0.6.7 on Max's Mac, never on
the live server. Harness and code: `spikes/` (`server.sh start`, `rcon.py`, the test mod `spikes/mod/fabric-spike`).

## S1 Overrides: whole entity or per setting

**Result: per-setting merge works for every case tried, and the entity is never rebuilt or reset.** Recommendation:
per-setting merge, not whole-entity protection. **Decided otherwise: overrides cover the whole entity (D20).** The
detection and the traps below apply either way.

Method: the world entity's settings are read as a one-entity blueprint table (through 0-things, so Cybersyn 2 settings
come along). With the old template version T1, the new one T2 and the world W, each setting is merged: where W differs
from T1 it is a hand change and stays; otherwise T2's value is taken. Lists whose entries carry an index (logistic
sections, their requests, filters) are merged entry by entry. If the result differs from W, it is pasted as a one-entity
blueprint over the entity, in place.

| Case | Hand change | Template change | Merge result | A plain paste of the new version instead |
|---|---|---|---|---|
| Fast inserter | filter iron → copper | circuit condition 10 → 99 | copper kept, 99 applied | filter back to iron |
| Assembler with 50 plates inside | recipe gear → pipe | recipe → copper cable | pipe kept, plates kept, nothing pasted | recipe copper cable, **plates gone** |
| Constant combinator | iron 10 → 40000 | adds copper 5 | 40000 kept, copper added | iron back to 10 |
| Requester chest with 77 plates inside | iron request 100 → 400 | adds copper 50 | 400 kept, copper added, plates kept | request back to 100 |
| Splitter | output priority left | filter iron, priority right | left kept, filter applied | priority right |
| Cybersyn 2 combinator | provider only (pr 1) | reserved slots 2 | pr 1 kept, slots 2 applied | pr back to 0 |

In every merge case the entity kept its `unit_number` (same entity, not rebuilt), and its contents stayed.

What this means for the design:

- **Hand changes can be found without any event**: at update time, a setting whose world value differs from what the
  last applied version put there *is* a hand change. The merge above computes exactly that list (for example
  `request_filters.sections[1].filters[1].count`). Overrides can be recorded then, at the most precise level.
- An override covers one setting, not the whole entity, so a template change to another setting of the same entity
  still arrives (Seppi's concern about predictability: the panel can list the overridden settings by name).
- Conflict on the same setting (assembler: hand pipe, template copper cable): the hand value wins, as D10 says.

Traps found:

1. **0-things applies Cybersyn 2 settings one tick after a paste.** A hand change made in the same tick as a template
   paste is overwritten a tick later. The reconcile must read the world, merge and write in one go, and never
   interleave its own paste with a read in the same tick.
2. **A settings paste on a map chunk that was never generated does nothing, without an error.** Irrelevant for the
   live map (entities stand on generated chunks), but the mod's own work surfaces must generate their chunks first.
3. **Runtime state that looks like a setting.** Cybersyn 2 and circuits write some values at runtime (for example the
   outputs Cybersyn 2 writes into wagon-control combinators). Read by the merge, they would look like hand changes and
   become overrides. The design needs a list of settings the game or other mods own, which are never treated as
   overrides. Not tested yet; the first implementation step should check the mall's combinators.

## S2 Mirroring

**Result: everything sampled mirrors correctly except rail signals, chain signals, train stops (and thrusters); the
game itself refuses to flip those four.** Tested on a sample of 20 entities: straight, half-diagonal and curved rails
(and the elevated ones and ramps for the direction table), inserters, long inserters, belts, undergrounds, a splitter,
assembler 3 with a fluid recipe, chemical plant, oil refinery, pipes, pipe-to-ground, pump, decider combinator, the
Cybersyn 2 combinator, a pole. All 20 landed; every rail end and every pipe connection of the mirrored copy is the exact
mirror image of the original's.

- The script API cannot flip a blueprint while building it (`build_blueprint` has no flip parameter; only a player's
  paste has one). So the mod mirrors the blueprint itself: mirror positions, mirror directions, toggle the entity's
  mirror flag, swap left and right priorities. Rails need their own direction table, which the spike derived and
  checked: straight `(8 - d) mod 8`, half-diagonal `(2 - d) mod 8`, curved A and B `(18 - d) mod 16`, ramps
  `(16 - d) mod 16`; the same for elevated rails.
- **Signals and train stops** must stand on the right-hand side of the track for the direction they serve. Mirrored,
  they would serve the other direction: trains would drive on the left. That is why the game refuses, and it is a
  design question, not a technical one: a template with signals or a train stop either cannot be mirrored (the panel
  says so), or Fabric moves each signal and stop to the other side of its track, which changes the template's
  geometry and can collide. Most station and Grid templates contain both.
- Recommendation: mirroring in the first version for templates without signals and train stops; for the others, show
  "cannot be mirrored: contains signals / a train stop" and decide later whether moving them is worth it.

## S4 Which events report hand changes

**Result: Fabric does not need events to keep overrides correct** (S1: the update itself finds hand changes). Events are
only needed to show an override in the panel the moment it is made.

The events Factorio 2.1 offers for a player's settings change on an entity, from its API reference: `on_gui_closed`
(entity GUIs, after any edit in them), `on_entity_settings_pasted`, `on_player_rotated_entity`,
`on_player_flipped_entity`, `on_entity_logistic_slot_changed` (requests, with section and slot), `on_entity_color_changed`,
`on_train_schedule_changed`. Cybersyn 2's own combinator window is a mod GUI, so only its `on_gui_closed` with a GUI
element (not an entity) arrives; 0-things changes its tags without an event we could rely on.

Not verified: which of these really fire for which change. A headless server has no player and cannot open a GUI. The
test mod logs all of them; a 3-minute check needs one player on the local spike server (connect to `localhost:34410`,
change an inserter filter, a request, a combinator value and a Cybersyn 2 setting, then read the log). Recommendation:
skip it until the panel is built; a cheap fallback is to re-check an entity's settings whenever its GUI closes.

## S5 Piece identity in an edit cell (2026-10-30)

Seppi's question: when a player moves, replaces, copies or deletes pieces in an edit cell, can Commit tell which
entity is which template piece, so that an override follows a moved piece (D21)? Seppi's rule: solid identity with a
small feature set beats brittle identity with a large one; anything unclear must be asked at Commit, never guessed.

Method (`spikes/mod/fabric-spike/s5.lua`, run with `spikes/s5.sh`): each scenario builds pieces, applies an edit whose
right answer is known, and grades four approaches against it: **ok** (right without asking), **ask** (Commit asks the
player), **WRONG** (silently wrong: a lost or a false identity).

- **Guess**: no ids, match by name, settings and position (Seppi's approach 1).
- **Carrier**: an id in the entity's own settings: the combinator description (`fabric:<id>`) or a disabled request
  section in requester and buffer chests (approach 2). Entities without either fall back to guessing.
- **Tool**: `unit_number` provenance plus Fabric's own move and replace tools, which log old entity → new entity
  (approach 3).
- **Things**: 0-things gives each piece a Thing with a tag holding the piece id. The tag travels in blueprints, copy
  and cut included (the "blueprint tag transport" Seppi listed).

Player operations are emulated by script on the headless server: cut = blueprint plus remove plus paste, copy =
blueprint plus paste, the game's upgrade = fast replace.

| Scenario | Guess | Carrier | Tool | Things |
|---|---|---|---|---|
| Two identical combinators swapped with the move tool | WRONG | ok | ok | ok |
| The same swap by cut and paste | WRONG | ok | WRONG (lost) | ok |
| Requester moved by cut and paste, then its request changed | WRONG (lost) | ok | WRONG (lost) | ok |
| Inserter moved with the move tool, then its filter changed | WRONG (lost) | ok | ok | ok |
| Deleted, and an identical one built by hand elsewhere | WRONG (calls it a move) | ok | ok | ok |
| Copied and pasted twice | ok | ok | ok | ok |
| Cut and pasted twice (which one is the piece?) | ask | ask | WRONG (lost) | ask |
| Three cut, two pasted back elsewhere | ok | ok | WRONG (lost) | ok |
| Upgrade by the game on the same spot (inserter → fast, requester → buffer) | WRONG (lost) | chest ok, inserter lost | WRONG (lost) | WRONG (lost) |
| Same replacement through Fabric's replace tool | WRONG (lost) | ok | ok | WRONG (lost) |
| Deleted and rebuilt fresh on the same spot | says same piece | says new | says new | says new |
| A player edits a combinator's description to another piece's id | ok | WRONG | WRONG (lost) | ok |
| Belt and splitter moved by the move tool (rebuild and log) | ok | ok | ok | ok (once registered) |

Further results:

- **Save and reload**: all scenarios graded identically after saving and loading the map again.
- **Move tool by teleport**: works for everything tried except belts, underground belts, splitters and rails (the
  engine refuses). The entity, its `unit_number`, its settings and its contents stay (an assembler kept its 20
  plates). For the four refusing types the tool rebuilds the entity and logs the mapping; that worked.
- **Leaks**: a disabled request section does not request anything (the chest's real request list stays as it was),
  but it shows in the chest's window as an extra section. A description shows in the combinator's window, and a
  player can edit it, which produced the one silently wrong answer of the carrier approach. Descriptions exist only on
  the four combinator types.
- **Things**: an entity type must be registered with 0-things at data stage (`spikes/mod/fabric-spike/data.lua`;
  without automatic interception, so only the pieces Fabric chooses become Things). Cybersyn 2 combinators already
  are Things; Fabric's tag sits next to Cybersyn 2's own tags. 0-things does not follow the game's own upgrade (fast
  replace): the new entity is no Thing.
- **Not tested** (needs a player, cannot run headless): undo and redo, the real cut tool, pasting from the cursor,
  the upgrade planner with robots. 0-things documents that a Thing survives undo and redo; that needs a short in-game
  check.

**Follow-up after Seppi's source audit of 0-things** (same day): 0-things *replaces* a Thing's whole tag set when a
player pastes settings onto it or a blueprint is pasted over it. A piece then carries another piece's id (or none),
and a later cut and paste carries the wrong id. Reproduced: a blueprint of piece A pasted over piece B, B cut and
pasted elsewhere, A deleted: the pasted B claims to be A (silently wrong). **Fix tested: Fabric keeps its own map
from Thing id to piece id as the truth and writes the piece id back the moment 0-things reports a tag change** (it
reports every change through a per-type event; Cybersyn 2's own event for its combinator). Only Fabric's key is
touched, Cybersyn 2's settings stay. With the fix, the sequence above, the same with a source Thing that has no Fabric
id, and the same with Cybersyn 2 combinators all come out right. The player's settings paste (and its undo) is in
the in-game check, since a script cannot raise it.

| Scenario | Guess | Carrier | Tool | Things |
|---|---|---|---|---|
| A pasted over B, B cut and pasted, A deleted (no repair) | WRONG (lost) | WRONG | WRONG (lost) | WRONG |
| The same with the repair | WRONG (lost) | WRONG | WRONG (lost) | ok |
| Overlap from a Thing without a Fabric id, with the repair | ask | WRONG (lost) | WRONG (lost) | ok |
| Cybersyn 2 combinators, A over B, with the repair | WRONG (lost) | WRONG | WRONG (lost) | ok |

**Second round: two prototypes on one regression suite** (Seppi's request, same day). Both keep Fabric's own map
(piece → entity, `unit_number`) as the truth, and both share one Commit rule: a piece that is gone while an
unidentified entity in the cell could be it (same name, or another entity on its spot) **blocks Commit** until the
player answers. Nothing unclear is published as a deletion.

- **P1, with 0-things as a helper**: piece ids also travel as 0-things tags. Two safeguards: an overwritten tag is
  written back at once (above), and a new Thing that arrives carrying the id of a piece whose entity still stands
  (and is not marked for removal, as by a cut) is a copy: its claim is dropped the moment it is created. Without that
  second safeguard, "copy, then delete the original" passed silently for a move.
- **P2, Fabric's own operations only**: nothing travels through blueprints. Fabric's move tool (teleport; rebuild and
  log for belts, splitters, undergrounds, rails) and replace tool keep identity; everything a player does by hand
  that removes a piece is asked at Commit. Fabric still needs 0-things' cooperative blueprinting for Cybersyn 2
  settings, so P2 avoids the identity dependency, not the mod.

`spikes/s5.sh` runs 20 scenarios on a fresh map, saves and reloads it, grades again, and fails if either prototype is
silently wrong anywhere. Result: **no silent errors in either prototype, grades identical after reload.**

| Scenario | P1 0-things | P2 own operations |
|---|---|---|
| Swap of two identical combinators with the move tool | ok | ok |
| The same swap by cut and paste | ok | ask |
| Requester cut, pasted, request changed | ok | ask |
| Inserter moved with the move tool, filter changed | ok | ok |
| Deleted, identical one built by hand elsewhere | ask | ask |
| Copied and pasted twice | ok | ok |
| Cut and pasted twice | ask | ask |
| Three cut, two pasted back | ok | ask |
| The game's upgrade on the same spot | ask | ask |
| Fabric's replace tool | ok | ok |
| Deleted and rebuilt on the same spot | ask | ask |
| Description edited by a player, then cut and pasted | ok | ask |
| Belt and splitter moved by the move tool (rebuild and log) | ok | ok |
| Blueprint of A pasted over B, B cut and pasted, A deleted | ok | ask |
| The same from a source without a Fabric id | ok | ask |
| The same with Cybersyn 2 combinators | ok | ask |
| Two instances of one component, their combinators swapped by cut and paste | ok | ask |
| Cut and pasted through a plain blueprint (no ids travel) | ask | ask |
| Copied, then the original deleted | ask | ask |
| Control: overlap sequence with P1's repair switched off | WRONG (as expected) | ask |

Supported scope, failure modes, uncertainty:

- **P1** answers hand cut and paste, partial pastes, swaps and repeated components without asking; it asks 6 times
  in 19, each time where intent really is unclear or no id can travel. Failure modes: it depends on 0-things'
  internal behaviour (tag replacement on overlap and settings paste, copies as new Things, creation events), which a
  0-things update can change; the suite is the guard. Unverified: the player's real cut (in normal play the original
  stays until robots remove it, which the copy safeguard must recognise as "marked for removal"), settings paste,
  undo and redo, the upgrade planner.
- **P2** never depends on anything travelling; it asks 14 times in 19, i.e. after every hand cut and paste. Its
  supported scope is: move, swap and replace through Fabric's tools; copy; delete. Unverified: undo and redo (an
  undone deletion is a new entity, so Commit would ask), the upgrade planner.
- Both: the player operations above need the in-game check (`spikes/README.md`).

Conclusions:

1. **Guessing alone is rejected**: silently wrong in most move and swap cases, because identical pieces look the same.
2. **Carriers in settings are rejected**: visible in the entity's window, editable by players (a silently wrong
   answer), limited to combinators and chests, and Things does the same job invisibly for every type.
3. **Things tags plus `unit_number` plus Fabric's move and replace tools, with Fabric's map as the truth and the
   immediate repair of overwritten tags,** answer every scenario correctly or ask.
   The tag catches cut and paste and partial pastes; the tools cover what the tag cannot (the game's upgrade, belts
   that cannot teleport).
4. **What Commit must ask**: one piece's id on two entities while the original is gone (cut and pasted twice); a
   piece gone with an untagged entity of the same name in the cell (deleted plus built new, or moved by hand?); a
   different entity on a removed piece's spot (the game's upgrade). Until the player answers, Commit is blocked
   (Seppi: never publish a silent deletion).

Recommended minimal scope: identity through 0-things tags and `unit_number`, Fabric's map authoritative, overwritten
tags repaired at once; Fabric move and replace tools as the
supported way to move or swap a piece while keeping its override; everything else that is unclear is asked at
Commit. Copy always makes a new piece.

## Summary for the decision log

| Spike | Recommendation | Needs |
|---|---|---|
| S1 | Per-setting merge (D11). **Decided otherwise: whole entity (D20)** | A list of runtime-owned settings |
| S2 | Mirror templates without signals and train stops; others say why not (D7). **Agreed (D22)** | Moving signals and stops: a later version |
| S4 | Detect overrides at update time; events only for a live panel badge | A 3-minute in-game check when the panel exists |
| S5 | Two prototypes, both without silent errors: P1 (0-things helper, asks 6 of 19) and P2 (own operations only, asks 14 of 19); Commit blocks on anything unclear | Seppi and Max to choose; the in-game check (cut tool, undo, redo, upgrade planner, settings paste) |
