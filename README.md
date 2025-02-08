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

You can find quickstart guides and more on the [Wiki](https://wiki.godotmodding.com/).

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
