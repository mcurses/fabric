# 01 Requirements

What the mod must do, not how. `[BV n]` points at requirement n in the old repo's
`block-versioning/docs/refactor/01-requirements.md`, where the history and the version that introduced it are. `[new]`
marks what Fabric adds. Wording follows the vocabulary in `05-decisions.md` D18.

## R1 Source of truth

1. The game's blueprint library (the save-stored tab, never the personal library) holds one record per template; it is
   the authority for template content. [BV 1, 2, 9]
2. Template configuration (slots, nesting, repeats, map variant) travels with the record. [BV 9]
3. Scripts can edit library records but not add them: a new template enters the library through the player's cursor.
   [BV 8, 63]
4. Renaming a record keeps versions, edit cell and every instance; links from other templates follow the rename.
   [BV 5; plan v2 decision 6]
5. Deleting a record freezes the template at its last version; instances keep their entities; nothing is wiped while the
   library itself is not found. [BV 6, 7]

## R2 Versions and Commit

6. Every content change is a new, immutable version. A label-only or description-only change that alters nothing
   placed is not a version. [BV 10, 13 of §6]
7. Commit captures the edit cell, including Cybersyn 2 / 0-things settings, writes the record and publishes at once (no
   staging). [BV 11, 13; ruling]
8. Commit never captures preview ghosts, context pieces from other templates, or pieces of filled slots it does not own.
   [BV 12, 14, 15]
9. Reset an edit cell to any version; Commit after that is a revert. [BV 20]
10. Commit must not stall the server: it returns at once, the world updates in a queue. [BV 18; plan v2 1.6]

## R3 Instances placed by the mod (block panel)

11. Per block: add, remove, reorder (top of the list wins, D14), count for repeated templates, Build now, Clear items, Restore removed.
    [BV 22, 31, 32, 53-55, 66]
12. Grid origin per surface, auto-detected, settable. [BV 23]
13. An update pastes only pieces whose content changed; unchanged pieces keep running state. [BV 25; ruling]
14. Pieces the new version drops are removed, unless another placement still wants them (shared border rails). [BV 24, 26]
15. Wires defined by a template are (re)connected after every update; wires a version drops are removed under the same
    owner rule. [BV 27; LEARNINGS §4]
16. Outside its own block a paste is soft: neighbours' buildings are never marked. [BV 30]
17. Overlaps between templates are warnings, never blocking. [BV 34; ruling]

## R4 Placement through Fabric's interface [new; `05-decisions.md` D3-D7, D13]

18. Instances come only from Fabric's interface: place at the template's default spot in a block, or **place freely**
    (hold the template like a blueprint, put it anywhere, shifted, rotated, mirrored). The result is an instance whose
    placement (offset, rotation, mirror) is stored with it.
19. An instance's placement can be changed later (move, turn, mirror); the world follows through the normal reconcile.
20. Ordinary copy/paste of built pieces gives plain entities. The mod never inspects a pasted blueprint to guess whether
    it was a template.
21. Duplicate instance: a linked copy of an existing instance, placed like a free placement. (tentative, D5)
22. Each instance belongs to one city block (the block holding its anchor) and may reach beyond it. Instances outside
    the city-block grid are out of scope for the first version. (D6)
23. Mirroring is offered where the template's pieces allow it; a template whose pieces cannot be mirrored (rails,
    possibly others) says so instead of building something wrong. (D7, spike S2)
24. A player can **unlink** an instance: its entities stay, the mod forgets them.
25. Deliberately removing some pieces keeps the instance and records the removals, even if one piece remains;
    deliberately removing all pieces removes the instance entry. Destruction (biters, trains) never counts as
    deliberate; zero pieces alone never removes an instance. (D13)

## R5 Nesting, slots, repeats, turns, variants

26. Slots: named positions, optionally turned 90/180/270; the same template may sit in several slots. [BV 36-37, 40]
27. Repeats with head and tail, count per instance. [BV 38-39]
28. Templates may contain other templates (components). A component's Commit reaches every template that contains it
    and all their instances without a Commit of the containing template; uncommitted work in a containing template's
    edit cell is never published by it. Changing the composition builds and removes the difference. [BV 42, 45, 47; D8]
28a. A template's edit view lists its direct components as whole units, placed like instances in a block (default spot
    or free placement); it never shows their insides. [new, D9]
29. Overrides: an outer template's own settings on a nested piece win over the nested template's updates. [BV 44]
30. Omits: pieces an outer template deliberately lacks stay absent. [plan v2]
31. Map variants (no infinity chests / steel chests) without hidden copies of the template. [BV 41]
32. A nested piece's identity never depends on list positions or labels. [LEARNINGS §4 root cause 3]

## R6 Per-instance state

33. A hand change to a placed piece's settings (a request combinator set to 40k iron) is recorded as an **override** of
    that instance automatically; no marker is needed. It survives every Commit. Overrides also exist on components
    inside a template. The most local value wins. [new, D10; replaces BV 49-52]
34. Clearing an override shows the template's **current** value, not an old snapshot. [new, D10]
34a. Protected settings stay in place during an update; they are never reset and reapplied. Whether protection covers
    the whole entity or single settings is decided by spike S1. [new, D11]
34b. A piece the template deletes upstream is removed even if it carries an override. [tentative, D12]
35. A piece a player removed on purpose stays removed through updates; Restore removed brings it back on request.
    [ruling 0.4.25; plan v2 decision 1]
36. Upgraded pieces (a turbo belt on a belt spot) count as the template's piece. [plan v2 D14]

## R7 Panels and UI

37. One component set for block panel and edit-cell panel, with a declared difference table. [LEARNINGS §4]
38. Hotkeys act on the block in the middle of the screen; the panel follows it. [BV 68]
39. Opening a panel stays cheap (well under a second). [BV 70]
40. An instance is visible as one: the panel lists it, selecting it highlights its pieces; a piece can be traced to
    its instance, template and version. Seppi's frontend prototype decides the interaction (D16). [new]
40a. A view for priority across blocks: the block, its neighbours it really overlaps with, and the overlapping instances
    in one list, top wins. [new, D15]

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
