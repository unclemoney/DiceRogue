# GameController.gd
extends Node
class_name GameController

signal power_up_granted(id: String, power_up: PowerUp)
signal power_up_revoked(id: String)
signal consumable_used(id: String, consumable: Consumable)

# Active power-ups and consumables in the game dictionaries
var active_power_ups: Dictionary = {}  # id -> PowerUp
var active_consumables: Dictionary = {}  # id -> Consumable
var active_debuffs: Dictionary = {}  # id -> Debuff
var active_mods: Dictionary = {}  # id -> Mod
var active_challenges: Dictionary = {}  # id -> Challenge

const ScoreCardUI := preload("res://Scripts/UI/score_card_ui.gd")
const DebuffManager := preload("res://Scripts/Managers/DebuffManager.gd")
const DebuffUI := preload("res://Scripts/UI/debuff_ui.gd")
const ScoreCard := preload("res://Scenes/ScoreCard/score_card.gd")

# Centralized, explicit NodePaths (tweak in Inspector if scene changes)
@export var dice_hand_path: NodePath            = ^"../DiceHand"
@export var turn_tracker_path: NodePath         = ^"../TurnTracker"
@export var power_up_manager_path: NodePath     = ^"../PowerUpManager"
@export var power_up_ui_path: NodePath          = ^"../PowerUpUI"
@export var power_up_container_path: NodePath   = ^"PowerUpContainer"
@export var consumable_manager_path: NodePath   = ^"../ConsumableManager"
@export var consumable_ui_path: NodePath        = ^"../ConsumableUI"
@export var consumable_container_path: NodePath = ^"ConsumableContainer"
@export var score_card_ui_path: NodePath        = ^"../ScoreCardUI"
@export var debuff_ui_path: NodePath            = ^"../DebuffUI"
@export var debuff_container_path: NodePath     = ^"DebuffContainer"
@export var debuff_manager_path: NodePath       = ^"../DebuffManager"
@export var score_card_path: NodePath           = ^"../ScoreCard"
@export var mod_manager_path: NodePath          = ^"../ModManager"
@export var shop_ui_path: NodePath              = ^"../ShopUI"
@export var game_button_ui_path: NodePath       = ^"../GameButtonUI"
@export var challenge_manager_path: NodePath    = ^"../ChallengeManager"
@export var challenge_ui_path: NodePath         = ^"../ChallengeUI"
@export var challenge_container_path: NodePath  = ^"ChallengeContainer"
@export var round_manager_path: NodePath        = ^"../RoundManager"

@onready var consumable_manager: ConsumableManager = get_node(consumable_manager_path)
@onready var consumable_ui: ConsumableUI = get_node(consumable_ui_path)
@onready var consumable_container: Node  = get_node(consumable_container_path)
@onready var dice_hand: DiceHand         = get_node(dice_hand_path) as DiceHand
@onready var turn_tracker: TurnTracker   = get_node(turn_tracker_path) as TurnTracker
@onready var pu_manager: PowerUpManager  = get_node(power_up_manager_path) as PowerUpManager
@onready var powerup_ui: PowerUpUI       = get_node(power_up_ui_path) as PowerUpUI
@onready var power_up_container: Node    = get_node(power_up_container_path)
@onready var score_card_ui: ScoreCardUI  = get_node(score_card_ui_path) as ScoreCardUI
@onready var debuff_ui: DebuffUI         = get_node(debuff_ui_path) as DebuffUI
@onready var debuff_container: Node      = get_node(debuff_container_path)
@onready var debuff_manager: DebuffManager = get_node(debuff_manager_path) as DebuffManager
@onready var scorecard: ScoreCard          = get_node(score_card_path) as ScoreCard
@onready var mod_manager: ModManager       = get_node(mod_manager_path) as ModManager
@onready var shop_ui: ShopUI               = get_node(shop_ui_path) as ShopUI
@onready var game_button_ui: Control       = get_node(game_button_ui_path)
@onready var challenge_manager: ChallengeManager = get_node(challenge_manager_path) as ChallengeManager
@onready var challenge_ui: ChallengeUI     = get_node(challenge_ui_path) as ChallengeUI
@onready var challenge_container: Node     = get_node(challenge_container_path)
@onready var round_manager: RoundManager   = get_node_or_null(round_manager_path)

