extends Node2D

@onready var bar: Bar = $Bar
@onready var plate_spawner: PlateSpawner = $PlateSpawner


func _ready() -> void:
	# Connect to bar signals for feedback
	bar.tilt_angle_changed.connect(_on_bar_tilt_changed)
	bar.bar_crashed.connect(_on_bar_crashed)
	
	# Connect to spawner signals
	plate_spawner.all_plates_spawned.connect(_on_all_plates_spawned)
	
	print("=== BAR TEST ===")
	print("Controls:")
	print("  A / Left Arrow - Nudge Left")
	print("  D / Right Arrow - Nudge Right")
	print("  R - Reset Bar")
	print("  SPACE - Start Spawning Plates")
	print("================")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # Spacebar
		plate_spawner.start_spawning()
		print("🎮 Started plate spawning!")


func _on_bar_tilt_changed(angle: float) -> void:
	# Print angle occasionally for debugging
	pass


func _on_bar_crashed() -> void:
	print("!!! CRASH !!!")
	# Flash the screen red
	modulate = Color.RED
	await get_tree().create_timer(0.3).timeout
	modulate = Color.WHITE


func _on_all_plates_spawned() -> void:
	print("🎉 All plates have been spawned!")
