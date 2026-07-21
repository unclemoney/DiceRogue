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

@onready var _tfx : Node = get_node("/root/TweenFXHelper")
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

# Dedicated top-level layer hosting hover tooltips so they render above
# all other UI and are never clipped by clip_contents panels.
var _tooltip_layer: CanvasLayer

# Panels registered for hover tooltips: [{panel, tooltip, timer, hovered}]
var _hover_entries: Array[Dictionary] = []

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
const CONSUMABLE_RATIO: float = 37.8
const CONSOLE_RATIO: float = 18.7
const LEFT_INFO_RATIO: float = 14.5

const TITLE_RATIO: float = 23.0
const DICE_AREA_RATIO: float = 61.0
const CHORE_METER_RATIO: float = 23.0
const CENTER_ROLL_RATIO: float = 23.0

const SCORECARD_RATIO: float = 77.0
const RIGHT_BUTTON_RATIO: float = 23.0

# Visual theme colors
const PANEL_BG: Color = Color(0.431373, 0.317647, 0.611765, 0.26) # Dark Purple
const PANEL_BORDER: Color = Color(0.901961, 0.450980, 0.556863, 0.02) #Magenta
const PANEL_BORDER_WIDTH: int = 2
const PANEL_CORNER_RADIUS: int = 16
const PANEL_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.34)
const PANEL_SHADOW_SIZE: int = 5
const TITLE_FONT_SIZE: int = 12

# Hover tooltip tuning
const TOOLTIP_HOVER_DELAY: float = 1.0
const TOOLTIP_FONT_SIZE: int = 20
const TOOLTIP_LAYER_INDEX: int = 128
const TOOLTIP_POP_DURATION: float = 0.35
const TOOLTIP_POP_OVERSHOOT: float = 0.2

# Verbose terminal logging for hover tooltip diagnostics
const DEBUG_TOOLTIPS: bool = true

# New color pallete
# 
const COLOR_ORANGE: Color = Color(1.0, 0.729412, 0.490196, 1.0) # ffba7d
const COLOR_MAGENTA: Color = Color(0.901961, 0.450980, 0.556863, 1.0) # e6738e
const COLOR_PURPLE: Color = Color(0.431373, 0.317647, 0.611765, 1.0) # 6e519c
const COLOR_BLUE: Color = Color(0.403922, 0.572549, 0.670588, 1.0) # 6792ab
const COLOR_TEAL: Color = Color(0.549020, 0.729412, 0.662745, 1.0) # 8cbaa9



func _ready() -> void:
	add_to_group("game_ui")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	size = Vector2(SCREEN_WIDTH, SCREEN_HEIGHT)
	_build_ui()


