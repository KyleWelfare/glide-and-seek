extends Control

@export var catalog: LevelCatalog

@onready var title_label: Label = $MarginContainer/VBoxContainer/Title
@onready var grid: GridContainer = $MarginContainer/VBoxContainer/GridContainer
@onready var vbox: BoxContainer = $MarginContainer/VBoxContainer

# ----- layout knobs -----
const GRID_H_SEP: int = 24
const GRID_V_SEP: int = 16
const BORDER_WIDTH: int = 2
const CORNER_RADIUS: int = 12
const WRAP_SELECTION: bool = true

# Square size is computed from viewport width, then clamped (keeps things smaller)
const SQUARE_WIDTH_FRACTION: float = 0.10
const SQUARE_MIN: int = 84
const SQUARE_MAX: int = 140

# Font sizes (override theme so they don’t balloon)
const TITLE_FONT_SIZE: int = 28
const BUTTON_FONT_SIZE: int = 18
const CAPTION_FONT_SIZE: int = 16
const TIME_FONT_SIZE: int = 18

# ---- analog navigation tuning ----
const AXIS_DEADZONE: float = 0.45    # tilt past this to trigger
const AXIS_RELEASE: float = 0.25     # tilt back under this to re-arm
const AXIS_REPEAT_DELAY: float = 0.28
const AXIS_REPEAT_INTERVAL: float = 0.12

var _tile_square_size: int = 120

# For selection + activation
var _buttons: Array[Button] = []
var _level_ids: Array[String] = []
var _scene_paths: Array[String] = []
var _selected_index: int = 0

# Action names (resolve to your custom ones if present)
var _left_action: String = "ui_left"
var _right_action: String = "ui_right"
var _select_action: String = "ui_accept"

# Best-time labels for live updates
var _best_time_labels: Dictionary = {} # level_id -> Label

# Analog latch state
var _axis_latched: bool = false
var _axis_dir: int = 0
var _axis_timer: float = 0.0

func _ready() -> void:
	if catalog == null:
		push_warning("LevelSelect: No catalog assigned.")
		return

	# Resolve action names to your custom mappings when available
	if InputMap.has_action("move_left"):
		_left_action = "move_left"
	if InputMap.has_action("move_right"):
		_right_action = "move_right"
	if InputMap.has_action("select"):
		_select_action = "select"

	# We’ll read select in _unhandled_input and analog/dpad in _process
	set_process_unhandled_input(true)
	set_process(true)

	_tile_square_size = _compute_square_size()

	# Title
	if title_label != null:
		title_label.text = catalog.title
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)

	# VBox spacing
	if vbox != null:
		vbox.add_theme_constant_override("separation", 16)

	# Wrap grid in a centering HBox once so it truly centers
	if grid == null:
		push_warning("LevelSelect: GridContainer not found at $MarginContainer/VBoxContainer/GridContainer")
		return

	if grid.get_parent() == vbox:
		var idx: int = grid.get_index()
		var wrap: HBoxContainer = HBoxContainer.new()
		wrap.name = "GridCenterWrap"
		wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_theme_constant_override("separation", 0)
		vbox.add_child(wrap)
		vbox.move_child(wrap, idx)
		vbox.remove_child(grid)
		wrap.add_child(grid)

	# Configure grid
	grid.columns = max(1, catalog.columns)
	grid.add_theme_constant_override("h_separation", GRID_H_SEP)
	grid.add_theme_constant_override("v_separation", GRID_V_SEP)

	_build_tiles()
	_refresh_all_best_time_labels()

	# Listen for best-time changes while this screen is open.
	var records: Node = get_node_or_null("/root/LevelRecords")
	if records != null and records.has_signal("best_time_changed"):
		records.connect("best_time_changed", Callable(self, "_on_best_time_changed"))

