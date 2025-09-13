extends Node

signal best_time_changed(level_id: String, best_seconds: float)

const SAVE_PATH: String = "user://records.json"
const SAVE_VERSION: int = 1

var _best_times: Dictionary = {} # key: String (level_id), value: float seconds


func _ready() -> void:
	# Load saved data at startup (creates defaults if missing/invalid).
	_load_from_disk()


# --- Public API (unchanged) ---

func get_record(level_id: String) -> float:
	# Returns INF if no record exists.
	if not _best_times.has(level_id):
		return INF
	return _best_times[level_id]


func update_record(level_id: String, time_seconds: float) -> float:
	# Immediate overwrite if time is lower (or no record yet).
	if not _best_times.has(level_id):
		_best_times[level_id] = time_seconds
		_save_to_disk()
		emit_signal("best_time_changed", level_id, time_seconds)
		return _best_times[level_id]

	var prev: float = _best_times[level_id]
	if time_seconds < prev:
		_best_times[level_id] = time_seconds
		_save_to_disk()
		emit_signal("best_time_changed", level_id, time_seconds)

	return _best_times[level_id]


# --- Persistence ---

func _load_from_disk() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_best_times.clear()
		return

	var f: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_warning("LevelRecords: Could not open save file for reading.")
		_best_times.clear()
		return

	var text: String = f.get_as_text()
	f.close()

	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("LevelRecords: Save file is invalid JSON. Starting fresh.")
		_best_times.clear()
		return

	var dict: Dictionary = parsed
	var levels_dict: Dictionary = {}
	if dict.has("levels") and typeof(dict["levels"]) == TYPE_DICTIONARY:
		levels_dict = dict["levels"]

	_best_times.clear()
	for level_id in levels_dict.keys():
		var entry = levels_dict[level_id]
		if typeof(entry) == TYPE_DICTIONARY and entry.has("best_ms"):
			var best_ms: int = int(entry["best_ms"])
			if best_ms > 0:
				_best_times[level_id] = float(best_ms) / 1000.0


func _save_to_disk() -> void:
	# Build JSON payload from current _best_times.
	var levels_out: Dictionary = {}
	for level_id in _best_times.keys():
		var seconds: float = _best_times[level_id]
		# Only save finite, positive times.
		if is_finite(seconds) and seconds > 0.0:
			var ms: int = int(round(seconds * 1000.0))
			levels_out[level_id] = { "best_ms": ms }

	var data: Dictionary = {
		"version": SAVE_VERSION,
		"levels": levels_out
	}

	var json_text: String = JSON.stringify(data, "\t", true) # pretty + sorted keys
	_atomic_write(json_text)


func _atomic_write(text: String) -> void:
	# Write to temp, move previous to .bak, then rename temp to final.
	var tmp_path: String = SAVE_PATH + ".tmp"
	var bak_path: String = SAVE_PATH + ".bak"

	var f: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_warning("LevelRecords: Could not open temp file for writing.")
		return
	f.store_string(text)
	f.close()

	# Clean any old .bak
	if FileAccess.file_exists(bak_path):
		var _rmb = DirAccess.remove_absolute(bak_path)

	# Move current to .bak (if it exists)
	if FileAccess.file_exists(SAVE_PATH):
		var _bak_err: int = DirAccess.rename_absolute(SAVE_PATH, bak_path)
		# If this fails, we still try to place the new file.

	# Move temp to final
	var rename_err: int = DirAccess.rename_absolute(tmp_path, SAVE_PATH)
	if rename_err != OK:
		# Fallback: attempt direct write to final path.
		var f2: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f2 != null:
			f2.store_string(text)
			f2.close()
