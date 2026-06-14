class_name GenerationProfile
extends Resource


@export var width := 100
@export var depth := 2000
@export var base_octaves := 4
@export var base_frequency_x := 0.045
@export var base_frequency_y := 0.012
@export var base_gain := 0.58
@export var cave_threshold := 0.26
@export var dirt_threshold := 0.5
@export var pocket_octaves := 3
@export var pocket_frequency_x := 0.075
@export var pocket_frequency_y := 0.03
@export var sand_threshold := 0.72
@export var water_threshold := 0.81
@export var lava_threshold := 0.89
@export var water_depth_start_ratio := 0.16
@export var lava_depth_start_ratio := 0.45
@export var spawn_width := 10
@export var spawn_height := 4
@export var spawn_margin_top := 0
@export var max_retries := 4


func create_dimensions() -> WorldDimensions:
	return WorldDimensions.new(width, depth)
