extends Control
class_name ShopItem

signal purchased(item_id: String, item_type: String)

@onready var card_panel: PanelContainer = $CardPanel
@onready var icon: TextureRect = $CardPanel/MarginContainer/ContentVBox/Icon
@onready var title_plate: PanelContainer = $CardPanel/MarginContainer/ContentVBox/TitlePlate
@onready var name_label: Label = $CardPanel/MarginContainer/ContentVBox/TitlePlate/NameLabel
@onready var buy_button: GlassActionButton = $CardPanel/MarginContainer/ContentVBox/BuyButton
@onready var rarity_badge: PanelContainer = $BadgeLayer/RarityBadge
@onready var rarity_label: Label = $BadgeLayer/RarityBadge/RarityLabel
@onready var price_badge: PanelContainer = $BadgeLayer/PriceBadge
@onready var price_label: Label = $BadgeLayer/PriceBadge/PriceLabel
@onready var _tfx := get_node("/root/TweenFXHelper")

# Dice texture and shader for colored dice shop cards
const DICE_TEXTURE_PATH := "res://Resources/Art/Dice/dieWhite1.png"
const DICE_SHADER_PATH := "res://Scripts/Shaders/dice_combined_effects.gdshader"
const RARITY_BADGE_SHADER_PATH := "res://Scripts/Shaders/rarity_badge.gdshader"
const PRICE_TAG_SHADER_PATH := "res://Scripts/Shaders/shop_price_tag.gdshader"
const CARD_PANEL_SHADER_PATH := "res://Scripts/Shaders/shop_card_panel.gdshader"
const SHOP_ITEM_THEME = preload("res://Resources/UI/shop_item_theme.tres")
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const BADGE_CORNER_RADIUS := 12.0
const CARD_CORNER_RADIUS := 10.0
# Shop-exclusive amber/gold palette for the glass Buy button.
const SHOP_BUY_BUTTON_PALETTE := {
	"base_color": Color(0.321569, 0.203922, 0.070588, 0.92),
	"mid_color": Color(0.478431, 0.32549, 0.117647, 0.96),
	"accent_color": Color(0.964706, 0.760784, 0.360784, 1.0),
	"glow_color": Color(1.0, 0.898039, 0.6, 1.0),
	"rim_color": Color(1.0, 0.956863, 0.823529, 1.0),
	"font_color": Color(1.0, 0.968627, 0.878431, 1.0),
	"font_outline_color": Color(0.2, 0.12, 0.03, 0.0),
	"outline_size": 0
}
const HANG_PIVOT_Y := 32.0
const TITLE_FONT_SIZE_DEFAULT := 24
const TITLE_FONT_SIZE_MIN := 16
const TITLE_HORIZONTAL_PADDING := 8.0
const BADGE_SIDE_MARGIN := 12.0
const BADGE_TOP := 44.0
const BADGE_HEIGHT := 28.0
const RARITY_BADGE_MIN_WIDTH := 36.0
const PRICE_BADGE_MIN_WIDTH := 72.0
const SWING_HALF_DURATION := 0.095
const SWING_SETTLE_DURATION := 0.21
const SWING_ANGLE_MIN := 1.0
const SWING_ANGLE_MAX := 3.0
const SWING_COUNT_MIN := 1
const SWING_COUNT_MAX := 3

var item_id: String
var item_type: String
var price: int
var item_data: Resource  # Store the data resource for tooltip access
var color_type: DiceColor.Type = DiceColor.Type.NONE  # Track color type for colored dice
var _base_title_text: String = ""
var _rng := RandomNumberGenerator.new()
# Shader-backed overlay rects (created in _apply_shop_item_styling).
var _card_fx_rect: ColorRect
var _rarity_fx_rect: ColorRect
var _price_fx_rect: ColorRect

# Purchase/removal guards to prevent race conditions between buy click,
# hover tweens, and the removal animation started by ShopUI.
var _is_purchasing: bool = false
var _is_being_removed: bool = false

# Hover tooltip variables
var hover_tooltip: PanelContainer
var hover_tooltip_label: Label
var is_hovered: bool = false
var is_card_hovered: bool = false
var is_button_hovered: bool = false
var _hover_tween: Tween
var _time: float = 0.0
const RAINBOW_SPEED := 0.5
const RAINBOW_COLORS := [
	Color(1, 0, 0),    # Red
	Color(1, 0.5, 0),  # Orange
	Color(1, 1, 0),    # Yellow
	Color(0, 1, 0),    # Green
	Color(0, 0, 1),    # Blue
	Color(0.5, 0, 1),  # Purple
]

