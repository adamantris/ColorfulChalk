extends CanvasLayer


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

onready var textrect = $"TextureRect"
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


func create_set_tex(py_image):
	var imgtex = ImageTexture.new()
	imgtex.create_from_image(py_image)
	
	textrect.set_texture(imgtex)
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
