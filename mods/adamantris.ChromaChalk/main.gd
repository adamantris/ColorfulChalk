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

signal picker_visible
signal tileset_update(new_tileset)
signal custom_draw(color_id)
signal custom_draw_stop


export var color_id: Dictionary

enum send_type{
	RELIABLE = 8,
	UNRELIABLE = 0,
	UNRELIABLE_FAST = 4,
}

const COLOR_CHANNEL = 10
const protocol_version = 5

#const world_canv_paths = {
#	"1": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/",
#	"2": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas2/Viewport/TileMap",
#	"3": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas3/Viewport/TileMap",
#	"4": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas4/Viewport/TileMap"
#}

var canv_paths #this might turn into a dict for world+prop canvases, i got an outline on how to support props in my head
var api
onready var Lure = get_node("/root/SulayreLure")
onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")

#onready var pythonscript = preload("res://pyloader/adamantrisChromaChalk/testing_script.py")
#var pynode

onready var canv_prox = preload("res://mods/adamantris.ChromaChalk/scenes/proxy_canvl.tscn")

onready var file_scene = preload("res://mods/adamantris.ChromaChalk/scenes/image_loader/file_dialog.tscn")
onready var API = preload("res://mods/adamantris.ChromaChalk/Color_API.gd")
#onready var vanilla_canvas = preload("res://Scenes/Entities/ChalkCanvas/chalk_canvas.tscn") #holy shit i finally found the reason for colors not matching the picker


var loader_logic

var canvas_TileMap: TileMap
var canvas_TileSet: TileSet
var color_dict: Dictionary = {}
var color_dict_remap: Dictionary = {}
var selected_chalk_color
var Lure_chalk_dict
var Lure_chalk_resource
var current_tileset: TileSet

var mod_user_list = []

var packet_timer: float = 0.0
var packet_thread: Thread
var packet_semaphore: Semaphore
var packet_mutex: Mutex
var kill_threads = false

var world_node

var tile_thread: Thread

export onready var atlas_img: Image
export onready var atlas_tex: ImageTexture

var color_slot = 8
var selected_slot = 3 #whatever its a placeholder value
var button_id = 0
var selected_color_id = 0
#var vanilla_canv

func _ready():
	
#	self.add_child(pythonscript.new(), true)
##	vanilla_canv = vanilla_canvas.instance()
##	var vanilla_canv_mesh = vanilla_canv.get_node("MeshInstance")
##	print("got an instance of chalk canvas: " + str(vanilla_canv_mesh))
##	var vanilla_canv_mat = vanilla_canv_mesh.get_active_material(0)
##	print("got a duplicate of the spatialmaterial: " + str(vanilla_canv_mat))
##	vanilla_canv_mat.set_flag(SpatialMaterial.FLAG_UNSHADED, true)
##	vanilla_canv_mat.set_flag(SpatialMaterial.FLAG_DONT_RECEIVE_SHADOWS, true)
##	vanilla_canv_mat.set_flag(SpatialMaterial.FLAG_ALBEDO_TEXTURE_FORCE_SRGB, true)
##	var save = ResourceSaver.save("res://Scenes/Entities/ChalkCanvas/chalk_canvas.tscn", vanilla_canv)
##	print(save)
#	canv_paths = world_canv_paths.duplicate() #godot docs say i need to duplicate it, even as a const? idk
	
	self.add_child(file_scene.instance())
	self.add_child(API.new(), true)

	
	var file_manager = Directory.new()
	if not file_manager.dir_exists("user://ChromaChalk_images"):
		print("Images folder doesn't exist, creating new folder.")
		file_manager.make_dir("user://ChromaChalk_images")
	
	Chat.connect("player_messaged", self, "chat_command")
	Players.connect("ingame", self, "ingame")
	Players.connect("player_removed", self, "player_removed")
	Lure.add_content("adamantris.ChromaChalk", "Rainbow Chalk", "res://mods/adamantris.ChromaChalk/resources/chalk_rainbow.tres", [Lure.LURE_FLAGS.FREE_UNLOCK])
