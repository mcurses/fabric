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
- `s5.sh`: runs every S5 scenario and prints the grades.

Example: `./server.sh start && echo 'rcon.print(serpent.block(remote.call("fabric-spike-s1", "run")))' | ./rcon.py -`
