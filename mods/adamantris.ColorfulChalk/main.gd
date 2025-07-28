extends Node

signal picker_visible

export var color_id: Dictionary

enum send_type{
	RELIABLE = 8,
	UNRELIABLE = 0,
	UNRELIABLE_FAST = 4,
}

const COLOR_CHANNEL = 10
const protocol_version = 4

onready var Lure = get_node("/root/SulayreLure")
onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")


onready var color_picker = preload("res://mods/adamantris.ColorfulChalk/scenes/color_picker.tscn")
#onready var chalk = preload("res://mods/adamantris.ColorfulChalk/RGB_chalk.tres")

var canvas_TileMap: TileMap
var canvas_TileSet: TileSet
var color_dict: Dictionary = {}
var selected_chalk_color
var Lure_chalk_dict
var Lure_chalk_resource

var mod_user_list = []



var packet_timer: float = 0.0
var packet_thread: Thread
var packet_semaphore: Semaphore #first attempt at multithreading im suuuuuuuure everything will be fine :3
var packet_mutex: Mutex
var kill_threads = false

var color_thread: Thread
var color_mutex: Mutex

var tile_thread: Thread
var tile_mutex: Mutex

var global_color_string: String = "#ff0000ff"
export onready var img_data

export onready var atlas_img: Image
export onready var atlas_tex: ImageTexture
var color_slot = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	yield(get_tree().create_timer(1.0), "timeout")
	
	
	#look a friend managed to get me sidetracked on creating an image saving function, so now i need a folder too
	var file_manager = Directory.new()
	if file_manager.dir_exists("user://colorfulchalk_images") == false:
		
		print("yeh the images folder doesnt exist, making new folder")
		file_manager.make_dir("user://colorfulchalk_images")
		
	else:
		print("the img folder exists, passing")
		pass
	
	print("file manager did its job, clearing")
	get_tree().queue_delete(file_manager)
	
	
	
	Chat.connect("player_messaged", self, "chat_command")
	Players.connect("ingame", self, "ingame")
	Players.connect("player_removed", self, "player_removed")
	Lure.add_content("adamantris.ColorfulChalk", "Rainbow Chalk", "res://mods/adamantris.ColorfulChalk/resources/chalk_rainbow.tres", [Lure.LURE_FLAGS.FREE_UNLOCK])
	
	atlas_img = Image.new()
	atlas_img.create(512, 512, false, Image.FORMAT_RGBA8)
	
	atlas_tex = ImageTexture.new()
	atlas_tex.create_from_image(atlas_img)
	atlas_tex.flags += Texture.FLAG_CONVERT_TO_LINEAR
	
	#this key is just temporary, ill think of a better solution along the way (maybe)
	InputMap.add_action("toggle_picker")
	var keyevent = InputEventKey.new()
	keyevent.scancode = KEY_P
	InputMap.action_add_event("toggle_picker", keyevent)
	
	
	packet_semaphore = Semaphore.new()
	packet_mutex = Mutex.new()
	packet_thread = Thread.new()
	packet_thread.start(self, "read_packets")
	
	if packet_thread.is_active() == true:
		print("yippee the thread has started")
	elif packet_thread.is_active() == false:
		print("oh no the thread isnt running")
	
	
	
	#string_to_color(color_string)
	pass # Replace with function body.
	
func _process(delta):
	
	if Players.in_game == false:
		return
	
	elif packet_timer >= 0.2:
		#print("about to post the semaphore")
		packet_semaphore.post()
		packet_timer = 0.0
		
	else:
		packet_timer += delta
		
		
func _input(event):
	if Input.is_action_just_pressed("toggle_picker") and Players.local_player.busy == false:
		emit_signal("picker_visible")

func ingame(): #to get the tilemap, gotta add dynamically after all or the whole world explodes
	Lure_chalk_dict = Lure.item_list.get("adamantris.ColorfulChalk.Rainbow Chalk")
	Lure_chalk_resource = Lure_chalk_dict.get("resource")
	PlayerData._send_notification("this is a test message, please ignore")
	lobby_joined()
	
	
	print(str(Lure_chalk_resource))
	canvas_TileMap = get_node("/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap")
	canvas_TileSet = canvas_TileMap.get_tileset()
	print(str(canvas_TileMap))
	
	self.add_child(color_picker.instance())

