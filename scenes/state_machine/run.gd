extends State

# REVIEW: Ensure all exported states are assigned in the inspector.
@export var duck_state: State
@export var fall_state: State
@export var idle_state: State
@export var jump_state: State
@export var ground_dash_state: State
@export var coyote_state: State

# Input action names to avoid magic strings.
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"

# Tunables kept as constants to preserve behavior now.
const HORIZONTAL_DEADZONE: float = 0.0
const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

func enter() -> void:
	super()
	parent.stop_dash_carry()
	parent.can_double_jump = true

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_pressed(INPUT_JUMP):
		return jump_state
	elif Input.is_action_just_pressed(INPUT_CLING_DASH):
		return ground_dash_state
	elif Input.is_action_just_pressed(INPUT_MOVE_DOWN):
		return duck_state
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta

	# Buffered inputs consumed after gravity to keep ordering stable.
	if parent.dash_buffer_timer > 0.0:
		parent.dash_buffer_timer = 0.0
		return ground_dash_state

	if parent.jump_buffer_timer > 0.0:
		parent.jump_buffer_timer = 0.0
		return jump_state

	var horizontal_input: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	var movement_speed: float = horizontal_input * move_speed
	if absf(horizontal_input) <= HORIZONTAL_DEADZONE or movement_speed == 0.0:
		return idle_state

	# Centralized facing + wall-ray flip:
	parent.set_facing(movement_speed > 0.0)
	parent.last_horizontal_dir = DIRECTION_LEFT if movement_speed < 0.0 else DIRECTION_RIGHT

	parent.velocity.x = movement_speed
	parent.move_and_slide()

	if !parent.is_on_floor():
		return coyote_state

	return null
