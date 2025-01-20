extends State

@export var idle_state: State
@export var run_state: State
@export var duck_state: State
@export var jump_state: State
@export var fall_state: State
@export var coyote_state: State

@export var dash_speed: float = 350.0
@export var dash_duration: float = 0.25

func enter() -> void:
	super()
	parent.regular_collision.disabled = true
	parent.ground_dash_collision.disabled = false
	
	# Reset dash timer
	dash_duration = 0.25
	
	# Get the direction the player is facing and dash
	var moving_left: bool = parent.player_sprite.flip_h
	parent.velocity.x = dash_speed * (-1 if moving_left else 1)

func process_input(event: InputEvent) -> State:
	if Input.is_action_just_pressed('jump') and parent.is_on_floor():
		return jump_state
	return null

func process_physics(delta: float) -> State:
	parent.velocity.y += gravity * delta
	parent.move_and_slide()
	
	dash_duration -= delta
	if dash_duration <= 0:
		var direction = Input.get_axis("move_left", "move_right")
		if direction != 0:
			return run_state
		elif Input.is_action_pressed("move_down"):
			return duck_state
		else:
			return idle_state
	
	if !parent.is_on_floor():
		return coyote_state
	return null

func exit() -> void:
	parent.regular_collision.disabled = false
	parent.ground_dash_collision.disabled = true
