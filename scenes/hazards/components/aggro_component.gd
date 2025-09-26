extends Node
class_name AggroComponent

@export var controller_path: NodePath

var controller: HazardController
var _connected: bool = false
var _retry_attempts: int = 0
const _MAX_RETRY_ATTEMPTS: int = 8

func _ready() -> void:
	controller = _resolve_controller()
	call_deferred("_deferred_connect")

func _exit_tree() -> void:
	_disconnect_area_signals()

func _deferred_connect() -> void:
	_connect_area_signals()
	if not _connected and _retry_attempts < _MAX_RETRY_ATTEMPTS:
		_retry_attempts += 1
		await get_tree().process_frame
		_connect_area_signals()

func _on_aggro_body_entered(body: Node) -> void:
	if controller == null:
		return
	if body.is_in_group("player"):
		controller.set_active(true)

func _on_aggro_area_entered(area: Area2D) -> void:
	if controller == null:
		return
	if area.is_in_group("player"):
		controller.set_active(true)

func _on_deaggro_body_exited(body: Node) -> void:
	if controller == null:
		return
	if body.is_in_group("player"):
		controller.set_active(false)
		controller.request_return_to_spawn()

func _on_deaggro_area_exited(area: Area2D) -> void:
	if controller == null:
		return
	if area.is_in_group("player"):
		controller.set_active(false)
		controller.request_return_to_spawn()

func _connect_area_signals() -> void:
	if controller == null or _connected:
		return
	var aggro_area: Area2D = controller.aggro_radius_area
	var deaggro_area: Area2D = controller.deaggro_radius_area
	if aggro_area:
		if not aggro_area.body_entered.is_connected(_on_aggro_body_entered):
			aggro_area.body_entered.connect(_on_aggro_body_entered)
		if not aggro_area.area_entered.is_connected(_on_aggro_area_entered):
			aggro_area.area_entered.connect(_on_aggro_area_entered)
	if deaggro_area:
		if not deaggro_area.body_exited.is_connected(_on_deaggro_body_exited):
			deaggro_area.body_exited.connect(_on_deaggro_body_exited)
		if not deaggro_area.area_exited.is_connected(_on_deaggro_area_exited):
			deaggro_area.area_exited.connect(_on_deaggro_area_exited)
	_connected = aggro_area != null or deaggro_area != null

func _disconnect_area_signals() -> void:
	if controller == null:
		return
	var aggro_area: Area2D = controller.aggro_radius_area
	var deaggro_area: Area2D = controller.deaggro_radius_area
	if aggro_area:
		if aggro_area.body_entered.is_connected(_on_aggro_body_entered):
			aggro_area.body_entered.disconnect(_on_aggro_body_entered)
		if aggro_area.area_entered.is_connected(_on_aggro_area_entered):
			aggro_area.area_entered.disconnect(_on_aggro_area_entered)
	if deaggro_area:
		if deaggro_area.body_exited.is_connected(_on_deaggro_body_exited):
			deaggro_area.body_exited.disconnect(_on_deaggro_body_exited)
		if deaggro_area.area_exited.is_connected(_on_deaggro_area_exited):
			deaggro_area.area_exited.disconnect(_on_deaggro_area_exited)
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
