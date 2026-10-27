# 04 Prior art

## Unity prefabs

What we take: the asset/instance split; nested prefabs that follow their own asset; per-instance property overrides
that survive asset changes; "added/removed object" overrides (our tombstones and omits); prefab mode (our edit cell);
unpack (our Unlink); variants (open, `03-open-questions.md` Q7).

What does not carry over: Unity overrides are per property of a component; ours are per piece settings signature (a
piece's settings win as a whole). Unity applies overrides from the scene back to the asset; we do not support editing a
prefab from an instance in the field (Commit only from the edit cell). Unity instances live in a scene hierarchy; ours
are entities on a shared map that two players and robots change all the time, so "what the world looks like" is never
the authority: the applied record is.

## Block Versions (old repo, reference only)

Everything in `02-design.md` §1-3 comes from its from-scratch design and review. The lessons that shaped the model are
in the old repo's `LEARNINGS.md` §4: record what was built, ids not looks, one reconcile, never re-paste unchanged
pieces, queue heavy work, state in `storage`. Its requirements list (`block-versioning/docs/refactor/01-requirements.md`)
is the checklist `01-requirements.md` references by number.

## bplib (github.com/project-cybersyn/bplib)

A library mod for other mods (MIT, by the Cybersyn 2 author, version 2.1.5, last change 2026-08-25, Factorio 2.1).
Checked against its source on 2026-10-27; it listens only to `on_player_setup_blueprint` and `on_pre_build`, i.e.
player actions, never script pastes.

| bplib event | What it gives | Use in Fabric |
|---|---|---|
| `bplib-positions` | Where each registered entity of a blueprint the player is pasting will land, the bounding box, the orientation (position, direction, flips), before anything is built | Detect player pastes through the marker entity; the instance transform (`02-design.md` §4.1) |
| `bplib-extract` | Fires when registered entities are copied into a blueprint, with a writable blueprint | Stamp Ctrl+C copies with identity tags (§4.3) |
| `bplib-overlaps` | Existing same-name entities a paste lands on | Possibly; we compute overlaps ourselves from piece tables to avoid registering every entity name |

Registration through `mod-data` at data stage (no dynamic registration, which needs restoring in `on_load` and risks
desyncs). Its "universal mode" (positions for every blueprint) is expensive and not needed.

Not covered by bplib: the mod's own script pastes (we know those anyway), the update of existing instances, and any
record of what was built. Dependency risk and the needed spike: `03-open-questions.md` Q10.

## 0-things

Cybersyn 2's dependency; stores combinator settings outside the entity. Its cooperative blueprinting API
(`cooperative-blueprinting-v1`) is what made Cybersyn 2 settings survive capture and paste in Block Versions; Fabric
keeps using it for every capture and paste. Known traps: cloning loses its data; settings are applied a tick after a
revive (tests come in two parts).
