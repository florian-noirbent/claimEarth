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
- `assets/objects/small_bomb.svg`
- `assets/objects/large_bomb.svg`
- `assets/objects/flag.svg`
- `assets/objects/pickaxe.svg`
- `assets/objects/shovel.svg`
- `assets/objects/flare.svg`
- `assets/objects/water_bottle.svg`
- `assets/objects/explosive_barrel.svg` — placeholder red barrel with dark hoops and a yellow warning triangle; the generated barrel scene scales it to 2.4 hex radii wide and spins it as the barrel rolls.
- `assets/objects/chest.png` — item-chest world sprite, centered in a rotatable visual root and rendered as one scaled image across a 2x2 staggered hex footprint.
- `assets/objects/perk.png` — authored perk-relic art reserved for the future perk reward workflow.
- `assets/ui/help_icon.svg`
- `assets/ui/fullscreen_icon.svg`
- `assets/ui/pause_icon.svg`
- `assets/ui/play_icon.svg`
- `assets/ui/hazard_suffocation.svg` — original dark-outlined blue bubble icon for the generic suffocation meter.
- `assets/ui/hazard_lava.svg` — original dark-outlined orange flame with a yellow core, reused by the shared Cooked heat meter for Lava and Steam.
- `assets/ui/hazard_impact.svg` — white radial collision burst for the accumulating impact meter.
- `assets/ui/statistics/*.svg` — original statistics page icons: `runs.svg`, `victory.svg`,
  `streak.svg`, `time.svg`, `depth.svg`, `distance.svg`, `death.svg`, `items.svg`,
  `bounds.svg` (left-the-map death cause), and `unknown.svg` (fallback for unlisted keys).
  The victory icon also marks the main-menu Statistics button.
- `assets/ui/title.png`
- `assets/ui/menu_background.jpg`
- `assets/terrain/background.jpg`
- `assets/terrain/dirt.jpg`
- `assets/terrain/grassBand.png`
- `assets/terrain/stone.jpg`
- Stone and dirt surfaces use looping textures from `TerrainMaterial` resources.
  The shader terrain renderer packs those textures into a smooth material-index atlas.
  Edge resources are retained for deferred visual polish.
- Gameplay effects are generated procedurally by `GameplayFeedback`.
- Audio cues are synthesized at runtime by `AudioDirector`.

The menu background is a diffusion-model generated PNG created with ComfyUI using
`zavychromaxl_v80.safetensors`. It depicts a stylized underground cave scene with
water, sand, stone, and distant lava glow, and intentionally contains no text,
logo, UI, or characters.
