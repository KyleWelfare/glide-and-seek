extends State

@export var idle_state: State
@export var fall_state: State
@export var jump_state: State
@export var run_state: State
@export var ground_dash_state: State

var _exit_to_ground_dash: bool = false

const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

const HORIZONTAL_DEADZONE: float = 0.0
const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

func enter() -> void:
	super()
	_exit_to_ground_dash = false
	parent.stop_dash_carry()
	parent.velocity.x = 0.0
	parent.can_double_jump = true
	# Use short collider while ducking (shared with GroundDash).
	parent.regular_collision.disabled = true
	parent.ground_dash_collision.disabled = false

func process_input(event: InputEvent) -> State:
	var axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if absf(axis) > HORIZONTAL_DEADZONE:
		parent.set_facing(axis > 0.0)
		parent.last_horizontal_dir = DIRECTION_LEFT if axis < 0.0 else DIRECTION_RIGHT

	# In cramped tunnels, only allow GroundDash.
	if parent.is_cramped_tunnel():
		if Input.is_action_just_pressed(INPUT_CLING_DASH):
			_exit_to_ground_dash = true
			return ground_dash_state
		return null

	# Normal grounded exits.
	if parent.is_on_floor():
		if Input.is_action_just_pressed(INPUT_JUMP):
			return jump_state
		if Input.is_action_just_pressed(INPUT_CLING_DASH):
			_exit_to_ground_dash = true
			return ground_dash_state

	# Stand up when releasing down.
	if Input.is_action_just_released(INPUT_MOVE_DOWN):
		if absf(axis) > HORIZONTAL_DEADZONE:
			return run_state
		return idle_state

	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	parent.move_and_slide()

	# Consume buffered inputs while ducking.
	if parent.dash_buffer_timer > 0.0:
		parent.dash_buffer_timer = 0.0
		_exit_to_ground_dash = true
		return ground_dash_state

	if parent.jump_buffer_timer > 0.0:
		parent.jump_buffer_timer = 0.0
		return jump_state

	# If briefly airborne inside a cramped tunnel, remain ducking.
	if !parent.is_on_floor():
		if parent.is_cramped_tunnel():
			return null
		return fall_state

	return null

func exit() -> void:
	# Keep short collider if transitioning to GroundDash; otherwise restore tall collider.
	if _exit_to_ground_dash:
		_exit_to_ground_dash = false
	else:
		parent.regular_collision.disabled = false
		parent.ground_dash_collision.disabled = true