func _ready() -> void:
	print("[ShopItem] Initializing:", name)
	
	if not card_panel or not icon or not name_label or not price_label or not buy_button or not rarity_badge or not price_badge:
		push_error("[ShopItem] Required nodes not found!")
		for child in get_children():
			print("[ShopItem] Found child:", child.name)
		return
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_STOP
	rarity_badge.visible = false
	rotation_degrees = 0.0
	if not resized.is_connected(_on_shop_item_resized):
		resized.connect(_on_shop_item_resized)
	call_deferred("_on_shop_item_resized")
	# Apply theme and uniform card size
	#theme = load("res://Resources/UI/action_button_theme_no_panel.tres")
	#custom_minimum_size = Vector2(180, 180)

	# Explicitly connect the button signal; GlassActionButton handles its own
	# hover/press juice internally, so no TweenFX hookups are needed here.
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
		buy_button.configure("BUY", Vector2(0, 34), SHOP_BUY_BUTTON_PALETTE, 16, VCR_FONT)
		print("[ShopItem] Connected buy button signal")

	# Card hover juice
	mouse_entered.connect(_on_shop_item_mouse_entered)
	mouse_exited.connect(_on_shop_item_mouse_exited)

	# Initialize tooltip references now so they are non-null during removal.
	_setup_hover_tooltip()
	_apply_shop_item_styling()
	_apply_shop_item_fonts()

func _process(delta: float) -> void:
	if not buy_button:
		return
	
	_time += delta * RAINBOW_SPEED
	
	# Calculate two color indices for interpolation
	var color_count: int = RAINBOW_COLORS.size()
	var index1: int = int(_time) % color_count
	var index2: int = (index1 + 1) % color_count
	var t: float = fmod(_time, 1.0)  # Interpolation factor
	
	# Interpolate between colors (for potential future rainbow effects)
	var _current_color: Color = RAINBOW_COLORS[index1].lerp(RAINBOW_COLORS[index2], t)
	
	# Rainbow effect could be applied to shop_label if needed in the future
	# Check if this is a power-up item and if there's a maximum reached
	if item_type == "power_up":
		# Find the GameController to check ownership directly
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller:
			# Check if we already own this power-up
			if game_controller.active_power_ups.has(item_id):
				buy_button.disabled = true
				buy_button.text = "OWNED"
				return
			
		# Check if maximum reached via PowerUpUI
		var power_up_ui = _find_power_up_ui()
		if power_up_ui and power_up_ui.has_max_power_ups():
			buy_button.disabled = true
			buy_button.text = "MAX REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and (buy_button.text == "MAX REACHED" or buy_button.text == "OWNED"):
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a consumable item and if there's a maximum reached
	elif item_type == "consumable":
		# Find the ConsumableUI node to check if maximum reached
		var consumable_ui = _find_consumable_ui()
		if consumable_ui and consumable_ui.has_max_consumables():
			# Disable the buy button and show "MAX REACHED" text
			buy_button.disabled = true
			buy_button.text = "MAX REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and buy_button.text == "MAX REACHED":
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a mod item and if there's a mod limit reached
	elif item_type == "mod":
		# Find the GameController to check mod vs dice count limit
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and _has_reached_mod_limit(game_controller):
			# Disable the buy button and show "LIMIT REACHED" text
			buy_button.disabled = true
			buy_button.text = "LIMIT REACHED"
		else:
			# Re-enable the button if previously disabled
			if buy_button.disabled and buy_button.text == "LIMIT REACHED":
				buy_button.disabled = false
				buy_button.text = "BUY"
	
	# Check if this is a colored dice item - update price and status dynamically
	elif item_type == "colored_dice":
		_update_colored_dice_display()

	# Check if this is a gaming console and the player already owns one
	elif item_type == "gaming_console":
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and game_controller.has_method("has_gaming_console"):
			if game_controller.has_gaming_console():
				buy_button.disabled = true
				buy_button.text = "LIMIT (1)"
			else:
				if buy_button.disabled and buy_button.text == "LIMIT (1)":
					buy_button.disabled = false
					buy_button.text = "BUY"

func setup(data: Resource, type: String) -> void:
	print("[ShopItem] Setting up item:", data.id)
	item_id = data.id
	item_type = type
	item_data = data  # Store the data for tooltip access
	_base_title_text = data.display_name
	
	# Apply shop price multiplier from channel difficulty
	var base_price = data.price
	price = _apply_price_multiplier(base_price, type)
	
	# Apply consumable-based discounts (Half Price, Loss Leader)
	price = _apply_consumable_discounts(price, type)
	
	if not icon or not name_label or not price_label:
		push_error("[ShopItem] One or more required nodes not found!")
		return
	
	# Explicitly set icon size and expansion
	icon.custom_minimum_size = Vector2(68, 68)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Handle colored dice icons specially - use dice texture with color shader
	if type == "colored_dice" and data is ColoredDiceData:
		color_type = data.color_type
		_setup_colored_dice_icon(data.color_type)
	else:
		icon.texture = data.icon
	
	_set_title_text(_base_title_text)
	_update_price_badge_from_price(price)
	_update_rarity_badge()
	
	# Apply shop item styling with border this is currently empty
	_apply_shop_item_styling()
	
	# Apply VCR font to labels and button
	_apply_shop_item_fonts()
	
	# Enforce uniform card size and theme for all item types
	#custom_minimum_size = Vector2(180, 180)
	#theme = load("res://Resources/UI/action_button_theme_no_panel.tres")
	
	_setup_hover_tooltip()
	
	_update_button_state()
	if not PlayerEconomy.is_connected("money_changed", _update_button_state):
		PlayerEconomy.money_changed.connect(_update_button_state)
	call_deferred("_fit_title")
	call_deferred("_layout_badges")
	#print("[ShopItem] Connected to PlayerEconomy.money_changed, Instance ID:", PlayerEconomy.get_instance_id())
	#print("[ShopItem] Setup complete for:", data.id)

