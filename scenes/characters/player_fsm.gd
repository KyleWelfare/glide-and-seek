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
const ONE_WAY_PLATFORM_LAYER: int = 5					# Your one-way platforms live on layer 5
@export var drop_through_duration: float = 0.25			# Time to ignore layer 5 (seconds)
@export var drop_nudge_pixels: float = 2.0				# Small downward nudge to immediately leave the platform
var is_dropping_through: bool = false

func _ready() -> void:
	state_machine.init(self)
	# IMPORTANT: rays are under RayCastsContainer, so Exclude Parent will not exclude the Player.
	# Explicitly ignore the player's own body so rays don't hit our colliders.
	if floor_ray:
		# Ensure floor ray doesn't detect the player itself
		floor_ray.add_exception(self)
	if ceiling_ray:
		# Ensure ceiling ray doesn't detect the player itself
		ceiling_ray.add_exception(self)

func _unhandled_input(event: InputEvent) -> void:
	state_machine.process_input(event)

func _physics_process(delta: float) -> void:
	# Handle drop-through request before/alongside normal physics.
	# (Safe even if not over a one-way platform: ignoring layer 5 won't affect solid ground.)
	_handle_drop_through()

	state_machine.process_physics(delta)

func _process(delta: float) -> void:
	state_machine.process_frame(delta)

	if jump_buffer_timer > 0.0:
		jump_buffer_timer -= delta
	if dash_carry_active:
		dash_carry_elapsed += delta

	double_jump_label.text = str(can_double_jump)
	state_label.text = state_machine.current_state.name

# Called by GroundDash when we leave ground mid‑dash (or cancel right at a ledge)
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
	# 1) Decelerate the carried dash velocity toward 0
	var sign: int = 1 if dash_carry_velocity_x >= 0.0 else -1
	var mag: float = abs(dash_carry_velocity_x)
	mag = max(0.0, mag - dash_carry_deceleration * delta)
	dash_carry_velocity_x = mag * float(sign)
	if mag <= dash_carry_stop_threshold:
		dash_carry_active = false
		dash_carry_velocity_x = 0.0

	# 2) Fade in player control over time
	var blend: float = clamp(dash_carry_elapsed / dash_carry_input_blend_time, 0.0, 1.0)
	var input_component: float = lerp(0.0, input_axis * input_move_speed, blend)

	return dash_carry_velocity_x + input_component

# ---------------------------
# Drop-through logic
# ---------------------------
func _handle_drop_through() -> void:
	# Hold Down + press Jump while on floor to drop through layer-5 one-way platforms.
	# If standing on solid ground (not on layer 5), this safely does nothing visible.
	if is_on_floor() \
	and Input.is_action_pressed("move_down") \
	and Input.is_action_just_pressed("jump") \
	and not is_dropping_through:
		_start_drop_through()

func _start_drop_through() -> void:
	is_dropping_through = true

	# Temporarily ignore collisions with one-way platform layer (5) only.
	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, false)

	# Nudge down slightly so we're no longer 'on_floor' this frame; gravity will take over.
	global_position.y += drop_nudge_pixels

	# If we happened to be moving upward slightly, zero it so drop feels immediate.
	if velocity.y < 0.0:
		velocity.y = 0.0

	# Re-enable after a short delay.
	await get_tree().create_timer(drop_through_duration).timeout

	set_collision_mask_value(ONE_WAY_PLATFORM_LAYER, true)
	is_dropping_through = false

# ---------------------------
# Cramped utility
# ---------------------------
func is_cramped_tunnel() -> bool:
	# True when BOTH rays report hits (floor under + ceiling over).
	# Requires: rays Enabled, Hit From Inside ON, mask set to terrain, and add_exception(self) above.
	if !is_on_floor():
		return false
	return floor_ray != null && ceiling_ray != null && floor_ray.is_colliding() && ceiling_ray.is_colliding()
