# 03 Open questions (round 2)

Round 1's questions are answered or replaced; the answers are in `05-decisions.md`. What is still open:

**Q1. Vocabulary.** Fabric gets its own words, not Unity's (D1). Needed: the design (working name *template*), one
placement of it (*instance*), its offset/rotation/mirror (*placement*), a hand-kept setting (*override*), the editing
area (*edit cell*), publishing (*Commit*). Block Versions' words (module, dev cell, Commit) are known to both players
and are candidates too. Max and Seppi to propose; the docs are renamed in one pass.

**Q2. Duplicate instance** (D5, tentative): keep it, given that free placement already places a template anywhere?
Duplicate would also copy the source instance's overrides, which free placement does not.

**Q3. Overrides: whole entity or single settings** (D11): spike S1 decides; Seppi leans to whole entity.

**Q4. Upstream deletion of an overridden piece** (D12, tentative): removed with its override, or kept as a plain
entity? Needs play-testing; the same for an upstream move or replacement of an overridden piece.

**Q5. Cross-block priority view** (D15): its layout and when it is needed (first version, or later with soft spill
until then).

**Q6. Free placement mechanism** (spike S3): blueprint in the cursor, or a selection tool with a drawn preview.

**Q7. Mirroring scope** (spike S2): which templates can be mirrored, and what the panel shows for those that cannot.

**Q8. Where an instance belongs when it is moved** across a block edge by changing its placement: does it change block
(its anchor decides) or stay with the block it was placed in?

**Q9. Scope of the first version**: `00-brief.md` lists a proposal. Anything to add or drop before a plan with phases
and estimates is written?
