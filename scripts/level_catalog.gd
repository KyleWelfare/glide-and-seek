extends Resource
class_name LevelCatalog

@export var title: String = "World"
@export_range(1, 12) var columns: int = 3
@export var levels: Array[LevelEntry] = []
