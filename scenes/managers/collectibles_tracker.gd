extends Node2D

@onready var collectibles_remaining_label: Label = $CanvasLayer/CollectiblesRemainingLabel

var collectibles_remaining: int = 0

func _ready() -> void:
	# Wait one frame so all nodes (including collectibles) have run their _ready() and joined groups.
	await get_tree().process_frame
	_initialize_counts()

	Signals.was_collected.connect(update_remaining_collectibles)
	_update_label()

func _initialize_counts() -> void:
	if get_tree().has_group("collectibles"):
		collectibles_remaining = get_tree().get_nodes_in_group("collectibles").size()
	else:
		collectibles_remaining = 0
		print("[CollectiblesTracker] Warning: 'collectibles' group not found. Are your collectibles adding themselves to the group?")

func update_remaining_collectibles() -> void:
	if collectibles_remaining > 0:
		collectibles_remaining -= 1
	_update_label()
	if collectibles_remaining <= 0:
		collectibles_remaining = 0
		# This is where we’ll hook the door in a moment.
		if "all_collected" in Signals:
			Signals.all_collected.emit()

func _update_label() -> void:
	collectibles_remaining_label.text = "Flowers Remaining: " + str(collectibles_remaining)
