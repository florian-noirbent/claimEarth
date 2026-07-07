# Presentation

`src/presentation` turns committed world data into terrain visuals, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions or terrain collision.

`WorldPresenter` renders terrain with one shader-driven world quad. `WorldGridTexture` mirrors committed terrain IDs, fill amounts, and a reserved lighting byte into a nearest-filtered GPU data texture. Terrain material fill textures are packed into a smooth material-index atlas for shader sampling. `ChunkActivityIndex` only computes visible chunk windows for simulation scheduling.

Keep renderer node counts bounded and refresh the terrain texture only from committed world state.
