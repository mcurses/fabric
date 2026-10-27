# 02 Design (round 2)

Starts from Block Versions' from-scratch design (old repo `block-versioning/docs/refactor/03-fresh-design.md`, "design
A") with the corrections of its adversarial review (`06`) and plan v2 (`07`). Round 2 applies the decisions in
`05-decisions.md` (Seppi's review and Max's answers): instances come only from Fabric's interface, with free placement;
hand changes become overrides automatically; editing contexts are flat. Words are working names (D1).

The short version:

- A **template** has immutable **versions**; a version is pieces, wires, components (other templates placed inside it)
  and metadata.
- An **instance** is one template placed under one **placement** (offset, rotation, mirror) in one city block, with its
  own overrides and removed pieces. It is a stored record.
- A **block** (or an **edit cell**, which is a block whose panel edits a template) holds an ordered list of instances;
  top of the list wins.
- Every action edits intent, then one **reconcile** per block compares applied and desired state, only at the spots that
  may have changed, and touches only those entities.
- Hand changes to settings are noticed and stored as overrides; an update never resets and reapplies them.

---

## 1. Model

### 1.1 Concepts

| Concept | What it is |
|---|---|
| **Template** | A named design with a stable integer id; the label is only a display name. One library record. |
| **Version** | Immutable snapshot: pieces, wires, components, metadata (slots, repeat, map variant). |
| **Piece** | One entity of a version. Piece id stable across versions while it stays on its spot. |
| **Component** | A version's reference to another template under a placement, with overrides and removals. Components follow their template's newest version (D8). |
| **Placement** | `{dx, dy, rot, mirror}`: offset from the template's default spot in the block, quarter turns, mirror flag (D4, D7). |
| **Instance** | `{id, template, block, placement, slot?, count?, overrides, removed, applied}`. |
| **Block** | One 160×160 cell; its ordered instance list; profile `map` or `edit`. |
| **Edit cell** | A block with profile `edit` whose instances are the components of one template (D9). |
| **Spot** | `name|2x|2y|dir` (positions doubled to integers). Same spot = same entity, maybe other settings. |
| **Override** | A setting value an instance (or a component inside a template) holds instead of the template's (D10). |

### 1.2 Storage sketch

```lua
storage.templates[template_id] = { label, record = <library locator>, head = version_id, next_piece_id, meta }
storage.versions[version_id]   = { template_id, n, bp, pieces = {[piece_id] = {name, x2, y2, dir, sig, settings}},
                                   wires, ext_wires,
                                   components = {{uid, template_id, placement, slot, count, overrides, removed}},
                                   marker }
storage.instances[instance_id] = {
  template_id, block = {surface, bx, by}, placement = {dx, dy, rot, mirror}, slot, count,
  overrides = {[piece_path] = settings},  -- recorded from hand changes (§4)
  removed   = {[piece_path] = tick},      -- deliberately removed pieces (§5)
  applied   = <resolved tree from the last reconcile: path ids, version ids, placements>,
}
storage.blocks[surface][bx][by] = { profile = "map"|"edit", order = {instance_id, ...}, edits = template_id|nil }
storage.claims[surface][chunk]  = { [spot] = {instance_id, ...} }  -- who wants which spot (§2.5)
storage.prov[unit_number]       = { instance_id, piece_path }      -- edit cells only (§3)
```

`order[1]` is the top of the list and wins (D14). Rotated and mirrored piece tables are cached per
`(version_id, rot, mirror, profile)` and read from the engine on a hidden work surface: the engine rotates and flips
blueprints itself, so the mod never computes rail geometry (LEARNINGS §5). A version whose pieces do not all land under
a mirror is marked "cannot be mirrored" (D7, spike S2).

### 1.3 Invariants

1. Versions are immutable; the old side of every diff can be recomputed exactly.
2. After reconcile, each instance's `applied` equals its resolved desired state; the world differs from it only by
   overrides, removed pieces and hand changes not yet recorded.
