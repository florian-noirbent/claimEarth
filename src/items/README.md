# Items

`src/items` owns item definitions, inventory, projectile behavior, trajectories, and terrain explosions. Items are registered through `config/items/catalog.tres`.

`ItemDefinition` points to an `ItemActionFactory`; factories create polymorphic `ItemAction` instances used by `RunItemController`. Selection, HUD inventory, throws, and resolution should remain generic over item type.

`WorldRigidBody2D` owns terrain-aware gravity, collision response, and radial blast impulses for thrown items and autonomous world objects. `ItemProjectile` adds item resolution and fuse behavior; the excavator uses the same body and explosive receiver, so blast pulses and chain reactions remain type-agnostic. `ExplosionService` mutates committed terrain through blast strategies and returns exact change sets so presentation and simulation can react.