#	Lure.register_action("adamantris.ChromaChalk", "_custom_paint", self, "_custom_paint")
#	Lure.register_action("adamantris.ChromaChalk", "_custom_paint_stop", self, "_custom_paint_stop")
	loader_logic = $"UI"

	
	
	
	atlas_img = Image.new()
	atlas_img.create(512, 512, false, Image.FORMAT_RGB8)
	
	atlas_tex = ImageTexture.new()
	atlas_tex.create_from_image(atlas_img)
	atlas_tex.flags += Texture.FLAG_CONVERT_TO_LINEAR
	
	InputMap.add_action("toggle_picker")
	var keyevent = InputEventKey.new()
	keyevent.scancode = KEY_P
	InputMap.action_add_event("toggle_picker", keyevent)
	
	packet_semaphore = Semaphore.new()
	packet_mutex = Mutex.new()
	packet_thread = Thread.new()
	packet_thread.start(self, "read_packets")
	print("after packet thread start")
	
	get_tree().connect("node_added", self, "on_node_add")
	#pynode = get_node("/root/adamantrisChromaChalk/Python_Processor")
	yield(get_tree().create_timer(1.0), "timeout")
	#pynode.dict_testing({"test_entry": 1})
	api = get_node("API")
	
#func _custom_paint():
#	print("this is custom paint calling")
#	emit_signal("custom_draw", selected_color_id)
	
#func _custom_paint_stop():
#	print("draw stop called")
#	emit_signal("custom_draw_stop")
	
func on_node_add(node):
	if node.get_path() == "/root/world":
		print("we joined a world, lets remove the block and activate the player left check")
		loader_logic.menu_block = false
		node.connect("tree_exiting", self, "on_node_exit")
		world_node = node
#

	if node.name == "Viewport" and "chalk_canvas" in str(node.get_path()): #why is a nodepath and a string different?
		
		var tilemap = node.get_node("TileMap")
		tilemap.name = "vanilla_tilemap"
		tilemap.visible = false
		
		node.add_child(canv_prox.instance())
#	Lure_chalk_dict = Lure.item_list.get("adamantris.ChromaChalk.Rainbow Chalk")
#	Lure_chalk_resource = Lure_chalk_dict.get("resource")
	#lobby_joined()
#
	#canvas_TileMap = get_node("/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap")
	#canvas_TileSet = canvas_TileMap.get_tileset()
	#current_tileset = canvas_TileSet

func on_node_exit():
	print("we are leaving from the world, lets disconnect and reactivate the block state")
	world_node.disconnect("tree_exiting", self, "on_node_exit")
	loader_logic.menu_block = true



func _process(delta):
	packet_timer += delta
	if packet_timer >= 0.2:
		#print("packet timer over 0.2, posting")
		packet_semaphore.post()
		packet_timer = 0.0



func chat_command(message: String, player, is_self):
#
	var ent = Players.local_player.get_node("..")
	var localPlayer = Players.local_player

	if is_self == true and message.begins_with("!write"): #!write (x) (y) (text)
		
		
		var sliced_message = message.split(" ", true, 3)
		var x = int(sliced_message[1])
		var y = int(sliced_message[2])
		var text = sliced_message[3]
		var pos_vec = Vector2(x, y)
		api.draw_text(-6, pos_vec, text)
#	if is_self == true and message.begins_with("!debug_save"):
#		var canvussy = get_node(world_canv_paths.get("1") + "Node2D/TextureRect").texture.get_data()
#		canvussy.save_png("user://img_test.png")
#		print("hopefully saved a png lol")
#		if is_self == true and msg.begins_with("!jail"):


#

