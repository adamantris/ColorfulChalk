extends Node

signal chalk_color_changed

enum send_type{
	RELIABLE = 8,
	UNRELIABLE = 0,
	UNRELIABLE_FAST = 4,
}

const COLOR_CHANNEL = 10

onready var Lure = get_node("/root/SulayreLure")
onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")

#onready var chalk = preload("res://mods/adamantris.ColorfulChalk/RGB_chalk.tres")

var canvas_TileSet
var color_dict: Dictionary = {}
var selected_chalk_color
var Lure_chalk_dict
var Lure_chalk_resource

var packet_timer: float = 0.0

onready var color_string #: String = "#ff0000ff"
onready var color
export onready var img_data


# Called when the node enters the scene tree for the first time.
func _ready():
	Chat.connect("player_messaged", self, "set_color")
	Players.connect("ingame", self, "ingame")
	Lure.add_content("adamantris.ColorfulChalk", "Rainbow Chalk", "res://mods/adamantris.ColorfulChalk/chalk_rainbow.tres", [Lure.LURE_FLAGS.FREE_UNLOCK])
	#Steam.connect("lobby_joined", self, "lobby_joined")
	
	
	
	#string_to_color(color_string)
	pass # Replace with function body.
	
func _process(delta):
	if packet_timer >= 0.1:
		read_packets()
		
	else:
		packet_timer += delta

func ingame(): #to get the tilemap, gotta add dynamically after all or the whole world explodes
	Lure_chalk_dict = Lure.item_list.get("adamantris.ColorfulChalk.Rainbow Chalk")
	Lure_chalk_resource = Lure_chalk_dict.get("resource")
	lobby_joined()
	
	
	print(str(Lure_chalk_resource))
	var canvas_TileMap = get_node("/root/world/Viewport/main/map/main_map/zones/main_zone/chalk_zones/chalk_canvas/Viewport/TileMap")
	canvas_TileSet = canvas_TileMap.get_tileset()
	print(str(canvas_TileMap))

func set_color(message: String, player, is_self):
	print("color command")
	if is_self == true and message.begins_with("!color"):
		print("check passed")
		
		var new_color_received = message.get_slice(" ", 1)
		print("new color slice: " + new_color_received)
		
		var processed_color = "#ff" + new_color_received
		print("made correct with alpha: " + processed_color)
		
		if processed_color in color_dict.keys():
			print("color already been created once, setting to existing tile id")
			selected_chalk_color = color_dict.get(processed_color)
			Lure_chalk_resource.action_params[1] = selected_chalk_color
			
		else:
			color_string = processed_color
			string_to_color(processed_color)
			
#		emit_signal("chalk_color_changed")
#		print("emittin chalk color change signal :>")
	else:
		print("ayo how did u find urself with this message its not normal help AAAAAAAAAAAAAAAAAa")
	


func string_to_color(color_string):
	print("receiving string, turning into color object")
	color = Color(color_string)
	create_new_tile(color)



func create_new_tile(color: Color): #in hex value
	print("color object received, creating colored pixel")
	
	#first we create
	img_data = Image.new()
	img_data.create(1, 1, false, Image.FORMAT_RGBA8)
	img_data.fill(color)
	
	#now, we add a color-tile ID pair into the dict first, because lookups take up less ram i think?
	var tileset_id = canvas_TileSet.get_last_unused_tile_id()
	color_dict[color_string] = tileset_id
	
	print(str(color_dict))
	
	#lets add the textured tile already
	var img_texture = ImageTexture.new()
	img_texture.create_from_image(img_data)
	
	canvas_TileSet.create_tile(tileset_id)
	canvas_TileSet.tile_set_name(tileset_id, color_string)
	canvas_TileSet.tile_set_texture(tileset_id, img_texture)
	
	selected_chalk_color = tileset_id
	Lure_chalk_resource.action_params[1] = selected_chalk_color
	
	
	
	print("AAAAA hopefully a new tile has been created: " + str(canvas_TileSet.tile_get_name(tileset_id)) + " " + str(canvas_TileSet.tile_get_texture(tileset_id)))
	

func lobby_joined():
	var color_handshake = "hello_lobby_i_just_joined"
	
	var hello_poolbyte = var2bytes(["color_handshake", color_handshake])
	print("attempting to send a hello")
	for connection_entry in Network.OPEN_CONNECTIONS:
		var steam_id = connection_entry
		Steam.sendMessageToUser(str(steam_id), hello_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
		print("heyyy i sent a hello to " + str(steam_id))
		
		
func read_packets():
	
	var message_array = Steam.receiveMessagesOnChannel(COLOR_CHANNEL, 5)
	if message_array.empty():
		return
		
	else:
		for message in message_array:
			var decoded = bytes2var(message.get("payload"))
			var packet_command = decoded[0]
			
			match packet_command:
				
				"color_handshake":
					var respond_handshake = "hi yes i see you"
					var response_poolbyte = var2bytes(["response", respond_handshake])
					Steam.sendMessageToUser(str(decoded[3]), response_poolbyte, send_type.RELIABLE, COLOR_CHANNEL)
					print("i sent a response to the handshake")
					
				"response":
					print("ooo " + Players.get_usernme(decoded[3]) + " sent a response")
					
		
	
