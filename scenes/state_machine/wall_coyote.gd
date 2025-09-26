extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var wall_idle_state: State
@export var wall_jump_state: State
@export var glide_state: State

@export var wall_coyote_time: float = 0.20
@export var max_fall_speed: float = 500.0

var time_in_state: float = 0.0

const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
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
	# Jump during grace window → wall jump.
	if event.is_action_pressed(INPUT_JUMP):
		return wall_jump_state
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# Gravity + clamp
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Air control or dash-carry (mirrors fall.gd)
	var axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
	else:
		parent.velocity.x = axis * move_speed
		if absf(axis) > HORIZONTAL_DEADZONE:
			parent.set_facing(axis > 0.0)
			parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT

	parent.move_and_slide()

	# Immediate re-grab if pressing cling while the ray sees a wall.
	if parent.wall_ray_cast.is_colliding() and Input.is_action_pressed(INPUT_CLING_DASH):
		return wall_idle_state

	# Glide while falling.
	if Input.is_action_pressed(INPUT_GLIDE) and parent.is_glide_available():
		return glide_state

	# Timer expired → normal fall.
	if time_in_state >= wall_coyote_time:
		return fall_state

	# Grounded outcomes.
	if parent.is_on_floor():
		if absf(axis) > HORIZONTAL_DEADZONE:
			return run_state
		return idle_state

	return null
