# GDScript Mod Loader

A general purpose mod-loader for GDScript-based Godot Games.

For detailed info, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md), upon which ModLoader is based. The docs there cover mod setup and helper functions in much greater detail.

## Mod Setup

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
            "compatible_modloader_version": "3.0.0",
			"compatible_game_version": ["0.6.1.6"],
            "config_defaults": {}
		}
	}
}
```

See `get_mod_config` below for info on `config_defaults`.

## Helper Methods

Use these when creating your mods. As above, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md) for more details.

### installScriptExtension

	installScriptExtension(childScriptPath:String)

Add a script that extends a vanilla script. `childScriptPath` is the path to your mod's extender script path, eg `MOD/extensions/singletons/utils.gd`.

Inside that extender script, it should include `extends {target}`, where {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.

Your extender scripts don't have to follow the same directory path as the vanilla file, but it's good practice to do so.

One approach to organising your extender scripts is to put them in a dedicated folder named "extensions", eg:

```
yourmod.zip
├───.import
└───mods-unpacked
    └───Author-ModName
        ├───mod_main.gd
        ├───manifest.json
        └───extensions
            └───Any files that extend vanilla code can go here, eg:
            ├───main.gd
            └───singletons
                ├───item_service.gd
                └───debug_service.gd
```

### addTranslationFromResource

	addTranslationFromResource(resourcePath: String)

Add a translation file, eg "mytranslation.en.translation". The translation file should have been created in Godot already: When you import a CSV, such a file will be created for you.

Note that this function is exclusive to ModLoader, and departs from Delta-V's two functions [addTranslationsFromCSV](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md#addtranslationsfromcsv) and [addTranslationsFromJSON](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md#addtranslationsfromjson), which aren't available in ModLoader.

### appendNodeInScene

	appendNodeInScene(modifiedScene, nodeName:String = "", nodeParent = null, instancePath:String = "", isVisible:bool = true)

Create and add a node to a instanced scene.

### saveScene

	saveScene(modifiedScene, scenePath:String)

Save the scene as a PackedScene, overwriting Godot's cache if needed.

### get_mod_config

    get_mod_config(mod_id:String = "", key:String = "", default_value = null)->Dictionary:

Get data from a mod's config JSON file. Configs are added by users, to a folder named *configs* (`res://configs`). They are named by the mod ID (eg. `AuthorName-ModName.json`).

Returns a dictionary with three keys: `data`, `error`, and `error_msg`.

#### Data

Data (`data`) is either the full config, or data from a specific key if one was specified. If an error occured, `data` is an empty dictionary (`{}`).

#### Error

Error (`error`) is `0` if there were no errors, or `> 0` if the setting could not be retrieved:

| #   | Description |
| --- | ----------- |
| `0` | No errors |
| `1` | Invalid mod ID |
| `2` | No custom JSON (file probably does not exist). Defaults will be used |
| `3` | No custom JSON, and `key` was not present in your mod's defaults |
| `4` | Invalid `key`, although config data does exists |

#### Error Msg

Text representation of the error that occured, intended to make debugging easier.

### Defaults

If no custom JSON file exists, your mod's default settings will be returned as `data`. This only applies if you're not using a `key`, or the `key` you provide exists in your defaults.

Default settings are set in your *manifest.json* file, via `extra.godot.config_defaults`.


### Config Options

A user's custom config file can use a special setting, `load_from`. If specified, their config is loaded from the specified file, instead of the file named after the mod ID.

The `load_from` JSON file should be in the same directory, and include the file extension, eg:

```json
{
    "load_from": "my-special-config.json"
}
```

This allows users to multiple config files for a single mod and switch between them quickly. This settings is ignord if the filename matches the mod ID, or is empty.


## Credits

🔥 ModLoader is based on the work of these brilliant people 🔥

- [Delta-V-Modding](https://gitlab.com/Delta-V-Modding/Mods)
