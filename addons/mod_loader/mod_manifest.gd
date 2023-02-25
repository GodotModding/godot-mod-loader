extends Resource
# Stores and validates contents of the manifest set by the user
class_name ModManifest

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

var authors: PoolStringArray = []
# only used for information
var compatible_game_version: PoolStringArray = []
# only used for information
var incompatibilities: PoolStringArray = []
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
	config_defaults = godot_details.config_defaults

	var mod_id = get_mod_id()
	if not validate_dependencies_and_incompatibilities(mod_id, dependencies, incompatibilities):
		return

	# todo load file named icon.png when loading mods and use here
#	image StreamTexture


# Mod ID used in the mod loader
# Format: {namespace}-{name}
func get_mod_id() -> String:
	return "%s-%s" % [namespace, name]


# Package ID used by Thunderstore
# Format: {namespace}-{name}-{version_number}
func get_package_id() -> String:
	return "%s-%s-%s" % [namespace, name, version_number]


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


# A valid semantic version should follow this format: {mayor}.{minor}.{patch}
# reference https://semver.org/ for details
# {0-9}.{0-9}.{0-9} (no leading 0, shorter than 16 characters total)
static func is_semver_valid(check_version_number: String, is_silent := false) -> bool:
	var re := RegEx.new()
	var _compile_error = re.compile("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$")

	if re.search(check_version_number) == null:
		if not is_silent:
			ModLoaderUtils.log_fatal('Invalid semantic version: "%s". ' +
				'You may only use numbers without leading zero and periods following this format {mayor}.{minor}.{patch}' % check_version_number,
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


static func validate_dependencies_and_incompatibilities(mod_id: String, dependencies: PoolStringArray, incompatibilities: PoolStringArray, is_silent := false) -> bool:
	var valid_dep = true
	var valid_inc = true

	if dependencies.size() > 0:
		for dep in dependencies:
			valid_dep = is_mod_id_valid(mod_id, dep, "dependency", is_silent)

	if incompatibilities.size() > 0:
		for inc in incompatibilities:
			valid_inc = is_mod_id_valid(mod_id, inc, "incompatibility", is_silent)

	if not valid_dep or not valid_inc:
		return false

	return true


static func is_mod_id_valid(original_mod_id: String, check_mod_id: String, type := "", is_silent := false) -> bool:
	var intro_text = "A %s for the mod '%s' is invalid: " % [type, original_mod_id] if not type == "" else ""

	# contains hyphen?
	if not check_mod_id.count("-") == 1:
		if not is_silent:
			ModLoaderUtils.log_fatal(str(intro_text, 'Expected a single hypen in the mod ID, but the %s was: "%s"' % [type, check_mod_id]), LOG_NAME)
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


# Returns an empty String if the key does not exist
static func _get_string_from_dict(dict: Dictionary, key: String) -> String:
	if not dict.has(key):
		return ""
	return dict[key]


# Returns an empty Array if the key does not exist
static func _get_array_from_dict(dict: Dictionary, key: String) -> Array:
	if not dict.has(key):
		return []
	return dict[key]


# Works like [method Dictionary.has_all],
# but allows for more specific errors if a field is missing
static func dict_has_fields(dict: Dictionary, required_fields: Array) -> bool:
	var missing_fields := required_fields

	for key in dict.keys():
		if(required_fields.has(key)):
			missing_fields.erase(key)

	if missing_fields.size() > 0:
		ModLoaderUtils.log_fatal("Mod manifest is missing required fields: %s" % missing_fields, LOG_NAME)
		return false

	return true


#func _to_json()	-> String:
#	return ""

