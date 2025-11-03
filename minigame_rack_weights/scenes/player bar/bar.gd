extends Node2D
class_name Bar

## Signals
signal tilt_angle_changed(angle: float)
signal bar_crashed()

## Exported tuning parameters - Bar Physics
@export_group("Bar Physics")
@export var base_drift_force: float = 2.0
@export var gravity_threshold: float = 15.0
@export var gravity_multiplier: float = 3.0
@export var max_tilt_angle: float = 45.0
@export var rotation_damping: float = 0.98

## Exported tuning parameters - Player Control
@export_group("Player Control")
@export var nudge_impulse: float = 150.0
@export var consecutive_nudge_amplifier: float = 1.15  ## Each consecutive nudge is 15% stronger

## Internal state
var current_angle: float = 0.0
var angular_velocity: float = 0.0
var is_crashed: bool = false
var nudge_commitment: int = 0  # Negative = left commitment, Positive = right commitment

## Drift state
var drift_direction: float = 0.0
var drift_timer: float = 0.0
var drift_change_interval: float = 1.5

## Node references
@onready var pivot_point: Marker2D = $PivotPoint


func _ready() -> void:
	_randomize_drift()


func _process(delta: float) -> void:
	if is_crashed:
		return
	
	_update_drift(delta)
	_apply_physics(delta)
	_update_rotation(delta)
	_check_crash()


func _input(event: InputEvent) -> void:
	# Always allow reset, even when crashed
	if event.is_action_pressed("reset_bar"):
		reset_bar()
		return
	
	# Don't allow nudging when crashed
	if is_crashed:
		return
	
	if event.is_action_pressed("nudge_left"):
		_nudge(-1)
	elif event.is_action_pressed("nudge_right"):
		_nudge(1)

## Updates the random drift direction
func _update_drift(delta: float) -> void:
	drift_timer -= delta
	if drift_timer <= 0.0:
		_randomize_drift()


## Randomizes drift direction and resets timer
func _randomize_drift() -> void:
	drift_direction = randf_range(-1.0, 1.0)
	drift_timer = drift_change_interval


## Applies all physics forces to angular velocity
func _apply_physics(delta: float) -> void:
	# Apply random drift force
	var drift_force: float = drift_direction * base_drift_force
	
	# Apply gravity simulation when past threshold
	var gravity_force: float = 0.0
	if abs(current_angle) > gravity_threshold:
		var over_threshold: float = abs(current_angle) - gravity_threshold
		var gravity_direction: float = sign(current_angle)
		gravity_force = gravity_direction * over_threshold * gravity_multiplier
	
	# Combine forces
	angular_velocity += (drift_force + gravity_force) * delta
	
	# Apply damping to slow rotation naturally
	angular_velocity *= rotation_damping


## Updates bar rotation based on angular velocity
func _update_rotation(delta: float) -> void:
	current_angle += angular_velocity * delta
	
	# Clamp to prevent runaway values
	current_angle = clamp(current_angle, -max_tilt_angle * 1.5, max_tilt_angle * 1.5)
	
	# Apply rotation to the pivot point (which has the sprite as a child)
	pivot_point.rotation_degrees = current_angle
	
	# Emit signal for debugging/UI
	tilt_angle_changed.emit(current_angle)


## Player nudge input
## Player nudge input
## Player nudge input
func _nudge(direction: int) -> void:
	# Update commitment based on direction
	nudge_commitment += direction
	
	# Calculate amplified strength based on absolute commitment
	# The more committed in ANY direction, the stronger nudges become in that direction
	var commitment_strength: int = 0
	
	# If nudging in the direction we're already committed to, use full commitment
	if sign(nudge_commitment) == direction or nudge_commitment == 0:
		commitment_strength = abs(nudge_commitment)
	# If nudging against our commitment, we're "peeling back" so use 0 (base strength)
	else:
		commitment_strength = 0
	
	var amplification: float = pow(consecutive_nudge_amplifier, commitment_strength)
	var final_impulse: float = nudge_impulse * amplification
	
	# Apply impulse to angular velocity
	angular_velocity += direction * final_impulse * get_process_delta_time()
	
	# Debug output
	print("Commitment: ", nudge_commitment, " | Strength: ", commitment_strength, " | Amp: %.2f" % amplification)


## Checks if bar has exceeded crash threshold
func _check_crash() -> void:
	if abs(current_angle) >= max_tilt_angle:
		_crash()


## Handles bar crash
func _crash() -> void:
	is_crashed = true
	bar_crashed.emit()
	print("BAR CRASHED at angle: ", current_angle)


## Reset bar to initial state
func reset_bar() -> void:
	current_angle = 0.0
	angular_velocity = 0.0
	is_crashed = false
	pivot_point.rotation_degrees = 0.0
	nudge_commitment = 0
	_randomize_drift()
	print("Bar reset")
