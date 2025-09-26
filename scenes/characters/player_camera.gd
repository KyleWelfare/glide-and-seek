extends Camera2D
class_name CameraController2D

@export var target_path: NodePath

# Deadzone (centered on camera anchor)
@export_range(0.0, 2000.0, 1.0) var deadzone_width: float = 48.0
@export_range(0.0, 2000.0, 1.0) var deadzone_height: float = 160.0

# --- Horizontal look-ahead ---
@export_range(0.0, 1000.0, 1.0) var lookahead_max_distance: float = 64.0
@export_range(0.01, 50.0, 0.01) var lookahead_responsiveness: float = 8.0
@export_range(0.0, 1000.0, 0.1) var lookahead_velocity_threshold: float = 20.0
@export_range(1.0, 5000.0, 1.0) var max_offset_speed: float = 800.0
@export_range(0.0, 2.0, 0.01) var recenter_delay_seconds: float = 0.20
@export_range(0.01, 20.0, 0.01) var recenter_speed: float = 4.0

# --- Vertical look-ahead (walls only) ---
@export var vertical_lookahead_enabled: bool = true
@export var vertical_requires_on_wall: bool = true
@export_range(0.0, 1000.0, 1.0) var lookahead_vertical_max_distance: float = 72.0
@export_range(0.01, 50.0, 0.01) var lookahead_vertical_responsiveness: float = 8.0
@export_range(0.0, 1000.0, 0.1) var lookahead_vertical_velocity_threshold: float = 20.0
@export_range(1.0, 5000.0, 1.0) var max_vertical_offset_speed: float = 800.0
@export_range(0.0, 2.0, 0.01) var vertical_recenter_delay_seconds: float = 0.20
@export_range(0.01, 20.0, 0.01) var vertical_recenter_speed: float = 4.0

# --- Per-level camera bounds ---
@export var bounds_area_path: NodePath
@export var bounds_inset: Vector2 = Vector2(0.0, 0.0)
# If true, when view is larger than bounds on an axis, the camera will still center there (locked).
# If false (default), we do NOT clamp that axis so the camera can move freely instead of sticking.
@export var clamp_when_smaller_than_view: bool = false

var target: Node2D = null
var anchor_position: Vector2 = Vector2.ZERO
var smoothed_lookahead_x: float = 0.0
var time_since_horizontal_moved: float = 0.0
var smoothed_lookahead_y: float = 0.0
var time_since_vertical_moved: float = 0.0
var level_bounds: Rect2 = Rect2() # world-space rect; size==ZERO means disabled

func _ready() -> void:
	if target_path != NodePath(""):
		var node: Node = get_node_or_null(target_path)
		if node is Node2D:
			target = node
	if target != null:
		anchor_position = target.global_position
	else:
		anchor_position = global_position
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	_resolve_bounds_from_area()

func _process(delta: float) -> void:
	if target == null:
		return
	_update_horizontal_lookahead(delta)
	_update_vertical_lookahead(delta)
	_apply_deadzone_and_drive_camera()
	_apply_bounds_clamp()

func _update_horizontal_lookahead(delta: float) -> void:
	var velocity_x: float = _get_target_velocity_x()
	var horizontal_speed: float = absf(velocity_x)
	var is_moving_horizontally: bool = horizontal_speed >= lookahead_velocity_threshold
	var desired_lookahead_x: float = 0.0
	if is_moving_horizontally:
		var horizontal_direction: float = signf(velocity_x)
		desired_lookahead_x = horizontal_direction * lookahead_max_distance
	if is_moving_horizontally:
		time_since_horizontal_moved = 0.0
	else:
		time_since_horizontal_moved += delta
	var target_lookahead_x: float = smoothed_lookahead_x
	if is_moving_horizontally:
		var lerp_step_x: float = clamp(lookahead_responsiveness * delta, 0.0, 1.0)
		target_lookahead_x = lerp(smoothed_lookahead_x, desired_lookahead_x, lerp_step_x)
	else:
		if time_since_horizontal_moved > recenter_delay_seconds:
			var recenter_step_x: float = clamp(recenter_speed * delta, 0.0, 1.0)
			target_lookahead_x = lerp(smoothed_lookahead_x, 0.0, recenter_step_x)
		else:
			target_lookahead_x = smoothed_lookahead_x
	var max_change_x: float = max_offset_speed * delta
	var change_x: float = target_lookahead_x - smoothed_lookahead_x
	if change_x > max_change_x:
		change_x = max_change_x
	elif change_x < -max_change_x:
		change_x = -max_change_x
	smoothed_lookahead_x += change_x

