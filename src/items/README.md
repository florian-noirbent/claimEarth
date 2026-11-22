# Items

`src/items` owns item definitions, inventory, projectile behavior, trajectories, and terrain explosions. Items are registered through `config/items/catalog.tres`.

`ItemDefinition` points to an `ItemActionFactory`; factories create polymorphic `ItemAction` instances used by `RunItemController`. Selection, HUD inventory, throws, and resolution should remain generic over item type.

`WorldRigidBody2D` owns terrain-aware gravity, collision response, and radial blast impulses for thrown items and autonomous world objects. A body config may name a `visual_texture` with an optional `visual_scale`, `visual_rotation_degrees`, `visual_offset`, `visual_mirror_with_heading`, and `visual_settle_speed`; the sprite then replaces the fallback polygon, and thrown items pass their own icon. `ItemProjectile` adds item resolution and fuse behavior; the excavator uses the same body and explosive receiver, so blast pulses and chain reactions remain type-agnostic. `ExplosionService` mutates committed terrain through blast strategies, deposits each definition's origin emission, and returns exact change sets so presentation and simulation can react.

`ExplosiveBarrel` is a generated world object on the same body: it moves as a circle through `TerrainBodyMotionSolver`, composes a `WorldExplosive2D` that also arms anywhere in a blast radius, and detonates on its definition's terrain tags or a hard impact. `ExplosiveBarrelDefinition` holds its placement rules and tuning, and `ExplosiveBarrelGrappleTarget` lets the hook pull it without player code knowing its type. Chests and barrels share `WorldBodySleep`, and `RunItemController` delivers their terrain wake checks through one `WorldBodySleepScheduler`.
