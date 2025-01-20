extends Area2D

@onready var sprite_2d = $Sprite2D

var score: int = 1
	
func _ready():
	play_floating_animation()

func play_floating_animation() -> void:
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)

	var sprite_2d := get_node("Sprite2D")
	var position_offset := Vector2(0.0, 3.0)
	var duration = randf_range(0.8, 1.2)
	sprite_2d.position = -1.0 * position_offset
	tween.tween_property(sprite_2d, "position", position_offset, duration)
	tween.tween_property(sprite_2d, "position",  -1.0 * position_offset, duration)

func _on_body_entered(body):
	if body.is_in_group("player"):
		Signals.was_collected.emit()
		queue_free()