const STARTING_POWER_UP_IDS := ["extra_dice", "extra_rolls"]

var _last_modded_die_index: int = -1  # Track which die received the last mod

var pending_mods: Array[String] = []
var mod_persistence_map: Dictionary = {}  # mod_id -> int tracking how many instances of each mod should persist
var _shop_tween: Tween


func _ready() -> void:
	add_to_group("game_controller")
	print("▶ GameController._ready()")
	if dice_hand:
		dice_hand.roll_complete.connect(_on_roll_completed)
		dice_hand.dice_spawned.connect(_on_dice_spawned)
	if scorecard:
		scorecard.score_auto_assigned.connect(_on_score_assigned)
	if game_button_ui:
		game_button_ui.connect("shop_button_pressed", _on_shop_button_pressed)	
	if shop_ui:
		print("[GameController] Setting up shop UI")
		shop_ui.hide()
		shop_ui.connect("item_purchased", _on_shop_item_purchased)
	if challenge_manager:
		challenge_manager.challenge_completed.connect(_on_challenge_completed)
		challenge_manager.challenge_failed.connect(_on_challenge_failed)
	if round_manager:
		round_manager.round_started.connect(_on_round_started)
		round_manager.round_completed.connect(_on_round_completed)
		round_manager.round_failed.connect(_on_round_failed)
		round_manager.all_rounds_completed.connect(_on_all_rounds_completed)
	if consumable_ui:
		if not consumable_ui.is_connected("consumable_sold", _on_consumable_sold):
			consumable_ui.connect("consumable_sold", _on_consumable_sold)
	if powerup_ui:
		if not powerup_ui.is_connected("max_power_ups_reached", _on_max_power_ups_reached):
			powerup_ui.connect("max_power_ups_reached", _on_max_power_ups_reached)
	call_deferred("_on_game_start")

func _on_game_start() -> void:
	#spawn_starting_powerups()
	#grant_consumable("score_reroll")
	#apply_debuff("lock_dice")
	#activate_challenge("300pts_no_debuff")
	if round_manager:
		round_manager.start_game()



func _process(delta):
	if Input.is_action_just_pressed("quit_game"):
		get_tree().quit()


func spawn_starting_powerups() -> void:
	for id in ["extra_dice", "extra_rolls"]:
		var def: PowerUpData = pu_manager.get_def(id)
		if def:
			var icon = powerup_ui.add_power_up(def)
			# Connect the signals from the icon
			icon.power_up_selected.connect(_on_power_up_selected)
			icon.power_up_deselected.connect(_on_power_up_deselected)

			# Create the power up but don't apply it yet
			var pu: PowerUp = pu_manager.spawn_power_up(id, power_up_container)
			if pu:
				active_power_ups[id] = pu
			else:
				push_error("No PowerUpData for '%s'" % id)


func grant_power_up(id: String) -> void:
	print("\n=== Granting Power-Up: ", id, " ===")
	
	# Check if we've reached the maximum number of power-ups
	if powerup_ui and powerup_ui.has_max_power_ups():
		print("[GameController] Maximum number of power-ups reached. Cannot add more.")
		return
	
	# 1) Spawn logic via scene manager
	var pu := pu_manager.spawn_power_up(id, power_up_container) as PowerUp
	if pu == null:
		push_error("[GameController] Failed to spawn PowerUp '%s'" % id)
		return

	# Create and connect UI first
	var def: PowerUpData = pu_manager.get_def(id)
	if def:
		var icon = powerup_ui.add_power_up(def)
		if icon:
			print("[GameController] Connecting power-up signals for:", id)
			# Connect the sell signal
			if not powerup_ui.is_connected("power_up_sold", _on_power_up_sold):
				powerup_ui.connect("power_up_sold", _on_power_up_sold)
		else:
			push_error("[GameController] Failed to create UI icon for power-up:", id)
			
	# Store the power-up reference
	active_power_ups[id] = pu
	emit_signal("power_up_granted", id, pu)
	print("[GameController] Power-up granted and ready:", id)
	
	# Automatically activate the power-up
	_activate_power_up(id)