func chat_command(message: String, player, is_self):
	if is_self == true and (message.begins_with("!color") or message.begins_with("!colour")): #i added "colour" by request for a friend they wanted !colour lol
		print("check passed")
		
		var new_color_received = message.get_slice(" ", 1)
		print("new color slice: " + new_color_received)
		
		var processed_color = "#ff" + new_color_received
		print("made correct with alpha: " + processed_color)
		
		if processed_color.length() == 9 and processed_color.countn("#") == 1: #a small check so people dont put whateverthefuck into the color tileset
		
			if processed_color in color_dict.keys():
				print("color already been created once, setting to existing tile id")
				selected_chalk_color = color_dict.get(processed_color)
				Lure_chalk_resource.action_params[1] = selected_chalk_color
				
			else:
				global_color_string = processed_color
				add_color_data(processed_color.to_lower())
			
			
			
	#		emit_signal("chalk_color_changed")
	#		print("emittin chalk color change signal :>")
		else:
			print("uh oh, the color string is in a wrong format! discarding...")
			PlayerData._send_notification("you entered an invalid code! use 6 letters/numbers, without #", 1)
			
			
	if is_self == true and message.begins_with("!debug_save"):
		atlas_img.save_png("user://test.png")
		print("hopefully saved a png lol")
	
	
	#this is experimental, i just wanna see if its possible
	if is_self == true and message.begins_with("!save"):
		
		var canv_id = message.get_slice(" ", 1)
		
		if not int(canv_id) in [1, 2, 3, 4]:
			print("im yelling at u you there are only 4 chalk spots")
			PlayerData._send_notification("invalid canvas ID, only numbers between 1 and 4 are valid", 1)
			return
		
		var canv_paths = {
			"1": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap",
			"2": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas2/Viewport/TileMap",
			"3": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas3/Viewport/TileMap",
			"4": "/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas4/Viewport/TileMap"
		}
		
		var canv_tilemap_node = get_node(canv_paths.get(canv_id))
		var canv_tileset_node = canv_tilemap_node.get_tileset()
		
		atlas_img.lock()
		var tileset_cells = canv_tilemap_node.get_used_cells()
		
		var temp_image = Image.new()
		temp_image.create(200, 200, false, Image.FORMAT_RGBA8)
		
		temp_image.lock()
		#print("this is the tileset cells used (vec2 array): " + str(tileset_cells))
		#temp_image.lock()
		
		
		for cell in tileset_cells:
			#print(str(canvas_TileMap.get_cellv(cell)))
			var canv_tile_tex = canvas_TileSet.tile_get_texture(canv_tilemap_node.get_cellv(cell))
			
			var pixel_color
			#print(canv_tile_tex)
			#print(str(canv_tile_tex))
			if !(canv_tile_tex is AtlasTexture):
				print("this is vanilla chalk, passing")
				pass
			if canv_tile_tex is AtlasTexture:
				var canv_tile_coord = canv_tile_tex.region
				pixel_color = atlas_img.get_pixel(canv_tile_coord.position.x, canv_tile_coord.position.y)
			#print(canv_tile_coord)
			
			if pixel_color:
			
				temp_image.set_pixelv(cell, pixel_color)
				print("set pixel at " + str(cell) + " to color " + pixel_color.to_html())
				
			else:
				print("no mod chalk found, sorry")
		temp_image.save_png("user://colorfulchalk_images/canvas_" + str(int(rand_range(0.0, 100000.0))) + ".png")
		temp_image.unlock()
		atlas_img.unlock()
		
	if is_self == true and message.begins_with("!hash"):
		var hash_debug_thread = Thread.new()
		
		var debug_hash = var2bytes("bepis")
		print("created debug hash: " + debug_hash.hex_encode())
		
		hash_debug_thread.start(self, "compute_hash", debug_hash)
		var hashed = hash_debug_thread.wait_to_finish()
		
		print("hashed data: " + str(hashed.hex_encode()))


#func string_to_color(color_string: String, tile_id: int = -1):
	
#	global_color_string = color_string
#	print(typeof(color_string))
#	print("got passed a string, creating color")
#	#yield(get_tree().create_timer(1.0), "timeout")
#	var color = Color(global_color_string)
#	create_new_tile(color, tile_id)
#
#	PlayerData._send_notification("created color #" + color_string.trim_prefix("#ff"))
#
#	print(color.a8)
#



func thread_create_new_tile(color_data) -> Array: #multithreading is dumb its hard :(
	
	var tile_mutex = Mutex.new()
	#PRODUCT ARRAY:
	#array[0] is a dict of color-ID pairs
	#array[1] is the modified atlas image duplicate
	#array[2] is the created atlas textures in an array
	#array[3] is the regions for the atlas texture
	#array[4] is the updated color incremental
	#array[5] is wether to send a steam message about creating new colors
	#array[-1] is my will to live because holy shit is thread safety a beast
	
	
	
	var do_send = false
	var id = -1
	
	
	
	tile_mutex.lock()
