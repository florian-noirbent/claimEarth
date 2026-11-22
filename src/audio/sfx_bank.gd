## Renders each sound of the synthesized set once into a 16-bit AudioStreamWAV and keeps
## it. A sound is rendered on first use, or ahead of use through prewarm_step.
class_name SfxBank
extends RefCounted


var _mix_rate := 32000
var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _pending: Array[StringName] = []
var _render_usec := 0
var _byte_count := 0


func _init(mix_rate: int = 32000) -> void:
	_mix_rate = mix_rate


## Queues sounds for prewarm_step, first queued first rendered.
func queue(ids: Array[StringName]) -> void:
	for id in ids:
		if not _streams.has(id) and not _pending.has(id):
			_pending.append(id)


## Renders queued sounds until budget_msec is spent (always at least one). Returns true
## while sounds remain queued.
func prewarm_step(budget_msec: float) -> bool:
	var deadline := Time.get_ticks_usec() + int(budget_msec * 1000.0)
	while not _pending.is_empty():
		stream(_pending[0])
		if Time.get_ticks_usec() >= deadline:
			break
	return not _pending.is_empty()


## The rendered stream of a sound, or null when the set has no such sound.
func stream(id: StringName) -> AudioStreamWAV:
	var cached: AudioStreamWAV = _streams.get(id)
	if cached != null:
		return cached
	_pending.erase(id)
	if not SfxRecipes.has(id):
		return null
	var started := Time.get_ticks_usec()
	var rendered := AudioSynth.to_stream(SfxRecipes.render(id, _mix_rate), _mix_rate)
	_render_usec += Time.get_ticks_usec() - started
	_byte_count += rendered.data.size()
	_streams[id] = rendered
	return rendered


func is_rendered(id: StringName) -> bool:
	return _streams.has(id)


func pending_count() -> int:
	return _pending.size()


func rendered_count() -> int:
	return _streams.size()


## Total time spent rendering so far.
func render_msec() -> float:
	return _render_usec / 1000.0


## Total PCM bytes held.
func byte_count() -> int:
	return _byte_count
