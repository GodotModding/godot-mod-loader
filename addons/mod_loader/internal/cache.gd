class_name _ModLoaderCache
extends Reference


# This Class provides methods for caching data.

const CACHE_FILE_PATH = "user://ModLoaderCache.json"
const LOG_NAME = "ModLoader:Cache"


# ModLoaderStore is passed as parameter so the cache data can be loaded on ModLoaderStore._init()
static func init_cache(_ModLoaderStore) -> void:
	if not _ModLoaderFile.file_exists(CACHE_FILE_PATH):
		_init_cache_file()
		return

	_load_file(_ModLoaderStore)


static func add_data(key: String, data: Dictionary) -> void:
	if ModLoaderStore.cache.has(key):
		ModLoaderLog.error("key: \"%s\" already exists in \"ModLoaderStore.cache\"" % key, LOG_NAME)
		return

	ModLoaderStore.cache[key] = data


static func get_data(key: String) -> Dictionary:
	if not ModLoaderStore.cache.has(key):
		ModLoaderLog.error("key: \"%s\" not found in \"ModLoaderStore.cache\"" % key, LOG_NAME)
		return {}

	return ModLoaderStore.cache[key]


static func get_cache() -> Dictionary:
	return ModLoaderStore.cache


static func has_key(key: String) -> bool:
	return ModLoaderStore.cache.has(key)


static func update_data(key: String, data: Dictionary) -> Dictionary:
	# If the key exists
	if has_key(key):
		# Update the data
		ModLoaderStore.cache[key].merge(data, true)
	else:
		ModLoaderLog.info("key: \"%s\" not found in \"ModLoaderStore.cache\" added as new data instead." % key, LOG_NAME, true)
		# Else add new data
		add_data(key, data)

	return ModLoaderStore.cache[key]


static func remove_data(key: String) -> void:
	if not ModLoaderStore.cache.has(key):
		ModLoaderLog.error("key: \"%s\" not found in \"ModLoaderStore.cache\"" % key, LOG_NAME)
		return

	ModLoaderStore.cache.erase(key)


static func save_to_file() -> void:
	_ModLoaderFile.save_dictionary_to_json_file(ModLoaderStore.cache, CACHE_FILE_PATH)


# ModLoaderStore is passed as parameter so the cache data can be loaded on ModLoaderStore._init()
static func _load_file(_ModLoaderStore = ModLoaderStore) -> void:
	_ModLoaderStore.cache = _ModLoaderFile.get_json_as_dict(CACHE_FILE_PATH)


# Create empty cache file
static func _init_cache_file() -> void:
	_ModLoaderFile.save_dictionary_to_json_file({}, CACHE_FILE_PATH)
