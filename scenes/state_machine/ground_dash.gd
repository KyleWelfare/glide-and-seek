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

# Internal: if we decided to go to Duck, don't expand collider in exit()
var _exit_to_duck: bool = false

func enter() -> void:
	super()
	# Use short collider while dashing
	parent.regular_collision.disabled = true
	parent.ground_dash_collision.disabled = false

	dash_time_left = dash_duration
	_exit_to_duck = false

	# Prefer current input; otherwise use facing direction
	var input_axis: float = Input.get_axis("move_left", "move_right")
	dash_dir_sign = -1 if parent.player_sprite.flip_h else 1
	if input_axis != 0.0:
		dash_dir_sign = -1 if input_axis < 0.0 else 1
	parent.last_horizontal_dir = dash_dir_sign
	parent.velocity.x = dash_speed * float(dash_dir_sign)

func process_input(event: InputEvent) -> State:
	# Jump-cancel on floor transfers dash speed into the jump via air-carry.
	if Input.is_action_just_pressed("jump") and parent.is_on_floor():
		parent.start_dash_carry()
		return jump_state

	# Normal cancel behaviour (no special case)—on floor we choose post-dash state.
	if Input.is_action_just_released("cling_dash") and parent.is_on_floor():
		return _choose_post_dash_state()

	return null

func process_physics(delta: float) -> State:
	# Maintain dash motion every frame
	parent.velocity.x = dash_speed * float(dash_dir_sign)
	parent.velocity.y += gravity * delta

	var attempted_x: float = parent.velocity.x
	parent.move_and_slide()

	# 1) Early exit if blocked by a wall in dash direction (grounded path only)
	var hit_blocking_wall: bool = false
	if attempted_x != 0.0:
		for i in range(parent.get_slide_collision_count()):
			var col: KinematicCollision2D = parent.get_slide_collision(i)
			var n: Vector2 = col.get_normal()
			if n.x == -float(dash_dir_sign):
				hit_blocking_wall = true
				break
	if hit_blocking_wall:
		if !parent.is_on_floor():
			parent.start_dash_carry()
			return coyote_state
		return _choose_post_dash_state()

	# 2) If airborne, switch to Coyote with carry
	if !parent.is_on_floor():
		parent.start_dash_carry()
		return coyote_state

	# 3) Normal timeout → choose post-dash state (no early exit)
	dash_time_left -= delta
	if dash_time_left <= 0.0:
		return _choose_post_dash_state()

	return null

func _choose_post_dash_state() -> State:
	# If cramped (both rays colliding), we must crouch.
	if parent.is_cramped_tunnel():
		_exit_to_duck = true
		return duck_state

	# Not cramped → usual grounded choice
	var axis: float = Input.get_axis("move_left", "move_right")
	if axis != 0.0:
		return run_state
	elif Input.is_action_pressed("move_down"):
		return duck_state
	return idle_state

func exit() -> void:
	# If we are transitioning to Duck, keep the short collider—Duck will manage it.
	if _exit_to_duck:
		_exit_to_duck = false
	else:
		# Normal exits restore tall collider
		parent.regular_collision.disabled = false
		parent.ground_dash_collision.disabled = true

	# If we left the ground during the last frame, start air carry
	if !parent.is_on_floor():
		parent.start_dash_carry()
