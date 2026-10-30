# Fabric UI playground

Standalone frontend prototype. No dependency on Fabric's main logic and no factory actions.

Launch from the workspace:

```sh
fabric/ui-playground/play.sh
```

The launcher creates a dedicated single-player save and profile in `~/fabric-ui-playground`.
Its mod folder links directly to `mod/`, so Lua edits need no packaging or copying.
The Steam install is detected by default; set `FACTORIO_BIN` to use another executable.
Set `FABRIC_UI_HOME` for a different profile. An already-running profile is not launched again.

## Iteration

Edit `mod/ui.lua`, then click **Reload** or press **Ctrl+Shift+R**.
The window rebuilds on the first tick after scripts reload, retaining its position.
**Ctrl+Shift+U** or `/ui` reopens the window.
**Ctrl+Shift+P** captures the game including GUI into
`~/fabric-ui-playground/script-output/fabric-ui/`.

`control.lua` handles reload and events; `ui.lua` owns template rows and live tuning.
`overrides.lua` owns the compact override panel; `world.lua` owns isolated world fixtures and highlights.
New prototypes, `data.lua`, and default keybindings require a client restart.
Script syntax errors may require reloading the save after fixing them; layout construction errors are logged and can be retried with Reload.

Runtime log: `~/fabric-ui-playground/factorio-current.log`.
The reload shortcut and automatic rebuilding were verified in the graphical 2.1.24 client.

## World hover demo

Click **World** to open a separate concrete test area. The first three rows present
when it is created are linked to three small building groups. Hover their names,
icons, or controls to outline those buildings in cyan; leaving clears the outline.
Click **World** again to return to the previous surface and position.
The fixture is reused, not duplicated, on subsequent visits. Reordering retains
links by row ID. New rows have no world fixture yet. Removing a row does not delete
buildings. This is only a frontend interaction test, with no Fabric backend logic.

## Working loop and boundaries

1. Keep one graphical client open using the isolated profile above.
2. Edit runtime Lua directly in this directory; the installed mod is a symlink.
3. Click **Reload**. Scripts reload, then the first runtime tick rebuilds the UI.
   Never create GUI or mutate storage inside `on_load`.
4. Review in-game, share a screenshot, repeat. Do not launch more clients for edits.
5. Use **Tune** for live row offsets, icon size, and highlight style. Values persist
   in the save across script reloads. The preferred highlight is **Pulsing soft fill**.

Template names/icons center the camera and open overrides; grips only reorder.
Changed templates show a small dot. Overrides have per-change white check/reset
icons plus bulk actions. These actions resolve mock entries only: they do not
apply real template edits or reset buildings.

Hover an override to show its world fixture; click its row to center there.
Open **World** first. Three reusable real-building fixtures demonstrate moved
furnaces/assemblers/chests, replaced belts, and deleted inserters. Baseline
positions use temporary entity ghosts only while hovering; leaving the row, closing
the panel, or reloading destroys them. Current positions use real entities. Demo instance
selection cycles by row ID, so these are examples, not detected world differences.
New template rows still do not have their own full building groups.

## Layout lessons

- Each draggable row is a top-level screen frame. Its grip is a descendant with
  `drag_target` set to that frame; the main window moves all rows together.
- Add/remove/reorder incrementally. Rebuilding every row causes flickering.
- The add button has its own top-level footer. A root-owned button can raise the
  background over the rows and make the list appear empty.
- Raise the composite windows deliberately, not continuously every tick.
- Train schedule styles have inherited geometry. Use explicit row/child sizes,
  consistent insets, and check alignment in-game rather than guessing from Lua.
- Working template-row tuning: whole row -5, icon +1, text 0, grip/close +1,
  icon size 24. No scrollbar: that experiment was deliberately removed.
- `LuaStyle.height` is write-only; use known dimensions or readable limits.
  Frames do not accept flow spacing properties. Use child flows.
- Keep module imports at file scope. Avoid GUI child names that collide with
  native properties (for example `value`).

## Validation

Lua syntax checks are useful but do not validate Factorio styles or GUI APIs.
Run the bundled runtime smoke check from the repository root:

```sh
./ui-playground/smoke.sh
```

It creates and deletes a temporary headless profile, leaving the running graphical
client and its save untouched. Set `FACTORIO_BIN` if needed. It exercises GUI
creation, tuning, incremental rows, world highlights, camera focus, temporary
ghost cleanup, and mock actions. Runtime checks do not replace visual review
at the user's display scale.

## First proof of concept: handoff to Max and his agent

Tested with Factorio **2.1.24** on macOS (base game only; Space Age is disabled).
The mod requires Factorio **2.1.7 or newer within 2.1**. Factorio 2.0 is not supported.
An installed, licensed Factorio executable is required; no game assets are bundled.

From a checkout of this branch, at the repository root:

```sh
./ui-playground/play.sh setup  # create isolated profile/save without opening a window
./ui-playground/smoke.sh      # optional real-engine checks
./ui-playground/play.sh       # start one graphical client
```

The launcher detects macOS Steam and /Applications installs. For another install:
`FACTORIO_BIN="/absolute/path/to/factorio" ./ui-playground/play.sh`.
The launcher is primarily tested on macOS. Do not install this into the shared
multiplayer server or enable it in a production save.

Try this five-minute tour:

1. Drag the three template rows by their grips; click a name to open Overrides.
2. Click **World** to enter the real-building test area. Hover template rows for
   pulsing highlights, and click them to center the camera.
3. Steel Dropoff starts with sample changes; other rows can be clean. Use
   **Restore sample changes** in Overrides to populate any row.
4. Hover Moved/Replaced/Deleted rows: prior positions appear temporarily as
   ghosts. Click a change to center there. Leave it: the ghosts disappear.
5. Try white check/reset actions and the bulk buttons; these resolve sample UI
   entries only. They do not modify actual templates or buildings.
6. Use **Tune**, then change a runtime Lua file and click **Reload**.

This is early interaction research, not a finished design or Fabric integration.
The three override fixture variants are shared cyclically by row ID. They are
not actual detected differences, and the fixture placement is deliberately simple.
There is no scrolling, production persistence model, multiplayer validation,
or real apply/reset logic.

Save the game manually before quitting if you want to keep your current list and
tuning. Code is stored in Git; unsaved in-game edits are not stored by committing.

Feedback wanted: is the list/override flow understandable, is hover versus click
clear, are the apply/reset icons readable, and what should we try next?
