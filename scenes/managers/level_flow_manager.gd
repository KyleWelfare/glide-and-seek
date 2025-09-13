extends Node

@export var player_path: NodePath
@export var timer_hud_path: NodePath
@export var end_menu_path: NodePath
@export var level_id: String = "" # Stable ID used for saving best times. Set this per level in the Inspector.

const PLAYER_GROUP: String = "player"
const TIMER_HUD_GROUP: String = "timer_hud"
const END_MENU_GROUP: String = "level_end_menu"

var _player: Node = null
var _timer_hud: Node = null
var _end_menu: Node = null

var _elapsed_seconds: float = 0.0
var _is_running: bool = false
var _menu_open: bool = false


func _enter_tree() -> void:
	# Freeze the entire world regardless of node order.
	get_tree().paused = true

	# Keep your original best-effort early lock (harmless redundancy while paused).
	var explicit_player: Node = _safe_get(player_path)
	if explicit_player != null:
		_force_disable_processing(explicit_player)
	else:
		get_tree().call_group(PLAYER_GROUP, "set_controls_locked", true)
		get_tree().call_group(PLAYER_GROUP, "set_process", false)
		get_tree().call_group(PLAYER_GROUP, "set_physics_process", false)


func _ready() -> void:
	# LevelFlowManager must run while paused to drive the countdown.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = _safe_get(player_path)
	if _player == null:
		_player = get_tree().get_first_node_in_group(PLAYER_GROUP)
		if _player == null:
			push_warning("LevelFlowManager: No Player found. Set player_path or put the Player in the 'player' group.")

	_timer_hud = _safe_get(timer_hud_path)
	if _timer_hud == null:
		_timer_hud = get_tree().get_first_node_in_group(TIMER_HUD_GROUP)

	_end_menu = _safe_get(end_menu_path)
	if _end_menu == null:
		_end_menu = get_tree().get_first_node_in_group(END_MENU_GROUP)

	if _timer_hud != null:
		_timer_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if _end_menu != null:
		_end_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		_end_menu.hide()

	if _player is CharacterBody2D:
		var character_body: CharacterBody2D = _player as CharacterBody2D
		character_body.velocity = Vector2.ZERO

	_connect_complete_doors()

	# Warn once if level_id is empty. We will fall back to scene path key.
	if level_id.strip_edges() == "":
		push_warning("LevelFlowManager: 'level_id' is empty; falling back to scene_file_path for saving. Set a stable ID in the Inspector.")

	# Ensure UI nodes are fully ready before we show "READY…"
	await _await_node_ready(_timer_hud)
	await _await_node_ready(_end_menu)
	await get_tree().process_frame

	await _run_countdown_and_start()


func _process(delta: float) -> void:
	# Open end menu via Start button / pause button
	if Input.is_action_just_pressed("open_menu"):
		_open_end_menu_manual()

	if _is_running:
		_elapsed_seconds += delta
		if _timer_hud != null and _timer_hud.has_method("set_time_seconds"):
			_timer_hud.set_time_seconds(_elapsed_seconds)


# --- Sequence ---

func _run_countdown_and_start() -> void:
	# Show "Ready… GO!" while paused.
	if _timer_hud != null and _timer_hud.has_method("play_ready_go"):
		await _timer_hud.play_ready_go()
	else:
		# Use pause-aware timers so they tick while the tree is paused.
		await get_tree().create_timer(0.8, true).timeout
		await get_tree().create_timer(0.35, true).timeout

	# If the menu was opened during the countdown, DO NOT start the run yet.
	if _menu_open:
		return

	# Start run time after GO
	_elapsed_seconds = 0.0
	_is_running = true

	# Unpause the world exactly at GO so the player and physics resume.
	get_tree().paused = false

	if _player != null:
		_force_enable_processing(_player)
	else:
		get_tree().call_group(PLAYER_GROUP, "set_process", true)
		get_tree().call_group(PLAYER_GROUP, "set_physics_process", true)

	_lock_player_controls(false)


# --- Completion ---

