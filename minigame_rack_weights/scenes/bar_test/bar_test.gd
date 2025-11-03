extends Node2D

@onready var bar: Bar = $Bar


func _ready() -> void:
	# Connect to bar signals for feedback
	bar.tilt_angle_changed.connect(_on_bar_tilt_changed)
	bar.bar_crashed.connect(_on_bar_crashed)
	
	print("=== BAR TEST ===")
	print("Controls:")
	print("  A / Left Arrow - Nudge Left")
	print("  D / Right Arrow - Nudge Right")
	print("  R - Reset Bar")
	print("================")


func _on_bar_tilt_changed(angle: float) -> void:
	# Print angle occasionally for debugging
	pass


func _on_bar_crashed() -> void:
	print("!!! CRASH !!!")
	# Flash the screen red
	modulate = Color.RED
	await get_tree().create_timer(0.3).timeout
	modulate = Color.WHITE
