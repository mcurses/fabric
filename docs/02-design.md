# 02 Design (first draft)

Starts from Block Versions' from-scratch design (old repo `block-versioning/docs/refactor/03-fresh-design.md`, "design
A") with the corrections of its adversarial review (`06`) and plan v2 (`07`), and adds what Fabric needs beyond it:
**instances are first-class records**, because players create them by pasting, not only the panel.

The short version:

- A **prefab** has immutable **versions**; a version is pieces, wires, children (nested prefabs) and metadata.
- An **instance** is one prefab placed under one transform, with its own overrides, omits, owned settings and removed
  pieces. It is stored, whoever created it (panel, player paste, Ctrl+C copy).
- A **host** groups instances that rank against each other: a city block (ordered list, later wins), an edit cell, or
  (if Q3 allows it) a single free instance.
- Every action edits intent, then one **reconcile** per host compares the applied state with the desired one, only at
  the spots that may have changed, and touches only those entities.
- Identity travels in **blueprint tags** with strict rules for where tags may appear. Shape matching only suggests.
- A player paste is detected **before it is built** (through bplib's positions event on a marker entity), so the mod
  knows the prefab, version and transform, and which pieces were already standing there.

---

## 1. Model

### 1.1 Concepts

| Concept | What it is |
|---|---|
| **Prefab** | A named design with a stable integer id; the label is only a display name. One library record. |
| **Version** | Immutable snapshot: pieces, wires, children, metadata (slots, repeat, map variant). |
| **Piece** | One entity of a version. Piece id stable across versions while it stays on its spot. |
| **Child** | A version's reference to another prefab under a transform, with `overrides` and `omits` (nesting; Unity: nested prefab). Children follow their prefab's head. |
| **Transform** | `{surface, x, y, rot}`; `rot` in 0/90/180/270. Flip is open (Q6). |
| **Instance** | A prefab placed under a transform in a host: `{id, prefab, applied_version, transform, origin, overrides, omits, owned, removed, counts}`. |
| **Host** | The ranking scope: block (layout = ordered instance ids), edit cell (block with profile `edit` and a workspace prefab), free (Q3). |
| **Profile** | The declared differences between map and edit (§6.3). |
| **Spot** | `name|2x|2y|dir` (positions doubled to integers). Same spot = same entity, maybe other settings. |

Unity mapping (for reviewers who know it): prefab asset = prefab, prefab instance = instance, nested prefab = child,
prefab variant = a prefab whose version is "parent + overrides" (Q7), prefab mode = edit cell, Apply/Revert overrides =
Commit from an edit cell / Restore removed + reset owned. Unity's "unpack prefab" = Unlink.

### 1.2 Storage sketch

```lua
storage.prefabs[prefab_id]   = { label, record = <library locator>, head = version_id, next_piece_id, meta }
storage.versions[version_id] = { prefab_id, n, bp, pieces = {[piece_id] = {name, x2, y2, dir, sig, inst}},
                                 wires, ext_wires, children = {{uid, prefab_id, rot, dx, dy, slot, count,
                                 overrides, omits}}, marker }
storage.instances[instance_id] = {
  prefab_id, host = {kind = "block"|"edit"|"free", key},
  transform = {surface, x, y, rot}, slot = name|nil, count = n|nil,
  origin = "panel"|"paste"|"copy",
  applied = <resolved layer tree from the last reconcile: path ids, version ids, transforms>,
  overrides = {[piece_path] = sig},   -- this instance's own settings (Unity: property override)
  omits     = {[piece_path] = true},  -- pieces this instance never had (partial paste)
  removed   = {[spot] = tick},        -- tombstones: a player removed or replaced a piece
  owned     = {[spot] = true},        -- #instance pieces whose settings belong to the instance
  child_counts = {[child_path] = n},
}
storage.blocks[surface][bx][by] = { profile = "map"|"edit", layout = {instance_id, ...}, workspace = prefab_id|nil }
storage.claims[surface][chunk]  = { [spot] = {instance_id, ...} }   -- who wants which spot (§2.5)
storage.prov[unit_number]       = { instance_id, piece_path }       -- edit cells only (§3.2)
```

Rotation and map variants are transforms on cached piece tables keyed `(version_id, rot, profile)`, read from the
engine on a hidden work surface (LEARNINGS §5: let the engine do the geometry). No hidden variant prefabs.

### 1.3 Invariants

1. Versions are immutable; the old side of every diff can be recomputed exactly.
2. After reconcile, `instance.applied` equals its resolved desired state; the world differs from the compile only by
   hand changes, tombstones, owned settings and omits.
3. A version referenced by any `applied` is never garbage-collected.
4. Piece ids are stable; a moved piece is a new piece id.
5. Higher rank wins: host order first (owner block over spill from neighbours), then layout index, then depth-first
   child order, own pieces after children.
6. Nothing that affects game state lives outside `storage`.
7. The mod removes only what an `applied` tree says it placed; never an area scan.

---

## 2. One reconcile

### 2.1 Commands

Every GUI click, chat command, remote call and relevant game event becomes a command that edits data and names the
hosts it affects; a queue in `storage` drains them by piece budget.

| Command | Edit | Scope |
|---|---|---|
| `place(host, prefab, transform/slot)` | new instance, appended to the host's layout | that host |
| `adopt_paste(...)` | new instance from a player paste (§4) | that host |
| `remove(instance)` | drop instance | its host |
| `unlink(instance)` | drop instance, leave entities, clear claims | its host |
| `move(host, instance, index)` | layout order | that host |
| `set_count(instance or child path, n)` | counts | that host |
| `publish(prefab, version)` | prefab head | every host whose applied tree contains the prefab |
| `restore_removed(instance, spots?)` | clear tombstones | that host |
| `reset_cell(cell, version)` | workspace checkout | that edit cell |

### 2.2 Resolve, compile, reconcile

Unchanged from design A §2.2-2.3, with "layer" replaced by "instance and its child tree": resolve the host's instances
into layers with stable path ids (`<instance_id>/u<uid>#k`), compute the set D of spots whose winner may have changed
(added and removed layers, version deltas cached per version pair, rank flips, collision partners), and decide winners
**before** pasting, only at D. Plan v2's corrections apply: the old re-paste paths are not needed because winners are
decided first; a veto after paste is only a backstop.

### 2.3 Filters: what the player did wins

- **Tombstones** (`removed`): written when a player mines, deconstructs, cancels the ghost of, or builds over a managed
  piece. Never by robots, scripts or biters. Restore removed clears them.
- **Owned settings** (`owned`, `#instance` pieces): never changed by an update; added with the override as starting
  value where missing.
- **Omits**: never added.
- **Already there**: an add on an identical entity or ghost (upgraded tiers count) is adopted, not pasted.
- **Foreign building in the way**: a player claim, tombstoned and reported.

### 2.4 Execute

Removals as deconstruction orders (map) or destroy (edit); adds and changes as one subset blueprint per layer, pasted
superforced through 0-things' cooperative blueprinting so Cybersyn 2 settings survive; then the wire diff by piece pair
under the owner rule; then pole connections. Wires and pole handling as in design A §2.6.

### 2.5 Shared spots: the claim index

Block Versions asked "does a neighbour block still want this spot?" by looking at the 3×3 neighbourhood. With player
instances anywhere, that becomes one **claim index** per surface and chunk: spot → instances whose applied compile has
it as a winner. Remove only spots without another claim. Outside its host block an instance is soft (yields to the
owner block's winners), as before.

---

## 3. Identity

### 3.1 Tags and where they may appear

| Where | Tags |
|---|---|
| Library record of prefab F | every own piece `fab = {f = F, p = piece_id}`; nested pieces `fab = {f = F, c = uid, p = child_piece_id}`; the marker `fab_h = {f = F, v = version_id}` |
| Clipboard from Ctrl+C / Ctrl+X of instance pieces | the same, from the source instance's compile, plus a marker that names the source (§4.3) |
| A new blueprint made with the blueprint tool | **no tags** (default, Q4) |
| A record the mod reads as a *new* prefab | foreign tags stripped at poll (review 06 #6) |
| Commit output | own tags rewritten, foreign tags stripped |

A record may carry only its own prefab's tags. That one rule closes the leak where a new station prefab blueprinted from
a built one silently became "a copy of" it.

### 3.2 Provenance

In edit cells the mod needs to know, per built entity, which prefab piece it came from (Commit classifies own pieces,
children and context by it): `storage.prov[unit_number]`, written on the mod's own revives and on build events with tags,
removed on `on_object_destroyed`. In the map, identity is by spot through the claim index; no per-entity table.

### 3.3 Commit

As design A §3.2: capture with 0-things; classify each entity by provenance (own / context / member of a copy of prefab
M / new); group copy members by (M, transform) into children with overrides and omits; a group under half of M's pieces
becomes own pieces and the Commit message says so; write the record; publish. Commit guard from plan v2: warn before
capturing real entities on preview spots or one entity matched to two prefabs.

### 3.4 Shape matching

Only as "Find copies by shape" in edit cells and "Link to prefab..." on plain pastes in the map: lists candidates, the
player confirms. Never automatic.

---

## 4. Player-placed instances [new]

### 4.1 Detecting a paste before it is built

The engine raises `on_pre_build` for a blueprint paste but does not say where each entity lands; computing that
(absolute and relative snapping, grid offsets, rotation, flip, books, library records) is what bplib does. Fabric
registers one entity name with bplib, the **marker** that every stamped blueprint carries, and listens to
`bplib-positions`:

1. The event gives the blueprint, the marker's world position and `orientation_info` (position, direction, flips),
   the surface, and the player.
2. From the marker's tags: prefab and version (or, on a copy, the source instance, §4.3). From the orientation: the
   instance transform. If flipped and flips are not supported (Q6): no instance; the paste stays plain and the player
   gets a message.
3. The mod computes every piece's world spot from its cached piece table and checks which spots already hold the
   identical entity (those raise no build event and would otherwise look missing). bplib's overlaps event can do this
   for registered names; computing it from our own table avoids registering every entity name (bplib's "universal
   mode", which it warns is expensive).
4. `adopt_paste`: a new instance with `origin = "paste"`, `applied = the pasted version`, host = the block that holds
   the transform origin (Q3 if none), appended at the bottom of that block's layout (it wins, like a newly added row).
   Pieces of the prefab that are not in the pasted blueprint become `omits` (partial paste, R19).
5. The ghosts the engine places are the instance's pieces. If the pasted version is older than the head, the normal
   reconcile brings the instance up to date: an old blueprint item in someone's inventory is no problem.
6. The marker's own ghost is removed by the mod (or kept as a visible handle, Q5).

The mod's own pastes never contain a marker, so they never trigger this path.

### 4.2 Paste over an existing instance

Same prefab, same transform: no new instance (R20). Different prefab or transform: a new instance on top, later wins;
pieces of the lower one that are displaced follow the normal collision rule, and the lower instance's remaining pieces
stay linked to it.

### 4.3 Ctrl+C of built pieces

On copy (`bplib-extract`, or `on_player_setup_blueprint` for the cursor stack only), the mod looks up each copied
entity's spot in the claim index (map) or provenance (edit cell) and writes `fab` tags plus a marker that names the
source prefab and the copied transform. Pasting it creates a new instance of the same prefab with omits for everything
not copied. Copied pieces of two different instances give one blueprint with two prefab groups: pasting it makes two
instances (one marker per group). Plain entities in the selection stay plain.

### 4.4 Removing and unlinking

A player who deconstructs all of an instance's pieces leaves an instance with only tombstones; the panel shows it
("all pieces removed by hand") with Remove and Restore. Unlink keeps the entities and drops the record and its claims
(Unity: unpack).

---

## 5. Hosts

- **Block**: the main workflow. Its layout lists panel-placed and player-placed instances in one ordered list; the
  panel shows which came from a paste.
- **Edit cell**: a block with profile `edit`, a workspace prefab, previews (instances that are ghost-only and never
  captured), instant builds. "Part of it" turns a preview into a child of the workspace prefab (a new version).
- **Free** (open, Q3): a paste outside any block on a surface without a grid origin (a space platform, a planet not
  laid out in blocks) is its own host.

---

## 6. UI

### 6.1 One view model, one renderer

As design A §4: the panel is a pure function of `storage` plus per-player GUI state; it is rebuilt on change; controls
carry `tags = {cmd, path}`; components `InstanceRow`, `ChildRow`, `AddControl`, `CountSlider`, `GrabHandle`,
`VersionPicker`, `ActionBar`, `MapToggles`, `RemovedBadge`, plus new `OriginBadge` (placed by panel / pasted) and
`InstancePanel`.

### 6.2 Inspecting an instance [new]

A hotkey on the entity under the cursor (and a click on the marker, if Q5 keeps it) opens the instance panel: prefab,
version, host, counts, removed pieces, owned pieces, and the actions Restore removed, Unlink, Open edit cell,
Blueprint of this prefab (puts a stamped copy of the record into the cursor). Hovering highlights the instance's pieces.

### 6.3 Profile table (map vs edit)

As design A §4.3, unchanged: adds as ghosts vs instant; removals as orders vs destroy; map variant vs originals;
previews only in edit; Commit/Reset/Find copies only in edit; power source only in edit.

---

## 7. Determinism and performance

As design A §5 and review 06 §2: all state in `storage`; caches are storage that is a pure function of other storage;
script inventories and work-surface pastes created and destroyed in one handler; sorted iteration; integer positions;
canonical signatures; the job budget counts pieces, never time; a job never holds the work surface across ticks; the
"we are capturing" flag lives in `storage` and is set and cleared in one call. New for Fabric: the claim index is
written in the same handler as the paste it describes; bplib's dynamic registration is not used (registration through
`mod-data` at data stage only, so nothing needs restoring in `on_load`).

Performance goal unchanged: a one-lamp Commit to a prefab with 85 instances costs one lamp per instance.

---

## 8. Migration from Block Versions

Fabric replaces `block-versions` on the main server. Proposed path (details for a later round):

1. Fabric reads Block Versions' state over its remote interface (`block-versions`, `state` and friends) and the library
   book, and builds prefabs, versions, blocks and instances in a **shadow** that changes nothing.
2. A read-only shadow check prints, per block, what the first reconcile would change. Max approves the list.
3. Switch: Block Versions stops acting (a switch in its storage, or it is removed after Fabric took over), Fabric's
   reconcile goes live, per-feature switches allow rollback without a release.

Tombstones are seeded from what is missing in the world (the 0.4.25 ruling stored explicitly); `#instance` combinators
become owned spots; edit-cell provenance is seeded by exact spot only.

---

## 9. Not supported at first

Mirroring (unless Q6 decides otherwise); per-instance version pins and a staging/release pipeline; editing a prefab
from an instance in the field (Unity's "apply override to prefab" from the scene); removing tiles; the personal
blueprint library as a source (it would desync); drag and drop in the GUI; more than one force; Cybersyn 2 shared
inventory links across separate prefabs (a mall stays one prefab).
