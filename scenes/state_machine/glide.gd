extends State

@export var idle_state: State
@export var run_state: State
@export var jump_state: State
@export var fall_state: State
@export var wall_idle_state: State

@export var glide_gravity: float = 100

func enter() -> void:
	super()
	parent.velocity.y = 0
	
	#parent.vertical_collision.disabled = true
	#parent.horizontal_collision.disabled = false

func process_physics(delta: float) -> State:
	parent.velocity.y = glide_gravity

	var movement = Input.get_axis('move_left', 'move_right') * move_speed
	if movement != 0:
		parent.player_sprite.flip_h = movement < 0
	parent.velocity.x = movement
	parent.move_and_slide()
	
	if parent.is_on_floor():
		if movement != 0:
			return run_state
		return idle_state
	
	if Input.is_action_just_pressed('jump'):
		if parent.can_double_jump == true:
			parent.can_double_jump = false
			return jump_state
	
	if Input.is_action_just_released("glide_cling_dash"):
		return fall_state
		
	if parent.is_on_wall():
		return wall_idle_state
		
	return null

func exit() -> void:
	#parent.vertical_collision.disabled = false
	#parent.horizontal_collision.disabled = true
	pass