func _update_button_state(_new_amount := 0, _change := 0) -> void:
	#print("[ShopItem] _update_button_state called")
	#print("[ShopItem] Updating button state for", item_id, "- Player money:", PlayerEconomy.money, ", Price:", price)
	if buy_button:
		if _is_purchasing or _is_being_removed:
			return
		if buy_button.text in ["OWNED", "MAX REACHED", "LIMIT REACHED", "LIMIT (1)", "MAX ODDS"]:
			buy_button.disabled = true
			return
		buy_button.disabled = not PlayerEconomy.can_afford(price)
		#print("[ShopItem] Buy button state updated - disabled:", buy_button.disabled)


## _apply_price_multiplier(base_price, type_str) -> int
##
## Applies the channel difficulty shop price multiplier to the base price.
## Uses different multipliers for colored dice vs other shop items.
## @param base_price: The original item price
## @param type_str: The type of item ("colored_dice", "power_up", "consumable", "mod")
## @return int: The modified price (rounded to nearest integer)
func _apply_price_multiplier(base_price: int, type_str: String) -> int:
	var channel_manager = _find_channel_manager()
	if not channel_manager:
		return base_price
	
	var multiplier: float = 1.0
	if type_str == "colored_dice":
		# Use specialized colored dice cost multiplier
		if channel_manager.has_method("get_colored_dice_cost_multiplier"):
			multiplier = channel_manager.get_colored_dice_cost_multiplier()
	else:
		# Use general shop price multiplier
		if channel_manager.has_method("get_shop_price_multiplier"):
			multiplier = channel_manager.get_shop_price_multiplier()
	
	return int(round(base_price * multiplier))


## _apply_consumable_discounts(current_price, type_str) -> int
##
## Applies active consumable-based discounts (Half Price for power_ups, Loss Leader for consumables).
## Called during setup() and refresh_price().
func _apply_consumable_discounts(current_price: int, type_str: String) -> int:
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if not game_controller:
		return current_price
	
	if type_str == "power_up" and game_controller.half_price_stacks > 0:
		var multiplier = game_controller.get_half_price_multiplier()
		current_price = int(round(current_price * multiplier))
		if current_price < 1:
			current_price = 1
	elif type_str == "consumable" and game_controller.loss_leader_stacks > 0:
		current_price = 0
	
	return current_price


## refresh_price()
##
## Recalculates price with channel multiplier + consumable discounts and updates the label.
## Called by ShopUI.refresh_all_prices() when discount state changes.
func refresh_price() -> void:
	if not item_data:
		return
	var base_price = item_data.price
	price = _apply_price_multiplier(base_price, item_type)
	price = _apply_consumable_discounts(price, item_type)
	_update_price_badge_from_price(price)
	_update_button_state()


## _find_channel_manager() -> Node
##
## Locates the ChannelManager in the scene tree.
## @return Node: The ChannelManager or null if not found
func _find_channel_manager():
	# Try to find via scene tree
	var root = get_tree().current_scene
	if root:
		var channel_manager = root.get_node_or_null("ChannelManager")
		if channel_manager:
			return channel_manager
	
	# Try to find via game controller
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller:
		var parent = game_controller.get_parent()
		if parent:
			var channel_manager = parent.get_node_or_null("ChannelManager")
			if channel_manager:
				return channel_manager
	
	return null


func _on_buy_button_pressed() -> void:
	# Prevent double clicks / re-entry while a purchase is in flight.
	if _is_purchasing:
		return
	_is_purchasing = true
	if buy_button:
		buy_button.disabled = true
		buy_button.text = "BUYING..."
	
	# Pre-purchase validation for mods - check if mod limit is reached
	if item_type == "mod":
		var game_controller = get_tree().get_first_node_in_group("game_controller")
		if game_controller and _has_reached_mod_limit(game_controller):
			print("[ShopItem] Mod purchase blocked - limit reached (all dice have mods)")
			buy_button.disabled = true
			buy_button.text = "LIMIT REACHED"
			_is_purchasing = false
			# Play denied sound
			var audio_mgr = get_node_or_null("/root/AudioManager")
			if audio_mgr:
				audio_mgr.play_denied_sound()
			return
	
	if PlayerEconomy.can_afford(price):
		print("[ShopItem] Purchase request ready for", item_id, "at", price)
		print("[ShopItem] Emitting purchase signal for:", item_id, "type:", item_type)
		emit_signal("purchased", item_id, item_type)
		print("[ShopItem] Purchase signal emitted")
		# Leave _is_purchasing set until ShopUI resolves the request.
		return
	else:
		print("[ShopItem] Cannot afford", item_id, "(cost:", price, ", money:", PlayerEconomy.money, ")")
		# Play denied sound
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_denied_sound()
		# Shake the buy button to indicate insufficient funds
		if buy_button:
			TweenFX.shake(buy_button, 0.2, 5.0, 3)
		_is_purchasing = false
	_update_button_state()


## cancel_purchase_request()
##
## Resets the temporary BUYING state when ShopUI rejects or rolls back a request.
func cancel_purchase_request() -> void:
	if _is_being_removed:
		return
	_is_purchasing = false
	if buy_button and buy_button.text == "BUYING...":
		buy_button.text = "BUY"
	_update_button_state()


