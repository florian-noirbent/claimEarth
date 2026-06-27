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
