extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D

var score: int = 1

func _ready() -> void:
	# Ensure all collectibles are in the same group for counting.
	add_to_group("collectibles")
	# Floating animation (cosmetic).
	play_floating_animation()
	# NOTE: Make sure the Area2D's "body_entered" signal is connected to _on_body_entered in the scene.

func play_floating_animation() -> void:
	var tween: Tween = create_tween()
	# Loop forever. Your original no-arg call is valid in 4.4.x too.
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE)

	var position_offset: Vector2 = Vector2(0.0, 3.0)
	var duration: float = randf_range(0.8, 1.2)

	# Use the onready variable (do not re-declare a local with same name).
	sprite_2d.position = -1.0 * position_offset
	tween.tween_property(sprite_2d, "position", position_offset, duration)
	tween.tween_property(sprite_2d, "position", -1.0 * position_offset, duration)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	Signals.was_collected.emit()
	queue_free()
