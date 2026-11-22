## A transient world effect: emitter layers spawned together, drawn in list order, plus the
## camera shake the moment asks for.
class_name EffectRecipe
extends Resource


@export var emitters: Array[EffectEmitter] = []
## Peak camera offset in world px this moment asks for next to the player; 0 for none.
@export_range(0.0, 64.0, 0.1) var shake_intensity := 0.0
## Multiplies the shake by the played intensity.
@export var shake_scales_with_intensity := false


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for index in emitters.size():
		var emitter := emitters[index]
		if emitter == null:
			errors.append("emitter[%d] is missing" % index)
			continue
		for error in emitter.validate():
			errors.append("emitter[%d]: %s" % [index, error])
	return errors
