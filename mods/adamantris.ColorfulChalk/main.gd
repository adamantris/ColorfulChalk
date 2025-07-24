extends Node

signal chalk_color_changed

enum send_type{
	RELIABLE = 8,
	UNRELIABLE = 0,
	UNRELIABLE_FAST = 4,
}

const COLOR_CHANNEL = 10
const protocol_version = 1

onready var Lure = get_node("/root/SulayreLure")
onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")

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


# Called when the node enters the scene tree for the first time.
func _ready():
	yield(get_tree().create_timer(1.0), "timeout")
	Chat.connect("player_messaged", self, "set_color")
	Players.connect("ingame", self, "ingame")
	Players.connect("player_removed", self, "player_removed")
	Lure.add_content("adamantris.ColorfulChalk", "Rainbow Chalk", "res://mods/adamantris.ColorfulChalk/chalk_rainbow.tres", [Lure.LURE_FLAGS.FREE_UNLOCK])
	
	
	#Steam.connect("lobby_joined", self, "lobby_joined")
	
	
	
	#string_to_color(color_string)
	pass # Replace with function body.
	
func _process(delta):
	if packet_timer >= 0.2:
		read_packets()
		
	else:
		packet_timer += delta

func ingame(): #to get the tilemap, gotta add dynamically after all or the whole world explodes
	Lure_chalk_dict = Lure.item_list.get("adamantris.ColorfulChalk.Rainbow Chalk")
	Lure_chalk_resource = Lure_chalk_dict.get("resource")
	PlayerData._send_notification("this is a test message, please ignore")
	lobby_joined()
	
	
	print(str(Lure_chalk_resource))
	var canvas_TileMap = get_node("/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap")
	canvas_TileSet = canvas_TileMap.get_tileset()
	print(str(canvas_TileMap))

func set_color(message: String, player, is_self):
	if is_self == true and message.begins_with("!color"):
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
			
			var color_poolbyte = var2bytes(["create_new_color", processed_color, protocol_version])
			for steam_id in Network.OPEN_CONNECTIONS:
				Steam.sendMessageToUser(str(steam_id), color_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
			
	#		emit_signal("chalk_color_changed")
	#		print("emittin chalk color change signal :>")
		else:
			print("uh oh, the color string is in a wrong format! discarding...")
			PlayerData._send_notification("you entered an invalid code! use 6 letters/numbers, without #", 1)
	


func string_to_color(color_string: String):
	global_color_string = color_string
	print(typeof(color_string))
	print("got passed a string, creating color")
	#yield(get_tree().create_timer(1.0), "timeout")
	var color = Color(global_color_string)
	create_new_tile(color)
	
	PlayerData._send_notification("created color #" + color_string.trim_prefix("#ff"))
	



func create_new_tile(color: Color, id: int = -1): #in hex value
	print("color object received, creating colored pixel")
	
	var tileset_id
	
	#first we create a blank 1x1 image
	img_data = Image.new()
	img_data.create(1, 1, false, Image.FORMAT_RGB8)
	img_data.fill(color)
	
	#now we see if we are creating color tiles from a dict or a new one, if new we get a new ID
	
	if id == -1:
		tileset_id = canvas_TileSet.get_last_unused_tile_id()
		selected_chalk_color = tileset_id
		
	elif not id == -1:
		tileset_id = id
	
	
	color_dict[global_color_string] = tileset_id
	print(str(color_dict))
	
	#lets add the textured tile already
	var img_texture = ImageTexture.new()
	img_texture.create_from_image(img_data)
	
	canvas_TileSet.create_tile(tileset_id)
	canvas_TileSet.tile_set_name(tileset_id, global_color_string)
	canvas_TileSet.tile_set_texture(tileset_id, img_texture)
	Lure_chalk_resource.action_params[1] = selected_chalk_color
	
	
	
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
		
		for tile in color_dict.keys():
			canvas_TileSet.remove_tile(color_dict.get(tile))
		
		print("tried to remove tiles, tiles left: " + str(canvas_TileSet.get_tiles_ids()))
		
		color_dict = {}
		mod_user_list = []


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
		if decoded[0] in valid_commands and decoded[2] == protocol_version:
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
					
					var dict_poolbyte = var2bytes(["sent_dict", color_dict, protocol_version])
					Steam.sendMessageToUser(sender_steam_id, dict_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
					
					
				"sent_dict":
					print("received a color dict, turning into colors")
					
					for color_string in decoded[1].keys():
						print(color_string)
						if typeof(color_string) == TYPE_STRING and color_string.length() == 9:
							
							string_to_color(color_string)
							
						else:
							print("hey something went wrong with the received dict, this is the type of one entry: " + str(typeof(color_string)))
							PlayerData._send_notification("something went wrong in recreating the old colors of a player, yell at ferrum and show them this: " + str(typeof(color_string)) + " " + str(color_string))
							
					
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
					global_color_string = decoded[1]
					string_to_color(decoded[1])

				"_":
					pass
			
		elif decoded[2] != protocol_version:
			print("wrong protocol version, discarding")
			PlayerData._send_notification("you received a packet with a mismatching protocol version, either you or the other person should update their mod.")
		
		
		elif not decoded[0] in valid_commands:
			print("received garbage data, passing")
			PlayerData._send_notification("you received a packet filled with garbage, please tell ferrum - " + str(decoded))
			
		else:
			print("something went *very* wrong in packet command validation")
			PlayerData._send_notification("yell at ferrum that the mod couldnt read a packet")
