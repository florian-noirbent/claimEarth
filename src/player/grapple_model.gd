## Pure model for hook launch, attachment, rope length, and swing forces.
class_name GrappleModel
extends RefCounted


var config: GrappleConfig
var state := GrappleState.new()
var _anchor_query: GrappleAnchorQuery


func _init(config_value: GrappleConfig, anchor_query: GrappleAnchorQuery = null) -> void:
	config = config_value
	_anchor_query = anchor_query


func set_anchor_query(anchor_query: GrappleAnchorQuery) -> void:
	_anchor_query = anchor_query


func update(input_frame: GrappleInputFrame, player_position: Vector2, velocity: Vector2, delta: float) -> Vector2:
	if input_frame.hook_released:
		detach()
	elif state.is_attached and not _is_anchor_valid():
		detach()

	if not state.is_attached and input_frame.hook_pressed:
		_try_attach(player_position, input_frame.aim_position)

	if not state.is_attached:
		return velocity

	state.rope_length = clampf(
		state.rope_length + input_frame.rope_axis * config.rope_adjust_speed * delta,
		config.min_rope_length,
		config.max_rope_length
	)

	var rope_vector := player_position - state.anchor.position
	if rope_vector.length_squared() <= 0.001:
		return velocity

	var radial_direction := rope_vector.normalized()
	var tangent := Vector2(-radial_direction.y, radial_direction.x)
	return velocity + tangent * (input_frame.move_axis * config.tangential_acceleration * delta)


func constrain_position(player_position: Vector2, velocity: Vector2, delta: float) -> Dictionary:
	if not state.is_attached or state.anchor == null:
		return {
			"position": player_position,
			"velocity": velocity,
		}

	var rope_vector := player_position - state.anchor.position
	var distance := rope_vector.length()
	if distance <= state.rope_length or distance <= 0.001:
		return {
			"position": player_position,
			"velocity": velocity,
		}

	var radial_direction := rope_vector / distance
	var overshoot := distance - state.rope_length
	var pull_distance := minf(overshoot, config.pull_in_speed * delta)
	var corrected_position := player_position - radial_direction * pull_distance
	var corrected_velocity := velocity
	var radial_speed := corrected_velocity.dot(radial_direction)
	if radial_speed > 0.0:
		corrected_velocity -= radial_direction * radial_speed

	return {
		"position": corrected_position,
		"velocity": corrected_velocity,
	}


func detach() -> void:
	state.is_attached = false
	state.anchor = null
	state.rope_length = 0.0


func _try_attach(player_position: Vector2, target_position: Vector2) -> void:
	if _anchor_query == null:
		return

	var target_delta := target_position - player_position
	var target_distance := target_delta.length()
	if target_distance <= 0.001:
		return

	var projected_target := player_position + target_delta / target_distance * config.effective_attach_range()
	var anchor := _anchor_query.find_anchor(player_position, projected_target)
	if anchor == null:
		return

	var anchor_distance := player_position.distance_to(anchor.position)
	if anchor_distance > config.effective_attach_range():
		return

	state.anchor = anchor
	state.is_attached = true
	state.rope_length = clampf(minf(anchor_distance, config.max_rope_length), config.min_rope_length, config.max_rope_length)


func _is_anchor_valid() -> bool:
	return _anchor_query != null and _anchor_query.is_anchor_valid(state.anchor)
