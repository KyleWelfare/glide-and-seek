extends PathFollow2D

@export var speed: float = 100.0  # Movement speed along the path

func _process(delta):
	progress += speed * delta  # Move along the path
