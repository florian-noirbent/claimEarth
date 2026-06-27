# Items

`src/items` owns item definitions, inventory, projectile behavior, trajectories, and terrain explosions. Items are registered through `config/items/catalog.tres`.

`ItemDefinition` points to an `ItemActionFactory`; factories create polymorphic `ItemAction` instances used by `RunItemController`. Selection, HUD inventory, throws, and resolution should remain generic over item type.

`ItemProjectile` owns flight, terrain sampling, fuse/bounce behavior, and resolution signals. `ExplosionService` mutates committed terrain through blast strategies and returns exact change sets so presentation and simulation can react.
