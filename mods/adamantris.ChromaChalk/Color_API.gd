extends Node


## Signal emits color hex string and tile index ID upon creation of a new color
signal new_square(id, pos, color, size)
signal new_line(id, start, end, color, size)
signal api_tile(id, pos, color, size)
signal api_text(id, pos, text, color)

var chalk_color = { #color values courtesy to GIMP!
	0: Color(1, 0.933, 0.835, 1),
	1: Color(0.02, 0.043, 0.082, 1),
	2: Color(0.675, 0, 0.161, 1),
	3: Color(0, 0.522, 0.514, 1),
	4: Color(0.902, 0.616, 0, 1),
	5: Color(0, 0, 0, 0), #we wont support rainbow chalk, that would make managing an image a massive headache. also why is green after rainbow?
	6: Color(0.49, 0.635, 0.141, 1),
	7: Color(0.02, 0.016, 0.667, 1), #our custom color!
	-1: Color(0, 0, 0, 0) #because we be erasin stuff
}



func _init():
	self.name = "API"




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
	
