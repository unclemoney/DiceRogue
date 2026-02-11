extends Node

## ProgressManager Autoload
##
## Manages player progress across games, including locked/unlocked PowerUps, Consumables,
## and Colored Dice features. Tracks game statistics and handles unlock condition checking.

# Preload the required classes
const UnlockConditionClass = preload("res://Scripts/Core/unlock_condition.gd")
const UnlockableItemClass = preload("res://Scripts/Core/unlockable_item.gd")

signal item_unlocked(item_id: String, item_type: String)
signal item_locked(item_id: String, item_type: String)  # For when items are locked
signal items_unlocked_batch(item_ids: Array[String])  # For showing notifications
signal progress_loaded
signal progress_saved
signal profile_loaded(slot: int)
signal profile_renamed(slot: int, new_name: String)

# Legacy save path (for auto-migration)
const LEGACY_SAVE_FILE_PATH := "user://progress.save"

# Profile save paths
const PROFILE_SAVE_PATHS := {
	1: "user://profile_1.save",
	2: "user://profile_2.save",
	3: "user://profile_3.save",
}

# Default profile names
const DEFAULT_PROFILE_NAMES := {
	1: "Player 1",
	2: "Player 2",
	3: "Player 3",
}

const PROFILE_NAME_MAX_LENGTH := 30

# Save version for profile format migration
# Version 1: Original format
# Version 2: Added chore tracking stats, difficulty ratings
const CURRENT_SAVE_VERSION := 2

signal profile_migration_needed(slot: int)  # Emitted when old profile detected

# Current active profile slot (1-3)
var current_profile_slot: int = 1
var current_profile_name: String = "Player 1"

# Tutorial tracking
var tutorial_completed: bool = false
var tutorial_in_progress: bool = false

# Core progress data
var unlockable_items: Dictionary = {}  # item_id -> UnlockableItem
var completed_channels: Array[int] = []  # Tracks which channels have been won
var cumulative_stats: Dictionary = {
	"games_completed": 0,
	"games_won": 0,
	"total_score": 0,
	"total_money_earned": 0,
	"total_consumables_used": 0,
	"total_yahtzees": 0,
	"total_straights": 0,
	"total_color_bonuses": 0,
	"highest_channel_completed": 0,
	"total_chores_completed": 0,
	"total_chores_completed_easy": 0,
	"total_chores_completed_hard": 0
}

# Current game tracking
var current_game_stats: Dictionary = {}
var is_tracking_game: bool = false

func _ready() -> void:
	add_to_group("progress_manager")
	print("[ProgressManager] Initializing progress tracking system")
	
	# Initialize default unlockable items FIRST (so they exist for loading)
	_create_default_unlockable_items()
	
	# Check for legacy save file and auto-migrate if needed
	_check_and_migrate_legacy_save()
	
	# Ensure all profile slots have save files
	_ensure_all_profiles_exist()
	
	# Get active profile slot from GameSettings if available
	var game_settings = get_node_or_null("/root/GameSettings")
	if game_settings:
		current_profile_slot = game_settings.active_profile_slot
	
	# Load the active profile
	load_profile(current_profile_slot)
	
	# Connect to game events
	_connect_to_game_systems()

## _check_and_migrate_legacy_save()
##
## Check for old progress.save file and migrate to profile_1.save if needed.
func _check_and_migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_FILE_PATH):
		return
	
	# Check if any profile already exists
	var any_profile_exists := false
	for slot in PROFILE_SAVE_PATHS.keys():
		if FileAccess.file_exists(PROFILE_SAVE_PATHS[slot]):
			any_profile_exists = true
			break
	
	if any_profile_exists:
		print("[ProgressManager] Profile files already exist, skipping migration")
		return
	
	print("[ProgressManager] Found legacy save file, migrating to profile slot 1...")
	
	# Read legacy save
	var file = FileAccess.open(LEGACY_SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[ProgressManager] Failed to open legacy save file for migration")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[ProgressManager] Failed to parse legacy save file JSON")
		return
	
	var save_data = json.get_data()
	
	# Add profile name and last_played to migrated data
	save_data["profile_name"] = "Player 1"
	save_data["last_played"] = Time.get_datetime_string_from_system()
	
	# Write to profile 1 slot
	var new_json_string = JSON.stringify(save_data, "\t")
	var new_file = FileAccess.open(PROFILE_SAVE_PATHS[1], FileAccess.WRITE)
	if new_file:
		new_file.store_string(new_json_string)
		new_file.close()
		print("[ProgressManager] Successfully migrated to profile_1.save")
		
		# Delete legacy file after successful migration
		DirAccess.remove_absolute(LEGACY_SAVE_FILE_PATH)
		print("[ProgressManager] Deleted legacy progress.save file")
	else:
		push_error("[ProgressManager] Failed to create profile_1.save during migration")


## _ensure_all_profiles_exist()
##
## Create default profile files for any slots that don't have save files.
func _ensure_all_profiles_exist() -> void:
	for slot in PROFILE_SAVE_PATHS.keys():
		if not FileAccess.file_exists(PROFILE_SAVE_PATHS[slot]):
			_create_default_profile(slot)


