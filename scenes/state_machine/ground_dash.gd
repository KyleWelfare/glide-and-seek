extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var fall_state: State
@export var coyote_state: State

@export var dash_speed: float = 400.0
@export var dash_duration: float = 0.25

var dash_time_left: float = 0.0
var dash_dir_sign: int = 1
var _exit_to_duck: bool = false

const INPUT_MOVE_LEFT: String = "move_left"
const INPUT_MOVE_RIGHT: String = "move_right"
const INPUT_MOVE_DOWN: String = "move_down"
const INPUT_JUMP: String = "jump"
const INPUT_CLING_DASH: String = "cling_dash"

const HORIZONTAL_DEADZONE: float = 0.0
const DIRECTION_LEFT: int = -1
const DIRECTION_RIGHT: int = 1

# Collision normal must oppose dash direction at least this strongly to count as blocking.
const WALL_BLOCK_DOT_MIN: float = 0.9

func enter() -> void:
	super()
	# Use short collider while dashing.
	parent.regular_collision.disabled = true
	parent.ground_dash_collision.disabled = false

	dash_time_left = dash_duration
	_exit_to_duck = false

	# Prefer current input; otherwise use facing direction.
	var input_axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if absf(input_axis) > HORIZONTAL_DEADZONE:
		dash_dir_sign = DIRECTION_LEFT if input_axis < 0.0 else DIRECTION_RIGHT
	else:
		dash_dir_sign = parent.last_horizontal_dir

	# Centralized facing update:
	parent.set_facing(dash_dir_sign == DIRECTION_RIGHT)
	parent.last_horizontal_dir = dash_dir_sign

	parent.velocity.x = dash_speed * float(dash_dir_sign)

func process_input(event: InputEvent) -> State:
	# Jump-cancel on floor transfers dash speed into the jump via air-carry.
	if Input.is_action_just_pressed(INPUT_JUMP) and parent.is_on_floor():
		parent.start_dash_carry()
		return jump_state

	# Early cancel: releasing dash on floor.
	if Input.is_action_just_released(INPUT_CLING_DASH) and parent.is_on_floor():
		return _choose_post_dash_state()

	return null

func process_physics(delta: float) -> State:
	# Maintain dash motion every frame.
	parent.velocity.x = dash_speed * float(dash_dir_sign)
	parent.velocity.y += gravity * delta

	var attempted_x: float = parent.velocity.x
	parent.move_and_slide()

	# 1) Early exit if blocked by a wall in dash direction (grounded path only).
	var hit_blocking_wall: bool = false
	if attempted_x != 0.0:
		var dash_normal: Vector2 = Vector2(float(dash_dir_sign), 0.0)
		for i in range(parent.get_slide_collision_count()):
			var col: KinematicCollision2D = parent.get_slide_collision(i)
			var n: Vector2 = col.get_normal()
			if n.dot(dash_normal) <= -WALL_BLOCK_DOT_MIN:
				hit_blocking_wall = true
				break
	if hit_blocking_wall:
		if !parent.is_on_floor():
			parent.start_dash_carry()
			return coyote_state
		return _choose_post_dash_state()

	# 2) If airborne, switch to Coyote with carry.
	if !parent.is_on_floor():
		parent.start_dash_carry()
		return coyote_state

	# 3) Normal timeout → choose post-dash state.
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		return _choose_post_dash_state()

	return null

func _choose_post_dash_state() -> State:
	# If cramped (both rays colliding), we must crouch.
	if parent.is_cramped_tunnel():
		_exit_to_duck = true
		return duck_state

	# Not cramped → usual grounded choice.
	var axis: float = Input.get_axis(INPUT_MOVE_LEFT, INPUT_MOVE_RIGHT)
	if absf(axis) > HORIZONTAL_DEADZONE:
		return run_state
	elif Input.is_action_pressed(INPUT_MOVE_DOWN):
		return duck_state
	return idle_state

func exit() -> void:
	# If we are transitioning to Duck, keep the short collider; otherwise restore tall collider.
	if _exit_to_duck:
		_exit_to_duck = false
	else:
		parent.regular_collision.disabled = false
		parent.ground_dash_collision.disabled = true

	# If we left the ground during the last frame, start air carry.
	if !parent.is_on_floor():
		parent.start_dash_carry()
