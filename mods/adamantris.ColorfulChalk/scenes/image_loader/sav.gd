extends Button


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var main = $"/root/adamantrisColorfulChalk/UI"

# Called when the node enters the scene tree for the first time.
func _ready():
	self.connect("pressed", self, "on_press")
	
func on_press():
	var id = self.name.get_slice("_", 1)


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
