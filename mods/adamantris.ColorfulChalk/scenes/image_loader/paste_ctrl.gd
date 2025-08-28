extends Button


onready var paste_select = $"../../.."
onready var loader_logic = $"../../../../.." #doing that kind of relative paths is cursed but too bad!

# Called when the node enters the scene tree for the first time.
func _ready():
	self.connect("pressed", self, "button_pressed") # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func button_pressed():
	print("pressed the " + str(self.name) + " button, telling loader and hiding paste")
	var canv_id = self.name.get_slice("_", 1)
	print("canvas id " + str(canv_id))
	loader_logic.paste_image(canv_id)
	paste_select.visible = false
