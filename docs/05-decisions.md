# 05 Decision log

Newest round at the bottom. Each entry says who decided and whether it is final or tentative. Later rounds may
overturn earlier ones; the overturned entry stays, marked.

## Round 1 (2026-10-27): first draft

Max: Fabric is "something like Unity prefabs for Factorio", wording open. The main workflow stays Block Versions' (a
panel per block); the mod places instances, players place them as well. Design only, several review rounds before code.

## Round 2 (2026-10-27): Seppi's review, Max's answers

Seppi reviewed the first draft with his agent (AXOS message 186); Max answered in chat the same day.

| # | Decision | Who | State |
|---|---|---|---|
| D1 | Fabric gets **its own vocabulary**, not Unity's words (Max: the Unity terms were only used because everyone knows them). **Template** (the design) and **instance** (one placement) are working names until the vocabulary is chosen; Unity-specific terms (prefab, transform override, variant, unpack) are not used in the mod. | Max | direction final, words open (Q1) |
| D2 | Fabric is a **new mod**, not a new major version of `block-versions`. | Seppi | final |
| D3 | **Ordinary copy/paste never links.** The mod never inspects pasted blueprints to guess whether a template was copied. Instances come only from Fabric's own interface. | Max | final |
| D4 | The interface offers **free placement**: pick a template, place it where you want (like holding a blueprint), and it becomes an instance with its own **placement** (offset, rotation, mirror; Max's comparison: Unity's transform override). Placing at the template's default spot is the special case with no offset. | Max | final |
| D5 | An explicit **Duplicate instance** action for a linked copy of an existing instance. | Seppi | tentative |
| D6 | **City-block grid only** at first. Each instance belongs to one block but may reach beyond it. | Seppi | final for the first version |
| D7 | **Rotation and mirroring** of a whole instance are wanted, as part of its placement. Pieces that cannot be mirrored (rails, possibly others) need a rule; feasibility is checked before the first-release scope is fixed. | Max, Seppi | wanted; scope after spike S2 |
| D8 | **Nesting propagates on Commit**: a component's Commit reaches every template that contains it and all their instances, with no extra Commit of the containing templates. Uncommitted work in a containing template's edit cell is never published by that. | Seppi, Max | final |
| D9 | **Editing contexts are flat**: a template's edit view (the panel of its edit cell) lists its direct components as whole units, not their insides. Components are placed there the same way as in the world, including free placement. Internally composition stays recursive. | Seppi, Max | final |
| D10 | **Overrides first**, parameters later. Changing a placed piece by hand (a request combinator set to 40k iron) records an override automatically, on world instances and on components inside a template. The most local value wins. Clearing an override shows the **current** inherited value, not an old snapshot. | Seppi | final in intent; mechanism after spike S1 |
| D11 | Protected settings stay **in place** during an update: never reset and reapplied. Whole-entity protection vs per-setting merging is decided by a headless prototype; Seppi leans to whole-entity for predictability. | Seppi | open, spike S1 |
| D12 | An upstream deletion removes the piece even if it carries an override. | Seppi | tentative, needs play-testing |
| D13 | **Removal**: deliberately removing some pieces keeps the instance and records the removals, even if one piece remains. Deliberately removing **all** pieces removes the instance entry automatically. Destruction (biters, trains) is not deliberate removal; zero remaining pieces alone never removes an instance. | Seppi, Max | final |
| D14 | **Order in a list**: the top of the list wins, like a stack where the top lies on top. (The first draft and Block Versions said "later wins"; same idea, the list is shown the other way round.) | Max | final |
| D15 | Order **across blocks** gets its own view: the block in the middle, every neighbour it really overlaps with, and a list of the instances that actually overlap, top wins. | Max | direction agreed, details open |
| D16 | Seppi builds a **frontend prototype** before the interaction is fixed (instance list, highlighting an instance's pieces, possibly a dedicated selection cursor for instances). | Seppi | agreed |
| D17 | bplib: left to technical investigation. With D3 the mod no longer has to recognise player pastes, so bplib's main use is gone; it may still help the free-placement tool (spike S3). | Seppi, Max | open |

### Overturned by round 2

- Round 1 draft: player pastes and Ctrl+C copies become linked instances (requirements R18-R25 of the first draft,
  design §4). Overturned by D3/D4.
- Round 1 draft: flipped pastes refused. Overturned by D7.
- Round 1 draft: an instance with all pieces removed by hand stays until someone clicks Remove. Overturned by D13.
- Round 1 draft: a hand change lasts only until the template changes that piece; only `#instance` combinators keep
  their settings. Overturned by D10.