#func jail(a):
#	print(a)
#	var clown
#	for plr in Players.get_players(true):
#		if a in Players.get_username(plr):
#			print("This is chihuahua " + str(plr))
#			clown = plr
#			#print(player.get_position(clown))
#
#
#	var current_pos = Players.get_position(clown)
#	var scale = clown.scale.y
#
#	var temp_scale = 1
#
#	if clown.scale.y < 1:
#
#		temp_scale = 0.9
#	var col = clown.get_node("CollisionShape")
#
#	var rad = col.shape.radius
#
#	var chair_head = Vector3(current_pos.x, current_pos.y + (((col.shape.height + 2 * col.shape.radius) / 2) - (0.18 / scale)) * scale, current_pos.z)
#	Network._sync_create_actor("chair", chair_head, clown.current_zone)
#	Network._sync_create_actor("chair", Vector3(current_pos.x + (rad * 10 * scale), current_pos.y - 0.5, current_pos.z), clown.current_zone)
#	Network._sync_create_actor("chair", Vector3(current_pos.x - (rad * 10 * scale), current_pos.y - 0.5, current_pos.z), clown.current_zone)
#	Network._sync_create_actor("chair", Vector3(current_pos.x, current_pos.y - 0.5, current_pos.z + (rad * 10 * scale)), clown.current_zone)
#	Network._sync_create_actor("chair", Vector3(current_pos.x, current_pos.y - 0.5, current_pos.z - (rad * 10 * scale)), clown.current_zone)
	
#	#this is experimental, i just wanna see if its possible
#	if is_self == true and message.begins_with("!save"):
#
#		var canv_id = message.get_slice(" ", 1)
#
#		if not int(canv_id) in [1, 2, 3, 4]:
#			print("im yelling at u you there are only 4 chalk spots")
#			PlayerData._send_notification("invalid canvas ID, only numbers between 1 and 4 are valid", 1)
#			return
#
#
#
#		var canv_tilemap_node = get_node(canv_paths.get(canv_id))
#		var canv_tileset_node = canv_tilemap_node.get_tileset()
#
#		atlas_img.lock()
#		var tileset_cells = canv_tilemap_node.get_used_cells()
#
#		var temp_image = Image.new()
#		temp_image.create(200, 200, false, Image.FORMAT_RGB8)
#
#		temp_image.lock()
#		#print("this is the tileset cells used (vec2 array): " + str(tileset_cells))
#		#temp_image.lock()
#
#
#		for cell in tileset_cells:
#			#print(str(canvas_TileMap.get_cellv(cell)))
#			var canv_tile_tex = canvas_TileSet.tile_get_texture(canv_tilemap_node.get_cellv(cell))
#
#			var pixel_color
#			#print(canv_tile_tex)
#			#print(str(canv_tile_tex))
#			if !(canv_tile_tex is AtlasTexture):
#				print("this is vanilla chalk, passing")
#				pass
#			if canv_tile_tex is AtlasTexture:
#				var canv_tile_coord = canv_tile_tex.region
#				pixel_color = atlas_img.get_pixel(canv_tile_coord.position.x, canv_tile_coord.position.y)
#			#print(canv_tile_coord)
#
#			if pixel_color:
#
#				temp_image.set_pixelv(cell, pixel_color)
#				print("set pixel at " + str(cell) + " to color " + pixel_color.to_html())
#
#			else:
#				print("no mod chalk found, sorry")
#		temp_image.save_png("user://ChromaChalk_images/canvas_" + str(int(rand_range(0.0, 100000.0))) + ".png")
#		temp_image.unlock()
#		atlas_img.unlock()
#
#	if is_self == true and message.begins_with("!hash"):
#		var hash_debug_thread = Thread.new()
#
#		var debug_hash = var2bytes("bepis")
#		print("created debug hash: " + debug_hash.hex_encode())
#
#		hash_debug_thread.start(self, "compute_hash", debug_hash)
#		var hashed = hash_debug_thread.wait_to_finish()
#
#		print("hashed data: " + str(hashed.hex_encode()))
#
#
#func add_color_data(color_data):
#
##	var single = false
##
##	if tile_thread and tile_thread.is_active():
##		print("A tile creation process is already running. Ignoring new request.")
##		return
##
##	if color_data.get("pixels").size() == 1:
##		var color_hex = color_data.get("pixels")[0].to_html(false) #eww
##
##		print("this is for checking old colors. color received: " + color_hex + " , is it in dict? ")
##		if color_hex in color_dict:
##			selected_color_id = color_dict.get(color_hex)
##
##		else:
##			single = true
##
##	print("Starting background thread to process colors and tileset...")
##	tile_thread = Thread.new()
##	var thread_data = {
##		"pixels": color_data.get("pixels"),
##		"existing_colors": color_dict.duplicate(),
##		"loader_path": color_data.get("loader_path"),
##		"tilemap_path": color_data.get("tilemap_path"),
##		"tileset_duplicate": canvas_TileSet.duplicate(),
##		"atlas_img_duplicate": atlas_img.duplicate(),
##		"current_color_slot": color_slot,
##		"single": single
##	}
##	tile_thread.start(self, "_thread_process_new_colors", thread_data)
##	print("did the process color thread start? " + str(tile_thread.is_alive()))
#	pass

