extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var wall_idle_state: State
@export var glide_state: State
@export var ground_dash_state: State

@export var jump_force: float = 340.0
@export var jump_buffer_duration: float = 0.15

# Variable jump height tuning
@export var min_jump_hold_time: float = 0.06
@export var jump_cut_gravity_multiplier: float = 2.8
@export var max_fall_speed: float = 1200.0

var played_air_transition: bool = false
var double_jump_ready: bool = false
var time_in_state: float = 0.0

const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"
const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_GLIDE: String = "glide"

const ANIM_AIR_TRANSITION: String = "air_transition"
const AIR_TRANSITION_THRESHOLD: float = -100.0
const HORIZONTAL_DEADZONE: float = 0.0
const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

func enter() -> void:
	super()
	parent.velocity.y = -jump_force
	played_air_transition = false
	double_jump_ready = false
	time_in_state = 0.0

func process_input(event: InputEvent) -> State:
	if event.is_action_released(INPUT_JUMP):
		double_jump_ready = true
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# Vertical
	var is_rising: bool = parent.velocity.y < 0.0
	if is_rising:
		var cut_jump_now: bool = time_in_state >= min_jump_hold_time and !Input.is_action_pressed(INPUT_JUMP)
		if cut_jump_now:
			parent.velocity.y += gravity * jump_cut_gravity_multiplier * delta
		else:
			parent.velocity.y += gravity * delta
	else:
		parent.velocity.y += gravity * delta

	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Horizontal
	var axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
		if absf(axis) > HORIZONTAL_DEADZONE:
			parent.set_facing(axis > 0.0)
			parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT
	else:
		var movement: float = axis * move_speed
		parent.velocity.x = movement
		if absf(axis) > HORIZONTAL_DEADZONE:
			parent.set_facing(axis > 0.0)
			parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT

	parent.move_and_slide()

	if parent.velocity.y > AIR_TRANSITION_THRESHOLD and !played_air_transition:
		parent.player_anims.play(ANIM_AIR_TRANSITION)
		played_air_transition = true

	# Buffer dash if pressed while airborne.
	if Input.is_action_just_pressed(INPUT_CLING_DASH) and !parent.is_on_floor():
		parent.dash_buffer_timer = parent.dash_buffer_duration

	# Glide
	if Input.is_action_just_pressed(INPUT_GLIDE) and parent.is_glide_available():
		return glide_state

	# Double jump or buffer jump for landing
	if Input.is_action_just_pressed(INPUT_JUMP) and !parent.is_on_floor() and double_jump_ready:
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration

	# Apex → Fall
	if parent.velocity.y > 0.0:
		if Input.is_action_pressed(INPUT_GLIDE) and parent.is_glide_available():
			return glide_state
		return fall_state

	# Landing: consume buffered dash first (same frame)
	if parent.is_on_floor():
		if parent.dash_buffer_timer > 0.0 or Input.is_action_just_pressed(INPUT_CLING_DASH):
			parent.dash_buffer_timer = 0.0
			return ground_dash_state

		var movement_ground: float = axis * move_speed
		if movement_ground != 0.0:
			return run_state
		if Input.is_action_pressed(INPUT_MOVE_DOWN):
			return duck_state
		return idle_state

	# Wall cling (raycast-based)
	if parent.wall_ray_cast.is_colliding() and Input.is_action_pressed(INPUT_CLING_DASH):
		return wall_idle_state

	return null
