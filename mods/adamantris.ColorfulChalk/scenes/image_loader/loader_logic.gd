# ColorfulChalk, a mod that extends chalk colors and adds save/load functionality.
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



#this is an extremely convoluted mess and i hate it
onready var main = get_node("/root/adamantrisColorfulChalk")
onready var paste_select = $"paste_stuff/paste_select"
onready var file_dialog = $"paste_stuff/FileDialog"
onready var tex_rect = $"paste_stuff/paste_select/VBoxContainer/TextureRect"
onready var paste_button = $"paste_stuff/button_container/paste_button"
onready var color_picker_button = $"paste_stuff/button_container/picker_button"
onready var color_picker = $"color_picker"
onready var canvaslayer = $"paste_stuff"

var filter_switch

var menu_block = true setget on_block_change #wooo i finally found an use for setget
var filter_mode = Image.INTERPOLATE_NEAREST #...or, "no filter on resizing"


var processed_image: Image
var current_tilemap_path: String

var load_thread: Thread

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
	image_tex.create_from_image(processed_image)
	

	
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
	
	
	if not processed_image: return
	
	_set_ui_busy(true)
	
	var tilemap_path = main.canv_paths.get(id)
	if not tilemap_path:
		_set_ui_busy(false)
		return
		
	var all_pixels = []
	processed_image.lock()
	for y in range(processed_image.get_height()):
		for x in range(processed_image.get_width()):
			all_pixels.append(processed_image.get_pixel(x, y))
	processed_image.unlock()
	
	var data_for_main = { "pixels": all_pixels, "loader_path": self.get_path(), "tilemap_path": tilemap_path }
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

