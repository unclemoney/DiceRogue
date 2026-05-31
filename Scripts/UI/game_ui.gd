extends Control
class_name GameUI

## GameUI
##
## Master UI container scene for the Guhtzee game.
## Builds a deterministic 13-container layout using nested Godot containers.
## All sizing is proportional via stretch ratios; no hardcoded offsets.
##
## Side-effects: Creates the full node tree in _ready().

# Container references — populated during _build_ui()
var turn_info_container: PanelContainer
var power_up_container: PanelContainer
var money_container: PanelContainer
var challenge_container: PanelContainer
var debuff_container: PanelContainer
var consumable_container: PanelContainer
var console_container: PanelContainer
var title_container: PanelContainer
var dice_area_container: PanelContainer
var chore_meter_container: PanelContainer
var scorecard_container: PanelContainer

# Layout constants
const SCREEN_WIDTH: float = 1280.0
const SCREEN_HEIGHT: float = 720.0
const MARGIN: int = 8
const SEPARATION: int = 8

# Stretch ratios (must sum consistently within each parent)
const UPPER_STRETCH: float = 40.0
const MIDDLE_STRETCH: float = 160.0 #135.0
const BOTTOM_STRETCH: float = 0.0 #25.0

const TURN_INFO_RATIO: float = 25.0
const POWER_UP_RATIO: float = 50.0
const MONEY_RATIO: float = 25.0

const CHALLENGE_RATIO: float = 14.5 #19
const DEBUFF_RATIO: float = 14.5
const CONSUMABLE_RATIO: float = 42.0
const CONSOLE_RATIO: float = 14.5
const LEFT_INFO_RATIO: float = 14.5

const TITLE_RATIO: float = 23.0
const DICE_AREA_RATIO: float = 61.0
const CHORE_METER_RATIO: float = 23.0
const CENTER_ROLL_RATIO: float = 23.0

const SCORECARD_RATIO: float = 77.0
const RIGHT_BUTTON_RATIO: float = 23.0

# Visual theme colors
const PANEL_BG: Color = Color(0.247059, 0.219608, 0.345098, 0.56)
const PANEL_BORDER: Color = Color(0.713725, 0.301961, 0.478431, 0.92)
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 16
const PANEL_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.34)
const PANEL_SHADOW_SIZE: int = 5
const TITLE_FONT_SIZE: int = 12


