extends CanvasLayer

enum DrawMode {
	SQUARE,
	LINE
	
}



var van_tilemap: TileMap
var texrect: TextureRect
var imgtex: ImageTexture
var img: Image
onready var draw = get_node("Node2D")


onready var img_size = 200 #matching vanilla resolution
onready var baby_node = get_node("Node2D")

var canvas #this is cringe but relative path is way easier to handle
var canvas_transform

var draw_count = 0

var chalk_color = { #color values courtesy to GIMP!
	0: Color(1, 0.933, 0.835, 1),
	1: Color(0.02, 0.043, 0.082, 1),
	2: Color(0.675, 0, 0.161, 1),
	3: Color(0, 0.522, 0.514, 1),
	4: Color(0.902, 0.616, 0, 1),
	5: -2, #we wont support rainbow chalk, that would make managing an image a massive headache. also why is green after rainbow?
	6: Color(0.49, 0.635, 0.141, 1),
	7: Color(0.02, 0.016, 0.667, 1), #our custom color!
	-1: Color(0, 0, 0, 0) #because we be erasin stuff
}

var last_pixel_pos = null
# Declare member variables here. Examples:
# var a = 2
# var b = "text"

var funny_update_counter = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	#yield(self, "tree_entered")
	var color_picker = get_node("/root/adamantrisChromaChalk/UI/color_picker/PanelContainer/VBoxContainer/Control/ColorPicker")
	#color_picker.connect("color_changed", self, "set_custom_color")
#	var tilemap = get_node("../TileMap")

#	tilemap.name = "vanilla_tilemap"

	van_tilemap = get_node("../vanilla_tilemap")
	#van_tilemap.visible = false

	#self.name = "TileMap"
	
	
#	texrect = TextureRect.new()
#
#
#	img = Image.new()
#
#
#	while img == null:
#		print("oh no image is null or something")
#
#
#
#
#	img.lock()
#	print("we will try creating an image")
#	img.create(img_size, img_size, true, Image.FORMAT_RGBA8)
#
#	img.unlock()
#
#	imgtex = ImageTexture.new()
#	print("we created the texture")
#	#yield(get_tree(), "idle_frame")
#
#	imgtex.create_from_image(img)
#
#
#
#
#	texrect.set_texture(imgtex)
#	texrect.visible = false
#	self.add_child(texrect)



	canvas = get_node("../..") # cursed relative path but easier to handle
	canvas_transform = canvas.transform
func set_custom_color(color):
	chalk_color[7] = color

func set_cell(posx, posy, color):
	#print("proxying set_cell")
	van_tilemap.set_cell(posx, posy, color)
	#draw.draw_new([draw.DrawMode.SQUARE, ])
	
	

	
func get_used_cells():
	var used_cells = van_tilemap.get_used_cells()
	#print("proxying get_used_cells")
	return used_cells
	
	
func get_cell(x, y):
	var cell = van_tilemap.get_cell(x, y)
	#print("proxying get_cell")
	return cell
	
	
func color_img(pos, size, color, last_mouse_pos):
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):

	draw_count += 1
	if color == 5: #5 is rainbow chalk, we dont support animations
		return
	#var momma_view = get_node("..")
	#var canv_transform = self.transform
	var local_pos = canvas_transform.xform_inv(pos) #we dont need a Y position
#	var baby_node = get_node("Node2D")
	#print("this is the canvaslayer transform " + str(momma_view.get_final_transform()))
	#print("this is another test for canvasitem transform: " + str(baby_node.get_global_transform()))
	#the xformed vector is a value between -10 and +10, so we compensate it with adding 10,
	#dividing by 20 (because +10 is essentialy doubling), then we scale to 200 because our value will be between 0 and 1
	var pixel_pos = Vector2((local_pos.x + 10), (local_pos.z + 10)) / 20 * img_size
	var selected_color = chalk_color.get(color)
#	var trans = get_node("..")

	#print(str(get_global_transform_with_canvas()))
	
	var paint_size = 1 * size

	
	
	
	if last_pixel_pos == null:
		last_pixel_pos = pixel_pos
	
	

		
	var square_pos = Vector2(int(pixel_pos.x) - 1, int(pixel_pos.y))
	var square_size = Vector2(paint_size, paint_size)
	var paint_rect = Rect2(square_pos,  square_size)
	#draw.draw_new([DrawMode.SQUARE, paint_rect, selected_color])
	
	#baby_node.stored_strokes.append([last_pixel_pos, pixel_pos, selected_color])
	#baby_node.update()
	
#	var temp_pos = last_pixel_pos #so we have something to modify
#	while temp_pos != pixel_pos:
#
#		var paint_rect = Rect2(int(temp_pos.x) - paint_size / 2, int(temp_pos.y) - paint_size / 2, paint_size, paint_size)
#		img.fill_rect(paint_rect, selected_color)
#		temp_pos = temp_pos.move_toward(pixel_pos, 1)
#	img.unlock()
#	imgtex.set_data(img)

	last_pixel_pos = Vector2(int(pixel_pos.x), int(pixel_pos.y))
	pass

	#baby_node.stored_strokes.append()
func chalk_update(pos):
	last_pixel_pos = null
	
	if draw_count != 0:
		draw.add_undo(draw_count)

		draw_count = 0
	


func create_tile(tile_id): #im just gonna assume that the game will crash when another mod adds tiles, so im proxying that too
	van_tilemap.create_tile(tile_id)
	
func tile_set_texture(tile_id, texture):
	van_tilemap.tile_set_texture(tile_id, texture)

func clear():
	van_tilemap.clear()

func get_cellv(vector):
	var vec = van_tilemap.get_cellv(vector)
	return vec

func set_cellv(vector, id):
	van_tilemap.set_cellv(vector, id)
