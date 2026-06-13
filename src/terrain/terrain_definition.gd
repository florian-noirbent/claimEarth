class_name TerrainDefinition
extends Resource


@export_range(0, 255) var stable_id := 0
@export var display_name := ""
@export var is_solid := false
@export var is_passable := false
@export var is_hookable := false
@export var is_destructible := false
@export var debug_color := Color.WHITE
@export var visual_style: Resource
@export var motion_behavior: TerrainMotionBehavior
@export var hazard_behavior: TerrainHazardBehavior
@export var blast_reaction: BlastReaction


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if display_name.is_empty():
		errors.append("display_name is required")
	if motion_behavior == null:
		errors.append("%s is missing motion_behavior" % _identity())
	if hazard_behavior == null:
		errors.append("%s is missing hazard_behavior" % _identity())
	if blast_reaction == null:
		errors.append("%s is missing blast_reaction" % _identity())
	if is_solid == is_passable:
		errors.append("%s must be either solid or passable" % _identity())
	return errors


func _identity() -> String:
	return "terrain[%d:%s]" % [stable_id, display_name]