func _ready() -> void:
	add_to_group("game_ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	_build_ui()


func _build_ui() -> void:
	var margin := _create_margin_container()
	add_child(margin)

	var main_vbox := _create_vbox("MainVBox", 1.0)
	margin.add_child(main_vbox)

	var upper := _create_hbox("UpperSection", UPPER_STRETCH)
	main_vbox.add_child(upper)

	turn_info_container = _create_panel("TurnInfoContainer", TURN_INFO_RATIO)
	upper.add_child(turn_info_container)
	var tracker_ui := preload("res://Scenes/UI/vcr_turn_tracker_ui.tscn").instantiate()
	tracker_ui.name = "VCRTurnTrackerUI"
	tracker_ui.clip_contents = true
	tracker_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracker_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(turn_info_container, "INFO", "res://Resources/Font/BALLOON1.ttf", tracker_ui, 14, Color(0.713725, 0.301961, 0.478431, 1.0))

	power_up_container = _create_panel("PowerUpContainer", POWER_UP_RATIO)
	upper.add_child(power_up_container)
	var power_up_ui := preload("res://Scenes/UI/power_up_ui.tscn").instantiate()
	power_up_ui.name = "PowerUpUI"
	power_up_ui.clip_contents = true
	_add_glowing_title(power_up_container, "PowerUps", "res://Resources/Font/BALLOON1.ttf", power_up_ui)

	money_container = _create_panel("MoneyContainer", MONEY_RATIO)
	upper.add_child(money_container)
	var money_ui := preload("res://Scenes/UI/money_ui.tscn").instantiate()
	money_ui.name = "MoneyUI"
	money_ui.clip_contents = true
	money_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(money_container, "MONEY", "res://Resources/Font/BALLOON1.ttf", money_ui, 14, Color(0.137255, 0.411765, 0.415686, 1.0))

	var middle := _create_hbox("MiddleSection", MIDDLE_STRETCH)
	main_vbox.add_child(middle)

	# ── Left column ──
	var left_col := _create_vbox("LeftColumn", 1.0)
	middle.add_child(left_col)

	challenge_container = _create_panel("ChallengeContainer", CHALLENGE_RATIO)
	left_col.add_child(challenge_container)
	var challenge_ui := preload("res://Scenes/UI/challenge_ui.tscn").instantiate()
	challenge_ui.name = "ChallengeUI"
	challenge_ui.clip_contents = false
	_add_glowing_title(challenge_container, "Challenges", "res://Resources/Font/BALLOON1.ttf", challenge_ui)

	debuff_container = _create_panel("DebuffContainer", DEBUFF_RATIO)
	left_col.add_child(debuff_container)
	var debuff_ui := preload("res://Scenes/UI/debuff_ui.tscn").instantiate()
	debuff_ui.name = "DebuffUI"
	debuff_ui.clip_contents = false
	_add_glowing_title(debuff_container, "Debuffs", "res://Resources/Font/BALLOON1.ttf", debuff_ui)

	consumable_container = _create_panel("ConsumableContainer", CONSUMABLE_RATIO)
	left_col.add_child(consumable_container)
	var consumable_ui := preload("res://Scenes/UI/consumable_ui.tscn").instantiate()
	consumable_ui.name = "ConsumableUI"
	consumable_ui.clip_contents = true
	_add_glowing_title(consumable_container, "Consumables", "res://Resources/Font/BALLOON1.ttf", consumable_ui)

	console_container = _create_panel("ConsoleContainer", CONSOLE_RATIO)
	left_col.add_child(console_container)
	var console_ui := preload("res://Scenes/UI/gaming_console_ui.tscn").instantiate()
	console_ui.name = "GamingConsoleUI"
	console_ui.clip_contents = true
	_add_glowing_title(console_container, "Consoles", "res://Resources/Font/BALLOON1.ttf", console_ui)

	# Action buttons moved from bottom panel to left column
	var game_button_container := _create_panel("GameButtonContainer", LEFT_INFO_RATIO)
	left_col.add_child(game_button_container)
	var game_buttons := preload("res://Scenes/UI/game_button_ui.tscn").instantiate()
	game_buttons.name = "GameButtonUI"
	game_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(game_button_container, "Actions", "res://Resources/Font/BALLOON1.ttf", game_buttons)

	# ── Center column ──
	var center_col := _create_vbox("CenterColumn", 1.0)
	middle.add_child(center_col)

	title_container = _create_panel("TitleContainer", TITLE_RATIO)
	center_col.add_child(title_container)
	_add_glowing_title(title_container, "Guhtzee!", "res://Resources/Font/PumpDemiBoldPlain.otf", null, 72)

	dice_area_container = _create_panel("DiceAreaContainer", DICE_AREA_RATIO)
	center_col.add_child(dice_area_container)
	var dice_hand := preload("res://Scenes/Dice/dice_hand.tscn").instantiate()
	dice_hand.name = "DiceHand"
	dice_area_container.add_child(dice_hand)

	chore_meter_container = _create_panel("ChoreMeterContainer", CHORE_METER_RATIO)
	center_col.add_child(chore_meter_container)
	var chore_ui := preload("res://Scenes/UI/chore_ui.tscn").instantiate()
	chore_ui.name = "ChoreUI"
	chore_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chore_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(chore_meter_container, "Chore Meter", "res://Resources/Font/BALLOON1.ttf", chore_ui)

	# Prominent roll button below chore meter
	var roll_button_container := _create_panel("RollButtonContainer", CENTER_ROLL_RATIO)
	center_col.add_child(roll_button_container)
	var roll_button_ui := preload("res://Scenes/UI/roll_button_ui.tscn").instantiate()
	roll_button_ui.name = "RollButtonUI"
	roll_button_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_button_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roll_button_container.add_child(roll_button_ui)

	# ── Right column (scorecard) ──
	var right_col := _create_vbox("RightColumn", 1.0)
	middle.add_child(right_col)

	scorecard_container = _create_panel("ScorecardContainer", 1.0)
	right_col.add_child(scorecard_container)
	var scorecard := preload("res://Scenes/UI/score_card_ui.tscn").instantiate()
	scorecard.name = "ScoreCardUI"
	scorecard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorecard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorecard_container.add_child(scorecard)


func _create_margin_container() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	return margin


func _create_hbox(node_name: String, stretch: float) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = stretch
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", SEPARATION)
	return box


func _create_vbox(node_name: String, stretch: float) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = stretch
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", SEPARATION)
	return box


func _create_panel(node_name: String, stretch: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = PANEL_BORDER
	style.set_border_width_all(PANEL_BORDER_WIDTH)
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.corner_detail = 8
	style.shadow_color = PANEL_SHADOW
	style.shadow_size = PANEL_SHADOW_SIZE
	panel.add_theme_stylebox_override("panel", style)

	return panel


func _add_glowing_title(parent: PanelContainer, title_text: String, font: String = "res://Resources/Font/BALLOON1.ttf", content: Control = null, text_font_size: int = TITLE_FONT_SIZE, title_color: Color = Color(0.8, 0.4, 1.0, 1.0)) -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(vbox)

	var glow_title := preload("res://Scenes/UI/GlowingTitle.tscn").instantiate()
	glow_title.name = "GlowingTitle"
	glow_title.text = title_text
	glow_title.font_size = text_font_size
	glow_title.font_color = title_color
	glow_title.font_path = font
	glow_title.glow_intensity = 0.0
	glow_title.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glow_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(glow_title)
	
	if content:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(content)
