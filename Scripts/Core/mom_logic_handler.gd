extends RefCounted
class_name MomLogicHandler

## MomLogicHandler
##
## Handles the logic for Mom's appearance when chore progress reaches 100.
## Checks for R and NC-17 rated PowerUps and applies appropriate consequences.
## R-rated PowerUps are removed.
## NC-17 rated PowerUps are removed and a random debuff is stacked.
## If no chores were completed, player is fined $100 or gets a random debuff.

const AVAILABLE_DEBUFFS: Array[String] = ["lock_dice", "costly_roll", "disabled_twos", "roll_score_minus_one"]
const NO_CHORES_FINE: int = 100

## Result of Mom's check
class MomCheckResult:
	var removed_power_ups: Array[String] = []
	var applied_debuffs: Array[String] = []
	var mom_is_upset: bool = false
	var mom_is_furious: bool = false  # NC-17 found
	var no_chores_penalty: bool = false  # Player didn't complete any chores
	var fine_amount: int = 0  # Money fined (if any)
	var dialog_text: String = ""
	var expression: String = "neutral"

## trigger_mom_check()
##
## Performs the Mom check on the player's active power-ups and chore completion.
## Returns a MomCheckResult with all consequences.
##
## Parameters:
##   game_controller: Node - the GameController instance
##   chores_completed: int - number of chores completed since last Mom visit (default: -1 to skip check)
##   active_debuffs: Dictionary - currently active debuffs to avoid duplicates
##
## Returns: MomCheckResult
static func trigger_mom_check(game_controller: Node, chores_completed: int = -1, active_debuffs: Dictionary = {}) -> MomCheckResult:
	var result = MomCheckResult.new()
	var power_up_manager = game_controller.get("pu_manager")
	var active_power_ups: Dictionary = game_controller.get("active_power_ups")
	
	if active_power_ups == null:
		active_power_ups = {}
	
	var r_rated_ids: Array[String] = []
	var nc17_rated_ids: Array[String] = []
	
	# Scan all active power-ups for restricted ratings
	for power_up_id in active_power_ups.keys():
		var def = _get_power_up_def(power_up_manager, power_up_id)
		if def == null:
			continue
		
		var rating = def.get("rating") if def else "G"
		if rating == null:
			rating = "G"
		
		if PowerUpData.is_rating_nc17(rating):
			nc17_rated_ids.append(power_up_id)
		elif PowerUpData.is_rating_restricted(rating):
			r_rated_ids.append(power_up_id)
	
	# Process NC-17 first (worse consequences)
	if nc17_rated_ids.size() > 0:
		result.mom_is_furious = true
		result.mom_is_upset = true
		result.expression = "upset"
		
		for id in nc17_rated_ids:
			result.removed_power_ups.append(id)
		
		# Apply stacking debuffs for each NC-17 power-up (avoid duplicates)
		for i in range(nc17_rated_ids.size()):
			var random_debuff = _get_random_non_active_debuff(active_debuffs, result.applied_debuffs)
			if random_debuff != "":
				result.applied_debuffs.append(random_debuff)
		
		result.dialog_text = _get_nc17_dialog(nc17_rated_ids.size())
	
	# Process R-rated (just removal)
	if r_rated_ids.size() > 0:
		result.mom_is_upset = true
		if not result.mom_is_furious:
			result.expression = "upset"
		
		for id in r_rated_ids:
			result.removed_power_ups.append(id)
		
		if result.dialog_text == "":
			result.dialog_text = _get_r_rated_dialog(r_rated_ids.size())
		else:
			result.dialog_text += "\n\n" + _get_r_rated_dialog(r_rated_ids.size())
	
	# Check if player completed any chores (only if chores_completed was provided)
	if chores_completed == 0:
		result.no_chores_penalty = true
		result.mom_is_upset = true
		if not result.mom_is_furious:
			result.expression = "upset"
		
		# Try to fine the player $100
		var player_economy = Engine.get_singleton("PlayerEconomy") if Engine.has_singleton("PlayerEconomy") else null
		if player_economy == null:
			# Try autoload path
			var root = Engine.get_main_loop()
			if root and root.has_node("/root/PlayerEconomy"):
				player_economy = root.get_node("/root/PlayerEconomy")
		
		var can_pay = false
		if player_economy and player_economy.has_method("can_afford"):
			can_pay = player_economy.can_afford(NO_CHORES_FINE)
		
		if can_pay:
			result.fine_amount = NO_CHORES_FINE
			if result.dialog_text == "":
				result.dialog_text = _get_no_chores_fine_dialog()
			else:
				result.dialog_text += "\n\n" + _get_no_chores_fine_dialog()
		else:
			# Can't afford fine - apply random debuff instead
			var punishment_debuff = _get_random_non_active_debuff(active_debuffs, result.applied_debuffs)
			if punishment_debuff != "":
				result.applied_debuffs.append(punishment_debuff)
			if result.dialog_text == "":
				result.dialog_text = _get_no_chores_debuff_dialog()
			else:
				result.dialog_text += "\n\n" + _get_no_chores_debuff_dialog()
	
	# No restricted content found and chores were done (or not checked)
	if not result.mom_is_upset:
		result.expression = "happy"
		result.dialog_text = _get_happy_dialog()
	
	return result