#	var new_color_array = color_array[0]
#	var id = color_array[1]
	var canv_tileset = canvas_TileSet
	var old_color_dict_duplicate = color_dict.duplicate()
	var colors: Array
	var atlas_img_duplicate = atlas_img.duplicate()
	var atlas_tex_ref = atlas_tex
	var atlas_tex_collection = []
	var atlas_regs = []
	var product_array = []
#	var flags = atlas_tex_duplicate.get_flags()
	var color_slot_duplicate = color_slot
	var temp_dict = {}
	tile_mutex.unlock()
	
	
	if typeof(color_data) == TYPE_STRING:
		tile_mutex.lock()
		temp_dict[color_data] = canv_tileset.get_last_unused_tile_id()
		product_array.append(temp_dict)
		print("its a string! " + str(temp_dict))
		do_send = true
		tile_mutex.unlock()
	
	elif typeof(color_data) == TYPE_DICTIONARY:
		tile_mutex.lock()
		temp_dict = color_data
		print("its a dictionary! " + str(temp_dict))
		product_array.append(color_data)
			
		tile_mutex.unlock()
		
	else:
		print("PANIC AAAAA HELP ITS NEITHER A STRING OR A DICT")


	
	
	var atlas_size = 512 #i hate this but this way godot has less resources to care about which is important in webfibby i think, at least my mod created some lag in tester art
	

	
	var color_x = color_slot_duplicate % atlas_size #literally first time i found use for modulo, make it wrap around
	var color_y = int(color_slot_duplicate / atlas_size) #we dont want stinky decimal points
	
#	flags += Texture.FLAG_CONVERT_TO_LINEAR
	
	atlas_img_duplicate.lock()
	
	for temp_entry in temp_dict.keys():
		atlas_img_duplicate.set_pixel(color_x, color_y, Color(temp_entry))
#		print("hey i set a pixel on the duplicate, at " + str(color_x) + ", " + str(color_y) + ", and the color string is " + temp_entry)
#
#		tile_mutex.lock()
#		var atlas_final = AtlasTexture.new()
#		atlas_final.region = Rect2(color_x, color_y, 1, 1)
#		atlas_regs.append(Rect2(color_x, color_y, 1, 1)) #create a texture out of the given position, with a size of 1x1
#		atlas_tex_collection.append(atlas_final)
#		color_slot_duplicate += 1
#		print("incremented color slot duplicate, new value: " + str(color_slot_duplicate))
#		print("currently set pixel color: " + atlas_img_duplicate.get_pixel(color_x, color_y).to_html())
#		tile_mutex.unlock()
		
	product_array.append(atlas_img_duplicate) #1
	product_array.append(0)#atlas_tex_collection) #2
	product_array.append(0)#atlas_regs) #3
	product_array.append(0)#color_slot_duplicate) #4
	product_array.append(do_send) #5
	
	print("this is the whole product array: " + str(product_array))
	atlas_img_duplicate.unlock()
	
#	
	
	
	return product_array
#	print("AAAAA hopefully a new tile has been created: " + str(canvas_TileSet.tile_get_name(tileset_id)) + " " + str(canvas_TileSet.tile_get_texture(tileset_id)))
	
	
func add_color_data(color_data):
	tile_thread = Thread.new()
	tile_thread.start(self, "thread_create_new_tile", color_data)
	var result = tile_thread.wait_to_finish()
	print("this is the result var in add_color_data, after waiting for the thread to sudoku: " + str(result))
	finish_tile_stuff(result)
	#PRODUCT ARRAY:
	#array[0] is a dict of color-ID pairs
	#array[1] is the modified atlas image duplicate
	#array[2] is the created atlas textures in an array
	#array[3] is the regions for the atlas texture
	#array[4] is the updated slot incremental
	#array[5] is wether to send a steam message about creating new colors
	#array[-1] is my will to live because holy shit is thread safety a beast
	
	
func finish_tile_stuff(processed_color_data):
	var color_id = processed_color_data[0]
	var mod_atlas_img = processed_color_data[1]
	#var atlas_tex_collection = processed_color_data[2]
	#var atlas_regs = processed_color_data[3]
	#var new_color_slot = processed_color_data[4]
	var should_send = processed_color_data[5]
	
	color_dict.merge(color_id)
	
	atlas_img.copy_from(mod_atlas_img)
	
	atlas_tex.set_data(atlas_img)
	
	
	var temp_id_array = []
