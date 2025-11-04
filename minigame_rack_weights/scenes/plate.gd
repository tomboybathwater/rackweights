extends Node2D
class_name Plate

## Signals
signal rack_attempted(plate: Plate, bar_angle: float)
signal fell_out_of_bounds(plate: Plate)

## Exported variables
@export_group("Plate Properties")
@export var countdown_value: int = 3  ## 3, 4, or 5
@export_enum("Slow", "Medium", "Fast") var drop_speed: int = 0  ## Speed tier

@export_group("Speed Configuration")
@export var slow_drop_duration: float = 3.0  ## Seconds for slow drop
@export var medium_drop_duration: float = 2.0  ## Seconds for medium drop
@export var fast_drop_duration: float = 1.0  ## Seconds for fast drop
@export var drop_ease_type: Tween.EaseType = Tween.EASE_IN  ## Tween ease type
@export var drop_trans_type: Tween.TransitionType = Tween.TRANS_QUAD  ## Tween transition type

@export_group("Countdown Configuration")
@export var countdown_tick_duration: float = 0.5  ## Seconds per countdown number

@export_group("Slide Configuration")
@export var slide_duration: float = 0.75  ## Seconds to slide down bar after racking
@export var slide_ease_type: Tween.EaseType = Tween.EASE_OUT
@export var slide_trans_type: Tween.TransitionType = Tween.TRANS_CUBIC

@export_group("Spawn/Stop Positions")
@export var spawn_offset_y: float = -200.0  ## How far above screen to spawn
@export var stop_offset_y: float = -100.0  ## Where to stop for countdown

## State
enum State { SLIDING_IN, COUNTING, DROPPING, RACKED, FAILED }
var current_state: State = State.SLIDING_IN

## Node references
@onready var visuals: CanvasGroup = $PlateVisuals
@onready var countdown_label: Label = $CountdownLabel
@onready var detection_zone: Area2D = $DetectionZone

## Internal
var target_drop_y: float = 0.0  ## Where plate should drop to


func _ready() -> void:
	# Hide countdown initially
	countdown_label.visible = false
	
	# We'll set target position when spawned by spawner
	pass


## Initialize and start the plate sequence
func start_sequence(screen_center_x: float, drop_target_y: float) -> void:
	# Position at spawn point
	position = Vector2(screen_center_x, spawn_offset_y)
	target_drop_y = drop_target_y
	
	# Start sliding in
	_slide_to_countdown_position()


## Slide from spawn to countdown stop position
func _slide_to_countdown_position() -> void:
	current_state = State.SLIDING_IN
	
	var target_pos: Vector2 = Vector2(position.x, stop_offset_y)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.finished.connect(_start_countdown)


## Start the countdown
func _start_countdown() -> void:
	current_state = State.COUNTING
	countdown_label.visible = true
	_show_countdown_number(countdown_value)


## Show a countdown number with fade
func _show_countdown_number(number: int) -> void:
	if number < 1:
		# Countdown finished, start dropping
		countdown_label.visible = false
		_start_drop()
		return
	
	countdown_label.text = str(number)
	countdown_label.modulate = Color.WHITE
	
	# Fade out this number
	var tween: Tween = create_tween()
	tween.tween_property(countdown_label, "modulate", Color(1, 1, 1, 0), countdown_tick_duration)
	tween.finished.connect(func(): _show_countdown_number(number - 1))


## Start dropping
func _start_drop() -> void:
	current_state = State.DROPPING
	
	# Get drop duration based on speed
	var duration: float
	match drop_speed:
		0: duration = slow_drop_duration
		1: duration = medium_drop_duration
		2: duration = fast_drop_duration
		_: duration = medium_drop_duration
	
	# Drop to target
	var target_pos: Vector2 = Vector2(position.x, target_drop_y)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, duration).set_ease(drop_ease_type).set_trans(drop_trans_type)
	tween.finished.connect(_on_drop_finished)


## Called when drop tween finishes (fell past bar without catching)
func _on_drop_finished() -> void:
	fell_out_of_bounds.emit(self)
	queue_free()


## Called by bar when collision detected - check angle and determine result
func check_rack_attempt(bar_angle: float, perfect_threshold: float, good_threshold: float) -> String:
	var abs_angle: float = abs(bar_angle)
	
	if abs_angle <= perfect_threshold:
		return "perfect"
	elif abs_angle <= good_threshold:
		return "good"
	else:
		return "fail"


## Successfully racked - slide down bar
func rack_on_bar(bar_node: Node2D, rest_position_y: float) -> void:
	current_state = State.RACKED
	
	# Parent to bar so we follow its rotation
	var old_global_pos: Vector2 = global_position
	get_parent().remove_child(self)
	bar_node.add_child(self)
	global_position = old_global_pos
	
	# Slide to rest position (local to bar)
	var target_pos: Vector2 = Vector2(0, rest_position_y)
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", target_pos, slide_duration).set_ease(slide_ease_type).set_trans(slide_trans_type)


## Failed rack - flip and fall
func fail_and_fall(bar_tilt_direction: float) -> void:
	current_state = State.FAILED
	
	# Apply rotation based on bar direction
	var flip_rotation: float = 180.0 if bar_tilt_direction > 0 else -180.0
	
	# Animate flip and fall
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "rotation_degrees", flip_rotation, 0.5)
	tween.tween_property(self, "position:y", position.y + 500, 1.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(visuals, "modulate", Color(1, 1, 1, 0), 1.0)
	
	tween.finished.connect(func(): queue_free())
