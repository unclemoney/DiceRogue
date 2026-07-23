extends Control
class_name EndOfRoundStatsPanel

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")

## EndOfRoundStatsPanel
##
## Displays end-of-round statistics with animated bonus reveals.
## Shows after clicking Shop button but before the Shop opens.
## Awards bonuses for challenge completion, chores completed,
## empty scorecard categories ($5 each), and points above challenge target ($1 per point).

signal continue_to_shop_pressed
signal panel_closed

# Constants for bonus calculations
const EMPTY_CATEGORY_BONUS: int = 5
const POINTS_ABOVE_TARGET_BONUS: int = 1

# Animation settings
const COUNTER_ANIMATION_DURATION: float = 1.5
const REVEAL_DELAY: float = 0.3
const CELEBRATION_THRESHOLD: int = 100  # Bonus amount to trigger celebration

const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const PANEL_CORNER_RADIUS := 20.0

# UI References (will be set up in _ready or via scene)
var overlay: ColorRect
var panel_container: PanelContainer
var backdrop_fx_rect: ColorRect
var title_label: Label
var round_label: Label
var challenge_score_label: Label
var final_score_label: Label
var challenge_reward_label: Label
var challenge_reward_value_label: Label
var chore_reward_label: Label
var chore_reward_value_label: Label
var empty_categories_label: Label
var empty_categories_bonus_label: Label
var score_above_label: Label
var score_above_bonus_label: Label
var power_up_bonus_label: Label
var power_up_bonus_value_label: Label
var total_bonus_label: Label
var continue_button = null

# Round data
var round_number: int = 0
var challenge_target_score: int = 0
var final_score: int = 0
var empty_category_count: int = 0
var points_above_target: int = 0

# Challenge and chore rewards
var challenge_reward_amount: int = 0
var chores_completed_count: int = 0
var chore_reward_amount: int = 0

# Calculated bonuses
var empty_categories_bonus: int = 0
var score_above_bonus: int = 0
var power_up_bonus_amount: int = 0
var total_bonus: int = 0

# Animation state
var _animation_tween: Tween
var _is_animating: bool = false

func _ready() -> void:
	# Hide by default
	visible = false
	
	# Build UI if not already set up via scene
	if not overlay:
		_build_ui()
	
	# Connect button (check if not already connected)
	if continue_button and not continue_button.pressed.is_connected(_on_continue_button_pressed):
		continue_button.pressed.connect(_on_continue_button_pressed)


