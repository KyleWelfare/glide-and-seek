extends Camera2D
class_name CameraBoundsChild2D

# Assign your Area2D (with a RectangleShape2D) that defines the camera bounds.
@export var bounds_area_path: NodePath
# Optional: pull the clamp a little inward so walls/floor are not glued to the edges.
@export var bounds_inset: Vector2 = Vector2.ZERO
# If the view is larger than the bounds on an axis, do you want to lock-center that axis?
# false = do not clamp that axis (prevents “stuck” feeling). true = lock center on that axis.
@export var clamp_when_smaller_than_view: bool = false

var level_bounds: Rect2 = Rect2()
var parent_node: Node2D = null
var base_local_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	parent_node = get_parent() as Node2D
	base_local_position = position
	_resolve_bounds_from_area()

func _process(_delta: float) -> void:
	if parent_node == null:
		return
	if level_bounds.size == Vector2.ZERO:
		# No bounds → keep original local position
		position = base_local_position
		return

	# 1) Where would the camera center be if we did not clamp?
	var expected_center: Vector2 = parent_node.global_transform * base_local_position

	# 2) Clamp that center to bounds (account for zoom and viewport)
	var viewport_size: Vector2 = get_viewport_rect().size
	var half_view_world: Vector2 = Vector2(viewport_size.x * 0.5 * zoom.x, viewport_size.y * 0.5 * zoom.y)
	var inset_bounds: Rect2 = Rect2(level_bounds.position + bounds_inset, level_bounds.size - bounds_inset * 2.0)

	var min_center: Vector2 = inset_bounds.position + half_view_world
	var max_center: Vector2 = inset_bounds.position + inset_bounds.size - half_view_world

	var clamped_center: Vector2 = expected_center

	# X axis
	var too_small_x: bool = max_center.x < min_center.x
	if too_small_x:
		if clamp_when_smaller_than_view:
			clamped_center.x = inset_bounds.position.x + inset_bounds.size.x * 0.5
		else:
			clamped_center.x = expected_center.x
	else:
		clamped_center.x = clamp(expected_center.x, min_center.x, max_center.x)

	# Y axis
	var too_small_y: bool = max_center.y < min_center.y
	if too_small_y:
		if clamp_when_smaller_than_view:
			clamped_center.y = inset_bounds.position.y + inset_bounds.size.y * 0.5
		else:
			clamped_center.y = expected_center.y
	else:
		clamped_center.y = clamp(expected_center.y, min_center.y, max_center.y)

	# 3) Apply the *per-frame* delta to the local position (no accumulation)
	var delta_center: Vector2 = clamped_center - expected_center
	position = base_local_position + delta_center

func _resolve_bounds_from_area() -> void:
	level_bounds = Rect2()
	if bounds_area_path == NodePath(""):
		return

	var node: Node = get_node_or_null(bounds_area_path)
	if not (node is Area2D):
		return
	var area: Area2D = node as Area2D

	# Find a RectangleShape2D under this Area2D (any CollisionShape2D child)
	var rectangle_shape: RectangleShape2D = null
	var shape_node: CollisionShape2D = null
	for child in area.get_children():
		if child is CollisionShape2D:
			var shape: Shape2D = (child as CollisionShape2D).shape
			if shape is RectangleShape2D:
				rectangle_shape = shape as RectangleShape2D
				shape_node = child as CollisionShape2D
				break
	if rectangle_shape == null or shape_node == null:
		return

	# Build world-space AABB from transformed rectangle corners (handles offset/rotation/scale)
	var half: Vector2 = rectangle_shape.size * 0.5
	var full_transform: Transform2D = area.global_transform * shape_node.transform

	var c0: Vector2 = full_transform * Vector2(-half.x, -half.y)
	var c1: Vector2 = full_transform * Vector2( half.x, -half.y)
	var c2: Vector2 = full_transform * Vector2( half.x,  half.y)
	var c3: Vector2 = full_transform * Vector2(-half.x,  half.y)

	var min_x: float = min(c0.x, min(c1.x, min(c2.x, c3.x)))
	var max_x: float = max(c0.x, max(c1.x, max(c2.x, c3.x)))
	var min_y: float = min(c0.y, min(c1.y, min(c2.y, c3.y)))
	var max_y: float = max(c0.y, max(c1.y, max(c2.y, c3.y)))

	level_bounds = Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))
