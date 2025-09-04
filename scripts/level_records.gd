extends Node

var _best_times: Dictionary = {} # key: String (level_id), value: float seconds

func get_record(level_id: String) -> float:
	if not _best_times.has(level_id):
		return INF
	return _best_times[level_id]

func update_record(level_id: String, time_seconds: float) -> float:
	if not _best_times.has(level_id):
		_best_times[level_id] = time_seconds
	else:
		var prev: float = _best_times[level_id]
		if time_seconds < prev:
			_best_times[level_id] = time_seconds
	return _best_times[level_id]
