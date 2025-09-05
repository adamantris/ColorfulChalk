# ChromaChalk, a mod that extends chalk colors and adds save/load functionality.
# Copyright (C) 2025 adamantris
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends Node

signal save_button_pressed(id)

#this is an extremely convoluted mess and i hate it
onready var main = get_node("/root/adamantrisChromaChalk")
onready var paste_select = $"paste_stuff/paste_select"
onready var file_dialog = $"paste_stuff/FileDialog"
onready var tex_rect = $"paste_stuff/paste_select/VBoxContainer/TextureRect"
onready var paste_button = $"paste_stuff/button_container/HSplitContainer/paste_button"
onready var color_picker_button = $"paste_stuff/button_container/picker_button"
onready var color_picker = $"color_picker"
onready var canvaslayer = $"paste_stuff"
onready var save_select = $"paste_stuff/save_select"

var filter_switch

var menu_block = true setget on_block_change #wooo i finally found an use for setget
var filter_mode = Image.INTERPOLATE_NEAREST #...or, "no filter on resizing"


var processed_image: Image
var current_tilemap_path: String

var load_thread: Thread
var pixel_thread: Thread

func _ready():
	
	file_dialog.connect("file_selected", self, "on_file_selected")
	color_picker_button.connect("pressed", self, "color_button_pressed")
	
	InputMap.add_action("toggle_chalk_overlay")
	var f4 = InputEventKey.new()
	f4.scancode = KEY_F4
	InputMap.action_add_event("toggle_chalk_overlay", f4)
	
	if color_picker == null:
		color_picker = get_node("color_picker") #and the color picker takes aaages to appear
		
	filter_switch = $"paste_stuff/paste_select/VBoxContainer/interpolate_switch"
	filter_switch.connect("toggled", self, "on_filter_toggle")
	
	self.connect("save_button_pressed", self, "on_save")
	
func on_save(id):
	main.atlas_img.lock()
	var selected_canv: TileMap = get_node(main.canv_paths.get(id))
	print("saving canvas " + str(selected_canv))
	var temp_img = Image.new()
	temp_img.create(200, 200, false, Image.FORMAT_RGBA8)
	temp_img.lock()
	var tileset = selected_canv.tile_set
	print("tileset is: " + str(tileset))
	var set_cells = selected_canv.get_used_cells()
	#print("set cells without world_to_map: " + str(set_cells[0]))
	#print("set cells are: " + str(set_cells))
	#print("set cells with world_to_map: " + str(selected_canv.world_to_map(set_cells[0])))
	for cell in set_cells: #one cell is one vec2 on the tilemap
		var cell_id = selected_canv.get_cellv(cell)
		var cell_atlas_region = tileset.tile_get_region(cell_id)
		#print("region is: " + str(cell_atlas_region))
		var pixel_color = main.atlas_img.get_pixelv(cell_atlas_region.position)
		#print("got color: " + pixel_color.to_html(), " , color object: " + str(pixel_color))
		temp_img.set_pixelv(cell, pixel_color)
		
	var date = Time.get_datetime_dict_from_system()
		
	#this is the most incomprehensible string ive ever written, its supposed to be "canvas_[id]_[day]_[month]_[hour][minute][second].png" glued together
	temp_img.save_png("user://ChromaChalk_images/canvas_" + str(id) + "_" + str(date.get("day")) + "_" + str(date.get("month")) + "_" + str(date.get("hour")) + str(date.get("minute")) + str(date.get("second")) + ".png")
	main.atlas_img.unlock()
	temp_img.unlock()
	
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
		
	image.resize(200, 200, filter_mode)

	call_deferred("_on_loading_finished", image)

func _on_loading_finished(loaded_img: Image):
	processed_image = loaded_img
	var image_tex = ImageTexture.new()
	image_tex.create_from_image(loaded_img)
	

	
	tex_rect.set_texture(image_tex)
	
	paste_select.popup()
	
	if load_thread:
		load_thread.wait_to_finish()
	print("Image loading and texture creation complete.")

func create_one_color(color):
	var fake_color_dict = {"pixels": [color], "loader_path": self.get_path(), "tilemap_path": "meow"}
	main.add_color_data(fake_color_dict)

