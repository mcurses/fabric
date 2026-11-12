# Project and identity status — 2026-11-12

## Project map

- `ui-playground/first-poc` at 88e7e86: functional UI, template library, slots,
  anchors, World patches and composition. Uses whole-blueprint snapshots and has
  no persistent entity identity. Its recent World-row experiment was retired.
- `main` at 32514f6: requirements/design and Max's v102 review, including the
  reproduced late-join state divergence. The older design-only index is stale as
  a description of the whole project, but accurately describes that branch's
  implementation content.
- `identity/handoff-v102` at a2bc9ca: pinned identity prototype and bounded evidence.
- `identity/completion`: the continuing implementation plus portable local tests.

The next integration work remains: settle the supported-operation boundary,
extract a scoped identity service, define immutable template/version and instance
ownership, compose events, implement reconciliation, then connect the UI. Existing
UI snapshots must not become identity evidence based on position alone.

## Verification

On official Factorio 2.1.24:

- Existing module suite: 71 cases / 201 assertions pass.
- Added module regressions: persisted eligibility migration/reload; remote input;
  read-only records; held replacement and stale input rejection pass.
- Minimal profile: 32 core predicates, 18 scripted engine checks, 185 domain
  scenarios / 491 assertions pass. Server and both real clients have identical
  authoritative storage at late join, reconnect and save/reload.
- Things 0.6.7 / Cybersyn 2 0.5.1 profile: the same 32 + 18 checks and 185
  domain scenarios pass, with matching storage across both clients/server at all
  four checkpoints. An additional five Cybersyn combinator domain scenarios pass.
- Native single-belt fast replacement preserved F136 while changing runtime 180
  to 209. Setup was scripted; the replacement used native mouse input.
- Held-moving replacement and complete remote cut/paste are module-tested only.
  The CUA attempts did not produce the required native moving/selection events;
  no native success is claimed for those paths.

These domain tests exercise actual entities, settings export, rotation/movement,
removal, conservative recreation, explicit acceptance and no-change commits.
Direct placement labels inside those fixtures are scripted setup; they do not
establish native cut/Undo/robot provenance by themselves.

The first multiplayer harness run passed late join/reconnect but failed saving
because the disposable profile lacked a `saves` directory. The runner now creates
it; the second complete minimal run passed. The failed run is not counted as a
successful save/reload test.

## Remaining boundary

See [DEFERRED.md](DEFERRED.md). In particular, concurrent same-piece restores,
hand-built provenance and production acceptance scope are still open. This is not
an integrated release and not a claim that the entire identity system is finished.

Bounded JSON results are checked in under `evidence/`. Private test profiles,
saves, peer storage dumps and raw logs remain outside the repository.
