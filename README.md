<div align="center">

# GDScript Mod Loader

<img alt="Godot Modding Logo" src="https://github.com/KANAjetzt/godot-mod-loader/assets/41547570/44df4f33-883e-4c1d-baac-06f87b0656f4" width="256" />

</div>

<br />

A generalized Mod Loader for GDScript-based Godot games.  
The Mod Loader allows users to create mods for games and distribute them as zips.  
Importantly, it provides methods to change existing scripts, scenes, and resources without modifying and distributing vanilla game files.

## Getting Started

You can find detailed documentation, for game and mod developers, on the [Wiki](https://wiki.godotmodding.com/#/) page.

1. Add ModLoader to your [Godot Project](https://wiki.godotmodding.com/#/guides/integration/godot_project_setup)   
   *Details on how to set up the Mod Loader in your Godot Project, relevant for game and mod developers.*
2. Create your [Mod Structure](https://wiki.godotmodding.com/#/guides/modding/mod_structure)   
   *The mods loaded by the Mod Loader must follow a specific directory structure.*
3. Create your [Mod Files](https://wiki.godotmodding.com/#/guides/modding/mod_files)   
   *Learn about the required files to create your first mod.*
4. Use the [API Methods](https://wiki.godotmodding.com/#/api/mod_loader_api)   
   *A list of all available API Methods.*

## Godot Version
The current version of the Mod Loader is developed for Godot 3. The Godot 4 version is in progress on the [4.x branch](https://github.com/GodotModding/godot-mod-loader/tree/4.x) and can be used as long as no `class_name`s are in the project. Projects with `class_name`s are currently affected by an [engine bug](https://github.com/godotengine/godot/issues/83542). We are hopeful that this issue will be resolved in the near future. For more details and updates on the Godot 4 version, please follow this [issue](https://github.com/GodotModding/godot-mod-loader/issues/315) or join us on [our Discord](https://discord.godotmodding.com).

## Development
The latest work-in-progress build can be found on the [development branch](https://github.com/GodotModding/godot-mod-loader/tree/development).

## Compatibility
The Mod Loader supports the following platforms:
- Windows
- macOS
- Linux
- Android
- iOS

## Games Made Moddable by This Project
- [Brotato](https://store.steampowered.com/app/1942280/Brotato/) by 
[Blobfish Games](https://store.steampowered.com/developer/blobfishgames)
- [Dome Keeper](https://store.steampowered.com/app/1637320/Dome_Keeper/) by 
[Bippinbits](https://store.steampowered.com/developer/bippinbits)
- [Endoparasitic](https://store.steampowered.com/app/2124780/Endoparasitic/) by [Miziziziz](https://www.youtube.com/@Miziziziz)
- [Windowkill](https://store.steampowered.com/app/2726450/Windowkill/) by [torcado](https://store.steampowered.com/developer/torcado)
