# Identity decisions and verified limits

Seppi's direction on 2026-11-12: finish the implementable identity core, preserve
uncertainty, and collect human decisions rather than interrupting implementation.
No automatic delete-plus-new policy has been selected.

## Decisions for Seppi and Max

1. **Unprovable continuity.** Anonymous mined/merged item stacks and a late paste
   can lose the distinguishing evidence. Choose between explicit resolution and
   automatic removal plus a fresh object. The current behavior retains candidates
   and blocks the unresolved commit. Position/prototype equality never proves an ID.
2. **Supported interaction contract.** Keep the conservative native operation
   boundary, or require Fabric-owned edit/build commands for cases where vanilla
   callbacks are indistinguishable. Examples: delayed native versus scripted paste;
   an owned ghost disappearing while an unraised same-prototype body is created
   elsewhere; mixed grid/off-grid or custom-grid placement not covered by the
   validated geometry. Broadening a time/geometry heuristic is not a safe fix.
3. **Save forks.** Should separate save branches always get distinct instance
   identity, or share an externally managed lineage? A saved deterministic RNG and
   a static mod-package issuer cannot distinguish identical saves that later fork.
   This needs a world/branch ownership contract, not a different random call in Lua.
4. **Edit ownership and conflict UX.** Define instances/edit cells and whether
   another player's cancellation means abort, conflict, or explicit takeover.
   The implementation prevents competing pending restores from choosing a winner.
   Exact runtime-unit acceptance is available and protects unfinished operations;
   the production UI must decide which instance/player may offer that action.

These choices affect intended behavior. They are not requests to authorize local
coding or testing, and none were silently decided by this implementation.

## Implemented from the v102 review

- Persisted domain migration; late joining VMs cannot overwrite evidence.
- Remote controller input and stale selection classification fixed.
- Held replacement requires the unchanged cursor epoch.
- Competing pending history restores reject all contenders; newer proved
  continuations invalidate stale claims even after their newer owner disappears.
- History claims wait for both the restore tick and the body-build tick to finish.
- Exact player construction receipts support hand-built tracked ghosts.
- Duplicate logical IDs in one cut selection invalidate every claimant.
- Personal/shared library records use immutable, copy-only virtual receipts.
  Old library tags cannot consume or cancel original move rights.
- Acceptance can select exact units and preserves pending cut/history/death work;
  partial acceptance retains the baseline.
- Diagnostic traces are amortized bounded arrays; full-surface debug refresh is
  explicit rather than performed every second per player.

## Evidence limits, separate from product decisions

Native character cut/paste with actual robot mining and construction preserved
F146 from runtime 166 to 175. Native manual construction of an accepted ghost
preserved F146 from ghost 164 to body 166 (intermediate source snapshots recorded).
On the final source, native cut/paste followed by hand construction preserved F143
from source 210 to body 217; native Undo, robot removal, Redo and hand construction
restored F143 on body 222. Native remote-view cut/paste then moved F143 from 222 to
228 through actual robot construction. Fixtures, materials and camera panning were
scripted; the user operations were native. Source hashes accompany every artifact.

Held moving replacement and immutable library copy have production-module
regressions. Held key/mouse attempts, including scripted walking, only emitted
nonmoving builds; see `evidence/native-input-limits.json`. Native held replacement,
personal-library pointer selection and simultaneous two-player
native controls have not been established end-to-end by the computer-control
interface. Its mouse cursor repeatedly stayed at the window edge inside Factorio
while the OS pointer moved. Hiding the test controller overlays allowed the remote
cut trial to complete; this does not establish arbitrary GUI navigation. These are
validation limits, not human policy decisions. Module tests are not a substitute
for missing native evidence.

The actual-engine domain suites cover supported blueprintable, unit-numbered
entities and settings. Tiles/no-unit entities and unsupported placement geometry
stay outside identity transfer. No universal gamepad/train/custom-mod claim is
made. Arbitrary scripts that silently create/revive/teleport objects can erase
causal evidence; the strict fallback remains unresolved.

Performance is measured for 100/500/2,000-object snapshots. The expensive periodic
scan is removed. This is not an unlimited-history or megabase throughput claim.
Authoritative history/clipboard rights are intentionally not pruned on an
arbitrary timeout: retained clipboard and undo data may still refer to them.

## Integration boundary

The existing UI branch represents whole-blueprint snapshots, without entity IDs.
This identity package is a separate runnable prototype with its own event handlers,
debug UI and test fixtures. Both prototypes use the mod name `fabric-playground`;
they must not simply be installed together. Integration needs composed handlers,
instance ownership and immutable template/version records. Keep diagnostic and
fixture interfaces out of the eventual production mod.
