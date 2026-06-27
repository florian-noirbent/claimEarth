## Time-slices chunk build jobs and merges superseded chunk work.
class_name CooperativeChunkJobExecutor
extends RefCounted


var _jobs: Array[ChunkBuildJob] = []
var _completed: Array[ChunkBuildResult] = []


func enqueue(job: ChunkBuildJob) -> void:
	for index in range(_jobs.size() - 1, -1, -1):
		if _jobs[index].chunk_coord == job.chunk_coord:
			var previous := _jobs[index]
			var previous_full_collision := (previous.layer_mask & TerrainLayerMask.COLLISION) != 0 and previous.collision_indices.is_empty()
			job.layer_mask |= previous.layer_mask
			job.result.layer_mask = job.layer_mask
			if previous_full_collision:
				job.collision_indices = PackedInt32Array()
				job.result.collision_full_rebuild = true
			else:
				var merged := {}
				for changed_index in previous.collision_indices:
					merged[changed_index] = true
				for changed_index in job.collision_indices:
					merged[changed_index] = true
				job.collision_indices = PackedInt32Array()
				for changed_index in merged.keys():
					job.collision_indices.append(int(changed_index))
				job.collision_indices.sort()
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
