class_name ModManifest
extends Resource

# Stores and validates contents of the manifest set by the user

const LOG_NAME := "ModLoader:ModManifest"

# Mod name.
# Validated by [method is_name_or_namespace_valid]
var name := ""
# Mod namespace, most commonly the main author.
# Validated by [method is_name_or_namespace_valid]
var namespace := ""
# Semantic version. Not a number, but required to be named like this by Thunderstore
# Validated by [method is_semver_valid]
var version_number := "0.0.0"
var description := ""
var website_url := ""
# Used to determine mod load order
var dependencies: PoolStringArray = []
# Used to determine mod load order
var optional_dependencies: PoolStringArray = []

var authors: PoolStringArray = []
# only used for information
var compatible_game_version: PoolStringArray = []
# only used for information
# Validated by [method _handle_compatible_mod_loader_version]
var compatible_mod_loader_version: PoolStringArray = []
# only used for information
var incompatibilities: PoolStringArray = []
var load_before: PoolStringArray = []
var tags : PoolStringArray = []
var config_defaults := {}
var description_rich := ""
var image: StreamTexture


# Required keys in a mod's manifest.json file
const REQUIRED_MANIFEST_KEYS_ROOT = [
	"name",
	"namespace",
	"version_number",
	"website_url",
	"description",
	"dependencies",
	"extra",
]

# Required keys in manifest's `json.extra.godot`
const REQUIRED_MANIFEST_KEYS_EXTRA = [
	"authors",
	"compatible_mod_loader_version",
	"compatible_game_version",
	"incompatibilities",
	"config_defaults",
]


# Takes the manifest as [Dictionary] and validates everything.
# Will return null if something is invalid.
func _init(manifest: Dictionary) -> void:
	if (not ModLoaderUtils.dict_has_fields(manifest, REQUIRED_MANIFEST_KEYS_ROOT) or
		not ModLoaderUtils.dict_has_fields(manifest.extra, ["godot"]) or
		not ModLoaderUtils.dict_has_fields(manifest.extra.godot, REQUIRED_MANIFEST_KEYS_EXTRA)):
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

	var godot_details: Dictionary = manifest.extra.godot
	authors = ModLoaderUtils.get_array_from_dict(godot_details, "authors")
	optional_dependencies = ModLoaderUtils.get_array_from_dict(godot_details, "optional_dependencies")
	incompatibilities = ModLoaderUtils.get_array_from_dict(godot_details, "incompatibilities")
	load_before = ModLoaderUtils.get_array_from_dict(godot_details, "load_before")
	compatible_game_version = ModLoaderUtils.get_array_from_dict(godot_details, "compatible_game_version")
	compatible_mod_loader_version = _handle_compatible_mod_loader_version(godot_details)
	description_rich = ModLoaderUtils.get_string_from_dict(godot_details, "description_rich")
	tags = ModLoaderUtils.get_array_from_dict(godot_details, "tags")
	config_defaults = godot_details.config_defaults

	var mod_id = get_mod_id()
	if (not is_mod_id_array_valid(mod_id, dependencies, "dependency") or
		not is_mod_id_array_valid(mod_id, incompatibilities, "incompatibility") or
		not is_mod_id_array_valid(mod_id, optional_dependencies, "optional_dependency") or
		not validate_distinct_mod_ids_in_arrays(
			mod_id,
			dependencies,
			incompatibilities,
			["dependencies", "incompatibilities"]
		) or
		not validate_distinct_mod_ids_in_arrays(
			mod_id,
			optional_dependencies,
			incompatibilities,
			["optional_dependencies", "incompatibilities"]
		)):
		return


# Mod ID used in the mod loader
# Format: {namespace}-{name}
func get_mod_id() -> String:
	return "%s-%s" % [namespace, name]


# Package ID used by Thunderstore
# Format: {namespace}-{name}-{version_number}
func get_package_id() -> String:
	return "%s-%s-%s" % [namespace, name, version_number]


