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

const SAVE_FILE_PATH := "user://progress.save"

# Core progress data
var unlockable_items: Dictionary = {}  # item_id -> UnlockableItem
var cumulative_stats: Dictionary = {
	"games_completed": 0,
	"games_won": 0,
	"total_score": 0,
	"total_money_earned": 0,
	"total_consumables_used": 0,
	"total_yahtzees": 0,
	"total_straights": 0,
	"total_color_bonuses": 0
}

# Current game tracking
var current_game_stats: Dictionary = {}
var is_tracking_game: bool = false

func _ready() -> void:
	add_to_group("progress_manager")
	print("[ProgressManager] Initializing progress tracking system")
	
	# Initialize default unlockable items FIRST (so they exist for loading)
	_create_default_unlockable_items()
	
	# Load existing progress (now that items exist to be unlocked)
	load_progress()
	
	# Connect to game events
	_connect_to_game_systems()

## Load progress from save file
func load_progress() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		print("[ProgressManager] No save file found, starting fresh")
		return
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if not file:
		push_error("[ProgressManager] Failed to open save file")
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error("[ProgressManager] Failed to parse save file JSON")
		return
	
	var save_data = json.get_data()
	
	# Load cumulative stats
	if save_data.has("cumulative_stats"):
		cumulative_stats = save_data["cumulative_stats"]
	
	# Load unlockable items
	if save_data.has("unlocked_items"):
		var unlocked_item_ids = save_data["unlocked_items"]
		print("[ProgressManager] Loading %d unlocked items from save file" % unlocked_item_ids.size())
		for item_id in unlocked_item_ids:
			if unlockable_items.has(item_id):
				var item = unlockable_items[item_id]
				if item.has_method("unlock_item"):
					item.unlock_item()
					print("[ProgressManager] Successfully unlocked %s from save file" % item_id)
				else:
					print("[ProgressManager] WARNING: Item %s has no unlock_item method" % item_id)
			else:
				print("[ProgressManager] WARNING: Item %s from save file not found in unlockable_items" % item_id)
	
	print("[ProgressManager] Progress loaded successfully")
	progress_loaded.emit()

## Save progress to file
func save_progress() -> void:
	var save_data = {
		"cumulative_stats": cumulative_stats,
		"unlocked_items": []
	}
	
	# Collect unlocked item IDs
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.is_unlocked:
			save_data["unlocked_items"].append(item_id)
	
	var json_string = JSON.stringify(save_data, "\t")  # Use tab indentation for readability
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if not file:
		push_error("[ProgressManager] Failed to create save file")
		return
	
	file.store_string(json_string)
	file.close()
	
	print("[ProgressManager] Progress saved successfully")
	progress_saved.emit()

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
		"combinations_rolled": {},
		"upper_bonus_achieved": false,
		"game_completed": false,
		"final_score": 0
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
	
	print("[ProgressManager] Updated cumulative stats: %s" % cumulative_stats)
	
	# Check for new unlocks
	check_all_unlock_conditions()
	
	# Save progress
	save_progress()
	
	is_tracking_game = false
	print("[ProgressManager] Game tracking ended. Final score: %d" % final_score)

## Check all unlock conditions and unlock eligible items
func check_all_unlock_conditions() -> void:
	var newly_unlocked: Array[String] = []
	
	for item_id in unlockable_items:
		var item = unlockable_items[item_id]
		if item.has_method("check_unlock") and item.check_unlock(current_game_stats, cumulative_stats):
			if item.has_method("unlock_item"):
				item.unlock_item()
			newly_unlocked.append(item_id)
			item_unlocked.emit(item_id, item.get_type_string())
	
	if newly_unlocked.size() > 0:
		print("[ProgressManager] Newly unlocked items: %s" % newly_unlocked)
		items_unlocked_batch.emit(newly_unlocked)  # Emit batch signal for UI

## Track game events
func track_score_assigned(category: String, score: int) -> void:
	if not is_tracking_game:
		return
	
	current_game_stats["max_category_score"] = max(current_game_stats["max_category_score"], score)
	if category not in current_game_stats["categories_scored"]:
		current_game_stats["categories_scored"].append(category)

func track_yahtzee_rolled() -> void:
	if not is_tracking_game:
		return
	current_game_stats["yahtzees_rolled"] += 1

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
		return
	current_game_stats["money_earned"] += amount

func track_color_bonus() -> void:
	if not is_tracking_game:
		return
	current_game_stats["same_color_bonuses"] += 1

func track_upper_bonus_achieved() -> void:
	if not is_tracking_game:
		return
	current_game_stats["upper_bonus_achieved"] = true

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

## Connect to game systems for automatic tracking
func _connect_to_game_systems() -> void:
	# Wait for the tree to be ready
	call_deferred("_connect_game_signals")