3. A version referenced by any `applied` is never garbage-collected.
4. Piece ids are stable; a moved piece is a new piece id.
5. Rank: own block over spill from neighbours (until D15's cross-block order exists), then list position (top wins),
   then within an instance: own pieces over its components, components in their template's list order.
6. Nothing that affects game state lives outside `storage`.
7. The mod removes only what an `applied` tree says it placed; never an area scan.

---

## 2. One reconcile

### 2.1 Commands

Every GUI click, chat command, remote call and relevant game event becomes a command that edits data and names the
blocks it affects; a queue in `storage` drains them by piece budget.

| Command | Edit | Scope |
|---|---|---|
| `place(block, template, placement or slot)` | new instance at the top of the list | that block |
| `set_placement(instance, placement)` | move, turn, mirror | that block (and the old one if the anchor changes block) |
| `duplicate(instance, placement)` | new instance with the same template, overrides copied (D5, tentative) | that block |
| `remove(instance)` | drop instance | its block |
| `unlink(instance)` | drop instance, leave entities, clear claims | its block |
| `move(block, instance, index)` | list order | that block |
| `set_count(instance or component path, n)` | counts | that block |
| `set_override(instance, piece_path, settings)` / `clear_override` | overrides | that block |
| `publish(template, version)` | template head | every block whose applied tree contains the template |
| `restore_removed(instance, pieces?)` | clear removals | that block |
| `reset_cell(cell, version)` | checkout | that edit cell |

### 2.2 Resolve, compile, reconcile

As design A §2.2-2.3: resolve the block's instances (and recursively their components) into layers with stable path ids
(`<instance_id>/c<uid>#k`), compute the set D of spots whose winner may have changed (layers added or removed, version
deltas cached per version pair, placement changes, rank flips, collision partners), decide winners **before** pasting,
only at D. Plan v2's corrections apply: no re-paste paths, a veto after paste only as a backstop.

**Propagation (D8).** A component's Commit changes the newest version of that template; every containing template's
resolve picks it up because components follow their template's head. No new version of the containing template is
made. An edit cell of the containing template is a block like any other: it receives the component update through the
same reconcile, and its own uncommitted pieces (provenance says they are the cell's own) are never touched or
published.

### 2.3 Filters: what the player did wins

- **Removed** pieces are never added back; Restore removed clears them.
- **Overrides**: a change planned for a piece with an override is applied with the override's value, and if the
  template changed nothing the override covers, the spot is not touched at all (§4.2).
- **Already there**: an add on an identical entity or ghost (upgraded tiers count) is adopted, not pasted.
- **Foreign building in the way**: reported in the panel; not destroyed.

### 2.4 Execute

Removals as deconstruction orders (map) or destroy (edit); adds and changes as one subset blueprint per layer, pasted
through 0-things' cooperative blueprinting so Cybersyn 2 settings survive; then the wire diff by piece pair under the
owner rule; then pole connections (design A §2.6).

### 2.5 Shared spots: the claim index

One claim index per surface and chunk: spot → instances whose applied compile has it as a winner. A spot is removed
only when no instance claims it any more (shared border rails). Outside its own block an instance yields to the owner
block's winners (soft spill) until the cross-block view (D15) lets the players order them explicitly.

---

## 3. Identity and Commit

With D3 there is no linking by paste, so identity tags never have to travel through players' blueprints. What remains:

- **Library records** carry the template id on the marker entity only, so a renamed or moved record is still found.
- **Edit cells** keep provenance per built entity (`storage.prov[unit_number]`), written by the mod's own builds and
  removed on `on_object_destroyed`. Commit uses it to tell the template's own pieces from its components' pieces and
  from the Grid underneath. An entity without provenance is new own work.
- **Components in an edit cell** are instances in that cell's list (D9), placed through the panel. Commit writes them as
  the version's components with their placements, overrides and removals. No look-based detection of copies; at most a
  "Find copies by shape" helper that suggests and never adopts on its own.

Commit, step by step: capture the cell with 0-things; classify by provenance (own / component / context); own pieces keep
their piece ids, new ones get fresh ids; components come from the cell's instance list; write the library record;
publish (§2.2). Commit guard from plan v2: warn before capturing something ambiguous.

---

## 4. Overrides (D10, D11, D12)

### 4.1 Recording hand changes

The mod notices settings changes on pieces it placed: `on_gui_closed` for an entity GUI, `on_entity_settings_pasted`,
the 0-things change events for Cybersyn 2 combinators, rotation events. It compares the entity's settings with the value
the instance's compile expects for that piece; a difference becomes `set_override` on the **most local** owner: the
instance in a map block, or the component instance in an edit cell (where Commit then writes it into the version). Only
settings, not position: moving a piece by hand is remove plus a plain entity.

### 4.2 Updates keep overrides in place

An update never resets a protected piece and reapplies the override (D11). Two candidate rules, decided by spike S1:

- **Whole-entity protection** (Seppi's lean): a piece with any override is left untouched by updates that change its
  settings; only an upstream deletion (D12) or a clear removes the protection. Predictable, but a template change to
  another setting of the same entity does not arrive.
- **Per-setting merge**: the reconcile computes the new settings as "template's new value, with the instance's
  overridden settings on top" and changes the entity only if that result differs from what stands there. The template's
  other changes arrive; it needs a reliable field-by-field model of each entity type's settings (filters, circuit
  conditions, combinator programs, Cybersyn 2 data), which is where it can break.

### 4.3 Clearing

`clear_override` drops the record and plans a change to the template's **current** value for that piece.

### 4.4 Upstream deletion

A piece the template deletes is removed even if it has an override (D12, tentative); the override goes with it and the
panel says so.

---

## 5. Removal (D13)

- A player who mines, deconstructs or cancels the ghost of a managed piece records a removal on its instance
  (`on_player_mined_entity`, `on_marked_for_deconstruction` and `on_pre_ghost_deconstructed` with a `player_index`).
  Robots executing the mod's own orders, scripts and destruction (`on_entity_died`) never do.
- When the last remaining piece of an instance is deliberately removed, the instance itself is removed from its block
  (no extra cleanup for bulk clearing).
- An instance whose pieces were destroyed keeps its record; ghosts-on-death and Build now bring the pieces back.
- Restore removed brings deliberately removed pieces back on request.

---

## 6. Placement and UI

### 6.1 Free placement (D4)

The panel's "Place freely" gives the player the template as a blueprint-like preview in the cursor. Where it is put
down, with R to turn and the flip keys to mirror, becomes the instance's placement. Candidate mechanisms (spike S3):

1. **A blueprint item in the cursor** made from the template's version, with a marker. `on_pre_build` reports the
   position, direction and flips of the paste; the mod knows the blueprint it handed out, so it can compute the
   placement itself (bplib could do that part). The engine's own ghosts become the instance's pieces through the
   "already there" filter. Risk: the engine paste places ghosts before the mod's rank rules are applied.
2. **A selection tool plus a drawn preview** (`rendering` of the template's outline and pieces). The mod pastes after the
   click, so only the reconcile ever builds. Risk: less familiar to use than a blueprint.

### 6.2 Panels

One view model, one renderer, one component set for block panels and edit-cell panels, with a profile table for the
deliberate differences (design A §4). Rows: instances, top wins (D14), with placement, count, overrides, removed pieces.
Selecting an instance highlights its pieces. Seppi builds a frontend prototype before the interaction is fixed (D16):
instance list, highlighting, possibly a dedicated selection cursor that picks the instance under the mouse.

### 6.3 Priority across blocks (D15)

A separate view: the block in the middle, its eight neighbours, and a list of only those instances that actually overlap
across the block edges; top wins. Until it exists, the soft-spill rule (§2.5) applies.

---

## 7. Determinism and performance

As design A §5 and review 06 §2: all state in `storage`; caches are storage that is a pure function of other storage;
script inventories and work-surface pastes created and destroyed in one handler; sorted iteration; integer positions;
canonical settings signatures; the job budget counts pieces, never time; a job never holds the work surface across
ticks. Override recording reads only the event's entity. Performance goal: a one-lamp Commit to a template with 85
instances costs one lamp per instance.

---

## 8. Spikes before implementation

| Spike | Question | Where |
|---|---|---|
| S1 | Whole-entity protection vs per-setting merge (§4.2): can settings be compared and merged reliably for the entity types we use, Cybersyn 2 combinators included, without ever resetting a protected value? | Standalone headless prototype (D11) |
| S2 | Mirroring: which entities the engine mirrors correctly in a blueprint (rails, curved and elevated rails, inserters, Cybersyn 2 combinators, fluid boxes), and what "cannot be mirrored" should mean | Headless server, scripted |
| S3 | Free placement: cursor blueprint vs selection tool with drawn preview (§6.1); include whether bplib is worth a dependency for it | Headless server plus a quick in-game look |
| S4 | Recording hand changes: which events fire for which settings changes, including 0-things/Cybersyn 2 and settings pasted with Shift+click | Headless server, scripted |

---

## 9. Migration from Block Versions

Fabric replaces `block-versions` (D2). Fabric reads Block Versions' state (its remote interface) and the library book
into a shadow that changes nothing; a read-only shadow check prints per block what the first reconcile would change;
Max approves; then Block Versions stops acting and Fabric's reconcile goes live, with per-feature switches for rollback.
`#instance` combinators become overrides; pieces missing in the world become removals; Block Versions' "later wins"
order is turned upside down for "top wins".

---

## 10. Not in the first version

Instances outside the city-block grid (D6); linking by copy/paste (D3); parameters (D10); per-instance version pins and
staging; editing a template from an instance in the field; removing tiles; the personal blueprint library as a source;
drag and drop in the GUI; more than one force; Cybersyn 2 shared-inventory links across separate templates (a mall stays
one template).
