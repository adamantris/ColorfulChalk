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
									indent: 1
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
								RAINBOW = 5,
								GREEN = 6,
								ERASER = -1

							}
							//we dont support rainbow chalk, so its -1
							const vanilla_color = {
								0: Color(1, 0.933, 0.835, 1),
								1: Color(0.02, 0.043, 0.082, 1),
								2: Color(0.675, 0, 0.161, 1),
								3: Color(0, 0.522, 0.514, 1),
								4: Color(0.902, 0.616, 0, 1),
								5: -1,
								6: Color(0.49, 0.635, 0.141, 1),
								-1: Color(0, 0, 0, 0)
							}


							onready var main = get_node("/root/adamantrisChromaChalk")
							onready var canvas_image = Image.new()
							onready var canvas_texture = ImageTexture.new()
							var textrect

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

							chalk_mod.connect("tileset_update", self, "update_tileset")
							tilemap = $"Viewport/TileMap"
							if chalk_mod.current_tileset != null and chalk_mod.current_tileset.get_tiles_ids().size() > 7: 
								tilemap.tile_set = chalk_mod.current_tileset

							""",
							indent: 1
						)
				)

				.AddRule(
					new TransformationRuleBuilder()
					.Named("Connect to the drawing signal, and add couple of functions")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						Network.connect("_new_player_join", self, "set_drawing")
						"""
					)
					.With(
						"""

							PlayerData.connect("drawing", self, "set_drawing")

						func process(delta):
							if drawing:
								pass

						func set_drawing(is_drawing):
							drawing = is_drawing

						"""
						)
				.Build()

		);

		mi.RegisterScriptMod(
			new TransformationRuleScriptModBuilder()
				.ForMod(mi)
				.Named("Paint Node patches")
				.Patching("res://Scenes/Entities/Player/paint_node.gdc")
				.AddRule(
					new TransformationRuleBuilder()
						.Named("Make the paint node emit a signal upon drawing")
						.Do(Operation.Append)
						.Matching(TransformationPatternFactory.CreateGdSnippetPattern("PlayerData.emit_signal("_chalk_update", global_transform.origin)"))
						.With(
							"""

							func transmit_drawing(drawing):
								PlayerData.emit_signal("drawing", drawing)

							"""
						)
				)
				.AddRule(
					new TransformationRuleBuilder()
					.Named("make drawing a setget")
					.Do(Operation.ReplaceAll)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern("var drawing = false"))
					.With(
						"""

						var drawing = false setget transmit_drawing

						"""
					)
				)
				.Build()

		;)
			mi.RegisterScriptMod(
				new TransformationRuleScriptModBuilder()
					.ForMod(mi)
					.Named("PlayerData patches")
					.Patching("res://Scenes/Singletons/playerdata.gdc")
					.AddRule(
						new TransformationRuleBuilder()
						.Named("Add a signal for the paint node to emit to")
						.Do(Operation.Append)
						.Matching(TransformationPatternFactory.CreateGlobalsPattern())
						.With(
							"""

							signal drawing(is_drawing)

							"""
						)
					)
		);
		
	}

	public void Dispose()
	{
		// Post-injection cleanup (optional)
	}
}