func _build_ui() -> void:
	var margin : MarginContainer = _create_margin_container()
	add_child(margin)

	var main_vbox : VBoxContainer = _create_vbox("MainVBox", 1.0)
	margin.add_child(main_vbox)

	var upper : HBoxContainer = _create_hbox("UpperSection", UPPER_STRETCH)
	main_vbox.add_child(upper)

	turn_info_container = _create_panel("TurnInfoContainer", TURN_INFO_RATIO)
	upper.add_child(turn_info_container)
	var tracker_ui : Node = preload("res://Scenes/UI/vcr_turn_tracker_ui.tscn").instantiate()
	tracker_ui.name = "VCRTurnTrackerUI"
	tracker_ui.clip_contents = true
	tracker_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tracker_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(turn_info_container, "INFO", "res://Resources/Font/BALLOON1.ttf", tracker_ui, 14, Color(0.713725, 0.301961, 0.478431, 1.0))
	_add_container_hover_title(turn_info_container, "INFO")

	power_up_container = _create_panel("PowerUpContainer", POWER_UP_RATIO)
	upper.add_child(power_up_container)
	var power_up_ui : Node = preload("res://Scenes/UI/power_up_ui.tscn").instantiate()
	power_up_ui.name = "PowerUpUI"
	power_up_ui.clip_contents = true
	_add_glowing_title(power_up_container, "PowerUps", "res://Resources/Font/BALLOON1.ttf", power_up_ui)
	_add_container_hover_title(power_up_container, "PowerUps")

	money_container = _create_panel("MoneyContainer", MONEY_RATIO)
	upper.add_child(money_container)
	var money_ui := preload("res://Scenes/UI/money_ui.tscn").instantiate()
	money_ui.name = "MoneyUI"
	money_ui.clip_contents = true
	money_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	money_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(money_container, "MONEY", "res://Resources/Font/BALLOON1.ttf", money_ui, 14, Color(0.137255, 0.411765, 0.415686, 1.0))
	_add_container_hover_title(money_container, "MONEY")

	var middle : HBoxContainer = _create_hbox("MiddleSection", MIDDLE_STRETCH)
	main_vbox.add_child(middle)

	# ── Left column ──
	var left_col : VBoxContainer = _create_vbox("LeftColumn", 1.0)
	middle.add_child(left_col)

	#Chore Meter UI
	chore_meter_container = _create_panel("ChoreMeterContainer", CHORE_METER_RATIO)
	left_col.add_child(chore_meter_container)
	var chore_ui := preload("res://Scenes/UI/chore_ui.tscn").instantiate()
	chore_ui.name = "ChoreUI"
	chore_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chore_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(chore_meter_container, "Chore Meter", "res://Resources/Font/BALLOON1.ttf", chore_ui)
	_add_container_hover_title(chore_meter_container, "Chore Meter")

	debuff_container = _create_panel("DebuffContainer", DEBUFF_RATIO)
	left_col.add_child(debuff_container)
	var debuff_ui : Node = preload("res://Scenes/UI/debuff_ui.tscn").instantiate()
	debuff_ui.name = "DebuffUI"
	debuff_ui.clip_contents = false
	_add_glowing_title(debuff_container, "Debuffs", "res://Resources/Font/BALLOON1.ttf", debuff_ui)
	_add_container_hover_title(debuff_container, "Debuffs")

	consumable_container = _create_panel("ConsumableContainer", CONSUMABLE_RATIO)
	left_col.add_child(consumable_container)
	var consumable_ui : Node = preload("res://Scenes/UI/consumable_ui.tscn").instantiate()
	consumable_ui.name = "ConsumableUI"
	consumable_ui.clip_contents = true
	_add_glowing_title(consumable_container, "Consumables", "res://Resources/Font/BALLOON1.ttf", consumable_ui)
	_add_container_hover_title(consumable_container, "Consumables")

	console_container = _create_panel("ConsoleContainer", CONSOLE_RATIO)
	left_col.add_child(console_container)
	var console_ui : Node = preload("res://Scenes/UI/gaming_console_ui.tscn").instantiate()
	console_ui.name = "GamingConsoleUI"
	console_ui.clip_contents = true
	_add_glowing_title(console_container, "Consoles", "res://Resources/Font/BALLOON1.ttf", console_ui)
	_add_container_hover_title(console_container, "Consoles")

	# Action buttons moved from bottom panel to left column
	var game_button_container := _create_panel("GameButtonContainer", LEFT_INFO_RATIO)
	left_col.add_child(game_button_container)
	var game_buttons : Node = preload("res://Scenes/UI/game_button_ui.tscn").instantiate()
	game_buttons.name = "GameButtonUI"
	game_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game_buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_add_glowing_title(game_button_container, "Actions", "res://Resources/Font/BALLOON1.ttf", game_buttons)
	_add_container_hover_title(game_button_container, "Actions")

	# ── Center column ──
	var center_col := _create_vbox("CenterColumn", 1.0)
	middle.add_child(center_col)

	title_container = _create_panel("TitleContainer", TITLE_RATIO)
	center_col.add_child(title_container)
	var interactive_game_title_scene = load("res://Scenes/UI/InteractiveGameTitle.tscn") as PackedScene
	if interactive_game_title_scene:
		var interactive_game_title = interactive_game_title_scene.instantiate()
		interactive_game_title.name = "InteractiveGameTitle"
		interactive_game_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		interactive_game_title.size_flags_vertical = Control.SIZE_EXPAND_FILL
		title_container.add_child(interactive_game_title)
	else:
		push_error("[GameUI] Failed to load InteractiveGameTitle scene")
	#_add_container_hover_title(title_container, "Guhtzee!")

	dice_area_container = _create_panel("DiceAreaContainer", DICE_AREA_RATIO)
	center_col.add_child(dice_area_container)
	var dice_hand := preload("res://Scenes/Dice/dice_hand.tscn").instantiate()
	dice_hand.name = "DiceHand"
	dice_area_container.add_child(dice_hand)
	#_add_container_hover_title(dice_area_container, "Dice Area")

	#Challenge UI
	challenge_container = _create_panel("ChallengeContainer", CHALLENGE_RATIO)
	center_col.add_child(challenge_container)
	var challenge_ui : Node = preload("res://Scenes/UI/challenge_ui.tscn").instantiate()
	challenge_ui.name = "ChallengeUI"
	challenge_ui.clip_contents = true
	_add_glowing_title(challenge_container, "Challenges", "res://Resources/Font/BALLOON1.ttf", challenge_ui)
	_add_container_hover_title(challenge_container, "Challenges")

	# Prominent roll button below challenges
	var roll_button_container := _create_panel("RollButtonContainer", CENTER_ROLL_RATIO)
	center_col.add_child(roll_button_container)
	var roll_button_ui := preload("res://Scenes/UI/roll_button_ui.tscn").instantiate()
	roll_button_ui.name = "RollButtonUI"
	roll_button_ui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll_button_ui.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roll_button_container.add_child(roll_button_ui)
	_add_container_hover_title(roll_button_container, "Roll Button")

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
	_add_container_hover_title(scorecard_container, "Scorecard")

	# Wire GameButtonUI to the ScoreCard (dynamic scenes built in code)
	if game_buttons:
		var path_to_scorecard := game_buttons.get_path_to(scorecard)
		game_buttons.score_card_ui_path = path_to_scorecard


