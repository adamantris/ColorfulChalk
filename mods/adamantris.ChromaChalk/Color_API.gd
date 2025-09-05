extends Node


## Signal emits color hex string and tile index ID upon creation of a new color
signal color_created(color_string, id)

## Signal emits color hex string and tile index ID upon a new color being set in the chalk
signal color_updated(color_string, id)

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var main = $"/root/adamantrisChromaChalk"


func _ready():
	self.name = "Color_API"

## Takes a hex color string, returns it's associated tile index ID
## If color doesn't exist, returns null
func get_id_by_string(color: String) -> int:
	return 1
	pass
	
## Takes in a tile index ID, returns its corresponding color hex string
## If ID doesn't exist or is vanilla chalk, returns null
func get_string_by_id(id: int) -> String:
	return "hi"

## Takes in *either* a color object or a hex string, returns its new tile index ID
## Color objects are HIGHLY preferred because they are less expensive in terms of compute resources, so if possible pass that
## If passed object/string is invalid, returns null
func create_color(color_object_or_string) -> int:
	return main

## Takes in a hex string or a tile index ID, and sets the chalk item to the specified color
## Does nothing if passed object is invalid or outside the tile index
func set_chalk_color(color_string_or_id) -> void:
	pass
