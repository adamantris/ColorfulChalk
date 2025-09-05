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
						.Named("Create a ref to my main node, a var for tilemap and a baby function to update the tileset")
						.Do(Operation.Append)
						.Matching(
							TransformationPatternFactory.CreateGlobalsPattern()
						)
						.With(
							"""

							onready var chalk_mod = get_node("/root/adamantrisChromaChalk")
							var tilemap: TileMap


							func update_tileset(tileset):
								tilemap.tile_set = tileset
							"""
						)
					)
				.AddRule(
					new TransformationRuleBuilder()
						.Named("check if there already exists a changed tileset, and connect a signal from main mod node to receive newly created ones.")
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
				.Build()

		);

		mi.RegisterScriptMod(
			new TransformationRuleScriptModBuilder()
				.ForMod(mi)
				.Named("Paint Node patches")
				.Patching("res://Scenes/Entities/Player/paint_node.gdc")
				.AddRule(
					new TransformationRuleBuilder()
						.Named("Add a path to my main mod below extends")
						.Do(Operation.Append)
						.Matching(TransformationPatternFactory.CreateGlobalsPattern())
						.With(
							"""

							onready var chalk_mod = get_node("/root/adamantrisChromaChalk")

							"""
						)
				)
				.AddRule(
					new TransformationRuleBuilder()
						.Named("Add a custom draw variable, a ready for my signal and an action + release function")
						.Do(Operation.Append)
						.Matching(TransformationPatternFactory.CreateGdSnippetPattern("""var color = 0"""))
						.With(
							"""

							var custom_draw = false

							func _ready():
								yield(get_tree(), "idle_frame")
								chalk_mod.connect("custom_draw", self, "on_custom_draw")
								chalk_mod.connect("custom_draw_stop", self, "on_custom_draw_stop")
								
							func on_custom_draw(mod_color_id):
								print("should i draw or nah")
								print("received a custom draw signal, id is " + str(mod_color_id))
								custom_draw = true
								drawing = true
								color = mod_color_id + 6
								
							func on_custom_draw_stop():
								print("received a signal to stop drawing")
								custom_draw = false
								drawing = false
								color = 0

							""" //for anyone curious, +6 is because the atlas lookup thingymajig needs to start at 0 for pixel setting, but custom colors start at 7
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
