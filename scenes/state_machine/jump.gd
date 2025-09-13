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

func enter() -> void:
	super()
	parent.velocity.y = -jump_force
	played_air_transition = false
	double_jump_ready = false
	time_in_state = 0.0

func process_input(event: InputEvent) -> State:
	if event.is_action_released("jump"):
		double_jump_ready = true
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# Vertical
	var is_rising: bool = parent.velocity.y < 0.0
	if is_rising:
		var cut_jump_now: bool = time_in_state >= min_jump_hold_time and !Input.is_action_pressed("jump")
		if cut_jump_now:
			parent.velocity.y += gravity * jump_cut_gravity_multiplier * delta
		else:
			parent.velocity.y += gravity * delta
	else:
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

	if parent.velocity.y > -100.0 and !played_air_transition:
		parent.player_anims.play("air_transition")
		played_air_transition = true

	# Buffer dash if pressed while airborne (redundant with Player-level arming; fine)
	if Input.is_action_just_pressed("cling_dash") and !parent.is_on_floor():
		parent.dash_buffer_timer = parent.dash_buffer_duration

	# Glide
	if Input.is_action_just_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Double jump or buffer jump for landing
	if Input.is_action_just_pressed("jump") and !parent.is_on_floor() and double_jump_ready:
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration

	# Apex → Fall
	if parent.velocity.y > 0.0:
		if Input.is_action_pressed("glide") and parent.is_glide_available():
			return glide_state
		return fall_state

	# Landing: consume buffered dash first (same frame)
	if parent.is_on_floor():
		if parent.dash_buffer_timer > 0.0 or Input.is_action_just_pressed("cling_dash"):
			parent.dash_buffer_timer = 0.0
			return ground_dash_state

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
