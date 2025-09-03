using GDWeave;
using util.LexicalTransformer;

namespace adamantris.ColorfulChalk;

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
				// ? Named solely for debugging/logging purposes
				.Named("ColorfulChalk")
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

							onready var chalk_mod = get_node("/root/adamantrisColorfulChalk")
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
		// }
	}

	public void Dispose()
	{
		// Post-injection cleanup (optional)
	}
}
