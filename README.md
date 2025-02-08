<div align="center">

# GDScript Mod Loader

<img alt="Godot Modding Logo" src="icon.png" width="256" />

</div>

<br />

A generalized Mod Loader for GDScript-based Godot games.  
The Mod Loader allows users to create mods for games and distribute them as zips.  
Importantly, it provides methods to change existing scripts, scenes, and resources without modifying and distributing vanilla game files.

## Features
- Loading ZIPs as mods into the running game
  - Makes every script and resource moddable
  - Vanilla game files are not shared in mods
  - Disabled mods leave no trace
  - since Godot 4: workaround to mod scripts using `class_name`
  - Mod metadata
    - Compatibility checks between game and mod version
    - Load order/dependencies between mods 
    - General info like author and version
- Mod Configs
  - Settings for each individual mod
- Mod Profiles
  - Lists of mods and configurations that can easily be enabled and disabled
- Unified logging system for mods
- Mod Loader Options
  - allowing different Mod Loader settings per-feature
- Built in Mod Sources:
  - Steam Workshop
  - Thunderstore
  - Local /mods folder
- Self Setup for mods that don't have the Mod Loader preinstalled

## Getting Started

You can find detailed documentation, for game and mod developers, on the [Wiki](https://wiki.godotmodding.com/) page.

1. Add ModLoader to your [Godot Project](https://wiki.godotmodding.com/guides/integration/godot_project_setup/)   
   *Details on how to set up the Mod Loader in your Godot Project, relevant for game and mod developers.*
2. Create your [Mod Structure](https://wiki.godotmodding.com/guides/modding/mod_structure/)   
   *The mods loaded by the Mod Loader must follow a specific directory structure.*
3. Create your [Mod Files](https://wiki.godotmodding.com/guides/modding/mod_files/)   
   *Learn about the required files to create your first mod.*
4. Use the [API Methods](https://wiki.godotmodding.com/api/mod_loader_api/)   
   *A list of all available API Methods.*

## Godot Version
The current version of the Mod Loader is developed for Godot 3.  
The Godot 4 version is nearing release on the [4.x branch](https://github.com/GodotModding/godot-mod-loader/tree/4.x).   
For more details and updates on the Godot 4 version, please follow this [issue](https://github.com/GodotModding/godot-mod-loader/issues/315) 
or join us on [our Discord](https://discord.godotmodding.com).

## Development
The latest work-in-progress build can be found on the [development branch](https://github.com/GodotModding/godot-mod-loader/tree/development).

## Compatibility
The Mod Loader supports the following platforms:
- Windows
- macOS
- Linux
- Android
- iOS
