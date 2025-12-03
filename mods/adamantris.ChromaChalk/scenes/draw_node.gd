extends Node2D



enum DrawMode {
	SQUARE, #[draw mode, rectangle, color]
	LINE, #[draw mode, start, end, color, size(optional)]
	TEXT, #[draw mode, start pos, text (as string), color (whatever modulate is)]
	TEXTURE #[draw mode, position, texture]
}
onready var font = preload("res://mods/adamantris.ChromaChalk/new_dynamicfont.tres")
onready var API = get_node("/root/adamantrisChromaChalk/API")
onready var vanilla_tilemap: TileMap = get_node("../../vanilla_tilemap")
onready var proxy = get_node("..")
onready var canvas_script = get_node("../../..") #i LOVE wonky node paths
var canvas
var canvas_tex
 #this
var undo_queue = []
var stored_strokes = []

var remembered_pos
var img_size = Rect2(Vector2(0, 0), Vector2(200, 200))
var canv_beginning = Vector2(0, 0)

func _init():
	canvas = Image.new()
	canvas_tex = ImageTexture.new()
	canvas.create(200, 200, true, Image.FORMAT_RGBA8)
	canvas.lock()
	canvas_tex.create_from_image(canvas)
	canvas.unlock()

func _ready():

	var ll = get_node("/root/adamantrisChromaChalk/UI")
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
				
	draw_texture(canvas_tex, canv_beginning)


func add_undo(amount):
	#undo_queue.append(amount)
	pass
func undo():
	
	if undo_queue.empty():
		return
		
	else:
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
	
	#print("we have received some chalk packets, debug print: " + str(data))
	
	if data.empty() == true:
		return
	
	var last_unused_id = proxy.tile_set.get_last_unused_tile_id()
	
	var color
	
	var repl_img = Image.new()
	repl_img.create(200, 200, true, Image.FORMAT_RGBA8)
	
	repl_img.lock()
	
	for pixel in data:
		if not pixel[1] in range(-1, last_unused_id):
			var int_color = pixel[1]
			if int_color < -1:
				#print("we are below -1, need to convert")
				int_color = 16777216 + int_color #signed -> unsigned: 2^24 - our number
				
			
			var prepared_string = "#%x" % int_color
			color = Color(prepared_string) #this is ugly, but the server responds with a signed integer, while we dont want negative numbers for colors
			#print("we received a mod color, this is it: " + str(color))
		elif pixel[1] in API.chalk_color:
			color = API.chalk_color.get(pixel[1])
			#print("no mod color, this is our current color: " + str(color))
		else:
			var other_color = pixel[1]
			var outside_texture = proxy.tile_set.tile_get_texture(other_color)
			var outside_area = proxy.tile_set.tile_get_region(other_color)
			var outside_img = outside_texture.get_data()
			outside_img.lock()
			color = outside_img.get_pixelv(outside_area.position)
			outside_img.unlock()
			
		repl_img.set_pixelv(pixel[0], color)
		
	var repl_tex = ImageTexture.new()
	repl_tex.create_from_image(repl_img)
	
	canvas.lock()
	canvas.blend_rect(repl_img, img_size, canv_beginning)
	canvas.unlock()
	canvas_tex.set_data(canvas)
	
	#stored_strokes.append([DrawMode.TEXTURE, Vector2(0, 0), repl_tex])
	repl_img.unlock()
	update()

func new_line(start: Vector2, end: Vector2, brush_size, color, canvas_id):
	var send_load = []