## _build_ui()
##
## Programmatically builds the panel UI structure.
## Uses overlay pattern similar to GameOver popup.
func _build_ui() -> void:
	# Create semi-transparent overlay
	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	
	# Create centered panel container
	panel_container = PanelContainer.new()
	panel_container.name = "PanelContainer"
	panel_container.custom_minimum_size = Vector2(500, 450)
	# Center the panel using anchors preset
	panel_container.set_anchors_preset(Control.PRESET_CENTER)
	panel_container.offset_left = -250  # Half of width
	panel_container.offset_top = -225   # Half of height
	panel_container.offset_right = 250  # Half of width
	panel_container.offset_bottom = 225 # Half of height
	panel_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel_container.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	# Load and apply the powerup hover theme
	var theme_path = "res://Resources/UI/powerup_hover_theme.tres"
	var panel_theme = load(theme_path) as Theme
	if panel_theme:
		panel_container.theme = panel_theme

	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.247059, 0.219608, 0.345098, 0.98)
	panel_style.border_color = Color(0.713725, 0.301961, 0.478431, 1.0)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(20)
	panel_style.corner_detail = 8
	panel_style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	panel_style.shadow_size = 8
	panel_container.add_theme_stylebox_override("panel", panel_style)
	
	overlay.add_child(panel_container)
	
	# Shader backdrop behind all panel content (gradient, vignette, grain, sheen)
	backdrop_fx_rect = _create_backdrop_fx_rect()
	panel_container.resized.connect(_update_backdrop_fx_size)
	
	# Main vertical container
	var main_vbox = VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.add_theme_constant_override("separation", 15)
	panel_container.add_child(main_vbox)
	
	# Add margin container for padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	main_vbox.add_child(margin)
	
	var content_vbox = VBoxContainer.new()
	content_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(content_vbox)
	
	# Title
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "ROUND COMPLETE!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(0.968627, 0.941176, 1.0, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	title_label.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(title_label)
	
	# Separator
	var sep1 = HSeparator.new()
	content_vbox.add_child(sep1)
	
	# Round number
	round_label = Label.new()
	round_label.name = "RoundLabel"
	round_label.text = "Round 1"
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	round_label.add_theme_font_size_override("font_size", 24)
	round_label.add_theme_color_override("font_color", Color(0.780392, 0.733333, 0.866667, 1.0))
	round_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	round_label.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(round_label)
	
	# Challenge and final score section
	var scores_hbox = HBoxContainer.new()
	scores_hbox.add_theme_constant_override("separation", 40)
	scores_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	content_vbox.add_child(scores_hbox)
	
	# Challenge target score
	var challenge_vbox = VBoxContainer.new()
	challenge_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scores_hbox.add_child(challenge_vbox)
	
	var challenge_title = Label.new()
	challenge_title.text = "Challenge Target"
	challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_title.add_theme_font_size_override("font_size", 14)
	challenge_vbox.add_child(challenge_title)
	
	challenge_score_label = Label.new()
	challenge_score_label.name = "ChallengeScoreLabel"
	challenge_score_label.text = "100"
	challenge_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_score_label.add_theme_font_size_override("font_size", 28)
	challenge_vbox.add_child(challenge_score_label)
	
	# Final score
	var final_vbox = VBoxContainer.new()
	final_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	scores_hbox.add_child(final_vbox)
	
	var final_title = Label.new()
	final_title.text = "Your Score"
	final_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_title.add_theme_font_size_override("font_size", 14)
	final_vbox.add_child(final_title)
	
	final_score_label = Label.new()
	final_score_label.name = "FinalScoreLabel"
	final_score_label.text = "130"
	final_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_score_label.add_theme_font_size_override("font_size", 28)
	final_score_label.add_theme_color_override("font_color", Color(0.47451, 0.886275, 0.890196, 1.0))
	final_score_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	final_score_label.add_theme_constant_override("outline_size", 1)
	final_vbox.add_child(final_score_label)
	
	# Separator
	var sep2 = HSeparator.new()
	content_vbox.add_child(sep2)
	
	# Bonuses section title
	var bonus_title = Label.new()
	bonus_title.text = "ROUND BONUSES"
	bonus_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bonus_title.add_theme_font_size_override("font_size", 20)
	bonus_title.add_theme_color_override("font_color", Color(0.780392, 0.733333, 0.866667, 1.0))
	bonus_title.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	bonus_title.add_theme_constant_override("outline_size", 1)
	content_vbox.add_child(bonus_title)
	
	# Challenge reward row
	var challenge_hbox = HBoxContainer.new()
	challenge_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(challenge_hbox)
	
	challenge_reward_label = Label.new()
	challenge_reward_label.name = "ChallengeRewardLabel"
	challenge_reward_label.text = "Challenge Reward:"
	challenge_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	challenge_reward_label.add_theme_font_size_override("font_size", 18)
	challenge_hbox.add_child(challenge_reward_label)
	
	challenge_reward_value_label = Label.new()
	challenge_reward_value_label.name = "ChallengeRewardValueLabel"
	challenge_reward_value_label.text = "$0"
	challenge_reward_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	challenge_reward_value_label.add_theme_font_size_override("font_size", 18)
	challenge_reward_value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	challenge_hbox.add_child(challenge_reward_value_label)
	
	# Chore reward row
	var chore_hbox = HBoxContainer.new()
	chore_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(chore_hbox)
	
	chore_reward_label = Label.new()
	chore_reward_label.name = "ChoreRewardLabel"
	chore_reward_label.text = "Chores Completed (0 × $50):"
	chore_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chore_reward_label.add_theme_font_size_override("font_size", 18)
	chore_hbox.add_child(chore_reward_label)
	
	chore_reward_value_label = Label.new()
	chore_reward_value_label.name = "ChoreRewardValueLabel"
	chore_reward_value_label.text = "$0"
	chore_reward_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chore_reward_value_label.add_theme_font_size_override("font_size", 18)
	chore_reward_value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	chore_hbox.add_child(chore_reward_value_label)
	
	# Empty categories bonus row
	var empty_hbox = HBoxContainer.new()
	empty_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(empty_hbox)
	
	empty_categories_label = Label.new()
	empty_categories_label.name = "EmptyCategoriesLabel"
	empty_categories_label.text = "Empty Categories (3 × $25):"
	empty_categories_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty_categories_label.add_theme_font_size_override("font_size", 18)
	empty_hbox.add_child(empty_categories_label)
	
	empty_categories_bonus_label = Label.new()
	empty_categories_bonus_label.name = "EmptyCategoriesBonusLabel"
	empty_categories_bonus_label.text = "$0"
	empty_categories_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	empty_categories_bonus_label.add_theme_font_size_override("font_size", 18)
	empty_categories_bonus_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	empty_hbox.add_child(empty_categories_bonus_label)
	
	# Points above target bonus row
	var score_hbox = HBoxContainer.new()
	score_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(score_hbox)
	
	score_above_label = Label.new()
	score_above_label.name = "ScoreAboveLabel"
	score_above_label.text = "Points Above Target (30 × $1):"
	score_above_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	score_above_label.add_theme_font_size_override("font_size", 18)
	score_hbox.add_child(score_above_label)
	
	score_above_bonus_label = Label.new()
	score_above_bonus_label.name = "ScoreAboveBonusLabel"
	score_above_bonus_label.text = "$0"
	score_above_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_above_bonus_label.add_theme_font_size_override("font_size", 18)
	score_above_bonus_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	score_hbox.add_child(score_above_bonus_label)

	# PowerUp bonus row
	var power_up_hbox = HBoxContainer.new()
	power_up_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(power_up_hbox)

	power_up_bonus_label = Label.new()
	power_up_bonus_label.name = "PowerUpBonusLabel"
	power_up_bonus_label.text = "Bonuses from PowerUps:"
	power_up_bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_up_bonus_label.add_theme_font_size_override("font_size", 18)
	power_up_hbox.add_child(power_up_bonus_label)

	power_up_bonus_value_label = Label.new()
	power_up_bonus_value_label.name = "PowerUpBonusValueLabel"
	power_up_bonus_value_label.text = "$0"
	power_up_bonus_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_up_bonus_value_label.add_theme_font_size_override("font_size", 18)
	power_up_bonus_value_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	power_up_hbox.add_child(power_up_bonus_value_label)
	
	# Separator
	var sep3 = HSeparator.new()
	content_vbox.add_child(sep3)
	
	# Total bonus row
	var total_hbox = HBoxContainer.new()
	total_hbox.add_theme_constant_override("separation", 10)
	content_vbox.add_child(total_hbox)
	
	var total_text_label = Label.new()
	total_text_label.text = "TOTAL BONUS:"
	total_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_text_label.add_theme_font_size_override("font_size", 22)
	total_hbox.add_child(total_text_label)
	
	total_bonus_label = Label.new()
	total_bonus_label.name = "TotalBonusLabel"
	total_bonus_label.text = "$0"
	total_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_bonus_label.add_theme_font_size_override("font_size", 26)
	total_bonus_label.add_theme_color_override("font_color", Color(0.47451, 0.886275, 0.890196, 1.0))
	total_bonus_label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	total_bonus_label.add_theme_constant_override("outline_size", 1)
	total_hbox.add_child(total_bonus_label)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content_vbox.add_child(spacer)
	
	# Continue button
	continue_button = GlassActionButtonClass.new()
	continue_button.name = "ContinueButton"
	continue_button.configure(
		"Head to Shop",
		Vector2(280, 50),
		{
			"base_color": Color(0.137255, 0.411765, 0.415686, 0.92),
			"mid_color": Color(0.2, 0.56, 0.56, 0.96),
			"accent_color": Color(0.47451, 0.886275, 0.890196, 1.0),
			"glow_color": Color(0.6, 0.94, 0.96, 1.0),
			"rim_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_outline_color": Color(0.129412, 0.121569, 0.2, 1.0),
			"outline_size": 1
		},
		20
	)
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content_vbox.add_child(continue_button)
	
	# Connect button signal
	continue_button.pressed.connect(_on_continue_button_pressed)


