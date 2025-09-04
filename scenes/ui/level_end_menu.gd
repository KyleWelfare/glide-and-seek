extends CanvasLayer

@export var hub_scene: PackedScene

# --- Split labels (exact paths from your tree) ---
@onready var current_time_major_label: Label = $Root/MarginContainer/VBoxContainer/CurrentTimeHBox/CurrentTimeMajorLabel
@onready var current_time_ms_label: Label = $Root/MarginContainer/VBoxContainer/CurrentTimeHBox/CurrentTimeMSLabel
@onready var best_time_major_label: Label = $Root/MarginContainer/VBoxContainer/BestTimeHBox/BestTimeMajorLabel
@onready var best_time_ms_label: Label = $Root/MarginContainer/VBoxContainer/BestTimeHBox/BestTimeMSLabel

# --- Buttons ---
@onready var retry_button: Button = $Root/MarginContainer/VBoxContainer/HBoxContainer/RetryButton
@onready var return_button: Button = $Root/MarginContainer/VBoxContainer/HBoxContainer/ReturnButton

func _ready() -> void:
	# Menu must still work after we pause the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Default text so you never see empty labels.
	_set_split_labels(0.0, 0.0)

	hide()

	# Button wiring
	if is_instance_valid(retry_button):
		retry_button.pressed.connect(_on_retry_pressed)
	if is_instance_valid(return_button):
		return_button.pressed.connect(_on_return_pressed)

# Show menu and populate times.
func open_with_times(current_time_seconds: float, best_time_seconds: float) -> void:
	_set_split_labels(current_time_seconds, best_time_seconds)
	show()

# --- Internal: formatting & writing to split labels ---

func _set_split_labels(cur: float, best: float) -> void:
	# Current
	var cur_ms_total: int = int(round(cur * 1000.0))
	var cur_mins: int = cur_ms_total / 60000
	var cur_secs: int = (cur_ms_total % 60000) / 1000
	var cur_ms: int = cur_ms_total % 1000

	# Best
	var best_ms_total: int = int(round(best * 1000.0))
	var best_mins: int = best_ms_total / 60000
	var best_secs: int = (best_ms_total % 60000) / 1000
	var best_ms: int = best_ms_total % 1000

	if is_instance_valid(current_time_major_label):
		current_time_major_label.text = "%02d:%02d" % [cur_mins, cur_secs]
	if is_instance_valid(current_time_ms_label):
		current_time_ms_label.text = ".%03d" % cur_ms

	if is_instance_valid(best_time_major_label):
		best_time_major_label.text = "%02d:%02d" % [best_mins, best_secs]
	if is_instance_valid(best_time_ms_label):
		best_time_ms_label.text = ".%03d" % best_ms

# --- Buttons ---

func _on_retry_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_return_pressed() -> void:
	if hub_scene == null:
		push_warning("LevelEndMenu: hub_scene is not set.")
		return
	get_tree().paused = false
	get_tree().change_scene_to_packed(hub_scene)
