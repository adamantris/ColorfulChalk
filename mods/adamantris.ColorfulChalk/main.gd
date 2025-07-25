extends Node

signal picker_visible

enum send_type{
	RELIABLE = 8,
	UNRELIABLE = 0,
	UNRELIABLE_FAST = 4,
}

const COLOR_CHANNEL = 10
const protocol_version = 3

onready var Lure = get_node("/root/SulayreLure")
onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")


onready var color_picker = preload("res://mods/adamantris.ColorfulChalk/scenes/color_picker.tscn")
#onready var chalk = preload("res://mods/adamantris.ColorfulChalk/RGB_chalk.tres")

var canvas_TileSet
var color_dict: Dictionary = {}
var selected_chalk_color
var Lure_chalk_dict
var Lure_chalk_resource

var mod_user_list = []

var packet_timer: float = 0.0

var global_color_string: String = "#ff0000ff"
export onready var img_data

export onready var atlas_img: Image
export onready var atlas_tex: ImageTexture
var color_slot = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	yield(get_tree().create_timer(1.0), "timeout")
	Chat.connect("player_messaged", self, "set_color")
	Players.connect("ingame", self, "ingame")
	Players.connect("player_removed", self, "player_removed")
	Lure.add_content("adamantris.ColorfulChalk", "Rainbow Chalk", "res://mods/adamantris.ColorfulChalk/chalk_rainbow.tres", [Lure.LURE_FLAGS.FREE_UNLOCK])
	
	atlas_img = Image.new()
	atlas_img.create(512, 512, false, Image.FORMAT_RGBA8)
	
	atlas_tex = ImageTexture.new()
	atlas_tex.create_from_image(atlas_img)
	
	#this key is just temporary, ill think of a better solution along the way (maybe)
	InputMap.add_action("toggle_picker")
	var keyevent = InputEventKey.new()
	keyevent.scancode = KEY_P
	InputMap.action_add_event("toggle_picker", keyevent)
	
	#Steam.connect("lobby_joined", self, "lobby_joined")
	
	
	
	#string_to_color(color_string)
	pass # Replace with function body.
	
func _process(delta):
	if packet_timer >= 0.2:
		read_packets()
		
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
	var canvas_TileMap = get_node("/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap")
	canvas_TileSet = canvas_TileMap.get_tileset()
	print(str(canvas_TileMap))
	
	self.add_child(color_picker.instance())

func set_color(message: String, player, is_self):
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
				string_to_color(processed_color.to_lower())
			
			
			
	#		emit_signal("chalk_color_changed")
	#		print("emittin chalk color change signal :>")
		else:
			print("uh oh, the color string is in a wrong format! discarding...")
			PlayerData._send_notification("you entered an invalid code! use 6 letters/numbers, without #", 1)
			
			
	if is_self == true and message.begins_with("!save"):
		atlas_img.save_png("user://test.png")
		print("hopefully saved a png lol")
	


func string_to_color(color_string: String, tile_id: int = -1):
	global_color_string = color_string
	print(typeof(color_string))
	print("got passed a string, creating color")
	#yield(get_tree().create_timer(1.0), "timeout")
	var color = Color(global_color_string)
	create_new_tile(color, tile_id)
	
	PlayerData._send_notification("created color #" + color_string.trim_prefix("#ff"))
	



func create_new_tile(color: Color, id: int = -1): #in hex value
	print("color object received, creating colored pixel")
	
	var atlas_size = 512 #i hate this but this way godot has less resources to care about which is important in webfibby i think, at least my mod created some lag in tester art
	

	
	var color_x = color_slot % atlas_size #literally first time i found use for modulo, make it wrap around
	var color_y = int(color_slot / atlas_size) #we dont want stinky decimal points
	
	atlas_img.lock()
	atlas_img.set_pixel(color_x, color_y, color)
	print("currently set pixel color: " + atlas_img.get_pixel(color_x, color_y).to_html())
	
	atlas_tex.set_data(atlas_img)
	atlas_img.unlock()
	
	print("set pixel in atlas image at coords " + str(color_x) + " " + str(color_y) + " to color " + global_color_string + ", incrementing slot")
	color_slot += 1

	
	var tileset_id
	
	#first we create a blank 1x1 image