## show_stats(data: Dictionary)
##
## Displays the panel with round statistics and animates bonus reveals.
## @param data: Dictionary containing:
##   - round_number: int
##   - challenge_target: int
##   - final_score: int
## set_final_round(is_final: bool)
##
## Updates the continue button text based on whether this is the final round.
## Call before show_stats() to ensure the correct label is visible.
func set_final_round(is_final: bool) -> void:
	if continue_button:
		continue_button.set_button_text("Head to Next Mall Zone" if is_final else "Head to Shop")

##   - empty_categories: int
##   - scorecard: Scorecard reference (for calculating empty categories)
##   - challenge_reward: int (reward from completing the challenge)
##   - chores_completed: int (number of chores completed this round)
func show_stats(data: Dictionary) -> void:
	print("[EndOfRoundStatsPanel] Showing stats with data:", data)
	
	# Store data
	round_number = data.get("round_number", 1)
	challenge_target_score = data.get("challenge_target", 0)
	final_score = data.get("final_score", 0)
	
	# Get challenge reward and chores completed
	challenge_reward_amount = data.get("challenge_reward", 0)
	chores_completed_count = data.get("chores_completed", 0)
	chore_reward_amount = data.get("chore_reward_total", 0)
	
	# Read precomputed bonus data, falling back to local calculation when necessary.
	if data.has("empty_categories"):
		empty_category_count = data.get("empty_categories", 0)
	elif data.has("scorecard"):
		empty_category_count = _count_empty_categories(data.scorecard)
	else:
		empty_category_count = 0

	empty_categories_bonus = data.get("empty_categories_bonus", empty_category_count * EMPTY_CATEGORY_BONUS)
	points_above_target = data.get("points_above_target", max(0, final_score - challenge_target_score))
	score_above_bonus = data.get("score_above_bonus", points_above_target * POINTS_ABOVE_TARGET_BONUS)
	power_up_bonus_amount = data.get("power_up_bonus", 0)
	
	# Total includes challenge reward, chore reward, empty categories, score above target, and PowerUp bonuses.
	total_bonus = challenge_reward_amount + chore_reward_amount + empty_categories_bonus + score_above_bonus + power_up_bonus_amount
	
	print("[EndOfRoundStatsPanel] Challenge reward:", challenge_reward_amount)
	print("[EndOfRoundStatsPanel] Chores completed:", chores_completed_count, "Reward:", chore_reward_amount)
	print("[EndOfRoundStatsPanel] Empty categories:", empty_category_count, "Bonus:", empty_categories_bonus)
	print("[EndOfRoundStatsPanel] Points above target:", points_above_target, "Bonus:", score_above_bonus)
	print("[EndOfRoundStatsPanel] PowerUp bonuses:", power_up_bonus_amount)
	print("[EndOfRoundStatsPanel] Total bonus:", total_bonus)
	
	# Update static labels
	round_label.text = "Round %s" % NumberFormatter.format_int(round_number)
	challenge_score_label.text = NumberFormatter.format_score(challenge_target_score)
	final_score_label.text = NumberFormatter.format_score(final_score)
	challenge_reward_label.text = "Challenge Reward:"
	chore_reward_label.text = "Chore Rewards (%s chores):" % NumberFormatter.format_int(chores_completed_count)
	empty_categories_label.text = "Empty Categories (%s × $%s):" % [NumberFormatter.format_int(empty_category_count), NumberFormatter.format_int(EMPTY_CATEGORY_BONUS)]
	score_above_label.text = "Points Above Target (%s pts, max $100):" % NumberFormatter.format_int(points_above_target)
	power_up_bonus_label.text = "Bonuses from PowerUps:"
	
	# Reset bonus labels for animation
	challenge_reward_value_label.text = "$0"
	chore_reward_value_label.text = "$0"
	empty_categories_bonus_label.text = "$0"
	score_above_bonus_label.text = "$0"
	power_up_bonus_value_label.text = "$0"
	total_bonus_label.text = "$0"
	
	# Position and size this control to fill the viewport
	var viewport = get_viewport()
	if viewport:
		var viewport_rect = viewport.get_visible_rect()
		global_position = Vector2.ZERO
		size = viewport_rect.size
		# Set z_index high to ensure it's on top
		z_index = 100
	
	# Show panel with entrance animation
	visible = true
	_animate_entrance()
	
	# Start bonus animation sequence after entrance
	await get_tree().create_timer(0.5).timeout
	_animate_bonuses()


