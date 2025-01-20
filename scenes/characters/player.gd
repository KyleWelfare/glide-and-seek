extends CharacterBody2D

#Defines node vars
@onready var player_sprite = $PlayerSprite
@onready var player_anim = $PlayerAnim
@onready var squash_timer = $SquashTimer
@onready var coyote_timer = $CoyoteTimer
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var glide_stamina_bar = $GlideStaminaBar
@onready var vertical_collision = $VerticalCollision
@onready var horizontal_collision = $HorizontalCollision

#Defines onready vars
@onready var initial_position = position

#Defines movement variables
@export_category("Movement Variables")
@export var horizontal_speed := 200.0
@export var sprint_multiplier := 1.5
@export var acceleration := 100.0
@export var deceleration := 100.0
@export var jump_peak_time := 16.0
@export var jump_fall_time := 16.0
@export var jump_height := 2048.0
@export var max_fall_speed := 600
@export var jump_distance := 128.0
@export var speed := 5.0
@export var jump_velocity := 0.0
@export var glide_diminisher := 1.25
@export var double_jump := 1
@export var jump_buffer_time: float = 0.1
@export var wallslide_gravity := 100.0
@export var walljump_pushback: = 400
@export var climb_speed: float = 200.0
@export var glide_stamina: float = 1.0
@export var max_glide_stamina: float = 1.0

var can_glide: bool = true
var is_wall_sliding: bool = false

#Defines different gravity for rising or falling
var fall_gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var jump_gravity: float = 5.0

func _ready():
	calculate_movement_parameters()
	Signals.was_collected.connect(on_collectible_collected)
	
func _physics_process(delta):
	handle_horizontal_movement()
	handle_vertical_movement()
	wall_climb(delta)
	glide(delta)

func calculate_movement_parameters():
	fall_gravity = (2 * jump_height)/pow(jump_peak_time, 2)
	jump_gravity = (2 * jump_height)/pow(jump_fall_time, 2)
	jump_velocity = jump_gravity * jump_peak_time
	speed = jump_distance/(jump_peak_time + jump_fall_time)

func handle_horizontal_movement():
	var direction = Input.get_axis("move_left", "move_right")
	if direction == 0:
		velocity.x = move_toward(velocity.x, 0, deceleration)
		player_anim.play("player_idle")
		return
	
	#Acceleration and Deceleration
	velocity.x = move_toward(velocity.x, direction * horizontal_speed, acceleration)
	
	#Handle run and idle animations
	if is_on_floor():
		player_anim.play("player_run")
		#Sprint while holding X
		if Input.is_action_pressed("sprint"):
			velocity.x = velocity.x * sprint_multiplier
	else:
		player_anim.play("player_idle")
	
	#Flip sprite direction based on input
	player_sprite.flip_h = direction < 0

func handle_vertical_movement():
	#Logic to determine the frame where the player lands on or leaves the floor
	var was_in_air: bool = not is_on_floor()
	var was_on_floor: bool = is_on_floor() 
	move_and_slide()
	var just_landed: bool = is_on_floor() and was_in_air
	var just_left_floor: bool = not is_on_floor() and was_on_floor
	
	#Landing on floor stops coyote timer, increments double jump, and squashes sprite
	if just_landed:
		coyote_timer.stop()
		double_jump = 1
		player_sprite.scale.x = 1.25
		player_sprite.scale.y = 0.75
		squash_timer.start(0.1)
	#Leaving the floor starts coyote timer
	elif just_left_floor:
		coyote_timer.start()

	if not is_on_floor():
		#Apply fall gravity while falling and stretch sprite
		if velocity.y > -50 and not is_on_wall():
			if Input.is_action_pressed("move_down"):
				velocity.y = move_toward(velocity.y, max_fall_speed, 20)
		if velocity.y > 0 and not Input.is_action_pressed("glide") and not is_on_wall():
			velocity.y += fall_gravity
			player_anim.play("player_fall")
			player_sprite.scale.x = .75
			player_sprite.scale.y = 1.25
			#Cap fall speed at 600
			if velocity.y > max_fall_speed:
				velocity.y = max_fall_speed
		#Apply jump gravity while jumping and reset sprite scale (because of double jump)
		else:
			velocity.y += jump_gravity
			player_anim.play("player_jump")
			player_sprite.scale.x = 1
			player_sprite.scale.y = 1
			
	#Handle jump input logic
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = -jump_velocity
		#Handle double jump
		elif double_jump > 0:
			velocity.y = -jump_velocity
			if coyote_timer.is_stopped(): 
				double_jump -= 1
		#Queue jump by starting jump buffer timer
		elif not is_on_floor() and double_jump < 1:
			jump_buffer_timer.start()
			
	#If land on floor while jump buffer timer is active, uses queued jump
	if not jump_buffer_timer.is_stopped() and is_on_floor():
		velocity.y = -jump_velocity
	
	#Variable jump height. If jump button is released early, end jump and let gravity take over
	if Input.is_action_just_released("jump"):
		if velocity.y < 50:
			velocity.y = 0

func glide(delta):
	if glide_stamina > max_glide_stamina:
		glide_stamina = max_glide_stamina
		
	if is_on_floor():
		glide_stamina = max_glide_stamina
		can_glide = true
		player_sprite.scale.x = 1
		player_sprite.scale.y = 1
		glide_stamina_bar.hide()
		horizontal_collision.disabled = true
		vertical_collision.disabled = false
	else:
		if Input.is_action_pressed("glide") and can_glide and velocity.y > 0:
			velocity.y /= glide_diminisher
			glide_stamina -= delta
			glide_stamina_bar.show()
			player_anim.play("player_glide")
			horizontal_collision.disabled = false
			vertical_collision.disabled = true
		elif not Input.is_action_pressed("glide"):
			horizontal_collision.disabled = true
			vertical_collision.disabled = false
			
	if glide_stamina <= 0:
		can_glide = false
		glide_stamina_bar.hide()
	glide_stamina_bar.value = glide_stamina
	
func wall_climb(delta):
	var direction_x = Input.get_axis("move_left", "move_right")
	var direction_y = Input.get_axis("move_up", "move_down")
	
	if is_on_wall() and Input.is_action_pressed("wall_grab"):
		if direction_y == 0:
			velocity.y = move_toward(velocity.y, 0, deceleration)
		else:
			velocity.y = move_toward(velocity.y, direction_y * climb_speed, acceleration)
		if Input.is_action_just_pressed("jump"):
			if player_sprite.flip_h:
				velocity.y = -jump_velocity
				velocity.x = walljump_pushback
			else:
				velocity.y = -jump_velocity
				velocity.x = -walljump_pushback
			
func wall_slide(delta):
	var direction = Input.get_axis("move_left", "move_right")
	if is_on_wall_only():
		if direction != 0:
			is_wall_sliding = true
		else: is_wall_sliding = false
	else:
		is_wall_sliding = false
		
	if is_wall_sliding:
		velocity.y += (wallslide_gravity * delta)
		velocity.y = min(velocity.y, wallslide_gravity)
		
func reset_position():
	position = initial_position

func _on_squash_timer_timeout():
	if is_on_floor():
		player_sprite.scale.x = 1
		player_sprite.scale.y = 1

func on_collectible_collected():
	glide_stamina += 0.33
