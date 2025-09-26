extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State
@export var fall_state: State
@export var ground_dash_state: State

@export var max_fall_speed: float = 500.0
@export var coyote_time: float = 0.08

var time_in_state: float = 0.0

const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_GLIDE: String = "glide"
const INPUT_CLING_DASH: String = "cling_dash"

const HORIZONTAL_DEADZONE: float = 0.0
const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

func enter() -> void:
	super()
	time_in_state = 0.0

func process_input(event: InputEvent) -> State:
	# Coyote jump behaves like a ground jump (do not consume double jump here).
	if event.is_action_pressed(INPUT_JUMP):
		return jump_state
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# Gravity + clamp
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Air control or dash-carry
	var axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
		if absf(axis) > HORIZONTAL_DEADZONE:
			parent.set_facing(axis > 0.0)
			parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT
	else:
		parent.velocity.x = axis * move_speed
		if absf(axis) > HORIZONTAL_DEADZONE:
			parent.set_facing(axis > 0.0)
			parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT

	parent.move_and_slide()

	# --- Airborne transitions first ---
	# Buffer dash while airborne so it can trigger on landing.
	if Input.is_action_just_pressed(INPUT_CLING_DASH) and !parent.is_on_floor():
		parent.dash_buffer_timer = parent.dash_buffer_duration

	# Start gliding while falling (hold)
	if Input.is_action_pressed(INPUT_GLIDE) and parent.is_glide_available():
		return glide_state

	# Wall cling (raycast-based)
	if parent.wall_ray_cast.is_colliding() and Input.is_action_pressed(INPUT_CLING_DASH):
		return wall_idle_state

	# If coyote window expires and we're still airborne → Fall
	if time_in_state >= coyote_time and !parent.is_on_floor():
		return fall_state

# --- Grounded outcomes (consume buffers on the landing frame) ---
	if parent.is_on_floor():
		# Dash buffer (or fresh press on the landing frame) takes priority.
		if parent.dash_buffer_timer > 0.0 or Input.is_action_just_pressed(INPUT_CLING_DASH):
			parent.dash_buffer_timer = 0.0
			return ground_dash_state

		# Normal grounded routing
		if absf(axis) > HORIZONTAL_DEADZONE:
			return run_state
		if Input.is_action_pressed(INPUT_MOVE_DOWN):
			return duck_state
		return idle_state

	return null