# Helper function to find the PowerUpUI node
func _find_power_up_ui() -> PowerUpUI:
	# Try to find it in the scene tree
	var candidates = get_tree().get_nodes_in_group("power_up_ui")
	if candidates.size() > 0:
		return candidates[0]
		
	# Or navigate up to GameController and then down
	var root = get_tree().get_root()
	var game_controller = root.find_child("GameController", true, false)
	if game_controller:
		return game_controller.get_node_or_null("PowerUpUI") as PowerUpUI
	
	return null

# Helper function to find the ConsumableUI node
func _find_consumable_ui():
	# Try to find ConsumableUI via group
	var candidates = get_tree().get_nodes_in_group("consumable_ui")
	if candidates.size() > 0:
		return candidates[0]
		
	# Or navigate up to GameController and then down via GameUI
	var root = get_tree().get_root()
	var game_controller = root.find_child("GameController", true, false)
	if game_controller:
		return game_controller.get_node_or_null("../GameUI/MarginContainer/MainVBox/MiddleSection/LeftColumn/ConsumableContainer/ContentVBox/ConsumableUI")
	
	return null

# Helper function to check if mod limit has been reached
func _has_reached_mod_limit(game_controller: GameController) -> bool:
	if not game_controller:
		return false
	
	var current_mod_count = game_controller._get_total_active_mod_count()
	# Use expected dice count instead of current dice list size to handle pre-spawn scenario
	var expected_dice_count = game_controller._get_expected_dice_count()
	
	#print("[ShopItem] Mod limit check - Current mods:", current_mod_count, "Expected dice count:", expected_dice_count)
	return current_mod_count >= expected_dice_count

## _setup_hover_tooltip()
## Creates and configures the hover tooltip for shop items.
## Called during setup() and, if setup() has not run yet, in _ready() so
## mark_for_removal() always has a valid hover_tooltip reference.
func _setup_hover_tooltip() -> void:
	var needs_create := not hover_tooltip or not is_instance_valid(hover_tooltip)
	if needs_create:
		hover_tooltip = PanelContainer.new()
		hover_tooltip.name = "HoverTooltip"
		hover_tooltip.visible = false
		hover_tooltip.z_index = 4000
		hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not hover_tooltip_label or not is_instance_valid(hover_tooltip_label):
		hover_tooltip_label = Label.new()
		hover_tooltip_label.name = "HoverTooltipLabel"
		hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hover_tooltip_label.custom_minimum_size = Vector2(220, 0)
		hover_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hover_tooltip.theme = SHOP_ITEM_THEME
	hover_tooltip.theme_type_variation = &"ShopTooltipPanel"
	hover_tooltip_label.theme = SHOP_ITEM_THEME
	hover_tooltip_label.theme_type_variation = &"ShopTooltipLabel"
	hover_tooltip_label.text = _get_current_tooltip_text()

	if hover_tooltip_label.get_parent() != hover_tooltip:
		hover_tooltip.add_child(hover_tooltip_label)

	if needs_create:
		var scene_root = get_tree().current_scene
		if scene_root:
			scene_root.add_child.call_deferred(hover_tooltip)
			print("[ShopItem] Added tooltip to scene root (deferred)")
		else:
			get_parent().add_child.call_deferred(hover_tooltip)
			print("[ShopItem] Added tooltip to direct parent (deferred)")

	# Connect hover signals for the card itself
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)

	# Connect hover signals for the buy button to maintain tooltip visibility
	if buy_button:
		if not buy_button.mouse_entered.is_connected(_on_button_mouse_entered):
			buy_button.mouse_entered.connect(_on_button_mouse_entered)
		if not buy_button.mouse_exited.is_connected(_on_button_mouse_exited):
			buy_button.mouse_exited.connect(_on_button_mouse_exited)

	print("[ShopItem] Tooltip created with direct styling")

## _on_mouse_entered()
## Shows the hover tooltip when mouse enters the shop item card.
func _on_mouse_entered() -> void:
	# Never show the tooltip while the card is being removed.
	if _is_being_removed:
		return
	if not hover_tooltip or not item_data:
		return

	if hover_tooltip_label:
		hover_tooltip_label.text = _get_current_tooltip_text()

	is_card_hovered = true
	is_hovered = true
	hover_tooltip.visible = true
	_update_tooltip_position()

## _on_mouse_exited()
## Hides the hover tooltip when mouse exits the shop item card
func _on_mouse_exited() -> void:
	if not hover_tooltip:
		return

	is_card_hovered = false
	# Only hide if not hovering over the button either
	if not is_button_hovered:
		is_hovered = false
		hover_tooltip.visible = false

## _on_button_mouse_entered()
## Called when mouse enters the buy button - keeps tooltip visible
func _on_button_mouse_entered() -> void:
	if _is_being_removed:
		return
	is_button_hovered = true
	# Show tooltip if it exists
	if hover_tooltip and item_data:
		if hover_tooltip_label:
			hover_tooltip_label.text = _get_current_tooltip_text()
		is_hovered = true
		hover_tooltip.visible = true
		_update_tooltip_position()

