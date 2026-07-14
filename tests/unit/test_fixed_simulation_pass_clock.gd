extends GutTest


const FixedSimulationPassClockScript = preload("res://src/simulation/fixed_simulation_pass_clock.gd")


func test_equal_elapsed_time_requests_equal_passes_at_supported_frame_rates() -> void:
	for fps in [30, 60, 90, 120, 240]:
		var clock = FixedSimulationPassClockScript.new()
		var scheduled := 0
		for _frame in range(fps):
			clock.add_time(1.0 / float(fps))
			var due: int = clock.available_passes(6)
			clock.consume(due)
			scheduled += due
		assert_eq(scheduled, 60, "%d FPS must request 60 passes per elapsed second." % fps)
		assert_eq(int(scheduled / 6), 10)


func test_clock_batches_at_30_and_skips_at_120_fps() -> void:
	var clock = FixedSimulationPassClockScript.new()
	clock.add_time(1.0 / 30.0)
	assert_eq(clock.available_passes(6), 2)
	clock.consume(2)
	clock.add_time(1.0 / 120.0)
	assert_eq(clock.available_passes(6), 0)
	clock.add_time(1.0 / 120.0)
	assert_eq(clock.available_passes(6), 1)


func test_clock_retains_and_drains_drop_debt_and_reset_clears_it() -> void:
	var clock = FixedSimulationPassClockScript.new()
	clock.add_time(0.1)
	assert_eq(clock.available_passes(6), 6)
	clock.consume(6)
	clock.add_time(0.5)
	var drained := 0
	for _batch in range(5):
		var due: int = clock.available_passes(6)
		clock.consume(due)
		drained += due
	assert_eq(drained, 30)
	assert_almost_eq(clock.pending_passes(), 0.0, 0.000001)
	clock.add_time(0.25)
	clock.reset()
	assert_eq(clock.available_passes(6), 0)
