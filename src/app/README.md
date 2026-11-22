# App

`src/app` owns runtime composition and run-state orchestration. `AppRoot` is the persistent shell: it wires UI, audio, scores, leaderboard access, and the active `RunSession`.

`RunSession` is disposable per gameplay run. Its controllers keep ownership narrow: `RunWorldController` owns generation, initial GPU settlement, player lifetime, simulation scheduling, camera bounds, and presentation; `RunItemController` owns inventory, generated chests and explosive barrels, projectiles, explosions, and flag resolution; `ScoreController` owns local saves and leaderboard workflows. `RunSession` creates the run's `GrappleTargetRegistry` and hands it to both the world controller's hook query and the item controller, which registers barrels as hook targets. `RunItemController` is the item facade: `RunItemRuntimeTuning` compiles perk snapshots into typed item policy, while `RunItemRewards` owns the single pending chest or geode selection transaction.

Use typed signals for cross-boundary events. UI emits intent through `AppUiController`; gameplay controllers emit outcomes; `AppRoot` maps both to `RunPhase` transitions and owns the terminal-outcome lock so death, planted flag, and destroyed flag cannot race.

Audio and visual feedback flows one way: owners emit typed facts, `RunSession` relays them, and `FeedbackRouter` calls one named method per moment on `AudioDirector` and `GameplayFeedback`. Gameplay code never calls a sink.