# Returns the Manifest values as a dictionary
func get_as_dict() -> Dictionary:
	return {
		"name": name,
		"namespace": namespace,
		"version_number": version_number,
		"description": description,
		"website_url": website_url,
		"dependencies": dependencies,
		"optional_dependencies": optional_dependencies,
		"authors": authors,
		"compatible_game_version": compatible_game_version,
		"compatible_mod_loader_version": compatible_mod_loader_version,
		"incompatibilities": incompatibilities,
		"load_before": load_before,
		"tags": tags,
		"config_defaults": config_defaults,
		"description_rich": description_rich,
		"image": image,
	}


# Returns the Manifest values as JSON, in the manifest.json format
func to_json() -> String:
	return JSON.print({
		"name": name,
		"namespace": namespace,
		"version_number": version_number,
		"description": description,
		"website_url": website_url,
		"dependencies": dependencies,
		"extra": {
			"godot":{
				"authors": authors,
				"optional_dependencies": optional_dependencies,
				"compatible_game_version": compatible_game_version,
				"compatible_mod_loader_version": compatible_mod_loader_version,
				"incompatibilities": incompatibilities,
				"load_before": load_before,
				"tags": tags,
				"config_defaults": config_defaults,
				"description_rich": description_rich,
				"image": image,
			}
		}
	}, "\t")


# Handles deprecation of the single string value in the compatible_mod_loader_version.
func _handle_compatible_mod_loader_version(godot_details: Dictionary) -> Array:
	var link_manifest_docs := "https://github.com/GodotModding/godot-mod-loader/wiki/Mod-Files#manifestjson"
	var array_value := ModLoaderUtils.get_array_from_dict(godot_details, "compatible_mod_loader_version")

	# If there are array values
	if array_value.size() > 0:
		# Check for valid versions
		if not is_semver_version_array_valid(array_value):
			return []

		return array_value

	# If the array is empty check if a string was passed
	var string_value := ModLoaderUtils.get_string_from_dict(godot_details, "compatible_mod_loader_version")
	# If an empty string was passed
	if string_value == "":
		ModLoaderUtils.log_error(
			"\"compatible_mod_loader_version\" is a required field." +
			" For more details visit " + link_manifest_docs,
			LOG_NAME
		)
		return []

	# If a string was passed
	ModLoaderDeprecated.deprecated_message(
		"The single String value for \"compatible_mod_loader_version\" is deprecated." +
		" Please provide an Array. For more details visit " + link_manifest_docs,
		"6.0.0"
	)
	return [string_value]


# A valid namespace may only use letters (any case), numbers and underscores
# and has to be longer than 3 characters
# a-z A-Z 0-9 _ (longer than 3 characters)
static func is_name_or_namespace_valid(check_name: String, is_silent := false) -> bool:
	var re := RegEx.new()
	var _compile_error_1 = re.compile("^[a-zA-Z0-9_]*$") # alphanumeric and _

	if re.search(check_name) == null:
		if not is_silent:
			ModLoaderUtils.log_fatal('Invalid name or namespace: "%s". You may only use letters, numbers and underscores.' % check_name, LOG_NAME)
		return false

	var _compile_error_2 = re.compile("^[a-zA-Z0-9_]{3,}$") # at least 3 long
	if re.search(check_name) == null:
		if not is_silent:
			ModLoaderUtils.log_fatal('Invalid name or namespace: "%s". Must be longer than 3 characters.' % check_name, LOG_NAME)
		return false

	return true


static func is_semver_version_array_valid(version_array: PoolStringArray, is_silent := false) -> bool:
	var is_valid := true

	for version in version_array:
		if not is_semver_valid(version, is_silent):
			is_valid = false

	return is_valid


