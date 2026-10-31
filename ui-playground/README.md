# Fabric UI playground

Standalone, playable frontend prototype for reviewing Fabric's interaction model.
This runs separately from the main mod. Template/version changes and patches are
sample data; stitching and discarding resolve those samples, not backend changes.
Custom blueprint placement does place buildings/ghosts in the disposable demo.

## Try this version

Tested with **Factorio 2.1.24 on macOS**, base game only. Close any previous
playground client before updating: this version adds icon prototypes.

From the repository root:

```sh
git fetch origin
git switch ui-playground/first-poc
git pull --ff-only
./ui-playground/play.sh
```

For an independent review with fresh fixtures, use a new profile:

```sh
FABRIC_UI_HOME="$HOME/fabric-ui-review-2026-10-31" ./ui-playground/play.sh
```

The launcher detects Steam's macOS Factorio install (or `/Applications`). Set
`FACTORIO_BIN` to your executable if installed elsewhere. It creates an isolated
profile and save, links the mod to this checkout, and leaves your normal saves
and mods alone. Default profile: `~/fabric-ui-playground`.
`./ui-playground/play.sh setup` prepares the profile without opening a window.
Use a separate checkout/worktree if you have unrelated changes on your branch.
The downloadable playground archive can also be extracted and run directly with
`./ui-playground/play.sh`; no checkout is needed.

## Suggested walkthrough

1. Open the persistent **Fabric** panel using the Fabric shortcut at the bottom
   of the screen. **Edit on Map** opens the editor at the camera's location.
2. In **World**, move the camera between bordered concrete squares on land.
   Each square is an instance containing template references. Examples contain
   0, 1, 5, and 10 references, plus the original demo. The square's border shows
   selection, and the editor lists its references. Names are generated once;
   the small pencil edits an instance's name.
3. Hover reference rows to highlight their buildings. Click one to inspect its
   **Patches**. Hover changes for before/after feedback; click to locate them.
   The small icon beside the reference name opens its source template in the
   collection. Sample patch indicators are deliberately varied.
4. **View Template Collection** opens a scrolling, categorized library of 50
   templates. Clicking a card centers its concrete island in the void surface
   and opens **Edit Template**. Moving the camera selects another island;
   moving between islands clears selection. Surface switching alone closes the
   editor; use Edit on Map to reopen it.
5. **View Changes** opens the template's sample draft. Examples range from zero
   to 18 changes, with an always-visible scrollbar. **Stitch into Template**,
   **Discard Changes**, and individual reset/apply actions resolve sample rows.
   Closing the window preserves unfinished changes.
6. Use the pencil to edit a template's name, icon, or category. The icon picker
   supports items, fluids, and signals; categories can be selected or created.
   **+ Sew new Template** reuses this same form and creates a new island.
7. **+ Add a Template** in World and **+ Reference a Template** in Collection
   share a placement popup. Select a template and a sample position preset, or
   choose Custom → Place freely. Custom uses a real blueprint cursor with native
   preview, rotate/flip, click placement, and Q to cancel. Empty templates cannot
   supply a blueprint preview. Presets currently add a reference entry only.

## Iteration and validation

**Reload** / **Ctrl+Shift+R** reload runtime Lua. Open editors retain their state;
closed editors remain closed. New prototypes/assets require restarting Factorio.
**Ctrl+Shift+U** or `/ui` opens the editor. **Ctrl+Shift+P** captures a screenshot
under the profile's `script-output/fabric-ui/` directory.

**Tune** has Reference rows, Change rows, and Fabric title controls. Offsets,
icon size, spacing, replacement-arrow gaps, and reset inset update immediately.
Debug controls and Add sample edits live in the top bar, outside product windows.

```sh
./ui-playground/smoke.sh
```

The smoke script uses a fresh temporary headless profile and removes it afterward.
It requires Factorio 2.1.24's `--test-scenario` support. It exercises construction,
row retention/tuning, highlights and temporary ghost cleanup, draft close/actions,
camera-selected World instances, collection islands, name/category/icon editing,
creation, blueprint cursor setup, and navigation persistence. It does not replace
visual testing of pointer interaction and layout at different display scales.

Runtime log: `~/fabric-ui-playground/factorio-current.log` (or your custom profile).
Save after reviewing if you want to retain edits and tuning on the next launch.

## Shared components and current boundaries

- `components.lua`: shared title bars, action stacks/icons, and debug toolbar.
- `ui.lua`: shared reference rows, composite layout, and live tuning.
- `overrides.lua`: shared scrollable change rows and actions for template drafts
  and reference patches.
- `metadata.lua`: shared creation/edit form, icon picker, and category popup.
- `placement.lua`: shared Add/Reference dialog and blueprint cursor setup.
- `navigation.lua`, `library.lua`: persistent Fabric controls and grouped chooser.
- `workspaces.lua`, `collection.lua`, `world_areas.lua`: spatial contexts, template
  islands, instance squares, and camera selection.
- `world.lua`: fixtures, hover feedback, and camera focus.

This is a UI testing ground, not a completed Fabric implementation. Recursive
resolution, real diff/patch propagation, version conflict handling, and persistence
of real backend template semantics are not implemented. Some older sample
references acquire their catalog definition when first followed. Reference rows
use separate top-level frames for native dragging; Add and View Changes also use
separate frames so pressing them does not cover the reference list. Very long
reference lists and cross-instance drag/reordering still need further design.

The custom Fabric and needle icons come from Seppi's supplied SVG assets in
`mod/graphics/`; PNG exports are included so no graphics tooling is needed to run.
