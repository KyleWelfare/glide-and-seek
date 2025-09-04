extends State

@export var idle_state: State
@export var wall_idle_state: State
@export var wall_slide_state: State
@export var fall_state: State
@export var wall_jump_state: State
@export var wall_coyote_state: State

@export var climb_speed: float = 200

func enter() -> void:
	super()
	# Regain mid-air double jump as soon as we are clinging to the wall.
	parent.can_double_jump = true

func process_input(event: InputEvent) -> State:
	if event.is_action_released("cling_dash"):
#		return fall_state
		return wall_coyote_state
	if event.is_action_pressed("jump"):
		return wall_jump_state
	return null

func process_physics(delta: float) -> State:
	var movement := Input.get_axis('move_up', 'move_down') * climb_speed
	if movement == 0:
		return wall_idle_state
	elif movement > 0:
		return wall_slide_state

	# Keep contact with wall
	if parent.player_sprite.flip_h == false:
		parent.velocity.x = 10
	else:
		parent.velocity.x = -10

	if not parent.is_on_wall():
		return fall_state

	parent.velocity.y = movement
	parent.move_and_slide()
	return null
