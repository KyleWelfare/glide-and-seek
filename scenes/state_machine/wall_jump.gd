extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var glide_state: State
@export var wall_idle_state: State

@export var vertical_jump_force: float = 340.0
@export var horizontal_jump_force: float = 150.0

const INPUT_GLIDE: String = "glide"
const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_CLING_DASH: String = "cling_dash"

const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

func enter() -> void:
	super()
	# Vertical impulse
	parent.velocity.y = -vertical_jump_force

	# Determine wall side from ray; push away and face away from the wall.
	var dir_sign: int = 1 # +1 = right, -1 = left
	if parent.wall_ray_cast and parent.wall_ray_cast.is_colliding():
		var n: Vector2 = parent.wall_ray_cast.get_collision_normal()
		# normal.x > 0 → wall on left → jump to the right (+1)
		# normal.x < 0 → wall on right → jump to the left (-1)
		dir_sign = 1 if n.x > 0.0 else -1

	parent.velocity.x = horizontal_jump_force * float(dir_sign)
	parent.set_facing(dir_sign == 1)
	parent.last_horizontal_dir = DIRECTION_RIGHT if dir_sign == 1 else DIRECTION_LEFT

func process_physics(delta: float) -> State:
	# Gravity
	parent.velocity.y += gravity * delta

	# If the player PRESSES glide during the wall-jump, cancel immediately to Glide.
	if Input.is_action_just_pressed(INPUT_GLIDE) and parent.is_glide_available():
		return glide_state

	# Rising -> Falling (apex): if GLIDE is being HELD, go straight to Glide.
	if parent.velocity.y > 0.0:
		if Input.is_action_pressed(INPUT_GLIDE) and parent.is_glide_available():
			return glide_state
		return fall_state

	# No air control here by design — preserves original feel.
	var direction: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)

	parent.move_and_slide()

	# Grounded outcomes
	if parent.is_on_floor():
		if direction != 0.0:
			return run_state
		return idle_state

	# Wall cling (early reattach)
	if parent.wall_ray_cast.is_colliding() and Input.is_action_pressed(INPUT_CLING_DASH):
		return wall_idle_state

	return null
