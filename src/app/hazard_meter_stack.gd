## Maintains an ordered, reusable stack of generic icon-only hazard meters.
class_name HazardMeterStack
extends Control

@export var row_scene: PackedScene

@onready var rows: VBoxContainer = %Rows

var _rows_by_key := {}


func update_hazards(snapshots: Array) -> void:
	var ordered := snapshots.duplicate()
	ordered.sort_custom(_sort_snapshots)
	var retained := {}
	for index in ordered.size():
		var snapshot: Variant = ordered[index]
		var level := clampf(float(_value(snapshot, &"normalized_level", _value(snapshot, &"level", 0.0))), 0.0, 1.0)
		if is_zero_approx(level):
			continue
		var key := _key_for(snapshot, index)
		retained[key] = true
		var row = _rows_by_key.get(key)
		if row == null:
			row = row_scene.instantiate()
			_rows_by_key[key] = row
			rows.add_child(row)
		row.configure(
			_value(snapshot, &"icon", null) as Texture2D,
			_value(snapshot, &"bar_color", Color.WHITE) as Color,
			level,
			bool(_value(snapshot, &"is_active", _value(snapshot, &"active", false))),
			float(_value(snapshot, &"secondary_threshold", -1.0)),
			bool(_value(snapshot, &"lethal_end", false))
		)
	for key in _rows_by_key.keys():
		if retained.has(key):
			continue
		var retired = _rows_by_key[key]
		_rows_by_key.erase(key)
		retired.queue_free()


func clear_hazards() -> void:
	for row in _rows_by_key.values():
		row.queue_free()
	_rows_by_key.clear()


func meter_count() -> int:
	return _rows_by_key.size()


func _sort_snapshots(left: Variant, right: Variant) -> bool:
	var left_order := int(_value(left, &"display_order", 0))
	var right_order := int(_value(right, &"display_order", 0))
	if left_order != right_order:
		return left_order < right_order
	return str(_value(left, &"cause", "")) < str(_value(right, &"cause", ""))


func _key_for(snapshot: Variant, index: int) -> StringName:
	var cause := str(_value(snapshot, &"cause", ""))
	if not cause.is_empty():
		return StringName(cause)
	var icon := _value(snapshot, &"icon", null) as Texture2D
	if icon != null and not icon.resource_path.is_empty():
		return StringName(icon.resource_path)
	return StringName("hazard_%d" % index)


func _value(snapshot: Variant, property: StringName, fallback: Variant) -> Variant:
	if snapshot is Dictionary:
		return (snapshot as Dictionary).get(property, fallback)
	if snapshot is Object:
		var value: Variant = (snapshot as Object).get(property)
		return fallback if value == null else value
	return fallback
