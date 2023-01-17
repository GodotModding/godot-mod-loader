extends Resource
## Stores and validates contents of the manifest set by the user
class_name ModManifest


## Mod name.
## Validated by [method is_name_or_namespace_valid]
var name := ""
## Mod namespace, most commonly the main author.
## Validated by [method is_name_or_namespace_valid]
var namespace := ""
## Semantic version. Not a number, but required to be named like this by Thunderstore
## Validated by [method is_semver_valid]
var version_number := "0.0.0"
var description := ""
var website_url := ""
## Used to determine mod load order
var dependencies := []				# Array[String]

var authors := [] 					# Array[String]
## only used for information
var compatible_game_version := [] 	# Array[String]
## only used for information
var incompatibilities := [] 			# Array[String]
var tags := [] 						# Array[String]
var description_rich := ""
var image: StreamTexture


## Required keys in a mod's manifest.json file
const REQUIRED_MANIFEST_KEYS_ROOT = [
	"name",
	"namespace",
	"version_number",
	"website_url",
	"description",
	"dependencies",
	"extra",
]

## Required keys in manifest's `json.extra.godot`
const REQUIRED_MANIFEST_KEYS_EXTRA = [
	"authors",
	"compatible_mod_loader_version",
	"compatible_game_version",
	"incompatibilities",
	"config_defaults",
]


## Takes the manifest as [Dictionary] and validates everything.
## Will return null if something is invalid.
func _init(manifest: Dictionary) -> void:
	if (not dict_has_fields(manifest, REQUIRED_MANIFEST_KEYS_ROOT) or
		not dict_has_fields(manifest.extra, ["godot"]) or
		not dict_has_fields(manifest.extra.godot, REQUIRED_MANIFEST_KEYS_EXTRA)):
			return

	name = manifest.name
	namespace = manifest.namespace
	version_number = manifest.version_number
	if (not is_name_or_namespace_valid(name) or
		not is_name_or_namespace_valid(namespace) or
		not is_semver_valid(version_number)):
			return

	description = manifest.description
	website_url = manifest.website_url
	dependencies = manifest.dependencies

	var 	godot_details: Dictionary = manifest.extra.godot
	authors = _get_array_from_dict(godot_details, "authors")
	incompatibilities = _get_array_from_dict(godot_details, "incompatibilities")
	compatible_game_version = _get_array_from_dict(godot_details, "compatible_game_version")
	description_rich = _get_string_from_dict(godot_details, "description_rich")
	tags = _get_array_from_dict(godot_details, "tags")

	# todo load file named icon.png when loading mods and use here
#	image StreamTexture


## Mod ID used in the mod loader
## Format: {namespace}-{name}
func get_mod_id() -> String:
	return "%s-%s" % [namespace, name]


## Package ID used by Thunderstore
## Format: {namespace}-{name}-{version_number}
func get_package_id() -> String:
	return "%s-%s-%s" % [namespace, name, version_number]


## A valid namespace may only use letters (any case), numbers and underscores
## and has to be longer than 3 characters
## /^[a-zA-Z0-9_]{3,}$/
static func is_name_or_namespace_valid(name: String) -> bool:
	var re := RegEx.new()
	re.compile("^[a-zA-Z0-9_]*$") # alphanumeric and _

	if re.search(name) == null:
		printerr('Invalid name or namespace: "%s". You may only use letters, numbers and underscores.' % name)
		return false

	re.compile("^[a-zA-Z0-9_]{3,}$") # at least 3 long
	if re.search(name) == null:
		printerr('Invalid name or namespace: "%s". Must be longer than 3 characters.' % name)
		return false

	return true


## A valid semantic version should follow this format: {mayor}.{minor}.{patch}
## reference https://semver.org/ for details
## /^[0-9]+\\.[0-9]+\\.[0-9]+$/
static func is_semver_valid(version_number: String) -> bool:
	var re := RegEx.new()
	re.compile("^[0-9]+\\.[0-9]+\\.[0-9]+$")

	if re.search(version_number) == null:
		printerr('Invalid semantic version: "%s". ' +
		'You may only use numbers and periods in this format {mayor}.{minor}.{patch}' % version_number)
		return false

	return true


## Returns an empty String if the key does not exist
static func _get_string_from_dict(dict: Dictionary, key: String) -> String:
	if not dict.has(key):
		return ""
	return dict[key]


## Returns an empty Array if the key does not exist
static func _get_array_from_dict(dict: Dictionary, key: String) -> Array:
	if not dict.has(key):
		return []
	return dict[key]


## Works like [method Dictionary.has_all],
## but allows for more specific errors if a field is missing
static func dict_has_fields(dict: Dictionary, required_fields: Array) -> bool:
	var missing_fields := required_fields

	for key in dict.keys():
		if(required_fields.has(key)):
			missing_fields.erase(key)

	if missing_fields.size() > 0:
		printerr("Mod data is missing required fields: " + str(missing_fields))
		return false

	return true


#func _to_json()	-> String:
#	return ""

