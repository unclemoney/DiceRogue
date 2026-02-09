extends PowerUp
class_name ThePiggyBankPowerUp

## ThePiggyBankPowerUp
##
## Uncommon PowerUp that accumulates $3 per roll (including rerolls).
## When sold, the player receives the accumulated savings as a bonus
## on top of the normal half-price sell refund.
## Shows an animated coin effect each time money is banked.
## Price: $125, Rarity: Uncommon, Rating: E
##
## Visual: Animated coin particle flies upward each roll to show saving.

var dice_hand_ref: Node = null
var accumulated_savings: int = 0
var game_controller_ref = null
const SAVINGS_PER_ROLL: int = 3

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying ThePiggyBankPowerUp ===")
	if not target:
		push_error("[ThePiggyBankPowerUp] Target is null")
		return
	
	dice_hand_ref = target
	accumulated_savings = 0
	
	game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	
	if dice_hand_ref.has_signal("roll_complete"):
		if not dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
			dice_hand_ref.roll_complete.connect(_on_roll_complete)
			print("[ThePiggyBankPowerUp] Connected to roll_complete signal")
	
	# Connect to power_up_sold signal for sell payout
	if game_controller_ref:
		var powerup_ui = game_controller_ref.powerup_ui
		if powerup_ui and powerup_ui.has_signal("power_up_sold"):
			if not powerup_ui.is_connected("power_up_sold", _on_power_up_sold):
				powerup_ui.power_up_sold.connect(_on_power_up_sold)
				print("[ThePiggyBankPowerUp] Connected to power_up_sold signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_roll_complete() -> void:
	accumulated_savings += SAVINGS_PER_ROLL
	print("[ThePiggyBankPowerUp] Saved $%d this roll. Total savings: $%d" % [SAVINGS_PER_ROLL, accumulated_savings])
	
	_play_coin_animation()
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func _on_power_up_sold(sold_id: String) -> void:
	## _on_power_up_sold()
	##
	## When this PowerUp is sold, pays out all accumulated savings
	## as bonus money on top of the normal sell refund. No confirmation dialog.
	if sold_id != "the_piggy_bank":
		return
	
	if accumulated_savings > 0:
		print("[ThePiggyBankPowerUp] SOLD! Paying out $%d in savings!" % accumulated_savings)
		PlayerEconomy.add_money(accumulated_savings)
		
		# Show big payout effect
		_play_payout_effect()
	else:
		print("[ThePiggyBankPowerUp] SOLD! No savings accumulated.")

func _play_coin_animation() -> void:
	## _play_coin_animation()
	##
	## Plays a small animated coin that flies upward and fades out
	## each time money is banked on a roll.
	if not is_inside_tree() or not get_tree():
		return
	
	var coin = Label.new()
	coin.text = "+$%d" % SAVINGS_PER_ROLL
	coin.add_theme_font_size_override("font_size", 16)
	coin.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))  # Gold
	coin.add_theme_color_override("font_outline_color", Color(0.3, 0.2, 0.0, 1.0))
	coin.add_theme_constant_override("outline_size", 3)
	coin.z_index = 500
	
	# Position near left quadrant center (where PowerUp icons display)
	var viewport_size = get_viewport().get_visible_rect().size
	var start_x = viewport_size.x * 0.15 + randf_range(-30, 30)
	var start_y = viewport_size.y * 0.5
	coin.position = Vector2(start_x, start_y)
	get_tree().root.add_child(coin)
	
	# Coin float + gold particle circle (use tree tween so it survives node destruction)
	var ctween = get_tree().create_tween()
	ctween.set_parallel(true)
	ctween.tween_property(coin, "position:y", start_y - 60, 0.8).set_ease(Tween.EASE_OUT)
	ctween.tween_property(coin, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.3)
	ctween.tween_property(coin, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
	ctween.chain().tween_callback(func():
		coin.queue_free()
	)
	
	# Spawn a few gold particles
	for i in range(5):
		var particle = ColorRect.new()
		particle.size = Vector2(3, 3)
		particle.color = Color(1.0, 0.85, 0.0, 0.8)
		particle.position = Vector2(start_x + randf_range(-10, 10), start_y)
		particle.z_index = 499
		get_tree().root.add_child(particle)
		
		var ptween = get_tree().create_tween()
		var angle = randf() * TAU
		var target_pos = particle.position + Vector2(cos(angle), sin(angle)) * randf_range(15, 40)
		ptween.set_parallel(true)
		ptween.tween_property(particle, "position", target_pos, 0.5).set_ease(Tween.EASE_OUT)
		ptween.tween_property(particle, "color:a", 0.0, 0.5).set_ease(Tween.EASE_IN)
		ptween.chain().tween_callback(func():
			particle.queue_free()
		)

func _play_payout_effect() -> void:
	## _play_payout_effect()
	##
	## Plays a large payout animation with cascading coins and big text
	## when the Piggy Bank is sold.
	if not is_inside_tree() or not get_tree():
		return
	
	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size / 2.0
	
	# Big payout text
	var label = Label.new()
	label.text = "+$%d PAYOUT!" % accumulated_savings
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.2, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1001
	label.position = Vector2(center.x - 120, center.y - 40)
	label.size = Vector2(240, 50)
	get_tree().root.add_child(label)
	
	var ltween = get_tree().create_tween()
	ltween.set_parallel(true)
	ltween.tween_property(label, "position:y", center.y - 120, 1.5).set_ease(Tween.EASE_OUT)
	ltween.tween_property(label, "modulate:a", 0.0, 1.5).set_ease(Tween.EASE_IN).set_delay(0.8)
	ltween.chain().tween_callback(func():
		label.queue_free()
	)
	
	# Cascading coin particles
	for i in range(15):
		var coin = ColorRect.new()
		coin.size = Vector2(5, 5)
		coin.color = Color(1.0, 0.85, 0.0, 1.0)
		coin.position = Vector2(center.x + randf_range(-60, 60), center.y)
		coin.z_index = 1000
		get_tree().root.add_child(coin)
		
		var angle = randf_range(-PI, 0)
		var dist = randf_range(80, 200)
		var target_pos = coin.position + Vector2(cos(angle), sin(angle)) * dist
		
		var ctween = get_tree().create_tween()
		ctween.set_parallel(true)
		ctween.tween_property(coin, "position", target_pos, 0.8 + randf_range(0, 0.4)).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		ctween.tween_property(coin, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.4 + i * 0.05)
		ctween.chain().tween_callback(func():
			coin.queue_free()
		)

func get_current_description() -> String:
	return "Gains $%d per roll.\nCurrent savings: $%d\nSell to cash out!" % [SAVINGS_PER_ROLL, accumulated_savings]

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("the_piggy_bank")
		if icon:
			icon.update_hover_description()

func remove(_target) -> void:
	print("=== Removing ThePiggyBankPowerUp ===")
	if dice_hand_ref:
		if dice_hand_ref.has_signal("roll_complete"):
			if dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
				dice_hand_ref.roll_complete.disconnect(_on_roll_complete)
	
	if game_controller_ref:
		var powerup_ui = game_controller_ref.powerup_ui
		if powerup_ui and powerup_ui.has_signal("power_up_sold"):
			if powerup_ui.is_connected("power_up_sold", _on_power_up_sold):
				powerup_ui.power_up_sold.disconnect(_on_power_up_sold)
	
	dice_hand_ref = null
	game_controller_ref = null

func _on_tree_exiting() -> void:
	if dice_hand_ref:
		if dice_hand_ref.has_signal("roll_complete"):
			if dice_hand_ref.is_connected("roll_complete", _on_roll_complete):
				dice_hand_ref.roll_complete.disconnect(_on_roll_complete)
	
	if game_controller_ref:
		var powerup_ui = game_controller_ref.powerup_ui
		if powerup_ui and powerup_ui.has_signal("power_up_sold"):
			if powerup_ui.is_connected("power_up_sold", _on_power_up_sold):
				powerup_ui.power_up_sold.disconnect(_on_power_up_sold)