## _ensure_tooltip_layer()
##
## Lazily creates the dedicated CanvasLayer that hosts hover tooltips.
## layer = 128 keeps tooltips above every other UI layer.
func _ensure_tooltip_layer() -> void:
	if _tooltip_layer and is_instance_valid(_tooltip_layer):
		return
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.name = "TooltipLayer"
	_tooltip_layer.layer = TOOLTIP_LAYER_INDEX
	add_child(_tooltip_layer)


## _add_container_hover_title(panel, title_text)
##
## Adds a hover tooltip to a panel that displays the container's title.
## The tooltip lives on a dedicated top-level CanvasLayer so it is always
## visible on-screen, above all other layers, and never clipped by panels
## with clip_contents. It appears after a short hover delay and pops in
## with a bubble-grow bounce via TweenFX.
## Respects the GameSettings.container_title_tooltips_enabled toggle.
func _add_container_hover_title(panel: PanelContainer, title_text: String) -> void:
	if not panel:
		return
	_ensure_tooltip_layer()

	var tooltip := PanelContainer.new()
	tooltip.name = "HoverTitleTooltip"
	tooltip.z_index = 4096
	tooltip.top_level = true
	tooltip.visible = false
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# High-contrast style: dark near-opaque background, bright accent border,
	# rounded corners, and generous padding for a slightly larger panel.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.04, 0.10, 0.97)
	style.border_color = COLOR_MAGENTA
	style.set_border_width_all(3)
	style.border_blend = true
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 4
	tooltip.add_theme_stylebox_override("panel", style)
	_tooltip_layer.add_child(tooltip)

	var label := Label.new()
	label.name = "TooltipLabel"
	label.text = title_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	label.add_theme_font_size_override("font_size", TOOLTIP_FONT_SIZE)
	label.add_theme_color_override("font_color", Color(1, 0.98, 0.9, 1))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	tooltip.add_child(label)

	# Delay from mouse-enter before the tooltip is shown; cancelled on exit.
	var delay_timer := Timer.new()
	delay_timer.name = "TooltipDelayTimer"
	delay_timer.one_shot = true
	delay_timer.wait_time = TOOLTIP_HOVER_DELAY
	panel.add_child(delay_timer)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hover_entries.append({
		"panel": panel,
		"tooltip": tooltip,
		"timer": delay_timer,
		"hovered": false,
	})
	delay_timer.timeout.connect(func():
		if not GameSettings.container_title_tooltips_enabled:
			return
		# Size to content, then place clamped on-screen above the panel.
		tooltip.size = tooltip.get_combined_minimum_size()
		tooltip.visible = true
		_tfx.place_tooltip(tooltip, panel.get_global_rect(), SIDE_TOP, false)
		tooltip.pivot_offset = tooltip.size / 2.0
		TweenFX.overshoot_pop_in(tooltip, TOOLTIP_POP_DURATION, TOOLTIP_POP_OVERSHOOT)
		if DEBUG_TOOLTIPS:
			var vp := tooltip.get_viewport().get_visible_rect()
			print("[GameUI:Tooltip] SHOW '%s' at %s size %s (viewport %s, inside=%s, layer=%d, z=%d)" % [
				panel.name, tooltip.global_position, tooltip.size, vp.size,
				vp.has_point(tooltip.global_position), TOOLTIP_LAYER_INDEX, tooltip.z_index])
	)


