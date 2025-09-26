extends Area2D
class_name PatrolGround

@export var speed: float = 30.0
@export var turn_cooldown_seconds: float = 0.05

@onready var ground_check_raycast: RayCast2D = $GroundCheckRaycast
@onready var wall_check_raycast: RayCast2D = $WallCheckRaycast

var direction: int = 1
var _turn_cooldown_timer: float = 0.0

func _ready() -> void:
	ground_check_raycast.enabled = true
	wall_check_raycast.enabled = true

func _physics_process(delta: float) -> void:
	position.x += speed * direction * delta

	# Cooldown to prevent jittery re-flips
	if _turn_cooldown_timer > 0.0:
		_turn_cooldown_timer -= delta

	if not ground_check_raycast.is_colliding():
		_reverse_direction()
		return

	if wall_check_raycast.is_colliding():
		_reverse_direction()
		return

func _reverse_direction() -> void:
	if _turn_cooldown_timer > 0.0:
		return

	direction *= -1
	scale.x = -scale.x

	_turn_cooldown_timer = turn_cooldown_seconds
