extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var wall_idle_state: State
@export var wall_jump_state: State
@export var glide_state: State

@export var wall_coyote_time: float = 0.20
@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 500.0

var time_in_state: float = 0.0

func enter() -> void:
	# Optional: set an animation for this state via animation_name if you want a unique pose
	super()
	time_in_state = 0.0

func process_input(event: InputEvent) -> State:
	# If the player jumps during the grace window, perform a wall jump
	if event.is_action_pressed("jump"):
		return wall_jump_state
	return null


func process_physics(delta: float) -> State:
	time_in_state += delta

	# Gravity + clamp
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	# Air control or dash-carry (mirror your fall.gd behavior)
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

	# Allow immediate re-grab if they press cling again while touching the wall
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	# Allow glide while falling (matches fall.gd behavior)
	if Input.is_action_pressed("glide") and parent.is_glide_available():
		return glide_state

	# Timer expired → normal fall
	if time_in_state >= wall_coyote_time:
		return fall_state

	# Grounded outcomes
	if parent.is_on_floor():
		if axis != 0.0:
			return run_state
		return idle_state

	return null
