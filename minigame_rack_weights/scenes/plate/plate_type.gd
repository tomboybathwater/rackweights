extends Resource
class_name PlateType

## Visual properties
@export var plate_name: String = "Plate"
@export var background_sprite: Texture2D
@export var foreground_sprite: Texture2D
@export var icon_sprite: Texture2D

## Gameplay properties
@export var countdown_value: int = 3  ## 3, 4, or 5
@export_enum("Slow:0", "Medium:1", "Fast:2") var drop_speed: int = 1

## Optional: Custom properties for weight/scoring later
@export var weight_value: float = 1.0  ## How much this plate affects bar physics
@export var score_value: int = 100  ## Points awarded for racking
