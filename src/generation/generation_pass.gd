class_name GenerationPass
extends RefCounted


func get_name() -> String:
	return "generation_pass"


func apply(_context: GenerationContext) -> bool:
	return true
