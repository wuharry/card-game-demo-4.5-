# Dedicated card-art generation

- Generator: Codex built-in `imagegen` (one call per card)
- Style anchor: `Frost_Witch_CardArt.png`
- Output naming: `<data/cards slug>_card_art.png`
- Card-art window: landscape `295:207` (approximately 10:7)
- Runtime usage: `CardData.art` with `use_dedicated_art = true`
- Animation invariant: `CardData.standee` and every Idle/Summon/Attack sheet remain unchanged

## Input roles

- Image 1: finished style, pixel density, lighting, and landscape-composition reference
- Image 2 for minions: exact character-design reference (`Idle` or `Flying` sprite sheet)
- Image 2 for non-minions: current icon atlas used only as a symbol/color hint; card name and implemented effect remain authoritative

Character identity always outranks the style anchor. If a two-reference generation inherits unrelated Frost Witch
features (white hair, blue hood, ice staff, ice crystals, or snowflake emblems), discard it and make one targeted
correction using the original character reference as the only identity authority. Mechanical single-frame crops may
be used only to clarify a tiny sprite; they are not runtime assets.

## Shared prompt contract

```text
Use case: stylized-concept
Asset type: landscape collectible-card illustration for the same game as Image 1
Primary request: create the dedicated illustration for <card>, preserving <reference identity or implemented effect>.
Style/medium: polished high-resolution crisp pixel art matching Image 1 in deliberate pixel clusters,
silhouette clarity, detail density, edge treatment, and finished game-card quality.
Composition/framing: 295:207 landscape ratio; one clear focal subject/event; keep all important anatomy,
weapons, spell effects, and symbols inside an 8–10% safe margin.
Constraints: opaque scenic background edge to edge; no card frame, text, logo, UI, or watermark;
not a sprite sheet; no unrelated characters or objects; do not copy the Frost Witch subject.
Avoid: smooth vector shapes, painterly brush texture, photorealism, cropped focal elements,
illegible silhouette, and excessive visual noise.
```

Each call adds a card-specific subject, action/effect, environment, mood, and palette derived from the
corresponding `CardData` and its existing sprite/icon reference. Generated source files remain in the
Codex image store; project copies in this directory are the assets consumed by Godot.

## Completed-set verification

- Dedicated art resolved from `CardData`: 58/58 cards
- New generated project assets: 57 (the existing Frost Witch is the style anchor and 58th card)
- PNG encoding: 58/58 opaque RGB, edge-to-edge
- Dimensions: 1495x1052 through 1503x1046
- Aspect-ratio range: 1.4211 through 1.4369
- Unique SHA-256 hashes: 58/58
- Missing art references: 0
- `load_steps` mismatches: 0
- `standee` changes introduced by this pass: 0
