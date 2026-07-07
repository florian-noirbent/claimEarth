# Claim Earth Asset Notes

Current art is original repository content stored by runtime use:

- `assets/objects/player_body.svg`
- `assets/objects/small_bomb.svg`
- `assets/objects/large_bomb.svg`
- `assets/objects/flag.svg`
- `assets/ui/help_icon.svg`
- `assets/ui/pause_icon.svg`
- `assets/ui/play_icon.svg`
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
