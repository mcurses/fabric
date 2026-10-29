# 06 Spike results (2026-10-29)

Spikes S1, S2 and S4 from `02-design.md` §8, agreed with Seppi (S3, free placement, is his, in the frontend prototype).
All ran on a local headless Factorio 2.1.23 with Space Age, Cybersyn 2 0.5.1 and 0-things 0.6.7 on Max's Mac, never on
the live server. Harness and code: `spikes/` (`server.sh start`, `rcon.py`, the test mod `spikes/mod/fabric-spike`).

## S1 Overrides: whole entity or per setting

**Result: per-setting merge works for every case tried, and the entity is never rebuilt or reset.** Recommendation:
per-setting merge, not whole-entity protection (decision D11 is still Seppi's and Max's).

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

## Summary for the decision log

| Spike | Recommendation | Needs |
|---|---|---|
| S1 | Per-setting merge (D11) | Seppi and Max to confirm; a list of runtime-owned settings |
| S2 | Mirror templates without signals and train stops; others say why not (D7) | Max: is moving signals and stops worth it later? |
| S4 | Detect overrides at update time; events only for a live panel badge | A 3-minute in-game check when the panel exists |