#	for id_entry in color_id.keys():
#		var id = color_id.get(id_entry)
#		canvas_TileSet.create_tile(id)
#		canvas_TileSet.tile_set_name(id, id_entry)
#		temp_id_array.append(id)
		
		
		

	for id_entry in color_id.keys():
		
		var id = color_id.get(id_entry)
		var image_size = 512
		var color_x = color_slot % image_size
		var color_y = int(color_slot / image_size)
		
		
		var atlas_tex_new = AtlasTexture.new()
		atlas_tex_new.atlas = atlas_tex
		atlas_tex_new.region = Rect2(color_x, color_y, 1, 1)
		
		color_slot += 1
		
		canvas_TileSet.create_tile(id)
		canvas_TileSet.tile_set_name(id, id_entry)
		canvas_TileSet.tile_set_texture(id, atlas_tex_new)
		
		selected_chalk_color = id
		
	color_dict.merge(color_id)
		
	#color_slot = new_color_slot
	
	if should_send == true:
		print("should send, shooting players a steam network message :)")
		
		var color_poolbytes = var2bytes(["create_new_color", color_id, protocol_version])
		
		for player in mod_user_list:
			Steam.sendMessageToUser(player, color_poolbytes, send_type.RELIABLE, COLOR_CHANNEL)
	
#	canvas_TileSet.create_tile(tileset_id)
#	canvas_TileSet.tile_set_name(tileset_id, global_color_string)
#	canvas_TileSet.tile_set_texture(tileset_id, atlas_final)
	Lure_chalk_resource.action_params[1] = selected_chalk_color

