extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var wall_idle_state: State
@export var glide_state: State
@export var ground_dash_state: State

# Buffers / gravity
@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 1200.0

var played_air_transition: bool = false

func enter() -> void:
	super()
	played_air_transition = false

func process_input(event: InputEvent) -> State:
	return null

func process_physics(delta: float) -> State:
	# Vertical
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Horizontal
	var axis: float = Input.get_axis("move_left", "move_right")
	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
		if axis != 0.0:
			parent.player_sprite.flip_h = axis < 0.0
			parent.last_horizontal_dir = -1 if axis < 0.0 else 1
	else:
		var movement: float = axis * move_speed
		parent.velocity.x = movement
		if axis != 0.0:
			parent.player_sprite.flip_h = axis < 0.0
			parent.last_horizontal_dir = -1 if axis < 0.0 else 1

	parent.move_and_slide()

	if !played_air_transition and parent.velocity.y >= 0.0:
		parent.player_anims.play("fall")
		played_air_transition = true

	# Buffer dash if pressed while airborne (redundant with Player-level arming; fine)
	if Input.is_action_just_pressed("cling_dash") and !parent.is_on_floor():
		parent.dash_buffer_timer = parent.dash_buffer_duration

	# Glide
	if Input.is_action_just_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Double jump or buffer jump for landing
	if Input.is_action_just_pressed("jump") and !parent.is_on_floor():
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration

	# Landing: consume buffered dash first (same frame), then buffered jump
	if parent.is_on_floor():
		if parent.dash_buffer_timer > 0.0 or Input.is_action_just_pressed("cling_dash"):
			parent.dash_buffer_timer = 0.0
			return ground_dash_state

		if parent.jump_buffer_timer > 0.0:
			parent.jump_buffer_timer = 0.0
			return jump_state

		var movement_ground: float = axis * move_speed
		if movement_ground != 0.0:
			return run_state
		if Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	# Wall cling
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	return null