#	img_data = Image.new()
#	img_data.create(1, 1, false, Image.FORMAT_RGB8)
#	img_data.fill(color)
#
	#now we see if we are creating color tiles from a dict or a new one, if new we get a new ID
	
	if id == -1:
		tileset_id = canvas_TileSet.get_last_unused_tile_id()
		selected_chalk_color = tileset_id
		
	elif not id == -1:
		tileset_id = id
	
	
	color_dict[global_color_string] = tileset_id
	print(str(color_dict))
	
	var atlas_final = AtlasTexture.new()
	atlas_final.atlas = atlas_tex
	atlas_final.region = Rect2(color_x, color_y, 1, 1) #create a texture out of the given position, with a size of 1x1
	print("created an atlastexture, data is " + str(atlas_final.region))
	
	canvas_TileSet.create_tile(tileset_id)
	canvas_TileSet.tile_set_name(tileset_id, global_color_string)
	canvas_TileSet.tile_set_texture(tileset_id, atlas_final)
	Lure_chalk_resource.action_params[1] = selected_chalk_color
	
	
	
	#lets add the textured tile already
#	var img_texture = ImageTexture.new()
#	img_texture.create_from_image(img_data)
#

#	Lure_chalk_resource.action_params[1] = selected_chalk_color
	
	var compound_id_pair = [global_color_string, tileset_id]
	
	var color_poolbyte = var2bytes(["create_new_color", compound_id_pair, protocol_version])
	
	if id == -1:
		for steam_id in mod_user_list:
			Steam.sendMessageToUser(str(steam_id), color_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
	
	
	
	print("AAAAA hopefully a new tile has been created: " + str(canvas_TileSet.tile_get_name(tileset_id)) + " " + str(canvas_TileSet.tile_get_texture(tileset_id)))
	

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
	var valid_commands = ["color_handshake", "handshake_response", "create_new_color", "requested_dict", "sent_dict"] #this is stupid but maybe it works
	var message_array = Steam.receiveMessagesOnChannel(COLOR_CHANNEL, 10) 
	#REMEMBER: dec[0] is command, dec[1] is payload data, dec[2] is prot version
	#print(str(message_array.size()))
	
	#print("rolling over packets now")
	for message in message_array:
		var decoded = bytes2var(message.get("payload"))
		var packet_command = decoded[0]
		
		#the identity steam ID gets sent like "steamid:[ID]", i think thats weird ngl
		var sender = message.get("identity")
		var sender_steam_id = sender.get_slice(":", 1)
		
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
					mod_user_list.append(sender_steam_id)

					Steam.sendMessageToUser(sender_steam_id, response_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
					
					
				"handshake_response":
					print("received a response, stuffing player " + sender_steam_id + " into mod user list")
					mod_user_list.append(sender_steam_id)
					
					print("asking first available player for the color dict")
					request_dict()
					
				"requested_dict":
					print("received a request for the color dict, sending it since theyre asking so nicely")
					
					var atlas_bytes = atlas_img.save_png_to_buffer()
					var atlas_hash = compute_hash(atlas_bytes)
					
					var dict_poolbyte = var2bytes(["sent_dict", color_dict, protocol_version, atlas_hash])
					Steam.sendMessageToUser(sender_steam_id, dict_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
					
					
				"sent_dict":
					print("received a color dict, turning into colors")
					
					for color_string in decoded[1].keys():
						print(color_string)
						if typeof(color_string) == TYPE_STRING and color_string.length() == 9:
							
							string_to_color(color_string, decoded[1].get(color_string))
							
						else:
							print("hey something went wrong with the received dict, this is the type of one entry: " + str(typeof(color_string)))
							PlayerData._send_notification("something went wrong in recreating the old colors of a player, yell at ferrum and show them this: " + str(typeof(color_string)) + " " + str(color_string))
							
					var atlas_bytes = atlas_img.save_png_to_buffer()
					var local_atlas_hash = compute_hash(atlas_bytes)
					
					if local_atlas_hash == decoded[3]:
						print("the hashes are matching, carrying on :)")
						
					else:
						print("the hecc the hashes arent matching, re-requesting atlas")
						PlayerData._send_notification("yell at ferrum that the generated colors sent by another player arent matching with the ones you got saved pls", 1)
						clear_color()
						request_dict()
						
					
					
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
					var remote_color_array = decoded[1]
					string_to_color(remote_color_array[0], remote_color_array[1]) #string first, then ID

				_:
					pass
			
		else:
			print("something went *very* wrong in packet command validation")
			PlayerData._send_notification("yell at ferrum that the mod couldnt read a packet")
		

