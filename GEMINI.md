# GEMINI.md - adamantris.ColorfulChalk

> **Meta:** Wir haben vereinbart, auf Deutsch zu kommunizieren.

## Project Overview

`adamantris.ColorfulChalk` is a mod for a Godot 3.5 game, likely "Webfishing". The mod enhances the in-game "chalk" feature by allowing players to select any color from the RGB spectrum. It includes a custom color picker UI, chat commands for activation, and multiplayer support to synchronize colors between players. The mod also allows saving the current chalk canvas as a PNG image.

The project is a hybrid, utilizing both GDScript for high-level game logic and C# for lower-level patching and integration via the GDWeave modding framework.

**Key Technologies:**
*   Godot 3.5
*   GDScript
*   C# (.NET 8)
*   GDWeave (Modding Framework)

**Dependencies:**
*   `toes.Socks`: For multiplayer chat and player state management.
*   `TeamLure.LureRefreshed`: For integrating the custom chalk item into the game.
*   `NotNet.GDWeave`: C# modding and patching framework.

## Project Structure

The project is organized into two main parts: the Godot mod assets and the C# patch script.

*   `/mods/adamantris.ColorfulChalk/`: Contains the core GDScript files, scenes (`.tscn`), and resources (`.tres`) that constitute the Godot part of the mod.
    *   `main.gd`: The central script that manages UI, player interactions, networking, and color data.
    *   `scenes/`: Contains the color picker UI and other related scenes.
    *   `resources/`: Holds Godot resources like custom materials and item definitions.

*   `/scriptmod/`: Contains the C# solution for patching the game.
    *   `base_canv_patches/GDWeave.Sample/adamantris.ColorfulChalk.csproj`: The C# project file. The code within this project likely interacts with the game's core systems to enable the GDScript portion to function correctly.

*   `manifestation.toml`: A manifest file that defines the mod's metadata, dependencies, and project structure for a mod loader.

## Building and Running

The project has two components that need to be handled separately.

**1. GDScript:**
The GDScript files (`.gd`) are interpreted directly by Godot and do not require a separate build step. They are loaded by the game's mod loader. The user has indicated that the `/mods/adamantris.ColorfulChalk` directory inside the main game folder (`webfishing`) is a symlink to this project's `/mods/adamantris.ColorfulChalk` directory.

**2. C# Script:**
The C# project needs to be compiled. The `adamantris.ColorfulChalk.csproj` file contains a post-build event that automatically copies the compiled artifacts to the correct location for the GDWeave mod loader.

To build the C# project, you would typically run:
```bash
# TODO: Verify the exact build command and path.
dotnet build /path/to/adamantris.ColorfulChalk/scriptmod/base_canv_patches/GDWeave.Sample/adamantris.ColorfulChalk.csproj
```

The game, with the appropriate mod loaders (Socks, Lure, GDWeave) installed, will then load both the GDScript files and the compiled C# assembly.

## Development Conventions

*   **Hybrid Architecture:** Logic is split between GDScript and C#. GDScript handles game-level features and UI, while C# seems to be used for patching and framework-level integration.
*   **Networking:** Custom networking logic is implemented in `main.gd` using Godot's low-level `Steam` multiplayer API (`sendMessageToUser`, `receiveMessagesOnChannel`) on a dedicated channel (`COLOR_CHANNEL = 10`) to sync color data between players.
*   **Chat Commands:** The mod uses the Socks chat API to register commands (e.g., `!save`, `!color`) for user interaction.
*   **Threading:** The mod uses Godot's `Thread` class to handle potentially long-running operations like processing image data and creating new chalk tiles without blocking the main game thread.