# Add this function to handle power-up activation
func _activate_power_up(power_up_id: String) -> void:
	print("\n=== Power-up Auto-Activated ===")
	print("[GameController] Activating power-up:", power_up_id)
	
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return
	
	# Special handling for Foursome power-up
	if power_up_id == "foursome":
		print("[GameController] Applying Foursome to scorecard:", scorecard)
		if scorecard:
			pu.apply(scorecard)
			# Verify multiplier function is set
			scorecard.debug_multiplier_function()
		else:
			push_error("[GameController] No scorecard available for Foursome power-up")
	# Regular power-ups
	else:
		match power_up_id:
			"extra_dice":
				pu.apply(dice_hand)
				enable_debuff("lock_dice")
			"extra_rolls":
				pu.apply(turn_tracker)
			_:
				push_error("[GameController] Unknown power-up type:", power_up_id)

# Add this function to handle power-up selling
func _on_power_up_sold(power_up_id: String) -> void:
	print("[GameController] Selling power-up:", power_up_id)
	
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return
		
	# Get the refund amount (half of purchase price)
	var def = pu_manager.get_def(power_up_id)
	if def:
		var refund = def.price / 2
		print("[GameController] Refunding", refund, "coins for power-up:", power_up_id)
		PlayerEconomy.add_money(refund)
	
	# Deactivate and remove the power-up
	_deactivate_power_up(power_up_id)
	
	# Remove the power-up
	revoke_power_up(power_up_id)
	
	# Remove the UI icon
	powerup_ui.remove_power_up(power_up_id)

# Add this function to handle power-up deactivation
func _deactivate_power_up(power_up_id: String) -> void:
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return
		
	match power_up_id:
		"extra_dice":
			pu.remove(dice_hand)
			disable_debuff("lock_dice")
		"extra_rolls":
			pu.remove(turn_tracker)
		"foursome":
			pu.remove(scorecard)
		_:
			push_error("[GameController] Unknown power-up type:", power_up_id)
func revoke_power_up(power_up_id: String) -> void:
	if not active_power_ups.has(power_up_id):
		return

	var pu := active_power_ups[power_up_id] as PowerUp
	if pu:
		# Pass the correct target based on power-up type
		match power_up_id:
			"extra_dice":
				pu.remove(dice_hand)
			"extra_rolls":
				pu.remove(turn_tracker)
			"foursome":
				pu.remove(scorecard)
			_:
				# For unknown types, use the stored reference in the PowerUp itself
				pu.remove(pu)
		
		pu.queue_free()
	active_power_ups.erase(power_up_id)
	emit_signal("power_up_revoked", power_up_id)

func _on_power_up_selected(power_up_id: String) -> void:
	print("\n=== Power-up Selected ===")
	print("[GameController] Activating power-up:", power_up_id)
	
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("[GameController] No PowerUp found for id:", power_up_id)
		return
		
	match power_up_id:
		"extra_dice":
			pu.apply(dice_hand)
			enable_debuff("lock_dice")
		"extra_rolls":
			pu.apply(turn_tracker)
		"foursome":
			print("[GameController] Applying Foursome to scorecard:", scorecard)
			pu.apply(scorecard)
		_:
			push_error("[GameController] Unknown power-up type:", power_up_id)

func _on_power_up_deselected(power_up_id: String) -> void:
	var pu = active_power_ups.get(power_up_id)
	if not pu:
		push_error("No PowerUp found for id: %s" % power_up_id)
		return
		
	match power_up_id:
		"extra_dice":
			pu.remove(dice_hand)
			disable_debuff("lock_dice")
		"extra_rolls":
			pu.remove(turn_tracker)
		"foursome":
			pu.remove(scorecard)
		_:
			push_error("Unknown target for power-up: %s" % power_up_id)

