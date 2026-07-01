## Defines dirty and render layer bits used by terrain presentation.
class_name TerrainLayerMask
extends RefCounted


const NONE := 0
const STATIC_VISUAL := 1 << 0
const SAND_VISUAL := 1 << 1
const FLUID_VISUAL := 1 << 2
const COLLISION := 1 << 3
const ALL_VISUAL := STATIC_VISUAL | SAND_VISUAL | FLUID_VISUAL
const ALL := ALL_VISUAL
