# Generation

`src/generation` builds deterministic `WorldGrid` instances from a resource-driven pass stack. `GenerationProfile` owns the ordered passes and the number of complete GPU simulation ticks used to settle a playable map before attachment; the default profile lives in `config/generation/default_profile.tres`.

Each pass receives a `GenerationContext` and may be reordered, duplicated, disabled, or tuned through resources. Generation must preserve seed determinism, valid registered terrain IDs, spawn safety, and the configured bottom lava fill.

The generated-item pass stays type-agnostic: a `GeneratedItemPlacementDefinition` accepts or skips candidate anchors, prepares terrain, and records a typed spawn (`GeneratedItemChestSpawn` for chests and geodes, `GeneratedExplosiveBarrelSpawn` for barrels) that the context and `WorldGenerationResult` carry to the run. Selectable placement definitions are listed in `config/generation/item_catalog.tres`.

`WorldGenerationTask` wraps generation with progress reporting and cancellation tolerance. Editor previews use the same generator and presenter path without spawning the player, items, or simulation.