func grant_consumable(id: String) -> void:
	var consumable := consumable_manager.spawn_consumable(id, consumable_container) as Consumable
	if consumable == null:
		push_error("[GameController] Failed to spawn Consumable '%s'" % id)
		return

	active_consumables[id] = consumable
	
	# Add to UI with null checks
	var def: ConsumableData = consumable_manager.get_def(id)
	if not def:
		push_error("[GameController] No ConsumableData found for '%s'" % id)
		return
		
	var icon = consumable_ui.add_consumable(def) #, consumable
	if not icon:
		push_error("[GameController] Failed to create UI icon for consumable '%s'" % id)
		return

	# Connect signals and set initial state
	icon.consumable_used.connect(_on_consumable_used)
	
	# Set initial usability state
	match id:
		"score_reroll":
			# Score reroll is only useable if we have scores
			var can_use = scorecard and scorecard.has_any_scores()
			icon.set_useable(can_use)
			print("[GameController] Score reroll consumable added, useable:", can_use)
		_:
			# Other consumables are useable by default
			icon.set_useable(true)
			print("[GameController] Consumable granted and ready:", id)

func _on_consumable_used(consumable_id: String) -> void:
	var consumable = active_consumables.get(consumable_id)
	if not consumable:
		push_error("No Consumable found for id: %s" % consumable_id)
		return
		
	match consumable_id:
		"score_reroll":
			if score_card_ui:
				# Activate reroll mode
				consumable.apply(self)
				score_card_ui.activate_score_reroll()
				# Connect to score_rerolled signal for cleanup
				if not score_card_ui.is_connected("score_rerolled", _on_score_rerolled):
					score_card_ui.connect("score_rerolled", _on_score_rerolled)
			else:
				push_error("GameController: score_card_ui not found!")
		"double_existing":
			if score_card_ui:
				# Activate double mode
				consumable.apply(self)
				# Connect to score_doubled signal for cleanup
				if not score_card_ui.is_connected("score_doubled", _on_score_doubled):
					score_card_ui.connect("score_doubled", _on_score_doubled)
			else:
				push_error("GameController: score_card_ui not found!")
		_:
			push_error("Unknown consumable type: %s" % consumable_id)

func _on_score_rerolled(_section: Scorecard.Section, _category: String, _score: int) -> void:
	var reroll = get_active_consumable("score_reroll") as ScoreRerollConsumable
	if reroll:
		reroll.complete_reroll()
		remove_consumable("score_reroll")

func _on_score_doubled(_section: Scorecard.Section, _category: String, _new_score: int) -> void:
	var double_consumable = get_active_consumable("double_existing") as DoubleExistingConsumable
	if double_consumable:
		double_consumable.complete_double()
		remove_consumable("double_existing")

func _on_score_assigned(_section: int, _category: String, _score: int) -> void:
	if not scorecard:
		push_error("No scorecard reference found")
		return
		
	if scorecard.has_any_scores():
		var reroll_icon = consumable_ui.get_consumable_icon("score_reroll")
		if reroll_icon:
			reroll_icon.set_useable(true)
		else:
			print("No reroll icon found")
	else:
		print("No scores yet, reroll remains disabled")

func apply_debuff(id: String) -> void:
	print("[GameController] Attempting to apply debuff:", id)
	var debuff := debuff_manager.spawn_debuff(id, debuff_container) as Debuff
	if debuff == null:
		push_error("[GameController] Failed to spawn Debuff '%s'" % id)
		return

	active_debuffs[id] = debuff
	
	# Add to UI with null checks
	var def: DebuffData = debuff_manager.get_def(id)
	if not def:
		push_error("No DebuffData found for '%s'" % id)
		return
		
	var icon = debuff_ui.add_debuff(def, debuff)
	if not icon:
		push_error("Failed to create UI icon for debuff '%s'" % id)
		return

	# Apply the debuff effect
	match id:
		"lock_dice":
			debuff.target = dice_hand
			debuff.start()
		"disabled_twos":
			debuff.target = dice_hand
			debuff.start()
		"roll_score_minus_one":
			debuff.target = self  # Target game controller to access multiple components
			debuff.start()
		_:
			push_error("Unknown debuff type: %s" % id)

