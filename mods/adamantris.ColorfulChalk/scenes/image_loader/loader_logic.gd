extends Node

onready var main = get_node("/root/adamantrisColorfulChalk")
onready var paste_select = $"CanvasLayer/paste_select"
onready var file_dialog = $"CanvasLayer/FileDialog"
onready var tex_rect = $"CanvasLayer/paste_select/VSplitContainer/TextureRect"
onready var tex_rect_2x = get_node("/root/adamantrisColorfulChalk/image_loader/CanvasLayer/TextureRect_2x")
onready var paste_button = $"CanvasLayer/Button"

var processed_image: Image
var processed_image_2x: Image
var current_tilemap_path: String

var load_thread: Thread

func _ready():
	file_dialog.connect("file_selected", self, "on_file_selected")
	
func _set_ui_busy(is_busy: bool): #this is a dumb hack
	if paste_button:
		paste_button.disabled = is_busy
	file_dialog.get_ok().disabled = is_busy
	print("UI Busy State: %s" % is_busy)

func on_file_selected(path: String):
	print("File selected, starting background loading thread for: " + path)
	if load_thread and load_thread.is_active():
		load_thread.wait_to_finish()
	
	load_thread = Thread.new()
	load_thread.start(self, "_thread_load_function", path)

func _thread_load_function(path: String):
	var image = Image.new()
	if image.load(path) != OK:
		print("Error loading image.")
		return
		
	image.resize(200, 200, Image.INTERPOLATE_NEAREST)
	var image_2x = image.duplicate()
	image_2x.resize_to_po2(true, Image.INTERPOLATE_NEAREST)
	
	call_deferred("_on_loading_finished", image, image_2x)

func _on_loading_finished(loaded_img: Image, loaded_img_2x: Image):
	processed_image = loaded_img
	processed_image_2x = loaded_img_2x
	
	var image_tex = ImageTexture.new()
	image_tex.create_from_image(processed_image)
	
	var image_tex_2x = ImageTexture.new()
	image_tex_2x.create_from_image(processed_image_2x)
	
	tex_rect.set_texture(image_tex)
	tex_rect_2x.set_texture(image_tex_2x)
	
	paste_select.popup()
	
	if load_thread:
		load_thread.wait_to_finish()
	print("Image loading and texture creation complete.")

# This is called by the UI button. It starts the whole process.
func paste_image(id):
	if not processed_image: return
	
	_set_ui_busy(true)
	
	current_tilemap_path = main.canv_paths.get(id)
	if not current_tilemap_path:
		_set_ui_busy(false)
		return
		
	var all_pixels = []
	processed_image.lock()
	for y in range(processed_image.get_height()):
		for x in range(processed_image.get_width()):
			all_pixels.append(processed_image.get_pixel(x, y))
	processed_image.unlock()
	
	var data_for_main = { "pixels": all_pixels, "loader_path": self.get_path() }
	main.add_color_data(data_for_main)

func actually_paint_tiles_on_map():
	print("Callback received. Painting tiles...")
	var selected_tilemap = get_node_or_null(current_tilemap_path)
	if not selected_tilemap:
		_set_ui_busy(false)
		return

	var pos = selected_tilemap.world_to_map(selected_tilemap.global_transform.origin)
	processed_image.lock()
	for y in range(processed_image.get_height()):
		for x in range(processed_image.get_width()):
			var pixel_color = processed_image.get_pixel(x, y)
			var hex_color = pixel_color.to_html(false)
			var tile_id = main.color_dict.get(hex_color, -1)
			if tile_id != -1:
				var pixel_coord = Vector2(pos.x, pos.y) + Vector2(x, y)
				selected_tilemap.set_cell(pixel_coord.x, pixel_coord.y, tile_id)
	processed_image.unlock()
	
	print("Finished painting tiles. Re-enabling UI.")
	_set_ui_busy(false)

func _input(event):
	if event.is_class("InputEventKey") and event.scancode == KEY_F4:
		print("ohai i work")
