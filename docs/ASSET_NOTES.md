# Claim Earth Asset Notes

Current art is original repository content stored by runtime use:

- `assets/objects/player/*.png` — the 16 cutout parts of the player rig (head, torso
  with scarf, backpack, pelvis, and an upper arm, forearm, hand, thigh, shin, and boot
  for each side). They are imported with mipmaps because the rig draws them far below
  their painted size. `tools/extract_player_parts.py` strengthens their saturation
  and lifts their dark tones so the small on-screen character stays readable, and
  leaves a transparent margin around each part for the outline shader.
  `scenes/player/player_rig.tscn` assembles and animates them, thickens the limbs,
  darkens the far-side (`*_left`) limbs, and outlines the whole body.
- `assets/objects/player/source/` (ignored by Godot) holds the art sources:
  `reference.png` is the original character painting, `template/` and
  `parts_sheet.png` are the redraw template sliced from it, and `parts_redraw.png`
  is the repainted sheet the part textures are extracted from.
- `assets/objects/grapple/rope.svg` — one seamless tile of the braided grappling
  rope with a dark outline; `scenes/player/player_presentation.tscn` repeats it along
  the rope. `claw_jaw.svg` (one steel jaw, mirrored for the other) and `claw_hub.svg`
  (hinge and brass rope sleeve) form the claw. All three are imported with mipmaps
  because they are drawn far below their authored size.
- `assets/objects/*.svg` — item art, used both as toolbar/reward icons and as the
  world sprite of the thrown item. They are imported with mipmaps because world
  sprites are drawn at roughly a sixth of their texture size.
  - `small_bomb.svg` — round orange bomb with a steel cap and a sparking fuse.
  - `large_bomb.svg` — three strapped red dynamite sticks with a sparking fuse.
  - `flag.svg` — upright yellow banner with a red disc on a wooden pole. The flag
    factory offsets and turns it so the pole tip leads the throw.
  - `pickaxe.svg`, `shovel.svg` — bright steel heads on wooden handles, with a red
    grip and a yellow T-grip respectively.
  - `flare.svg` — magenta stick with a burning tip.
  - `water_bottle.svg` — round corked flask of blue water.
  - `acid_bottle.svg` — conical lab flask of bubbling green acid with a dark stopper.
  - `excavator.svg` — orange walking drill with its bit pointing down.
  - `explosive_barrel.svg` — bulged red drum with steel hoops and a yellow warning
    plate, centered in its square so it can spin; the generated barrel scene scales it
    to 2.4 hex radii wide.
- `assets/objects/chest.png` — item-chest world sprite, centered in a rotatable visual root and rendered as one scaled image across a 2x2 staggered hex footprint.
- `assets/objects/perk.png` — authored perk-relic art reserved for the future perk reward workflow.
- `assets/ui/help_icon.svg`, `fullscreen_icon.svg`, `pause_icon.svg`, `play_icon.svg`,
  `settings_cog.svg` — gold button glyphs.
- `assets/ui/hazard_*.svg` — hazard meter icons, colored like their meter bars:
  `hazard_suffocation.svg` (blue bubbles), `hazard_lava.svg` (orange flame with a
  yellow core, shared by the Cooked meter for Lava and Steam), `hazard_acid.svg`
  (green droplet), `hazard_poison.svg` (yellow-green gas cloud with a face), and
  `hazard_impact.svg` (pale collision burst, kept near white because the meter tints it).
- `assets/ui/statistics/*.svg` — statistics page icons: `runs.svg` (miner helmet),
  `victory.svg` (trophy), `streak.svg`, `time.svg`, `depth.svg`, `distance.svg`,
  `death.svg`, `items.svg` (backpack), `bounds.svg` (left-the-map death cause), and
  `unknown.svg` (fallback for unlisted keys). The victory icon also marks the
  main-menu Statistics button.
- `assets/ui/perks/*.svg` — one round badge per perk: a dark rim, a light ring, a
  tinted disc, and an outlined symbol.
- `assets/ui/title.png`
- `assets/ui/menu_background.jpg`
- `assets/terrain/background.jpg`
- `assets/terrain/dirt.jpg`
- `assets/terrain/grassBand.png`
- `assets/terrain/stone.jpg`
- Stone and dirt surfaces use looping textures from `TerrainMaterial` resources.
  The shader terrain renderer packs those textures into a smooth material-index atlas.
  Edge resources are retained for deferred visual polish.
- All SVG art shares one hand-drawn style: a dark warm outline (`#1a0f0a`, about
  6% of the icon size, round joins), gradient shading lit from the top left with one
  highlight and one core shadow, and a saturated identity color per item over wood,
  steel, and gold neutrals. The files use only paths, basic shapes, gradients, opacity,
  and transforms, because Godot rasterizes them with ThorVG; glows are stacked
  translucent shapes. Each icon keeps its square canvas (64, 96, or 128 units) and is
  checked at 14 to 32 pixels on dark, grey, and sky backgrounds.
- Gameplay effects are generated procedurally by `GameplayFeedback`.
- There are no audio files. Every sound effect is synthesized from code by
  `SfxRecipes` on the `AudioSynth` toolkit, rendered once at 32 kHz mono 16-bit, and
  mixed by `config/audio/audio_tuning.tres`. The set aims for a warm, punchy cave
  character: sine sub thumps with pitch drops, filtered noise, FM metal and bells,
  soft saturation, and short comb reflections for space. Music has its own `Music`
  bus and no content yet.

The menu background is a diffusion-model generated PNG created with ComfyUI using
`zavychromaxl_v80.safetensors`. It depicts a stylized underground cave scene with
water, sand, stone, and distant lava glow, and intentionally contains no text,
logo, UI, or characters.
