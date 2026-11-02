# v102 identity prototype: review handoff

This branch is a source-review handoff, not a Fabric release or integration. It does not change the production mod. Prototype behavior is not automatically approved product policy.

## Source and evidence

`source/` is the exact final full-profile source snapshot, including generated manifest/issuer files. SHA256 of concatenated sorted top-level Lua bytes is `a98e38d1cdc50f308198a448cfea3d52341e54c8ca38b1c30f7ba2a394b881c7`. `loaded-build.json` records the runtime manifest. Generated issuer values identify test operations; they are not authentication credentials. Do not reuse the static issuer as a general save-fork solution.

`campaign-v102-review.md` and `remaining-tasks-v102.md` describe observed results and limits. `evidence/` includes selected bounded result summaries, not complete raw traces. Referenced raw artifacts remain on the private test machine; absence here means a claim may still require additional evidence for independent reproduction. No saves, credentials, raw session logs or screenshots are included. Per-file hashes are in `handoff-manifest.json`.

The source requires Factorio >=2.1.24. Max's current2.1.23 test profile is a version difference to resolve, not silently bypass. Embedded campaign/range tests create test entities/surfaces: run only in a disposable profile/save. This package is not a one-command reproduction of all native tests.

## Agreed work ownership

- Seppi side: isolated Mac mini native gameplay/robot regressions and source fixes. Current automated campaign stopped at documented delayed-input proof boundary; game saved and user state restored.
- Max side (accepted through AXOS2029): source/design contract review, supported-operation draft, complementary headless tests on separate fixtures.
- Parent coordinator: exact evidence reconciliation, review findings, scope questions and final cross-review. No concurrent mini GUI/server control.

## First multiplayer checks proposed

1. Player B copies/pastes A's pending cut: A retains its move permission; B cannot consume/invalidate it. Current hybrid evidence exists, not two-human native evidence.
2. Both players cut overlapping selections before robots act: no first-event guess and no duplicate ID.
3. One player cancels or undoes while the other pastes: preserve ownership and explicit ambiguity.
4. Per-player clipboard/Undo independence and save/reconnect with pending operations.
5. Concurrent Commit/panel operations belong to integrated Fabric; prototype identity tests alone cannot establish them.

## Acceptance and open decisions

Review the implemented proof and fallback, not historical pass counts. Confirm latest source-matched regressions and ordinary native controls; close exact historical failures with linked evidence. Enumerate unavailable native tests and explicit unsupported domains. A failed or unavailable test is not a green result.

Max's delete+new policy for mining/delayed unsupported pastes and first-version multiplayer priority are recorded on his side; do not infer Seppi's acceptance. Current prototype unresolved rows block Commit unless explicitly accepted. No production deployment is part of this handoff.
