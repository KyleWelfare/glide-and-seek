extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var wall_idle_state: State
@export var glide_state: State

@export var jump_force: float = 340.0
@export var jump_buffer_duration: float = 0.15

# --- Variable jump height tunables ---
# Minimum time (seconds) after jump begins that we allow normal gravity even if Jump is released.
@export var min_jump_hold_time: float = 0.06
# Extra gravity multiplier applied while still rising if the player has released Jump (after the min hold).
@export var jump_cut_gravity_multiplier: float = 2.8
# Safety cap for fall speed. If you already cap elsewhere, keep this equal or lower.
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
	# Arm the double jump once jump is released
	if event.is_action_released("jump"):
		double_jump_ready = true
	return null

func process_physics(delta: float) -> State:
	time_in_state += delta

	# --- Controlled gravity for variable jump height ---
	var is_rising: bool = parent.velocity.y < 0.0
	if is_rising:
		# Guarantee a tiny hop even for very quick taps, then allow jump-cut
		var cut_jump_now: bool = time_in_state >= min_jump_hold_time and not Input.is_action_pressed("jump")
		if cut_jump_now:
			parent.velocity.y += gravity * jump_cut_gravity_multiplier * delta
		else:
			parent.velocity.y += gravity * delta
	else:
		# Falling or apex reached: normal gravity
		parent.velocity.y += gravity * delta

	# Clamp downward speed
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# --- Horizontal input ---
	var axis: float = Input.get_axis("move_left", "move_right")
	var movement: float = axis * move_speed
	if movement != 0.0:
		parent.player_sprite.flip_h = movement < 0.0
		parent.last_horizontal_dir = -1 if movement < 0.0 else 1
	parent.velocity.x = movement

	parent.move_and_slide()

	# Early air animation cue
	if parent.velocity.y > -100.0 and not played_air_transition:
		parent.player_anims.play("air_transition")
		played_air_transition = true

	# --- Glide handling in Jump ---
	# If the player PRESSES glide during jump, cancel jump immediately into glide.
	if Input.is_action_just_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Double jump: only after a release since entering Jump
	if Input.is_action_just_pressed("jump") and not parent.is_on_floor() and double_jump_ready:
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration

	# Rising -> Falling (apex): if GLIDE is being HELD, go straight to Glide (no 1-frame Fall).
	if parent.velocity.y > 0.0:
		if Input.is_action_pressed("glide") and parent.is_glide_available():
			return glide_state
		return fall_state

	# Grounded outcomes
	if parent.is_on_floor():
		if movement != 0.0:
			return run_state
		if Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	# Wall cling
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	return null