func lobby_joined():
	var color_handshake = "hello_lobby_i_just_joined"
	
	var hello_poolbyte = var2bytes(["color_handshake", color_handshake, protocol_version])
	print("attempting to send a hello")
	for connection_entry in Network.OPEN_CONNECTIONS:
		var steam_id = connection_entry
		Steam.sendMessageToUser(str(steam_id), hello_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
		print("heyyy i sent a hello to " + str(steam_id))
		
		
func request_dict():
	if mod_user_list.size() >= 1:
		yield(get_tree().create_timer(0.5), "timeout") #waiting a lil bit for the dict to populate
		var request_poolbyte = var2bytes(["requested_dict", "pls send dict i want to see colors", protocol_version])
		
		Steam.sendMessageToUser(mod_user_list[0], request_poolbyte, send_type.RELIABLE, COLOR_CHANNEL) #asking the first available user for already created colors
	
	else:
		pass
		

func player_removed(player_node):
	
	if player_node.owner_id in mod_user_list:
		mod_user_list.erase(player_node.owner_id)
		print("a player left, removing id: " + str(player_node.owner_id))
		
	elif player_node.owner_id == Network.STEAM_ID: #it took me too long to implement dict clearing lol im lazy
		print("you left, emptying player list, removing created tiles and color dict")
		clear_color()

func clear_color():
	atlas_img.lock()
	atlas_img.fill(Color("#00000000")) #a nice blank slate
	atlas_tex.set_data(atlas_img)
	atlas_img.unlock()
	color_slot = 0
	
	for tile in color_dict.keys():
		canvas_TileSet.remove_tile(color_dict.get(tile))
	
	print("tried to remove tiles, tiles left: " + str(canvas_TileSet.get_tiles_ids()))
	
	color_dict = {}
	mod_user_list = []

func compute_hash(hash_data) -> PoolByteArray: #i dont even know why the fuck this is necessary but it always desyncs so im angy
	var hash_compute = HashingContext.new()
	hash_compute.start(HashingContext.HASH_MD5)
	hash_compute.update(hash_data)
	
	var hashed_data = hash_compute.finish()
	
	print("just computed a hash, hex representation: " + hashed_data.hex_encode())
	return hashed_data
	
#behold, my network code of shame

func read_packets():
	packet_thread = Thread.new()
	while true:
		packet_semaphore.wait()
		#print("semaphore post, processing network packets")
		
		var valid_commands = ["color_handshake", "handshake_response", "create_new_color", "requested_dict", "received_dict"] #this is stupid but maybe it works
		
		packet_mutex.lock()
		var message_array = Steam.receiveMessagesOnChannel(COLOR_CHANNEL, 10) 
		packet_mutex.unlock()
		#REMEMBER: dec[0] is command, dec[1] is payload data, dec[2] is prot version, dec[3] is a hash of something, whenever you need it
		#print(str(message_array.size()))
		
		#print("rolling over packets now")
		for message in message_array:
			var decoded = bytes2var(message.get("payload"))
			var packet_command = decoded[0]
			
			#the identity steam ID gets sent like "steamid:[ID]", i think thats weird ngl
			var sender = message.get("identity")
			var sender_steam_id = sender.get_slice(":", 1)
##			global_sid = sender_steam_id
			
			if decoded[2] != protocol_version:
				print("wrong protocol version, discarding")
				PlayerData._send_notification("you received a packet with a mismatching protocol version, either you or the other person should update their mod.")
			
			elif not decoded[0] in valid_commands:
				print("received garbage data, passing")
				PlayerData._send_notification("you received a packet filled with garbage, please tell ferrum - " + str(decoded))
				

				
			elif decoded[0] in valid_commands and decoded[2] == protocol_version:
				match packet_command:
					
					"color_handshake":
						var response_poolbyte = var2bytes(["handshake_response", "hello_back", protocol_version])
						#adding responding players to an array, i dont want to round-robin packets to all players constantly
						print("received a handshake, responding and adding to player list")
						
						packet_mutex.lock()
						mod_user_list.append(sender_steam_id)
						packet_mutex.unlock()

						#Steam.sendMessageToUser(sender_steam_id, response_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
						Steam.call_deferred("sendMessageToUser", sender_steam_id, response_poolbyte, send_type.RELIABLE)
						
						
					"handshake_response":
						print("received a response, stuffing player " + sender_steam_id + " into mod user list")
						packet_mutex.lock()
						mod_user_list.append(sender_steam_id)
						packet_mutex.unlock()
						
						print("asking first available player for the color dict")
						request_dict()
						
					"requested_dict":
						print("received a request for the color dict, sending it since theyre asking so nicely")
						
						var hash_thread = Thread.new()
						var atlas_bytes = atlas_img.save_png_to_buffer()
						hash_thread.start(self, "compute_hash", atlas_bytes)
						var atlas_hash = hash_thread.wait_to_finish()
						var dict_poolbyte = var2bytes(["received_dict", color_dict, protocol_version, atlas_hash])
						#Steam.sendMessageToUser(sender_steam_id, dict_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
						Steam.call_deferred("sendMessageToUser", sender_steam_id, dict_poolbyte, send_type.RELIABLE, atlas_hash)
						
					"received_dict":
						print("received a color dict, turning into colors")
						
						for color_string in decoded[1].keys():
							print(color_string)
							if typeof(color_string) == TYPE_STRING and color_string.length() == 9:
								
								call_deferred("string_to_color", color_string, decoded[1].get(color_string))
								#string_to_color(color_string, decoded[1].get(color_string))
								
							else:
								print("hey something went wrong with the received dict, this is the type of one entry: " + str(typeof(color_string)))
								PlayerData._send_notification("something went wrong in recreating the old colors of a player, yell at ferrum and show them this: " + str(typeof(color_string)) + " " + str(color_string))
								
						
						var hash_thread = Thread.new()
						var atlas_bytes = atlas_img.save_png_to_buffer()
						hash_thread.start(self, "compute_hash", atlas_bytes)
						var local_atlas_hash = hash_thread.wait_to_finish()
						
						if local_atlas_hash == decoded[3]:
							print("the hashes are matching, carrying on :)")
							
						else:
							print("the hecc the hashes arent matching, re-requesting atlas")
							PlayerData._send_notification("yell at ferrum that the generated colors sent by another player arent matching with the ones you got saved pls", 1)
							
							call_deferred("clear_color")
							#clear_color()
							
							call_deferred("request_dict")
							
						
						
						print(str(decoded[1]) + str(typeof(decoded[1])))
						
	#					if color_dict.empty():
	#						for color_entry in decoded[1]:
	#							print("section out of received packet from handshake: " + str(color_entry) + " " + str(typeof(color_entry)))
	#							if typeof(color_entry) != TYPE_STRING:
	#								print("invalid variant type, want strin, but getting " + str(color_entry))
	#								PlayerData._send_notification("yell this at ferrum pls: " + str(color_entry))
	#
	#							else:
	#								print("should have received a string " + color_entry)
	#								var dict_color = Color(color_entry)
	#								create_new_tile(dict_color)
	#
	#					else:
	#						pass
							
					"create_new_color":
						print("someone created a new color, passing on to create_new_tile")
						
						atlas_img.lock()
						var remote_color_dict = decoded[1]
						atlas_img.unlock()
						
						call_deferred("add_color_data", remote_color_dict) #string first, then ID

					_:
						return
				
			else:
				print("something went *very* wrong in packet command validation")
				PlayerData._send_notification("yell at ferrum that the mod couldnt read a packet")
			