func _update_vertical_lookahead(delta: float) -> void:
	if not vertical_lookahead_enabled:
		smoothed_lookahead_y = 0.0
		return
	var on_wall_now: bool = _is_target_on_wall()
	var can_apply_vertical: bool = on_wall_now or not vertical_requires_on_wall
	var velocity_y: float = _get_target_velocity_y()
	var vertical_speed: float = absf(velocity_y)
	var is_moving_vertically: bool = vertical_speed >= lookahead_vertical_velocity_threshold and can_apply_vertical
	var desired_lookahead_y: float = 0.0
	if is_moving_vertically:
		if velocity_y < 0.0:
			desired_lookahead_y = -lookahead_vertical_max_distance
		else:
			desired_lookahead_y = lookahead_vertical_max_distance
	if is_moving_vertically:
		time_since_vertical_moved = 0.0
	else:
		if vertical_requires_on_wall and not on_wall_now:
			time_since_vertical_moved = vertical_recenter_delay_seconds + 999.0
		else:
			time_since_vertical_moved += delta
	var target_lookahead_y: float = smoothed_lookahead_y
	if is_moving_vertically:
		var lerp_step_y: float = clamp(lookahead_vertical_responsiveness * delta, 0.0, 1.0)
		target_lookahead_y = lerp(smoothed_lookahead_y, desired_lookahead_y, lerp_step_y)
	else:
		if time_since_vertical_moved > vertical_recenter_delay_seconds:
			var recenter_step_y: float = clamp(vertical_recenter_speed * delta, 0.0, 1.0)
			target_lookahead_y = lerp(smoothed_lookahead_y, 0.0, recenter_step_y)
		else:
			target_lookahead_y = smoothed_lookahead_y
	var max_change_y: float = max_vertical_offset_speed * delta
	var change_y: float = target_lookahead_y - smoothed_lookahead_y
	if change_y > max_change_y:
		change_y = max_change_y
	elif change_y < -max_change_y:
		change_y = -max_change_y
	smoothed_lookahead_y += change_y

func _apply_deadzone_and_drive_camera() -> void:
	var half_deadzone: Vector2 = Vector2(deadzone_width * 0.5, deadzone_height * 0.5)
	var deadzone_top_left: Vector2 = anchor_position - half_deadzone
	var target_position_with_lookahead: Vector2 = target.global_position + Vector2(smoothed_lookahead_x, smoothed_lookahead_y)
	var anchor_changed: bool = false
	if target_position_with_lookahead.x < deadzone_top_left.x:
		anchor_position.x = target_position_with_lookahead.x + half_deadzone.x
		anchor_changed = true
	elif target_position_with_lookahead.x > deadzone_top_left.x + deadzone_width:
		anchor_position.x = target_position_with_lookahead.x - half_deadzone.x
		anchor_changed = true
	if target_position_with_lookahead.y < deadzone_top_left.y:
		anchor_position.y = target_position_with_lookahead.y + half_deadzone.y
		anchor_changed = true
	elif target_position_with_lookahead.y > deadzone_top_left.y + deadzone_height:
		anchor_position.y = target_position_with_lookahead.y - half_deadzone.y
		anchor_changed = true
	if anchor_changed:
		global_position = anchor_position
	else:
		global_position = anchor_position

