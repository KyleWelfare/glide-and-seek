extends PathFollow2D
class_name PatrolFly

@export var speed: float = 50.0

# --- Sprite flipping (assign if your sprite is not named "Sprite2D")
@export var sprite_path: NodePath

# --- Bobbing controls (code-driven)
@export var bob_amplitude: float = 5.0		# pixels of offset from the path
@export var bob_frequency_hz: float = 0.5	# cycles per second
@export var randomize_phase: bool = true	# different start phase per instance

# Ignore tiny horizontal wobbles so we do not spam-flip on near-vertical path segments.
const HORIZONTAL_EPSILON: float = 0.25

var _prev_global_position: Vector2
var _sprite: Sprite2D
var _time: float = 0.0
var _base_v_offset: float = 0.0
var _phase: float = 0.0

func _ready() -> void:
	# Resolve the sprite safely.
	if sprite_path != NodePath():
		_sprite = get_node(sprite_path) as Sprite2D
	else:
		_sprite = get_node_or_null("Sprite2D") as Sprite2D
	if _sprite == null:
		push_warning("PatrolFly: Sprite2D not found. Assign 'sprite_path' or name your sprite 'Sprite2D'.")

	_prev_global_position = global_position
	_base_v_offset = v_offset
	
	# Give each instance a different starting phase so they don't bob identically.
	if randomize_phase:
		# Simple deterministic phase from instance id
		var seed := int(get_instance_id() & 0x7FFFFFFF)
		var rand := float(((seed * 1103515245) + 12345) & 0x7fffffff) / float(0x7fffffff)
		_phase = rand * TAU
	else:
		_phase = 0.0

func _physics_process(delta: float) -> void:
	# Move along the path.
	progress += speed * delta
	
	# Flip sprite based on actual horizontal motion in screen space.
	var frame_delta := global_position - _prev_global_position
	if absf(frame_delta.x) > HORIZONTAL_EPSILON and _sprite:
		_sprite.flip_h = frame_delta.x < 0.0
	_prev_global_position = global_position

	# Bobbing: oscillate perpendicular to the path using v_offset.
	_time += delta
	var bob := sin((_time * bob_frequency_hz * TAU) + _phase) * bob_amplitude
	v_offset = _base_v_offset + bob
