extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var glide_state: State
@export var wall_idle_state: State

@export var jump_buffer_duration: float = 0.15
@export var max_fall_speed: float = 500

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_pressed("jump"):
		if parent.can_double_jump == true:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration
			
	return null
			
func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	if parent.velocity.y > max_fall_speed:
		parent.velocity.y = max_fall_speed

	var movement = Input.get_axis('move_left', 'move_right') * move_speed
	
	if movement != 0:
		parent.player_sprite.flip_h = movement < 0
	parent.velocity.x = movement
	parent.move_and_slide()
	
	if parent.is_on_floor():
		if movement != 0:
			return run_state
		elif Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state
	
	if Input.is_action_pressed("glide_cling_dash"):
		if parent.is_on_wall():
			return wall_idle_state
		return glide_state
		
	return null
