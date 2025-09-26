extends State

@export var idle_state: State
@export var wall_idle_state: State
@export var wall_slide_state: State
@export var wall_jump_state: State
@export var wall_coyote_state: State

@export var climb_speed: float = 200.0

const INPUT_MOVE_UP: String = "move_up"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

const VERTICAL_DEADZONE: float = 0.0

func enter() -> void:
	super()
	parent.stop_dash_carry()
	parent.velocity = Vector2.ZERO
	# Regain mid-air double jump as soon as we are clinging to the wall.
	parent.can_double_jump = true

	# Face the wall based on the ray's normal if available.
	if parent.wall_ray_cast and parent.wall_ray_cast.is_colliding():
		var n: Vector2 = parent.wall_ray_cast.get_collision_normal()
		parent.set_facing(n.x < 0.0)

func process_input(event: InputEvent) -> State:
	if event.is_action_released(INPUT_CLING_DASH):
		return wall_coyote_state
	if event.is_action_pressed(INPUT_JUMP):
		return wall_jump_state
	return null

func process_physics(delta: float) -> State:
	var movement: float = Input.get_axis(INPUT_MOVE_UP, INPUT_MOVE_DOWN) * climb_speed
	if absf(movement) <= VERTICAL_DEADZONE:
		return wall_idle_state
	elif movement > 0.0:
		return wall_slide_state

	# If wall contact is lost per the ray, enter wall coyote (grace window).
	if !(parent.wall_ray_cast and parent.wall_ray_cast.is_colliding()):
		return wall_coyote_state

	parent.velocity.x = 0.0
	parent.velocity.y = movement
	parent.move_and_slide()
	return null