func _process(delta: float) -> void:
	# Read combined input strength: right (1) .. left (-1)
	var horiz: float = Input.get_action_strength(_right_action) - Input.get_action_strength(_left_action)

	if not _axis_latched:
		# First crossing of the deadzone → move once, latch, start repeat delay
		if absf(horiz) >= AXIS_DEADZONE:
			_axis_dir = (1 if horiz > 0.0 else -1)
			_move_selection(_axis_dir)
			_axis_latched = true
			_axis_timer = AXIS_REPEAT_DELAY
	else:
		# Re-arm when stick returns under the lower threshold
		if absf(horiz) <= AXIS_RELEASE:
			_axis_latched = false
		else:
			# Held past deadzone: repeat when timer elapses
			_axis_timer -= delta
			if _axis_timer <= 0.0:
				_move_selection(_axis_dir)
				_axis_timer = AXIS_REPEAT_INTERVAL

func _unhandled_input(event: InputEvent) -> void:
	# Only handle "select" here to avoid double-triggering left/right
	if event.is_action_pressed(_select_action) and not event.is_echo():
		_activate_selection()
		accept_event()

func _build_tiles() -> void:
	_clear_children(grid)
	_best_time_labels.clear()
	_buttons.clear()
	_level_ids.clear()
	_scene_paths.clear()
	_selected_index = 0

	var index: int = 0
	for entry in catalog.levels:
		if entry == null:
			continue

		var level_id: String = entry.id
		var level_title: String = entry.title if entry.title != "" else entry.id
		var scene_path: String = entry.scene_path

		var tile: VBoxContainer = VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var button: Button = _make_square_button(level_title)
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.pressed.connect(_on_level_button_pressed.bind(level_id, scene_path))
		button.mouse_entered.connect(_on_button_hovered.bind(index)) # mouse can change selection
		tile.add_child(button)

		var caption: Label = Label.new()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", CAPTION_FONT_SIZE)
		caption.text = "Best Time"
		tile.add_child(caption)

		var time_label: Label = Label.new()
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_label.add_theme_font_size_override("font_size", TIME_FONT_SIZE)
		time_label.text = _best_time_text(level_id)
		tile.add_child(time_label)

		_best_time_labels[level_id] = time_label
		grid.add_child(tile)

		_buttons.append(button)
		_level_ids.append(level_id)
		_scene_paths.append(scene_path)

		index += 1

	_update_selection_visuals() # start with first selected

func _move_selection(direction: int) -> void:
	if _buttons.is_empty():
		return
	var new_index: int = _selected_index + direction
	if WRAP_SELECTION:
		if new_index < 0:
			new_index = _buttons.size() - 1
		if new_index >= _buttons.size():
			new_index = 0
	else:
		new_index = clamp(new_index, 0, _buttons.size() - 1)
	if new_index == _selected_index:
		return
	_selected_index = new_index
	_update_selection_visuals()

func _activate_selection() -> void:
	if _buttons.is_empty():
		return
	var idx: int = clamp(_selected_index, 0, _scene_paths.size() - 1)
	_on_level_button_pressed(_level_ids[idx], _scene_paths[idx])

func _on_button_hovered(index: int) -> void:
	if index >= 0 and index < _buttons.size():
		_selected_index = index
		_update_selection_visuals()

func _update_selection_visuals() -> void:
	for i in _buttons.size():
		var b: Button = _buttons[i]
		_apply_button_selected(b, i == _selected_index)

func _refresh_all_best_time_labels() -> void:
	for entry in catalog.levels:
		if entry == null:
			continue
		var level_id: String = entry.id
		if _best_time_labels.has(level_id):
			var label: Label = _best_time_labels[level_id]
			label.text = _best_time_text(level_id)

func _best_time_text(level_id: String) -> String:
	var seconds: float = _get_best_seconds(level_id)
	if not is_finite(seconds) or seconds == INF or seconds <= 0.0:
		return "0:00.000"
	return _format_time_m_ss_mmm(seconds)

func _get_best_seconds(level_id: String) -> float:
	var records: Node = get_node_or_null("/root/LevelRecords")
	if records == null or not records.has_method("get_record"):
		return INF
	return records.get_record(level_id)

