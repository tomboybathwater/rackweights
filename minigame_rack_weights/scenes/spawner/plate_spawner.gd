extends Node2D
class_name PlateSpawner

## Signals
signal plate_spawned(plate: Plate)
signal all_plates_spawned()

## Exported configuration
@export_group("Spawn Configuration")
@export var total_plates: int = 10  ## Total plates to spawn per game
@export var plate_scene: PackedScene  ## Reference to plate.tscn

@export_group("Plate Types")
@export var available_plate_types: Array[PlateType] = []  ## Pool of plate types to spawn from

@export_group("Drop Target")
@export var drop_target_y: float = 700.0  ## Y position where plates drop to (below screen)

## State
var plates_spawned: int = 0
var current_plate: Plate = null
var can_spawn_next: bool = true
var plate_queue: Array[PlateType] = []  ## Pre-generated queue of plates

## Node references
@onready var spawn_position: Marker2D = $SpawnPosition


func _ready() -> void:
	if plate_scene == null:
		push_error("PlateSpawner: plate_scene not assigned!")


## Generate the plate queue at game start
func generate_queue() -> void:
	plate_queue.clear()
	
	if available_plate_types.is_empty():
		push_error("PlateSpawner: No plate types available!")
		return
	
	for i in range(total_plates):
		var random_type: PlateType = available_plate_types.pick_random()
		plate_queue.append(random_type)
	
	print("📋 Generated queue of %d plates" % plate_queue.size())


## Start spawning plates
func start_spawning() -> void:
	generate_queue()
	plates_spawned = 0
	can_spawn_next = true
	_spawn_next_plate()


## Spawn the next plate in sequence
func _spawn_next_plate() -> void:
	if plates_spawned >= total_plates:
		all_plates_spawned.emit()
		print("📦 All plates spawned!")
		return
	
	if not can_spawn_next:
		return
	
	# Get next plate type from queue
	if plates_spawned >= plate_queue.size():
		push_error("PlateSpawner: Trying to spawn more plates than queue has!")
		return
	
	var plate_type: PlateType = plate_queue[plates_spawned]
	
	# Create plate instance
	var plate: Plate = plate_scene.instantiate()
	plate.apply_plate_type(plate_type)
	
	# Add to scene
	get_parent().add_child(plate)
	current_plate = plate
	
	# Connect signals
	plate.rack_attempted.connect(_on_plate_rack_attempted)
	plate.fell_out_of_bounds.connect(_on_plate_fell_out)
	
	# Start plate sequence - use spawner's actual global position
	var spawn_x: float = global_position.x
	plate.start_sequence(spawn_x, drop_target_y)
	
	plates_spawned += 1
	can_spawn_next = false
	
	plate_spawned.emit(plate)
	print("🎲 Spawned plate %d/%d | Type: %s | Countdown: %d | Speed: %s" % [plates_spawned, total_plates, plate_type.plate_name, plate_type.countdown_value, _speed_name(plate_type.drop_speed)])



## Get speed name for debug
func _speed_name(speed: int) -> String:
	match speed:
		0: return "SLOW"
		1: return "MEDIUM"
		2: return "FAST"
		_: return "UNKNOWN"


## Called when plate attempts rack (connected by bar)
func _on_plate_rack_attempted(plate: Plate, bar_angle: float) -> void:
	# Plate handled by bar, we just wait for outcome
	pass


## Called when plate falls out of bounds
func _on_plate_fell_out(plate: Plate) -> void:
	print("⬇️ Plate fell out of bounds")


## Called externally when plate successfully racks or fails
func on_plate_resolved() -> void:
	can_spawn_next = true
	call_deferred("_spawn_next_plate")


## Reset spawner for new game
func reset_spawner() -> void:
	plates_spawned = 0
	can_spawn_next = true
	if current_plate != null and is_instance_valid(current_plate):
		current_plate.queue_free()
	current_plate = null
"res://minigame_rack_weights/assets/sprites/plate_tire_back.png"
