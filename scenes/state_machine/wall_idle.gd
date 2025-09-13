extends State

@export var wall_climb_state: State
@export var wall_slide_state: State
@export var fall_state: State
@export var wall_jump_state: State
@export var wall_coyote_state: State

func enter() -> void:
	super()
	parent.stop_dash_carry() # Clear dash-carry when entering wall contact
	parent.velocity = Vector2(0, 0)
	# Regain mid-air double jump as soon as we are clinging to the wall.
	parent.can_double_jump = true

func process_input(event: InputEvent) -> State:
	var climb_direction := Input.get_axis("move_up", "move_down")
	if climb_direction < 0:
		return wall_climb_state
	elif climb_direction > 0:
		return wall_slide_state

	if event.is_action_pressed("jump"):
		return wall_jump_state

	# Releasing cling enters WallCoyote (grace window) instead of immediate fall.
	if event.is_action_released("cling_dash"):
		return wall_coyote_state

	return null

func process_physics(delta: float) -> State:
	# Keep slight push into wall to maintain contact
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = 10
	else:
		parent.velocity.x = -10

	parent.move_and_slide()
	return null
