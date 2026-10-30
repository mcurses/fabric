# 03 Open questions (round 2)

Round 1's questions are answered or replaced; the answers are in `05-decisions.md`. What is still open:

**Q1. Vocabulary.** Settled: the working names stay (`05-decisions.md` D18).

**Q2. Duplicate instance** (D5, tentative): keep it, given that free placement already places a template anywhere?
Duplicate would also copy the source instance's overrides, which free placement does not.

**Q3. Overrides: whole entity or single settings.** Settled: whole entity (D20).

**Q4. Upstream deletion, move or replacement of an overridden piece.** Settled: move keeps the override, replacement
keeps it where it applies, deletion deletes (D21).

**Q5. Cross-block priority view** (D15): its layout and when it is needed (first version, or later with soft spill
until then).

**Q6. Free placement mechanism** (spike S3): blueprint in the cursor, or a selection tool with a drawn preview.

**Q7. Mirroring scope.** Settled: templates without signals and train stops mirror; moving signals and stops is for a
later version (D22).

**Q8. Where an instance belongs when it is moved** across a block edge by changing its placement: does it change block
(its anchor decides) or stay with the block it was placed in?

**Q9. Scope of the first version**: `00-brief.md` lists a proposal. Anything to add or drop before a plan with phases
and estimates is written?

**Q10. How Commit recognises a moved or replaced piece** (D21 needs it): proposal in `02-design.md` §3.1 (keep the
entity where possible, same-spot replacement, otherwise the player confirms); spike S5 to settle it.
