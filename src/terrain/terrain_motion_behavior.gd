@tool
class_name TerrainMotionBehavior
extends Resource


@export var behavior_name := ""
@export var can_fall := false
@export var can_side_down := false
@export var can_side_up := false
@export var displaces_passable_moving_on_fall := false
@export_range(0, 255, 1) var fall_rate := 0
@export_range(0, 255, 1) var side_down_rate := 0
@export_range(0, 255, 1) var side_up_rate := 0
@export_range(0, 255, 1) var min_fill_difference := 0
@export_range(0, 255, 1) var side_flow_offset := 50
@export_range(0, 255, 1) var side_up_source_threshold := 128
