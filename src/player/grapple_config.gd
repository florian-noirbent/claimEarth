## Resource tuning for grapple range, rope, and swing behavior.
class_name GrappleConfig
extends Resource


@export var min_rope_length := 26.0
@export var max_rope_length := 220.0
@export var rope_adjust_speed := 110.0
@export var tangential_acceleration := 520.0
@export var probe_step := 8.0
@export var attach_range_leeway_ratio := 0.1
@export var pull_in_speed := 900.0


func effective_attach_range() -> float:
	return max_rope_length * (1.0 + attach_range_leeway_ratio)