# This is called by the UI button. It starts the whole process.
func paste_image(id):
	pixel_thread = Thread.new()
	main.button_id = id
	paste_select.visible = false
	if not processed_image: return
	
#	_set_ui_busy(true)
#
#
#	if not tilemap_path:
#		_set_ui_busy(false)
#		return
		
	var all_pixels = []
	processed_image.lock()
	pixel_thread.start(self, "gather_pixel_data", [processed_image, str(id)])
	#pixel_thread.wait_to_finish()
#	while pixel_thread.is_alive():
#		#print("thread is alive, waiting")
#		continue
#	all_pixels = pixel_thread.wait_to_finish()
#	print("pixel gatherer thread finished, collected pixels: " + str(all_pixels))
	processed_image.unlock()
	
#	var data_for_main = { "pixels": all_pixels, "loader_path": self.get_path(), "tilemap_path": tilemap_path }
#	main.add_color_data(data_for_main)

func gather_pixel_data(data_array):
	var all_pixels = []
	var img = data_array[0]
	var id = data_array[1]
	img.lock()
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			all_pixels.append(img.get_pixel(x, y))
	img.unlock()
	call_deferred("use_pixel_data", all_pixels, id)
	
func use_pixel_data(pixel_array, id):


	print("i assume the thread is marked as dead now? " + str(pixel_thread.is_alive()))
	pixel_thread.wait_to_finish()
	print("received id: " + id)
	#print("this b color array: " + str(pixel_array))
	var tilemap_path = main.canv_paths.get(id)
	var data_for_main = { "pixels": pixel_array, "loader_path": self.get_path(), "tilemap_path": tilemap_path }
	main.add_color_data(data_for_main)

func actually_paint_tiles_on_map(canv_path):
	print("Callback received. Painting tiles...")
	var selected_tilemap = get_node(canv_path)
	print("this is tilemap path: " + str(canv_path) + ", this is tilemap node: " + str(selected_tilemap))
	if not selected_tilemap:
		_set_ui_busy(false)
		return

	var pos = selected_tilemap.world_to_map(selected_tilemap.global_transform.origin)
	processed_image.lock()
	for y in range(processed_image.get_height()):
		for x in range(processed_image.get_width()):
			var pixel_color = processed_image.get_pixel(x, y)
			#if pixel_color.a8 == 0:
				#print("pixel isnt visible, lets skip setting it")
			#	continue
			var hex_color = pixel_color.to_html(false)
			var tile_id = main.color_dict.get(hex_color, -1)
			if tile_id != -1:
				var pixel_coord = Vector2(pos.x, pos.y) + Vector2(x, y)
				selected_tilemap.set_cell(pixel_coord.x, pixel_coord.y, tile_id)
	processed_image.unlock()
	
	print("Finished painting tiles. Re-enabling UI.")
	
	_set_ui_busy(false)

func _input(event):
	if Input.is_action_just_pressed("toggle_chalk_overlay") and menu_block == false:
		if canvaslayer.visible == true:
			canvaslayer.visible = false
			
		elif canvaslayer.visible == false:
			canvaslayer.visible = true
			
		if (color_picker.visible or file_dialog.visible or paste_select.visible) == true:
			color_picker.visible = false
			file_dialog.visible = false
			paste_select.visible = false
		
		
		
func color_button_pressed(): #this flipflopping is also cringe
	
		
	if color_picker.visible == false:
		color_picker.visible = true
		
	elif color_picker.visible == true:
		color_picker.visible = false
		
func on_block_change(new_block_state):
	print("received a set call, new menu block state: " + str(new_block_state))
	menu_block = new_block_state
	print("was setting the new block state successful? " + str(menu_block == new_block_state))
	if new_block_state == true:
		color_picker.visible = false
		canvaslayer.visible = false
		
func on_filter_toggle(toggle_state):
	if toggle_state == true:
		print("filter toggle set to on, switching to lanczos interpolation")
		filter_mode = Image.INTERPOLATE_LANCZOS
		
	elif toggle_state == false:
		print("filter toggle set to off, switching to no interpolation")
		filter_mode = Image.INTERPOLATE_NEAREST



func _on_save_button_pressed():
	 # Replace with function body.
	save_select.popup()


func paste_img(extra_arg_0):
	pass # Replace with function body.


func _on_paste_button_pressed():
	file_dialog.popup_centered() # Replace with function body.