func _connect_game_signals() -> void:
	# Connect to scorecard signals
	var scorecard = get_tree().get_first_node_in_group("scorecard")
	if scorecard:
		if not scorecard.is_connected("score_assigned", _on_score_assigned):
			scorecard.score_assigned.connect(_on_score_assigned)
		if not scorecard.is_connected("game_completed", _on_game_completed):
			scorecard.game_completed.connect(_on_game_completed)
		if not scorecard.is_connected("upper_bonus_achieved", _on_upper_bonus_achieved):
			scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
		print("[ProgressManager] Connected to scorecard signals")
	
	# Connect to game controller signals
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		if not game_controller.is_connected("consumable_used", _on_consumable_used):
			game_controller.consumable_used.connect(_on_consumable_used)
		print("[ProgressManager] Connected to game controller signals")
	
	# Connect to turn tracker for new game detection
	var turn_tracker = get_tree().get_first_node_in_group("turn_tracker")
	if turn_tracker:
		if not turn_tracker.is_connected("turn_started", _on_turn_started):
			turn_tracker.turn_started.connect(_on_turn_started)
		print("[ProgressManager] Connected to turn tracker signals")
	
	# Connect to player economy for money tracking
	if PlayerEconomy and not PlayerEconomy.is_connected("money_changed", _on_money_changed):
		PlayerEconomy.money_changed.connect(_on_money_changed)
		print("[ProgressManager] Connected to player economy signals")
	
	# Connect to DiceColorManager for color bonus tracking
	if DiceColorManager and not DiceColorManager.is_connected("color_effects_calculated", _on_color_effects_calculated):
		DiceColorManager.color_effects_calculated.connect(_on_color_effects_calculated)
		print("[ProgressManager] Connected to dice color manager signals")
	
	# Connect to RollStats for yahtzee and straight tracking  
	if RollStats:
		if not RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
			RollStats.yahtzee_rolled.connect(_on_yahtzee_rolled)
		if not RollStats.is_connected("combination_achieved", _on_combination_achieved):
			RollStats.combination_achieved.connect(_on_combination_achieved)
		print("[ProgressManager] Connected to roll stats signals")

## Signal handlers for game events
func _on_score_assigned(_section: int, category: String, score: int) -> void:
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

