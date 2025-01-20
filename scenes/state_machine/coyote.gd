extends State

@export var idle_state: State
@export var run_state: State
@export var jump_state: State
@export var fall_state: State
@export var glide_state: State

var coyote_timer: float = 0
@export var coyote_duration: float = 0.125

func enter() -> void:
	super()
	coyote_timer = coyote_duration

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta

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
		return jump_state
	
	coyote_timer -= delta
	if coyote_timer <= 0:
		return fall_state
	
	if Input.is_action_pressed("glide_cling_dash"):
		return glide_state
		
	return null
