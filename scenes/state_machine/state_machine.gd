extends Node

@export var starting_state: State

var current_state: State

# Initialize the state machine by giving each child state a reference to the
# parent object it belongs to and enter the default starting_state.
func init(parent: CharacterBody2D) -> void:
	if starting_state == null:
		push_error("StateMachine: starting_state is not assigned.")
		return

	for child in get_children():
		if child is State:
			child.parent = parent

	change_state(starting_state)

# Change to the new state by first calling any exit logic on the current state.
func change_state(new_state: State) -> void:
	if current_state != null:
		current_state.exit()

	current_state = new_state
	if current_state != null:
		current_state.enter()

# Pass-through functions for the Player to call,
# handling state changes as needed.
func process_physics(delta: float) -> void:
	if current_state == null:
		return
	var new_state: State = current_state.process_physics(delta)
	if new_state != null:
		change_state(new_state)

func process_input(event: InputEvent) -> void:
	if current_state == null:
		return
	var new_state: State = current_state.process_input(event)
	if new_state != null:
		change_state(new_state)

func process_frame(delta: float) -> void:
	if current_state == null:
		return
	var new_state: State = current_state.process_frame(delta)
	if new_state != null:
		change_state(new_state)
