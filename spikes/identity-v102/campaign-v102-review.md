# v102 bounded continuation — review packet

The isolated prototype now repairs three confirmed defects since v99: invalid built-entity history callbacks (v100), on-demand binding of an exact known real entity at the history shortcut boundary (v101), and copy-recipient failures invalidating an owner's pending cut (v102). **Not production ready or universal identity coverage.** The remaining delayed-native-input failure is preserved, with a concrete equal-delay API counterexample to widening the input window.

## Latest verification, separate from historical matrix

- Full loaded after final verified reload: `a98e38d1cdc50f308198a448cfea3d52341e54c8ca38b1c30f7ba2a394b881c7`. Before that reload, full engine/native tests used `653fba1d86c4b6eb7763a1aa066ffe4e2a810e982b3e49017def72f9a58382d6`. Only generated launch issuer and loaded manifest changed; source comparison evidence records exact hashes.
- Minimal loaded/tested: `ade87fbee224438a8323c0f25f1d837375b7bdf975c96de2734803ad3ce5d363`; now saved and stopped.
- Each profile: **47 production-module files passed** (simulated engine objects, not engine proof). New recipient regressions:5scenarios/20assertions plus3robot-mismatch scenarios/9assertions.
- Actual engine domain profile executions: full705PASS/30ENGINE_LIMIT/1845assertions; minimal700PASS/35ENGINE_LIMIT/1831assertions. These are executions across profiles, not1470independent universal scenarios. Full actual engine core36predicates +18Commit/Accept checks also passed after final reload; minimal same checks passed before stop.
- Actual native owner cut after other-player receipt fixture: F21246/unit62013 -> native paste -> real robots62501, same logicalID. Other player path is **synthetic registered linked/pre callbacks + actual API build_blueprint**, not a second human GUI session.
- Actual native held mouse with **API walking fixture**: one earlier proved reservation, then27fresh copyIDs, originalF21259 only at first destination62909. API walking is not native keyboard proof. Original same-tick unconsumed multi-receipt ambiguity remains blocked.
- Ordinary native Copy/paste/Q/F8/F9: freshF22312/62952 removed by robots, Redo restoresF22312/62956. No artificial binding delay in this latest control.
- Actual save/reload:39scratch ID/runtime pairs,10user building pairs and consumed/invalid ledger states retained; no fixture remote interfaces survive. Source invalidated under v101 remains invalid; no retroactive guessed repair.

## Measured remaining boundary

`MOD-REPEAT01` remains **FAIL**, not green: genuine native cold replay emitted nonmovingPre27ticks after linked input, robot62943 stayedU22305. Earlier v100age116/robot62020U21250 remains evidence.

An independent later-mod API `build_from_cursor` at the **same age27** createdghost62947 -> real62949, with exact runtime engine stack action149468/frame receipt96, same current cut token/template/player/mode/transform. Actual nativePre came later at+119 and merged. Current production event/stack tuple has no API-origin discriminator. A prior APIat+4 also created its own bound history action. Observer `inside_api` is fixture oracle, not production authority. Strict inputguard rejects both late-native and API births; no timing-window relaxation, ID guess, automatic acceptance, or new identity mechanism selected. This is a concrete limit of the tested proof, **not a theorem that all alternative integrations are impossible**.

Other explicit boundaries remain: anonymous merged-stack lineage; no-unit entities/tiles; unproven negative-phase mixed tank geometry; unavailable gamepad; unreliable native library/import/wire pointer routes; no two-human concurrent GUI proof; natural earliest-tick history binding race not demonstrated (artificially delayed real native history passed both profiles). Historical passes are not silently relabeled latest-build native coverage. P1 same-tick unobserved copy+delete ambiguity stays explicit.

## World preservation and running state

User surface212/normalcharacter2669 restored to{20.765625,-6.65625}, zoom2, cursor empty. Original10building tuples (logicalID/runtime/prototype/quality/position/direction) match pre-test evidence; all inventory item counts and serialized itemnumbers match the protected pre-test copied-save inventory. Only measured anonymous fixture item count deltas were restored. No world rollback, user building reset, unresolved autoaccept, or history erase. Normal simulation advanced; whole-world frozen equality is not claimed. Old character3 had already died before this continuation and was not represented as alive.

Active full server **73774**, client **73779**, UDP34423/RCON27423. Legacy main25225 remains untouched. Six idle owned branches and minimal were saved/CRC checked and stopped; the active full game stays running. No fixture automation or hooks active. Current save `<private-test-root>/branch-saved-replay-v59/saves/replay-v102-ready-parent-review.zip`, SHA `f95c7843642dcbd502bcc9142cbc88af5424fed015c1dcdb6a93edd1eeb73463`, Saving finished + CRC +script.dat/level.dat0 verified.

Controls: normal MacCommandX/C/V, Q, F8Undo/F9Redo (isolated profile only). Fabric playground lists current surface; Commit previews/accepts only unambiguous diffs. **Accept unresolved as new remains explicit user action**; existing user belts remainU and Commit remains blocked until user decides. Scratch history is retained, so Undo can reach prior test actions; it was not erased to make a tidy demo.

## Review / next ownership

Parent owns AXOS1887/Max coordination and publishing. No peer messages sent. Remaining review tasks and acceptance criteria are in `remaining-tasks-v102.md`. Request independent review of recipient permission isolation and immediate history binding; any further identity-proof mechanism or unsupported-domain product policy belongs to Seppi/Max. GUI/server control remains exclusive to mini owner. This packet reports the bounded repairs and a demonstrated boundary, not completion of a universal system.

## Reproduce

Requirements: local official standalone2.1.24, lua, python3; isolated profile files/ports/configs retained. Inspect fixture source and loaded manifest in each JSON before replay. Never run fixtures against original saves. Production module suite: `python3 coverage-run-module-batch.py UNIQUE-LABEL branch-saved-replay-v59`. API engine cases: `python3 coverage-run-domain.py branch-saved-replay-v59 UNIQUE-LABEL` (creates disposable surfaces). Native cases require CUA and recorded fixture instructions; synthetic callbacks are never native proof. Save first with `coverage-save-branch.py`; branch restart helpers preserve active input ZIPs and verify owned PIDs. No routine automated work is scheduled after this review handoff.

Primary evidence: P2-v102-recipient-isolation-summary.json; RESCOPY-v102-summary.json; H102-native-history-summary.json; ORIGIN-v102-origin-boundary-summary.json; S102-reload-cut-ledger.json; RESTORE-v102-verification.json; v102-final-reload-source-difference.json; v102-final-full-47files.json; v102-final-minimal-47files.json; v102-full-domain.json; v102-minimal-domain.json. All under evidence/coverage-loop. Native screenshots under branch-saved-replay-v59/client/script-output/coverage-loop. Full historical matrix `1190`enumerated rows includes failures/limits/untested, not all latest passes.