func _on_color_effects_calculated(_green_money: int, _red_additive: int, _purple_multiplier: float, same_color_bonus: bool) -> void:
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
	# ALL POWERUPS (21 total) - From Scripts/PowerUps/*.tres files
	# ==========================================================================
	
	# Starter PowerUps (unlock early with basic achievements)
	_add_default_power_up("step_by_step", "Step By Step", "Upper section scores get +6", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1)
	_add_default_power_up("extra_dice", "Extra Dice", "Start with an extra die", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 10)
	_add_default_power_up("extra_rolls", "Extra Rolls", "Get additional roll attempts", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 1)
	_add_default_power_up("evens_no_odds", "Evens No Odds", "Additive bonus for even dice", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 50)
	
	# Basic scoring PowerUps
	_add_default_power_up("foursome", "Foursome", "Bonus for four of a kind", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 100)
	_add_default_power_up("chance520", "Chance 520", "Bonus for chance category", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 1)
	_add_default_power_up("full_house", "Full House", "Full house scoring bonus", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 150)
	_add_default_power_up("upper_bonus_mult", "Upper Bonus Multiplier", "Multiplies upper bonus", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 200)
		
	# Money and economy PowerUps
	_add_default_power_up("bonus_money", "Bonus Money", "Earn extra money per round", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 50)
	_add_default_power_up("consumable_cash", "Consumable Cash", "Gain money from PowerUps", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 100)
	_add_default_power_up("money_multiplier", "Money Multiplier", "Multiplies money earned", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 150)
	_add_default_power_up("money_well_spent", "Money Well Spent", "Convert money to score", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 200)
	
	# Advanced scoring PowerUps
	_add_default_power_up("highlighted_score", "Highlighted Score", "Bonus for highlighted categories", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 250)
	_add_default_power_up("yahtzee_bonus_mult", "Yahtzee Bonus Multiplier", "Multiplies Yahtzee bonuses", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 2)
	_add_default_power_up("pin_head", "Pin Head", "Bonus for specific dice patterns", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 2)
	_add_default_power_up("perfect_strangers", "Perfect Strangers", "Bonus for diverse dice", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 3)
	
	# Special effect PowerUps
	_add_default_power_up("randomizer", "Randomizer", "Random bonus effects", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 5)
	_add_default_power_up("wild_dots", "Wild Dots", "Special die face effects", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 3)
	_add_default_power_up("the_consumer_is_always_right", "The Consumer Is Always Right", "Consumable synergies", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 10)
	
	# Color-themed PowerUps
	_add_default_power_up("green_with_envy", "Green With Envy", "Green dice bonuses", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 300)
	_add_default_power_up("red_power_ranger", "Red Power Ranger", "Red dice bonuses", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 300)
	
	# Slime PowerUps - Colored dice probability enhancers
	_add_default_power_up("green_slime", "Green Slime", "Doubles green dice probability", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 50)  # Common: unlock with basic money earning
	_add_default_power_up("red_slime", "Red Slime", "Doubles red dice probability", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 100)  # Uncommon: need more score points
	_add_default_power_up("purple_slime", "Purple Slime", "Doubles purple dice probability", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 1)  # Rare: need to roll a Yahtzee
	_add_default_power_up("blue_slime", "Blue Slime", "Doubles blue dice probability", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 3)  # Legendary: need multiple Yahtzees
	
	# ==========================================================================
	# ALL CONSUMABLES (16 total) - From Scripts/Consumable/*.tres files  
	# ==========================================================================
	
	# Basic consumables
	_add_default_consumable("quick_cash", "Quick Cash", "Gain instant money", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 25)
	_add_default_consumable("any_score", "Any Score", "Score dice in any category", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 25)
	_add_default_consumable("score_reroll", "Score Reroll", "Reroll after scoring", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 2)
	_add_default_consumable("one_extra_dice", "One Extra Dice", "Add one die temporarily", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 75)
	_add_default_consumable("three_more_rolls", "Three More Rolls", "Get three extra rolls", 
		UnlockConditionClass.ConditionType.COMPLETE_GAME, 3)
	
	# Score manipulation consumables
	_add_default_consumable("double_existing", "Double Existing", "Double a scored category", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 100)
	_add_default_consumable("double_or_nothing", "Double Or Nothing", "Risk/reward scoring", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 150)
	
	# Shop and economy consumables
	_add_default_consumable("power_up_shop_num", "Power Up Shop Number", "More PowerUps in shop", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 75)
	_add_default_consumable("the_pawn_shop", "The Pawn Shop", "Trade items for money", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 100)
	_add_default_consumable("empty_shelves", "Empty Shelves", "Clear shop for new items", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 3)
	_add_default_consumable("the_rarities", "The Rarities", "Access to rare items", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 5)
	
	# Advanced consumables
	_add_default_consumable("add_max_power_up", "Add Max Power Up", "Increase PowerUp limit", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 7)
	_add_default_consumable("random_power_up_uncommon", "Random Uncommon Power Up", "Get random uncommon PowerUp", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 8)
	_add_default_consumable("green_envy", "Green Envy", "Green dice effects", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 150)
	_add_default_consumable("go_broke_or_go_home", "Go Broke Or Go Home", "All-in money strategy", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 200)
	_add_default_consumable("poor_house", "Poor House", "Low money benefits", 
		UnlockConditionClass.ConditionType.EARN_MONEY, 250)
	
	# ==========================================================================
	# ALL MODS (7 total) - From Scripts/Mods/*.tres files
	# ==========================================================================
	
	_add_default_mod("even_only", "Even Only", "Forces die to only roll even numbers", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 200)
	_add_default_mod("odd_only", "Odd Only", "Forces die to only roll odd numbers", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 200)
	_add_default_mod("gold_six", "Gold Six", "Sixes count as wilds", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 2)
	_add_default_mod("five_by_one", "Five by One", "All dice show 1 or 5", 
		UnlockConditionClass.ConditionType.ROLL_YAHTZEE, 3)
	_add_default_mod("three_but_three", "Three But Three", "Dice avoid rolling 3s", 
		UnlockConditionClass.ConditionType.ROLL_STRAIGHT, 4)
	_add_default_mod("wild_card", "Wild Card", "Random special effects on each roll", 
		UnlockConditionClass.ConditionType.USE_CONSUMABLES, 10)
	_add_default_mod("high_roller", "High Roller", "Dice tend toward high values", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 350)
	
	# ==========================================================================
	# ALL COLORED DICE FEATURES (4 total) - Enable colored dice types
	# ==========================================================================
	
	_add_default_colored_dice("green_dice", "Green Dice", "Unlocks green colored dice (earn money)", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 100)
	_add_default_colored_dice("red_dice", "Red Dice", "Unlocks red colored dice (score bonus)", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 150)
	_add_default_colored_dice("purple_dice", "Purple Dice", "Unlocks purple colored dice (score multiplier)", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 200)
	_add_default_colored_dice("blue_dice", "Blue Dice", "Unlocks blue colored dice (complex effects)", 
		UnlockConditionClass.ConditionType.SCORE_POINTS, 250)
	
	print("[ProgressManager] Created %d total unlockable items across all categories" % unlockable_items.size())

func _add_default_power_up(id: String, item_name: String, desc: String, condition_type: int, target: int) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.POWER_UP
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	
	unlockable_items[id] = item

func _add_default_consumable(id: String, item_name: String, desc: String, condition_type: int, target: int) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.CONSUMABLE
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	
	unlockable_items[id] = item

func _add_default_colored_dice(id: String, item_name: String, desc: String, condition_type: int, target: int) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.COLORED_DICE_FEATURE
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	
	unlockable_items[id] = item

func _add_default_mod(id: String, item_name: String, desc: String, condition_type: int, target: int) -> void:
	var condition = UnlockConditionClass.new()
	condition.id = id + "_condition"
	condition.condition_type = condition_type
	condition.target_value = target
	
	var item = UnlockableItemClass.new()
	item.id = id
	item.item_type = UnlockableItemClass.ItemType.MOD
	item.display_name = item_name
	item.description = desc
	item.unlock_condition = condition
	
	unlockable_items[id] = item