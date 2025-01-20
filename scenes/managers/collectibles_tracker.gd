extends Node2D

@onready var collectibles_remaining_label = $CanvasLayer/CollectiblesRemainingLabel
@onready var collectibles_remaining = get_tree().get_nodes_in_group("collectibles").size()

func _ready():
	Signals.was_collected.connect(update_remaining_collectibles)
	collectibles_remaining_label.text = "Flowers Remaining: " + str(collectibles_remaining)
	
func update_remaining_collectibles():
	collectibles_remaining -= 1
	collectibles_remaining_label.text = "Flowers Remaining: " + str(collectibles_remaining)
	
