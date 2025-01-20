extends State

@export var fall_state: State
@export var idle_state: State
@export var run_state: State
@export var jump_state: State

@export var vertical_jump_force: float = 340.0
@export var horizontal_jump_force: float = 150
@export var jump_buffer_duration: float = 0.15

func enter() -> void:
	super()
	parent.velocity.y = -vertical_jump_force
	
	# Make player jump away from wall and flip the sprite
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = -horizontal_jump_force
		parent.player_sprite.flip_h = true
	else:
		parent.velocity.x = horizontal_jump_force
		parent.player_sprite.flip_h = false

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	
	if parent.velocity.y > 0:
		return fall_state
	
	var direction = Input.get_axis('move_left', 'move_right')
	
	parent.move_and_slide()
	
	if parent.is_on_floor():
		if direction != 0:
			return run_state
		return idle_state
	
	return null
