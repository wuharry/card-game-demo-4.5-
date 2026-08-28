# Dedicated card-art generation

- Generator: Codex built-in `imagegen` (one call per card)
- Minion inputs: one or more finished current minion cards as composition/detail anchors, plus an enlarged
  exact frame from the matching runtime animation sheet as the identity/action authority.
- Non-minion style anchors: use finished cards of the same type (`arcana_*`, `quick_*`, or `ward_*`)
  instead of the Frost Witch. Spell art is a centered, low-detail 32–48 px-style icon with chunky pixels,
  few colors, large dark-navy negative space, and the shared faint stone-floor / distant-mountain backdrop.
- Output naming: `<data/cards slug>_card_art.png`
- Card-art window: landscape `295:207` (approximately 10:7)
- Runtime usage: `CardData.art` with `use_dedicated_art = true`
- Animation invariant: every minion has `Idle` plus `Attack01` for its mandatory normal attack. A minion with an
  active skill additionally has a distinct skill sheet (currently `Attack02` for the generated archetypes).

## Minion shared visual contract

The existing minion cards share a stricter visual language than a generic "pixel-art character" prompt:

- Current card art refines the tiny sprite to roughly three times its logical detail while preserving the sprite's
  chibi proportions and identity. It is not a raw 17×21-pixel frame enlarged to fill the card.
- Use `Idle` frame 0 for a neutral card. A variant that advertises an attack/block/summon identity must use an
  enlarged real frame from that matching animation sheet as an imagegen reference; never invent an unavailable
  action. `tests/extract_sprite_reference.gd` accepts an optional frame index for this.
- Preserve the reference sprite's weapon type/count, armor or clothing shapes, ears/horns/tail/wings, facing
  direction, dominant palette, and pose silhouette. Character identity outranks every style anchor.
- Render crisp deliberate pixel clusters, hard edges, and a dark outer contour with no antialiasing. Match current
  minion cards' medium logical pixel density: visibly finer than the runtime sprite, much coarser than painted art.
- Keep the chibi body proportions from the sprite; do not lengthen limbs, add realistic anatomy, or turn the pose
  into a cinematic illustration.
- Center the character horizontally at roughly 35–45% of canvas width and 52–58% of canvas height, with the lowest
  visible pixel near baseline y≈900 of the 1495×1052 canvas and generous empty space above.
- Reuse `assets/ui/card_art/backgrounds/card_bg_neutral.png`: large empty dark-navy upper field, tiny distant
  mountains near the lower quarter, and a dim stone floor. The background must not recolor the sprite.
- Card-art action and runtime identity must agree: the `.tres` standee and the source animation family used for
  the dedicated art must be the same character. Reject outputs with any extra weapon, missing appendage, changed
  facing, costume drift, palette drift, or action that is absent from that animation family.

## Generated runtime character contract

New character archetypes that do not exist in the Tiny RPG packs use separate identity/skill and normal-attack
source generations:

- The identity/skill source is exactly 3 columns × 2 rows on a transparent background; the top row is a three-frame
  Idle loop and the bottom row is a three-frame `Attack02` skill-action loop.
- The mandatory normal-attack source is exactly 3 columns × 1 row: wind-up, ordinary impact, recovery. It exports
  as `Attack01` and must be a visibly simpler, character-specific physical action rather than a duplicate of the
  `Attack02` skill. A future skill-less minion still requires `Idle` plus `Attack01`, but has no `Attack02`.
- The subject keeps one identity, facing direction, palette, anatomy, equipment count, and foot baseline across all
  cells. Idle uses neutral/down/up timing; each action uses wind-up/impact/recovery timing.
- Source art targets a 28–34 logical-pixel character, hard one-pixel outline, nearest-neighbor pixels, 10–14 flat
  colors, and no scenery, floor, shadow, text, labels, borders, or grid lines.
- `tests/process_generated_sprite_sheet.gd` removes border-connected baked checkerboard pixels, normalizes a shared
  scale/baseline, and exports `<Character>_Idle.png` plus `<Character>_Attack02.png` as 300×100 three-frame sheets.
- `tests/process_generated_action_sheet.gd` performs the same normalization for the 3×1 normal-attack source and
  exports `<Character>_Attack01.png` as a 300×100 three-frame sheet. It also removes border-connected light
  checkerboards or dark generated fills without erasing enclosed black sprite details.
- The processed action sheet then becomes the identity/action authority for that character's dedicated card art.

## Input roles

- Image 1: finished same-type style, pixel density, lighting, and landscape-composition reference
- Image 2 for minions: exact character-design reference (`Idle` or `Flying` sprite sheet)
- Optional Image 2 for non-minions: another finished card of the same type or the icon atlas used only as a
  symbol/color hint; card name and implemented effect remain authoritative

Character identity always outranks the style anchor. If a two-reference generation inherits unrelated Frost Witch
features (white hair, blue hood, ice staff, ice crystals, or snowflake emblems), discard it and make one targeted
correction using the original character reference as the only identity authority. Mechanical single-frame crops may
be used only to clarify a tiny sprite; they are not runtime assets.

## Shared prompt contract

```text
Use case: stylized-concept
Asset type: landscape collectible-card illustration for the same game as Image 1
Primary request: create the dedicated illustration for <card>, preserving <reference identity or implemented effect>.
Style/medium: for minions, polished crisp pixel art matching the character anchor; for non-minions, a simple
retro pixel icon designed at 32–48 px then enlarged nearest-neighbor, using chunky edges and 6–10 flat colors.
Composition/framing: 295:207 landscape ratio; minions use one clear focal subject; non-minions use one isolated
centered icon occupying roughly 35% of the image with large empty dark-navy space.
Constraints: opaque scenic background edge to edge; no card frame, text, logo, UI, or watermark;
not a sprite sheet; no unrelated characters or objects; do not copy the Frost Witch subject.
Avoid: smooth vector shapes, painterly brush texture, photorealism, cropped focal elements, illegible silhouette,
excessive visual noise, and for non-minions especially the high-detail cinematic AI-concept-art look.
```

Each call adds a card-specific subject, action/effect, environment, mood, and palette derived from the
corresponding `CardData` and its existing sprite/icon reference. Generated source files remain in the
Codex image store; project copies in this directory are the assets consumed by Godot.

## Completed-set verification

- Dedicated art resolved from `CardData`: 120/120 cards
- New generated project assets: 119 (the existing Frost Witch is the style anchor and 120th card)
- PNG encoding: 120/120 opaque RGB, edge-to-edge
- Dimensions: 1493x1054 through 1536x1024
- Aspect-ratio range: 1.4165 through 1.5000
- Unique SHA-256 hashes: 120/120
- Missing art references: 0
- `load_steps` mismatches: 0
- `standee` changes introduced by this pass: 0
- High-tier runtime families added: Steel Forge Titan, Abyss Devourer, Thunderhorn Behemoth,
  Tombsea Colossus, Sky Leviathan, and Red Obsidian Ancient Dragon. Their normal attacks use hammer smash,
  claw swipe, horn jab, anchor sweep, tail/body ram, and dragon claw respectively; none uses a kick loop.
