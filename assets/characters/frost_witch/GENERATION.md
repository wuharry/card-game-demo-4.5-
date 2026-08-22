# Frost Witch asset generation

- Generator mode: Codex built-in `imagegen`
- Final card art: `res://assets/ui/card_art/Frost_Witch_CardArt.png`
- Accepted character-only card-art source: `res://assets/ui/card_art/Frost_Witch_CardArt_Source.png`
- Final idle sheet: `res://assets/characters/frost_witch/Frost_Witch_Idle.png`
- Exact static fallback: `res://assets/characters/frost_witch/Frost_Witch_Idle_Static.png`

## Final animation set

The Wizard family was used as the timing/layout exemplar, while the accepted Frost Witch idle was the identity and palette anchor.

| Sheet | Frames | Runtime use |
| --- | ---: | --- |
| `Frost_Witch_Idle.png` | 6 | Default looping pose |
| `Frost_Witch_Walk.png` | 8 | Ready; the current battle flow does not request `Walk` |
| `Frost_Witch_Attack01.png` | 6 | Basic attack |
| `Frost_Witch_Attack02.png` | 9 | Ready; Frost Witch currently has no active skill that requests it |
| `Frost_Witch_Hurt.png` | 4 | Damage reaction |
| `Frost_Witch_Death.png` | 4 | Death reaction |
| `Frost_Witch_Summon.png` | 6 | Summon/battlecry entrance |

Every final sheet is RGBA, one horizontal row of 100×100 cells, and is discovered by the existing sibling-sheet naming convention. No animation or battle code was changed.

## Card-art prompt

> Create a finished landscape card illustration using the supplied detailed Frost Witch as the exact character reference. Preserve her recognizable design: enormous dark navy pointed witch hat, long white hair, navy cloak and dress, pale-blue ice crystal staff, elegant young frost mage, detailed pixel-art rendering. Compose for a 295:207 landscape card-art window (approximately 10:7): the witch is the clear focal point, shown about three-quarter/full body with her entire hat tip and staff crystal safely inside the frame, centered slightly right, readable at card size. Add a cohesive icy moonlit setting behind her: frozen ruined arches, drifting snow, blue aurora glow, foreground frost crystals, deep navy shadows and cyan highlights. Strong silhouette and value separation; detailed but not visually noisy. No card frame, no text, no logo, no UI, no watermark. Opaque scenic background filling the full image edge to edge. Crisp polished high-resolution pixel art, deliberate pixel clusters, no smooth vector look, no painterly brush texture.

## Idle prompt

> Create a production-ready transparent pixel-art IDLE sprite sheet derived from the supplied Frost Witch sprite. Preserve the exact same character identity and design: tiny chibi proportions, right-facing side view, oversized dark navy pointed witch hat, white hair, dark navy cloak and dress, pale blue crystal staff, same limited navy/cyan/white palette, same crisp low-resolution pixel-cluster style. Output exactly SIX animation frames in ONE single horizontal row, six equal square cells, left to right. Motion is a very subtle looping idle: gentle one-pixel-like breathing/bob, slight hat-tip and cloak-edge sway, tiny staff crystal pulse; frame 6 must flow seamlessly back to frame 1. Keep feet locked to the same ground baseline, character scale and silhouette consistent, and staff always on the right. Generous transparent padding inside every cell. True transparent alpha background. No environment, no text, no labels, no grid lines, no cell borders, no checkerboard, no floor, no cast shadow, no extra characters. Strict sprite-sheet asset, not a presentation mockup. Nearest-neighbor hard pixel edges, no antialiasing, no gradients, no painterly rendering.

The generated idle draft baked in a light checkerboard. Post-processing removed only the edge-connected neutral background, zeroed transparent RGB, normalized it to six 100×100 cells, and aligned every foot baseline to y=86. The static fallback is retained unchanged from the accepted sprite design.

## Shared action prompt contract

> Use the supplied accepted Frost Witch idle as the exact character-identity reference and the supplied Wizard action sheet only as a choreography/timing reference. Create a production-ready transparent pixel-art ACTION sprite sheet. Preserve the same tiny right-facing chibi witch in every frame: oversized dark navy pointed hat, long white hair, dark navy cloak and dress, brown-gold staff with a cyan ice crystal, identical navy/cyan/white palette, proportions, silhouette, pixel density, and hard pixel-cluster rendering. Output exactly the requested number of distinct frames in one single horizontal row of equal square cells, ordered left to right. Keep the character at one consistent scale and ground line, keep the staff on her right, leave generous padding, and keep all effects inside their own cells. True transparent alpha only. No scene, floor, shadow, text, labels, grid, borders, checkerboard, extra characters, smooth vector art, or painterly rendering.

The action-specific choreography appended to that contract was:

