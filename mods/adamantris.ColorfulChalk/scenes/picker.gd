extends ColorPicker


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var save_button = $"../../Button"
onready var main = $"/root/adamantrisColorfulChalk"
onready var color_picker = $"/root/adamantrisColorfulChalk/color_picker"

# Called when the node enters the scene tree for the first time.
func _ready():
	print("did i find a button? " + str(save_button))
	main.connect("picker_visible", self, "picker_visible")
	save_button.connect("pressed", self, "button_pressed")
	pass # Replace with function body.


func button_pressed():
	var color_string = "#" + self.color.to_html()
	print("ayooooo we got a color signal " + color_string)
	main.global_color_string = color_string
	main.string_to_color(color_string)
	picker_visible()

func picker_visible():
	if color_picker.visible == false:
		color_picker.visible = true
		
	elif color_picker.visible == true:
		color_picker.visible = false
