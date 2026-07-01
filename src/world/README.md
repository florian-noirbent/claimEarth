# World

`src/world` contains packed terrain state and grid math. `WorldGrid` is authoritative and stores committed/working terrain IDs plus committed/working fill amounts in packed byte arrays.

`WorldDimensions`, `HexCoord`, and presentation `HexMetrics` define indexing and hex coordinate conversion. `CellChange`, `TerrainChangeSet`, and `DirtyRegion` describe what changed so simulation and presentation can update exact regions.

`TerrainCollisionQuery` and `TerrainBodyMotionSolver` provide reusable grid-backed collision and circular body motion against committed terrain. They depend on compiled terrain solidity/fill rules, but remain free of scene nodes and player-specific input.
