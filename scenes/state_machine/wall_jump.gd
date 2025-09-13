extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State

@export var vertical_jump_force: float = 340.0
@export var horizontal_jump_force: float = 150.0
@export var jump_buffer_duration: float = 0.15

func enter() -> void:
	super()
	# Vertical impulse
	parent.velocity.y = -vertical_jump_force

	# Horizontal push-away + sprite flip (kept as before)
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = -horizontal_jump_force
		parent.player_sprite.flip_h = true
	else:
		parent.velocity.x = horizontal_jump_force
		parent.player_sprite.flip_h = false

	# Keep facing intent in sync with the visual flip (helps states like Glide)
	parent.last_horizontal_dir = -1 if parent.player_sprite.flip_h else 1


func process_physics(delta: float) -> State:
	# Gravity
	parent.velocity.y += gravity * delta

	# --- Glide handling in WallJump ---
	# If the player PRESSES glide during the wall-jump, cancel immediately to Glide.
	if Input.is_action_just_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Rising -> Falling (apex): if GLIDE is being HELD, go straight to Glide.
	if parent.velocity.y > 0.0:
		if Input.is_action_pressed("glide") and parent.is_glide_available():
			return glide_state
		return fall_state

	# No air control here by design — preserves your original feel.
	var direction: float = Input.get_axis("move_left", "move_right")

	parent.move_and_slide()

	# Grounded outcomes
	if parent.is_on_floor():
		if direction != 0.0:
			return run_state
		return idle_state

	# Wall cling (match Jump state's early exit so you can reattach immediately)
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	return null
