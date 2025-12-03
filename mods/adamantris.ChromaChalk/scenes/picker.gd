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
onready var API = $"/root/adamantrisChromaChalk/API"
onready var color_picker = $"/root/adamantrisChromaChalk/UI/color_picker"
onready var panel = $"../.."
onready var loader_logic = $"/root/adamantrisChromaChalk/UI"

# Called when the node enters the scene tree for the first time.
func _ready():
	#print("did i find a button? " + str(save_button))
	main.connect("picker_visible", self, "picker_visible")
	#save_button.connect("pressed", self, "button_pressed")
	
	#what follows is highly suboptimal, but godot doesnt let you change the picker elements in the editor. means we have to use ugly code to rearrange stuff
	yield(get_tree().create_timer(0.5), "timeout")
	rearrange_controls()
	

func rearrange_controls():
	var preview = self.get_child(1)
	var sliders = self.get_child(4)
	var color_presets = self.get_child(6)
	
	preview.visible = false
	preview.rect_min_size = Vector2(0, 0)
	sliders.visible = false
	sliders.rect_min_size = Vector2(0, 0)
	color_presets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.rect_size = Vector2(304, 302) #after hiding everything you need to reset the size, growing happens automatically for preset colors


func button_pressed():
	#var color = self.color
	#print("ayooooo we got a color signal " + color_string)
	#main.global_color_string = color_string
	#loader_logic.create_one_color(self.color)
	pass
	

func picker_visible():
	color_picker.visible != color_picker.visible


func _on_ColorPicker_color_changed(color):
	#API.emit_signal(color)
	pass # Replace with function body.