## _on_button_mouse_exited()
## Called when mouse exits the buy button - hides tooltip if not on card
func _on_button_mouse_exited() -> void:
	is_button_hovered = false
	# Only hide if not hovering over the card either
	if not is_card_hovered and hover_tooltip:
		is_hovered = false
		hover_tooltip.visible = false

## _update_tooltip_position()
## Positions the tooltip relative to the shop item using the shared placement API.
func _update_tooltip_position() -> void:
	if not hover_tooltip or not hover_tooltip.visible:
		return
	_tfx.place_tooltip(hover_tooltip, get_global_rect())


## _on_shop_item_mouse_entered()
## Plays a short hanging-sign swing around the hook pivot.
func _on_shop_item_mouse_entered() -> void:
	# Ignore hover effects once the purchase has started; the card is about
	# to be removed and hover tweens must not kill the removal animation.
	if _is_purchasing or _is_being_removed:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_play_hang_swing()


## _on_shop_item_mouse_exited()
## Returns the hanging sign to its neutral angle.
func _on_shop_item_mouse_exited() -> void:
	# Ignore hover effects once the purchase has started.
	if _is_purchasing or _is_being_removed:
		return
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_return_to_rest_rotation()


## mark_for_removal()
## Called by ShopUI before the purchase-out animation starts.
## Kills any running hover tweens, hides the tooltip, blocks input,
## and stops hover handlers from interrupting the removal animation.
func mark_for_removal() -> void:
	_is_being_removed = true
	_is_purchasing = true

	# Stop any hover juice so it cannot kill the removal tween.
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = null
	rotation_degrees = 0.0

	# Hide tooltip and reset hover state.
	is_hovered = false
	is_card_hovered = false
	is_button_hovered = false
	if hover_tooltip:
		hover_tooltip.visible = false

	# Block all input to this card and its children so the mouse cannot
	# re-trigger hover or buy logic while it is being animated out.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_propagate_mouse_filter(self, Control.MOUSE_FILTER_IGNORE)


## _propagate_mouse_filter(node, filter)
## Recursively sets mouse_filter on the given Control and all descendants.
func _propagate_mouse_filter(node: Control, filter: Control.MouseFilter) -> void:
	if not is_instance_valid(node):
		return
	node.mouse_filter = filter
	for child in node.get_children():
		if child is Control:
			_propagate_mouse_filter(child, filter)


## _apply_shop_item_styling()
## Background and border are handled by the theme; shader overlays add depth.
func _apply_shop_item_styling() -> void:
	card_panel.theme = SHOP_ITEM_THEME
	title_plate.theme = SHOP_ITEM_THEME
	rarity_badge.theme = SHOP_ITEM_THEME
	price_badge.theme = SHOP_ITEM_THEME
	if not _card_fx_rect:
		_card_fx_rect = _create_fx_rect(card_panel, CARD_PANEL_SHADER_PATH, "CardFxRect")
	if not _rarity_fx_rect:
		_rarity_fx_rect = _create_fx_rect(rarity_badge, RARITY_BADGE_SHADER_PATH, "RarityFxRect")
	if not _price_fx_rect:
		_price_fx_rect = _create_fx_rect(price_badge, PRICE_TAG_SHADER_PATH, "PriceFxRect")
	if _rarity_fx_rect and _rarity_fx_rect.material:
		(_rarity_fx_rect.material as ShaderMaterial).set_shader_parameter("corner_radius", BADGE_CORNER_RADIUS)
	if _price_fx_rect and _price_fx_rect.material:
		(_price_fx_rect.material as ShaderMaterial).set_shader_parameter("corner_radius", BADGE_CORNER_RADIUS)
	if _card_fx_rect and _card_fx_rect.material:
		(_card_fx_rect.material as ShaderMaterial).set_shader_parameter("corner_radius", CARD_CORNER_RADIUS)
	_update_fx_rect_sizes()
	print("[ShopItem] Theme styling applied via shop_item_theme.tres")


## _create_fx_rect(parent, shader_path, rect_name) -> ColorRect
## Builds a full-rect ColorRect overlay with the given shader and inserts it
## behind the parent's other children so labels/content draw on top.
func _create_fx_rect(parent: Control, shader_path: String, rect_name: String) -> ColorRect:
	var fx_rect := ColorRect.new()
	fx_rect.name = rect_name
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader := load(shader_path) as Shader
	if shader:
		var fx_material := ShaderMaterial.new()
		fx_material.shader = shader
		fx_rect.material = fx_material
	else:
		push_error("[ShopItem] Failed to load shader: " + shader_path)
	parent.add_child(fx_rect)
	parent.move_child(fx_rect, 0)
	return fx_rect


