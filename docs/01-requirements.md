# 01 Requirements

What the mod must do, not how. `[BV n]` points at requirement n in the old repo's
`block-versioning/docs/refactor/01-requirements.md`, where the history and the version that introduced it are. `[new]`
marks what Fabric adds. Wording uses the working names *prefab*, *instance*, *edit cell* (see `03-open-questions.md`
Q1).

## R1 Source of truth

1. The game's blueprint library (the save-stored tab, never the personal library) holds one record per prefab; it is
   the authority for prefab content. [BV 1, 2, 9]
2. Prefab configuration (slots, nesting, repeats, map variant) travels with the record. [BV 9]
3. Scripts can edit library records but not add them: a new prefab enters the library through the player's cursor.
   [BV 8, 63]
4. Renaming a record keeps versions, edit cell and every instance; links from other prefabs follow the rename.
   [BV 5; plan v2 decision 6]
5. Deleting a record freezes the prefab at its last version; instances keep their entities; nothing is wiped while the
   library itself is not found. [BV 6, 7]

## R2 Versions and Commit

6. Every content change is a new, immutable version. A label-only or description-only change that alters nothing
   placed is not a version. [BV 10, 13 of §6]
7. Commit captures the edit cell, including Cybersyn 2 / 0-things settings, writes the record and publishes at once (no
   staging). [BV 11, 13; ruling]
8. Commit never captures preview ghosts, context pieces from other prefabs, or pieces of filled slots it does not own.
   [BV 12, 14, 15]
9. Reset an edit cell to any version; Commit after that is a revert. [BV 20]
10. Commit must not stall the server: it returns at once, the world updates in a queue. [BV 18; plan v2 1.6]

## R3 Instances placed by the mod (block panel)

11. Per block: add, remove, reorder (later wins), count for repeated prefabs, Build now, Clear items, Restore removed.
    [BV 22, 31, 32, 53-55, 66]
12. Grid origin per surface, auto-detected, settable. [BV 23]
13. An update pastes only pieces whose content changed; unchanged pieces keep running state. [BV 25; ruling]
14. Pieces the new version drops are removed, unless another placement still wants them (shared border rails). [BV 24, 26]
15. Wires defined by a prefab are (re)connected after every update; wires a version drops are removed under the same
    owner rule. [BV 27; LEARNINGS §4]
16. Outside its own block a paste is soft: neighbours' buildings are never marked. [BV 30]
17. Overlaps between prefabs are warnings, never blocking. [BV 34; ruling]

## R4 Instances placed by players [new]

18. A player who pastes a prefab's blueprint (library record, a copy from it, a blueprint in a book, or Ctrl+C of built
    instance pieces) creates an instance of that prefab at the pasted spot and turn. It follows the prefab's updates
    like a panel-placed instance.
19. A paste of only part of a prefab (the player cut it down, or copied a few pieces) is an instance with omits: the
    left-out pieces are not added by later updates.
20. A paste on top of an existing instance of the same prefab at the same spot and turn does not create a second
    instance; it is a no-op for the mod (the engine's own settings transfer applies).
21. Pieces a player copied from instance A and pasted elsewhere carry their identity: the new paste is a new instance
    of A's prefab, never a second owner of A's pieces.
22. A plain blueprint the mod never stamped (from outside, from before the migration) stays plain; the player can turn
    it into an instance by an explicit action ("Link to prefab..."), helped by shape matching that suggests.
23. A player can **unlink** an instance: its entities stay, the mod forgets them.
24. Player-placed instances must work inside a block (they become part of that block's list) and, if Q3 says so,
    outside any block.
25. A blueprint made from instance pieces and put into the library as a *new* prefab must not silently become a copy of
    the prefab it came from (the tag-leak trap, review 06 #6).

## R5 Nesting, slots, repeats, turns, variants

26. Slots: named positions, optionally turned 90/180/270; the same prefab may sit in several slots. [BV 36-37, 40]
27. Repeats with head and tail, count per instance. [BV 38-39]
28. Nested prefabs follow their own prefab's updates; changing the nesting builds and removes the difference.
    [BV 42, 45, 47]
29. Overrides: an outer prefab's own settings on a nested piece win over the nested prefab's updates. [BV 44]
30. Omits: pieces an outer prefab deliberately lacks stay absent. [plan v2]
31. Map variants (no infinity chests / steel chests) without hidden copies of the prefab. [BV 41]
32. A nested piece's identity never depends on list positions or labels. [LEARNINGS §4 root cause 3]

## R6 Per-instance state

33. Instance settings (`#instance`, e.g. a station's requests) survive every Commit. [BV 49-51; ruling]
34. A hand change stays until the prefab changes that piece. [BV 52; ruling]
35. A piece a player removed on purpose stays removed through updates; Restore removed brings it back on request.
    [ruling 0.4.25; plan v2 decision 1]
36. Upgraded pieces (a turbo belt on a belt spot) count as the prefab's piece. [plan v2 D14]

## R7 Panels and UI

37. One component set for block panel and edit-cell panel, with a declared difference table. [LEARNINGS §4]
38. Hotkeys act on the block in the middle of the screen; the panel follows it. [BV 68]
39. Opening a panel stays cheap (well under a second). [BV 70]
40. A player-placed instance is visible as one: the panel lists it, a hover or selection shows which prefab and version
    a piece belongs to. [new]

## R8 Non-functional

41. No desyncs: everything that affects the game lives in `storage`. [BV §4]
42. Never crash or stall the live server; guard heavy operations; job queue by piece budget, never by time. [BV §4;
    review 06 §2]
43. Every rollout: test server on a copy of the live save, then the main server only while nobody is online. [AGENTS]
44. Migrations repair once and log counts. [LEARNINGS §4]
45. A read-only shadow check can print, per block, what a reconcile would change, before any switch is flipped on the
    main server. [plan v2]
46. Edit cells and Max's scratch surface are never wiped. [BV ruling]
47. English UI, code and docs.
