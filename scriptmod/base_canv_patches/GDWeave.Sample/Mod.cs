using GDWeave;
using util.LexicalTransformer;

namespace adamantris.ChromaChalk;

/*
 The main entrypoint of your mod project
 This code here is invoked by GDWeave when loading your mod's DLL assembly, at runtime
*/

public class Mod : IMod
{
	public Mod(IModInterface mi)
	{
		// Load your mod's configuration file
		// var config = new Config(mi.ReadConfig<ConfigFileSchema>());
		// ...but this mod doesnt need any configs

		mi.RegisterScriptMod(
					new TransformationRuleScriptModBuilder()
						.ForMod(mi)
						.Named("Lure Item Action Fix")
						.Patching("res://Scenes/Entities/Player/player.gdc")
						.AddRule(
							new TransformationRuleBuilder()
								.Named("Fix Lure not changing _use_item correctly")
								.Do(Operation.Append)
								.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
									"""
									if not controlled: return

										if held_item.empty(): return
											var item_data = Globals.item_data[held_item["id"]]["file"]
									"""
									)
								)
								.With(
									"""

									if get_node("/root/SulayreLure/Patches")._call_action(item_data.action,item_data.action_params): return

									""",
									1
								)
						)

						
						.Build()
				);

		mi.RegisterScriptMod(
			new TransformationRuleScriptModBuilder()
				.ForMod(mi)
				// ? Named solely for debugging/logging purposes
				.Named("ChromaChalk")
				// ! Note the file extension will end in gdc NOT gd
				.Patching("res://Scenes/Entities/ChalkCanvas/chalk_canvas.gdc")
				.AddRule(
					new TransformationRuleBuilder()
						// ! These names MUST be unique or your mod will throw an System.InvalidOperationException when loading !
						.Named("Create required variables n stuff")
						.Do(Operation.Append)
						.Matching(
							TransformationPatternFactory.CreateGlobalsPattern()
						)
						.With(
							"""

								enum Vanilla {
									WHITE = 0,
									BLACK = 1,
									RED = 2,
									BLUE = 3,
									YELLOW = 4,
									SPECIAL = 5,
									GREEN = 6
									RGB = 7
									ERASER = -1
								}

								onready var main = get_node("/root/adamantrisChromaChalk")
								onready var ll = get_node("/root/adamantrisChromaChalk/UI/") 
								var chalk_color = {
									0: Color(1, 0.933, 0.835, 1),
									1: Color(0.02, 0.043, 0.082, 1),
									2: Color(0.675, 0, 0.161, 1),
									3: Color(0, 0.522, 0.514, 1),
									4: Color(0.902, 0.616, 0, 1),
									5: -2, 
									6: Color(0.49, 0.635, 0.141, 1),
									7: Color(0.02, 0.016, 0.667), 
									-1: Color(0, 0, 0, 0)
								}



								var canvas_image
								var canvas_texture
								var node2d


								var last_pixel_pos

								var textrect
								var img_viewport
								var img_size = 200

								"""
						)
					)
				.AddRule(
					new TransformationRuleBuilder()
						.Named("Create a TextureRect for displaying the drawings")
						.Do(Operation.Append)
						.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_ready", [])) //if theres an tileset and its bigger than vanilla, take it
						.With(
							"""

							yield(get_tree(), "idle_frame")
							canvas_image = Image.new()
							canvas_texture = ImageTexture.new()
							node2d = Node2D.new()

							canvas_image.lock()
							canvas_image.create(200, 200, true, Image.FORMAT_RGBA8)
							var blank_color = Color(0, 0, 0, 0)
							canvas_image.fill(blank_color)
							canvas_image.unlock()

							canvas_texture.create_from_image(canvas_image)


							var texture_rect = TextureRect.new()
							texture_rect.texture = canvas_texture
							node2d.add_child(texture_rect, true)



							print("BLOODY TEST PRINT")
							var tries = 0
							while get_node_or_null("Viewport") == null and tries < 50:
								yield(get_tree().create_timer(0.1), "timeout")
								tries += 1
								print("fucking waiting, tries number " + str(tries))
							img_viewport = get_node("Viewport")
							img_viewport.add_child(node2d, true)
							var color_picker = get_node("/root/adamantrisChromaChalk/UI/color_picker/PanelContainer/VBoxContainer/Control/ColorPicker")
							color_picker.connect("color_changed", self, "set_custom_color")

							textrect = get_node("Viewport/Node2D/TextureRect")



							""",
							1
						)
				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Hook into chalk_draw")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						_add_brush(p, brush_mode, p2)
						last_mouse_pos = pos
						"""
					))
					.With(
						"""

						if color == 5:
							return

						var canv_transform = self.transform
						var local_pos = canv_transform.xform_inv(pos)


						var pixel_pos = Vector2((local_pos.x + 10), (local_pos.z + 10)) / 20 * img_size
						var selected_color = chalk_color.get(color)


						var paint_size = 1 * size


						canvas_image.lock()

						if last_pixel_pos == null:
							last_pixel_pos = pixel_pos

						else:
							pass

						var temp_pos = last_pixel_pos
						while temp_pos != pixel_pos:

							var paint_rect = Rect2(int(temp_pos.x) - paint_size / 2, int(temp_pos.y) - paint_size / 2, paint_size, paint_size)
							canvas_image.fill_rect(paint_rect, selected_color)
							temp_pos = temp_pos.move_toward(pixel_pos, 1)
						canvas_image.unlock()
						canvas_texture.set_data(canvas_image)

						last_pixel_pos = Vector2(int(pixel_pos.x), int(pixel_pos.y))

						""",
						1
					)

				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Add small function to set custom colors on the fly")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						Network.connect("_new_player_join", self, "_chalk_send_total")
						"""
						)

					)
					.With(
						"""

						func set_custom_color(new_color):
							chalk_color[7] = new_color
						"""
					)

				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Make chalk_update reset chalk position")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_chalk_update", ["pos"]))
					.With(
						"""

						last_pixel_pos = null
						""",
						1
					)

				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Disable _screen_entered")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_screen_entered", []))
					.With(
						"""

						return
						""",
						1
						)

				)



				.AddRule(
					new TransformationRuleBuilder()
					.Named("Disable _screen_exited")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_screen_exited", []))
					.With(
						"""

						return
						""",
						1
						)

				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Disable _options_update")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_options_update", []))
					.With(
						"""

						return
						""",
						1
						)

				)

				.Build()

		);

		

		
	}

	public void Dispose()
	{
		// Post-injection cleanup (optional)
	}
}
