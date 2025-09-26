extends Node2D
class_name SquashStretchComponent

# Target sprite to scale.
@export var sprite_path: NodePath

# Timing
@export var reset_delay_seconds: float = 0.12
@export var tween_duration: float = 0.08

# State detection (brittle by design; configurable)
@export var fall_state_name: StringName = &"Fall"

# Scales (exported for easy tuning)
@export var fall_scale: Vector2 = Vector2(0.85, 1.15)
@export var land_scale: Vector2 = Vector2(1.2, 0.8)

# Feature toggles
@export var enable_fall_stretch: bool = true # for testing purposes
@export var enable_land_squash: bool = true # for testing purposes

const SCALE_EPSILON: float = 0.001

var _sprite: Sprite2D
var _reset_timer: Timer
var _player: CharacterBody2D
var _state_machine: Node
var _was_on_floor: bool = false
var _prev_in_fall: bool = false
var _active_tween: Tween
var _seen_airborne: bool = false
var _current_target_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	if _sprite == null:
		push_error("SquashStretchComponent: sprite_path is not set or does not point to a Sprite2D.")
		set_process(false)
		return

	_player = get_parent() as CharacterBody2D
	assert(_player != null)

	# Expect a child named "StateMachine" that exposes a 'current_state' Node.
	_state_machine = _player.get_node_or_null("StateMachine")
	assert(_state_machine != null)

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.autostart = false
	add_child(_reset_timer)
	_reset_timer.timeout.connect(_on_reset_timer_timeout)

	_was_on_floor = _player.is_on_floor()
	_prev_in_fall = false
	_seen_airborne = false
	_current_target_scale = _sprite.scale

func _exit_tree() -> void:
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	if _reset_timer != null:
		_reset_timer.stop()

func _process(_delta: float) -> void:
	if _state_machine == null:
		return

	var on_floor_now: bool = _player.is_on_floor()

	# Track if we've left the ground at least once (used for landing squash gating).
	if !on_floor_now:
		_seen_airborne = true

	var in_fall_now: bool = _is_in_fall_state()

	# === FALL STRETCH ===
	# Apply stretch ONLY while in the Fall state.
	if enable_fall_stretch and in_fall_now:
		# No reset timer when entering fall stretch.
		_manipulate_sprite(fall_scale, false)

	# === CLEAR STRETCH ON EXITING FALL WHILE STILL AIRBORNE ===
	# If we were in Fall last frame, and we're not in Fall now, and we're still off the floor,
	# immediately tween back to 1,1 (no landing squash; no reset timer).
	if _prev_in_fall and !in_fall_now and !on_floor_now:
		_clear_fall_stretch_immediately()

	# === LANDING SQUASH ===
	# Only when we *touch down* after being airborne at least once.
	if enable_land_squash and on_floor_now and !_was_on_floor and _seen_airborne:
		# Start at land_scale, then auto-reset to 1,1 after a short delay.
		_manipulate_sprite(land_scale, true)
		_seen_airborne = false

	# Update frame-to-frame flags.
	_prev_in_fall = in_fall_now
	_was_on_floor = on_floor_now

func _is_in_fall_state() -> bool:
	# We expect the state machine to have a 'current_state' property holding a Node (State).
	# Using Node.get() here avoids "prop in node" checks.
	var current_state: Node = _state_machine.get("current_state") as Node
	if current_state == null:
		return false
	# All Nodes have 'name'; compare with configured fall_state_name.
	return current_state.name == fall_state_name

func _clear_fall_stretch_immediately() -> void:
	# Kill any in-flight tween and snap back via tween to Vector2.ONE with no reset timer.
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_sprite, "scale", Vector2.ONE, tween_duration)
	_current_target_scale = Vector2.ONE
	_reset_timer.stop()

func _manipulate_sprite(target_scale: Vector2, start_reset_timer: bool) -> void:
	var safe_target: Vector2 = Vector2(max(0.001, target_scale.x), max(0.001, target_scale.y))
	if _is_scale_close(_current_target_scale, safe_target):
		return

	_current_target_scale = safe_target

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.tween_property(_sprite, "scale", safe_target, tween_duration)

	_reset_timer.stop()
	if start_reset_timer:
		_reset_timer.start(reset_delay_seconds)

func _on_reset_timer_timeout() -> void:
	# Return to normal scale after landing squash.
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	_active_tween = create_tween()
	_active_tween.tween_property(_sprite, "scale", Vector2.ONE, tween_duration)
	_current_target_scale = Vector2.ONE

func _is_scale_close(a: Vector2, b: Vector2) -> bool:
	return abs(a.x - b.x) <= SCALE_EPSILON and abs(a.y - b.y) <= SCALE_EPSILON