#func python_process_data(py_color_slot, lookup_img_poolbytes, new_rects):
#	print("this is the new color slot woah: " + str(py_color_slot))
#
#	var new_atlas_img = Image.new()
#	new_atlas_img.lock()
#	new_atlas_img.create_from_data(512, 512, false, Image.FORMAT_RGB8, lookup_img_poolbytes)
#	new_atlas_img.save_png("user://test.png")
#
#	atlas_img.lock()
#	atlas_img = new_atlas_img
#	atlas_tex.set_data(atlas_img)
#	atlas_img.save_png("user://post_update.png")
#
#	new_atlas_img.unlock()
#
#	var color_slot_steps = range(color_slot, py_color_slot + 1) #we start at 7, right?
#
#	for new_tile_id in color_slot_steps:
#		#print("creating new tile, id number: " + str(new_tile_id))
#		current_tileset.create_tile(new_tile_id)
#		current_tileset.tile_set_texture(new_tile_id, atlas_tex)
#		current_tileset.tile_set_region(new_tile_id, new_rects[color_slot - new_tile_id]) #totally bestest way to grab the rectangles
#
#	color_slot = py_color_slot
#
#	emit_signal("tileset_update", current_tileset)
#	#print("maybe some new rectangles should have arrived :3 " + str(new_rects))
#
##	for test in uint8_color_array:
##		print("this is MAYBE an array " + test.to_html())
#	#print("WOAH THIS IS THE NEW COLORS IN A BUNCH OF NUMBERS: " + str(uint8_color_array))
#	#print("OHHH HOLY THIS IS THE LOOKUP IMG POOLBYTES!!!: " + str(lookup_img_poolbytes))
#
#
##func _thread_process_new_colors(data: Dictionary):
##	var pixels: Array = data.get("pixels")
##	var existing_colors_dict: Dictionary = data.get("existing_colors")
##	var existing_colors_keys: Array = existing_colors_dict.keys()
##	var loader_path = data.get("loader_path")
##	var tilemap_path = data.get("tilemap_path")
##	var tileset_duplicate: TileSet = data.get("tileset_duplicate")
##	var atlas_img_duplicate: Image = data.get("atlas_img_duplicate")
##	var current_color_slot: int = data.get("current_color_slot")
##	var single = data.get("single")
##
##	var new_color_remap: Dictionary = {}
##	var unique_new_colors = []
##	var seen_colors = {}
##	var results
##
##	if pixels.size() == 1:
##		print("pixel array size is only 1, checking if we already created color to set it")
##		var color_hex = pixels[0].to_html(false)
##		if color_hex in existing_colors_dict:
##			print("the received color already exists, we can skip the creation process. passing old ID")
##			print("old color id is: " + str(existing_colors_dict.get(color_hex)))
##			results = {"color_id": existing_colors_dict.get(color_hex)}
##			#atlas_img.unlock()
##			call_deferred("_apply_thread_results", results)
##			return
##
##	for color_html in existing_colors_keys:
##		seen_colors[color_html] = true
##
##	for pixel_color in pixels:
##		var color_html = pixel_color.to_html(false)
##		if not seen_colors.has(color_html):
##			seen_colors[color_html] = true
##			unique_new_colors.append(pixel_color)
##
##	var new_color_map = {}
##	if not unique_new_colors.empty():
##		print("Thread: processing %d new colors." % unique_new_colors.size())
##		atlas_img_duplicate.lock()
##		var image_size = 512
##
##		for color in unique_new_colors:
##			var color_x = current_color_slot % image_size
##			var color_y = int(current_color_slot / image_size)
##
##			atlas_img_duplicate.set_pixel(color_x, color_y, color)
##
##
##			# NOTE: The atlas texture itself can't be passed to the thread, 
##			# so we create a placeholder. It will be reassigned on the main thread.
##			var region = Rect2(color_x, color_y, 1, 1)
##
##			var new_tile_id = tileset_duplicate.get_last_unused_tile_id()
##			tileset_duplicate.create_tile(new_tile_id)
##
##			var color_string = color.to_html(false)
##			tileset_duplicate.tile_set_name(new_tile_id, color_string)
##			tileset_duplicate.tile_set_texture(new_tile_id, atlas_tex)
##			tileset_duplicate.tile_set_region(new_tile_id, region)
##
##			new_color_map[color_string] = new_tile_id
##			new_color_remap[new_tile_id] = color_string
##			current_color_slot += 1
##
##			results = {
##				"new_tileset": tileset_duplicate,
##				"new_atlas_img": atlas_img_duplicate,
##				"new_color_map": new_color_map,
##				"new_color_remap": new_color_remap,
##				"new_color_slot": current_color_slot,
##				"loader_path": loader_path,
##				"tilemap_path": tilemap_path,
##				"single": single
##			}
##
##	else:
##		print("no new colors found, setting drawing color to known color")
##
##
##
##	atlas_img_duplicate.unlock()
##
##
##	call_deferred("_apply_thread_results", results)

