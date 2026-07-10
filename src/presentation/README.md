# Presentation

`src/presentation` turns committed world data into terrain visuals, markers, and effects. Presentation code consumes `WorldGrid`; it does not own gameplay decisions or terrain collision.

`WorldPresentationConfig` is the shared visual-tuning resource for playable runs and the static World Gen preview. It owns terrain/fluid shader controls and the cave/sky/grass backdrop settings. Editing it in the Godot Inspector updates active presenters immediately.

`WorldPresenter` renders terrain with one shader-driven world quad. It samples the current `WorldGrid` or simulation texture directly while terrain style data and material fill textures are packed into shader lookup textures. The World Gen preview uses the same presenter and backdrop configuration but never advances terrain simulation.

Keep renderer node counts bounded and refresh the terrain texture only through `WorldGrid` or the active simulation backend texture.
