# Local two-client multiplayer test

One headless Factorio server and two real game clients (players `fabricA`, `fabricB`) on one Mac, all loading the
same mod zip. Commands sent through RCON run on every machine; `mp.py dump TAG` makes each machine write its own copy of
the mod's `storage` (and the eligibility report) to its `script-output`, and `mp.py cmp TAG` compares the hashes.

1. `setup.sh <mod source dir>` builds `~/fabric-mp-test` and a fresh map.
2. Start the server and clients with the `srv` and `cli` functions from `run3.sh`, act through `mp.py sc '<lua>'`,
   dump, compare.
3. `run3.sh` is the late-join and reload check. It expects a running server with both clients connected and some
   built entities: B leaves, rejoins, then the server saves and restarts and both rejoin.

Local only: RCON listens on 27420 with a throwaway password; the server is not listed publicly or on LAN.
