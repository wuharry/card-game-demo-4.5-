# Frost Witch asset generation

- Generator mode: Codex built-in `imagegen`
- Final card art: `res://assets/ui/card_art/Frost_Witch_CardArt.png`
- Accepted character-only card-art source: `res://assets/ui/card_art/Frost_Witch_CardArt_Source.png`
- Final idle sheet: `res://assets/characters/frost_witch/Frost_Witch_Idle.png`
- Exact static fallback: `res://assets/characters/frost_witch/Frost_Witch_Idle_Static.png`
- Final summon sheet: `res://assets/characters/frost_witch/Frost_Witch_Summon.png`

## Card-art prompt

> Create a finished landscape card illustration using the supplied detailed Frost Witch as the exact character reference. Preserve her recognizable design: enormous dark navy pointed witch hat, long white hair, navy cloak and dress, pale-blue ice crystal staff, elegant young frost mage, detailed pixel-art rendering. Compose for a 295:207 landscape card-art window (approximately 10:7): the witch is the clear focal point, shown about three-quarter/full body with her entire hat tip and staff crystal safely inside the frame, centered slightly right, readable at card size. Add a cohesive icy moonlit setting behind her: frozen ruined arches, drifting snow, blue aurora glow, foreground frost crystals, deep navy shadows and cyan highlights. Strong silhouette and value separation; detailed but not visually noisy. No card frame, no text, no logo, no UI, no watermark. Opaque scenic background filling the full image edge to edge. Crisp polished high-resolution pixel art, deliberate pixel clusters, no smooth vector look, no painterly brush texture.

## Idle prompt

> Create a production-ready transparent pixel-art IDLE sprite sheet derived from the supplied Frost Witch sprite. Preserve the exact same character identity and design: tiny chibi proportions, right-facing side view, oversized dark navy pointed witch hat, white hair, dark navy cloak and dress, pale blue crystal staff, same limited navy/cyan/white palette, same crisp low-resolution pixel-cluster style. Output exactly SIX animation frames in ONE single horizontal row, six equal square cells, left to right. Motion is a very subtle looping idle: gentle one-pixel-like breathing/bob, slight hat-tip and cloak-edge sway, tiny staff crystal pulse; frame 6 must flow seamlessly back to frame 1. Keep feet locked to the same ground baseline, character scale and silhouette consistent, and staff always on the right. Generous transparent padding inside every cell. True transparent alpha background. No environment, no text, no labels, no grid lines, no cell borders, no checkerboard, no floor, no cast shadow, no extra characters. Strict sprite-sheet asset, not a presentation mockup. Nearest-neighbor hard pixel edges, no antialiasing, no gradients, no painterly rendering.

The generated idle draft baked in a light checkerboard. Post-processing removed only the edge-connected neutral background, zeroed transparent RGB, normalized it to six 100×100 cells, and aligned every foot baseline to y=86. The static fallback is retained unchanged from the accepted sprite design.

## Summon prompt

> Create a production-ready transparent pixel-art sprite sheet derived from the supplied Frost Witch sprite. Preserve the exact same character identity and design: tiny chibi proportions, right-facing side view, huge dark navy pointed witch hat, white hair, dark navy cloak and dress, pale blue crystal staff, the same limited navy/cyan/white palette, and the same crisp low-resolution pixel-cluster style. Output exactly SIX distinct animation frames in ONE single horizontal row, arranged left to right with six equal square cells and no gaps or overlap. This is a summon animation: (1) faint icy particles and a low translucent silhouette beginning to appear, (2) body materializing upward, (3) witch rises while lifting the staff, (4) compact cyan frost-rune flash around the staff without hiding the silhouette, (5) glow dissipates and she lowers into stance, (6) the exact neutral standing pose from the reference. Keep her feet locked to one consistent ground baseline and keep body scale/proportions consistent in every frame. Generous transparent padding inside each cell. True transparent alpha background. No environment, no card frame, no text, no labels, no grid lines, no cell borders, no checkerboard, no floor, no cast shadow, no extra characters. Strict sprite-sheet asset, not a presentation mockup. Nearest-neighbor hard pixel edges, no antialiasing, no gradients, no painterly rendering.

The summon output was normalized to six 100×100 cells with nearest-neighbor sampling; source proportions and the shared y=86 foot baseline were preserved.
