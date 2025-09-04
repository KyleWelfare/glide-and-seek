extends CanvasLayer

@onready var time_box: HBoxContainer = $TimeBox
@onready var time_major_label: Label = $TimeBox/TimeMajorLabel
@onready var ms_box: VBoxContainer = $TimeBox/MSBox
@onready var time_ms_label: Label = $TimeBox/MSBox/TimeMSLabel
@onready var ready_label: Label = $ReadyLabel
@onready var go_label: Label = $GoLabel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Defaults so we never show blanks
	if is_instance_valid(time_major_label):
		time_major_label.text = "00:00"
	if is_instance_valid(time_ms_label):
		time_ms_label.text = ".000"
	if is_instance_valid(ready_label):
		if ready_label.text.strip_edges() == "":
			ready_label.text = "READY..."
		ready_label.visible = false
	else:
		push_warning("TimerHUD: ReadyLabel not found. Countdown will skip the READY text.")
	if is_instance_valid(go_label):
		if go_label.text.strip_edges() == "":
			go_label.text = "GO!"
		go_label.visible = false
	else:
		push_warning("TimerHUD: GoLabel not found.")

	if is_instance_valid(time_box):
		time_box.visible = true

func set_time_seconds(seconds: float) -> void:
	var total_ms: int = int(round(seconds * 1000.0))
	var mins: int = total_ms / 60000
	var secs: int = (total_ms % 60000) / 1000
	var ms: int = total_ms % 1000

	if is_instance_valid(time_major_label):
		time_major_label.text = "%02d:%02d" % [mins, secs]
	if is_instance_valid(time_ms_label):
		time_ms_label.text = ".%03d" % ms

func set_timer_visible(visible: bool) -> void:
	if is_instance_valid(time_box):
		time_box.visible = visible

func play_ready_go() -> void:
	if is_instance_valid(ready_label):
		ready_label.visible = true
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(ready_label):
		ready_label.visible = false
	if is_instance_valid(go_label):
		go_label.visible = true
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(go_label):
		go_label.visible = false
