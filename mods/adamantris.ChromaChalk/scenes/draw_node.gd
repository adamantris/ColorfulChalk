extends Node2D




enum DrawMode {
	SQUARE, #[draw mode, rectangle, color]
	LINE, #[draw mode, start, end, color, size(optional)]
	TEXT, #[draw mode, start pos, text (as string), color (whatever modulate is)]
	TEXTURE #[draw mode, position, texture]
}
onready var font = preload("res://mods/adamantris.ChromaChalk/new_dynamicfont.tres")
onready var API = get_node("/root/adamantrisChromaChalk/API")
onready var canvas = Image.new()
onready var canvas_tex = ImageTexture.new()
 #this
var undo_queue = []
var stored_strokes = []

var remembered_pos




# Called when the node enters the scene tree for the first time.
func _ready():
	var ll = get_node("/root/adamantrisChromaChalk/UI") # Replace with function body.
	ll.connect("undo", self, "undo")
	
	API.connect("api_tile", self, "draw_api_tile")
	API.connect("api_text", self, "draw_api_text")
	
	var prev_canv = get_node("../../vanilla_tilemap")
	
	var tilemap_img = Image.new()
	

	tilemap_img.create(200, 200, true, Image.FORMAT_RGBA8)
	tilemap_img.lock()
	
	
	#var meow = []
	

	for tile in prev_canv.get_used_cells():
		var color = API.chalk_color.get(prev_canv.get_cellv(tile))
#		meow.append(prev_canv.get_cellv(tile))
		tilemap_img.set_pixelv(prev_canv.world_to_map(tile), color)
		
		#print("set color " + str(color) + "for tile " + str(prev_canv.world_to_map(tile)))
	
	
	#print(meow)
	
	yield(get_tree().create_timer(0.5), "timeout")
	
	var tilemap_tex = ImageTexture.new()
	tilemap_tex.create_from_image(tilemap_img)
	
	
	tilemap_img.unlock()
	
	canvas.create(200, 200, true, Image.FORMAT_RGBA8)
	canvas_tex.create_from_image(canvas)
	
	update()
	
func _draw():
	for draw in stored_strokes:
		
		match draw[0]:
			
			
			DrawMode.SQUARE:
				draw_rect(draw[1], draw[2])
		
			DrawMode.LINE:
			
				draw_line(draw[1], draw[2], draw[3], draw[4])
		
			DrawMode.TEXT:
				
				draw_string(draw[1], draw[2], draw[3], draw[4])
				
			DrawMode.TEXTURE:
				draw_texture(draw[2], draw[1])


func add_undo(amount):
	#undo_queue.append(amount)
	pass
func undo():
	
	if undo_queue.empty():
		print("theres nothing there to undo!")
		return
		
	else:
		print("we gonna undo EVERYTHING (not really)")
		var old_tex = undo_queue.back()
		canvas_tex = old_tex 
		
		undo_queue.pop_back()
		

		
		update()
		

func draw_new(data: Array):
	assert(typeof(data) == TYPE_ARRAY, "You are trying to draw with something that isnt an array.")
	stored_strokes.append(data)
	update()

func draw_api_tile(id, pos, color, size):
	
	
	var tile_size = Vector2(size, size)
	var tile_square = Rect2(pos, tile_size)
	
	stored_strokes.append([DrawMode.SQUARE, tile_square, color])
	update()


func draw_api_text(id, pos, text, color):
	
	var text_data = [DrawMode.TEXT, font, pos, text, color]
	stored_strokes.append(text_data)
	undo_queue.append(1)
	update()
	
func replicate(data):
	
	if data.empty() == true:
		return
	
	var repl_img = Image.new()
	repl_img.create(200, 200, true, Image.FORMAT_RGBA8)
	
	repl_img.lock()
	
	for pixel in data:
		repl_img.set_pixelv(pixel[0], API.chalk_color.get(pixel[1]))
		
	var repl_tex = ImageTexture.new()
	repl_tex.create_from_image(repl_img)
	
	stored_strokes.append([DrawMode.TEXTURE, Vector2(0, 0), repl_tex])
	repl_img.unlock()
	update()

func new_line(start: Vector2, end: Vector2, brush_size, color):
	#print("new line received, we start at " + str(start) + ", go to " + str(end) + " and use the color " + str(color))
	if end == remembered_pos:
		#print("you didnt move your mouse, current pos: " + str(end) + ", remembered pos: " + str(remembered_pos))
		return
	
	
	
	else:
		#print("is the remembered and current different? " + str(end) + " " + str(remembered_pos))
		var current = start.round()
		remembered_pos = end.round()
		var line_img
		
		if color == -1: #for deletion
			line_img = canvas
			
		else:
			line_img = Image.new()
			line_img.create(200, 200, true, Image.FORMAT_RGBA8)
		
		line_img.lock()
		
		
		for x in brush_size:
			for y in brush_size:
				line_img.set_pixelv(current + Vector2(x, y), API.chalk_color.get(color))
		
		while current != end:
			for x in brush_size:
				for y in brush_size:
					line_img.set_pixelv(current + Vector2(x, y), API.chalk_color.get(color))
			current = current.move_toward(end, 1)
			
		for x in brush_size:
			for y in brush_size:
				line_img.set_pixelv(current + Vector2(x, y), API.chalk_color.get(color))
			
		var line_tex = ImageTexture.new()
		line_tex.create_from_image(line_img)
		line_img.unlock()
		
		if undo_queue.size() < 5:
			undo_queue.append(canvas)
			
		elif undo_queue.size() == 5:
			undo_queue.pop_front()
			undo_queue.append(canvas)
			
		var img_size = Rect2(Vector2(0, 0), Vector2(200, 200))
		
		if color != -1:
			canvas.blend_rect(line_img, img_size, Vector2(0, 0))
		canvas_tex.set_data(canvas)
		
		stored_strokes = [[DrawMode.TEXTURE, Vector2(0, 0), canvas_tex]]# .append([DrawMode.TEXTURE, Vector2(0, 0), line_tex])
		update()
		