#func _apply_thread_results(results: Dictionary):
#	print("Applying thread results to main game...")
#
#	var color_id = results.get("color_id")
#
#	if results.size() == 1: #because there is no new data, right?
#		print("theres no data but color id, setting drawing color")
#		selected_color_id = color_id
#		if tile_thread and tile_thread.is_active():
#			tile_thread.wait_to_finish()
#		return
#
#
#	var new_tileset = results.get("new_tileset")
#	var new_atlas_img = results.get("new_atlas_img")
#	var new_color_map = results.get("new_color_map")
#	var new_color_remap = results.get("new_color_remap")
#	var new_color_slot = results.get("new_color_slot")
#	var loader_path = results.get("loader_path")
#	var tilemap_path = results.get("tilemap_path")
#	var single = results.get("single")
#
#	# Re-assign the atlas texture to all new tiles on the main thread
#	for color_string in new_color_map:
#		var tile_id = new_color_map[color_string]
#		var atlas_tex_instance = new_tileset.tile_get_texture(tile_id) as AtlasTexture
#		if atlas_tex_instance:
#			atlas_tex_instance.atlas = self.atlas_tex
#
#	# send out the new tileset
#	current_tileset = new_tileset
#
#	emit_signal("tileset_update", current_tileset)
#	self.canvas_TileSet = new_tileset # Also update old reference
#	self.atlas_img = new_atlas_img
#	self.atlas_tex.set_data(self.atlas_img)
#	self.color_dict.merge(new_color_map, true)
#	self.color_dict_remap.merge(new_color_remap)
#	self.color_slot = new_color_slot
#
#	if single == true:
#		selected_color_id = color_slot + 6
#	#Lure_chalk_resource.action_params[1] = color_slot #this is a quick and dirty hack, the chalk is buggy as shit anyways
#
#	print("Finished applying results.")
#
#	if not new_color_map.empty():
#		var color_poolbytes = var2bytes(["create_new_color", new_color_map, protocol_version])
#		for player in mod_user_list:
#			Steam.sendMessageToUser(player, color_poolbytes, send_type.RELIABLE, COLOR_CHANNEL)
#
#	if loader_path:
#		var loader_logic = get_node_or_null(loader_path)
#		if loader_logic and tilemap_path:
#			loader_logic.actually_paint_tiles_on_map(tilemap_path)
#		else:
#			print("ERROR: Could not find loader_logic at path: " + loader_path)
#
#	if tile_thread and tile_thread.is_active():
#		tile_thread.wait_to_finish()
#		print("Process finished and thread cleaned up.")

