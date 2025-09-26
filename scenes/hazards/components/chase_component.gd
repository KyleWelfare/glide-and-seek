extends Node
class_name ChaseComponent

@export var controller_path: NodePath

var controller: HazardController
var _chasing: bool = false
var _connected: bool = false

func _ready() -> void:
	controller = _resolve_controller()
	_connect_controller_signals()

func _exit_tree() -> void:
	_disconnect_controller_signals()

func _physics_process(_delta: float) -> void:
	if controller == null:
		return
	if _chasing:
		if controller.is_player_valid():
			controller.set_desired_speed(controller.chase_speed)
			controller.set_target_position(controller.get_player_global_position())
		else:
			_chasing = false
			controller.clear_target()

func _on_player_aggro_changed(is_aggroed: bool) -> void:
	if controller == null:
		return
	if is_aggroed:
		_chasing = true
	else:
		_chasing = false
		controller.request_return_to_spawn()
		controller.set_desired_speed(controller.wander_speed)
		controller.set_target_position(controller.spawn_position)

func _on_reached_target() -> void:
	if controller == null:
		return
	if controller.is_returning_to_spawn:
		controller.clear_return_to_spawn_request()

func _connect_controller_signals() -> void:
	if controller == null or _connected:
		return
	if not controller.player_aggro_changed.is_connected(_on_player_aggro_changed):
		controller.player_aggro_changed.connect(_on_player_aggro_changed)
	if not controller.reached_target.is_connected(_on_reached_target):
		controller.reached_target.connect(_on_reached_target)
	_connected = true

func _disconnect_controller_signals() -> void:
	if controller == null or not _connected:
		return
	if controller.player_aggro_changed.is_connected(_on_player_aggro_changed):
		controller.player_aggro_changed.disconnect(_on_player_aggro_changed)
	if controller.reached_target.is_connected(_on_reached_target):
		controller.reached_target.disconnect(_on_reached_target)
	_connected = false

func _resolve_controller() -> HazardController:
	if not controller_path.is_empty():
		var node: Node = get_node_or_null(controller_path)
		if node is HazardController:
			return node as HazardController
	if owner is HazardController:
		return owner as HazardController
	if get_parent() is HazardController:
		return get_parent() as HazardController
	return null
