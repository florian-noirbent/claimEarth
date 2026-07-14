# Simulation

`src/simulation` owns terrain motion over packed world buffers. `TerrainSimulationBackend` is the replaceable backend contract; `RenderTextureSimulationBackend` is the current implementation.

The backend advances the full packed RGBA8 world as a six-pass GPU render-texture cellular automata tick: vertical, down-right, and down-left even connection pairs, followed by the same three odd pairs. `RunWorldController` accrues a fixed 60 passes per active gameplay second, skips work on high-frame-rate frames, and can schedule up to the six remaining passes of a tick after a slow frame. Fractional and excess debt is retained, while pause, run exit, and focus loss reset the clock.

Two alternating banks contain six `SubViewport` slots each. A catch-up batch chains each slot from the previous logical pass, retains pass three for liquid trail presentation, and exposes pass six as the final terrain texture. One post-draw callback completes the ordered batch after Godot's normal viewport render phase. Simulation never crosses a tick boundary in a batch or forces a global redraw. When the sixth pass finishes, the backend publishes a revisioned snapshot commit and never scans the full grid on the CPU to construct a diff. There is intentionally no CPU/GDScript simulation fallback; headless runs keep the generated terrain static.

Gameplay mutations write through `WorldGrid` first and then notify the backend. Any unfinished tick is cancelled and the patched packed texture becomes the next simulation source, so explosions and item effects never race an in-progress CA pass.
