extends PowerUp
class_name DaringDicePowerUp

## DaringDicePowerUp
##
## Rare PowerUp that immediately removes 2 dice from the player's hand
## but grants a permanent +50 score bonus (additive) via ScoreModifierManager.
## Always removes exactly 2 dice regardless of current count.
## Shows "-2 DICE" in red text on activation (no warning dialog).
## Price: $300, Rarity: Rare, Rating: PG-13
##
## Risk/reward: Fewer dice means harder combos, but +50 per score is huge.

var dice_hand_ref: Node = null
var dice_removed: int = 0
const DICE_TO_REMOVE: int = 2
const SCORE_BONUS: int = 50

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying DaringDicePowerUp ===")
	if not target:
		push_error("[DaringDicePowerUp] Target is null")
		return
	
	dice_hand_ref = target
	
	# Immediately remove 2 dice
	dice_hand_ref.dice_count -= DICE_TO_REMOVE
	dice_removed = DICE_TO_REMOVE
	print("[DaringDicePowerUp] Removed %d dice. Dice count now: %d" % [DICE_TO_REMOVE, dice_hand_ref.dice_count])
	
	# Register the +50 additive score bonus
	ScoreModifierManager.register_additive("daring_dice", SCORE_BONUS)
	print("[DaringDicePowerUp] Registered +%d additive bonus" % SCORE_BONUS)
	
	# Show the "-2 DICE" red text effect
	_play_dice_removed_effect()
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _play_dice_removed_effect() -> void:
	## _play_dice_removed_effect()
	##
	## Shows a dramatic "-2 DICE" label in red text that floats and fades.
	if not is_inside_tree() or not get_tree():
		return
	
	var label = Label.new()
	label.text = "-2 DICE"
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))  # Bright red
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1001
	
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2(viewport_size.x / 2 - 80, viewport_size.y * 0.4)
	label.size = Vector2(160, 50)
	get_tree().root.add_child(label)
	
	# Shake + float up + fade
	var ltween = create_tween()
	
	# Initial shake
	ltween.tween_property(label, "position:x", label.position.x + 8, 0.05)
	ltween.tween_property(label, "position:x", label.position.x - 8, 0.05)
	ltween.tween_property(label, "position:x", label.position.x + 5, 0.05)
	ltween.tween_property(label, "position:x", label.position.x, 0.05)
	
	# Then float up and fade
	var float_tween = create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(label, "position:y", label.position.y - 80, 1.2).set_ease(Tween.EASE_OUT).set_delay(0.2)
	float_tween.tween_property(label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_delay(0.6)
	float_tween.chain().tween_callback(func():
		label.queue_free()
	)
	
	# Also show the +50 bonus text below
	var bonus_label = Label.new()
	bonus_label.text = "+%d SCORE BONUS" % SCORE_BONUS
	bonus_label.add_theme_font_size_override("font_size", 20)
	bonus_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))  # Green
	bonus_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	bonus_label.add_theme_constant_override("outline_size", 3)
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_label.z_index = 1001
	bonus_label.position = Vector2(viewport_size.x / 2 - 100, viewport_size.y * 0.4 + 40)
	bonus_label.size = Vector2(200, 40)
	get_tree().root.add_child(bonus_label)
	
	var btween = create_tween()
	btween.set_parallel(true)
	btween.tween_property(bonus_label, "position:y", bonus_label.position.y - 60, 1.2).set_ease(Tween.EASE_OUT).set_delay(0.4)
	btween.tween_property(bonus_label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_delay(0.8)
	btween.chain().tween_callback(func():
		bonus_label.queue_free()
	)

func get_current_description() -> String:
	return "-%d dice, +%d score bonus per category" % [DICE_TO_REMOVE, SCORE_BONUS]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("daring_dice")
		if icon:
			icon.update_hover_description()

func remove(target) -> void:
	print("=== Removing DaringDicePowerUp ===")
	# Restore removed dice
	var hand = target if target else dice_hand_ref
	if hand and dice_removed > 0:
		hand.dice_count += dice_removed
		print("[DaringDicePowerUp] Restored %d dice. Dice count now: %d" % [dice_removed, hand.dice_count])
		dice_removed = 0
	
	# Unregister score bonus
	ScoreModifierManager.unregister_additive("daring_dice")
	print("[DaringDicePowerUp] Unregistered +%d additive bonus" % SCORE_BONUS)
	
	dice_hand_ref = null

func _on_tree_exiting() -> void:
	ScoreModifierManager.unregister_additive("daring_dice")
