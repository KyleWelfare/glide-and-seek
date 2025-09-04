extends Node

@export var player_path: NodePath
@export var timer_hud_path: NodePath
@export var end_menu_path: NodePath

const PLAYER_GROUP := "player"
const TIMER_HUD_GROUP := "timer_hud"
const END_MENU_GROUP := "level_end_menu"

var _player: Node = null
var _timer_hud: Node = null
var _end_menu: Node = null

var _elapsed: float = 0.0
var _running: bool = false

func _enter_tree() -> void:
	# Try to lock via explicit path first (works even if not in group).
	var p := _safe_get(player_path)
	if p != null:
		_force_disable_processing(p)
	else:
		# Fall back to group-wide calls (works when Player is in "player" group).
		get_tree().call_group(PLAYER_GROUP, "set_controls_locked", true)
		get_tree().call_group(PLAYER_GROUP, "set_process", false)
		get_tree().call_group(PLAYER_GROUP, "set_physics_process", false)

func _ready() -> void:
	# Resolve nodes (safe when unset)
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

	# HUD & Menu should still render/respond when the tree is paused at the end
	if _timer_hud != null:
		_timer_hud.process_mode = Node.PROCESS_MODE_ALWAYS
	if _end_menu != null:
		_end_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		_end_menu.hide()

	# Make sure the player's velocity is zero before we begin (just in case)
	if _player is CharacterBody2D:
		var cb := _player as CharacterBody2D
		cb.velocity = Vector2.ZERO

	# Listen for COMPLETE_LEVEL doors in this scene
	_connect_complete_doors()

	# Run the startup sequence
	await _run_countdown_and_start()

func _process(delta: float) -> void:
	if _running:
		_elapsed += delta
		if _timer_hud != null and _timer_hud.has_method("set_time_seconds"):
			_timer_hud.set_time_seconds(_elapsed)

# --- Sequence ---

func _run_countdown_and_start() -> void:
	# Show "Ready… GO!" without pausing the tree
	if _timer_hud != null and _timer_hud.has_method("play_ready_go"):
		await _timer_hud.play_ready_go()
	else:
		# Fallback timing if HUD is missing
		await get_tree().create_timer(0.8).timeout
		await get_tree().create_timer(0.35).timeout

	_elapsed = 0.0
	_running = true

	# Re-enable player processing + unlock controls right at GO
	if _player != null:
		_force_enable_processing(_player)
	else:
		# Group fallback if we never found a single player node
		get_tree().call_group(PLAYER_GROUP, "set_process", true)
		get_tree().call_group(PLAYER_GROUP, "set_physics_process", true)
	_lock_player_controls(false)

# --- Completion ---

func _on_level_complete_triggered() -> void:
	if not _running:
		return

	_running = false
	_lock_player_controls(true)

	# Update record (session-only for now), but only if the autoload exists
	var level_id := _get_level_id()
	var best_after: float = _elapsed
	var records := get_node_or_null("/root/LevelRecords")
	if records != null and records.has_method("get_record") and records.has_method("update_record"):
		best_after = records.update_record(level_id, _elapsed)

	# Hide the live HUD timer so we don't show the time twice
	if _timer_hud != null and _timer_hud.has_method("set_timer_visible"):
		_timer_hud.set_timer_visible(false)

	# Open the end menu, then pause the tree
	if _end_menu != null and _end_menu.has_method("open_with_times"):
		_end_menu.open_with_times(_elapsed, best_after)
	else:
		if _end_menu != null:
			_end_menu.show()

	# Now pause to freeze the world (HUD/Menu keep working due to PROCESS_MODE_ALWAYS)
	get_tree().paused = true

# --- Helpers ---

func _safe_get(path: NodePath) -> Node:
	if path == NodePath(""):
		return null
	return get_node_or_null(path)

func _lock_player_controls(locked: bool) -> void:
	if _player == null:
		return

	# Preferred: player implements a control gate
	if _player.has_method("set_controls_locked"):
		_player.set_controls_locked(locked)
		return
	if _player.has_method("set_input_enabled"):
		_player.set_input_enabled(not locked)
		return
	if _player.has_method("set_can_move"):
		_player.set_can_move(not locked)
		return

	# Fallback: toggle processing on the player node
	if locked:
		if _player is CharacterBody2D:
			var cb := _player as CharacterBody2D
			cb.velocity = Vector2.ZERO
		_player.set_physics_process(false)
		_player.set_process(false)
	else:
		_player.set_physics_process(true)
		_player.set_process(true)

func _force_disable_processing(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	if node is CharacterBody2D:
		var cb := node as CharacterBody2D
		cb.velocity = Vector2.ZERO

func _force_enable_processing(node: Node) -> void:
	node.set_process(true)
	node.set_physics_process(true)

func _connect_complete_doors() -> void:
	# Tree walk to find ExitDoor nodes and connect if in COMPLETE_LEVEL mode
	var root := get_tree().current_scene
	if root == null:
		return
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.push_back(child)
		if cur is ExitDoor:
			var door := cur as ExitDoor
			if door.mode == ExitDoor.DoorMode.COMPLETE_LEVEL:
				if not door.is_connected("level_complete_triggered", Callable(self, "_on_level_complete_triggered")):
					door.connect("level_complete_triggered", Callable(self, "_on_level_complete_triggered"))

func _get_level_id() -> String:
	var scene := get_tree().current_scene
	if scene == null:
		return ""
	return scene.scene_file_path