func enable_debuff(id: String) -> void:
	if not is_debuff_active(id):
		apply_debuff(id)
	else:
		var debuff = active_debuffs[id]
		if debuff and debuff.target:
			debuff.start()

func disable_debuff(id: String) -> void:
	if is_debuff_active(id):
		var debuff = active_debuffs[id]
		if debuff:
			debuff.end()
			active_debuffs.erase(id)
			# Remove the icon from UI
			if debuff_ui:
				debuff_ui.remove_debuff(id)
			else:
				push_error("No debuff_ui found when trying to remove debuff icon")


func is_debuff_active(id: String) -> bool:
	return active_debuffs.has(id) and active_debuffs[id] != null

# Add this function after other consumable-related functions
func get_active_consumable(id: String) -> Consumable:
	if active_consumables.has(id):
		return active_consumables[id]
	return null

func remove_consumable(id: String) -> void:
	if active_consumables.has(id):
		var consumable = active_consumables[id]
		if consumable:
			consumable.queue_free()
		active_consumables.erase(id)
		
		# Remove from UI if it exists
		if consumable_ui:
			consumable_ui.remove_consumable(id)
		else:
			push_error("No consumable_ui found when trying to remove consumable icon")

func grant_mod(id: String) -> void:
	print("[GameController] Attempting to grant mod:", id)
	
	# Get the mod definition
	var def: ModData = mod_manager.get_def(id)
	if not def:
		push_error("[GameController] No ModData found for:", id)
		return
		
	# Store reference for later use
	active_mods[id] = def
	
	# Track this mod for persistence between rounds (increment count)
	if mod_persistence_map.has(id):
		mod_persistence_map[id] += 1
	else:
		mod_persistence_map[id] = 1
	
	print("[GameController] Mod persistence map updated:", mod_persistence_map)
	
	if dice_hand and dice_hand.dice_list.size() > 0:
		if _apply_mod_to_available_die(id):
			print("[GameController] Mod", id, "applied successfully")
		else:
			# Couldn't find a suitable die, add to pending
			print("[GameController] No suitable die found, adding to pending mods")
			if not pending_mods.has(id):
				pending_mods.append(id)
	else:
		# No dice available, add to pending
		print("[GameController] No dice available - adding to pending mods")
		if not pending_mods.has(id):
			pending_mods.append(id)

# Helper function to find and apply a mod to an available die
func _apply_mod_to_available_die(mod_id: String) -> bool:
	# Try to find a die WITHOUT ANY mod
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if die.active_mods.size() == 0:
			var mod = mod_manager.spawn_mod(mod_id, die)
			if mod:
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to empty die at index", i)
				return true
	
	# If no empty die found, try to find one without this specific mod
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if not die.has_mod(mod_id):
			var mod = mod_manager.spawn_mod(mod_id, die)
			if mod:
				die.add_mod(active_mods[mod_id])
				print("[GameController] Applied mod", mod_id, "to die at index", i)
				return true
	
	# No suitable die found
	return false

func _on_roll_completed() -> void:
	if is_debuff_active("lock_dice"):
		var debuff = active_debuffs["lock_dice"]
		if debuff and dice_hand:
			debuff.apply(dice_hand)
	else:
		if dice_hand:
			dice_hand.enable_all_dice()

