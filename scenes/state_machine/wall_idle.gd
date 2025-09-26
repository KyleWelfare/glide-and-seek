extends State

@export var wall_climb_state: State
@export var wall_slide_state: State
@export var wall_jump_state: State
@export var wall_coyote_state: State

const INPUT_MOVE_UP: String = "move_up"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

func enter() -> void:
	super()
	parent.stop_dash_carry()
	parent.velocity = Vector2.ZERO
	# Regain mid-air double jump when clinging to the wall.
	parent.can_double_jump = true

	# Face the wall based on the ray's collision normal (if available).
	# normal.x > 0 → wall on left → face left; normal.x < 0 → wall on right → face right.
	if parent.wall_ray_cast and parent.wall_ray_cast.is_colliding():
		var n: Vector2 = parent.wall_ray_cast.get_collision_normal()
		parent.set_facing(n.x < 0.0)

func process_input(event: InputEvent) -> State:
	var climb_direction: float = Input.get_axis(INPUT_MOVE_UP, INPUT_MOVE_DOWN)
	if climb_direction < 0.0:
		return wall_climb_state
	elif climb_direction > 0.0:
		return wall_slide_state

	if event.is_action_pressed(INPUT_JUMP):
		return wall_jump_state

	# Releasing cling enters WallCoyote (grace window).
	if event.is_action_released(INPUT_CLING_DASH):
		return wall_coyote_state

	return null

func process_physics(delta: float) -> State:
	# No push-into-wall needed with raycast-gated entry.
	parent.move_and_slide()
	return null
