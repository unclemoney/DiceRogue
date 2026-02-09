extends PowerUp
class_name RandomCardLevelPowerUp

## RandomCardLevelPowerUp
##
## Rare PowerUp with a 20% chance each turn to upgrade a random
## scorecard category's level (from both upper and lower sections).
## Uses scorecard.upgrade_category() to apply the level boost.
## Price: $300, Rarity: Rare, Rating: PG-13
##
## Side-effects: Modifies scorecard category levels permanently.

var scorecard_ref: Scorecard = null
var upgrades_granted: int = 0
const UPGRADE_CHANCE: float = 0.2

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying RandomCardLevelPowerUp ===")
	var card = target as Scorecard
	if not card:
		push_error("[RandomCardLevelPowerUp] Target is not a Scorecard")
		return
	
	scorecard_ref = card
	upgrades_granted = 0
	
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.turn_tracker:
		var tracker = game_controller.turn_tracker
		if tracker.has_signal("turn_started"):
			if not tracker.is_connected("turn_started", _on_turn_started):
				tracker.turn_started.connect(_on_turn_started)
				print("[RandomCardLevelPowerUp] Connected to turn_started signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_turn_started() -> void:
	if not scorecard_ref:
		return
	
	var roll = randf()
	if roll <= UPGRADE_CHANCE:
		_upgrade_random_category()
	else:
		print("[RandomCardLevelPowerUp] No upgrade this turn (rolled %.2f, needed <= %.2f)" % [roll, UPGRADE_CHANCE])

func _upgrade_random_category() -> void:
	## _upgrade_random_category()
	##
	## Picks a random category from all 13 scorecard categories
	## (6 upper + 7 lower) and upgrades it one level.
	if not scorecard_ref:
		return
	
	var upper_categories = ["ones", "twos", "threes", "fours", "fives", "sixes"]
	var lower_categories = ["three_of_a_kind", "four_of_a_kind", "full_house", "small_straight", "large_straight", "yahtzee", "chance"]
	
	# Randomly pick upper or lower, then pick category
	var use_upper = randi() % 2 == 0
	var section: Scorecard.Section
	var category: String
	
	if use_upper:
		section = Scorecard.Section.UPPER
		category = upper_categories[randi() % upper_categories.size()]
	else:
		section = Scorecard.Section.LOWER
		category = lower_categories[randi() % lower_categories.size()]
	
	var current_level = scorecard_ref.get_category_level(section, category)
	var section_name = "upper" if use_upper else "lower"
	print("[RandomCardLevelPowerUp] Upgrading %s/%s from level %d!" % [section_name, category, current_level])
	
	scorecard_ref.upgrade_category(section, category)
	upgrades_granted += 1
	
	# Visual feedback
	_play_upgrade_effect(category)
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func _play_upgrade_effect(category_name: String) -> void:
	## _play_upgrade_effect()
	##
	## Shows a floating text notification when a category is upgraded.
	if not is_inside_tree() or not get_tree():
		return
	
	var label = Label.new()
	label.text = "%s LEVELED UP!" % category_name.to_upper().replace("_", " ")
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4, 1.0))  # Green
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1001
	
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2(viewport_size.x / 2 - 120, viewport_size.y * 0.35)
	label.size = Vector2(240, 40)
	get_tree().root.add_child(label)
	
	var ltween = get_tree().create_tween()
	ltween.set_parallel(true)
	ltween.tween_property(label, "position:y", label.position.y - 60, 1.0).set_ease(Tween.EASE_OUT)
	ltween.tween_property(label, "modulate:a", 0.0, 1.0).set_ease(Tween.EASE_IN).set_delay(0.4)
	ltween.chain().tween_callback(func():
		label.queue_free()
	)

func get_current_description() -> String:
	return "20%% chance each turn to level up a random scorecard category.\nUpgrades granted: %d" % upgrades_granted

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("random_card_level")
		if icon:
			icon.update_hover_description()

func remove(_target) -> void:
	print("=== Removing RandomCardLevelPowerUp ===")
	# Note: Category upgrades are permanent - they are NOT reversed on removal
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.turn_tracker:
		var tracker = game_controller.turn_tracker
		if tracker.has_signal("turn_started"):
			if tracker.is_connected("turn_started", _on_turn_started):
				tracker.turn_started.disconnect(_on_turn_started)
	
	scorecard_ref = null

func _on_tree_exiting() -> void:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.turn_tracker:
		var tracker = game_controller.turn_tracker
		if tracker.has_signal("turn_started"):
			if tracker.is_connected("turn_started", _on_turn_started):
				tracker.turn_started.disconnect(_on_turn_started)