## _create_default_profile(slot)
##
## Create a new default profile save file for the given slot.
func _create_default_profile(slot: int) -> void:
	var default_data = {
		"save_version": CURRENT_SAVE_VERSION,
		"profile_name": DEFAULT_PROFILE_NAMES[slot],
		"last_played": "",
		"tutorial_completed": false,
		"tutorial_in_progress": false,
		"cumulative_stats": {
			"games_completed": 0,
			"games_won": 0,
			"total_score": 0,
			"total_money_earned": 0,
			"total_consumables_used": 0,
			"total_yahtzees": 0,
			"total_straights": 0,
			"total_color_bonuses": 0,
			"highest_channel_completed": 0,
			"total_chores_completed": 0,
			"total_chores_completed_easy": 0,
			"total_chores_completed_hard": 0
		},
		"completed_channels": [],
		"unlocked_items": []
	}
	
	var json_string = JSON.stringify(default_data, "\t")
	var file = FileAccess.open(PROFILE_SAVE_PATHS[slot], FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
		print("[ProgressManager] Created default profile for slot %d: %s" % [slot, DEFAULT_PROFILE_NAMES[slot]])
	else:
		push_error("[ProgressManager] Failed to create default profile for slot %d" % slot)


## load_profile(slot)
##
## Load a specific profile slot and update current progress data.
## Includes debug logging for profile sync issue investigation.
## @param slot: Profile slot number (1-3)
## @return bool: True if successful
func load_profile(slot: int) -> bool:
	print("[ProgressManager] ===== LOAD PROFILE START =====")
	print("[ProgressManager] Requested slot: %d" % slot)
	print("[ProgressManager] Current slot before load: %d" % current_profile_slot)
	print("[ProgressManager] Current name before load: %s" % current_profile_name)
	
	if slot < 1 or slot > 3:
		push_error("[ProgressManager] Invalid profile slot: %d" % slot)
		return false
	
	var save_path = PROFILE_SAVE_PATHS[slot]
	print("[ProgressManager] Loading from path: %s" % save_path)
	if not FileAccess.file_exists(save_path):
		print("[ProgressManager] Profile slot %d not found, creating default" % slot)
		_create_default_profile(slot)
	
	# Reset unlockable items to locked state before loading
	_reset_all_unlocks()
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		push_error("[ProgressManager] Failed to open profile %d save file" % slot)
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[ProgressManager] Failed to parse profile %d JSON" % slot)
		return false
	
	var save_data = json.get_data()
	
	# Check save version - delete outdated profiles and create fresh defaults
	var save_version = save_data.get("save_version", 1)
	if save_version < CURRENT_SAVE_VERSION:
		print("[ProgressManager] Outdated profile detected (v%d < v%d) in slot %d" % [save_version, CURRENT_SAVE_VERSION, slot])
		print("[ProgressManager] Deleting outdated profile and creating fresh default")
		profile_migration_needed.emit(slot)
		_create_default_profile(slot)
		# Re-read the fresh profile
		file = FileAccess.open(save_path, FileAccess.READ)
		if not file:
			push_error("[ProgressManager] Failed to open new profile %d" % slot)
			return false
		json_string = file.get_as_text()
		file.close()
		json = JSON.new()
		if json.parse(json_string) != OK:
			push_error("[ProgressManager] Failed to parse new profile %d" % slot)
			return false
		save_data = json.get_data()
	
	# Update current profile info
	current_profile_slot = slot
	current_profile_name = save_data.get("profile_name", DEFAULT_PROFILE_NAMES[slot])
	print("[ProgressManager] Updated current slot to: %d" % current_profile_slot)
	print("[ProgressManager] Updated current name to: %s" % current_profile_name)
	print("[ProgressManager] Profile name from save_data: %s" % save_data.get("profile_name", "NOT FOUND"))
	
	# Load tutorial flags
	tutorial_completed = save_data.get("tutorial_completed", false)
	tutorial_in_progress = save_data.get("tutorial_in_progress", false)
	
	# Load cumulative stats
	if save_data.has("cumulative_stats"):
		cumulative_stats = save_data["cumulative_stats"]
		if not cumulative_stats.has("highest_channel_completed"):
			cumulative_stats["highest_channel_completed"] = 0
	else:
		# IMPORTANT: Reset to defaults if not in save file
		cumulative_stats = _get_default_cumulative_stats()
		print("[ProgressManager] WARNING: No cumulative_stats in save, using defaults")
	
	# Load completed channels
	if save_data.has("completed_channels"):
		completed_channels.clear()
		for channel_num in save_data["completed_channels"]:
			completed_channels.append(int(channel_num))
	else:
		completed_channels.clear()
	
	# Load unlocked items
	var unlocked_count = 0
	if save_data.has("unlocked_items"):
		var unlocked_item_ids = save_data["unlocked_items"]
		for item_id in unlocked_item_ids:
			if unlockable_items.has(item_id):
				var item = unlockable_items[item_id]
				if item.has_method("unlock_item"):
					item.unlock_item()
					unlocked_count += 1
	
	print("[ProgressManager] Loaded profile %d: %s (%d unlocked items)" % [slot, current_profile_name, unlocked_count])
	print("[ProgressManager] Final state - slot: %d, name: %s" % [current_profile_slot, current_profile_name])
	print("[ProgressManager] ===== LOAD PROFILE END =====")
	profile_loaded.emit(slot)
	progress_loaded.emit()
	return true


## _get_default_cumulative_stats()
##
## Returns a fresh default cumulative stats dictionary.
func _get_default_cumulative_stats() -> Dictionary:
	return {
		"games_completed": 0,
		"games_won": 0,
		"total_score": 0,
		"total_money_earned": 0,
		"total_consumables_used": 0,
		"total_yahtzees": 0,
		"total_straights": 0,
		"total_color_bonuses": 0,
		"highest_channel_completed": 0,
		"total_chores_completed": 0,
		"total_chores_completed_easy": 0,
		"total_chores_completed_hard": 0
	}


## _reset_all_unlocks()
##
## Reset all unlockable items to locked state (used before loading a new profile).
func _reset_all_unlocks() -> void:
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		item.is_unlocked = false
		item.unlock_timestamp = 0


## save_current_profile()
##
## Save the current profile's progress to its save file.
## Includes safeguards against profile slot mismatch.
func save_current_profile() -> void:
	print("[ProgressManager] ===== SAVE PROFILE START =====")
	print("[ProgressManager] Saving - current slot: %d, name: %s" % [current_profile_slot, current_profile_name])
	
	# Ensure we're using the correct profile slot from GameSettings
	var game_settings = get_node_or_null("/root/GameSettings")
	if game_settings:
		print("[ProgressManager] GameSettings active slot: %d" % game_settings.active_profile_slot)
		if game_settings.active_profile_slot != current_profile_slot:
			print("[ProgressManager] WARNING: Profile mismatch detected!")
			print("  ProgressManager slot: %d, GameSettings slot: %d" % [current_profile_slot, game_settings.active_profile_slot])
			print("  Syncing to GameSettings slot: %d" % game_settings.active_profile_slot)
			# Reload the correct profile before saving to avoid data corruption
			print("[ProgressManager] CRITICAL: Loading correct profile before save to prevent name crossover")
			load_profile(game_settings.active_profile_slot)
	else:
		print("[ProgressManager] WARNING: GameSettings not found during save!")
	
	var save_path = PROFILE_SAVE_PATHS[current_profile_slot]
	print("[ProgressManager] Saving to path: %s" % save_path)
	
	var save_data = {
		"save_version": CURRENT_SAVE_VERSION,
		"profile_name": current_profile_name,
		"last_played": Time.get_datetime_string_from_system(),
		"tutorial_completed": tutorial_completed,
		"tutorial_in_progress": tutorial_in_progress,
		"cumulative_stats": cumulative_stats,
		"completed_channels": completed_channels,
		"unlocked_items": []
	}
	
	# Collect unlocked item IDs
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.is_unlocked:
			save_data["unlocked_items"].append(item_id)
	
	var json_string = JSON.stringify(save_data, "\t")
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	if not file:
		push_error("[ProgressManager] Failed to save profile %d" % current_profile_slot)
		return
	
	file.store_string(json_string)
	file.close()
	
	print("[ProgressManager] Profile %d saved: %s" % [current_profile_slot, current_profile_name])
	progress_saved.emit()


## rename_profile(slot, new_name)
##
## Rename a profile slot.
## @param slot: Profile slot number (1-3)
## @param new_name: New profile name (max 30 chars)
## @return bool: True if successful
func rename_profile(slot: int, new_name: String) -> bool:
	if slot < 1 or slot > 3:
		push_error("[ProgressManager] Invalid profile slot: %d" % slot)
		return false
	
	# Enforce max length
	new_name = new_name.substr(0, PROFILE_NAME_MAX_LENGTH).strip_edges()
	if new_name.is_empty():
		new_name = DEFAULT_PROFILE_NAMES[slot]
	
	var save_path = PROFILE_SAVE_PATHS[slot]
	if not FileAccess.file_exists(save_path):
		push_error("[ProgressManager] Profile slot %d does not exist" % slot)
		return false
	
	# Load existing profile data
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return false
	
	var save_data = json.get_data()
	save_data["profile_name"] = new_name
	
	# Save updated data
	var new_json_string = JSON.stringify(save_data, "\t")
	var write_file = FileAccess.open(save_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(new_json_string)
		write_file.close()
		
		# Update current profile name if this is the active profile
		if slot == current_profile_slot:
			current_profile_name = new_name
		
		print("[ProgressManager] Profile %d renamed to: %s" % [slot, new_name])
		profile_renamed.emit(slot, new_name)
		return true
	
	return false


## get_profile_info(slot)
##
## Get info about a specific profile slot.
## @param slot: Profile slot number (1-3)
## @return Dictionary: Profile info including name, stats, last_played
func get_profile_info(slot: int) -> Dictionary:
	var default_info = {
		"slot": slot,
		"name": DEFAULT_PROFILE_NAMES.get(slot, "Player"),
		"games_completed": 0,
		"games_won": 0,
		"total_score": 0,
		"highest_channel": 0,
		"last_played": ""
	}
	
	if slot < 1 or slot > 3:
		return default_info
	
	var save_path = PROFILE_SAVE_PATHS[slot]
	if not FileAccess.file_exists(save_path):
		return default_info
	
	var file = FileAccess.open(save_path, FileAccess.READ)
	if not file:
		return default_info
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return default_info
	
	var save_data = json.get_data()
	var stats = save_data.get("cumulative_stats", {})
	
	return {
		"slot": slot,
		"name": save_data.get("profile_name", DEFAULT_PROFILE_NAMES[slot]),
		"games_completed": stats.get("games_completed", 0),
		"games_won": stats.get("games_won", 0),
		"total_score": stats.get("total_score", 0),
		"highest_channel": stats.get("highest_channel_completed", 0),
		"last_played": save_data.get("last_played", "")
	}


## get_current_profile_name()
##
## Get the name of the currently active profile.
## @return String: Current profile name
func get_current_profile_name() -> String:
	return current_profile_name


## list_profiles()
##
## Get info about all profile slots.
## @return Array[Dictionary]: Array of profile info dictionaries
func list_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for slot in [1, 2, 3]:
		profiles.append(get_profile_info(slot))
	return profiles


## Legacy compatibility - redirects to load_profile
func load_progress() -> void:
	load_profile(current_profile_slot)


## Legacy compatibility - redirects to save_current_profile
func save_progress() -> void:
	save_current_profile()

## Start tracking a new game
func start_game_tracking() -> void:
	current_game_stats = {
		"max_category_score": 0,
		"yahtzees_rolled": 0,
		"straights_rolled": 0,
		"consumables_used": 0,
		"money_earned": 0,
		"same_color_bonuses": 0,
		"categories_scored": [],
		"category_scores": {},
		"combinations_rolled": {},
		"upper_bonus_achieved": false,
		"game_completed": false,
		"final_score": 0,
		"chores_completed": 0,
		"chores_completed_easy": 0,
		"chores_completed_hard": 0
	}
	is_tracking_game = true
	print("[ProgressManager] Started tracking new game")

## End game tracking and check for unlocks
func end_game_tracking(final_score: int, did_win: bool = false) -> void:
	if not is_tracking_game:
		print("[ProgressManager] WARNING: No game being tracked when end_game_tracking called")
		print("[ProgressManager] current_game_stats: %s" % current_game_stats)
		return
	
	print("[ProgressManager] Ending game tracking - Final score: %d, Win: %s" % [final_score, did_win])
	print("[ProgressManager] Current game stats: %s" % current_game_stats)
	
	# Update current game stats
	current_game_stats["final_score"] = final_score
	current_game_stats["game_completed"] = true
	current_game_stats["game_won"] = did_win
	
	# Compute unscored categories (categories left completely blank, not scored at all)
	var all_categories = ["ones", "twos", "threes", "fours", "fives", "sixes",
		"three_of_a_kind", "four_of_a_kind", "full_house", "small_straight",
		"large_straight", "yahtzee", "chance"]
	var unscored: Array = []
	for cat in all_categories:
		if cat not in current_game_stats["categories_scored"]:
			unscored.append(cat)
	current_game_stats["unscored_categories"] = unscored
	print("[ProgressManager] Unscored categories: %s" % [str(unscored)])
	
	# Update cumulative stats
	cumulative_stats["games_completed"] += 1
	if did_win:
		cumulative_stats["games_won"] += 1
	cumulative_stats["total_score"] += final_score
	cumulative_stats["total_money_earned"] += current_game_stats["money_earned"]
	cumulative_stats["total_consumables_used"] += current_game_stats["consumables_used"]
	cumulative_stats["total_yahtzees"] += current_game_stats["yahtzees_rolled"]
	cumulative_stats["total_straights"] += current_game_stats["straights_rolled"]
	cumulative_stats["total_color_bonuses"] += current_game_stats["same_color_bonuses"]
	cumulative_stats["total_chores_completed"] += current_game_stats["chores_completed"]
	cumulative_stats["total_chores_completed_easy"] += current_game_stats.get("chores_completed_easy", 0)
	cumulative_stats["total_chores_completed_hard"] += current_game_stats.get("chores_completed_hard", 0)
	
	print("[ProgressManager] Updated cumulative stats: %s" % cumulative_stats)
	
	# Check for new unlocks
	check_all_unlock_conditions()
	
	# Save progress
	save_progress()
	
	is_tracking_game = false
	print("[ProgressManager] Game tracking ended. Final score: %d" % final_score)

## Check all unlock conditions and unlock eligible items
func check_all_unlock_conditions() -> void:
	print("[ProgressManager] Checking unlock conditions for profile %d (%s)" % [current_profile_slot, current_profile_name])
	
	var newly_unlocked: Array[String] = []
	
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.is_unlocked:
			continue  # Skip already unlocked items
		
		var should_unlock = false
		if item.has_method("check_unlock"):
			should_unlock = item.check_unlock(current_game_stats, cumulative_stats)
		
		if should_unlock:
			print("[ProgressManager] Unlocking item: %s" % item_id)
			if item.has_method("unlock_item"):
				item.unlock_item()
			newly_unlocked.append(item_id)
			item_unlocked.emit(item_id, item.get_type_string())
	
	if newly_unlocked.size() > 0:
		print("[ProgressManager] Newly unlocked items: %s" % [str(newly_unlocked)])
		items_unlocked_batch.emit(newly_unlocked)  # Emit batch signal for UI
	else:
		print("[ProgressManager] No new items unlocked")

## Track game events
func track_score_assigned(category: String, score: int) -> void:
	if not is_tracking_game:
		print("[ProgressManager] WARNING: track_score_assigned called but game tracking not started! Category: %s, Score: %d" % [category, score])
		return
	
	var old_max = current_game_stats["max_category_score"]
	current_game_stats["max_category_score"] = max(current_game_stats["max_category_score"], score)
	if category not in current_game_stats["categories_scored"]:
		current_game_stats["categories_scored"].append(category)
	# Track per-category scores for SCORE_THRESHOLD_CATEGORY unlock conditions
	current_game_stats["category_scores"][category] = score
	print("[ProgressManager] Score tracked: %s = %d pts (max score: %d -> %d)" % [category, score, old_max, current_game_stats["max_category_score"]])

func track_yahtzee_rolled() -> void:
	if not is_tracking_game:
		print("[ProgressManager] WARNING: track_yahtzee_rolled called but game tracking not started!")
		return
	current_game_stats["yahtzees_rolled"] += 1
	print("[ProgressManager] Yahtzee rolled! Game yahtzees: %d" % current_game_stats["yahtzees_rolled"])

func track_straight_rolled(straight_type: String) -> void:
	if not is_tracking_game:
		return
	current_game_stats["straights_rolled"] += 1
	var combinations = current_game_stats["combinations_rolled"]
	combinations[straight_type] = combinations.get(straight_type, 0) + 1

func track_consumable_used() -> void:
	if not is_tracking_game:
		return
	current_game_stats["consumables_used"] += 1

func track_money_earned(amount: int) -> void:
	if not is_tracking_game:
		print("[ProgressManager] WARNING: track_money_earned called but game tracking not started! Amount: $%d" % amount)
		return
	current_game_stats["money_earned"] += amount
	print("[ProgressManager] Money earned: $%d (total this game: $%d)" % [amount, current_game_stats["money_earned"]])

func track_color_bonus() -> void:
	if not is_tracking_game:
		return
	current_game_stats["same_color_bonuses"] += 1

func track_upper_bonus_achieved() -> void:
	if not is_tracking_game:
		return
	current_game_stats["upper_bonus_achieved"] = true

## track_chore_completed(difficulty: int)
##
## Tracks a chore completion for unlock condition checking.
## Increments both total and difficulty-specific counters.
## @param difficulty: ChoreData.Difficulty enum value (0=EASY, 1=HARD)
func track_chore_completed(difficulty: int) -> void:
	if not is_tracking_game:
		print("[ProgressManager] WARNING: track_chore_completed called but game tracking not started!")
		return
	current_game_stats["chores_completed"] += 1
	if difficulty == 0:  # EASY
		current_game_stats["chores_completed_easy"] += 1
	else:  # HARD
		current_game_stats["chores_completed_hard"] += 1
	print("[ProgressManager] Chore completed! (difficulty: %s, total this game: %d)" % [
		"EASY" if difficulty == 0 else "HARD", current_game_stats["chores_completed"]])

## mark_channel_completed(channel_num: int) -> void
##
## Marks a channel as completed and updates the highest channel stat.
## Called when player wins a channel. Persists to save file immediately.
## @param channel_num: The channel number that was completed (1-20)
func mark_channel_completed(channel_num: int) -> void:
	# Add to completed channels if not already there
	if channel_num not in completed_channels:
		completed_channels.append(channel_num)
		print("[ProgressManager] Channel %d marked as completed" % channel_num)
	
	# Update highest channel completed stat
	if channel_num > cumulative_stats["highest_channel_completed"]:
		cumulative_stats["highest_channel_completed"] = channel_num
		print("[ProgressManager] New highest channel completed: %d" % channel_num)
	
	# Save progress immediately
	save_progress()

## is_channel_completed(channel_num: int) -> bool
##
## Checks if a specific channel has been completed.
## @param channel_num: The channel number to check
## @return bool: True if the channel has been completed
func is_channel_completed(channel_num: int) -> bool:
	return channel_num in completed_channels


## get_total_channel_completions() -> int
##
## Returns the total number of unique channels the player has completed.
## Used by ChannelManager to determine which channels are unlocked.
## @return int: Count of completed channels
func get_total_channel_completions() -> int:
	return completed_channels.size()


## get_completed_channel_count() -> int
##
## Alias for get_total_channel_completions() for UI display.
## @return int: Count of completed channels
func get_completed_channel_count() -> int:
	return completed_channels.size()


## Check if a specific item is unlocked
## @param item_id: String ID of the item to check
## @return bool: True if item is unlocked
func is_item_unlocked(item_id: String) -> bool:
	if not unlockable_items.has(item_id):
		return false  # If not tracked by ProgressManager, assume locked
	
	var item = unlockable_items[item_id]
	return item.is_unlocked

## Get all unlocked items of a specific type
## @param item_type: UnlockableItem.ItemType to filter by
## @return Array[String]: Array of unlocked item IDs
func get_unlocked_items(item_type: int) -> Array[String]:
	var unlocked: Array[String] = []
	
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.item_type == item_type and item.is_unlocked:
			unlocked.append(item_id)
	
	return unlocked

## Get all locked items of a specific type
## @param item_type: UnlockableItem.ItemType to filter by
## @return Array: Array of locked UnlockableItem objects
func get_locked_items(item_type: int) -> Array:
	var locked: Array = []
	
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.item_type == item_type and not item.is_unlocked:
			locked.append(item)
	
	return locked


## get_condition_progress(item_id: String) -> Dictionary
##
## Gets the current progress toward unlocking an item.
## Returns dictionary with "current", "target", and "percentage" keys.
## @param item_id: The ID of the item to check progress for
## @return Dictionary: {current: int, target: int, percentage: float}
func get_condition_progress(item_id: String) -> Dictionary:
	var result = {"current": 0, "target": 0, "percentage": 0.0}
	
	if not unlockable_items.has(item_id):
		return result
	
	var item = unlockable_items[item_id]
	if item.is_unlocked:
		return {"current": 1, "target": 1, "percentage": 100.0}
	
	var condition = item.unlock_condition
	if not condition:
		return result
	
	result["target"] = condition.target_value
	
	# Get current progress based on condition type
	match condition.condition_type:
		UnlockConditionClass.ConditionType.SCORE_POINTS:
			# This is per-game, so we can't track cumulative progress
			result["current"] = 0  # Would need to track max ever achieved
		
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE:
			# Per-game yahtzees - can't track cumulative progress for this specific type
			result["current"] = 0
		
		UnlockConditionClass.ConditionType.COMPLETE_GAME:
			result["current"] = cumulative_stats.get("games_completed", 0)
		
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT:
			# Per-game straights
			result["current"] = 0
		
		UnlockConditionClass.ConditionType.USE_CONSUMABLES:
			# Per-game consumables used
			result["current"] = 0
		
		UnlockConditionClass.ConditionType.EARN_MONEY:
			# Per-game money earned
			result["current"] = 0
		
		UnlockConditionClass.ConditionType.WIN_GAMES:
			result["current"] = cumulative_stats.get("games_won", 0)
		
		UnlockConditionClass.ConditionType.CUMULATIVE_SCORE:
			result["current"] = cumulative_stats.get("total_score", 0)
		
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES:
			result["current"] = cumulative_stats.get("total_yahtzees", 0)
		
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL:
			result["current"] = cumulative_stats.get("highest_channel_completed", 0)
		
		UnlockConditionClass.ConditionType.REACH_CHANNEL:
			result["current"] = cumulative_stats.get("highest_channel_completed", 0)
		
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY:
			# Per-game category score - can't track cumulative progress
			result["current"] = 0
		
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS:
			var is_cumulative = condition.additional_params.get("cumulative", false)
			if is_cumulative:
				result["current"] = cumulative_stats.get("total_chores_completed", 0)
			else:
				result["current"] = 0  # Per-game chores
		
		_:
			result["current"] = 0
	
	# Calculate percentage (capped at 100)
	if result["target"] > 0:
		result["percentage"] = min(100.0, (float(result["current"]) / float(result["target"])) * 100.0)
	
	return result


## Debug functions for manual unlock/lock
func debug_unlock_item(item_id: String) -> void:
	if not unlockable_items.has(item_id):
		print("[ProgressManager] Item not found: %s" % item_id)
		return
	
	var item = unlockable_items[item_id]
	if item.has_method("unlock_item"):
		item.unlock_item()
	print("[ProgressManager] DEBUG: Manually unlocked %s" % item_id)
	
	# Emit signals to notify UI components
	item_unlocked.emit(item_id, item.get_type_string())
	save_progress()

func debug_lock_item(item_id: String) -> void:
	if not unlockable_items.has(item_id):
		print("[ProgressManager] Item not found: %s" % item_id)
		return
	
	var item = unlockable_items[item_id]
	item.is_unlocked = false
	item.unlock_timestamp = 0
	print("[ProgressManager] DEBUG: Manually locked %s" % item_id)
	
	# Emit signals to notify UI components
	item_locked.emit(item_id, item.get_type_string())
	save_progress()

## connect_to_game_scene()
##
## Public method to (re)connect to game scene signals. Called by GameController
## when a game scene loads to ensure ProgressManager can track game events.
func connect_to_game_scene() -> void:
	print("[ProgressManager] Connecting to game scene signals...")
	_connect_game_signals()

## Connect to game systems for automatic tracking
func _connect_to_game_systems() -> void:
	# Wait for the tree to be ready
	call_deferred("_connect_game_signals")

func _connect_game_signals() -> void:
	var connections_made = 0
	
	# Connect to scorecard signals
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard:
		if not scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.connect(_on_score_assigned)
			connections_made += 1
		if not scorecard.is_connected("game_completed", _on_game_completed):
			scorecard.game_completed.connect(_on_game_completed)
			connections_made += 1
		if not scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
			connections_made += 1
		print("[ProgressManager] Connected to scorecard signals")
	else:
		print("[ProgressManager] WARNING: Scorecard not found - score tracking unavailable")
	
	# Connect to game controller signals
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		if not game_controller.is_connected("consumable_used", _on_consumable_used):
			game_controller.consumable_used.connect(_on_consumable_used)
			connections_made += 1
		print("[ProgressManager] Connected to game controller signals")
	else:
		print("[ProgressManager] WARNING: GameController not found - consumable tracking unavailable")
	
	# Connect to turn tracker for new game detection
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker:
		if not turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.connect(_on_turn_started)
			connections_made += 1
		print("[ProgressManager] Connected to turn tracker signals")
	else:
		print("[ProgressManager] WARNING: TurnTracker not found - game start detection unavailable")
	
	# Connect to player economy for money tracking
	if PlayerEconomy and not PlayerEconomy.is_connected("money_changed", _on_money_changed):
		PlayerEconomy.money_changed.connect(_on_money_changed)
		connections_made += 1
		print("[ProgressManager] Connected to player economy signals")
	
	# Connect to DiceColorManager for color bonus tracking
	if DiceColorManager and not DiceColorManager.is_connected("color_effects_calculated", _on_color_effects_calculated):
		DiceColorManager.color_effects_calculated.connect(_on_color_effects_calculated)
		connections_made += 1
		print("[ProgressManager] Connected to dice color manager signals")
	
	# Connect to RollStats for yahtzee and straight tracking  
	if RollStats:
		if not RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
			RollStats.yahtzee_rolled.connect(_on_yahtzee_rolled)
			connections_made += 1
		if not RollStats.is_connected("combination_achieved", _on_combination_achieved):
			RollStats.combination_achieved.connect(_on_combination_achieved)
			connections_made += 1
		print("[ProgressManager] Connected to roll stats signals")
	
	print("[ProgressManager] Game signal connections complete (%d new connections)" % connections_made)

## Signal handlers for game events
func _on_score_assigned(_section: int, category: String, score: int) -> void:
	print("[ProgressManager] Score assigned: %s = %d pts" % [category, score])
	track_score_assigned(category, score)

func _on_game_completed(final_score: int) -> void:
	end_game_tracking(final_score)

func _on_upper_bonus_achieved(_bonus: int) -> void:
	track_upper_bonus_achieved()

func _on_consumable_used(_id: String, _consumable) -> void:
	track_consumable_used()

func _on_turn_started() -> void:
	# Start tracking on the first turn
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker and turn_tracker.current_turn == 1 and not is_tracking_game:
		start_game_tracking()

func _on_money_changed(_new_amount: int, change: int) -> void:
	if change > 0:
		track_money_earned(change)

func _on_color_effects_calculated(_green_money: int, _red_additive: int, _purple_multiplier: float, same_color_bonus: bool, _rainbow_bonus: bool) -> void:
	if same_color_bonus:
		track_color_bonus()

func _on_yahtzee_rolled() -> void:
	track_yahtzee_rolled()

func _on_combination_achieved(combination_type: String) -> void:
	if combination_type in ["small_straight", "large_straight"]:
		track_straight_rolled(combination_type)

## Create default unlockable items for all game content
func _create_default_unlockable_items() -> void:
	print("[ProgressManager] Creating complete unlockable items for all game content")
	
	# ==========================================================================
	# ALL POWERUPS - Difficulty 1-10, diversified unlock conditions
	# ==========================================================================
	
	# --- Difficulty 1: Starter PowerUps (unlock with first game or trivial achievements) ---
	_add_default_power_up("step_by_step", "Step By Step", "Upper section scores get +6", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	_add_default_power_up("extra_rolls", "Extra Rolls", "Get additional roll attempts", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	_add_default_power_up("allowance", "Allowance", "Grants $100 when challenge completes", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	_add_default_power_up("roll_efficiency", "Roll Efficiency", "+N to scores (N = rolls used)", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	
	# --- Difficulty 2: Early common PowerUps ---
	_add_default_power_up("extra_dice", "Extra Dice", "Start with an extra die", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 8, 2, {"category": "twos"})
	_add_default_power_up("evens_no_odds", "Evens No Odds", "Additive bonus for even dice", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 50, 2)
	_add_default_power_up("bonus_money", "Bonus Money", "Earn extra money per round", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 50, 2)
	_add_default_power_up("lock_and_load", "Lock & Load", "+$3 for each die locked", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 2, 2)
	_add_default_power_up("dice_diversity", "Dice Diversity", "+$5 per unique dice value scored", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 25, 2, {"category": "chance"})
	
	# --- Difficulty 3: Common PowerUps ---
	_add_default_power_up("foursome", "Foursome", "Bonus for four of a kind", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 22, 3, {"category": "four_of_a_kind"})
	_add_default_power_up("chance520", "Chance 520", "Bonus for chance category", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 1, 3)
	_add_default_power_up("green_slime", "Green Slime", "Doubles green dice probability", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 75, 3)
	_add_default_power_up("chore_champion", "Chore Champion", "Chores are 2x more effective", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 5, 3, {"cumulative": true})
	_add_default_power_up("pair_paradise", "Pair Paradise", "Pair bonuses: +3/+6/+9 based on pattern", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 18, 3, {"category": "three_of_a_kind"})
	_add_default_power_up("failed_money", "Failed Money", "+$25 for each failed hand at round end", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 2, 3)
	
	# --- Difficulty 4: Uncommon PowerUps ---
	_add_default_power_up("full_house_bonus", "Full House Fortune", "Full house scoring bonus", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 28, 4, {"category": "full_house"})
	_add_default_power_up("consumable_cash", "Consumable Cash", "Gain money from PowerUps", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 5, 4)
	_add_default_power_up("red_slime", "Red Slime", "Doubles red dice probability", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 100, 4)
	_add_default_power_up("lower_ten", "Lower Ten", "Lower section scores get +10 points", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 35, 4, {"category": "small_straight"})
	_add_default_power_up("shop_rerolls", "Shop Rerolls", "Shop rerolls always cost $25", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 100, 4)
	_add_default_power_up("tango_and_cash", "Tango & Cash", "+$10 for every odd die scored", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 3, 4)
	_add_default_power_up("purple_payout", "Purple Payout", "Earn $3 per purple die when scoring", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 120, 4)
	_add_default_power_up("chore_sprint", "Chore Sprint", "Chore completions reduce goof-off by extra 10", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 8, 4, {"cumulative": true})
	
	# --- Difficulty 5: Mid-tier PowerUps ---
	_add_default_power_up("upper_bonus_mult", "Upper Bonus Multiplier", "Multiplies upper bonus", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 24, 5, {"category": "sixes"})
	_add_default_power_up("money_multiplier", "Money Multiplier", "Multiplies money earned", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 200, 5)
	_add_default_power_up("pin_head", "Pin Head", "Bonus for specific dice patterns", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 3, 5)
	_add_default_power_up("purple_slime", "Purple Slime", "Doubles purple dice probability", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 2, 5)
	_add_default_power_up("different_straights", "Different Straights", "Straights can have one gap of 1", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 4, 5)
	_add_default_power_up("mod_money", "Mod Money", "Earn $8 per modded die when scoring", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 6, 5)
	_add_default_power_up("even_higher", "Even Higher", "+1 additive per even die scored (cumulative)", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 20, 5, {"category": "fives"})
	_add_default_power_up("extra_rainbow", "Extra Rainbow", "+10 per colored die scored", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 5)
	
	# --- Difficulty 6: Rare PowerUps ---
	_add_default_power_up("money_well_spent", "Money Well Spent", "Convert money to score", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 250, 6)
	_add_default_power_up("highlighted_score", "Highlighted Score", "Bonus for highlighted categories", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 45, 6, {"category": "large_straight"})
	_add_default_power_up("yahtzee_bonus_mult", "Yahtzee Bonus Multiplier", "Multiplies Yahtzee bonuses", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 3, 6)
	_add_default_power_up("perfect_strangers", "Perfect Strangers", "Bonus for diverse dice", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 5, 6)
	_add_default_power_up("randomizer", "Randomizer", "Random bonus effects", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 8, 6)
	_add_default_power_up("plus_thelast", "Plus The Last", "Adds last score to current score", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 250, 6)
	_add_default_power_up("straight_triplet_master", "Straight Triplet Master", "Score large straight in 3 categories for $150 + 75 bonus", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 5, 6)
	_add_default_power_up("modded_dice_mastery", "Modded Dice Mastery", "+10 per modded die when scoring", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 15, 6, {"cumulative": true})
	_add_default_power_up("blue_safety_net", "Blue Safety Net", "Halves blue dice penalties", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 6)
	_add_default_power_up("great_exchange", "The Great Exchange", "+2 dice, -1 roll per turn", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 6, 6)
	
	# --- Difficulty 7: Epic PowerUps ---
	_add_default_power_up("the_consumer_is_always_right", "The Consumer Is Always Right", "Consumable synergies", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 12, 7)
	_add_default_power_up("green_monster", "Green Monster", "Green dice bonuses", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 350, 7)
	_add_default_power_up("red_power_ranger", "Red Power Ranger", "Red dice bonuses", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 50, 7, {"category": "yahtzee"})
	_add_default_power_up("wild_dots", "Wild Dots", "Special die face effects", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 5, 7)
	_add_default_power_up("money_bags", "Money Bags", "Score multiplier based on current money", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 7)
	_add_default_power_up("debuff_destroyer", "Debuff Destroyer", "Removes random debuff when sold", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 4, 7)
	_add_default_power_up("extra_coupons", "Extra Coupons", "Hold 2 additional consumables (5 max)", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 20, 7, {"cumulative": true})
	
	# --- Difficulty 8: High-tier PowerUps ---
	_add_default_power_up("blue_slime", "Blue Slime", "Doubles blue dice probability", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 8, 8)
	_add_default_power_up("challenge_easer", "Challenge Easer", "All challenge targets reduced by 20%", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 8, 8)
	_add_default_power_up("azure_perfection", "Azure Perfection", "Blue dice always multiply (never divide)", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 10, 8)
	
	# --- Difficulty 9: Legendary PowerUps ---
	_add_default_power_up("ungrounded", "Ungrounded", "Prevents all debuffs", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 12, 9)
	_add_default_power_up("rainbow_surge", "Rainbow Surge", "2x multiplier when 4+ dice colors present", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 10, 9)
	_add_default_power_up("grand_master", "Grand Master", "All scoring categories get +10%", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 15, 9)
	
	# --- Difficulty 10: Mythic PowerUps ---
	_add_default_power_up("dice_lord", "Dice Lord", "Start each round with one guaranteed Yahtzee", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 20, 10)
	
	# --- New Wave PowerUps ---
	_add_default_power_up("the_piggy_bank", "The Piggy Bank", "Saves $3 per roll. Sell to cash out!", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 6, 4, {"cumulative": true})
	_add_default_power_up("daring_dice", "Daring Dice", "Remove 2 dice but gain +50 score bonus", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 4, 5)
	_add_default_power_up("consumable_collector", "Consumable Collector", "+0.1x multiplier per consumable used", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 8, 5)
	_add_default_power_up("random_card_level", "Random Card Level", "20% chance each turn to level up a category", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 4, 6)
	_add_default_power_up("the_replicator", "The Replicator", "Duplicates a random PowerUp you own after 1 turn", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 4, 7)
	_add_default_power_up("yahtzeed_dice", "Yahtzeed Dice", "Gain +1 die per Yahtzee (max 16)", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 6, 8)
	
	# --- Channel-based PowerUps (NOT IMPLEMENTED - preserved) ---
	_add_default_power_up("lucky_streak", "Lucky Streak", "Increased chance of rolling pairs", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 5)
	_add_default_power_up("steady_progress", "Steady Progress", "+5 points to all lower section scores", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 6)
	_add_default_power_up("combo_king", "Combo King", "Bonus multiplier for consecutive scoring", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 8, 7)
	_add_default_power_up("channel_champion", "Channel Champion", "Double points in favorite category", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 12, 8)
	
	# ==========================================================================
	# AVOIDANCE CHALLENGES - Win without scoring in specific categories/sections
	# ==========================================================================
	
	# --- Difficulty 1: Win without scoring in a single number category ---
	_add_default_power_up("avoidance_ones", "Ones Avoider", "Win without scoring in Ones", 
		UnlockConditionClass.ConditionType.WIN_WITHOUT_SCORING, 1, 1, {"category": "ones"})
	
	# --- Difficulty 6: Win without scoring in the entire Upper Section ---
	_add_default_power_up("avoidance_upper", "Upper Section Avoider", "Win without scoring in Upper Section", 
		UnlockConditionClass.ConditionType.WIN_WITHOUT_SCORING, 1, 6, {"section": "upper"})
	
	# --- Difficulty 10: Win without scoring in the entire Lower Section ---
	_add_default_power_up("avoidance_lower", "Lower Section Avoider", "Win without scoring in Lower Section", 
		UnlockConditionClass.ConditionType.WIN_WITHOUT_SCORING, 1, 10, {"section": "lower"})
	
	# ==========================================================================
	# ALL CONSUMABLES - Difficulty 1-10, diversified unlock conditions
	# ==========================================================================
	
	# --- Difficulty 1: Starter consumables ---
	_add_default_consumable("quick_cash", "Quick Cash", "Gain instant money", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	_add_default_consumable("any_score", "Any Score", "Score dice in any category", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	_add_default_consumable("free_chores", "Free Chores", "Reduces goof-off meter by 30 points", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1, 1)
	
	# --- Difficulty 2: Early consumables ---
	_add_default_consumable("score_reroll", "Score Reroll", "Reroll after scoring", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 4, 2, {"category": "ones"})
	_add_default_consumable("ones_upgrade", "Ones Upgrade", "Upgrade Ones category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 4, 2, {"category": "ones"})
	_add_default_consumable("twos_upgrade", "Twos Upgrade", "Upgrade Twos category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 8, 2, {"category": "twos"})
	_add_default_consumable("lucky_upgrade", "Lucky Upgrade", "Randomly upgrade one category by 1 level", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 2, 2)
	
	# --- Difficulty 3: Common consumables ---
	_add_default_consumable("one_extra_dice", "One Extra Dice", "Add one die temporarily", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 12, 3, {"category": "threes"})
	_add_default_consumable("three_more_rolls", "Three More Rolls", "Get three extra rolls", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 3, 3)
	_add_default_consumable("power_up_shop_num", "Power Up Shop Number", "More PowerUps in shop", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 75, 3)
	_add_default_consumable("threes_upgrade", "Threes Upgrade", "Upgrade Threes category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 12, 3, {"category": "threes"})
	_add_default_consumable("fours_upgrade", "Fours Upgrade", "Upgrade Fours category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 16, 3, {"category": "fours"})
	_add_default_consumable("all_chores", "All Chores", "Clears goof-off meter completely", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 5, 3, {"cumulative": true})
	
	# --- Difficulty 4: Uncommon consumables ---
	_add_default_consumable("double_existing", "Double Existing", "Double a scored category", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 16, 4, {"category": "fours"})
	_add_default_consumable("the_pawn_shop", "The Pawn Shop", "Trade items for money", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 150, 4)
	_add_default_consumable("empty_shelves", "Empty Shelves", "Clear shop for new items", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 5, 4)
	_add_default_consumable("fives_upgrade", "Fives Upgrade", "Upgrade Fives category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 20, 4, {"category": "fives"})
	_add_default_consumable("sixes_upgrade", "Sixes Upgrade", "Upgrade Sixes category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 24, 4, {"category": "sixes"})
	_add_default_consumable("one_free_mod", "One Free Mod", "Grants 1 free random dice mod", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 4, 4)
	_add_default_consumable("dice_surge", "Dice Surge", "Grants +2 temporary dice for 3 turns", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 2, 4)
	
	# --- Difficulty 5: Mid-tier consumables ---
	_add_default_consumable("double_or_nothing", "Double Or Nothing", "Risk/reward scoring", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 150, 5)
	_add_default_consumable("the_rarities", "The Rarities", "Access to rare items", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 8, 5)
	_add_default_consumable("three_of_a_kind_upgrade", "Three of a Kind Upgrade", "Upgrade Three of a Kind category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 18, 5, {"category": "three_of_a_kind"})
	_add_default_consumable("four_of_a_kind_upgrade", "Four of a Kind Upgrade", "Upgrade Four of a Kind category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 22, 5, {"category": "four_of_a_kind"})
	_add_default_consumable("chance_upgrade", "Chance Upgrade", "Upgrade Chance category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 25, 5, {"category": "chance"})
	_add_default_consumable("stat_cashout", "Stat Cashout", "Earn $10/yahtzee and $5/full house scored this run", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 3, 5)
	_add_default_consumable("visit_the_shop", "Visit The Shop", "Open the shop during active play", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 5)
	
	# --- Difficulty 6: Rare consumables ---
	_add_default_consumable("add_max_power_up", "Add Max Power Up", "Increase PowerUp limit", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 10, 6, {"cumulative": true})
	_add_default_consumable("random_power_up_uncommon", "Random Uncommon Power Up", "Get random uncommon PowerUp", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 4, 6)
	_add_default_consumable("green_envy", "Green Envy", "Green dice effects", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 200, 6)
	_add_default_consumable("full_house_upgrade", "Full House Upgrade", "Upgrade Full House category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 28, 6, {"category": "full_house"})
	_add_default_consumable("small_straight_upgrade", "Small Straight Upgrade", "Upgrade Small Straight category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 35, 6, {"category": "small_straight"})
	_add_default_consumable("upper_section_boost", "Upper Section Boost", "Upgrades all 6 upper section categories by one level", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 6)
	_add_default_consumable("score_amplifier", "Score Amplifier", "Doubles your next category score", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 400, 6)
	
	# --- Difficulty 7: Epic consumables ---
	_add_default_consumable("go_broke_or_go_home", "Go Broke Or Go Home", "All-in money strategy", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 300, 7)
	_add_default_consumable("poor_house", "Poor House", "Low money benefits", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 25, 7, {"cumulative": true})
	_add_default_consumable("large_straight_upgrade", "Large Straight Upgrade", "Upgrade Large Straight category level", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 45, 7, {"category": "large_straight"})
	_add_default_consumable("lower_section_boost", "Lower Section Boost", "Upgrades all 7 lower section categories by one level", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 7)
	_add_default_consumable("score_streak", "Score Streak", "Score multiplier grows: 1x -> 1.5x -> 2x over 3 turns", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 4, 7)
	_add_default_consumable("channel_bonus", "Channel Bonus", "Gain $50 per completed channel", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 7)
	_add_default_consumable("reroll_master", "Reroll Master", "Gain 2 extra rerolls this round", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 7)
	
	# --- Difficulty 8: Legendary consumables ---
	_add_default_consumable("yahtzee_upgrade", "Yahtzee Upgrade", "Upgrade Yahtzee category level", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 8, 8)
	_add_default_consumable("bonus_collector", "Bonus Collector", "Grants $35 if upper section bonus achieved", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 6, 8)
	_add_default_consumable("lucky_seven", "Lucky Seven", "All dice become 1-7 range this round", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 8, 8)
	
	# --- Difficulty 9: Mythic consumables ---
	_add_default_consumable("all_categories_upgrade", "Master Upgrade", "Upgrade ALL categories by one level", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 10, 9)
	_add_default_consumable("lower_section_boost", "Lower Section Boost", "Upgrades all lower section categories by one level", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 8, 9)
	
	# --- Difficulty 10: Ultimate consumables ---
	_add_default_consumable("ultimate_reroll", "Ultimate Reroll", "Reroll all dice up to 5 times", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 15, 10)
	
	# ==========================================================================
	# ALL MODS - Difficulty 4-9, specialized unlock conditions
	# ==========================================================================
	
	_add_default_mod("even_only", "Even Only", "Forces die to only roll even numbers", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 16, 4, {"category": "fours"})
	_add_default_mod("odd_only", "Odd Only", "Forces die to only roll odd numbers", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 20, 4, {"category": "fives"})
	_add_default_mod("gold_six", "Gold Six", "Sixes count as wilds", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 3, 6)
	_add_default_mod("five_by_one", "Five by One", "All dice show 1 or 5", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 8, 8)
	_add_default_mod("three_but_three", "Three But Three", "Dice avoid rolling 3s", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 5, 5)
	_add_default_mod("wild_card", "Wild Card", "Random special effects on each roll", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 30, 7, {"cumulative": true})
	_add_default_mod("high_roller", "High Roller", "Dice tend toward high values", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 50, 7, {"category": "yahtzee"})
	_add_default_mod("channel_veteran", "Channel Veteran", "Start with +$25 per channel completed", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 5, 6)
	_add_default_mod("precision_roller", "Precision Roller", "First roll each turn is always 4+", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 12, 9)
	
	# ==========================================================================
	# ALL COLORED DICE FEATURES - Difficulty 3-6, score-based progression
	# ==========================================================================
	
	_add_default_colored_dice("green_dice", "Green Dice", "Unlocks green colored dice (earn money)", 
		UnlockConditionClass.ConditionType.CHORE_COMPLETIONS, 3, 3, {"cumulative": true})
	_add_default_colored_dice("red_dice", "Red Dice", "Unlocks red colored dice (score bonus)", 
		UnlockConditionClass.ConditionType.SCORE_THRESHOLD_CATEGORY, 18, 4, {"category": "three_of_a_kind"})
	_add_default_colored_dice("purple_dice", "Purple Dice", "Unlocks purple colored dice (score multiplier)", 
		UnlockConditionClass.ConditionType.CUMULATIVE_YAHTZEES, 2, 5)
	_add_default_colored_dice("blue_dice", "Blue Dice", "Unlocks blue colored dice (complex effects)", 
		UnlockConditionClass.ConditionType.COMPLETE_CHANNEL, 3, 6)
	_add_default_colored_dice("yellow_dice", "Yellow Dice", "Unlocks yellow colored dice (grants consumables when scored)", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 8, 5)
	
	print("[ProgressManager] Created %d total unlockable items across all categories" % unlockable_items.size())

## Helper function to create unlockable items with consistent structure
## Parameters:
## - id: Unique identifier for the item
## - item_name: Display name for the item
## - desc: Description of the item's effects
## - condition_type: Type of unlock condition (from UnlockConditionClass.ConditionType)
## - target: Target value for the unlock condition (meaning depends on condition type)
## - difficulty: Difficulty rating for the item (1-10)
## - extra_params: Dictionary for any additional parameters needed for the condition (e.g. category for score-based conditions, cumulative flag for chore completions, etc.)
func _add_default_power_up(id: String, item_name: String, desc: String, condition_type: int, target: int, difficulty: int = 1, extra_params: Dictionary = {}) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	condition.additional_params = extra_params
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.POWER_UP
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	item.difficulty_rating = difficulty
	
	unlockable_items[id] = item

func _add_default_consumable(id: String, item_name: String, desc: String, condition_type: int, target: int, difficulty: int = 1, extra_params: Dictionary = {}) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	condition.additional_params = extra_params
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.CONSUMABLE
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	item.difficulty_rating = difficulty
	
	unlockable_items[id] = item

func _add_default_colored_dice(id: String, item_name: String, desc: String, condition_type: int, target: int, difficulty: int = 1, extra_params: Dictionary = {}) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	condition.additional_params = extra_params
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.COLORED_DICE_FEATURE
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	item.difficulty_rating = difficulty
	
	unlockable_items[id] = item

func _add_default_mod(id: String, item_name: String, desc: String, condition_type: int, target: int, difficulty: int = 1, extra_params: Dictionary = {}) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	condition.additional_params = extra_params
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.MOD
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	item.difficulty_rating = difficulty
	
	unlockable_items[id] = item