- `Walk` — exactly 8 frames: contact/down, passing pose, lifted foot, forward contact, then the mirrored second step; restrained hat-tip, hair, and cloak counter-sway; seamless loop.
- `Attack01` — exactly 6 frames: neutral, deep crouched anticipation, decisive rightward staff thrust with a large white-core cyan ice wave, sustained thrust with a large impact star, recovery with rightward fragments, neutral.
- `Attack02` — exactly 9 frames: neutral, channel, staff lift, small frost rune, low ice spikes emerging, peak ice-crystal wave, controlled dissipation, staff recovery, neutral.
- `Hurt` — exactly 4 frames: neutral, initial backward recoil, maximum recoil with cloak response, return toward stance.
- `Death` — exactly 4 frames: standing, hard stagger, kneel with staff falling, fully collapsed readable final pose; no recovery.

### Attack01 visibility revision

The first Attack01 draft was readable as a strip but too subtle during actual combat: its peak footprint was only about 7% larger than neutral, its isolated frost effect was about 8% of peak foreground, and the decisive thrust did not appear until after the 0.35 s combat resolution point.

The revision added this prompt constraint:

> Make the basic attack unmistakable at tiny in-game size. Use a deep backward anticipation followed by a visibly displaced horizontal staff thrust, a large white-hot/cyan ice crescent at least as large as the witch's torso, a second high-contrast impact starburst, and a rightward fragment aftertrail. The character must remain visible in every frame; effects may not replace her or cross cell boundaries. Preserve the accepted Frost Witch identity and keep every effect on the attacker's right.

The generated effect source supplied the charge/ice-wave/starburst/fragment shapes. The accepted RGBA Frost Witch poses were retained as the character layer, so removing the generator's black matte could not damage her dark navy outlines. The final six-frame order deliberately places the ice wave in frame 2 and the starburst in frame 3: at the shared 0.1 s frame duration, both attack peaks are visible by 0.30 s without changing battle timing code.

## Summon prompt

> Create a production-ready transparent pixel-art sprite sheet derived from the supplied Frost Witch sprite. Preserve the exact same character identity and design: tiny chibi proportions, right-facing side view, huge dark navy pointed witch hat, white hair, dark navy cloak and dress, pale blue crystal staff, the same limited navy/cyan/white palette, and the same crisp low-resolution pixel-cluster style. Output exactly SIX distinct animation frames in ONE single horizontal row, arranged left to right with six equal square cells and no gaps or overlap. This is a summon animation: (1) faint icy particles and a low translucent silhouette beginning to appear, (2) body materializing upward, (3) witch rises while lifting the staff, (4) compact cyan frost-rune flash around the staff without hiding the silhouette, (5) glow dissipates and she lowers into stance, (6) the exact neutral standing pose from the reference. Keep her feet locked to one consistent ground baseline and keep body scale/proportions consistent in every frame. Generous transparent padding inside each cell. True transparent alpha background. No environment, no card frame, no text, no labels, no grid lines, no cell borders, no checkerboard, no floor, no cast shadow, no extra characters. Strict sprite-sheet asset, not a presentation mockup. Nearest-neighbor hard pixel edges, no antialiasing, no gradients, no painterly rendering.

The summon output was normalized to six 100×100 cells with nearest-neighbor sampling; source proportions and the shared y=86 foot baseline were preserved.

## Sprite-sheet normalization

- `Idle`, `Walk`, the initial `Attack01` pose source, `Hurt`, and `Death` arrived with a baked light checkerboard. Only edge-connected bright neutral pixels were removed, protecting the enclosed white hair and pale-blue costume pixels.
- `Attack02` and `Summon` arrived with real alpha. Near-invisible alpha noise below 4/255 was cleared before framing.
- Every source was split by its requested conceptual frame count, cropped to square cells, scaled with nearest-neighbor sampling to a shared 44 px standing-character height, and placed into 100×100 output cells around the y=86 ground anchor.
- The canonical first cell of `Frost_Witch_Idle.png` is reused at every one-shot boundary: `Attack01` frames 0/5, `Attack02` frames 0/8, `Hurt` frames 0/3, `Death` frame 0, and `Summon` frame 5. This removes hat-shape, scale, and horizontal-position snaps when an action starts or returns to Idle.
- `Idle`, `Walk`, `Attack01`, `Hurt`, `Death`, and `Summon` now land exactly on y=86 in every frame. `Attack02` uses the same character anchor while its deliberate ground-ice effects extend as low as y=92.
- Intentional motion was retained: attack lunges, hurt recoil, collapsed death poses, and frost effects are not independently re-centered.
- Ice effects may extend a few pixels below the character ground anchor, but no opaque pixel reaches a sheet edge or crosses into a neighboring cell.
