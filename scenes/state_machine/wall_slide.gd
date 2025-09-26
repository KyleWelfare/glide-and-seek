extends State

@export var idle_state: State
@export var wall_idle_state: State
@export var wall_climb_state: State
@export var wall_jump_state: State
@export var wall_coyote_state: State

@export var max_slide_speed: float = 350.0

const INPUT_MOVE_UP: String = "move_up"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

const VERTICAL_DEADZONE: float = 0.0

func enter() -> void:
	super()
	parent.stop_dash_carry()
	parent.can_double_jump = true

	# Face the wall based on the ray's normal if available.
	if parent.wall_ray_cast and parent.wall_ray_cast.is_colliding():
		var n: Vector2 = parent.wall_ray_cast.get_collision_normal()
		parent.set_facing(n.x < 0.0)

func process_input(event: InputEvent) -> State:
	if event.is_action_released(INPUT_CLING_DASH):
		return wall_coyote_state
	# If wall contact lost, go to coyote.
	if !(parent.wall_ray_cast and parent.wall_ray_cast.is_colliding()):
		return wall_coyote_state
	if event.is_action_pressed(INPUT_JUMP):
		return wall_jump_state
	return null

func process_physics(delta: float) -> State:
	var direction: float = Input.get_axis(INPUT_MOVE_UP, INPUT_MOVE_DOWN)
	if absf(direction) <= VERTICAL_DEADZONE:
		return wall_idle_state
	elif direction < 0.0:
		return wall_climb_state

	if parent.is_on_floor():
		return idle_state

	# Slide downward with cap (positive direction means pressing DOWN).
	parent.velocity.x = 0.0
	parent.velocity.y += gravity * maxf(direction, 1.0) * delta
	if parent.velocity.y > max_slide_speed:
		parent.velocity.y = max_slide_speed

	parent.move_and_slide()
	return null
