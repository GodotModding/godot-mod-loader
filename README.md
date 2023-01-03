# GDScript Mod Loader

A general purpose mod-loader for GDScript-based Godot Games.

For detailed info, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md), upon which ModLoader is based. The docs there cover mod setup and helper functions in much greater detail.

## Mod Setup

Mods you create must have the following 2 files:

- **ModMain.gd** - The init file for your mod.
- **_meta.json** - Meta data for your mod (see below).

### Example _meta.json

```json
{
	"id": "AuthorName-ModName",
	"name": "Mod Name",
	"version": "1.0.0",
	"compatible_game_version": ["0.6.1.6"],
	"authors": ["AuthorName"],
	"description": "Mod description goes here",
	"website_url": "",
	"dependencies": [
		"Add IDs of other mods here, if your mod needs them to work"
	],
	"incompatibilities": [
		"Add IDs of other mods here, if your mod conflicts with them"
	]
}
```

#### Notes

Some properties in the JSON are not checke din the code (ATOW), and are only used for reference by yourself and your mod's users. These are:

- `version`
- `compatible_game_version`
- `authors`
- `description`
- `website_url`


## Helper Methods

Use these when creating your mods. As above, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md) for more details.

### installScriptExtension

	installScriptExtension(childScriptPath:String)

Add a script that extends a vanilla script. `childScriptPath` is the path to your mod's extender script path, eg `MOD/extensions/singletons/utils.gd`.

Inside that extender script, it should include `extends {target}`, where {target} is the vanilla path, eg: `extends "res://singletons/utils.gd"`.

Note that your extender script doesn't have to follow the same directory path as the vanilla file, but it's good practice to do so.

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


## Credits

🔥 ModLoader is based on the work of these brilliant people 🔥

- [Delta-V-Modding](https://gitlab.com/Delta-V-Modding/Mods)
