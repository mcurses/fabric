Fabric UI Drop — 2026-11-01

This is the playable clean starter, with a frozen runtime mod and pinned third-party
mods. Requires Factorio 2.1.24 and its Space Age content installed separately.

The repository is public; the save/mod bundle is encrypted for the handover.
Max receives the passphrase privately through AXOS. No passphrase is stored here.
From this directory run:

  bash unpack.sh /path/to/destination

Enter the passphrase when OpenSSL asks. The script verifies the decrypted ZIP hash
before extracting. Then open fabric-max-drop/START-HERE.txt and run play.command.
Set FACTORIO_BIN if the launcher does not find your installation.

Starts in editor mode with one instance containing only The Grid. All 19 template
islands are explored. Station entities remain; slot anchors, filler anchors,
eligibility and assignments are deliberately unconfigured for the Bayspine exercise.
The supplied save contains the current library; starting a random new game from
the mod alone seeds the older imported fixtures instead.

Inside: START-HERE.txt, KNOWN-LIMITS.txt, DISCUSSION.txt (fluid-slider question),
VALIDATION.txt, catalog.json, DEPENDENCIES.json, BUILD.txt and file checksums.

Source preparation: ui-playground/prepare-handover.sh, executed against a COPY of
the original save. Full smoke/integration and clean starter save/reload checks passed.
Native graphical launch with no preparation driver was also verified.
