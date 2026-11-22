# Presentation

`src/presentation` turns committed world data into terrain visuals, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions or terrain collision.

`WorldPresentationConfig` is the shared visual-tuning resource for playable runs and the static World Gen preview. It owns terrain/fluid shader controls and the cave/sky/grass backdrop settings. Editing it in the Godot Inspector updates active presenters immediately.

`WorldPresenter` renders terrain with one shader-driven world quad. It samples the current `WorldGrid` or simulation texture directly while terrain style data and material fill textures are packed into shader lookup textures. Generated grids start with dark lighting; the static World Gen editor preview uses a presentation-only full-bright override because it never advances terrain simulation. The main menu uses separate static art.

`GameplayFeedback` turns routed feedback moments into world effects and camera shake
requests. Its `WorldEffects` child plays `EffectRecipe` resources from the
`GameplayEffectLibrary` (`config/presentation/gameplay_effects.tres`, recipes under
`config/presentation/effects/`) into two shared `EffectBatch` particle layers under
`src/presentation/effects`. An `EffectEmitter` describes one particle layer of a
recipe. Effects add no nodes, stay inside a fixed particle budget, draw above the
world and unaffected by cave darkness, and end on their own. Change a look by editing
its recipe resource; add a shape or motion in `EffectEmitter` and `EffectBatch`.
The effects of the player's death sequences are recipes too, stored by cue key in
`death_cue_by_key` and played when the sequence asks for them.

Keep renderer node counts bounded and refresh the terrain texture only through `WorldGrid` or the active simulation backend texture.
