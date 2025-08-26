extends Area2D

@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect

var is_unlocked: bool = false
var has_exited: bool = false	# one‑shot guard so exit only triggers once

func _ready() -> void:
	# Visual state: start locked (dim, etc.)
	_set_locked_visuals()

	# Listen for "all collectibles gathered" from your tracker.
	if "all_collected" in Signals:
		Signals.all_collected.connect(_on_all_collected)

	# Detect the player overlapping the area.
	connect("body_entered", Callable(self, "_on_body_entered"))

	# Sense overlaps only (no blocking).
	monitoring = true
	monitorable = true

func _on_all_collected() -> void:
	is_unlocked = true
	_set_unlocked_visuals()

func _on_body_entered(body: Node) -> void:
	if has_exited or not is_unlocked:
		return
	if body.is_in_group("player"):
		has_exited = true
		print("Victory!")
		# Broadcast for timers/scene changes if you hook it up later.
		if "exit_reached" in Signals:
			Signals.exit_reached.emit()

func _set_locked_visuals() -> void:
	# Slightly dim while locked
	if is_instance_valid(sprite_2d):
		sprite_2d.modulate = Color(0.8, 0.8, 0.8, 0.9)
	# Start the ColorRect as solid black
	if is_instance_valid(color_rect):
		color_rect.color = Color.BLACK
	# Ensure any "unlock" anim is reset
	if is_instance_valid(animation_player) and animation_player.has_animation("unlock"):
		animation_player.stop()

func _set_unlocked_visuals() -> void:
	# Full brightness when unlocked
	if is_instance_valid(sprite_2d):
		sprite_2d.modulate = Color(1, 1, 1, 1)
	# Fade ColorRect from black to white
	if is_instance_valid(color_rect):
		var tween: Tween = create_tween()
		tween.tween_property(color_rect, "color", Color.WHITE, 1.0)
	# Optional animation cue
	if is_instance_valid(animation_player) and animation_player.has_animation("unlock"):
		animation_player.play("unlock")
