# Fabric functional UI prototype

A playable Factorio prototype using the 20 modules from **Gradus ad Parnassum
(versioned)** in the October 24 save. The Grid v6, Universal request v7, Trash
sender v6, stations, depots, providers, and the original small placeholder modules
replace the invented demo fixtures. See `mod/fixtures/provenance.txt`.

This version implements whole-blueprint snapshot commits. It deliberately has no
persistent entity identity system. Read `LIMITATIONS.txt` before using it beyond
the disposable playground.

## Run

Requires **Factorio 2.1.24**, Space Age, Elevated Rails, Quality, Cybersyn 2,
Cybersyn, Ghost Scanner 4 Ignore Assigned, Things, and flib.

```sh
./ui-playground/play.sh
```

The launcher prepares an isolated profile at `~/fabric-ui-playground`, copying
required mod ZIPs from installed local mods. Set `FABRIC_SOURCE_MODS` to another
mods folder if needed. It does not enable the previous Block Versions mod.
Missing dependencies produce a list rather than silently dropping their entities.
Close the game before the first launch of this version so its new mods load.

Set `FACTORIO_BIN` for a different executable or `FABRIC_UI_HOME` for a fresh
profile. The launcher supports the macOS Steam install and `/Applications`.
`./ui-playground/play.sh setup` prepares the profile without opening the game.
Normal Factorio saves and mods remain separate. Save your playground after editing.

## Try the workflow

1. **View Template Collection** opens the categorized real library. Select a
   template to open its concrete editing island in the void and **Edit Template**.
2. **+ Sew new Template** asks for name, icon, category, Origin Template or custom
   dimensions, and padding on each side. Mark an Origin Template at creation to
   make it available as a layout choice for future templates.
3. Choosing an Origin Template copies its cell dimensions and shows a toggleable
   visual underlay. It does **not** add a reference or include origin contents in
   commits. The title-bar underlay button toggles it. Padding is editable space
   outside the logical cell and is included in snapshot capture. Islands are packed
   into nearby rows with 32 tiles of void between their padded bounds. The underlay
   uses actual ghost entities on an isolated preview force, excluded from captures.
4. Build or change entities in the island using the native map editor. **View
   Changes → Stitch into Template** captures the real draft, increments its
   version, and immediately rebuilds dependent templates and World references. The
   changes panel lists Added, Deleted, Moved, Replaced, Changed, and tile changes
   with icons, hover ghosts, and individual reset actions. Versions stay out of that UI.
   **Discard Changes** restores the last committed contents and reference order.
5. **+ Reference a Template** and **+ Add a Template** use the same placement
   dialog. Its grouped template picker includes icons and native ghost previews on
   hover. Choose a saved source-book preset or **Custom → Place freely** for
   the native blueprint cursor, rotation/mirroring, and click placement. Q cancels.
6. In **World**, **Edit on Map** opens the instance beneath the camera. The four
   initial cells use The Grid's fixed 160 × 160 dimensions and real station,
   provider, and depot references. Concrete cells sit on grass; extensions beyond
   cells remain present. Hover rows to highlight their contributions.
7. Neighbor contributions appear as distinct blue rows, one per neighbor, without
   a remove button. Drag rows into order alongside your references: top to bottom,
   last wins inside the receiving cell. Dragging only previews the new order;
   **Apply order** performs one rebuild. The Grid is an explicit, non-removable
   ordered row too. Click a template row to inspect it; the
   small source button opens its template for editing.
8. World edits appear as patches on their contributing reference. Reset a patch to
   restore the world entity, or stitch it into its source template. Patches survive
   rebuilding/reordering. Removing a reference requires confirmation.
9. The pencil edits names, icons, and categories. **Fabric Settings** chooses the
   World Origin Template; a replacement must have the already-established cell
   dimensions. Applying it rebuilds World.

## Development and verification

**Reload / Ctrl+Shift+R** reloads Lua. **Ctrl+Shift+U** or `/ui` opens the editor.
**Ctrl+Shift+P** saves a screenshot to the profile's `script-output/fabric-ui/`.
**Tune** retains reference-row and title layout controls. Runtime log:
`~/fabric-ui-playground/factorio-current.log`.

```sh
./ui-playground/smoke.sh
# Shorter end-to-end UI test:
./ui-playground/smoke.sh integration
# Also check an existing save, without modifying the original:
FABRIC_TEST_SAVE=/absolute/path/to/save.zip ./ui-playground/smoke.sh integration
```

Tests run with the real dependencies in a temporary profile. They check original
module placement, native grid composition and all 16 Grid rotation/mirror cases,
capture coordinates and tile-only
snapshots, cooperative mod settings, nested propagation, discard, cycle rejection,
fixed World dimensions, underlay separation, neighbor precedence, and the shared
creation/placement/commit/metadata UI handlers. Native cursor placement is exercised
through Factorio's build API. Pointer input and visual layout still need graphical
review; passing a scripted test is not a claim of complete gameplay coverage.

`runtime.lua` owns templates, cells, references, and rebuilding. `snapshots.lua`
owns blueprint capture, transforms, placement, and wire restoration. Shared UI
components remain in `components.lua`, `ui.lua`, `metadata.lua`, `placement.lua`,
`library.lua`, `navigation.lua`, and `overrides.lua`.
