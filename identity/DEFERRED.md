# Deferred identity work and decisions

Seppi's direction on 2026-11-12: implement the clear core, record exceptional
scenarios and human decisions here, and resolve them later. Existing conservative
fallback remains; this is not acceptance of automatic delete-plus-new.

## Product decisions

- Anonymous mined/merged items and late clipboard input: explicit resolution versus
  delete-plus-new. Never silently claim continuity from location or prototype.
- Scope of explicit acceptance: the prototype currently accepts a whole surface.
  Production integration needs edit-cell/instance ownership and multiplayer conflict
  handling. Do not expose that prototype operation as a production per-player action.
- Another player cancelling/removing the source of a pending move: decide intent;
  conservative cancellation is distinct from stealing an ID.
- General save-fork clipboard portability: unsupported. A static package issuer and
  deterministic world RNG do not distinguish diverged saves. Controlled-launch
  issuer regeneration is not a production solution and is not used by this runner.

## Remaining gameplay/review scenarios

- Competing two-player Undo restores and stale history after another player's move:
  review #1 remains a potential wrong-owner bug; isolate and reproduce before claiming
  concurrent same-piece operations are supported. Uniqueness alone is insufficient.
- Hand-built cut/Undo ghosts: exact causal player-revival proof still needs work;
  robot-only test results cannot establish it.
- Unrelated same-prototype builds invalidating ghost moves; duplicate logical IDs
  inside one selection; overlapping simultaneous selections.
- Native personal-library paste must become a fresh copy without writing to the
  read-only record. Current guard prevents the crash and leaves it unresolved;
  do not describe that as completed copy support.
- Delayed nonmoving native input cannot borrow a widened time window: the v102
  equal-delay API counterexample remains relevant.
- Mixed-grid geometry, ghost selections, trains, tiles/no-unit entities, gamepad,
  library pointer paths and simultaneous controls: no new universal claim.
- Large-base scaling and ledger pruning remain unmeasured. Diagnostic/UI surface
  scans and historical ledgers are still prototype code.

## Integration boundary

The UI branch uses whole-blueprint snapshots without persistent entity identity.
The identity module still owns its own debug UI, surface baselines and event
handlers. A production app must compose event handlers and scope identity to
instances/edit cells, separate diagnostics/tests, and use explicit Fabric-owned
operation receipts for reconciliation. Do not simply install both mods: they share
the `fabric-playground` mod name and are different prototypes.
