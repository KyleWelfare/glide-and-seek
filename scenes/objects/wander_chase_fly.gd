extends Node2D

@onready var aggro_radius_shape: CollisionShape2D = $AggroRadius/AggroRadiusShape
@onready var fly: Node2D = $DeAggroRadius/Fly
@onready var pause_timer: Timer = $PauseTimer

var move_speed := 100
var current_speed := 0
var target_position := Vector2.ZERO
var acceleration := 50
var deceleration := 100

var is_chasing: bool = false
var player_body: Node2D = null

func _ready() -> void:
	randomize()

	if aggro_radius_shape == null:
		push_error("aggro_radius_shape is null (bad node path).")
		return

	if aggro_radius_shape.shape == null:
		# Ensure the CollisionShape2D has a CircleShape2D assigned in the Inspector
		push_error("aggro_radius_shape.shape is null (no Shape2D assigned).")
		return

	if !(aggro_radius_shape.shape is CircleShape2D):
		push_error("aggro_radius_shape.shape must be a CircleShape2D to use .radius.")
		return

	var radius := (aggro_radius_shape.shape as CircleShape2D).radius
	print("Aggro radius is: ", radius)

	# Godot 4-style signal hookup
	pause_timer.timeout.connect(_on_PauseTimer_timeout)
	pause_timer.wait_time = 1.0
	pause_timer.one_shot = true

	# Initial random target inside the circle, in GLOBAL coords
	target_position = get_random_position_within_radius()

func _process(delta: float) -> void:
	if not pause_timer.is_stopped():
		return

	var direction := (target_position - fly.global_position).normalized()

	if not is_chasing:
		if fly.global_position.distance_to(target_position) > 5.0:
			current_speed = min(current_speed + acceleration * delta, move_speed)
		else:
			current_speed = max(current_speed - deceleration * delta, 0.0)

		fly.global_position += direction * current_speed * delta

		if fly.global_position.distance_to(target_position) < 5.0:
			pause_timer.start()
	else:
		pass

func get_random_position_within_radius() -> Vector2:
	var circle := aggro_radius_shape.shape as CircleShape2D
	var radius := circle.radius
	var angle := randf() * TAU
	var distance := randf() * radius
	var offset := Vector2(cos(angle), sin(angle)) * distance
	return aggro_radius_shape.global_position + offset

func _on_PauseTimer_timeout() -> void:
	target_position = get_random_position_within_radius()

func _on_aggro_radius_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		target_position = body.global_position
