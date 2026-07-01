# Presentation

`src/presentation` turns committed world data into visible chunks, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions or terrain collision.

`WorldPresenter` creates one renderer per visible chunk. `ChunkActivityIndex` tracks dirty static, sand, and fluid visual layers. `ChunkBuildJob` snapshots packed world data and produces resource-free mesh arrays; `WorldPresenter` applies revision-checked results and creates engine resources on the main thread.

Keep renderer node counts bounded, dirty only affected chunks, and preserve the build-job boundary so chunk work can remain time-sliced or move behind a worker executor later.
