# GDScript Mod Loader

A general purpose mod-loader for GDScript-based Godot Games.

## Table of Contents
<!-- TOC -->
* [For Mod Users](#for-mod-users)
  * [Mod Loader Setup](#mod-loader-setup)
  * [Installing mods](#installing-mods)
  * [For Mod Developers](#for-mod-developers)
    * [Development Setup](#development-setup)
    * [Developing a Mod](#developing-a-mod)
    * [Structure](#structure)
    * [Required Files](#required-files)
    * [Helper Methods](#helper-methods)
      * [installScriptExtension](#installscriptextension)
      * [addTranslationFromResource](#addtranslationfromresource)
      * [appendNodeInScene](#appendnodeinscene)
      * [saveScene](#savescene)
  * [For Game Developers](#for-game-developers)
    * [How to integrate the ModLoader into a game](#how-to-integrate-the-modloader-into-a-game)
  * [For Mod Loader Developers](#for-mod-loader-developers)
    * [Clean Setup](#clean-setup)
  * [For Everyone](#for-everyone)
    * [Folder locations](#folder-locations)
  * [Credits](#credits)
<!-- TOC -->


## For Mod Users
### Mod Loader Setup
If the game you want to mod does not natively use this ModLoader, you will have to complete two steps to set it up:
1. Place the `/addons` folder from the ModLoader next to the executable of the game you want to mod.
2. set this flag `--script addons/mod_loader_tools/mod_loader_setup_helper.gd`
   - Steam: right-click the game in the game list > press `properties` > enter in `startup options` 
   - Godot: Project Settings > press `Editor` > enter in `Main Run Args`
   - Other: Search for "set launch (or command line) parameters [your platform]"

If the game window shows `(Modded)` in the title, setup was successful.
This renaming of the game will also move all logs, saves and other game data to a folder 
inside `app_userdata/<game name> (Modded)`. If the game had settings (like keybindings)
in that folder, don't forget to copy them over.

In more detail:

The mod loader comes with a little helper script to properly install itself without having to recompile a game's source.
This works by using Godot's functionality to override project settings with a file named `override.cfg`.
Since the override also saves all other Project settings, it's important to recreate this file after the game is updated (This can be done with one button press in the mod selection screen).

Use this flag to skip the mod selection screen (or tick the box in the selection screen)
`--skip-mod-selection`

Holding <kbd>ALT</kbd> during startup will invert the behavior: 
skip selection screen without the skip flag and show it with the skip flag

### Installing mods
First, you will have to download a mod for your game. When downloading a mod always keep the basics in mind: 
1. always confirm your sources are trustworthy 
   - (yes, even your friends, it could be someone else using their account) 
2. check the mod sources yourself or have someone else check for obvious bad stuff, for example:
   - random executables
   - a mod using the OS class (has access to your computer system)
   - something that's not an asset 
   - something that's not game code (not .gd)
3. if unsure, better ask the community!

Sources to download from are -
Steam workshop, for officially supported Steam games
Thunderstore, for unsupported and non-Steam games
Official Discord communities (be careful)

Have a mod? Good. Don't unzip it and place it inside the `mods` folder alongside the game (see [Folder locations](#folder-locations))

## For Mod Developers

### Development Setup

**Prerequisites**
- [Godot RE (Reverse Engineering) Tools](https://github.com/bruvzg/gdsdecomp/releases)
  - [The Godot game engine](https://godotengine.org/download) in the version mentioned by GDRE (probably 3.5)

**Decompiling the game you want to mod**
   1. Open up Godot RE Tools
   2. (top left) press `Godot RE Tools` and then `recover project`
   3. navigate to the game folder (or paste the path into the top input)
   4. select the `.exe` (Windows) or `.pck` (Mac) or, most likely, `.x86_64` (Linux)
   5. enter a destination folder for the decompiled game
   6. press `full recovery`, wait till done

Congratulations! You've successfully decompiled the game. 
> `Note:` do not share any of these files unless you get explicit permission from the developer

**Running the game from the Godot editor**

When opening the project for the first time: 
- select `import` (on the right) and navigate to the destination folder you previously selected. 
Select the `project.godot` file and press `open and edit`.
  - To run the game, press the Play triangle button in the top right.

> `Note for Steam Games:`
> 
> Most Steam games use a special SDK for achievements and such. 
> For us, that isn't relevant, but it will cause errors. 
> There are two ways to get around them which depend on personal preference.
> 1. Use a special version of Godot (download: https://godotsteam.com/) or
> 2. just comment the code away.
> You will have to run the game a bunch of times and every time it crashes, 
> comment it out. If you have to remove a full function, instead if removing it and having 
> to track where it is called, you can just use the keyword `pass` to make it do nothing.
> 
> ```gdscript
> func _ready():
> 	load_save()
> #	Steam.connect("overlay_toggled", self, "steam_overlay_toggled")
> 
> func _on_reset_achievements_button_pressed():
> 	pass
> #	Steam.resetAllStats(true)
> ```


### Developing a Mod

First off, if the game you want to mod does not have this ModLoader installed already, consider bringing it up to the developer for them to consider. 
Second off, there are some limitations if that's the case. There is no way to modify autoload (singleton) behavior, since the load order of 
them can't be overridden due to some strange behavior in Godot's way of overriding them.

#### Where to start?

Download the starterkit mod fitting your game from this repository [Starter Kit Mods]()
place it inside the `mods-unpacked` directory alongside the game executable (see [Folder locations](#folder-locations))

> `Note:`
> Due to packs overriding stuff when loaded in the editor, you will have to unzip and place all mods that you want to have active during 
> development (dependencies and so on) in `/mods-unpacked` 

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

> `Notes on .import`
> 
> Adding the .import directory is only needed when your mod adds content such as PNGs and sound files. 
> In these cases, your mod's .import folder should **only** include your custom assets, and should not 
> include any vanilla files.
> 
> You can copy your custom assets from your project's .import directory. They can be easily identified by sorting by date. 
> To clean up unused files, it's helpful to delete everything in .import that's not vanilla, then run the game again, 
> which will re-create only the files that are actually used.


### Required Files

Mods you create must have the following 2 files:

- `mod_main.gd` - The init file for your mod.
- `manifest.json` - Metadata for your mod (see below).

**Example `manifest.json`**

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
            "compatible_game_version": ["0.6.1.6"]
        }
    }
}
```

> `Notes`
> 
> Some properties in the JSON are not checked in the code, and are only used for reference by yourself and your mod's users. These are:
> 
> - `version`
> - `compatible_game_version`
> - `authors`
> - `description`
> - `website_url`


### Helper Methods

Use these when creating your mods.
For detailed info, see the [docs for Delta-V Modding](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md),
upon which ModLoader is based. They cover mod setup and helper functions in much greater detail.

#### install_script_extension

	func install_script_extension(child_script_path:String)

Add a script that extends a vanilla script. `child_script_path` is the path to your mod's extender script path, eg `MOD/extensions/singletons/utils.gd`.

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

#### add_translation_from_resource

	add_translation_from_resource(resource_path: String)

Add a translation file, eg "mytranslation.en.translation". The translation file should have been created in Godot already: When you import a CSV, such a file will be created for you.

Note that this function is exclusive to ModLoader, and departs from Delta-V's two functions [addTranslationsFromCSV](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md#addtranslationsfromcsv) and [addTranslationsFromJSON](https://gitlab.com/Delta-V-Modding/Mods/-/blob/main/MODDING.md#addtranslationsfromjson), which aren't available in ModLoader.

#### append_node_in_scene

	append_node_in_scene(modified_scene, node_name:String = "", node_parent = null, instance_path:String = "", is_visible:bool = true)

Create and add a node to an instanced scene.

#### save_scene

	save_scene(modified_scene, scenePath:String)

Save the scene as a PackedScene, overwriting Godot's cache if needed.



## For Game Developers

### How to integrate the ModLoader into a game

If the ModLoader is integrated into the source, the `--script` flag to use and set up the mod loader will not be necessary. This is the most optimal way to use it. 
To do that, you only have to add the `ModLoader` as the first autoload.

To properly do it, you will have to register the `ModLoader` script as an autoload. All helper classes will automatically be set as global classes by Godot.


## For Mod Loader Developers

### Clean Setup

Clone this repository.
The easiest way to keep git and the games you are working in clean, is to symbolically 
link the `mod_loader_tools` directory into the `addons` folder of any Godot project, 
or to symlink the `addons` folder besides any Godot game executable 

Windows 
```shell
mklink \d <path to godot-mod-loader/addons/mod_loader_tools> <path to addons>
```
Mac/Linux
```shell
ln -s <path to godot-mod-loader/addons/mod_loader_tools> <path to addons>
```

This way you can edit the mod loader any game (even multiple at once) while source control and all the other documents
can stay in the directory you cloned them into.


## For Everyone

### Folder locations

**Game Executable:**

Right-click the game on steam > press `manage` > press `browse local files`. You should be within a folder with the same name as the game.

(for MacOS the actual executable is in `/Contents/MacOS` within that folder, but you are still at the right place, 
only the override needs to be placed there, everything else goes right here)


**User Data:**
- Windows: `%appdata%\Godot\app_userdata\<game name>`
  - Linux: `~/.local/share/godot/app_userdata/<game name>`
  - Mac: `~/Library/Application Support/Godot/app_userdata/<game name>`


> `Note:` 
> Opening the Godot Project with the `override.cfg` file present can lead to Godot setting all 
> those values in the project settings, especially in 3.4. 
> This is a bug (https://github.com/godotengine/godot/issues/30912). Opening the project after that 
> will not revert those changes. It is the quickest way to set up the loader, but can also lead to confusion.


## Credits

🔥 ModLoader is based on the work of these brilliant people 🔥

- [Delta-V-Modding](https://gitlab.com/Delta-V-Modding/Mods)