func _on_dice_spawned() -> void:
	print("[GameController] mod_persistence_map:", mod_persistence_map)
	if not dice_hand:
		return
		
	print("[GameController] New dice spawned, checking for mods to apply")
	print("[GameController] Mod persistence map:", mod_persistence_map)
	
	# Track already applied mod types to prevent duplicates on a single die
	var applied_mod_counts = {}
	
	# First apply any pending mods (these are more recent)
	var mods_to_process = pending_mods.duplicate()
	pending_mods.clear()
	
	# Then add all persistent mods that should be reapplied
	for mod_id in mod_persistence_map:
		# Add each mod type the correct number of times
		var count = mod_persistence_map[mod_id]
		for i in range(count):
			mods_to_process.append(mod_id)
	
	print("[GameController] Total mods to process:", mods_to_process.size())
	print("[GameController] Mods to process:", mods_to_process)
	
	# Loop through all dice in order
	for die_index in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[die_index]
		
		# Skip dice that already have mods
		if die.active_mods.size() >= 1:
			print("[GameController] Dice at index", die_index, "already has mods, skipping")
			continue
			
		# Try to apply any available mod that hasn't been applied yet
		for i in range(mods_to_process.size()):
			var mod_id = mods_to_process[i]
			
			# Check if we've already applied the maximum number for this type
			if not applied_mod_counts.has(mod_id):
				applied_mod_counts[mod_id] = 0
				
			# Skip if we've already applied the maximum for this type
			if applied_mod_counts[mod_id] >= mod_persistence_map.get(mod_id, 1):
				continue
				
			var def = active_mods[mod_id]
			if def and not die.has_mod(mod_id):
				var mod = mod_manager.spawn_mod(mod_id, die)
				if mod:
					die.add_mod(def)
					# Record that we've applied an instance of this mod
					applied_mod_counts[mod_id] += 1
					print("[GameController] Applied mod", mod_id, "to die at index", die_index, 
						  "- count", applied_mod_counts[mod_id], "of", mod_persistence_map.get(mod_id, 1))
					
					# Remove this mod from the processing list
					mods_to_process.remove_at(i)
					break
		
		# If we've applied all available mods, we can stop
		if mods_to_process.is_empty():
			break
	
	# Add any mods that couldn't be applied back to pending_mods
	for mod_id in mods_to_process:
		print("[GameController] Couldn't apply mod", mod_id, ", adding to pending_mods")
		if not pending_mods.has(mod_id):
			pending_mods.append(mod_id)