func _on_level_complete_triggered() -> void:
	if not _is_running:
		return

	_is_running = false
	_menu_open = false
	_lock_player_controls(true)

	var level_identifier: String = _get_level_id()
	var best_time_after_seconds: float = _elapsed_seconds
	var level_records: Node = get_node_or_null("/root/LevelRecords")
	if level_records != null and level_records.has_method("get_record") and level_records.has_method("update_record"):
		best_time_after_seconds = level_records.update_record(level_identifier, _elapsed_seconds)

	if _timer_hud != null and _timer_hud.has_method("set_timer_visible"):
		_timer_hud.set_timer_visible(false)

	if _end_menu != null and _end_menu.has_method("open_with_times"):
		_end_menu.open_with_times(_elapsed_seconds, best_time_after_seconds)
	else:
		if _end_menu != null:
			_end_menu.show()

	# Pause at the end to freeze the world; HUD/Menu still work due to PROCESS_MODE_ALWAYS.
	get_tree().paused = true


# --- Manual open (Start button) ---

func _open_end_menu_manual() -> void:
	# Stop timer progression and freeze gameplay
	_is_running = false
	_menu_open = true
	_lock_player_controls(true)
	get_tree().paused = true

	# Hide HUD timer while menu is up
	if _timer_hud != null and _timer_hud.has_method("set_timer_visible"):
		_timer_hud.set_timer_visible(false)

	# Show current vs. best WITHOUT updating records
	var best_time_seconds: float = _elapsed_seconds
	var level_records: Node = get_node_or_null("/root/LevelRecords")
	if level_records != null and level_records.has_method("get_record"):
		var existing_best = level_records.get_record(_get_level_id())
		if typeof(existing_best) == TYPE_FLOAT:
			best_time_seconds = existing_best

	if _end_menu != null and _end_menu.has_method("open_with_times"):
		_end_menu.open_with_times(_elapsed_seconds, best_time_seconds)
	elif _end_menu != null:
		_end_menu.show()


# --- Helpers ---

func _safe_get(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)


func _lock_player_controls(locked: bool) -> void:
	if _player == null:
		return

	if _player.has_method("set_controls_locked"):
		_player.set_controls_locked(locked)
		return
	if _player.has_method("set_input_enabled"):
		_player.set_input_enabled(not locked)
		return
	if _player.has_method("set_can_move"):
		_player.set_can_move(not locked)
		return

	if locked:
		if _player is CharacterBody2D:
			var character_body: CharacterBody2D = _player as CharacterBody2D
			character_body.velocity = Vector2.ZERO
		_player.set_physics_process(false)
		_player.set_process(false)
	else:
		_player.set_physics_process(true)
		_player.set_process(true)


func _force_disable_processing(node_to_freeze: Node) -> void:
	node_to_freeze.set_process(false)
	node_to_freeze.set_physics_process(false)
	if node_to_freeze is CharacterBody2D:
		var character_body: CharacterBody2D = node_to_freeze as CharacterBody2D
		character_body.velocity = Vector2.ZERO


func _force_enable_processing(node_to_enable: Node) -> void:
	node_to_enable.set_process(true)
	node_to_enable.set_physics_process(true)


func _connect_complete_doors() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var nodes_to_visit: Array[Node] = [scene_root]
	while nodes_to_visit.size() > 0:
		var current_node: Node = nodes_to_visit.pop_back()
		for child_node in current_node.get_children():
			nodes_to_visit.push_back(child_node)

		if current_node is ExitDoor:
			var exit_door: ExitDoor = current_node as ExitDoor
			if exit_door.mode == ExitDoor.DoorMode.COMPLETE_LEVEL:
				if not exit_door.is_connected("level_complete_triggered", Callable(self, "_on_level_complete_triggered")):
					exit_door.connect("level_complete_triggered", Callable(self, "_on_level_complete_triggered"))


func _get_level_id() -> String:
	# Prefer the explicit level_id; otherwise fall back to the scene path (keeps tests running).
	if level_id.strip_edges() != "":
		return level_id
	var current_scene: Node = get_tree().current_scene
	if current_scene == null:
		return ""
	return current_scene.scene_file_path


func _await_node_ready(node_to_wait_for: Node) -> void:
	if node_to_wait_for == null:
		return
	while not node_to_wait_for.is_node_ready():
		await get_tree().process_frame