func _on_level_button_pressed(level_id: String, scene_path: String) -> void:
	if scene_path.strip_edges() == "":
		push_warning("LevelSelect: Scene path is empty for " + level_id + ".")
		return
	get_tree().change_scene_to_file(scene_path)

func _on_best_time_changed(level_id: String, best_seconds: float) -> void:
	if _best_time_labels.has(level_id):
		var label: Label = _best_time_labels[level_id]
		label.text = _best_time_text(level_id)

func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	var to_free: Array[Node] = []
	for child in parent.get_children():
		to_free.append(child)
	for c in to_free:
		c.queue_free()

# ---- formatting / sizing helpers ----

func _format_time_m_ss_mmm(seconds: float) -> String:
	var total_ms: int = int(round(seconds * 1000.0))
	var minutes: int = total_ms / 60000
	var remaining_ms: int = total_ms % 60000
	var sec: int = remaining_ms / 1000
	var ms: int = remaining_ms % 1000
	var sec_text: String = str(sec).pad_zeros(2)
	var ms_text: String = str(ms).pad_zeros(3)
	return str(minutes) + ":" + sec_text + "." + ms_text

func _compute_square_size() -> int:
	var vp_w: float = float(get_viewport_rect().size.x)
	var target: int = int(round(vp_w * SQUARE_WIDTH_FRACTION))
	return clamp(target, SQUARE_MIN, SQUARE_MAX)

func _make_square_button(text_value: String) -> Button:
	var b := Button.new()
	b.text = text_value
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(_compute_square_size(), _compute_square_size())
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Base styles
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.14, 0.18, 1.0)
	normal.border_color = Color(1, 1, 1, 0.85)
	normal.border_width_left = BORDER_WIDTH
	normal.border_width_top = BORDER_WIDTH
	normal.border_width_right = BORDER_WIDTH
	normal.border_width_bottom = BORDER_WIDTH
	normal.corner_radius_top_left = CORNER_RADIUS
	normal.corner_radius_top_right = CORNER_RADIUS
	normal.corner_radius_bottom_left = CORNER_RADIUS
	normal.corner_radius_bottom_right = CORNER_RADIUS

	var hover := normal.duplicate()
	hover.bg_color = normal.bg_color.lightened(0.08)

	var pressed := normal.duplicate()
	pressed.bg_color = normal.bg_color.darkened(0.08)

	# Selected variants (thicker/brighter border)
	var sel_normal := normal.duplicate()
	sel_normal.border_width_left = BORDER_WIDTH + 2
	sel_normal.border_width_top = BORDER_WIDTH + 2
	sel_normal.border_width_right = BORDER_WIDTH + 2
	sel_normal.border_width_bottom = BORDER_WIDTH + 2
	sel_normal.border_color = Color(0.6, 0.9, 1.0, 1.0)

	var sel_hover := sel_normal.duplicate()
	sel_hover.bg_color = hover.bg_color

	var sel_pressed := sel_normal.duplicate()
	sel_pressed.bg_color = pressed.bg_color

	# Store styleboxes on the button so we can toggle later
	b.set_meta("style_normal", normal)
	b.set_meta("style_hover", hover)
	b.set_meta("style_pressed", pressed)
	b.set_meta("sel_normal", sel_normal)
	b.set_meta("sel_hover", sel_hover)
	b.set_meta("sel_pressed", sel_pressed)

	# Apply base initially; selection code will swap them for the selected tile
	_apply_button_selected(b, false)

	return b

func _apply_button_selected(b: Button, selected: bool) -> void:
	if selected:
		b.add_theme_stylebox_override("normal", b.get_meta("sel_normal"))
		b.add_theme_stylebox_override("hover", b.get_meta("sel_hover"))
		b.add_theme_stylebox_override("pressed", b.get_meta("sel_pressed"))
	else:
		b.add_theme_stylebox_override("normal", b.get_meta("style_normal"))
		b.add_theme_stylebox_override("hover", b.get_meta("style_hover"))
		b.add_theme_stylebox_override("pressed", b.get_meta("style_pressed"))
	b.add_theme_stylebox_override("focus", b.get_theme_stylebox("normal"))
