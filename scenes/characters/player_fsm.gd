class_name Player
extends CharacterBody2D

@onready var player_anims: AnimationPlayer = $PlayerAnims
@onready var state_machine: Node = $StateMachine
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var regular_collision: CollisionShape2D = $RegularCollision
@onready var glide_collision: CollisionShape2D = $GlideCollision
@onready var ground_dash_collision: CollisionShape2D = $GroundDashCollision

@onready var double_jump_label: Label = $DoubleJumpLabel
@onready var state_label: Label = $StateLabel

var jump_buffer_timer: float = 0
var can_double_jump: bool = true

func _ready() -> void:
	# Initialize the state machine, passing a reference of the player to the states,
	# that way they can move and react accordingly
	state_machine.init(self)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	state_machine.process_physics(delta)
	
func _process(delta: float) -> void:
	state_machine.process_frame(delta)
	#print(state_machine.current_state)
	
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta

	double_jump_label.text = str(can_double_jump)
	state_label.text = str(state_machine.current_state)