#func dicttest(dict):
#	#for step in dict:
#		#print(str(step))
#	pass
#
#func lobby_joined():
#	var color_handshake = "hello_lobby_i_just_joined"
#	var hello_poolbyte = var2bytes(["color_handshake", color_handshake, protocol_version])
#	for connection_entry in Network.OPEN_CONNECTIONS:
#		var steam_id = connection_entry
#		print("OHELLO DO YOU HAVE A MOD WITH STEAM ID " + str(steam_id))
#		Steam.sendMessageToUser(str(steam_id), hello_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
#
#func request_img():
#	if mod_user_list.size() >= 1:
#		yield(get_tree().create_timer(0.5), "timeout")
#		var request_poolbyte = var2bytes(["requesting_img", "pls_send_img", protocol_version])
#		Steam.sendMessageToUser(mod_user_list[0], request_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
#
#func player_removed(player_node):
#	if player_node.owner_id in mod_user_list:
#		mod_user_list.erase(player_node.owner_id)
#	elif player_node.owner_id == Network.STEAM_ID:
#		clear_color()
#
#func clear_color():
#	atlas_img.lock()
#	atlas_img.fill(Color.transparent)
#	atlas_img.unlock()
#	atlas_tex.create_from_image(atlas_img)
#	color_slot = 0
#
#	for tile in color_dict.keys():
#		canvas_TileSet.remove_tile(color_dict.get(tile))
#
#	color_dict = {}
#	mod_user_list = []

func compute_hash(hash_data) -> PoolByteArray:
	var hash_compute = HashingContext.new()
	hash_compute.start(HashingContext.HASH_MD5)
	hash_compute.update(hash_data)
	return hash_compute.finish()
	
#func send_img(steam_id): 
#	# compressed poolbytes content:
#	# 0 = image poolbytes
#	# 1 = image poolbytes hash
#	# 2 = color dict
#	# 3 = color slot counter
#	atlas_img.lock()
#	var img_poolbytes = atlas_img.get_data() #sending a whole image over steam lets go
#	atlas_img.unlock()
#	var img_poolbytes_hash = compute_hash(img_poolbytes)
#
#	var combined_data_poolbytes = var2bytes([img_poolbytes, img_poolbytes_hash, color_dict, color_slot])
#	var combined_data_size = combined_data_poolbytes.size()
#	var compressed_data_poolbytes = combined_data_poolbytes.compress(File.COMPRESSION_ZSTD) #ZStandart compression because why not, i didnt try it
#	var final_poolbytes = var2bytes(["receive_img", compressed_data_poolbytes, protocol_version, combined_data_size]) 
#	#what a poolbyte orgy, but i hope this is good enough for initial sync
#	Steam.sendMessageToUser(steam_id, final_poolbytes, send_type.RELIABLE, COLOR_CHANNEL)
	
	
#func recreate_img(decompressed_data_poolbytes):
#
#	var packet_img_hash = decompressed_data_poolbytes[1]
#	var img_data = decompressed_data_poolbytes[0]
#	var recalculated_hash = compute_hash(img_data)
#
#	if recalculated_hash != packet_img_hash:
#		print("The locally calculated hash and the one in the packet dont match! panic!")
#		return
#	else:
#		var network_img: Image = Image.new()
#		atlas_img.lock()
#		network_img.lock()
#		atlas_img = network_img.create_from_data(512, 512, false, Image.FORMAT_RGBA8, img_data)
#		atlas_tex.set_data(atlas_img)
#		print("we did the image setting update woo")
	
	
func read_packets():
	print("packet thread started")
	while true:
		packet_semaphore.wait()
		packet_mutex.lock()
		var message_array = Steam.receiveMessagesOnChannel(COLOR_CHANNEL, 50) #reading for 50 messages
		packet_mutex.unlock()
		
		if message_array.empty() == true:
			#print("Steam Message Array is empty. Continuing.")
			continue
		
		for message in message_array:
			
			# Networking is such an awful mess. There's always something broken about the packets,
			# so i'm gonna be extremely defensive about it. hopefully it running on a seperate thread helps!
			

				
			if typeof(message_array) != TYPE_ARRAY:
				print("Steam Message Array is malformed. Discarding.")
				continue
			
			elif typeof(message) != TYPE_DICTIONARY:
				print("Message isn't a dict. Discarding.")
				continue
				
			elif typeof(message.get("identity")) != TYPE_STRING or message.get("identity") == null:
				print("Identity string is broken. Discarding.")
				continue

			var sender_steam_id = message.get("identity").get_slice(":", 1)
			var decoded = bytes2var(message.get("payload"))
			
