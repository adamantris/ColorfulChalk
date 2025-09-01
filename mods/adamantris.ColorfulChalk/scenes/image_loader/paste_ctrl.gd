# ColorfulChalk, a mod that extends chalk colors and adds save/load functionality.
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

extends Button


onready var paste_select = $"/root/adamantrisColorfulChalk/UI/paste_stuff/paste_select"
onready var loader_logic = $"/root/adamantrisColorfulChalk/UI" 
onready var main = get_node("/root/adamantrisColorfulChalk")
onready var canv_id = self.name.get_slice("_", 1)
func _ready():
	# Extrahiere die ID direkt aus dem Namen des Buttons.
	
	# Verbinde das 'pressed'-Signal direkt mit 'paste_image' auf dem loader_logic-Skript
	# und binde die extrahierte 'canv_id' als Argument.
	self.connect("pressed", loader_logic, "paste_image", [canv_id])
	
	# Verbinde das 'pressed'-Signal zusätzlich mit einer Funktion, um das Popup zu schließen.
	self.connect("pressed", self, "hide_popup")

func hide_popup():
	# Diese Funktion sorgt nur dafür, dass das Fenster verschwindet.
	main.button_id = canv_id
	paste_select.visible = false
