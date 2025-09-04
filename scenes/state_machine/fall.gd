extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State

@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 500.0

# --- Fast-fall tunable ---
# Multiplier applied to gravity while falling if the player holds "move_down".
# Keep this subtle (1.2–1.35) so it aids landing control without feeling like a new move.
@export var fast_fall_gravity_multiplier: float = 2.25

func process_input(event: InputEvent) -> State:
	if event.is_action_pressed("jump"):
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration
	return null

func process_physics(delta: float) -> State:
	# --- Gravity (+ optional fast-fall) ---
	var is_falling: bool = parent.velocity.y > 0.0
	var in_air: bool = not parent.is_on_floor()
	var glide_held: bool = Input.is_action_pressed("glide") and parent.is_glide_available()
	var want_fast_fall: bool = Input.is_action_pressed("move_down")

	# Only apply fast-fall when:
	# - actually falling
	# - in the air
	# - not gliding (glide is your slow fall)
	# - not during dash carry (avoid surprising interactions)
	var use_fast_fall: bool = is_falling and in_air and not glide_held and not parent.dash_carry_active and want_fast_fall

	var gravity_multiplier: float = fast_fall_gravity_multiplier if use_fast_fall else 1.0
	parent.velocity.y += gravity * gravity_multiplier * delta

	# Clamp downward speed
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# --- Air control or dash-carry ---
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
	# Start gliding while falling (hold)
	if Input.is_action_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Wall cling
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	# --- Grounded outcomes ---
	if parent.is_on_floor():
		if axis != 0.0:
			return run_state
		if Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	return null
