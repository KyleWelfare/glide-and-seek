extends Node2D
class_name HazardController

signal state_changed(new_state: int)
signal player_aggro_changed(is_aggroed: bool)
signal reached_target

enum HazardState { PASSIVE, ACTIVE }

@export var hazard_box_path: NodePath
@export var wander_radius_path: NodePath
@export var aggro_radius_path: NodePath
@export var deaggro_radius_path: NodePath
@export var pause_timer_path: NodePath
@export var sprite_path: NodePath	# Optional: AnimatedSprite2D for visual state

@export var wander_speed: float = 100.0
@export var chase_speed: float = 140.0
@export var arrival_threshold: float = 10.0
@export var wander_radius: float = 96.0

# Sprite-facing controls
@export var enable_auto_flip: bool = true			# Turn off if you flip elsewhere
@export var flip_deadzone: float = 6.0				# Ignore tiny velocities to reduce jitter
@export var invert_flip: bool = false				# If your art's default faces left, toggle this

var hazard_box: Area2D
var wander_radius_area: Area2D
var aggro_radius_area: Area2D
var deaggro_radius_area: Area2D
var pause_timer: Timer
var _animated_sprite: AnimatedSprite2D

var state: int = HazardState.PASSIVE
var spawn_position: Vector2
var current_target_position: Vector2
var has_target: bool = false
var current_speed: float = 0.0
var current_velocity: Vector2 = Vector2.ZERO
var is_returning_to_spawn: bool = false

var _player: Node2D
var last_facing_x: int = 1	# 1 = right, -1 = left

func _ready() -> void:
	spawn_position = global_position
	hazard_box = _get_node_or_null(hazard_box_path) as Area2D
	wander_radius_area = _get_node_or_null(wander_radius_path) as Area2D
	aggro_radius_area = _get_node_or_null(aggro_radius_path) as Area2D
	deaggro_radius_area = _get_node_or_null(deaggro_radius_path) as Area2D
	pause_timer = _get_node_or_null(pause_timer_path) as Timer
	_animated_sprite = _get_node_or_null(sprite_path) as AnimatedSprite2D
	_refresh_player_reference()
	_update_animation_for_state()
	_update_sprite_facing_from_velocity() # Initialize facing at start

func _physics_process(delta: float) -> void:
	if has_target and current_speed > 0.0:
		var to_target: Vector2 = current_target_position - global_position
		var distance: float = to_target.length()
		if distance <= arrival_threshold:
			has_target = false
			current_velocity = Vector2.ZERO
			emit_signal(&"reached_target")
		else:
			var step: float = min(current_speed * delta, distance)
			var direction: Vector2 = to_target / max(distance, 0.000001)
			var delta_move: Vector2 = direction * step
			current_velocity = delta_move / delta
			global_position += delta_move
	else:
		current_velocity = Vector2.ZERO

	_update_sprite_facing_from_velocity()

func set_target_position(position: Vector2, desired_speed: float = -1.0) -> void:
	current_target_position = position
	has_target = true
	if desired_speed > 0.0:
		current_speed = desired_speed

func clear_target() -> void:
	has_target = false
	current_velocity = Vector2.ZERO

func set_desired_speed(speed: float) -> void:
	current_speed = max(0.0, speed)

func set_active(is_active: bool) -> void:
	var new_state: int = HazardState.ACTIVE if is_active else HazardState.PASSIVE
	if new_state == state:
		return
	state = new_state
	emit_signal(&"state_changed", state)
	emit_signal(&"player_aggro_changed", state == HazardState.ACTIVE)
	_update_animation_for_state()

func request_return_to_spawn() -> void:
	is_returning_to_spawn = true

func clear_return_to_spawn_request() -> void:
	is_returning_to_spawn = false

func get_player_global_position() -> Vector2:
	if not is_player_valid():
		_refresh_player_reference()
	if is_player_valid():
		return _player.global_position
	return global_position

func is_player_valid() -> bool:
	return _player != null and is_instance_valid(_player)

func get_effective_wander_center() -> Vector2:
	return spawn_position

func get_effective_wander_radius() -> float:
	if wander_radius_area:
		var shape_node: CollisionShape2D = wander_radius_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node and shape_node.shape is CircleShape2D:
			var base_r: float = (shape_node.shape as CircleShape2D).radius
			var gs: Vector2 = shape_node.global_scale
			var scale_factor: float = max(abs(gs.x), abs(gs.y))
			var eff: float = base_r * scale_factor
			if eff > 0.0:
				return eff
	return wander_radius

func at_target() -> bool:
	return not has_target

func _get_node_or_null(path: NodePath) -> Node:
	if path.is_empty():
		return null
	return get_node_or_null(path)

func _refresh_player_reference() -> void:
	var players: Array = get_tree().get_nodes_in_group("player")
	if players.size() > 0 and players[0] is Node2D:
		_player = players[0] as Node2D
	else:
		_player = null

func _update_animation_for_state() -> void:
	# Plays "wander" when PASSIVE and "chase" when ACTIVE, if sprite is present.
	if _animated_sprite == null:
		return
	var desired: StringName = &"wander" if state == HazardState.PASSIVE else &"chase"
	if _animated_sprite.animation != desired:
		_animated_sprite.play(desired)

func _update_sprite_facing_from_velocity() -> void:
	# Flip sprite based on X velocity, with a small deadzone to avoid jitter.
	if _animated_sprite == null:
		return
	if not enable_auto_flip:
		return

	var vx: float = current_velocity.x
	if abs(vx) >= flip_deadzone:
		if vx > 0.0:
			last_facing_x = 1
		else:
			last_facing_x = -1

	var flip_left: bool = last_facing_x < 0
	if invert_flip:
		flip_left = not flip_left

	# Using flip_h avoids changing collision or children scale.
	_animated_sprite.flip_h = flip_left
