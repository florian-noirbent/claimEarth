@tool
## Resource catalog of terrain definitions available to a run.
class_name TerrainCatalog
extends Resource


@export var definitions: Array = []
## Ordered, resource-authored pair reactions evaluated by the terrain simulator.
@export var contact_reactions: Array = []