## _update_fx_rect_sizes()
## Pushes current control sizes into the shader overlays so their rounded
## masks and gradients track layout. Called on resize and badge layout.
func _update_fx_rect_sizes() -> void:
	if _card_fx_rect and _card_fx_rect.material and card_panel:
		var card_size := card_panel.size
		if card_size.x <= 0.0 or card_size.y <= 0.0:
			card_size = custom_minimum_size
		(_card_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", card_size)
	if _rarity_fx_rect and _rarity_fx_rect.material and rarity_badge:
		(_rarity_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", rarity_badge.size)
	if _price_fx_rect and _price_fx_rect.material and price_badge:
		(_price_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", price_badge.size)

## _apply_shop_item_fonts()
## Applies VCR font to shop item labels and button
func _apply_shop_item_fonts() -> void:
	if name_label:
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.clip_text = true
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.custom_minimum_size = Vector2(0, 32)
	if price_label:
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if rarity_label:
		rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

## _setup_colored_dice_icon()
##
## Sets up the icon for a colored dice shop item.
## Loads the dice texture and applies the color shader to display
## the dice with its characteristic color glow effect.
##
## @param dice_color_type: DiceColor.Type to display
func _setup_colored_dice_icon(dice_color_type: DiceColor.Type) -> void:
	if not icon:
		return
	
	# Load the dice texture
	var dice_texture = load(DICE_TEXTURE_PATH)
	if not dice_texture:
		push_error("[ShopItem] Failed to load dice texture from: " + DICE_TEXTURE_PATH)
		return
	
	icon.texture = dice_texture
	
	# Load and apply the shader
	var shader = load(DICE_SHADER_PATH)
	if not shader:
		push_error("[ShopItem] Failed to load dice shader from: " + DICE_SHADER_PATH)
		return
	
	# Create shader material and apply to icon
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	
	# Reset all color strengths
	shader_material.set_shader_parameter("green_color_strength", 0.0)
	shader_material.set_shader_parameter("red_color_strength", 0.0)
	shader_material.set_shader_parameter("purple_color_strength", 0.0)
	shader_material.set_shader_parameter("blue_color_strength", 0.0)
	shader_material.set_shader_parameter("glow_strength", 0.0)
	shader_material.set_shader_parameter("lock_overlay_strength", 0.0)
	shader_material.set_shader_parameter("disabled", false)
	
	# Set the appropriate color strength based on dice color type
	match dice_color_type:
		DiceColor.Type.GREEN:
			shader_material.set_shader_parameter("green_color_strength", 0.8)
		DiceColor.Type.RED:
			shader_material.set_shader_parameter("red_color_strength", 0.8)
		DiceColor.Type.PURPLE:
			shader_material.set_shader_parameter("purple_color_strength", 0.8)
		DiceColor.Type.BLUE:
			shader_material.set_shader_parameter("blue_color_strength", 0.8)
	
	icon.material = shader_material
	print("[ShopItem] Set up colored dice icon with shader for:", DiceColor.get_color_name(dice_color_type))


## _update_colored_dice_display()
## Updates price, button status, and tooltip for colored dice items dynamically
func _update_colored_dice_display() -> void:
	if item_type != "colored_dice" or not item_data:
		return
	
	# Get color type from the data (use local var to avoid shadowing class var)
	var dice_color = item_data.color_type
	
	# Get current dynamic price from DiceColorManager
	var current_cost = DiceColorManager.get_current_color_cost(dice_color)
	var purchase_count = DiceColorManager.get_color_purchase_count(dice_color)
	var at_max = DiceColorManager.is_color_at_max_odds(dice_color)
	
	# Update price display
	if at_max:
		_set_price_badge_text("MAX", "max")
	else:
		_set_price_badge_text(NumberFormatter.format_money(current_cost), "normal")
	
	# Update internal price for purchase validation
	price = current_cost
	
	# Update button status
	if buy_button:
		if at_max:
			buy_button.disabled = true
			buy_button.text = "MAX ODDS"
		elif not PlayerEconomy.can_afford(current_cost):
			buy_button.disabled = true
			buy_button.text = "BUY"
		else:
			buy_button.disabled = false
			buy_button.text = "BUY"
	
	# Update name label to show ownership count
	if purchase_count > 0:
		_set_title_text("%s x%d" % [_base_title_text, purchase_count])
	else:
		_set_title_text(_base_title_text)


## _get_colored_dice_tooltip_text()
## Builds enhanced tooltip text for colored dice showing purchase info
func _get_colored_dice_tooltip_text() -> String:
	if item_type != "colored_dice" or not item_data:
		return item_data.description if item_data else ""
	
	var dice_color = item_data.color_type
	var tooltip_lines = []
	
	# Base description
	tooltip_lines.append(item_data.description)
	tooltip_lines.append("")
	
	# Effect description
	if item_data.effect_description and item_data.effect_description != "":
		tooltip_lines.append("Effect: " + item_data.effect_description)
	
	tooltip_lines.append("")
	
	# Purchase info from DiceColorManager
	tooltip_lines.append(DiceColorManager.get_color_shop_tooltip(dice_color))
	
	return "\n".join(tooltip_lines)


func _on_shop_item_resized() -> void:
	_update_hang_pivot()
	_layout_badges()
	_update_fx_rect_sizes()
	call_deferred("_fit_title")


func _update_hang_pivot() -> void:
	var card_width := size.x
	if card_width <= 0.0:
		card_width = custom_minimum_size.x
	pivot_offset = Vector2(card_width * 0.5, HANG_PIVOT_Y)


func _set_title_text(title_text: String) -> void:
	if not name_label:
		return
	if name_label.text == title_text:
		return
	name_label.text = title_text
	call_deferred("_fit_title")


func _fit_title() -> void:
	if not name_label or not is_inside_tree():
		return
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	name_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_DEFAULT)
	await scene_tree.process_frame
	if not is_inside_tree() or get_tree() == null or not is_instance_valid(name_label):
		return
	var safe_width := title_plate.size.x - TITLE_HORIZONTAL_PADDING
	if safe_width <= 0.0:
		var card_width := size.x
		if card_width <= 0.0:
			card_width = custom_minimum_size.x
		safe_width = card_width - 48.0
	var title_font: Font = name_label.get_theme_font("font")
	if not title_font:
		title_font = VCR_FONT
	for font_size in range(TITLE_FONT_SIZE_DEFAULT, TITLE_FONT_SIZE_MIN - 1, -1):
		name_label.add_theme_font_size_override("font_size", font_size)
		await scene_tree.process_frame
		if not is_inside_tree() or get_tree() == null or not is_instance_valid(name_label):
			return
		var measured_width := title_font.get_string_size(
			name_label.text,
			name_label.horizontal_alignment,
			-1,
			font_size
		).x
		if measured_width <= safe_width:
			break


func _update_rarity_badge() -> void:
	if not rarity_badge or not rarity_label:
		return
	if item_type != "power_up" or not item_data or not (item_data is PowerUpData):
		rarity_badge.visible = false
		return
	var rarity_key: String = item_data.rarity.to_lower()
	rarity_badge.visible = true
	rarity_label.text = _get_rarity_badge_text(rarity_key)
	_apply_rarity_badge_palette(rarity_key)
	_layout_badges()


func _get_rarity_badge_text(rarity_key: String) -> String:
	return PowerUpData.get_rarity_display_char(rarity_key)


func _apply_rarity_badge_palette(rarity_key: String) -> void:
	var bg_color := Color(0.301961, 0.180392, 0.286275, 0.96)
	var border_color := Color(0.964706, 0.768627, 0.45098, 0.92)
	var text_color := Color(0.984314, 0.952941, 0.878431, 1.0)
	match rarity_key:
		"common":
			bg_color = Color(0.247059, 0.25098, 0.301961, 0.96)
			border_color = Color(0.776471, 0.815686, 0.862745, 0.9)
		"uncommon":
			bg_color = Color(0.188235, 0.305882, 0.215686, 0.96)
			border_color = Color(0.682353, 0.913725, 0.631373, 0.95)
		"rare":
			bg_color = Color(0.180392, 0.223529, 0.368627, 0.96)
			border_color = Color(0.588235, 0.768627, 0.980392, 0.95)
		"epic":
			bg_color = Color(0.321569, 0.160784, 0.396078, 0.96)
			border_color = Color(0.886275, 0.627451, 1.0, 0.95)
		"legendary":
			bg_color = Color(0.462745, 0.239216, 0.121569, 0.96)
			border_color = Color(1.0, 0.862745, 0.490196, 1.0)
	if rarity_badge:
		var badge_style := rarity_badge.get_theme_stylebox("panel") as StyleBoxFlat
		if badge_style:
			var override_style := badge_style.duplicate() as StyleBoxFlat
			# Fill and border hidden; the rarity shader overlay carries the visuals.
			override_style.bg_color = Color(bg_color, 0.0)
			override_style.border_color = Color(border_color, 0.0)
			rarity_badge.add_theme_stylebox_override("panel", override_style)
	if rarity_label:
		rarity_label.add_theme_color_override("font_color", text_color)
		rarity_label.add_theme_font_size_override("font_size", 11)
	# Push rarity colors into the juice shader; rarer tiers get more energy.
	if _rarity_fx_rect and _rarity_fx_rect.material:
		var fx_material := _rarity_fx_rect.material as ShaderMaterial
		fx_material.set_shader_parameter("rarity_color", border_color)
		fx_material.set_shader_parameter("glow_color", text_color)
		match rarity_key:
			"legendary":
				fx_material.set_shader_parameter("pulse_strength", 0.65)
				fx_material.set_shader_parameter("sheen_speed", 1.4)
			"epic":
				fx_material.set_shader_parameter("pulse_strength", 0.5)
				fx_material.set_shader_parameter("sheen_speed", 1.1)
			"rare":
				fx_material.set_shader_parameter("pulse_strength", 0.4)
				fx_material.set_shader_parameter("sheen_speed", 1.0)
			_:
				fx_material.set_shader_parameter("pulse_strength", 0.3)
				fx_material.set_shader_parameter("sheen_speed", 0.8)


func _update_price_badge_from_price(current_price: int) -> void:
	if current_price == 0:
		_set_price_badge_text("FREE", "free")
	else:
		_set_price_badge_text(NumberFormatter.format_money(current_price), "normal")


func _set_price_badge_text(text: String, palette: String) -> void:
	if not price_badge or not price_label:
		return
	price_label.text = text
	# Shop-exclusive amber/gold tag for normal prices; mint for FREE, red for MAX.
	var bg_color := Color(0.38, 0.26, 0.09, 0.96)
	var top_color := Color(0.58, 0.42, 0.15, 0.96)
	var accent_color := Color(1.0, 0.85, 0.45, 1.0)
	var border_color := Color(0.98, 0.8, 0.42, 0.95)
	var text_color := Color(1.0, 0.956863, 0.823529, 1.0)
	match palette:
		"free":
			bg_color = Color(0.16, 0.38, 0.3, 0.96)
			top_color = Color(0.24, 0.52, 0.42, 0.96)
			accent_color = Color(0.75, 1.0, 0.85, 1.0)
			border_color = Color(0.827451, 0.941176, 0.647059, 0.95)
			text_color = Color(0.94902, 1.0, 0.929412, 1.0)
		"max":
			bg_color = Color(0.42, 0.16, 0.16, 0.96)
			top_color = Color(0.58, 0.24, 0.24, 0.96)
			accent_color = Color(1.0, 0.65, 0.6, 1.0)
			border_color = Color(1.0, 0.643137, 0.643137, 0.98)
			text_color = Color(1.0, 0.909804, 0.909804, 1.0)
	var badge_style := price_badge.get_theme_stylebox("panel") as StyleBoxFlat
	if badge_style:
		var override_style := badge_style.duplicate() as StyleBoxFlat
		# Fill and border hidden; the price tag shader overlay carries the visuals.
		override_style.bg_color = Color(bg_color, 0.0)
		override_style.border_color = Color(border_color, 0.0)
		price_badge.add_theme_stylebox_override("panel", override_style)
	price_label.add_theme_color_override("font_color", text_color)
	price_label.add_theme_color_override("font_outline_color", Color(0.15, 0.1, 0.03, 0.8))
	price_label.add_theme_constant_override("outline_size", 2)
	if _price_fx_rect and _price_fx_rect.material:
		var fx_material := _price_fx_rect.material as ShaderMaterial
		fx_material.set_shader_parameter("base_color", bg_color)
		fx_material.set_shader_parameter("top_color", top_color)
		fx_material.set_shader_parameter("accent_color", accent_color)
	_layout_badges()


func _layout_badges() -> void:
	var card_width := size.x
	if card_width <= 0.0:
		card_width = custom_minimum_size.x
	var badge_font: Font = price_label.get_theme_font("font") if price_label else VCR_FONT
	if not badge_font:
		badge_font = VCR_FONT
	if rarity_badge and rarity_label:
		var rarity_text_width := badge_font.get_string_size(rarity_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 11).x
		var rarity_width := maxf(RARITY_BADGE_MIN_WIDTH, rarity_text_width + 14.0)
		rarity_badge.custom_minimum_size = Vector2(rarity_width, BADGE_HEIGHT)
		rarity_badge.position = Vector2(BADGE_SIDE_MARGIN, BADGE_TOP)
		rarity_badge.size = rarity_badge.custom_minimum_size
	if price_badge and price_label:
		var price_text_width := badge_font.get_string_size(price_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12).x
		var price_width := maxf(PRICE_BADGE_MIN_WIDTH, price_text_width + 18.0)
		price_badge.custom_minimum_size = Vector2(price_width, BADGE_HEIGHT)
		price_badge.position = Vector2(card_width - price_width - BADGE_SIDE_MARGIN, BADGE_TOP)
		price_badge.size = price_badge.custom_minimum_size
	_update_fx_rect_sizes()


func _get_current_tooltip_text() -> String:
	if not item_data:
		return ""
	if item_type == "colored_dice":
		return _get_colored_dice_tooltip_text()
	if item_type == "power_up" and item_data is PowerUpData:
		return _get_power_up_tooltip_text()
	return item_data.description


## _get_power_up_tooltip_text()
## Builds the PowerUp tooltip: description, then a footer with the
## Mom approval rating label and the rarity, in that order.
func _get_power_up_tooltip_text() -> String:
	var tooltip_lines: Array = []
	tooltip_lines.append(item_data.description)
	tooltip_lines.append("")
	tooltip_lines.append("Mom Approval: " + StickerBadge.get_sticker_label(item_data.rating))
	tooltip_lines.append("Rarity: " + item_data.rarity.capitalize())
	return "\n".join(tooltip_lines)


func _play_hang_swing() -> void:
	_update_hang_pivot()
	rotation_degrees = 0.0
	var base_angle := _rng.randf_range(SWING_ANGLE_MIN, SWING_ANGLE_MAX)
	var swing_count := _rng.randi_range(SWING_COUNT_MIN, SWING_COUNT_MAX)
	var direction := -1.0
	if _rng.randi() % 2 == 0:
		direction = 1.0
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE)
	_hover_tween.set_ease(Tween.EASE_IN_OUT)
	for swing_index in range(swing_count):
		var damping := 1.0 - (float(swing_index) * 0.14)
		if damping < 0.5:
			damping = 0.5
		var swing_angle := base_angle * damping
		_hover_tween.tween_property(self, "rotation_degrees", swing_angle * direction, SWING_HALF_DURATION)
		_hover_tween.tween_property(self, "rotation_degrees", -swing_angle * direction, SWING_HALF_DURATION)
	_hover_tween.tween_property(self, "rotation_degrees", 0.0, SWING_SETTLE_DURATION)


func _return_to_rest_rotation(duration: float = SWING_SETTLE_DURATION) -> void:
	_hover_tween = create_tween()
	_hover_tween.set_trans(Tween.TRANS_SINE)
	_hover_tween.set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "rotation_degrees", 0.0, duration)
