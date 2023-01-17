# GDScript Mod Loader

A general purpose mod-loader for GDScript-based Godot Games.

## Quick Loader Setup

If the game you want to mod does not natively use this ModLoader, you will have to complete two steps to set it up:
1. Place the `/addons` folder from the ModLoader next to the executable of the game you want to mod.
2. set this flag `--script addons/mod_loader_tools/mod_loader_setup_helper.gd`
   - Steam: right-click the game in the game list > press *properties* > enter in *startup options* 
   - Godot: Project Settings > press *Editor* > enter in *Main Run Args*
   - Other: Search for "set launch (or command line) parameters [your platform]"

If the game window shows `(Modded)` in the title, setup was successful.

See the [Wiki](https://github.com/GodotModding/godot-mod-loader/wiki) for more details. 

## Modding

Use these [Helper Methods](https://github.com/GodotModding/godot-mod-loader/wiki/Helper-Methods) and
[CLI Args](https://github.com/GodotModding/godot-mod-loader/wiki/CLI-Args).
For more info, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md), upon which ModLoader is based. The docs there cover mod setup in much greater detail.

## Credits

🔥 ModLoader is based on the work of these brilliant people 🔥

- [Delta-V-Modding](https://gitlab.com/Delta-V-Modding/Mods)
