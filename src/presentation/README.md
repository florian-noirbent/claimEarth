# Presentation

`src/presentation` turns committed world data into visible chunks, collision edges, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions.

`WorldPresenter` creates one renderer and one collider per visible chunk. `ChunkActivityIndex` tracks dirty static, sand, fluid, and collision layers. `ChunkBuildJob` snapshots packed world data and produces resource-free mesh arrays plus collision-edge updates; `WorldPresenter` applies revision-checked results and creates engine resources on the main thread.

Keep renderer and collider node counts bounded, dirty only affected chunks, and preserve the build-job boundary so chunk work can remain time-sliced or move behind a worker executor later.
