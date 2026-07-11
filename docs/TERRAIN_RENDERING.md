# Terrain Rendering

`WorldPresenter` draws the whole terrain as one shader-driven quad. It is the
only terrain renderer in a run: it does not create a node, mesh, or collider per
cell. This keeps the Web/Compatibility path bounded while the fragment shader
turns world pixels into flat-top hex cells.

## Data flow

`WorldGrid` remains the CPU-authoritative packed snapshot. Its RGBA8 cells use
`R` for stable terrain ID, `G` for fill, `B` for light, and `A` for reserved
flags. During a run, `RenderTextureSimulationBackend` supplies the final GPU
terrain texture to the presenter. The presenter also receives the retained even
simulation phase only to draw a proven vertical liquid trail through final-air
cells. Gameplay and collision continue to read committed `WorldGrid` data.

Terrain definitions are compiled into ID-indexed lookup textures. Presentation
properties contain terrain colour, atlas material selection and scale, density,
motion and edge-style inputs; their exact channel assignment is defined beside
the packing code in `WorldPresenter`. Material fill textures are packed into a
single atlas. Keep changes to packing, uniforms, shader sampling, and presenter
tests together.

## Shader layout

`world_presenter.gdshader` is the orchestration entry point: uniforms, vertex
placement, terrain-material and boundary decisions, and the final fragment
sequence. Its includes separate pure hex-grid math, world/terrain sampling, and
lighting. Includes are expanded into one compiled shader, so this organization
does not add a draw call or render pass.

The fragment path is deliberately ordered as follows:

1. Convert the world pixel to an offset cell and local hex position.
2. Sample the current cell and render its material, fill, and trail state.
3. Resolve a boundary only inside the edge/corner influence band, then reuse the
   same terrain-material function for the selected neighbouring cell.
4. Apply edge outline and hex-light interpolation to the final terrain colour.

Keep simulation rules (pair ownership, transfer, and pass resolution) in the
simulation shader. Only hex coordinate/topology helpers are shared with the
presenter shader.

## Canonical hex directions

All CPU and GPU topology uses `HexCoord.NEIGHBOR_OFFSETS` order. Directions are
axial `(q, r)` deltas and physical labels for the flat-top, odd-q grid:

| Direction | Axial delta | Physical neighbour |
| --- | --- | --- |
| `0` | `(1, 0)` | down-right |
| `1` | `(1, -1)` | up-right |
| `2` | `(0, -1)` | up |
| `3` | `(-1, 0)` | up-left |
| `4` | `(-1, 1)` | down-left |
| `5` | `(0, 1)` | down |

Use named constants in shader code instead of local, reordered direction lists.
`HexMetrics.edge_corner_indices_for_direction()` follows this same order. Offset
coordinates are only a storage/display mapping: convert with odd-q helpers before
performing axial distance or neighbour calculations.

## Performance and benchmark workflow

The expensive work is fragment work, particularly boundary/corner evaluation,
lighting topology, lookup-texture reads, and liquid animation. Keep the one-quad
architecture and measure before changing visual algorithms.

Use `benchmark_world_presenter.ps1` to capture a reference before a renderer
change, then compare the same build, fixed resolution, deterministic fixtures,
camera positions, warm-up period, and VSync setting. The current harness times
solid, boundary-heavy, dark/air, moving-sand, liquid-heavy, and representative
generated-world views in native Compatibility, and captures a Chromium Web-export
screenshot as a browser smoke reference. Store machine-specific samples and
screenshots under ignored `build/benchmarks/`.

Compare median and tail frame time, not only FPS. Inspect screenshots beside the
reference: edge ownership, rounded corners, lighting, partial fills, trails, and
liquid readability must remain perceptually equivalent. A change is rejected if
it causes a repeatable regression in any representative scenario.
