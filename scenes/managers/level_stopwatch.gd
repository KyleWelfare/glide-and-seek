extends Node2D

@onready var stopwatch_label = $CanvasLayer/StopwatchLabel

var time_elapsed: float = 0.0

func _process(delta):
	#Constantly increase stopwatch time
	time_elapsed += delta
	#Print the stopwatch time rounded to 2 decimals
	stopwatch_label.text = ("%.02f" % time_elapsed)
