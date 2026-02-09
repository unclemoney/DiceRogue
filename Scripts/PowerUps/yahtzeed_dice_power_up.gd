extends PowerUp
class_name YahtzeedDicePowerUp

## YahtzeedDicePowerUp
##
## Epic PowerUp that grants +1 die each time the player rolls a Yahtzee.
## Extra dice are permanent for the game duration (until PowerUp is removed).
## Capped at 16 total dice maximum.
## Price: $450, Rarity: Epic, Rating: R
##
## Connects to RollStats.yahtzee_rolled signal.

var dice_hand_ref: Node = null
var dice_added_count: int = 0
const MAX_DICE_CAP: int = 16

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying YahtzeedDicePowerUp ===")
	if not target:
		push_error("[YahtzeedDicePowerUp] Target is null")
		return
	
	dice_hand_ref = target
	dice_added_count = 0
	
	if RollStats.has_signal("yahtzee_rolled"):
		if not RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
			RollStats.yahtzee_rolled.connect(_on_yahtzee_rolled)
			print("[YahtzeedDicePowerUp] Connected to RollStats.yahtzee_rolled signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_yahtzee_rolled() -> void:
	## _on_yahtzee_rolled()
	##
	## Triggered when the player rolls a Yahtzee. Adds +1 die to the hand
	## up to the maximum dice cap of 16.
	if not dice_hand_ref:
		return
	
	if dice_hand_ref.dice_count >= MAX_DICE_CAP:
		print("[YahtzeedDicePowerUp] At max dice cap (%d). No additional die added." % MAX_DICE_CAP)
		return
	
	dice_hand_ref.dice_count += 1
	dice_added_count += 1
	print("[YahtzeedDicePowerUp] Yahtzee! +1 die granted. Total dice: %d (added: %d)" % [dice_hand_ref.dice_count, dice_added_count])
	
	# Visual and description update
	_play_dice_added_effect()
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func _play_dice_added_effect() -> void:
	## _play_dice_added_effect()
	##
	## Shows a floating "+1 DIE" text in gold when a new die is added.
	if not is_inside_tree() or not get_tree():
		return
	
	var label = Label.new()
	label.text = "+1 DIE!"
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0, 1.0))  # Gold
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1001
	
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2(viewport_size.x / 2 - 80, viewport_size.y * 0.4)
	label.size = Vector2(160, 40)
	get_tree().root.add_child(label)
	
	var ltween = create_tween()
	ltween.set_parallel(true)
	ltween.tween_property(label, "position:y", label.position.y - 70, 1.0).set_ease(Tween.EASE_OUT)
	ltween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN).set_delay(0.4)
	ltween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	ltween.chain().tween_callback(func():
		label.queue_free()
	)

func get_current_description() -> String:
	if dice_hand_ref:
		return "Gain +1 die per Yahtzee! (max %d)\nDice added: %d | Current dice: %d" % [MAX_DICE_CAP, dice_added_count, dice_hand_ref.dice_count]
	return "Gain +1 die per Yahtzee! (max %d)\nDice added: %d" % [MAX_DICE_CAP, dice_added_count]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("yahtzeed_dice")
		if icon:
			icon.update_hover_description()

func remove(target) -> void:
	print("=== Removing YahtzeedDicePowerUp ===")
	# Remove all added dice
	var hand = target if target else dice_hand_ref
	if hand and dice_added_count > 0:
		hand.dice_count -= dice_added_count
		print("[YahtzeedDicePowerUp] Removed %d dice. Dice count now: %d" % [dice_added_count, hand.dice_count])
		dice_added_count = 0
	
	if RollStats.has_signal("yahtzee_rolled"):
		if RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
			RollStats.yahtzee_rolled.disconnect(_on_yahtzee_rolled)
	
	dice_hand_ref = null

func _on_tree_exiting() -> void:
	if RollStats.has_signal("yahtzee_rolled"):
		if RollStats.is_connected("yahtzee_rolled", _on_yahtzee_rolled):
			RollStats.yahtzee_rolled.disconnect(_on_yahtzee_rolled)
