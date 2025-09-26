## Base class for player states in the FSM. Concrete states override enter/exit/process_* and may use move_speed/gravity.
class_name State
extends Node

@export var animation_name: String = ""	# Keep as String so existing scene data isn't lost
@export var move_speed: float = 200.0

var gravity: float = float(ProjectSettings.get_setting("physics/2d/default_gravity"))

## The player this state controls. Set by StateMachine.init().
var parent: Player

func enter() -> void:
	# Only play an animation if one is specified and the player has an AnimationPlayer.
	if animation_name == "":
		return
	if parent == null:
		push_error("State.enter(): 'parent' is null. Was StateMachine.init() called?")
		return
	if parent.player_anims == null:
		push_error("State.enter(): parent.player_anims is null.")
		return
	parent.player_anims.play(StringName(animation_name))

func exit() -> void:
	pass

func process_input(event: InputEvent) -> State:
	return null

func process_frame(delta: float) -> State:
	return null

func process_physics(delta: float) -> State:
	return null
