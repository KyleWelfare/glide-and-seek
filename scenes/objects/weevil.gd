extends Area2D

@onready var weevil_collision: CollisionShape2D = $WeevilCollision
@onready var weevil_raycast: RayCast2D = $WeevilRaycast

var direction: int = 1  # 1 for right, -1 for left
var speed: float = 30  # Movement speed

func _process(delta: float) -> void:
	position.x += speed * direction * delta  # Move at a constant rate

	var raycast_collision = weevil_raycast.is_colliding()
	if not raycast_collision:
		reverse_direction()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("terrain"):
		reverse_direction()
		
func reverse_direction():
	scale.x *= -1  # Flip sprite horizontally
	direction *= -1  # Reverse movement direction