## _count_empty_categories(scorecard: Scorecard) -> int
##
## Counts the number of unscored (null) categories in the scorecard.
func _count_empty_categories(scorecard) -> int:
	var count: int = 0
	
	# Count upper section
	if scorecard.upper_scores:
		for category in scorecard.upper_scores.keys():
			if scorecard.upper_scores[category] == null:
				count += 1
	
	# Count lower section
	if scorecard.lower_scores:
		for category in scorecard.lower_scores.keys():
			if scorecard.lower_scores[category] == null:
				count += 1
	
	return count


## _animate_entrance()
##
## Animates the panel appearing with a scale and fade effect.
func _animate_entrance() -> void:
	if _animation_tween:
		_animation_tween.kill()
	
	# Start small and transparent
	panel_container.scale = Vector2(0.5, 0.5)
	panel_container.modulate.a = 0.0
	overlay.modulate.a = 0.0
	
	# Play swoosh sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_panel_swoosh()
	
	_animation_tween = create_tween()
	_animation_tween.set_parallel(true)
	
	# Fade in overlay
	_animation_tween.tween_property(overlay, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Fade in panel
	_animation_tween.tween_property(panel_container, "modulate:a", 1.0, 0.3)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	# Scale up panel with bounce
	_animation_tween.tween_property(panel_container, "scale", Vector2(1.0, 1.0), 0.4)\
		.set_trans(Tween.TRANS_BACK)\
		.set_ease(Tween.EASE_OUT)


## _animate_bonuses()
##
## Animates the bonus counters incrementing from 0 to final values.
## Order: Challenge reward -> Chore reward -> Empty categories -> Score above -> Total
func _animate_bonuses() -> void:
	_is_animating = true
	
	# Animate challenge reward (with zero-value handling)
	await _animate_counter_with_zero_effect(challenge_reward_value_label, challenge_reward_amount, COUNTER_ANIMATION_DURATION * 0.6)
	if not _is_animating:
		return
	await get_tree().create_timer(REVEAL_DELAY).timeout
	if not _is_animating:
		return
	
	# Animate chore reward (with zero-value handling)
	await _animate_counter_with_zero_effect(chore_reward_value_label, chore_reward_amount, COUNTER_ANIMATION_DURATION * 0.6)
	if not _is_animating:
		return
	await get_tree().create_timer(REVEAL_DELAY).timeout
	if not _is_animating:
		return
	
	# Animate empty categories bonus (with zero-value handling)
	await _animate_counter_with_zero_effect(empty_categories_bonus_label, empty_categories_bonus, COUNTER_ANIMATION_DURATION * 0.6)
	if not _is_animating:
		return
	await get_tree().create_timer(REVEAL_DELAY).timeout
	if not _is_animating:
		return
	
	# Animate score above bonus (with zero-value handling)
	await _animate_counter_with_zero_effect(score_above_bonus_label, score_above_bonus, COUNTER_ANIMATION_DURATION * 0.6)
	if not _is_animating:
		return
	await get_tree().create_timer(REVEAL_DELAY).timeout
	if not _is_animating:
		return
	
	# Animate PowerUp bonuses (with zero-value handling)
	await _animate_counter_with_zero_effect(power_up_bonus_value_label, power_up_bonus_amount, COUNTER_ANIMATION_DURATION * 0.6)
	if not _is_animating:
		return
	await get_tree().create_timer(REVEAL_DELAY).timeout
	if not _is_animating:
		return

	# Animate total with longer duration and celebration
	await _animate_counter(total_bonus_label, total_bonus, COUNTER_ANIMATION_DURATION)
	if not _is_animating:
		return
	
	# Trigger celebration if bonus is high enough
	if total_bonus >= CELEBRATION_THRESHOLD:
		_play_celebration_effect()
	
	_is_animating = false


## _animate_counter(label: Label, target_value: int, duration: float)
##
## Animates a label counting up from 0 to the target value.
## Plays money sound via AudioManager for non-zero values.
func _animate_counter(label: Label, target_value: int, duration: float) -> void:
	if target_value == 0:
		label.text = "$0"
		return
	
	# Play money sound for non-zero values via AudioManager
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_money_sound(target_value)
	
	var tween = create_tween()
	var current_value = {"value": 0}
	
	# Highlight effect during counting
	var original_color = label.get_theme_color("font_color")
	var highlight_color = Color(1.0, 1.0, 0.5)
	label.add_theme_color_override("font_color", highlight_color)
	
	# Scale pulse
	label.pivot_offset = label.size / 2.0
	tween.tween_property(label, "scale", Vector2(1.2, 1.2), duration * 0.1)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_OUT)
	
	tween.parallel().tween_method(
		func(val: float):
			current_value.value = int(val)
			label.text = "$" + NumberFormatter.format_int(current_value.value),
		0.0,
		float(target_value),
		duration
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	# Settle animation
	var settle_tween = create_tween()
	settle_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.15)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
	
	# Restore original color
	label.add_theme_color_override("font_color", original_color)
	
	await settle_tween.finished


