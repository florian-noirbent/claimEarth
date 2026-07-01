## Time-slices chunk build jobs and merges superseded chunk work.
class_name CooperativeChunkJobExecutor
extends RefCounted


var _jobs: Array[ChunkBuildJob] = []
var _completed: Array[ChunkBuildResult] = []


func enqueue(job: ChunkBuildJob) -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		if _jobs[index].chunk_coord == job.chunk_coord:
			var previous := _jobs[index]
			job.layer_mask |= previous.layer_mask
			job.result.layer_mask = job.layer_mask
			_jobs.remove_at(index)
	_jobs.append(job)


func advance(time_budget_usec: int) -> void:
	var deadline := Time.get_ticks_usec() + maxi(time_budget_usec, 1)
	while not _jobs.is_empty():
		var remaining := maxi(1, deadline - Time.get_ticks_usec())
		var job := _jobs[0]
		if job.advance(remaining):
			_completed.append(job.result)
			_jobs.pop_front()
		if Time.get_ticks_usec() >= deadline:
			break


func take_completed() -> Array[ChunkBuildResult]:
	var result := _completed
	_completed = []
	return result


func pending_count() -> int:
	return _jobs.size()


func clear() -> void:
	_jobs.clear()
	_completed.clear()
