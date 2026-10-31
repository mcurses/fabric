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
| D1 | Fabric gets **its own vocabulary**, not Unity's words (Max: the Unity terms were only used because everyone knows them). **Template** (the design) and **instance** (one placement) are working names until the vocabulary is chosen; Unity-specific terms (prefab, transform override, variant, unpack) are not used in the mod. | Max | direction final |
| D2 | Fabric is a **new mod**, not a new major version of `block-versions`. | Seppi | final |
| D3 | **Ordinary copy/paste never links.** The mod never inspects pasted blueprints to guess whether a template was copied. Instances come only from Fabric's own interface. | Max | final |
| D4 | The interface offers **free placement**: pick a template, place it where you want (like holding a blueprint), and it becomes an instance with its own **placement** (offset, rotation, mirror; Max's comparison: Unity's transform override). Placing at the template's default spot is the special case with no offset. | Max | final |
| D5 | An explicit **Duplicate instance** action for a linked copy of an existing instance. | Seppi | tentative |
| D6 | **City-block grid only** at first. Each instance belongs to one block but may reach beyond it. | Seppi | final for the first version |
| D7 | **Rotation and mirroring** of a whole instance are wanted, as part of its placement. Pieces that cannot be mirrored (rails, possibly others) need a rule; feasibility is checked before the first-release scope is fixed. | Max, Seppi | wanted; scope after spike S2 |
| D8 | **Nesting propagates on Commit**: a component's Commit reaches every template that contains it and all their instances, with no extra Commit of the containing templates. Uncommitted work in a containing template's edit cell is never published by that. | Seppi, Max | final |
| D9 | **Editing contexts are flat**: a template's edit view (the panel of its edit cell) lists its direct components as whole units, not their insides. Components are placed there the same way as in the world, including free placement. Internally composition stays recursive. | Seppi, Max | final |
| D10 | **Overrides first**, parameters later. Changing a placed piece by hand (a request combinator set to 40k iron) records an override automatically, on world instances and on components inside a template. The most local value wins. Clearing an override shows the **current** inherited value, not an old snapshot. | Seppi | final in intent; mechanism after spike S1 |
| D11 | Protected settings stay **in place** during an update: never reset and reapplied. Whole-entity protection vs per-setting merging is decided by a headless prototype; Seppi leans to whole-entity for predictability. | Seppi | final; rule settled by D20 |
| D12 | An upstream deletion removes the piece even if it carries an override. | Seppi | final, confirmed by D21 |
| D13 | **Removal**: deliberately removing some pieces keeps the instance and records the removals, even if one piece remains. Deliberately removing **all** pieces removes the instance entry automatically. Destruction (biters, trains) is not deliberate removal; zero remaining pieces alone never removes an instance. | Seppi, Max | final |
| D14 | ~~Order in a list: the top of the list wins, like a stack.~~ Overturned by D19. | Max | overturned |
| D15 | Order **across blocks** gets its own view: the block in the middle, every neighbour it really overlaps with, and a list of the instances that actually overlap, ordered as in D19. | Max | direction agreed, details open |
| D16 | Seppi builds a **frontend prototype** before the interaction is fixed (instance list, highlighting an instance's pieces, possibly a dedicated selection cursor for instances). | Seppi | agreed; Max: the selection cursor is "amazing", fully agrees |
| D17 | bplib: left to technical investigation. With D3 the mod no longer has to recognise player pastes, so bplib's main use is gone; it may still help the free-placement tool (spike S3). | Seppi, Max | open |

### Overturned by round 2

- Round 1 draft: player pastes and Ctrl+C copies become linked instances (requirements R18-R25 of the first draft,
  design §4). Overturned by D3/D4.
- Round 1 draft: flipped pastes refused. Overturned by D7.
- Round 1 draft: an instance with all pieces removed by hand stays until someone clicks Remove. Overturned by D13.
- Round 1 draft: a hand change lasts only until the template changes that piece; only `#instance` combinators keep
  their settings. Overturned by D10.

## Round 3 (2026-10-27): vocabulary

| # | Decision | Who | State |
|---|---|---|---|
| D18 | The working names become the vocabulary: **template**, **instance**, **placement** (offset, rotation, mirror), **component** (a template inside a template), **override**, **removed piece**, **edit cell**, **Commit**, **Unlink**; plus **block**, **version**, **panel**, **Build now**. Settles D1 and Q1. | Max (template/instance proposed by Seppi) | final |

## Round 4 (2026-10-29): list order

| # | Decision | Who | State |
|---|---|---|---|
| D19 | **Order in a list: newest at the bottom, the last entry wins** (a sequence of steps applied in order). A new instance is added at the bottom. One shared display for both players, no per-player setting. Replaces D14. | Max, taking Seppi's model | final |

## Round 5 (2026-10-29): overrides and mirroring after the spikes

| # | Decision | Who | State |
|---|---|---|---|
| D20 | **Overrides cover the whole entity.** A piece with any hand change keeps all its settings through updates; a template change to that piece does not arrive until the override is cleared. Chosen over the per-setting merge that spike S1 showed to be workable. Settles Q3. | Max | final |
| D21 | **What the template does to an overridden piece**: a **move** changes only its position, the overridden settings are kept; a **replacement** keeps the overridden settings where they apply (an upgrade, or any new entity that has the same setting); a **delete** deletes the piece and its override (D12). Settles Q4. | Max | final |
| D22 | **Mirroring signals and train stops comes later.** The first version mirrors templates without rail signals, chain signals and train stops; a template with them says it cannot be mirrored. Moving them to the other side of the track is for a later version. Settles Q7. | Max | final |

## Round 6 (2026-10-31): Seppi's first UI prototype

| # | Decision | Who | State |
|---|---|---|---|
| D23 | **Hand moves, replacements and deletions of an instance's pieces are overrides**, listed in the instance's panel next to settings changes, each with its own reset (as in Seppi's prototype). Changes §4.1 ("only settings, not position") and how removed pieces (D13) are shown; the design doc follows once the panel's model is fixed. A hand move kept as an override needs the piece's identity (`06-spike-results.md`, S5). | Max, agreeing with Seppi's prototype | agreed; design text to follow |
| D24 | **Work split proposed**: Seppi builds the whole interface through; Max builds the mechanics behind it and playtests. | Max | proposed, waiting for Seppi |

## Round 7 (2026-10-31): identity limits and recovery

| # | Decision | Who | State |
|---|---|---|---|
| D25 | **Mining a piece by hand and placing it again is a delete plus a new piece, not a move.** Mined items stack anonymously, so identity cannot travel through the inventory. Cut and paste is the way to move a piece and keep it. | Max | final |
| D26 | **Recovery over perfect coverage**: rather than covering every edge case of identity, Fabric gets a change history of its own changes (Commits, placements, overrides, removals), where a single change can be undone, including the overrides it dropped on every instance. Goal: a wrong Commit never means fixing many instances by hand. Unsupported or unexpected cases at least inform the player (a log line), and are fixed by hand or covered later if they happen often. Today's design only has reset to a version (requirement 9), which does not bring back dropped overrides. | Max | proposed, to discuss with Seppi |
