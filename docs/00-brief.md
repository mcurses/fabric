# 00 Brief

## What it is

A Factorio 2.1 mod for **reusable designs that stay linked to their copies**. A player authors a design (working name
**prefab**) in an editing area, places it many times in the world, and when the prefab changes, every placed copy
(**instance**) is updated by ghosts and deconstruction orders, so robots do the work. Each instance keeps what belongs
to it alone: its own settings (a station's requests), pieces a player removed on purpose, hand changes the prefab never
touched.

Block Versions proved the idea on one special case: modules pasted onto a 160×160 city-block grid, chosen per block in
a panel. Fabric generalises it the way Unity's prefab system does: nested prefabs, variants, per-instance overrides, and
instances that come into the world in more than one way.

## Who

Max (product owner, plays daily) and his teammate Seppi, on one shared headless server (`quilton`), Cybersyn 2 for
trains. Two players, one force, one live save. Everything is designed for that, not for a public mod audience first
(though it ships through the mod portal).

## The main workflow (unchanged from Block Versions)

1. The map is a grid of city blocks. Each block has a **panel**: a list of the prefabs placed in it, in paste order,
   with add, remove, reorder, counts for repeated prefabs, Build now.
2. A prefab is edited in its own **edit cell** (Block Versions: dev cell) and published with **Commit**. Every instance
   follows.
3. The mod does the placing: choose in the panel, ghosts appear, robots build.

**New in Fabric: players place instances too.** A player pastes a prefab's blueprint (from the library, or a
copy of built pieces made with Ctrl+C) anywhere; that paste becomes an instance that follows the prefab like the ones
the panel placed. The panel workflow stays the main one; it will change over time.

## Principles (each one cost Block Versions at least one release)

1. **Record what was built; never infer it from looks.** Every instance has an applied state; the mod knows which
   placement put which piece there.
2. **Identity by id, not by shape.** Prefabs, versions, pieces and instances have stable ids, carried in blueprint tags.
   Shape matching only ever suggests.
3. **Every action changes intent; one reconcile changes the world.** No second paste path.
4. **Never touch what didn't change.** A paste over an identical entity resets its settings (the "mall trains stuck at
   99 %" fault). Updates paste only changed pieces.
5. **What a player did on purpose wins**, until they undo it with a click (removed pieces, owned settings).
6. **Multiplayer-deterministic**: all state in `storage`, no Lua-side caches that touch the game.
7. **Heavy work in a queue**, sliced over ticks by a piece budget.
8. **Map and edit areas run the same code**; their differences are one declared table.
9. **Test on a copy of the live save** before anything reaches the main server.

## Scope of the first version (proposal, to be confirmed)

In: prefabs with versions; edit cells and Commit; block panel; slots, repeats, turns; nested prefabs with overrides and
omits; per-instance owned settings; player-placed instances via paste; Ctrl+C copies that stay linked; map variants
(infinity chests out on planets); Cybersyn 2 settings surviving paste and capture; a migration path from Block Versions'
library book.

Out at first (see `02-design.md` §9): mirroring, per-instance version pins and staging, editing a prefab from an
instance in the field, removing tiles, the personal blueprint library as a source.
