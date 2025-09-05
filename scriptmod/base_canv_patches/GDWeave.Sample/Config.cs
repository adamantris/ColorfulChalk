using System.Text.Json.Serialization;

namespace adamantris.ChromaChalk;

public class Config(ConfigFileSchema configFile)
{
	[JsonInclude]
	public bool infiniteChatRange = configFile.infiniteChatRange;
}
