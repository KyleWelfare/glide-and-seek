extends Node2D
class_name SquashStretchComponent

@export var sprite_path: NodePath
@export var reset_delay_seconds: float = 0.12
@export var tween_duration: float = 0.08

var _sprite: Sprite2D
var _reset_timer: Timer
var _player: Node
var _state_machine: Node
var _was_on_floor: bool = false
var _active_tween: Tween = null
var _seen_airborne: bool = false	# NEW: only trigger landing after we've actually been in the air

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		push_error("SquashStretchComponent: sprite_path is not set or does not point to a Sprite2D.")
		set_process(false)
		return

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.autostart = false
	add_child(_reset_timer)
	_reset_timer.timeout.connect(_on_reset_timer_timeout)

	_player = get_parent()
	_state_machine = _player.get_node_or_null("StateMachine")
	_was_on_floor = _player.is_on_floor()

func _process(_delta: float) -> void:
	if _state_machine == null:
		return

	var current_state = _state_machine.current_state
	var on_floor_now: bool = _player.is_on_floor()

	# Mark that we've actually been airborne at least once
	if !on_floor_now:
		_seen_airborne = true

	# --- Case 1: Falling ---
	if current_state and current_state.name == "Fall":
		manipulate_sprite(0.85, 1.15)

	# --- Case 2: Landing (require we've been airborne) ---
	if on_floor_now and !_was_on_floor and _seen_airborne:
		manipulate_sprite(1.2, 0.8)
		_seen_airborne = false	# re-arm for the next jump/fall

	_was_on_floor = on_floor_now

func manipulate_sprite(x_scale: float, y_scale: float) -> void:
	var safe_x: float = max(0.001, x_scale)
	var safe_y: float = max(0.001, y_scale)

	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.tween_property(_sprite, "scale", Vector2(safe_x, safe_y), tween_duration)

	_reset_timer.stop()
	_reset_timer.start(reset_delay_seconds)

func _on_reset_timer_timeout() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.tween_property(_sprite, "scale", Vector2.ONE, tween_duration)
