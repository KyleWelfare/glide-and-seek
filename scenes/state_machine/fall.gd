extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State

@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 500.0

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_pressed("jump"):
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	var axis: float = Input.get_axis('move_left', 'move_right')
	var movement: float = axis * move_speed

	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
	else:
		parent.velocity.x = movement
		if axis != 0.0:
			parent.player_sprite.flip_h = axis < 0.0
			parent.last_horizontal_dir = -1 if axis < 0.0 else 1

	parent.move_and_slide()

	if parent.is_on_floor():
		if axis != 0.0:
			return run_state
		elif Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	if Input.is_action_pressed("glide"):
		if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
			return wall_idle_state
		return glide_state

	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	return null
