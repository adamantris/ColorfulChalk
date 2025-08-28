extends Button


# Declare member variables here. Examples:
# var a = 2
# var b = "text"
onready var dialog = $"../FileDialog"

# Called when the node enters the scene tree for the first time.
func _ready():
	self.connect("pressed", self, "button_pressed")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
func button_pressed():
	print("hello i am pressed")
	dialog.popup_centered()