#			if 
			
			if typeof(decoded) != TYPE_ARRAY:
				print("Decoded payload isn't an array. Discarding.")
				continue
			
			if decoded.size() < 3 or decoded[2] != protocol_version:
				print("Discarding packet with wrong protocol version.")
				continue
				

			var packet_command = decoded[0]
			
			
			if decoded[0] == null or typeof(decoded[0]) != TYPE_STRING:
				print("No proper command received in packet. Discarding.")
				continue
				
				
			match packet_command:
				"color_handshake":
					var response_poolbyte = var2bytes(["handshake_response", "hello_back", protocol_version])
					packet_mutex.lock()
					if not sender_steam_id in mod_user_list:
						mod_user_list.call_deferred("append", sender_steam_id)
					packet_mutex.unlock()
					Steam.call_deferred("sendMessageToUser", sender_steam_id, response_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
				
				"handshake_response":
					packet_mutex.lock()
					if not sender_steam_id in mod_user_list:
						mod_user_list.call_deferred("append", sender_steam_id)
					packet_mutex.unlock()
					call_deferred("request_img")
				
				"requesting_img":
						call_deferred("send_img", sender_steam_id)
						
				"receive_img":
					var compressed_data_poolbytes: PoolByteArray = decoded[1]
					var uncompressed_size = decoded[3]
					var decompressed_data_poolbytes = compressed_data_poolbytes.decompress(uncompressed_size, File.COMPRESSION_ZSTD)
					var received_dict = decompressed_data_poolbytes[2]
					var new_colors_from_net = []
					for color_string in received_dict.keys():
						if not color_dict.has(color_string):
							new_colors_from_net.append(Color(color_string))
					if not new_colors_from_net.empty():
						call_deferred("_apply_thread_results", {"new_color_map": received_dict})
					
					#call_deferred("recreate_img", decompressed_data_poolbytes)
					
				#				"requested_dict":
#					var dict_poolbyte = var2bytes(["received_dict", color_dict, protocol_version])
#					Steam.call_deferred("sendMessageToUser", sender_steam_id, dict_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
#
#				"received_dict":




				"create_new_color":
					var remote_color_dict = decoded[1]
					var new_colors_from_net = []
					for color_string in remote_color_dict.keys():
						if not color_dict.has(color_string):
							new_colors_from_net.append(Color(color_string))
					if not new_colors_from_net.empty():
						call_deferred("_apply_thread_results", {"new_color_map": remote_color_dict})
						

						
				"":
					pass
