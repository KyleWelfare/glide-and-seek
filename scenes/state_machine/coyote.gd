extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State
@export var fall_state: State
@export var ground_dash_state: State

@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 500.0
@export var coyote_time: float = 0.08

var time_in_state: float = 0.0

func enter() -> void:
	super()
	time_in_state = 0.0

func process_input(event: InputEvent) -> State:
	# Coyote jump should behave like a ground jump.
	# Do NOT consume the double jump here.
	if event.is_action_pressed("jump"):
		return jump_state
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# Gravity + clamp
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Air control or dash-carry
	var axis: float = Input.get_axis("move_left", "move_right")
	var movement: float = axis * move_speed
	if parent.dash_carry_active:
		parent.velocity.x = parent.apply_air_carry(delta, axis, move_speed)
	else:
		parent.velocity.x = movement
		if axis != 0.0:
			parent.player_sprite.flip_h = axis < 0.0
			parent.last_horizontal_dir = -1 if axis < 0.0 else 1

	parent.move_and_slide()

	# --- Airborne transitions first ---
	# Buffer DASH while airborne so it can trigger on landing.
	if Input.is_action_just_pressed("cling_dash") and !parent.is_on_floor():
		parent.dash_buffer_timer = parent.dash_buffer_duration

	# Start gliding while falling (hold)
	if Input.is_action_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Wall cling
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	# If coyote window expires and we're still airborne → Fall
	if time_in_state >= coyote_time and !parent.is_on_floor():
		return fall_state

	# --- Grounded outcomes (consume buffers on the landing frame) ---
	if parent.is_on_floor():
		# Dash buffer (or fresh press on the landing frame) takes priority.
		if parent.dash_buffer_timer > 0.0 or Input.is_action_just_pressed("cling_dash"):
			parent.dash_buffer_timer = 0.0
			return ground_dash_state

		# Normal grounded routing
		if axis != 0.0:
			return run_state
		if Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	return null
