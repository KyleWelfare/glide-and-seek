extends State

@export var wall_climb_state: State
@export var wall_slide_state: State
@export var fall_state: State
@export var wall_jump_state: State

func enter() -> void:
	super()
	parent.velocity = Vector2(0, 0)

func process_input(event: InputEvent) -> State:
	var climb_direction := Input.get_axis("move_up", "move_down")
	if climb_direction < 0:
		return wall_climb_state
	elif climb_direction > 0:
		return wall_slide_state

	if Input.is_action_just_pressed("jump"):
		return wall_jump_state

	# Releasing RT drops
	if Input.is_action_just_released("cling_dash"):
		return fall_state

	return null

func process_physics(delta: float) -> State:
	# Keep slight push into wall to maintain contact
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = 10
	else:
		parent.velocity.x = -10

	parent.move_and_slide()
	return null