## _animate_counter_with_zero_effect(label: Label, target_value: int, duration: float)
##
## Animates a label counting up from 0 to the target value.
## If target is 0, shows red "$0" with a bounce/shake animation.
## Plays money sound via AudioManager for non-zero values.
func _animate_counter_with_zero_effect(label: Label, target_value: int, duration: float) -> void:
	# Play money sound for non-zero values via AudioManager
	if target_value > 0:
		var audio_mgr = get_node_or_null("/root/AudioManager")
		if audio_mgr:
			audio_mgr.play_money_sound(target_value)
	
	if target_value == 0:
		# Set text red and play bounce animation for zero values
		label.text = "$0"
		label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))  # Red color
		
		# Bounce/shake animation for zero
		label.pivot_offset = label.size / 2.0
		var shake_tween = create_tween()
		
		# Quick shake left-right
		shake_tween.tween_property(label, "position:x", label.position.x - 5, 0.05)
		shake_tween.tween_property(label, "position:x", label.position.x + 5, 0.05)
		shake_tween.tween_property(label, "position:x", label.position.x - 3, 0.05)
		shake_tween.tween_property(label, "position:x", label.position.x + 3, 0.05)
		shake_tween.tween_property(label, "position:x", label.position.x, 0.05)
		
		# Scale bounce
		shake_tween.parallel().tween_property(label, "scale", Vector2(1.3, 0.8), 0.1)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		shake_tween.tween_property(label, "scale", Vector2(0.9, 1.2), 0.1)\
			.set_trans(Tween.TRANS_QUAD)\
			.set_ease(Tween.EASE_OUT)
		shake_tween.tween_property(label, "scale", Vector2(1.0, 1.0), 0.1)\
			.set_trans(Tween.TRANS_BOUNCE)\
			.set_ease(Tween.EASE_OUT)
		
		await shake_tween.finished
		return
	
	# For non-zero values, use normal animation
	await _animate_counter(label, target_value, duration)


