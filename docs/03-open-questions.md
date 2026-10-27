# 03 Open questions

Decisions for Max (and Seppi) before the next review round. Each has a recommendation; nothing is built until they are
answered.

**Q1. Wording.** "Prefab" / "instance" / "edit cell" are working names. Alternatives: *module* / *placement* / *dev
cell* (Block Versions' words, already familiar to both players), *template* / *copy*, *pattern* / *stamp*.
Recommendation: keep Block Versions' words where they worked for you in play (they are in your heads already), and pick
one new word for player-pasted instances only if it helps. Your call; the docs will be renamed in one pass.

**Q2. Mod name and relation to Block Versions.** Fabric as a new mod that takes over Block Versions' map (migration,
`02-design.md` §8), or a new major version of `block-versions` itself (same portal page, no second mod to install).
Recommendation: new mod, because the storage model changes completely and side-by-side shadow checks are easier with
two mods; Block Versions stays installed until the switch.

**Q3. Instances outside city blocks.** May a player paste a prefab outside any block (space platforms, planets not laid
out in blocks)? Recommendation: yes, as "free" instances; it costs little once the claim index exists, and space
platforms are an obvious use.

**Q4. Which blueprints stay linked.** Ctrl+C / Ctrl+X copies of instance pieces stay linked (recommended). A blueprint
made with the blueprint tool from built pieces: linked or plain? Recommendation: plain, plus a "Blueprint of this
prefab" button that gives a linked one. Otherwise a new station blueprinted from an old one silently becomes a copy of
it (the trap that cost Block Versions a review round).

**Q5. The marker.** Every linked blueprint carries one marker entity (that is how the mod sees a paste before it is
built). After the paste: remove its ghost (invisible, nothing to build) or keep it as a small visible handle you can
click to open the instance? Recommendation: remove; inspect via hotkey on any piece.

**Q6. Flipped pastes.** The game lets players flip blueprints (F/G). Rails, inserters and Cybersyn 2 combinators don't
mirror cleanly. Refuse to link a flipped paste (it stays plain, with a message), or support flips as a transform?
Recommendation: refuse in the first version.

**Q7. Variants.** Unity's prefab variant is "prefab B = prefab A plus overrides", and B follows A. Block Versions has
only map variants (infinity chests out). Needed now (e.g. "Provider bay, iron" as a variant of "Provider bay")? Or are
nested prefabs with overrides enough? Recommendation: nested prefabs with overrides first; variants later if you miss
them in play.

**Q8. Where a player paste goes in a block's list.** At the bottom (it wins over everything, like a newly added row) or
by a rule (for example above The Grid but below slots)? Recommendation: bottom, movable with the grab handle.

**Q9. A pasted instance whose pieces were all removed by hand.** Keep the empty record until someone clicks Remove
(recommended, nothing disappears by itself), or drop it automatically?

**Q10. Taking bplib as a dependency.** It is written by the Cybersyn 2 author, MIT, ready for Factorio 2.1, but small
(2 stars, no tagged releases) and not yet on our server. Neither Cybersyn 2 nor 0-things depend on it today. Both bplib
and 0-things react to blueprint events, so they must be checked together on the test server. Recommendation: depend on
it, after a spike on the test copy that pastes a stamped blueprint with Cybersyn 2 combinators and confirms both mods
behave.

**Q11. Scope of the first version.** `00-brief.md` lists a proposed scope. Anything to add or drop before a plan with
phases and estimates is written?
