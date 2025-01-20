extends State

@export var fall_state: State
@export var jump_state: State
@export var run_state: State
@export var ground_dash_state: State
@export var duck_state: State

func enter() -> void:
	super()
	parent.velocity.x = 0
	parent.can_double_jump = true
	
func process_input(event: InputEvent) -> State:
	if parent.is_on_floor():
		if Input.is_action_just_pressed('jump'):
			return jump_state
		elif Input.is_action_just_pressed('glide_cling_dash'):
			return ground_dash_state
	
	#if Input.is_action_just_pressed('move_left') or Input.is_action_just_pressed('move_right'):
	var direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		return run_state
	
	if Input.is_action_just_pressed("move_down"):
		return duck_state
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	parent.move_and_slide()
	
	if parent.jump_buffer_timer > 0:
		return jump_state
	
	if !parent.is_on_floor():
		return fall_state
	
	return null
