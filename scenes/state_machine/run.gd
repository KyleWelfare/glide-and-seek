extends State

@export var duck_state: State
@export var fall_state: State
@export var idle_state: State
@export var jump_state: State
@export var ground_dash_state: State
@export var coyote_state: State

func enter() -> void:
	super()
	parent.stop_dash_carry() # clear any stale air carry
	parent.can_double_jump = true

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_pressed("jump"):
		return jump_state
	elif Input.is_action_just_pressed("cling_dash"):
		return ground_dash_state
	elif Input.is_action_just_pressed("move_down"):
		return duck_state
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta

	if parent.jump_buffer_timer > 0.0:
		return jump_state

	var movement: float = Input.get_axis("move_left", "move_right") * move_speed
	if movement == 0.0:
		return idle_state

	parent.player_sprite.flip_h = movement < 0.0
	parent.last_horizontal_dir = -1 if movement < 0.0 else 1
	parent.velocity.x = movement
	parent.move_and_slide()

	if !parent.is_on_floor():
		return coyote_state
	return null
