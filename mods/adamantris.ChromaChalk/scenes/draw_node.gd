extends Node2D

enum DrawMode {
	SQUARE, #[draw mode, rectangle, color]
	LINE, #[draw mode, start, end, color, size(optional)]
	TEXT, #[draw mode, start pos, text (as string), color (whatever modulate is)]
	TEXTURE #[draw mode, position, texture]
}
onready var font = preload("res://mods/adamantris.ChromaChalk/new_dynamicfont.tres")
var undo_queue = []
var stored_strokes = []

onready var API = get_node("/root/adamantrisChromaChalk/API")

# Declare member variables here. Examples:
# var a = 2
# var b = "text"


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
	
	print("we created our empty image: " + str(tilemap_img))
	
	
	
	for tile in prev_canv.get_used_cells():
		var color = API.chalk_color.get(prev_canv.get_cellv(tile))
		tilemap_img.set_pixelv(prev_canv.world_to_map(tile), color)
		
		print("set color " + str(color) + "for tile " + str(prev_canv.world_to_map(tile)))
	
	
	
	print("we tried filling the tilemap img " + str(tilemap_img))
	
	yield(get_tree().create_timer(0.5), "timeout")
	
	var tilemap_tex = ImageTexture.new()
	tilemap_tex.create_from_image(tilemap_img)
	
	
	tilemap_img.unlock()
	
	print("did we create our imagetexture? " + str(tilemap_tex))
	
	stored_strokes.append([DrawMode.TEXTURE, Vector2(0, 0), tilemap_tex])
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
	undo_queue.append(amount)
	
func undo():
	
	if undo_queue.empty():
		print("theres nothing there to undo!")
		return
		
	else:
		print("we gonna undo EVERYTHING (not really)")
		var amount = undo_queue.back()
		var shortened_queue = stored_strokes.slice(0, stored_strokes.size() - 1 - amount) #-1 because i dont like 0 indexing
		
		stored_strokes = shortened_queue
		
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
