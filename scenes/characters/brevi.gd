extends CharacterBody2D

#															<--- VARIABLES --->
#ONREADY VARS
@onready var brevi_sprite: Sprite2D = $BreviSprite
@onready var state_chart: StateChart = $StateChart
@onready var glide_stamina_bar: ProgressBar = $GlideStaminaBar
@onready var brevi_anims: AnimationPlayer = $BreviAnims
@onready var coyote_timer: Timer = $CoyoteTimer

#EXPORT VARS
@export var run_speed: float = 200.0
@export var deceleration: float = 0.1
@export var gravity: float = 20.0
@export var jump_height: float = -600.0

#PUBLIC VARS
var direction: float = 0
var double_jump: int = 1

#															<--- FUNCTIONS --->
func _ready() -> void:
	pass # Replace with function body.

func _physics_process(delta: float) -> void:
	direction = Input.get_axis("move_left", "move_right")
	
	#Handle state group transitions
	if state_chart.current_state == is_on_floor():
		state_chart.send_event("collide_floor")
		
	elif is_on_wall() and not is_on_floor():
		state_chart.send_event("collide_wall")
	
	#Handle character horizontal flip
	if direction > 0:
		brevi_sprite.flip_h = false
	elif direction < 0:
		brevi_sprite.flip_h = true

#<--- STATE ENTER FUNCTIONS --->
#STATE GROUPS
func _on_ground_state_entered() -> void:
	pass

func _on_air_state_entered() -> void:
	pass # Replace with function body.

func _on_wall_state_entered() -> void:
	pass # Replace with function body.

#<--- STATE PHYSICS_PROCESS FUNCTIONS --->
#STATE GROUPS
func _on_ground_state_physics_processing(delta: float) -> void:
	#if not is_on_floor() and not is_on_wall() and not Input.is_action_pressed("jump"):
		#state_chart.send_event("is_in_air")
	if Input.is_action_just_pressed("jump"):
		jump(delta)

func _on_air_state_physics_processing(delta: float) -> void:
	apply_gravity()
	horizontal_input()
	move_and_slide()

func _on_wall_state_physics_processing(delta: float) -> void:
	apply_gravity()
	horizontal_input()
	move_and_slide()

#INDIVIDUAL STATES
func _on_idle_state_physics_processing(delta: float) -> void:
	#Transition to state: Run
	direction = Input.get_axis("move_left", "move_right")
	if direction != 0:
		state_chart.send_event("run")
	move_and_slide()
	
	brevi_anims.play("idle")
	
func _on_run_state_physics_processing(delta: float) -> void:
	horizontal_input()
	
	#Transition to state: Idle
	if velocity.x == 0:
		state_chart.send_event("run_stop")
	
	move_and_slide()
	
	#Play animation: Run
	brevi_anims.play("run")

func _on_airborne_state_physics_processing(delta: float) -> void:
	apply_gravity()
	
	if velocity.y < 0:
		brevi_anims.play("jump")
	else: brevi_anims.play("fall")

#	<--- ACTION FUNCTIONS --->
func horizontal_input():
	direction = Input.get_axis("move_left", "move_right")
	velocity.x = run_speed * direction
	if direction == 0:
		velocity.x = move_toward(velocity.x, 0, deceleration)

func jump(delta: float) -> void:
	velocity.y = jump_height
	state_chart.send_event("jump")
		
func apply_gravity():
	velocity.y += gravity
