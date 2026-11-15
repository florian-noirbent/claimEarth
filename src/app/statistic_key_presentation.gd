## Display name, description, and icon for one keyed statistic such as a death cause.
class_name StatisticKeyPresentation
extends Resource


@export var key: StringName
@export var display_name := ""
@export_multiline var description := ""
@export var icon: Texture2D


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if key == &"":
		errors.append("statistic presentation requires a key")
	if display_name.strip_edges().is_empty():
		errors.append("statistic presentation '%s' requires a display name" % key)
	if icon == null:
		errors.append("statistic presentation '%s' requires an icon" % key)
	return errors
