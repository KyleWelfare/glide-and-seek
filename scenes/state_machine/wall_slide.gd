extends State

@export var idle_state: State
@export var fall_state: State
@export var wall_idle_state: State
@export var wall_climb_state: State
@export var wall_jump_state: State

@export var max_slide_speed: float = 350

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_released("glide_cling_dash") or not parent.is_on_wall():
		return fall_state
		
	if Input.is_action_just_pressed("jump"):
		return wall_jump_state
	return null

func process_physics(delta: float) -> State:
	var direction = Input.get_axis('move_up', 'move_down')
	if direction == 0:
		return wall_idle_state
	elif direction < 0:
		return wall_climb_state
		
	if parent.is_on_floor():
		return idle_state
	
	# Ensure that player is always colliding with wall while in this state even if not using arrow keys
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = 10
	else:
		parent.velocity.x = -10
		
	parent.velocity.y += gravity * direction * delta
	
	if parent.velocity.y > max_slide_speed:
		parent.velocity.y = max_slide_speed
	
	parent.move_and_slide()
	
	return null
