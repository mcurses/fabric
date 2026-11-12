# Project and identity status — 2026-11-12

## Project map

- `ui-playground/first-poc` at 88e7e86: UI, template library, slots, anchors, World
  patches and composition. Uses whole-blueprint snapshots without entity identity.
- `main` at 32514f6: requirements/design and Max's v102 review.
- `identity/handoff-v102` at a2bc9ca: pinned prototype and its historical evidence.
- `identity/completion`: continued identity core, fixes and portable local tests.

The implementation work and test harness are isolated from the UI checkout.
Next integration sequence: agree the operation/ownership boundary, extract the
identity service, define immutable template versions and instance ownership,
compose handlers, implement reconciliation, then attach the existing UI.

## Verification

Official Factorio 2.1.24; exact source hashes are recorded with evidence.

- 76 main production-module cases / 212 assertions pass, plus five supplemental
  suites: migration/reload, remote/held input, player revival (10 cases), immutable
  library copy/duplicate sources, and 100,000 bounded trace events.
- Minimal and Things 0.6.7 / Cybersyn 2 0.5.1 profiles each run 32 core checks,
  18 scripted engine checks, 185 domain scenarios / 491 assertions, and seven
  scoped-acceptance checks. Server and both real clients are compared at late join,
  reconnect and save/reload.
- Native single-belt replacement preserved F136 while runtime 180 became 209.
- Native accepted-ghost manual construction preserved F146: ghost 164 → body 166.
- Native cut/paste plus robot removal/build preserved F146: body 166 → body 175.
- On final source, native cut → manual ghost construction retained F143 from 210
  to 217; native Undo/Redo → manual construction restored it on 222; remote native
  cut/paste → robot construction retained it on 228.
- At 2,000 objects, a cached full-surface snapshot took about 235 ms in one local
  sample. Periodic debug scans are removed; explicit preview remains. These are
  snapshot measurements, not per-tick throughput measurements.

Engine fixtures use scripted setup and deliberately distinguish that from native
input proof. Native artifacts record their intermediate loaded source; final
source validation is recorded separately. JSON under `evidence/` is bounded;
private saves, full storage dumps, profiles and raw logs remain outside the repo.

See [DEFERRED.md](DEFERRED.md) for the human decisions, unsupported proof cases and
remaining native validation limits. This is a tested identity core with explicit
boundaries, not the integrated Fabric release or universal native-control coverage.
