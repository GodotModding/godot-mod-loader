extends Resource
class_name ModDetails

var name := ""
var version_number := "v0.0.0"
var description := ""
var website_url := ""
var dependencies := [] # Array[String]

var id := ""
var authors := [] # Array[String]
var compatible_game_version := [] # Array[String]
var tags := [] # Array[String]
var description_rich := ""
var incompatibilities := [] # Array[String]
var image: StreamTexture


func _init(meta_data: Dictionary) -> void:
	if not dict_has_fields(meta_data, ModLoaderHelper.REQUIRED_MANIFEST_KEYS_ROOT):
		return

	var 	godot_details: Dictionary = meta_data.extra.godot
	if not godot_details:
		assert(false, "Extra details for Godot are missing")
		return

	if not dict_has_fields(godot_details, ModLoaderHelper.REQUIRED_MANIFEST_KEYS_EXTRA):
		return

	id = godot_details.id
	if not is_id_valid(id):
		return

	if not is_semver(meta_data.version_number):
		assert(false, "Version \"%s\" does not follow semantic versioning! see: README.md" % meta_data.version_number)

	name = meta_data.name
	version_number = meta_data.version_number
	description = meta_data.description
	website_url = meta_data.website_url
	dependencies = meta_data.dependencies

	if godot_details.has("authors"):
		authors = godot_details.authors
	if godot_details.has("incompatibilities"):
		incompatibilities = godot_details.incompatibilities
	if godot_details.has("compatible_game_version"):
		compatible_game_version = godot_details.compatible_game_version

	if godot_details.has("description_rich"):
		description_rich = godot_details.description_rich
	if godot_details.has("tags"):
		tags = godot_details.tags

	# todo load file named icon.png when loading mods and use here
#	image StreamTexture


func is_id_valid(id: String) -> bool:
	if id == "":
		assert(false, "Mod ID is empty")
		return false

	if false:
		assert(false, "Mod ID \"%s\" is not a valid ID" % id)

	# todo: validate id format
	return true


func is_alphanumeric(string: String) -> bool:
	# todo: implement

	# Returns true if this string is a valid identifier. A valid identifier may contain only letters, digits and underscores (_) and the first character may not be a digit.
	return string.is_valid_identifier()


func is_semver(version_number: String) -> bool:
	# todo implement
	return true


func dict_has_fields(dict: Dictionary, required_fields: Array) -> bool:
	var missing_fields := required_fields

	for key in dict.keys():
		if(required_fields.has(key)):
			missing_fields.erase(key)

	if missing_fields.size() > 0:
		assert(false, "Mod data is missing required fields: " + str(missing_fields))
		return false

	return true


#func _to_json()	-> String:
#	return ""

