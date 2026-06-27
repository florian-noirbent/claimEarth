# Claim Earth Asset Notes

Current art is original repository content created as SVG or through procedural
drawing/audio code inside the project.

- `assets/vector/player_body.svg`
- `assets/vector/small_bomb.svg`
- `assets/vector/large_bomb.svg`
- `assets/vector/flag.svg`
- `assets/vector/help_icon.svg`
- `assets/vector/pause_icon.svg`
- `assets/vector/play_icon.svg`
- `assets/generated/menu_background.png`
- `assets/generated/title.png`
- Terrain surfaces/outlines are generated procedurally by `WorldChunkRenderer`.
- Gameplay effects are generated procedurally by `GameplayFeedback`.
- Audio cues are synthesized at runtime by `AudioDirector`.

The menu background is a diffusion-model generated PNG created with ComfyUI using
`zavychromaxl_v80.safetensors`. It depicts a stylized underground cave scene with
water, sand, stone, and distant lava glow, and intentionally contains no text,
logo, UI, or characters.
