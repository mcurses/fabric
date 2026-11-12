# Identity implementation and reproducible test workspace

This continues the pinned `identity/handoff-v102` source (a2bc9ca) on top of the
current Fabric design/review branch (32514f6). It is a runnable identity prototype,
not the integrated Fabric mod. Source lives in `mod/`; no private saves are required.

## Changes from the handoff

- Blueprint-domain migration is persisted in `storage`; a late joining VM cannot
  overwrite stronger existing evidence. Migration fills only missing entries.
- Character and remote-view controls both arm cut/copy. A stale blueprint input
  cannot override a newer selection arm or classify a later selection as a copy.
- Fast replacement accepts engine-generated held-build movement with unchanged
  cursor epoch, while continuing to reject stale nonmoving API pre-build callbacks.
- Library records use immutable copy-only receipts; stale tags do not confer move
  rights and repeated copies receive fresh IDs.
- History restoration arbitrates complete callback batches and rejects competing
  or superseded owners. Hand construction uses exact native ghost/material receipts.
- Exact-unit acceptance protects unfinished cut/history/death work and retains the
  baseline when other unresolved entries remain.
- Debug snapshots refresh explicitly; diagnostic trace trimming is amortized.
- The inherited loaded-build manifest no longer claims this edited source is the
  historical v102 runtime. Test artifacts record exact source hashes.

The package issuer stays identical across server and clients and is not rewritten
on launch. General save-fork identity is still unsupported; the inherited issuer
is not a security credential or a universal fork solution.

## Run module regressions

From the repository root, with Python 3 and Lua installed:

```sh
python3 identity/tests/run_identity_regressions.py identity/mod
```

The runner includes the five supplemental suites. These use the actual modules with mocked engine objects. They do not prove native
input behavior. The eligibility regression fails against the unmodified v102
source, and passes after the persisted migration fix.

## Run actual Factorio and multiplayer checks

Use official Factorio 2.1.24. The runner creates a new disposable directory,
packages identical source for all peers, starts one server plus two graphical
clients, executes engine fixtures, compares authoritative storage on late join,
reconnect and save/reload, and stops only its own captured processes. It binds
locally and does not use existing saves or the normal player profile.

```sh
python3 identity/tests/multiplayer.py \
  --factorio /absolute/path/to/factorio \
  --output /absolute/path/to/new-disposable-test-directory
```

For the Things/Cybersyn profile, append `--extra-mod /path/to/0-things_0.6.7.zip`
and `--extra-mod /path/to/cybersyn2_0.5.1.zip`. Other concurrent runs must use
separate `--port` and `--rcon-port` values. `--hold-seconds 600` keeps only the
owned test processes alive for native checks; creating `OUTPUT/stop` ends the hold.

`results.json` records each result and source hashes. Detailed engine results and
peer storage dumps are under each profile's `data/script-output/identity/`.
Missing dumps, differing hashes, failed assertions and process errors fail the
run. A successful consistency test is not evidence of two-human concurrent edits.

The module still contains diagnostic interfaces and destructive test fixtures.
Use it only in disposable profiles. See [DEFERRED.md](DEFERRED.md) for unresolved
behavior and [STATUS.md](STATUS.md) for current verification.

## Scoped resolution API

`remote.call("fabric-playground", "accept_unresolved", surface_index, player_index,
{unit_a, unit_b})` accepts only those exact currently visible runtime units. Omitting
the selection considers idle unresolved objects on the surface. Pending construction
is reported in `protected`; successful resolutions are in `accepted`. A partial
resolution retains the existing baseline and revision. The caller must refresh its
selection before retrying if a runtime object has disappeared. This is a prototype
API, not the production permission/instance boundary.