# A valid semantic version should follow this format: {mayor}.{minor}.{patch}
# reference https://semver.org/ for details
# {0-9}.{0-9}.{0-9} (no leading 0, shorter than 16 characters total)
static func is_semver_valid(check_version_number: String, is_silent := false) -> bool:
	var re := RegEx.new()
	var _compile_error = re.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")

	if re.search(check_version_number) == null:
		if not is_silent:
			# Using str() here because format strings cause an error
			ModLoaderUtils.log_fatal(
				str(
					'Invalid semantic version: "%s".',
					'You may only use numbers without leading zero and periods',
					'following this format {mayor}.{minor}.{patch}'
				)  % check_version_number,
				LOG_NAME
			)
		return false

	if check_version_number.length() > 16:
		if not is_silent:
			ModLoaderUtils.log_fatal('Invalid semantic version: "%s". ' +
				'Version number must be shorter than 16 characters.', LOG_NAME
			)
		return false

	return true


static func validate_distinct_mod_ids_in_arrays(
	mod_id: String,
	array_one: PoolStringArray,
	array_two: PoolStringArray,
	array_description: PoolStringArray,
	is_silent := false
) -> bool:
	# Initialize an empty array to hold any overlaps.
	var overlaps: PoolStringArray = []

	# Loop through each incompatibility and check if it is also listed as a dependency.
	for mod_id in array_one:
		if array_two.has(mod_id):
			overlaps.push_back(mod_id)

	# If any overlaps were found, log a fatal error message and return true.
	if overlaps.size() > 0:
		if not is_silent:
			ModLoaderUtils.log_fatal(
				(
					"The mod -> %s lists the same mod(s) -> %s - in %s and %s"
					% [mod_id, overlaps, array_description[0], array_description[1]]
				),
				LOG_NAME
			)
		return true

	# If no overlaps were found, return false.
	return false


static func is_mod_id_array_valid(own_mod_id: String, mod_id_array: PoolStringArray, mod_id_array_description: String, is_silent := false) -> bool:
	var is_valid := true

	# If there are mod ids
	if mod_id_array.size() > 0:
		for mod_id in mod_id_array:
			# Check if mod id is the same as the mods mod id.
			if mod_id == own_mod_id:
				is_valid = false
				if not is_silent:
					ModLoaderUtils.log_fatal("The mod \"%s\" lists itself as \"%s\" in its own manifest.json file" % [mod_id, mod_id_array_description], LOG_NAME)

			# Check if the mod id is a valid mod id.
			if not is_mod_id_valid(own_mod_id, mod_id, mod_id_array_description, is_silent):
				is_valid = false

	return is_valid


static func is_mod_id_valid(original_mod_id: String, check_mod_id: String, type := "", is_silent := false) -> bool:
	var intro_text = "A %s for the mod '%s' is invalid: " % [type, original_mod_id] if not type == "" else ""

	# contains hyphen?
	if not check_mod_id.count("-") == 1:
		if not is_silent:
			ModLoaderUtils.log_fatal(str(intro_text, 'Expected a single hyphen in the mod ID, but the %s was: "%s"' % [type, check_mod_id]), LOG_NAME)
		return false

	# at least 7 long (1 for hyphen, 3 each for namespace/name)
	var mod_id_length = check_mod_id.length()
	if mod_id_length < 7:
		if not is_silent:
			ModLoaderUtils.log_fatal(str(intro_text, 'Mod ID for "%s" is too short. It must be at least 7 characters, but its length is: %s' % [check_mod_id, mod_id_length]), LOG_NAME)
		return false

	var split = check_mod_id.split("-")
	var check_namespace = split[0]
	var check_name = split[1]
	var re := RegEx.new()
	re.compile("^[a-zA-Z0-9_]*$") # alphanumeric and _

	if re.search(check_namespace) == null:
		if not is_silent:
			ModLoaderUtils.log_fatal(str(intro_text, 'Mod ID has an invalid namespace (author) for "%s". Namespace can only use letters, numbers and underscores, but was: "%s"' % [check_mod_id, check_namespace]), LOG_NAME)
		return false

	if re.search(check_name) == null:
		if not is_silent:
			ModLoaderUtils.log_fatal(str(intro_text, 'Mod ID has an invalid name for "%s". Name can only use letters, numbers and underscores, but was: "%s"' % [check_mod_id, check_name]), LOG_NAME)
		return false

	return true
