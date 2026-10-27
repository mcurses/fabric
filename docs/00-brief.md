# 00 Brief

## What it is

A Factorio 2.1 mod for **reusable designs that stay linked to their placements**, in the spirit of Unity's prefabs
(the idea, not Unity's vocabulary; Fabric's own words are fixed in `05-decisions.md` D18). A player authors a **template** in an editing area, places it many times through Fabric's interface, and when the template
changes, every **instance** is updated by ghosts and deconstruction orders, so robots do the work. Each instance keeps
what belongs to it alone: its overrides (a station's requests set by hand), pieces removed on purpose, and its
placement (offset, rotation, mirror).

Block Versions proved the idea on one special case: modules pasted onto a 160×160 city-block grid at a fixed spot,
chosen per block in a panel. Fabric generalises it: templates made of other templates, instances placed freely with
their own offset, rotation and mirror, and hand changes kept as overrides automatically.

## Who

Max (product owner, plays daily) and his teammate Seppi, on one shared headless server, Cybersyn 2 for trains. Two
players, one force, one live save. Designed for that first, shipped through the mod portal.

## The main workflow

1. The map is a grid of city blocks. Each block has a **panel**: the instances placed in it, top of the list wins
   (`05-decisions.md` D14), with add, remove, reorder, counts for repeated templates, Build now.
2. **Placing**: choose a template in the panel; either at its default spot in the block, or **freely**, like holding a
   blueprint: wherever it lands (shifted, rotated, mirrored) it becomes an instance with that transform (D4).
3. A template is edited in its own **edit cell** and published with **Commit**. Every instance follows, also through
   templates that contain it (D8). The edit cell's panel lists the template's direct components the same way a block
   lists its instances (D9).
4. **Hand changes are overrides**: change a placed piece's settings and that instance keeps them through updates; clear
   the override to get the template's current value back (D10).
5. Ordinary copy/paste of built pieces gives plain, unlinked entities; Fabric never guesses from a paste (D3).

## Principles (each one cost Block Versions at least one release)

1. **Record what was built; never infer it from looks.** Every instance has an applied state.
2. **Identity by id, not by shape.** Templates, versions, pieces and instances have stable ids.
3. **Every action changes intent; one reconcile changes the world.** No second paste path.
4. **Never touch what didn't change.** A paste over an identical entity resets its settings (the "mall trains stuck at
   99 %" fault). Updates paste only changed pieces; protected settings are never reset and reapplied (D11).
5. **What a player did on purpose wins**: overrides, removed pieces.
6. **Multiplayer-deterministic**: all state in `storage`.
7. **Heavy work in a queue**, sliced by a piece budget.
8. **Map and edit areas run the same code**; their differences are one declared table.
9. **Test on a copy of the live save**; settle risky mechanisms in a headless prototype first.

## Scope of the first version (proposal)

In: templates with versions; edit cells and Commit; block panel; default and free placement with offset and rotation;
mirroring if spike S2 allows; nesting with propagation on Commit; automatic overrides; removal rules (D13); slots,
repeats; map variants (infinity chests out on planets); Cybersyn 2 settings surviving paste and capture; migration from
Block Versions.

Out at first: instances outside the city-block grid (D6); linking by copy/paste (D3); parameters (D10); per-instance
version pins and staging; editing a template from an instance in the field; removing tiles; the personal blueprint
library as a source.
