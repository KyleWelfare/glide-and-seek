extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var wall_idle_state: State

@export var jump_force: float = 340.0
@export var jump_buffer_duration: float = 0.15

func enter() -> void:
	super()
	parent.velocity.y = -jump_force

func process_input(event: InputEvent) -> State:
	# I don't understand why I had to check if parent is on floor here but if I don't, sometimes regular jump sets double_jump to false
	if Input.is_action_just_pressed("jump") and not parent.is_on_floor():
		if parent.can_double_jump:
			parent.can_double_jump = false
			return jump_state
		else:
			parent.jump_buffer_timer = jump_buffer_duration
			
	return null
			
func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	
	var movement = Input.get_axis('move_left', 'move_right') * move_speed
	if movement != 0:
		parent.player_sprite.flip_h = movement < 0
	parent.velocity.x = movement
	parent.move_and_slide()
	
	if parent.velocity.y > -100:
		parent.player_anims.play("air_transition")
	
	if parent.velocity.y > 0:
		return fall_state
		
	if parent.is_on_floor():
		if movement != 0:
			return run_state
		elif Input.is_action_pressed("move_down"):
			return duck_state
		return idle_state
	
	if parent.is_on_wall() and Input.is_action_pressed("glide_cling_dash"):
		return wall_idle_state
	
	
	return null
