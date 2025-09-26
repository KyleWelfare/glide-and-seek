extends Node
class_name WanderComponent

@export var controller_path: NodePath
@export var pause_min_seconds: float = 0.3
@export var pause_max_seconds: float = 0.6
@export var min_travel_distance: float = 24.0

var controller: HazardController
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _is_pausing: bool = false
var _connected: bool = false

func _ready() -> void:
	_rng.randomize()
	controller = _resolve_controller()
	_validate_pause_range()
	_connect_controller_signals()
	_start_or_resume_passive()

func _exit_tree() -> void:
	_disconnect_controller_signals()
	_stop_pause_timer_if_any()

func _on_state_changed(new_state: int) -> void:
	if new_state == HazardController.HazardState.ACTIVE:
		_stop_pause_timer_if_any()
		_is_pausing = false
		controller.clear_target()
	else:
		_start_or_resume_passive()

func _on_reached_target() -> void:
	if controller.state == HazardController.HazardState.PASSIVE:
		if controller.is_returning_to_spawn:
			controller.clear_return_to_spawn_request()
		_start_pause_then_pick_new()

func _start_or_resume_passive() -> void:
	if controller.state != HazardController.HazardState.PASSIVE:
		return
	if controller.is_returning_to_spawn:
		controller.set_desired_speed(controller.wander_speed)
		controller.set_target_position(controller.spawn_position)
		return
	if _is_pausing:
		return
	_pick_new_wander_target()

func _start_pause_then_pick_new() -> void:
	_is_pausing = true
	var t: Timer = _get_pause_timer()
	if t == null:
		_is_pausing = false
		_pick_new_wander_target()
		return
	t.stop()
	t.one_shot = true
	t.wait_time = _rng.randf_range(pause_min_seconds, pause_max_seconds)
	if not t.timeout.is_connected(_on_pause_timeout):
		t.timeout.connect(_on_pause_timeout)
	t.start()

func _on_pause_timeout() -> void:
	_is_pausing = false
	if controller.state == HazardController.HazardState.PASSIVE:
		_pick_new_wander_target()

func _pick_new_wander_target() -> void:
	var center: Vector2 = controller.get_effective_wander_center()
	var radius: float = controller.get_effective_wander_radius()
	var min_d: float = max(min_travel_distance, controller.arrival_threshold * 1.5)
	if radius <= 0.0:
		# Fallback: no valid radius configured; just pick a small hop from center
		var angle0: float = _rng.randf_range(0.0, TAU)
		var target0: Vector2 = center + Vector2(cos(angle0), sin(angle0)) * max(min_d, 8.0)
		controller.set_desired_speed(controller.wander_speed)
		controller.set_target_position(target0)
		return
	if min_d >= radius:
		min_d = max(radius * 0.8, radius - 1.0)
	var r2_min: float = min_d * min_d
	var r2_max: float = radius * radius
	var angle: float = _rng.randf_range(0.0, TAU)
	var r: float = sqrt(_rng.randf_range(r2_min, r2_max))
	var target: Vector2 = center + Vector2(cos(angle), sin(angle)) * r
	controller.set_desired_speed(controller.wander_speed)
	controller.set_target_position(target)

func _get_pause_timer() -> Timer:
	if controller and controller.pause_timer:
		return controller.pause_timer
	return null

func _stop_pause_timer_if_any() -> void:
	var t: Timer = _get_pause_timer()
	if t and not t.is_stopped():
		t.stop()

func _connect_controller_signals() -> void:
	if controller == null or _connected:
		return
	controller.state_changed.connect(_on_state_changed)
	controller.reached_target.connect(_on_reached_target)
	_connected = true

func _disconnect_controller_signals() -> void:
	if controller == null or not _connected:
		return
	if controller.state_changed.is_connected(_on_state_changed):
		controller.state_changed.disconnect(_on_state_changed)
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

func _validate_pause_range() -> void:
	if pause_max_seconds < pause_min_seconds:
		var tmp: float = pause_min_seconds
		pause_min_seconds = pause_max_seconds
		pause_max_seconds = tmp
