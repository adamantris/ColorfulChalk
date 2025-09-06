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

const FAVORITE_COLOR :=  Color.royalblue

onready var main = $"/root/adamantrisChromaChalk"
onready var color_picker = $"/root/adamantrisChromaChalk/UI/color_picker"
onready var loader_logic = $"/root/adamantrisChromaChalk/UI"

# Called when the node enters the scene tree for the first time.
func _ready():
	#print("did i find a button? " + str(save_button))
	main.connect("picker_visible", self, "picker_visible")
	color = FAVORITE_COLOR


func button_pressed():
	var color = self.color
	#print("ayooooo we got a color signal " + color_string)
	#main.global_color_string = color_string
	loader_logic.create_one_color(color)
	loader_logic.picker_button_was_pushed = false
	picker_visible()


func picker_visible():
	color_picker.visible = !color_picker.visible


func _on_ColorPicker_hide():
	prints("Picker hidden", color.to_html())
	loader_logic.create_one_color(color)


func _on_ColorPicker_color_changed(color):
	loader_logic.create_one_color(color)
