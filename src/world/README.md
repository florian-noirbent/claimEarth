# World

`src/world` contains packed terrain state and grid math. `WorldGrid` is authoritative and stores committed/working terrain IDs plus committed/working fill amounts in packed byte arrays.

`WorldDimensions`, `HexCoord`, and presentation `HexMetrics` define indexing and hex coordinate conversion. `CellChange`, `TerrainChangeSet`, and `DirtyRegion` describe what changed so simulation and presentation can update exact regions.

World data stays policy-free: gameplay rules belong in terrain, simulation, item, or player systems.
