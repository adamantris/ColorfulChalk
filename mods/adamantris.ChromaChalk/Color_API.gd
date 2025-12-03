extends Node
class_name Chroma

## Signal emits color hex string and tile index ID upon creation of a new color
signal new_square(id, pos, color, size)
signal new_line(id, start, end, color, size)
signal api_tile(id, pos, color, size)
signal api_text(id, pos, text, color)

signal color_changed(color)

enum DrawMode {
	SQUARE, #[draw mode, rectangle, color]
	LINE, #[draw mode, start, end, color, size(optional)]
	TEXT, #[draw mode, start pos, text (as string), color (whatever modulate is)]
	TEXTURE #[draw mode, position, texture]
}

onready var chalk_color = { #color values courtesy to GIMP!
	0: Color(1, 0.933, 0.835, 1),
	1: Color(0.02, 0.043, 0.082, 1),
	2: Color(0.675, 0, 0.161, 1),
	3: Color(0, 0.522, 0.514, 1),
	4: Color(0.902, 0.616, 0, 1),
	5: Color(0, 0, 0, 0), #we wont support rainbow chalk, that would make managing an image a massive headache. also why is green after rainbow?
	6: Color(0.49, 0.635, 0.141, 1),
	999: Color(0.12, 0.26, 0.69, 1),# Color(0.02, 0.016, 0.667, 1), #our custom color!
	-1: Color(0, 0, 0, 0) #because we be erasin stuff
}

#onready var color_picker = get_node("/root/adamantrisChromaChalk/UI/color_picker/PanelContainer/Control/ColorPicker")
onready var save_button = get_node("/root/adamantrisChromaChalk/UI/color_picker/PanelContainer/VBoxContainer/Button")

onready var custom_color = Color(0.12, 0.26, 0.69, 1)

func _init():
	self.name = "API"

func _ready():
	
	var color_picker = get_node("/root/adamantrisChromaChalk/UI/color_picker/PanelContainer/MarginContainer/ColorPicker")
	color_picker.connect("color_changed", self, "set_custom_color")
	custom_color = color_picker.color
	
	
	
func set_custom_color(color):
	custom_color = color
	chalk_color[999] = color

func return_custom_color():
	return custom_color

func draw_square(canv_id: int, vecpos: Vector2, color: Color = Color(0.137, 0.216, 0.776), size: int = 3):
	
	assert(canv_id == null, "Tried to use draw_square without supplying an ID, which is needed to draw to specific canvases.")
	emit_signal("new_square", canv_id, vecpos, color, size)
	

func draw_line(canv_id: int, start: Vector2, end: Vector2, color: Color = Color(0.137, 0.216, 0.776), size: int = 3):
	assert(canv_id == null, "Tried to use draw_line without supplying an ID, which is needed to draw to specific canvases.")
	emit_signal("new_line", canv_id, start, end, color, size)
	
func draw_tile(canv_id: int, vecpos: Vector2, color: Color = Color(0.137, 0.216, 0.776), size: int = 1):
	emit_signal("api_tile", canv_id, vecpos, color, size)
	
func draw_text(canv_id: int, pos: Vector2, text: String, color: Color = Color(0, 0, 0, 1)):
	emit_signal("api_text", canv_id, pos, text, color)
	
	pass
	
	
