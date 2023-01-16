# GDScript Mod Loader

A general purpose mod-loader for GDScript-based Godot Games.

See the [Wiki](https://github.com/GodotModding/godot-mod-loader/wiki) for additional details, including [Helper Methods](https://github.com/GodotModding/godot-mod-loader/wiki/Helper-Methods) and [CLI Args](https://github.com/GodotModding/godot-mod-loader/wiki/CLI-Args).


## Mod Setup

For more info, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md), upon which ModLoader is based. The docs there cover mod setup in much greater detail.

### Structure

Mod ZIPs should have the structure shown below. The name of the ZIP is arbitrary.

```
yourmod.zip
├───.import
└───mods-unpacked
    └───Author-ModName
        ├───mod_main.gd
        └───manifest.json
```

#### Notes on .import

Adding the .import directory is only needed when your mod adds content such as PNGs and sound files. In these cases, your mod's .import folder should **only** include your custom assets, and should not include any vanilla files.

You can copy your custom assets from your project's .import directory. They can be easily identified by sorting by date. To clean up unused files, it's helpful to delete everything in .import that's not vanilla, then run the game again, which will re-create only the files that are actually used.


### Required Files

Mods you create must have the following 2 files:

- **mod_main.gd** - The init file for your mod.
- **manifest.json** - Meta data for your mod (see below).

#### Example manifest.json

```json
{
    "name": "ModName",
    "version": "1.0.0",
    "description": "Mod description goes here",
    "website_url": "https://github.com/example/repo",
    "dependencies": [
		"Add IDs of other mods here, if your mod needs them to work"
    ],
    "extra": {
        "godot": {
            "id": "AuthorName-ModName",
            "incompatibilities": [
				"Add IDs of other mods here, if your mod conflicts with them"
			],
            "authors": ["AuthorName"],
            "compatible_game_version": ["0.6.1.6"],
        }
    }
}
```

## Credits

🔥 ModLoader is based on the work of these brilliant people 🔥

- [Delta-V-Modding](https://gitlab.com/Delta-V-Modding/Mods)
