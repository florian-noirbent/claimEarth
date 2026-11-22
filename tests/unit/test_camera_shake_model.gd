extends GutTest


const STEP := 1.0 / 60.0


func test_a_request_adds_trauma_and_moves_the_camera() -> void:
	var model := CameraShakeModel.new()

	assert_false(model.is_active())
	assert_eq(model.offset(), Vector2.ZERO)

	model.add_shake(model.max_offset * 0.25)
	model.advance(STEP)

	assert_almost_eq(model.trauma, 0.5 * exp(-model.trauma_decay * STEP), 0.0001, "Trauma is the root of the asked share of the full offset")
	assert_true(model.is_active())
	assert_gt(_peak_offset(model, 30), 0.0)


func test_requests_accumulate_and_trauma_is_capped() -> void:
	var model := CameraShakeModel.new()

	model.add_shake(model.max_offset * 0.09)
	var single := model.trauma
	model.add_shake(model.max_offset * 0.09)
	assert_almost_eq(model.trauma, single * 2.0, 0.0001)

	for _index in 20:
		model.add_shake(model.max_offset)
	assert_eq(model.trauma, 1.0)


func test_offset_and_roll_never_exceed_their_limits() -> void:
	var model := CameraShakeModel.new()
	for _index in 10:
		model.add_shake(model.max_offset * 4.0, Vector2(50.0, 0.0))

	for _frame in 240:
		model.add_shake(model.max_offset, Vector2(-80.0, 30.0))
		model.advance(STEP)
		assert_lte(model.offset().length(), model.max_offset + 0.001)
		assert_lte(absf(model.rotation()), model.max_rotation + 0.0001)


func test_shake_decays_to_rest() -> void:
	var model := CameraShakeModel.new()
	model.add_shake(model.max_offset, Vector2(100.0, 0.0))
	var early := 0.0
	for _frame in 12:
		model.advance(STEP)
		early = maxf(early, model.offset().length())
	var late := 0.0
	for _frame in 48:
		model.advance(STEP)
	for _frame in 12:
		model.advance(STEP)
		late = maxf(late, model.offset().length())

	assert_lt(late, early * 0.25, "One second later the shake is a fraction of its start")
	for _frame in 240:
		model.advance(STEP)
	assert_false(model.is_active())
	assert_eq(model.offset(), Vector2.ZERO)
	assert_eq(model.rotation(), 0.0)


func test_motion_is_continuous_instead_of_white_noise() -> void:
	var coarse := _largest_step(STEP, 0.5)
	var fine := _largest_step(STEP / 8.0, 0.5)

	assert_gt(coarse, 0.0)
	assert_lt(fine, coarse * 0.3, "Sampling eight times as often makes the steps much smaller")


func test_far_requests_are_attenuated_and_distant_ones_ignored() -> void:
	var near := CameraShakeModel.new()
	var middle := CameraShakeModel.new()
	var far := CameraShakeModel.new()

	near.add_shake(10.0, Vector2(near.full_distance * 0.5, 0.0))
	middle.add_shake(10.0, Vector2((middle.full_distance + middle.zero_distance) * 0.5, 0.0))
	far.add_shake(10.0, Vector2(far.zero_distance + 1.0, 0.0))

	assert_eq(near.attenuation(0.0), 1.0)
	assert_almost_eq(middle.attenuation((middle.full_distance + middle.zero_distance) * 0.5), 0.25, 0.0001)
	assert_gt(near.trauma, middle.trauma)
	assert_gt(middle.trauma, 0.0)
	assert_eq(far.trauma, 0.0)
	assert_false(far.is_active())


func test_kick_pushes_the_camera_away_from_the_source() -> void:
	var kicked := CameraShakeModel.new()
	var unplaced := CameraShakeModel.new()

	kicked.add_shake(8.0, Vector2(100.0, 0.0))
	unplaced.add_shake(8.0)

	assert_eq(kicked.trauma, unplaced.trauma, "A source inside the full distance does not weaken the shake")
	assert_almost_eq(
		kicked.offset().x - unplaced.offset().x, -8.0 * kicked.kick_ratio, 0.001,
		"A blast on the right pushes the camera left"
	)
	assert_almost_eq(kicked.offset().y, unplaced.offset().y, 0.001)


func test_same_seed_and_requests_give_the_same_motion() -> void:
	var first := _recorded_motion(7)
	var second := _recorded_motion(7)
	var other := _recorded_motion(8)

	assert_eq(first, second)
	assert_ne(first, other)


func test_multiplier_scales_and_disables_the_output() -> void:
	var full := CameraShakeModel.new()
	var half := CameraShakeModel.new()
	var off := CameraShakeModel.new()
	half.intensity_multiplier = 0.5
	off.intensity_multiplier = 0.0
	for model: CameraShakeModel in [full, half, off]:
		model.add_shake(20.0, Vector2(60.0, 40.0))
		model.advance(STEP)

	assert_almost_eq(half.offset().length(), full.offset().length() * 0.5, 0.0001)
	assert_almost_eq(half.rotation(), full.rotation() * 0.5, 0.0001)
	assert_eq(off.offset(), Vector2.ZERO)
	assert_eq(off.rotation(), 0.0)


## Largest change of the offset between two updates while trauma is held at full.
func _largest_step(step: float, seconds: float) -> float:
	var model := CameraShakeModel.new()
	model.trauma_decay = 0.0
	model.add_shake(model.max_offset)
	var previous := model.offset()
	var largest := 0.0
	for _update in int(seconds / step):
		model.advance(step)
		largest = maxf(largest, (model.offset() - previous).length())
		previous = model.offset()
	return largest


func _peak_offset(model: CameraShakeModel, frames: int) -> float:
	var peak := 0.0
	for _frame in frames:
		model.advance(STEP)
		peak = maxf(peak, model.offset().length())
	return peak


func _recorded_motion(noise_seed: int) -> Array[Vector3]:
	var model := CameraShakeModel.new(noise_seed)
	var motion: Array[Vector3] = []
	model.add_shake(12.0, Vector2(120.0, -40.0))
	for frame in 40:
		if frame == 10:
			model.add_shake(6.0)
		model.advance(STEP)
		var offset := model.offset()
		motion.append(Vector3(offset.x, offset.y, model.rotation()))
	return motion
