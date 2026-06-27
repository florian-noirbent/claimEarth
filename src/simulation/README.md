# Simulation

`src/simulation` owns terrain motion over packed world buffers. `TerrainSimulationBackend` is the replaceable backend contract; `CooperativeChunkBackend` is the current implementation.

The backend copies committed cells/fill into working buffers, advances active cells within a frame budget, then commits exact `TerrainChangeSet` results when a tick completes. `RunWorldController` schedules chunks around the visible depth window, while external terrain mutations wake nearby simulation cells and cancel unfinished snapshots.

Per-cell behavior is split into data-only collaborators: `TerrainSimulationContext` wraps working buffers and wake/touch sets, `TerrainMotionStepper` owns fall/side-down/side-up ordering, and `TerrainTransferSolver` owns transfer math, liquid contact, and falling displacement. Keep these classes free of nodes, signals, renderer, physics-body, UI, and mutable resource dependencies so the step remains portable to a future worker boundary.