func _on_shop_button_pressed() -> void:
	if shop_ui:
		if not shop_ui.visible:
			# Cancel any existing tween
			if _shop_tween and _shop_tween.is_valid():
				_shop_tween.kill()
			
			# 1. Show label immediately
			shop_ui.show()
			shop_ui.visible = true
			shop_ui.modulate.a = 0.0
			shop_ui.scale = Vector2(0.1, 0.1)

			# 2. Create new tween
			_shop_tween = get_tree().create_tween()

			# 3. Fade in (faster)
			_shop_tween.tween_property(
				shop_ui, "modulate:a", 1.0, 0.1
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			# 4. Bounce scale (faster)
			_shop_tween.tween_property(
				shop_ui, "scale", Vector2(1.0, 1.0), 0.85
			).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

			# 5. Settle scale (faster)
			_shop_tween.tween_property(
				shop_ui, "scale", Vector2.ONE, 0.05
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		else:
			shop_ui.scale = Vector2(1.0, 1.0)
			# Cancel any existing tween
			if _shop_tween and _shop_tween.is_valid():
				_shop_tween.kill()
						# 2. Create new tween
			_shop_tween = get_tree().create_tween()

			# 3. Fade in (faster)
			_shop_tween.tween_property(
				shop_ui, "modulate:a", 1.0, 0.1
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

			# 4. Bounce scale (faster)
			_shop_tween.tween_property(
				shop_ui, "scale", Vector2(0.001, 0.001), 0.55
			).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

			await _shop_tween.finished
			shop_ui.hide()

func _on_shop_item_purchased(item_id: String, item_type: String) -> void:
	print("[GameController] Processing purchase:", item_id, "type:", item_type)
	match item_type:
		"power_up":
			print("[GameController] Granting power-up:", item_id)
			grant_power_up(item_id)
		"consumable":
			print("[GameController] Granting consumable:", item_id)
			grant_consumable(item_id)
		"mod":
			print("[GameController] Granting mod:", item_id)
			grant_mod(item_id)
		_:
			push_error("[GameController] Unknown item type purchased:", item_type)

func activate_challenge(id: String) -> void:
	print("[GameController] Activating challenge:", id)
	
	if active_challenges.has(id):
		print("[GameController] Challenge already active:", id)
		return
		
	var challenge = challenge_manager.spawn_challenge(id, challenge_container) as Challenge
	if challenge == null:
		push_error("[GameController] Failed to spawn challenge:", id)
		return
		
	active_challenges[id] = challenge
	
	# Apply to game controller to access all needed systems
	challenge.target = self
	challenge.start()
	
	# Add to UI
	var def = challenge_manager.get_def(id)
	if def and challenge_ui:
		challenge_ui.add_challenge(def, challenge)
	else:
		push_error("[GameController] Failed to add challenge to UI")

func _on_challenge_completed(id: String) -> void:
	print("[GameController] Challenge completed:", id)
	
	# Grant reward if specified
	var def = challenge_manager.get_def(id)
	if def and def.reward_money > 0:
		print("[GameController] Granting reward:", def.reward_money)
		PlayerEconomy.add_money(def.reward_money)
	
	# Clean up challenge
	if active_challenges.has(id):
		var challenge = active_challenges[id]
		if challenge:
			challenge.queue_free()
		active_challenges.erase(id)

func _on_challenge_failed(id: String) -> void:
	print("[GameController] Challenge failed:", id)
	
	# Clean up challenge
	if active_challenges.has(id):
		var challenge = active_challenges[id]
		if challenge:
			challenge.queue_free()
		active_challenges.erase(id)

func _on_round_started(round_number: int) -> void:
	print("[GameController] Round", round_number, "started")
	
	# Activate this round's challenge
	if round_manager:
		var round_data = round_manager.get_current_round_data()
		if not round_data.challenge_id.is_empty():
			activate_challenge(round_data.challenge_id)
			print("[GameController] Activated challenge:", round_data.challenge_id)
	
	# Reset shop for new round
	if shop_ui:
		shop_ui.reset_for_new_round()
		print("[GameController] Shop reset for new round")

func _on_round_completed(round_number: int) -> void:
	print("[GameController] Round", round_number, "completed")

func _on_round_failed(round_number: int) -> void:
	print("[GameController] Round", round_number, "failed")
	# Game over logic here

func _on_all_rounds_completed() -> void:
	print("[GameController] All rounds completed!")
	# Victory logic here

func remove_debuff(id: String) -> void:
	print("[GameController] Removing debuff:", id)
	if is_debuff_active(id):
		var debuff = active_debuffs[id]
		if debuff:
			# Call remove on the debuff itself
			debuff.remove()
			debuff.queue_free()
			active_debuffs.erase(id)
			
		# Remove the icon from UI
		if debuff_ui:
			debuff_ui.remove_debuff(id)
		else:
			push_error("[GameController] No debuff_ui found when trying to remove debuff icon")
	else:
		print("[GameController] Debuff not active:", id)

func _on_max_power_ups_reached() -> void:
	print("[GameController] Maximum power-ups reached!")
	# Show notification to player
	#NotificationSystem.show_notification("Maximum power-ups (2) reached! Sell one to buy another.")

# Add this function to handle consumable selling
func _on_consumable_sold(consumable_id: String) -> void:
	print("[GameController] Selling consumable:", consumable_id)
	
	var consumable = active_consumables.get(consumable_id)
	if not consumable:
		push_error("[GameController] No Consumable found for id:", consumable_id)
		return
		
	# Get the refund amount (half of purchase price)
	var def = consumable_manager.get_def(consumable_id)
	if def:
		var refund = def.price / 2
		print("[GameController] Refunding", refund, "coins for consumable:", consumable_id)
		PlayerEconomy.add_money(refund)
	
	# Remove the consumable
	revoke_consumable(consumable_id)
	
	# Remove the UI icon
	consumable_ui.remove_consumable(consumable_id)

func revoke_consumable(consumable_id: String) -> void:
	if not active_consumables.has(consumable_id):
		return

	var consumable := active_consumables[consumable_id] as Consumable
	if consumable:
		consumable.queue_free()
	active_consumables.erase(consumable_id)

func refresh_shop() -> void:
	if shop_ui:
		shop_ui.reset_for_new_round()
		print("[GameController] Shop refreshed with new items")
