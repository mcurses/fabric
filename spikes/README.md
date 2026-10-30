# Spikes

Throwaway experiments that settle design questions before implementation. Results: `docs/06-spike-results.md`.

- `server.sh start|stop`: a local headless Factorio (the Mac app in `/Applications`) in `~/fabric-spike`, fresh map
  every start, UDP 34410, RCON `127.0.0.1:27410` password `spike`. Mods: Cybersyn 2 and 0-things copied from the
  player's mod folder, plus `mod/fabric-spike` linked from here. Never touches the player's own saves or the live
  server.
- `rcon.py <file | ->`: sends each blank-line-separated chunk as one Lua command.
- `server.sh resume`: save, stop and load the same map again (save/reload checks).
- `mod/fabric-spike`: `s1.lua` (overrides), `s2.lua` (mirroring), `s5.lua` (piece identity; `data.lua` registers the
  entity types with 0-things), `control.lua` (event logger for S4, remote interfaces `fabric-spike-s1`, `-s2`, `-s5`).
- `s5.sh`: the S5 regression suite: every scenario on a fresh map, save and reload, grades for both prototypes; exits
  non-zero if either is silently wrong anywhere. Raw output in `~/fabric-spike/s5/`.

Example: `./server.sh start && echo 'rcon.print(serpent.block(remote.call("fabric-spike-s1", "run")))' | ./rcon.py -`

## S5 in-game check (needs one player, about 5 minutes)

Checks what the headless run cannot: the real cut tool, undo, redo and the upgrade planner. The spike server must be
running (`./server.sh start`). Start the game with the spike's mods (your own mod list is not touched) and join:

    /Applications/factorio.app/Contents/MacOS/factorio --mod-directory ~/fabric-spike/mods --mp-connect localhost:34410

In the chat (`~` or Enter), type each command; `/s5 <label>` prints and records what every entity now is:

1. `/s5 setup`: builds five pieces (p1, p2 combinators, p3 inserter, p4 requester chest, p5 assembler) and turns on
   the editor.
2. Cut p1 (Ctrl+X, drag over it) and paste it 3 tiles lower. `/s5 cut`
3. Ctrl+Z twice (undo the paste, undo the cut). `/s5 undo`
4. Ctrl+Y twice (redo both). `/s5 redo`
5. Upgrade planner: inserter → fast inserter over p3, requester → buffer chest over p4. `/s5 upgrade`
6. Mine p2 (remove it), then Ctrl+Z. `/s5 mine-undo`
7. Copy p5 (Ctrl+C) and paste it next to itself. `/s5 copy`
8. Paste settings from p1 onto p2 (Shift+right-click p1, Shift+left-click p2). `/s5 paste-settings`; then Ctrl+Z.
   `/s5 paste-settings-undo`

The results are read with `remote.call('fabric-spike-play', 'log')`.
