@tool
## Resource tuning for a deterministic, terrain-only directional destruction pulse.
class_name DirectionalTerrainPulseDefinition
extends Resource


@export_range(1, 32, 1) var width := 3
@export_range(1, 128, 1) var step_count := 16
@export_range(0.01, 10.0, 0.01) var step_interval_seconds := 0.1
@export_range(1, 128, 1) var pulse_tick_count := 16
@export_range(0.01, 10.0, 0.01) var front_load_decay := 2.65
@export var color := Color(0.68, 0.24, 0.95, 1.0)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if width < 1 or width % 2 == 0:
		errors.append("directional pulse width must be a positive odd number")
	if step_count < 1:
		errors.append("directional pulse step_count must be positive")
	if step_interval_seconds <= 0.0:
		errors.append("directional pulse step interval must be positive")
	if pulse_tick_count < 1:
		errors.append("directional pulse tick count must be positive")
	if front_load_decay <= 0.0:
		errors.append("directional pulse front-load decay must be positive")
	return errors


func steps_after_tick(completed_ticks: int) -> int:
	if completed_ticks >= pulse_tick_count:
		return step_count
	var progress := float(maxi(0, completed_ticks)) / float(pulse_tick_count)
	return mini(step_count, floori(step_count * progress_for_fraction(progress, front_load_decay)))


static func progress_for_fraction(progress: float, decay: float) -> float:
	var clamped_progress := clampf(progress, 0.0, 1.0)
	var normalization := 1.0 - exp(-decay)
	return (1.0 - exp(-decay * clamped_progress)) / normalization