func _apply_bounds_clamp() -> void:
	if level_bounds.size == Vector2.ZERO:
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view_world: Vector2 = Vector2(viewport_size.x * 0.5 * zoom.x, viewport_size.y * 0.5 * zoom.y)
	var inset_bounds: Rect2 = Rect2(level_bounds.position + bounds_inset, level_bounds.size - bounds_inset * 2.0)

	var min_center: Vector2 = inset_bounds.position + half_view_world
	var max_center: Vector2 = inset_bounds.position + inset_bounds.size - half_view_world

	# Axis-by-axis handling if bounds are smaller than the view
	var clamped: Vector2 = global_position

	# X axis
	var bounds_smaller_x: bool = max_center.x < min_center.x
	if bounds_smaller_x:
		if clamp_when_smaller_than_view:
			clamped.x = inset_bounds.position.x + inset_bounds.size.x * 0.5
		else:
			clamped.x = global_position.x
	else:
		clamped.x = clamp(global_position.x, min_center.x, max_center.x)

	# Y axis
	var bounds_smaller_y: bool = max_center.y < min_center.y
	if bounds_smaller_y:
		if clamp_when_smaller_than_view:
			clamped.y = inset_bounds.position.y + inset_bounds.size.y * 0.5
		else:
			clamped.y = global_position.y
	else:
		clamped.y = clamp(global_position.y, min_center.y, max_center.y)

	global_position = clamped
	anchor_position = clamped

func _resolve_bounds_from_area() -> void:
	level_bounds = Rect2()
	if bounds_area_path == NodePath(""):
		return
	var node: Node = get_node_or_null(bounds_area_path)
	if not (node is Area2D):
		return
	var area: Area2D = node as Area2D

	# Find the first CollisionShape2D child with a RectangleShape2D
	var collision_shape: CollisionShape2D = null
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape: Shape2D = (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				collision_shape = child as CollisionShape2D
				break
	if collision_shape == null:
		return

	var rectangle: RectangleShape2D = collision_shape.shape as RectangleShape2D
	var half: Vector2 = rectangle.size * 0.5

	# Transform the four corners to world, then build an AABB Rect2
	var transform_2d: Transform2D = area.global_transform
	var c0: Vector2 = transform_2d * Vector2(-half.x, -half.y)
	var c1: Vector2 = transform_2d * Vector2( half.x, -half.y)
	var c2: Vector2 = transform_2d * Vector2( half.x,  half.y)
	var c3: Vector2 = transform_2d * Vector2(-half.x,  half.y)

	var min_x: float = min(c0.x, min(c1.x, min(c2.x, c3.x)))
	var max_x: float = max(c0.x, max(c1.x, max(c2.x, c3.x)))
	var min_y: float = min(c0.y, min(c1.y, min(c2.y, c3.y)))
	var max_y: float = max(c0.y, max(c1.y, max(c2.y, c3.y)))

	level_bounds = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))

func _get_target_velocity_x() -> float:
	if target is CharacterBody2D:
		var body: CharacterBody2D = target as CharacterBody2D
		return body.velocity.x
	if target.has_method("get_velocity"):
		var velocity_variant: Variant = target.call("get_velocity")
		if velocity_variant is Vector2:
			var velocity_vector: Vector2 = velocity_variant as Vector2
			return velocity_vector.x
	return 0.0

func _get_target_velocity_y() -> float:
	if target is CharacterBody2D:
		var body: CharacterBody2D = target as CharacterBody2D
		return body.velocity.y
	if target.has_method("get_velocity"):
		var velocity_variant: Variant = target.call("get_velocity")
		if velocity_variant is Vector2:
			var velocity_vector: Vector2 = velocity_variant as Vector2
			return velocity_vector.y
	return 0.0

func _is_target_on_wall() -> bool:
	if target is CharacterBody2D:
		var body: CharacterBody2D = target as CharacterBody2D
		return body.is_on_wall()
	if target.has_method("is_on_wall"):
		var on_wall_variant: Variant = target.call("is_on_wall")
		if on_wall_variant is bool:
			return bool(on_wall_variant)
	return false

func set_bounds_area(area: Area2D) -> void:
	var path: NodePath = area.get_path()
	bounds_area_path = path
	_resolve_bounds_from_area()
