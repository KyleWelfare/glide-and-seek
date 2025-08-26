extends State

@export var idle_state: State
@export var fall_state: State
@export var jump_state: State
@export var run_state: State
@export var ground_dash_state: State

# Internal: if we decided to go to GroundDash, don't expand collider in exit()
var _exit_to_ground_dash: bool = false

func enter() -> void:
	super()
	_exit_to_ground_dash = false
	parent.stop_dash_carry() # clear any stale air carry
	parent.velocity.x = 0.0
	parent.can_double_jump = true

	# Duck uses the SHORT collider (same as ground dash)
	parent.regular_collision.disabled = true
	parent.ground_dash_collision.disabled = false

func process_input(event: InputEvent) -> State:
	# Allow facing flip while stationary ducking
	var axis: float = Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		parent.player_sprite.flip_h = axis < 0.0
		parent.last_horizontal_dir = -1 if axis < 0.0 else 1

	# If cramped, ONLY allow transition to GroundDash. Ignore everything else.
	if parent.is_cramped_tunnel():
		if Input.is_action_just_pressed("cling_dash"):
			_exit_to_ground_dash = true
			return ground_dash_state
		return null

	# Not cramped → normal exits allowed
	if parent.is_on_floor():
		if Input.is_action_just_pressed("jump"):
			return jump_state
		if Input.is_action_just_pressed("cling_dash"):
			_exit_to_ground_dash = true
			return ground_dash_state

	# Stand up if "down" released
	if Input.is_action_just_released("move_down"):
		if axis != 0.0:
			return run_state
		return idle_state

	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	parent.move_and_slide()

	# Safety: if we briefly lose floor contact inside the tunnel,
	# stay in Duck instead of falling; you'll regain floor or dash out.
	if !parent.is_on_floor():
		if parent.is_cramped_tunnel():
			return null
		return fall_state

	return null

func exit() -> void:
	# If we are about to dash, keep the short collider—GroundDash will manage it.
	if _exit_to_ground_dash:
		_exit_to_ground_dash = false
	else:
		# Restoring tall collider when leaving duck to idle/run/jump
		parent.regular_collision.disabled = false
		parent.ground_dash_collision.disabled = true