## _get_random_non_active_debuff()
##
## Returns a random debuff ID that is not currently active.
## Checks both active_debuffs dictionary and already_applied array.
##
## Parameters:
##   active_debuffs: Dictionary - currently active debuffs
##   already_applied: Array - debuffs already being applied in this check
##
## Returns: String - debuff ID or empty string if all are active
static func _get_random_non_active_debuff(active_debuffs: Dictionary, already_applied: Array) -> String:
	var available: Array[String] = []
	for debuff_id in AVAILABLE_DEBUFFS:
		if not active_debuffs.has(debuff_id) and debuff_id not in already_applied:
			available.append(debuff_id)
	
	if available.is_empty():
		# All debuffs already active, pick a random one anyway (will stack or do nothing)
		return AVAILABLE_DEBUFFS[randi() % AVAILABLE_DEBUFFS.size()]
	
	return available[randi() % available.size()]

## apply_consequences()
##
## Applies the consequences from a MomCheckResult to the game state.
## Removes power-ups, applies debuffs, and deducts fines.
##
## Parameters:
##   game_controller: Node - the GameController instance
##   result: MomCheckResult - the result from trigger_mom_check()
static func apply_consequences(game_controller: Node, result: MomCheckResult) -> void:
	# Remove power-ups
	for power_up_id in result.removed_power_ups:
		if game_controller.has_method("revoke_power_up"):
			game_controller.revoke_power_up(power_up_id)
		print("[MomLogicHandler] Removed power-up: %s" % power_up_id)
	
	# Apply fine if any
	if result.fine_amount > 0:
		var player_economy = Engine.get_singleton("PlayerEconomy") if Engine.has_singleton("PlayerEconomy") else null
		if player_economy == null:
			var root = Engine.get_main_loop()
			if root and root.has_node("/root/PlayerEconomy"):
				player_economy = root.get_node("/root/PlayerEconomy")
		
		if player_economy and player_economy.has_method("remove_money"):
			player_economy.remove_money(result.fine_amount, "mom_fine")
			print("[MomLogicHandler] Fined player $%d for not doing chores" % result.fine_amount)
	
	# Apply debuffs (stacking for NC-17)
	for debuff_id in result.applied_debuffs:
		if game_controller.has_method("enable_debuff"):
			game_controller.enable_debuff(debuff_id)
		print("[MomLogicHandler] Applied debuff: %s" % debuff_id)
	
	# Mark debuffs as "grounded" so they persist until next round
	# This requires modification to debuff system or tracking in ChoresManager

static func _get_power_up_def(power_up_manager: Node, id: String) -> PowerUpData:
	if power_up_manager == null:
		return null
	if power_up_manager.has_method("get_def"):
		return power_up_manager.get_def(id)
	return null

static func _get_nc17_dialog(_count: int) -> String:
	var dialogs = [
		"[wave amp=50 freq=3][color=red]WHAT IS THIS?![/color][/wave] You are [shake rate=20 level=10]GROUNDED[/shake] young one! I'm confiscating this... this... [i]filth[/i]!",
		"[wave amp=30 freq=5][color=red]I can't believe what I'm seeing![/color][/wave] You're in [shake rate=15 level=8]BIG TROUBLE[/shake]! Hand it over!",
		"[color=red][shake rate=25 level=12]ABSOLUTELY NOT![/shake][/color] Where did you even GET this?! You're grounded until further notice!"
	]
	return dialogs[randi() % dialogs.size()]

static func _get_r_rated_dialog(_count: int) -> String:
	var dialogs = [
		"[color=orange]Hmm...[/color] What's this? You know you're not old enough for this kind of thing. I'm taking it away.",
		"[color=orange]Excuse me?[/color] This is [i]not[/i] appropriate for someone your age. Hand it over.",
		"[color=orange]*sigh*[/color] We've talked about this. You're not ready for this yet. Consider it confiscated."
	]
	return dialogs[randi() % dialogs.size()]

static func _get_no_chores_fine_dialog() -> String:
	var dialogs = [
		"[color=orange]And ANOTHER thing![/color] You haven't done [i]any[/i] of your chores! That's [b]$100[/b] from your allowance, young one!",
		"[color=orange]Wait a minute...[/color] Not a [i]single[/i] chore done?! I'm taking [b]$100[/b] for being so irresponsible!",
		"[color=orange]*sigh*[/color] No chores completed? Really? That'll be [b]$100[/b]. Maybe you'll learn to be more responsible."
	]
	return dialogs[randi() % dialogs.size()]

static func _get_no_chores_debuff_dialog() -> String:
	var dialogs = [
		"[color=red]You didn't do ANY chores?![/color] And you can't even pay the fine?! You're [shake rate=15 level=8]GROUNDED[/shake]!",
		"[wave amp=30 freq=4][color=red]UNBELIEVABLE![/color][/wave] No chores AND no money?! Consider yourself [shake rate=12 level=6]PUNISHED[/shake]!",
		"[color=red]Not only did you skip ALL your chores,[/color] but you're broke too?! There will be [shake rate=10 level=5]CONSEQUENCES[/shake]!"
	]
	return dialogs[randi() % dialogs.size()]

static func _get_happy_dialog() -> String:
	var dialogs = [
		"[color=green]Just checking in![/color] Everything looks good here. Keep up the good work, sweetie!",
		"[color=green]How's it going?[/color] I see you're being responsible. I'll leave you to it!",
		"[color=green]Doing your chores?[/color] That's my good kid! Let me know if you need anything.",
		"[color=green]Don't forget to take breaks![/color] You're doing great!"
	]
	return dialogs[randi() % dialogs.size()]
