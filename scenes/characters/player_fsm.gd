class_name Player
extends CharacterBody2D

@onready var player_anims: AnimationPlayer = $PlayerAnims
@onready var state_machine: Node = $StateMachine
@onready var player_sprite: Sprite2D = $PlayerSprite
@onready var regular_collision: CollisionShape2D = $RegularCollision
@onready var glide_collision: CollisionShape2D = $GlideCollision
@onready var ground_dash_collision: CollisionShape2D = $GroundDashCollision

# Ray probes used to detect "cramped" (both floor and ceiling touching)
@onready var ceiling_ray: RayCast2D = $RayCastsContainer/CeilingRayCast
@onready var floor_ray: RayCast2D = $RayCastsContainer/FloorRayCast

@onready var double_jump_label: Label = $DoubleJumpLabel
@onready var state_label: Label = $StateLabel

# --- Stamina UI ---
@onready var glide_stamina_bar: ProgressBar = $GlideStaminaBar

# Input buffers
@export var dash_buffer_duration: float = 0.15
var dash_buffer_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var can_double_jump: bool = true

# Persistent facing/intent direction for dash logic
var last_horizontal_dir: int = 1 # -1 = left, 1 = right

# --- Smooth dash carry (air) ---
@export var dash_carry_deceleration: float = 1600.0
@export var dash_carry_input_blend_time: float = 0.25
@export var dash_carry_stop_threshold: float = 5.0

var dash_carry_active: bool = false
var dash_carry_velocity_x: float = 0.0
var dash_carry_elapsed: float = 0.0

# --- One-way platform drop-through (Layer 5) ---
const ONE_WAY_PLATFORM_LAYER: int = 5
@export var drop_through_duration: float = 0.25
@export var drop_nudge_pixels: float = 2.0
var is_dropping_through: bool = false

# ---------------------------
# Stamina (flat drain)
# ---------------------------
@export var max_stamina: float = 100.0
@export var stamina_drain_per_second: float = 35.0
var current_stamina: float = 0.0

# When true, the player cannot start gliding (set when stamina hits 0; cleared on landing)
var glide_lockout: bool = false

# Tracks ground contact edges to refill once on landing
var _was_on_floor: bool = false

func _ready() -> void:
	state_machine.init(self)

	# Rays: ignore our own body
	if floor_ray:
		floor_ray.add_exception(self)
	if ceiling_ray:
		ceiling_ray.add_exception(self)

	# Stamina init + UI wiring
	current_stamina = max_stamina
	if glide_stamina_bar:
		glide_stamina_bar.min_value = 0.0
		glide_stamina_bar.max_value = max_stamina
		glide_stamina_bar.value = current_stamina
		# Hidden when full at start
		glide_stamina_bar.visible = false

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)
	
	# Global arming: buffer dash if pressed while airborne (covers Jump/Fall/Glide/Wall/Coyote)
	if event.is_action_pressed("cling_dash") and !is_on_floor():
		dash_buffer_timer = dash_buffer_duration

	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

func _physics_process(delta: float) -> void:
	_handle_drop_through()

	state_machine.process_physics(delta)

	# Ground edge: refill + clear lockout when landing
	var on_floor_now: bool = is_on_floor()
	if on_floor_now and !_was_on_floor:
		current_stamina = max_stamina
		glide_lockout = false
		_update_stamina_ui()
	_was_on_floor = on_floor_now

	# Dash carry timing should be physics-stepped for consistency
	if dash_carry_active:
		dash_carry_elapsed += delta

	# Input buffer countdowns (physics for determinism)
	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
		if jump_buffer_timer < 0.0:
			jump_buffer_timer = 0.0

	if dash_buffer_timer > 0.0:
		dash_buffer_timer -= delta
		if dash_buffer_timer < 0.0:
			dash_buffer_timer = 0.0

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

	double_jump_label.text = str(can_double_jump)
	state_label.text = state_machine.current_state.name
	_update_stamina_ui()

# Public helper for states to check before transitioning into Glide
func is_glide_available() -> bool:
	return current_stamina > 0.0 and !glide_lockout

# Called by GroundDash when we leave ground mid-dash (or cancel right at a ledge)
func start_dash_carry() -> void:
	dash_carry_active = true
	dash_carry_velocity_x = velocity.x
	dash_carry_elapsed = 0.0

# Called by grounded states to ensure no stale carry persists after landing
func stop_dash_carry() -> void:
	dash_carry_active = false
	dash_carry_velocity_x = 0.0
	dash_carry_elapsed = 0.0

# Apply smooth carry + fade in air control; returns the new x velocity
func apply_air_carry(delta: float, input_axis: float, input_move_speed: float) -> float:
	var sign_val: int = 1 if dash_carry_velocity_x >= 0.0 else -1
	var mag: float = abs(dash_carry_velocity_x)
	mag = max(0.0, mag - dash_carry_deceleration * delta)
	dash_carry_velocity_x = mag * float(sign_val)
	if mag <= dash_carry_stop_threshold:
		dash_carry_active = false
		dash_carry_velocity_x = 0.0
	var blend: float = clamp(dash_carry_elapsed / dash_carry_input_blend_time, 0.0, 1.0)
	var input_component: float = lerp(0.0, input_axis * input_move_speed, blend)
	return dash_carry_velocity_x + input_component

# ---------------------------
# Drop-through logic
# ---------------------------
func _handle_drop_through() -> void:
	if is_on_floor() \
	and Input.is_action_pressed("move_down") \
	and Input.is_action_just_pressed("jump") \
	and !is_dropping_through:
		_start_drop_through()

func _start_drop_through() -> void:
	is_dropping_through = true
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)
	global_position.y += drop_nudge_pixels
	if velocity.y < 0.0:
		velocity.y = 0.0
	await get_tree().create_timer(drop_through_duration).timeout
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)
	is_dropping_through = false

# ---------------------------
# Cramped utility
# ---------------------------
func is_cramped_tunnel() -> bool:
	if !is_on_floor():
		return false
	return floor_ray != null && ceiling_ray != null && floor_ray.is_colliding() && ceiling_ray.is_colliding()

# ---------------------------
# UI helper
# ---------------------------
func _update_stamina_ui() -> void:
	if glide_stamina_bar:
		# Clamp first to avoid tiny overshoots/undershoots from math elsewhere.
		var clamped: float = clamp(current_stamina, 0.0, max_stamina)
		if clamped != current_stamina:
			current_stamina = clamped
		glide_stamina_bar.value = current_stamina
		# Only show when not full. Small epsilon prevents flicker at 99.9999…%
		var epsilon: float = 0.001
		glide_stamina_bar.visible = (current_stamina < max_stamina - epsilon)
