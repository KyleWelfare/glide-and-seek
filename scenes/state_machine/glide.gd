extends State

@export var idle_state: State
@export var run_state: State
@export var jump_state: State
@export var fall_state: State
@export var wall_idle_state: State

# Glide path and horizontal speeds
@export var cruise_angle_deg: float = 10.0
@export var base_glide_speed_x: float = 100.0
@export var minimum_glide_start_speed_x: float = 185.0
@export var max_glide_speed_x: float = 500.0
@export var horizontal_gain_per_downspeed: float = 0.65

# Decay shaping
@export var speed_decay_time: float = 1.90
@export var late_speed_decay_time: float = 3.00

# Vertical settling and entry smoothing
@export var vertical_approach_rate: float = 1000.0
@export var entry_blend_time: float = 0.06
@export var allow_wall_cancel: bool = true

var _facing_sign: int = 1
var _elapsed: float = 0.0
var _blend_elapsed: float = 0.0

var _entry_velocity: Vector2 = Vector2.ZERO
var _initial_speed_x: float = 0.0
var _current_speed_x: float = 0.0
var _exit_on_first_frame: bool = false

const INPUT_GLIDE: String = "glide"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

const GROUNDED_RUN_SPEED_EPS: float = 0.1

func enter() -> void:
	super()

	_facing_sign = DIRECTION_LEFT if parent.last_horizontal_dir < 0 else DIRECTION_RIGHT
	# Centralized facing so the wall ray flips with us.
	parent.set_facing(_facing_sign == DIRECTION_RIGHT)

	# If stamina empty or lockout active, bail next frame.
	_exit_on_first_frame = (parent.current_stamina <= 0.0) or parent.glide_lockout

	# Capture entry velocity BEFORE clearing any dash carry for a tiny entry nudge.
	_entry_velocity = parent.velocity
	parent.stop_dash_carry()

	var entry_downspeed: float = maxf(_entry_velocity.y, 0.0)

	# Entry horizontal speed = base + gain_from_downspeed, clamped to [minimum_at_entry, max].
	var minimum_entry: float = maxf(minimum_glide_start_speed_x, 0.0)
	var base_for_entry: float = maxf(base_glide_speed_x, 0.0)

	_initial_speed_x = base_for_entry + horizontal_gain_per_downspeed * entry_downspeed
	_initial_speed_x = clampf(_initial_speed_x, minimum_entry, max_glide_speed_x)
	_current_speed_x = _initial_speed_x

	_elapsed = 0.0
	_blend_elapsed = 0.0

func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	if _exit_on_first_frame:
		_exit_on_first_frame = false
		return fall_state

	_elapsed += delta
	_blend_elapsed += delta

	# Flat stamina drain → when empty, lockout and fall.
	parent.current_stamina = maxf(0.0, parent.current_stamina - parent.stamina_drain_per_second * delta)
	if parent.current_stamina <= 0.0:
		parent.glide_lockout = true
		return fall_state

	# Two-stage horizontal decay: (initial → minimum) fast, then (minimum → base) slow.
	var minimum_target: float = maxf(minimum_glide_start_speed_x, 0.0)
	var base_target: float = maxf(base_glide_speed_x, 0.0)

	var above_min_initial: float = maxf(_initial_speed_x - minimum_target, 0.0)
	var fast_decay: float = exp(-_elapsed / speed_decay_time) if speed_decay_time > 0.0 else 0.0
	var remaining_above_min: float = above_min_initial * fast_decay

	var slow_decay: float = exp(-_elapsed / late_speed_decay_time) if late_speed_decay_time > 0.0 else 0.0
	var min_to_base_component: float = base_target + (minimum_target - base_target) * slow_decay

	_current_speed_x = min_to_base_component + remaining_above_min
	_current_speed_x = clampf(_current_speed_x, 0.0, max_glide_speed_x)

	# Build target velocity with locked glide angle.
	var angle_rad: float = deg_to_rad(cruise_angle_deg)
	var target_vx: float = float(_facing_sign) * _current_speed_x
	var target_vy: float = tan(angle_rad) * absf(_current_speed_x) # positive is downward in 2D

	# Vertical: approach endpoint gently.
	parent.velocity.y = move_toward(parent.velocity.y, target_vy, vertical_approach_rate * delta)

	# Horizontal: blend from entry to target to avoid a one-frame hitch.
	var desired_vx: float = target_vx
	if _blend_elapsed < entry_blend_time and entry_blend_time > 0.0:
		var s: float = clampf(_blend_elapsed / entry_blend_time, 0.0, 1.0)
		s = _smoothstep01(s)
		desired_vx = lerpf(_entry_velocity.x, target_vx, s)
	parent.velocity.x = desired_vx

	parent.move_and_slide()

	# Transitions
	if Input.is_action_just_released(INPUT_GLIDE):
		return fall_state

	if parent.is_on_floor():
		if absf(parent.velocity.x) > GROUNDED_RUN_SPEED_EPS:
			return run_state
		return idle_state

	if allow_wall_cancel and parent.wall_ray_cast.is_colliding() and Input.is_action_pressed(INPUT_CLING_DASH):
		return wall_idle_state

	if Input.is_action_just_pressed(INPUT_JUMP):
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state

	return null

func exit() -> void:
	pass

func _smoothstep01(t: float) -> float:
	var x: float = clampf(t, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
