## Resource tuning for ground, air, jump, and step-up movement.
class_name PlayerMovementConfig
extends Resource


@export var max_ground_speed := 280.0
@export var ground_acceleration := 1800.0
@export var ground_friction := 2200.0
@export var max_air_speed := 280.0
@export var air_acceleration := 900.0
@export var gravity := 1400.0
@export var terminal_velocity := 900.0
@export var jump_velocity := -420.0
@export var coyote_time_seconds := 0.12
@export var jump_buffer_seconds := 0.12
@export var impact_hazard_minimum_speed := 500.0
@export var impact_hazard_recovery_seconds := 3.0
@export var impact_hazard_icon: Texture2D
@export var impact_hazard_bar_color := Color(0.96, 0.72, 0.20, 1.0)
@export var impact_hazard_display_order := 5
@export var medium_impact_speed := 620.0
@export var lethal_impact_speed := 840.0
@export var ragdoll_seconds := 1.0
@export var ragdoll_spin_speed := 8.0
