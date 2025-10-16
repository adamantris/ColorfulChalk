# ChromaChalk, a mod that extends chalk colors and adds save/load functionality.
# Copyright (C) 2025 adamantris
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

extends ColorPicker


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

#onready var save_button = $"../../Button"
onready var main = $"/root/adamantrisChromaChalk"
onready var color_picker = $"/root/adamantrisChromaChalk/UI/color_picker"
onready var loader_logic = $"/root/adamantrisChromaChalk/UI"

# Called when the node enters the scene tree for the first time.
func _ready():
	#print("did i find a button? " + str(save_button))
	main.connect("picker_visible", self, "picker_visible")
	#save_button.connect("pressed", self, "button_pressed")
	pass # Replace with function body.


func button_pressed():
	#var color = self.color
	#print("ayooooo we got a color signal " + color_string)
	#main.global_color_string = color_string
	#loader_logic.create_one_color(self.color)
	pass
	

func picker_visible():
	if color_picker.visible == false:
		color_picker.visible = true
		
	elif color_picker.visible == true:
		color_picker.visible = false