#	var resume_func = canvas_script._add_brush()
	if end == remembered_pos:
		return
	
	else:
		#print("is the remembered and current different? " + str(end) + " " + str(remembered_pos))
		var current = start.round()
		remembered_pos = end.round()
		var line_img
		var last_unused_id = proxy.tile_set.get_last_unused_tile_id()
		if color == -1: #for deletion
			line_img = canvas
			
		else:
			line_img = Image.new()
			line_img.create(200, 200, true, Image.FORMAT_RGBA8)
		
		line_img.lock()
		
		
		
		var dict_color
		
		if color in API.chalk_color:
			dict_color = API.chalk_color.get(color)
		
		elif not color in API.chalk_color:
			var outside_texture = proxy.tile_set.tile_get_texture(color)
			var outside_area = proxy.tile_set.tile_get_region(color)
			var outside_img = outside_texture.get_data()
			outside_img.lock()
			dict_color = outside_img.get_pixelv(outside_area.position)
			outside_img.unlock()
		
		var hex_color = dict_color.to_html(false)
		#VERY creative use of the tilemap. I want to use the basic tilemap as storage for all colors (that way vanilla servers repeat it upon joining)
		#so we convert a hex color code to int first, and use it as a tile ID. the tile ID is a signed 24-bit number,
		#which means we have to check for it later when we replicate colors and convert it to positive on demand
		
		
		
		var hexint = str("0x" + hex_color).hex_to_int()
		print("dis b color: " + str(hexint))
		
		#dirty hack so we dont accidentally ship colors from other mods. i know that hostileonions chalks raises the IDs to 61,
		#but i hope that with max we can at least not trample on client-installed mods
		if hexint <= max(last_unused_id - 1, 61):
			print("existing color detected weewooweewoo " + str(hexint))
			hexint = 0x010101 
			 
		if not color in range(-1, last_unused_id):
			for x in brush_size:
				for y in brush_size:
					var offset = Vector2(x, y)
					line_img.set_pixelv(current + offset, dict_color)
					vanilla_tilemap.set_cellv(current + offset, hexint)
					send_load.append([current + offset, hexint])
			
			while current != end:
				for x in brush_size:
					for y in brush_size:
						var offset = Vector2(x, y)
						line_img.set_pixelv(current + offset, dict_color)
						vanilla_tilemap.set_cellv(current + offset, hexint)
						send_load.append([current + offset, hexint]) #same as earlier
				current = current.move_toward(end, 1)
			
			
			for x in brush_size:
				for y in brush_size:
					var offset = Vector2(x, y)
					line_img.set_pixelv(current + offset, dict_color)
					vanilla_tilemap.set_cellv(current + offset, hexint)
					send_load.append([current + offset, hexint])
				
		elif color in range (-1, last_unused_id):
			for x in brush_size:
				for y in brush_size:
					var offset = Vector2(x, y)
					line_img.set_pixelv(current + offset, dict_color)
					vanilla_tilemap.set_cellv(current + offset, color)
					send_load.append([current + offset, color])
			
			while current != end:
				for x in brush_size:
					for y in brush_size:
						var offset = Vector2(x, y)
						line_img.set_pixelv(current + offset, dict_color)
						vanilla_tilemap.set_cellv(current + offset, color)
						send_load.append([current + offset, color]) #same as earlier
				current = current.move_toward(end, 1)
			
			
			for x in brush_size:
				for y in brush_size:
					var offset = Vector2(x, y)
					line_img.set_pixelv(current + offset, dict_color)
					vanilla_tilemap.set_cellv(current + offset, color)
					send_load.append([current + offset, color])

		Network._send_P2P_Packet({"type": "chalk_packet", "data": send_load.duplicate(), "canvas_id": canvas_id}, "all", 2, Network.CHANNELS.CHALK)
		var line_tex = ImageTexture.new()
		line_tex.create_from_image(line_img)
		line_img.unlock()
		
		if undo_queue.size() < 5:
			undo_queue.append(canvas)
			
		elif undo_queue.size() == 5:
			undo_queue.pop_front()
			undo_queue.append(canvas)
			
		
		if color != -1:
			canvas.blend_rect(line_img, img_size, Vector2(0, 0))
		canvas_tex.set_data(canvas)
		
		stored_strokes = [[DrawMode.TEXTURE, Vector2(0, 0), canvas_tex]]# .append([DrawMode.TEXTURE, Vector2(0, 0), line_tex])
		update()
		
