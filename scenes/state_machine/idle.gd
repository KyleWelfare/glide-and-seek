extends State

# REVIEW: Ensure all exported states are assigned in the inspector to avoid null transitions at runtime.
@export var fall_state: State
@export var jump_state: State
@export var run_state: State
@export var ground_dash_state: State
@export var duck_state: State

# Input action names kept local to avoid magic strings.
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"
const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_MOVE_DOWN: String = "move_down"

# Kept at 0.0 to preserve existing behavior; raise if you want to ignore tiny stick drift.
const DIRECTION_DEADZONE: float = 0.0

func enter() -> void:
	super()
	parent.stop_dash_carry()
	parent.velocity.x = 0.0
	parent.can_double_jump = true

func process_input(event: InputEvent) -> State:
	if parent.is_on_floor():
		if Input.is_action_just_pressed(INPUT_JUMP):
			return jump_state
		elif Input.is_action_just_pressed(INPUT_CLING_DASH):
			return ground_dash_state

	var horizontal_input: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if absf(horizontal_input) > DIRECTION_DEADZONE:
		return run_state

	if Input.is_action_just_pressed(INPUT_MOVE_DOWN):
		return duck_state

	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	parent.move_and_slide()

	# Buffered inputs are consumed after movement to keep ordering stable.
	if parent.dash_buffer_timer > 0.0:
		parent.dash_buffer_timer = 0.0
		return ground_dash_state

	if parent.jump_buffer_timer > 0.0:
		parent.jump_buffer_timer = 0.0
		return jump_state

	if !parent.is_on_floor():
		return fall_state

	return null
