class_name ExitDoor
extends Area2D

signal level_complete_triggered

# --- Modes ---
enum DoorMode { TELEPORT, LOAD_SCENE, COMPLETE_LEVEL }
@export var mode: DoorMode = DoorMode.TELEPORT

# --- Teleport destination (intra-scene only) ---
@export_group("Teleport Settings")
@export var target_position: Vector2 = Vector2.ZERO

# --- Scene to load (inter-scene) ---
@export_group("Load Scene Settings")
@export var scene_to_load: PackedScene

# Player group to react to
@export var player_group_name: String = "player"

# Optional UI (stub): if assigned, we'll update this label; otherwise we skip
@export var collectibles_label_path: NodePath

# Small cooldown so we don't re-trigger while overlapping
@export var rearm_delay_seconds: float = 0.20

# --- Nodes ---
@onready var sprite_2d: Sprite2D = $Sprite2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var color_rect: ColorRect = $ColorRect
@onready var collectibles_remaining_label: Label = null

# --- State ---
var is_unlocked: bool = false
var _can_trigger: bool = true
var _collectibles_remaining: int = 0

# --- Inspector filtering ---
func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary] = []
	props.append({
		"name": "mode",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": "Teleport,Load Scene,Complete Level",
		"usage": PROPERTY_USAGE_DEFAULT
	})
	props.append({
		"name": "player_group_name",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	props.append({
		"name": "collectibles_label_path",
		"type": TYPE_NODE_PATH,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	props.append({
		"name": "rearm_delay_seconds",
		"type": TYPE_FLOAT,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	if mode == DoorMode.TELEPORT:
		props.append({
			"name": "target_position",
			"type": TYPE_VECTOR2,
			"usage": PROPERTY_USAGE_DEFAULT
		})
	elif mode == DoorMode.LOAD_SCENE:
		props.append({
			"name": "scene_to_load",
			"type": TYPE_OBJECT,
			"hint": PROPERTY_HINT_RESOURCE_TYPE,
			"hint_string": "PackedScene",
			"usage": PROPERTY_USAGE_DEFAULT
		})
	return props

func _ready() -> void:
	if collectibles_label_path != NodePath(""):
		collectibles_remaining_label = get_node_or_null(collectibles_label_path)

	monitoring = true
	monitorable = true

	connect("body_entered", Callable(self, "_on_body_entered"))

	await get_tree().process_frame
	_initialize_child_collectibles()

	if _collectibles_remaining <= 0:
		_unlock()
	else:
		_set_locked_visuals()

	_update_label()

func _initialize_child_collectibles() -> void:
	_collectibles_remaining = 0
	for node in get_tree().get_nodes_in_group("collectibles"):
		if is_ancestor_of(node):
			_collectibles_remaining += 1
			if node.has_signal("collected"):
				node.connect("collected", Callable(self, "_on_child_collectible_collected"))
			else:
				node.tree_exited.connect(Callable(self, "_on_child_collectible_left_tree"))

func _on_child_collectible_collected() -> void:
	if _collectibles_remaining > 0:
		_collectibles_remaining -= 1
	_update_label()
	if _collectibles_remaining <= 0:
		_unlock()
		if "all_collected" in Signals:
			Signals.all_collected.emit()

func _on_child_collectible_left_tree() -> void:
	if _collectibles_remaining > 0:
		_collectibles_remaining -= 1
	_update_label()
	if _collectibles_remaining <= 0:
		_unlock()
		if "all_collected" in Signals:
			Signals.all_collected.emit()

func _update_label() -> void:
	if is_instance_valid(collectibles_remaining_label):
		collectibles_remaining_label.text = "Flowers Remaining: " + str(max(_collectibles_remaining, 0))

func _unlock() -> void:
	is_unlocked = true
	_set_unlocked_visuals()

func _on_body_entered(body: Node) -> void:
	if not _can_trigger or not is_unlocked:
		return
	if not body.is_in_group(player_group_name):
		return

	_can_trigger = false
	monitoring = false

	match mode:
		DoorMode.TELEPORT:
			var body_2d := body as Node2D
			if body_2d:
				body_2d.global_position = target_position
				if body_2d is CharacterBody2D:
					var char := body_2d as CharacterBody2D
					char.velocity = Vector2.ZERO
			_rearm_after_delay() # only teleport uses rearm

		DoorMode.LOAD_SCENE:
			if scene_to_load != null:
				get_tree().change_scene_to_packed(scene_to_load)
			else:
				push_warning("ExitDoor in LOAD_SCENE mode has no scene_to_load set.")

		DoorMode.COMPLETE_LEVEL:
			# Tell the level flow manager it's time to end the run.
			emit_signal("level_complete_triggered")

	# Optional compatibility signal (kept if other systems listen to it)
	if "exit_reached" in Signals:
		Signals.exit_reached.emit()

func _rearm_after_delay() -> void:
	await get_tree().create_timer(rearm_delay_seconds).timeout
	monitoring = true
	_can_trigger = true

# --- Visuals ---
func _set_locked_visuals() -> void:
	if is_instance_valid(sprite_2d):
		sprite_2d.modulate = Color(0.8, 0.8, 0.8, 0.9)
	if is_instance_valid(color_rect):
		color_rect.color = Color.BLACK
	if is_instance_valid(animation_player) and animation_player.has_animation("unlock"):
		animation_player.stop()

func _set_unlocked_visuals() -> void:
	if is_instance_valid(sprite_2d):
		sprite_2d.modulate = Color(1, 1, 1, 1)
	if is_instance_valid(color_rect):
		var tween: Tween = create_tween()
		tween.tween_property(color_rect, "color", Color.WHITE, 1.0)
	if is_instance_valid(animation_player) and animation_player.has_animation("unlock"):
		animation_player.play("unlock")
