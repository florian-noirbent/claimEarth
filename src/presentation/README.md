# Presentation

`src/presentation` turns committed world data into terrain visuals, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions or terrain collision.

`WorldPresenter` renders terrain with one shader-driven world quad. It samples the current `WorldGrid` or simulation texture directly while terrain style data and material fill textures are packed into shader lookup textures.

Keep renderer node counts bounded and refresh the terrain texture only through `WorldGrid` or the active simulation backend texture.
