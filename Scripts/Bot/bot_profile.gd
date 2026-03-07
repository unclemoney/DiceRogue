extends RefCounted
class_name BotProfile

## BotProfile
##
## Manages the bot's player profile as a JSON file.
## Mirrors key data from ProgressManager for the bot's own progression tracking.

const PROFILE_DIR := "user://bot_profiles/"
const PROFILE_PATH := "user://bot_profiles/bot_profile.json"

var data: Dictionary = {}


## reset()
##
## Resets the profile to default state.
func reset() -> void:
	data = _default_data()


## save_profile()
##
## Writes the current profile data to disk as JSON.
func save_profile() -> void:
	DirAccess.make_dir_recursive_absolute(PROFILE_DIR)
	var file = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


## load_profile() -> bool
##
## Loads profile from disk. Returns true if loaded successfully, false if
## no profile existed (a fresh default is created in that case).
func load_profile() -> bool:
	if not FileAccess.file_exists(PROFILE_PATH):
		reset()
		return false
	var file = FileAccess.open(PROFILE_PATH, FileAccess.READ)
	if not file:
		reset()
		return false
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("[BotProfile] Failed to parse profile JSON, resetting.")
		reset()
		return false
	data = json.data
	return true


## exists() -> bool
##
## Returns true if a saved profile file exists on disk.
func exists() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)


## get_total_games() -> int
func get_total_games() -> int:
	return data.get("total_games_played", 0)


## increment_games()
func increment_games() -> void:
	data["total_games_played"] = data.get("total_games_played", 0) + 1


## record_channel_win(channel: int)
func record_channel_win(channel: int) -> void:
	var wins: Dictionary = data.get("channel_wins", {})
	var key = str(channel)
	wins[key] = wins.get(key, 0) + 1
	data["channel_wins"] = wins
	var highest = data.get("highest_channel_completed", 0)
	if channel > highest:
		data["highest_channel_completed"] = channel


## _default_data() -> Dictionary
func _default_data() -> Dictionary:
	return {
		"total_games_played": 0,
		"total_games_won": 0,
		"total_games_lost": 0,
		"highest_channel_completed": 0,
		"channel_wins": {},
		"unlocked_items": [],
		"unlock_all_items": true,
		"created_at": Time.get_datetime_string_from_system(),
		"last_played": ""
	}


## should_unlock_all() -> bool
##
## Returns true if the profile wants all items unlocked.
func should_unlock_all() -> bool:
	return data.get("unlock_all_items", true)


## set_unlock_all(enabled: bool)
##
## Sets whether the bot should unlock all items at run start.
func set_unlock_all(enabled: bool) -> void:
	data["unlock_all_items"] = enabled


## add_unlocked_item(item_id: String)
##
## Adds a specific item to the bot's unlock list (used when unlock_all is false).
func add_unlocked_item(item_id: String) -> void:
	var items: Array = data.get("unlocked_items", [])
	if item_id not in items:
		items.append(item_id)
		data["unlocked_items"] = items


## remove_unlocked_item(item_id: String)
##
## Removes a specific item from the bot's unlock list.
func remove_unlocked_item(item_id: String) -> void:
	var items: Array = data.get("unlocked_items", [])
	items.erase(item_id)
	data["unlocked_items"] = items


## get_unlocked_items() -> Array
##
## Returns the list of specifically unlocked item IDs.
func get_unlocked_items() -> Array:
	return data.get("unlocked_items", [])
