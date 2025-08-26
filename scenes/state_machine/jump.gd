extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var wall_idle_state: State

@export var jump_force: float = 340.0
@export var jump_buffer_duration: float = 0.15

var played_air_transition: bool = false
var double_jump_ready: bool = false

func enter() -> void:
	super()
	parent.velocity.y = -jump_force
	played_air_transition = false
	# Require a release before allowing a double jump, so the
	# initial coyote-press can't eat the double jump.
	double_jump_ready = false

func process_input(event: InputEvent) -> State:
	# Allow the state to "arm" the double jump once jump is released
	if event.is_action_released("jump"):
		double_jump_ready = true
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta

	var movement := Input.get_axis('move_left', 'move_right') * move_speed
	if movement != 0:
		parent.player_sprite.flip_h = movement < 0
		parent.last_horizontal_dir = -1 if movement < 0 else 1
	parent.velocity.x = movement
	parent.move_and_slide()

	if parent.velocity.y > -100 and !played_air_transition:
		parent.player_anims.play("air_transition")
		played_air_transition = true

	# Only permit a double jump after a release since entering Jump
	if Input.is_action_just_pressed("jump") and not parent.is_on_floor() and double_jump_ready:
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration

	if parent.velocity.y > 0:
		return fall_state

	if parent.is_on_floor():
		if movement != 0:
			return run_state
		elif Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state

	# RT to cling when touching a wall
	if parent.is_on_wall() and Input.is_action_pressed("cling_dash"):
		return wall_idle_state

	return null
