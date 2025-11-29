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
