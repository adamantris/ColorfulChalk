using System.Text.Json.Serialization;

namespace adamantris.ColorfulChalk;

public class Config(ConfigFileSchema configFile)
{
	[JsonInclude]
	public bool infiniteChatRange = configFile.infiniteChatRange;
}
