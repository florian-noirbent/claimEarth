@tool
## Resource-driven tuning for a reusable world light source component.
class_name WorldLightSourceDefinition
extends Resource


enum UpdateMode {
	STANDARD,
	HIGH_FREQUENCY,
}

@export var update_mode := UpdateMode.STANDARD:
	set(value):
		update_mode = clampi(value, UpdateMode.STANDARD, UpdateMode.HIGH_FREQUENCY)
		emit_changed()
@export_range(1, 255, 1) var light_level := 90:
	set(value):
		light_level = clampi(value, 1, 255)
		emit_changed()
@export_range(0, 64, 1) var update_radius := 0:
	set(value):
		update_radius = clampi(value, 0, 64)
		emit_changed()


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if light_level <= 0 or light_level > 255:
		errors.append("world light level must be between 1 and 255")
	if update_mode == UpdateMode.HIGH_FREQUENCY and update_radius <= 0:
		errors.append("high-frequency world light requires a positive update radius")
	return errors
