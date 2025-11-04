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
@export var pulse_min_interval: float = 2.0  ## Minimum seconds between pulses
@export var pulse_max_interval: float = 5.0  ## Maximum seconds between pulses
@export var pulse_min_strength: float = 50.0  ## Minimum pulse force
@export var pulse_max_strength: float = 150.0  ## Maximum pulse force
@export var pulse_plate_multiplier: float = 1.3  ## Each plate increases pulse strength by 30%
@export var chaos_multiplier_chance: float = 0.15  ## 15% chance for chaos multiplier
@export var chaos_multiplier_range: Vector2 = Vector2(2.0, 5.0)  ## Random between 2x and 5x

## Exported tuning parameters - Player Control
@export_group("Player Control")
@export var nudge_impulse: float = 150.0
@export var consecutive_nudge_amplifier: float = 1.15  ## Each consecutive nudge is 15% stronger
@export var max_commitment_strength: int = 10  ## Cap on how much commitment amplifies nudges
@export var fitness_score: float = 1.0  ## Player skill level (1-10), set by game
@export var max_recovery_boost: float = 0.02  ## Max boost per fitness point (2% at fitness 10)

## Internal state
var current_angle: float = 0.0
var angular_velocity: float = 0.0
var is_crashed: bool = false
var nudge_commitment: int = 0  # Negative = left commitment, Positive = right commitment

## Drift state
var drift_direction: float = 0.0
var drift_timer: float = 0.0
var drift_change_interval: float = 1.5
## Pulse state
var pulse_timer: float = 0.0
var can_pulse: bool = true  ## Whether pulses are currently allowed
## plate state
var racked_plates_count: int = 0  ## Track number of plates (simulated for now)

## Node references
@onready var pivot_point: Marker2D = $PivotPoint


func _ready() -> void:
	_randomize_drift()
	pulse_timer = randf_range(pulse_min_interval, pulse_max_interval)


func _process(delta: float) -> void:
	if is_crashed:
		return
	
	_update_drift(delta)
	_update_pulse(delta)
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
	elif event.is_action_pressed("ui_accept"):  # Spacebar
		racked_plates_count += 1
		print("Added plate. Total: ", racked_plates_count)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_B:
		block_pulse()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_N:
		allow_pulse()

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
	
## Updates the pulse timer and triggers random pulses
func _update_pulse(delta: float) -> void:
	pulse_timer -= delta
	if pulse_timer <= 0.0:
		_trigger_pulse()


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
		commitment_strength = min(abs(nudge_commitment), max_commitment_strength)
	# If nudging against our commitment, we're "peeling back" so use 0 (base strength)
	else:
		commitment_strength = 0
	
	var amplification: float = pow(consecutive_nudge_amplifier, commitment_strength)
	var chaos_mult: float = _get_chaos_multiplier()
	var recovery_boost: float = _get_recovery_boost(direction)
	var final_impulse: float = nudge_impulse * amplification * chaos_mult * recovery_boost
	
	# Apply impulse to angular velocity
	angular_velocity += direction * final_impulse * get_process_delta_time()
	
	# Debug output
	var debug_msg: String = "Commitment: %d | Amp: %.2f | Chaos: %.2f" % [nudge_commitment, amplification, chaos_mult]
	if recovery_boost > 1.0:
		debug_msg += " | 🛟 Recovery: %.2fx" % recovery_boost
	print(debug_msg)
	
func _trigger_pulse() -> void:
	# Only pulse when in the safe zone (not in gravity territory) and when its safe to pulse based on state
	if can_pulse && abs(current_angle) < gravity_threshold:
		# Random direction
		var pulse_direction: float = 1.0 if randf() > 0.5 else -1.0
		
		# Random strength within range
		var base_strength: float = randf_range(pulse_min_strength, pulse_max_strength)
		
		# Amplify by number of plates
		var plate_amplification: float = pow(pulse_plate_multiplier, racked_plates_count)
		var chaos_mult: float = _get_chaos_multiplier()
		var final_strength: float = base_strength * plate_amplification * chaos_mult
		
		# Apply pulse to angular velocity
		angular_velocity += pulse_direction * final_strength * get_process_delta_time()
		
		print("PULSE! Direction: ", pulse_direction, " | Strength: %.1f" % final_strength, " | Plates: ", racked_plates_count)
	
	# Reset timer for next pulse
	pulse_timer = randf_range(pulse_min_interval, pulse_max_interval)
	

## Block pulses (called by external signal, e.g., when plate is close)
func block_pulse() -> void:
	can_pulse = false
	print("Pulses BLOCKED")


## Allow pulses (called by external signal, e.g., when plate lands or misses)
func allow_pulse() -> void:
	can_pulse = true
	print("Pulses ALLOWED")


## Calculates recovery boost based on angle severity and fitness score
## Only boosts nudges that push toward center (recovery nudges)
func _get_recovery_boost(nudge_direction: int) -> float:
	# Check if this nudge is a recovery nudge (pushing toward center)
	var is_recovery: bool = sign(current_angle) != sign(nudge_direction) and current_angle != 0
	
	if not is_recovery:
		return 1.0  # No boost for non-recovery nudges
	
	# Calculate how severe the tilt is (0.0 = centered, 1.0 = at crash threshold)
	var angle_severity: float = abs(current_angle) / max_tilt_angle
	
	# Calculate boost: severity * max_boost_per_point * fitness_score
	var boost_percentage: float = angle_severity * max_recovery_boost * fitness_score
	
	# Return as multiplier (e.g., 0.15 = 15% boost = 1.15x multiplier)
	return 1.0 + boost_percentage


## Rolls for a chaos multiplier - returns 1.0 normally, or 2-5x sometimes
func _get_chaos_multiplier() -> float:
	if randf() < chaos_multiplier_chance:
		var multiplier: float = randf_range(chaos_multiplier_range.x, chaos_multiplier_range.y)
		print("⚡ CHAOS MULTIPLIER: %.1fx" % multiplier)
		return multiplier
	return 1.0


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
	pulse_timer = randf_range(pulse_min_interval, pulse_max_interval)
	can_pulse = true
	_randomize_drift()
	print("Bar reset")
