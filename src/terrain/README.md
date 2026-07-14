# Terrain

`src/terrain` defines terrain identity and behavior contracts. Authoring data lives in `TerrainDefinition` resources registered through `config/terrain/catalog.tres`; runtime code resolves them through `TerrainRegistry`.

Behavior is resource-driven. Motion, hazard, and blast response are strategy resources, and call sites must not branch on terrain IDs, display names, script classes, or resource paths. Add new terrain by adding resources, registering the definition, and extending registry/simulation/rendering tests.

`CompiledTerrainData` is the hot-loop lookup table produced from the registry. It maps stable terrain IDs to compact motion, collision, passability, visual, transfer, and player-viscosity values so simulation, rendering, collision, and dirtying do not chase live resources. Viscosity is authored on motion resources and remains independent of CA transfer rates.