## _play_celebration_effect()
##
## Plays a visual celebration effect for high bonuses.
func _play_celebration_effect() -> void:
	print("[EndOfRoundStatsPanel] Playing celebration effect!")
	
	# Pulse the total bonus label
	var celebrate_tween = create_tween()
	celebrate_tween.set_loops(3)
	
	var glow_color = Color(0.5, 1.0, 0.5)
	var normal_color = Color(0.4, 1.0, 0.4)
	
	celebrate_tween.tween_property(total_bonus_label, "modulate", glow_color, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)
	celebrate_tween.tween_property(total_bonus_label, "modulate", normal_color, 0.15)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN_OUT)


## _on_continue_button_pressed()
##
## Handler for the continue button. Hides panel and emits signal.
func _on_continue_button_pressed() -> void:
	print("[EndOfRoundStatsPanel] Continue button pressed")
	_hide_panel()


## _hide_panel()
##
## Animates the panel hiding and emits signals.
func _hide_panel() -> void:
	# Stop any ongoing bonus animations and their sounds
	_is_animating = false
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.money_player:
		audio_mgr.money_player.stop()
	
	if _animation_tween:
		_animation_tween.kill()
	
	_animation_tween = create_tween()
	_animation_tween.set_parallel(true)
	
	# Fade out
	_animation_tween.tween_property(overlay, "modulate:a", 0.0, 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	_animation_tween.tween_property(panel_container, "scale", Vector2(0.8, 0.8), 0.2)\
		.set_trans(Tween.TRANS_QUAD)\
		.set_ease(Tween.EASE_IN)
	
	await _animation_tween.finished
	
	visible = false
	continue_to_shop_pressed.emit()
	panel_closed.emit()


## get_total_bonus() -> int
##
## Returns the calculated total bonus for this round.
## Includes challenge reward, chore reward, empty categories bonus, and score above target bonus.
func get_total_bonus() -> int:
	return total_bonus


## get_challenge_reward() -> int
##
## Returns the challenge reward amount.
func get_challenge_reward() -> int:
	return challenge_reward_amount


## get_chore_reward() -> int
##
## Returns the chore reward amount.
func get_chore_reward() -> int:
	return chore_reward_amount


## get_empty_categories_bonus() -> int
##
## Returns the empty categories bonus amount.
func get_empty_categories_bonus() -> int:
	return empty_categories_bonus


## get_score_above_bonus() -> int
##
## Returns the points-above-target bonus amount.
func get_score_above_bonus() -> int:
	return score_above_bonus


## get_power_up_bonus() -> int
##
## Returns the aggregated round-end PowerUp bonus amount.
func get_power_up_bonus() -> int:
	return power_up_bonus_amount



## _create_backdrop_fx_rect() -> ColorRect
##
## Builds a full-rect ColorRect with the panel backdrop shader and inserts it
## as the panel's first child so content draws on top.
func _create_backdrop_fx_rect() -> ColorRect:
	var fx_rect := ColorRect.new()
	fx_rect.name = "BackdropFxRect"
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader := load(BACKDROP_SHADER_PATH) as Shader
	if shader:
		var fx_material := ShaderMaterial.new()
		fx_material.shader = shader
		fx_material.set_shader_parameter("corner_radius", PANEL_CORNER_RADIUS)
		fx_rect.material = fx_material
	else:
		push_error("[EndOfRoundStatsPanel] Failed to load shader: " + BACKDROP_SHADER_PATH)
	panel_container.add_child(fx_rect)
	panel_container.move_child(fx_rect, 0)
	backdrop_fx_rect = fx_rect
	_update_backdrop_fx_size()
	return fx_rect


## _update_backdrop_fx_size()
##
## Pushes the panel's current size into the backdrop shader so its rounded
## mask tracks layout. Connected to the panel's resized signal.
func _update_backdrop_fx_size() -> void:
	if backdrop_fx_rect == null or backdrop_fx_rect.material == null or panel_container == null:
		return
	var panel_size := panel_container.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = panel_container.custom_minimum_size
	(backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)
