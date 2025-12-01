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
				// ? Named solely for debugging/logging purposes
				.Named("ChromaChalk")
				// ! Note the file extension will end in gdc NOT gd
				.Patching("res://Scenes/Entities/ChalkCanvas/chalk_canvas.gdc")
				
				.AddRule(
					new TransformationRuleBuilder()
					.Named("Add a small variable to hold our proxy node")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGlobalsPattern())
					.With(
						"""

						var proxy_node

						"""
						)

				)


				.AddRule(
					new TransformationRuleBuilder()
					.Named("Add our proxy node and get a reference")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						if not (color is int): color = 0
						$Viewport / TileMap.set_cell(pos.x, pos.y, color)
						"""
					))
					.With(
						"""

						get_node("Viewport/TileMap/Node2D").replicate(data)
						

						""",
						1
					)

				)
				.AddRule(
					new TransformationRuleBuilder()
					.Named("Make chalk_receive send us a copy of the packet data")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						vis_node.connect("screen_entered", self, "_screen_entered")
						vis_node.connect("screen_exited", self, "_screen_exited")
						"""
					))
					.With(
						"""



						proxy_node = get_node("Viewport/TileMap")


						""",
		   1
					)

				)
				.AddRule(
					new TransformationRuleBuilder()
					.Named("Make _chalk_draw call our color_img function")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						_add_brush(p, brush_mode, p2)
						last_mouse_pos = pos
						"""
					))
					.With(
						"""

						proxy_node.color_img(pos, size, color, last_mouse_pos)
						

						""",
						1
					)

				)
				.AddRule(
					new TransformationRuleBuilder()
					.Named("Snoop into _add_brush so we can draw lines too")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateGdSnippetPattern(
						"""
						$Viewport / TileMap.set_cell(final.x, final.y, color)
						send_load.append([final, color])
						"""
					))
					.With(
						"""

						get_node("Viewport/TileMap/Node2D").new_line(_clamp_cell(from), _clamp_cell(grid_pos), brush_size, color, canvas_id)


						""",
						1
					)

				)
				.AddRule(
					new TransformationRuleBuilder()
					.Named("Add a call to our chalk_update")
					.Do(Operation.Append)
					.Matching(TransformationPatternFactory.CreateFunctionDefinitionPattern("_chalk_update", ["pos"]))
					.With(
						"""

						proxy_node.chalk_update(pos)

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