## _process(delta)
##
## Polls the hovered GUI control each frame to drive hover tooltips.
## Signal-based mouse_entered/mouse_exited is unreliable here because the
## child UIs inside each panel use MOUSE_FILTER_STOP and swallow hover.
func _process(_delta: float) -> void:
	if _hover_entries.is_empty() or not is_inside_tree():
		return
	var hovered_ctrl := get_viewport().gui_get_hovered_control()
	for entry in _hover_entries:
		var panel: PanelContainer = entry["panel"]
		if not is_instance_valid(panel):
			continue
		var is_hovered: bool = hovered_ctrl != null \
			and (hovered_ctrl == panel or panel.is_ancestor_of(hovered_ctrl)) \
			and panel.is_visible_in_tree()
		if is_hovered and not entry["hovered"]:
			entry["hovered"] = true
			_on_tooltip_hover_start(entry)
		elif not is_hovered and entry["hovered"]:
			entry["hovered"] = false
			_on_tooltip_hover_end(entry)


## Starts the hover delay timer for a panel (unless tooltips are disabled).
func _on_tooltip_hover_start(entry: Dictionary) -> void:
	var panel: PanelContainer = entry["panel"]
	if DEBUG_TOOLTIPS:
		print("[GameUI:Tooltip] hover START '%s' (setting=%s)" % [
			panel.name, GameSettings.container_title_tooltips_enabled])
	if not GameSettings.container_title_tooltips_enabled:
		return
	(entry["timer"] as Timer).start()


## Cancels the pending tooltip and hides it when the hover ends.
func _on_tooltip_hover_end(entry: Dictionary) -> void:
	if DEBUG_TOOLTIPS:
		print("[GameUI:Tooltip] hover END '%s'" % (entry["panel"] as PanelContainer).name)
	(entry["timer"] as Timer).stop()
	(entry["tooltip"] as PanelContainer).visible = false

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
	glow_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	#vbox.add_child(glow_title)
	
	if content:
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(content)
		# Forward input from title area to content so the whole panel is interactive
		vbox.mouse_filter = Control.MOUSE_FILTER_STOP
		vbox.gui_input.connect(func(event: InputEvent):
			if content.has_method("_gui_input"):
				content._gui_input.call(event)
		)
