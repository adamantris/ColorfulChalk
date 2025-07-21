extends Node

signal chalk_color_changed

onready var Players = get_node_or_null("/root/ToesSocks/Players")
onready var Chat = get_node_or_null("/root/ToesSocks/Chat")

var canvas_TileSet
var color_dict: Dictionary = {}
var selected_chalk_color

onready var color_string #: String = "#ff0000ff"
onready var color
export onready var img_data


# Called when the node enters the scene tree for the first time.
func _ready():
	Chat.connect("player_messaged", self, "set_color")
	Players.connect("ingame", self, "ingame")
	#string_to_color(color_string)
	pass # Replace with function body.

func ingame(): #to get the tilemap, gotta add dynamically after all or the whole world explodes
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
			
		else:
			color_string = processed_color
			string_to_color(processed_color)
			
		emit_signal("chalk_color_changed")
		print("emittin chalk color change signal :>")
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
	
	#lets add the textured tile already
	var img_texture = ImageTexture.new()
	img_texture.create_from_image(img_data)
	
	canvas_TileSet.create_tile(tileset_id)
	canvas_TileSet.tile_set_name(tileset_id, color_string)
	canvas_TileSet.tile_set_texture(tileset_id, img_texture)
	
	print("AAAAA hopefully a new tile has been created: " + str(canvas_TileSet.tile_get_name(tileset_id)) + " " + str(canvas_TileSet.tile_get_texture(tileset_id)))
	

