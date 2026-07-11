# Simulation

`src/simulation` owns terrain motion over packed world buffers. `TerrainSimulationBackend` is the replaceable backend contract; `RenderTextureSimulationBackend` is the current implementation.

The backend advances the full packed RGBA8 world as a six-pass GPU render-texture cellular automata tick: vertical, down-right, and down-left even connection pairs, followed by the same three odd pairs. It retains the completed even phase in alternating render targets for liquid trail presentation while gameplay reads only the final sixth-pass snapshot. `RunWorldController` advances one pass per gameplay frame while playing. When the sixth pass finishes, the backend reports an exact `TerrainChangeSet`. There is intentionally no CPU/GDScript simulation fallback; headless runs keep the generated terrain static.

Gameplay mutations write through `WorldGrid` first and then notify the backend. Any unfinished tick is cancelled and the patched packed texture becomes the next simulation source, so explosions and item effects never race an in-progress CA pass.
