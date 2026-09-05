extends Control
class_name MomCharacter

## MomCharacter
##
## Dialog popup for Mom character that appears when chore progress reaches 100.
## Features tween animations, an animated portrait (MomPortraitAnimator with
## mood-scaled speech loops and one-shot reactions), typewriter dialog text,
## and RichTextLabel dialog with BBCode.
## Used by MomLogicHandler to display consequences to the player.

signal dialog_closed
signal response_selected(index: int)  # Emitted when the player picks a dialog response

enum MomExpression { NEUTRAL, UPSET, HAPPY }

const TWEEN_DURATION: float = 0.3
const TEXT_DISPLAY_SPEED: float = 0.03  # Seconds per character
## Extra reveal ticks paused on sentence punctuation (speech keeps looping).
const PUNCTUATION_CHARS := ",.!?;:—"
const PUNCTUATION_PAUSE_TICKS: int = 2
const PANEL_BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
## Preloaded (not the class_name) so parsing doesn't depend on the editor's
## class cache being fresh.
const MomPortraitAnimatorScript := preload("res://Scripts/UI/mom_portrait_animator.gd")

## One fixed panel size for every dialog beat so the popup never resizes
## between lines. Fits the worst case: long text + MAX_RESPONSES buttons.
const PANEL_SIZE := Vector2(560, 500)
## Response buttons beyond this are dropped with a warning (panel won't grow).
const MAX_RESPONSES: int = 4
## Portrait frame geometry: 128px panel with a 2px border. The portrait is
## bottom-aligned flush with the inner bottom edge, like a framed portrait.
const PORTRAIT_FRAME_SIZE: float = 128.0
const PORTRAIT_BORDER_WIDTH: float = 2.0
const PORTRAIT_SCALE: float = 0.9

## Rep meter (rebel mode): GameProgressBar, resources = gold scheme.
## Escalating rebel-stage tints (Teacher's Pet -> Banned from the Mall).
const REP_STAGE_COLORS: Array[Color] = [
	Color(0.47, 0.89, 0.89),  # teal
	Color(1.0, 0.73, 0.49),   # amber
	Color(0.9, 0.45, 0.56),   # magenta
	Color(1.0, 0.25, 0.5),    # hot pink
]

## Pink/purple palette for the GlassActionButton close button,
## matching the dialog border (0.6, 0.4, 0.7) and Mom label pink (1, 0.8, 0.9).
const MOM_BUTTON_PALETTE := {
	"base_color": Color(0.35, 0.15, 0.45, 1.0),
	"mid_color": Color(0.5, 0.25, 0.55, 1.0),
	"accent_color": Color(0.8, 0.4, 0.8, 1.0),
	"glow_color": Color(1.0, 0.7, 0.9, 1.0),
	"rim_color": Color(1.0, 0.85, 0.95, 1.0),
	"font_color": Color(1.0, 0.9, 0.95, 1.0),
	"font_outline_color": Color(0.15, 0.1, 0.2, 1.0),
	"outline_size": 1
}

# Fonts
var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

# Node references
var background_overlay: ColorRect
var dialog_panel: PanelContainer
var backdrop_fx_rect: ColorRect
var portrait: MomPortraitAnimatorScript
var dialog_label: RichTextLabel
var close_button: GlassActionButton
var response_row: VBoxContainer
var rep_row: HBoxContainer
var rep_meter: GameProgressBar
var rep_stage_label: Label
var response_buttons: Array[GlassActionButton] = []
var _current_responses: Array = []  # MomDialogResponse resources for the current beat
var _current_expression: MomExpression = MomExpression.NEUTRAL
var _is_animating: bool = false
var _full_dialog_text: String = ""
var _char_timer: Timer
var _total_chars: int = 0
var _punct_ticks: int = 0
var title_label: Label
## Node id of the beat currently shown (bot policy reads this for
## story-aware choices, e.g. contesting false Patterson sightings).
var current_node_id: String = ""

func _ready() -> void:
	_create_ui_structure()
	_create_char_timer()
	visible = false
	_connect_mood_signal()
	var pm := get_node_or_null("/root/ProgressManager")
	if pm and pm.has_signal("rep_changed"):
		if not pm.is_connected("rep_changed", _on_rep_changed):
			pm.rep_changed.connect(_on_rep_changed)
		_update_rep_display()
	print("[MomCharacter] Initialized")


## _create_char_timer()
##
## Builds the typewriter timer that reveals dialog text one character at a
## time and gates the portrait's speech loop.
func _create_char_timer() -> void:
	_char_timer = Timer.new()
	_char_timer.name = "CharTimer"
	_char_timer.wait_time = TEXT_DISPLAY_SPEED
	_char_timer.timeout.connect(_on_char_timer_timeout)
	add_child(_char_timer)


## _connect_mood_signal()
##
## Feeds ChoresManager.mom_mood into the portrait (initial seed + live
## updates) so speech clips and reaction availability track mood changes,
## including mid-dialogue. No-op outside a game scene (e.g. isolated tests
## can call portrait.set_mood() directly).
func _connect_mood_signal() -> void:
	if portrait == null:
		return
	var gc := get_tree().get_first_node_in_group("game_controller")
	if gc == null:
		return
	var cm = gc.get("chores_manager")
	if cm == null or not cm.has_signal("mom_mood_changed"):
		return
	if not cm.is_connected("mom_mood_changed", portrait.set_mood):
		cm.mom_mood_changed.connect(portrait.set_mood)
	portrait.set_mood(int(cm.get("mom_mood")))


## _on_rep_changed(new_rep)
##
## ProgressManager rep_changed handler: refreshes the rebel meter.
func _on_rep_changed(new_rep: int) -> void:
	_update_rep_display()
	# Juice the meter on change so the player notices the payoff
	if rep_meter:
		var tween := create_tween()
		tween.tween_property(rep_meter, "scale", Vector2(1.04, 1.3), 0.12)
		tween.tween_property(rep_meter, "scale", Vector2.ONE, 0.18)


## _update_rep_display()
##
## Refreshes the Rep meter value and stage styling from ProgressManager.
## Visual identity escalates with Rep: tint + stage name (4 stages).
func _update_rep_display() -> void:
	var pm := get_node_or_null("/root/ProgressManager")
	if not pm or not pm.has_method("get_rep") or not rep_meter:
		return
	rep_meter.value = pm.get_rep()
	var stage: int = pm.get_rep_stage()
	var color: Color = REP_STAGE_COLORS[clampi(stage, 0, REP_STAGE_COLORS.size() - 1)]
	rep_meter.tint_progress = color
	if rep_stage_label:
		rep_stage_label.text = pm.get_rep_stage_name().to_upper()
		rep_stage_label.add_theme_color_override("font_color", color)

## show_dialog(expression_name, dialog_text)
##
## Legacy entry point: shows the dialog with just the OK button.
## Used by the tutorial and any non-tree callers. For dialog trees,
## use show_node() instead.
##
## Parameters:
##   expression_name: String - "neutral", "upset", or "happy"
##   dialog_text: String - the BBCode-formatted dialog text
func show_dialog(expression_name: String, dialog_text: String) -> void:
	set_expression(expression_name)
	if title_label:
		title_label.text = "Mom"
	if portrait:
		portrait.modulate = Color.WHITE
		portrait.set_paused(false)
	_full_dialog_text = dialog_text
	_build_response_buttons([])
	close_button.visible = true

	visible = true
	_animate_in()

	# Set dialog text
	_type_dialog_text(dialog_text)

## show_node(node)
##
## Shows a MomDialogNode: her line, expression, and response buttons.
## Terminal nodes (no responses) show the OK button instead.
## Re-animates in only when the dialog is currently hidden, so
## follow-up beats swap content in place.
##
## Parameters:
##   node: MomDialogNode - the dialog beat to display
func show_node(node: MomDialogNode) -> void:
	if node == null:
		return
	var was_hidden := not visible
	current_node_id = node.id
	set_expression(node.expression)
	# Speaker label + portrait tint (cast story beats, e.g. phone calls).
	# Mom still delivers every line; the cast never speaks directly.
	if title_label:
		title_label.text = node.speaker_name
	if portrait:
		portrait.modulate = node.speaker_tint
		portrait.set_paused(false)
	_full_dialog_text = node.mom_text
	_type_dialog_text(node.mom_text)
	_build_response_buttons(node.responses)
	close_button.visible = node.is_terminal()

	if was_hidden:
		visible = true
		_animate_in()

## show_outcome_reply(text, expression)
##
## Shows Mom's reply line after an outcome resolves, with no responses
## (OK button shown). Used when an outcome ends the visit with a parting
## line instead of chaining to another node.
func show_outcome_reply(text: String, expression: String) -> void:
	if expression != "":
		set_expression(expression)
	_full_dialog_text = text
	_type_dialog_text(text)
	_build_response_buttons([])
	close_button.visible = true

## press_response(index)
##
## Programmatically picks a response. Used by the bot policy; the
## response_selected signal flows through the same path as a real click.
func press_response(index: int) -> void:
	if index < 0 or index >= response_buttons.size():
		return
	_on_response_pressed(index)

## has_pending_responses() -> bool
##
## Returns: bool - true while the dialog waits on a response button pick
func has_pending_responses() -> bool:
	return visible and response_row.visible and response_buttons.size() > 0

## choose_response_weighted(policy) -> bool
##
## Bot policy: picks a response and presses it. With the default
## "tone_weighted" policy this is a tone-weighted random pick (mostly
## polite, sometimes neutral, rarely sassy). "always_comply"/"always_sass"
## pin the pick to that tone (falling back to weighted when absent).
##
## Returns: bool - true if a response was pressed
func choose_response_weighted(policy: String = "tone_weighted") -> bool:
	if not has_pending_responses():
		return false
	match policy:
		"always_comply":
			return choose_response_by_tone("polite")
		"always_sass":
			return choose_response_by_tone("sassy")
	var weights: Array = []
	for response in _current_responses:
		var tone: String = response.tone if response else "neutral"
		weights.append(float(MomLogicHandler.BOT_TONE_WEIGHTS.get(tone, 1.0)))
	var index: int = MomLogicHandler._pick_weighted_index(weights)
	press_response(index)
	return true

## choose_response_by_tone(tone) -> bool
##
## Bot policy helper: picks a random response of the given tone and
## presses it. Falls back to the tone-weighted pick when no response of
## that tone exists on this beat.
##
## Returns: bool - true if a response was pressed
func choose_response_by_tone(tone: String) -> bool:
	if not has_pending_responses():
		return false
	var matching: Array[int] = []
	for i in range(_current_responses.size()):
		var response = _current_responses[i]
		if response and response.tone == tone:
			matching.append(i)
	if matching.is_empty():
		return choose_response_weighted("tone_weighted")
	press_response(matching[GameRNG.randi_range(0, matching.size() - 1)])
	return true

## choose_response_by_button_text(fragment) -> bool
##
## Bot policy helper: presses the first response whose button text
## contains the fragment (case-insensitive). Used by the tactical bot to
## contest Patterson sightings it knows are false. Falls back to the
## tone-weighted pick when nothing matches.
##
## Returns: bool - true if a response was pressed
func choose_response_by_button_text(fragment: String) -> bool:
	if not has_pending_responses():
		return false
	var needle := fragment.to_lower()
	for i in range(_current_responses.size()):
		var response = _current_responses[i]
		if response and response.button_text.to_lower().contains(needle):
			press_response(i)
			return true
	return choose_response_weighted("tone_weighted")

## _build_response_buttons(responses)
##
## Rebuilds the response button row from MomDialogResponse resources.
## Empty array hides the row (terminal beat).
func _build_response_buttons(responses: Array) -> void:
	for button in response_buttons:
		if is_instance_valid(button):
			button.queue_free()
	response_buttons.clear()

	if responses.is_empty():
		response_row.visible = false
		_current_responses.clear()
		return

	response_row.visible = true
	_current_responses = responses.duplicate()
	if responses.size() > MAX_RESPONSES:
		push_warning("[MomCharacter] Dialog node has %d responses; showing first %d (panel is fixed-size)" % [responses.size(), MAX_RESPONSES])
		_current_responses.resize(MAX_RESPONSES)
	for i in range(_current_responses.size()):
		var response: MomDialogResponse = _current_responses[i]
		if response == null:
			continue
		var button := GlassActionButton.new()
		button.name = "ResponseButton%d" % i
		button.configure(response.button_text, Vector2(420, 44), MOM_BUTTON_PALETTE, 15, vcr_font)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var index := i
		button.pressed.connect(_on_response_pressed.bind(index))
		response_row.add_child(button)
		response_buttons.append(button)

func _on_response_pressed(index: int) -> void:
	# Prevent double-picks while the outcome resolves
	for button in response_buttons:
		if is_instance_valid(button):
			button.disabled = true
	# Mom reacts to the player's tone (sassy draws a glare, polite a laugh
	# from a happy Mom) - the reaction interrupts speech, then resumes it.
	if portrait and index >= 0 and index < _current_responses.size():
		var response = _current_responses[index]
		if response:
			portrait.react_to_tone(response.tone)
	print("[MomCharacter] Response %d selected" % index)
	response_selected.emit(index)

## set_expression()
##
## Sets the dialog's expression hint. The portrait uses it (blended with the
## live mood) to pick speech clips; no static textures are swapped anymore.
##
## Parameters:
##   expression_name: String - "neutral", "upset", or "happy"
func set_expression(expression_name: String) -> void:
	match expression_name.to_lower():
		"happy":
			_current_expression = MomExpression.HAPPY
		"upset":
			_current_expression = MomExpression.UPSET
		_:
			_current_expression = MomExpression.NEUTRAL
	if portrait:
		portrait.set_expression_hint(expression_name)

	print("[MomCharacter] Expression set to: %s" % expression_name)

## close_dialog()
##
## Closes the dialog and animates out.
## Emits dialog_closed when animation completes.
func close_dialog() -> void:
	if _is_animating:
		return

	# Stop the typewriter and freeze the portrait while hidden
	_stop_typing()
	if portrait:
		portrait.stop_talking()
		portrait.set_paused(true)

	await _animate_out()
	visible = false
	dialog_closed.emit()


## get_portrait_center() -> Vector2
##
## Global center of Mom's portrait - fly target for confiscation animations.
func get_portrait_center() -> Vector2:
	if portrait:
		return portrait.global_position
	return Vector2.ZERO

func _create_ui_structure() -> void:
	# Set to fill screen
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 150  # Above corkboard/shop (100-135) but below pause menu (200)
	
	# Background overlay (semi-transparent black)
	background_overlay = ColorRect.new()
	background_overlay.name = "BackgroundOverlay"
	background_overlay.color = Color(0, 0, 0, 0.7)
	background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background_overlay)
	
	# Main dialog panel — centered via anchors (NOT CenterContainer, which fights tweens).
	# Fixed size: anchors + offsets + min size all agree, so content can never
	# grow or shrink the panel between beats.
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.custom_minimum_size = PANEL_SIZE
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER)
	dialog_panel.offset_left = -PANEL_SIZE.x / 2.0
	dialog_panel.offset_top = -PANEL_SIZE.y / 2.0
	dialog_panel.offset_right = PANEL_SIZE.x / 2.0
	dialog_panel.offset_bottom = PANEL_SIZE.y / 2.0
	dialog_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_apply_panel_style()
	add_child(dialog_panel)
	
	# Backdrop shader overlay (child index 0 so content draws on top)
	backdrop_fx_rect = _create_backdrop_fx_rect()
	
	# Content container
	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 15)
	dialog_panel.add_child(vbox)
	
	# Top section with sprite and dialog
	var hbox = HBoxContainer.new()
	hbox.name = "TopSection"
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)
	
	# Sprite container: pinned to a square at the top of the row so the tall
	# fixed panel can't stretch the frame away from the bottom-aligned
	# portrait (the text column takes the extra height instead).
	var sprite_container = PanelContainer.new()
	sprite_container.custom_minimum_size = Vector2(PORTRAIT_FRAME_SIZE, PORTRAIT_FRAME_SIZE)
	sprite_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_apply_sprite_panel_style(sprite_container)
	hbox.add_child(sprite_container)
	
	# Animated portrait (Node2D child of a Control draws at an explicit
	# position; containers only lay out Control children). Bottom-aligned so
	# Mom's feet sit flush with the frame's inner bottom edge, like a
	# portrait: center y = (frame - border) - half the scaled sprite height.
	portrait = MomPortraitAnimatorScript.new()
	portrait.name = "Portrait"
	portrait.position = Vector2(
		PORTRAIT_FRAME_SIZE / 2.0,
		(PORTRAIT_FRAME_SIZE - PORTRAIT_BORDER_WIDTH) - (PORTRAIT_FRAME_SIZE * PORTRAIT_SCALE) / 2.0
	)
	portrait.scale = Vector2.ONE * PORTRAIT_SCALE
	sprite_container.add_child(portrait)
	
	# Dialog text container
	var dialog_container = VBoxContainer.new()
	dialog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(dialog_container)
	
	# "Mom" title
	title_label = Label.new()
	title_label.text = "Mom"
	title_label.add_theme_font_override("font", vcr_font)
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	dialog_container.add_child(title_label)
	
	# Dialog text (RichTextLabel with BBCode)
	dialog_label = RichTextLabel.new()
	dialog_label.name = "DialogLabel"
	dialog_label.bbcode_enabled = true
	# No fit_content: long text scrolls inside the fixed panel instead of
	# growing it.
	dialog_label.fit_content = false
	dialog_label.custom_minimum_size = Vector2(300, 120)
	dialog_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_label.add_theme_font_override("normal_font", vcr_font)
	dialog_label.add_theme_font_size_override("normal_font_size", 16)
	dialog_label.add_theme_color_override("default_color", Color.WHITE)
	dialog_container.add_child(dialog_label)
	
	# Rep meter (rebel mode): persistent Rebellion stat feedback, shown
	# between Mom's line and the response buttons where sass happens.
	rep_row = HBoxContainer.new()
	rep_row.name = "RepRow"
	rep_row.add_theme_constant_override("separation", 8)
	vbox.add_child(rep_row)
	
	var rep_title = Label.new()
	rep_title.text = "REP"
	rep_title.add_theme_font_override("font", vcr_font)
	rep_title.add_theme_font_size_override("font_size", 14)
	rep_title.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	rep_row.add_child(rep_title)
	
	rep_meter = GameProgressBar.new()
	rep_meter.name = "RepMeter"
	rep_meter.min_value = 0
	rep_meter.max_value = 100
	rep_meter.value = 0
	rep_meter.fill_color = Color(0.95, 0.78, 0.3, 1.0)  # resources = gold
	rep_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rep_meter.custom_minimum_size = Vector2(0, 24)
	rep_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rep_row.add_child(rep_meter)
	
	rep_stage_label = Label.new()
	rep_stage_label.name = "RepStageLabel"
	rep_stage_label.add_theme_font_override("font", vcr_font)
	rep_stage_label.add_theme_font_size_override("font_size", 12)
	rep_row.add_child(rep_stage_label)
	
	# Response button column (hidden unless a dialog node has responses).
	# Buttons stack vertically and span the dialog width - response texts
	# are full sentences, too long for side-by-side buttons.
	response_row = VBoxContainer.new()
	response_row.name = "ResponseRow"
	response_row.add_theme_constant_override("separation", 8)
	response_row.alignment = BoxContainer.ALIGNMENT_CENTER
	response_row.visible = false
	vbox.add_child(response_row)

	# Close button (GlassActionButton handles its own hover/press TweenFX)
	close_button = GlassActionButton.new()
	close_button.name = "CloseButton"
	close_button.configure("OK", Vector2(100, 40), MOM_BUTTON_PALETTE, 18, vcr_font)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(close_button)

func _apply_panel_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.2, 0.98)
	style.border_color = Color(0.6, 0.4, 0.7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.6, 0.4, 0.7, 0.6)
	style.shadow_size = 12
	style.set_content_margin_all(20)
	dialog_panel.add_theme_stylebox_override("panel", style)

func _apply_sprite_panel_style(panel: PanelContainer) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.15, 0.25)
	style.border_color = Color(0.5, 0.4, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(4)
	panel.add_theme_stylebox_override("panel", style)

## _create_backdrop_fx_rect() -> ColorRect
## Builds a full-rect ColorRect with the panel backdrop shader and inserts it
## behind the dialog panel's content so text/sprites draw on top.
func _create_backdrop_fx_rect() -> ColorRect:
	var fx_rect := ColorRect.new()
	fx_rect.name = "BackdropFxRect"
	fx_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_rect.color = Color.WHITE
	var shader := load(PANEL_BACKDROP_SHADER_PATH) as Shader
	if shader:
		var fx_material := ShaderMaterial.new()
		fx_material.shader = shader
		fx_material.set_shader_parameter("corner_radius", 10.0)
		fx_rect.material = fx_material
	else:
		push_error("[MomCharacter] Failed to load shader: " + PANEL_BACKDROP_SHADER_PATH)
	dialog_panel.add_child(fx_rect)
	dialog_panel.move_child(fx_rect, 0)
	if not dialog_panel.resized.is_connected(_update_backdrop_rect_size):
		dialog_panel.resized.connect(_update_backdrop_rect_size)
	_update_backdrop_rect_size()
	return fx_rect


## _update_backdrop_rect_size()
## Pushes the dialog panel's current size into the backdrop shader so its
## rounded mask tracks layout. Called initially and on panel resize.
func _update_backdrop_rect_size() -> void:
	if backdrop_fx_rect and backdrop_fx_rect.material and dialog_panel:
		var panel_size := dialog_panel.size
		if panel_size.x <= 0.0 or panel_size.y <= 0.0:
			panel_size = dialog_panel.custom_minimum_size
		(backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)

func _animate_in() -> void:
	_is_animating = true
	
	# Fade in background overlay
	background_overlay.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(background_overlay, "modulate:a", 1.0, 0.3)
	
	# Reset panel to home offsets in case of a previous _animate_out
	dialog_panel.offset_left = -PANEL_SIZE.x / 2.0
	dialog_panel.offset_top = -PANEL_SIZE.y / 2.0
	dialog_panel.offset_right = PANEL_SIZE.x / 2.0
	dialog_panel.offset_bottom = PANEL_SIZE.y / 2.0
	dialog_panel.scale = Vector2.ONE
	dialog_panel.modulate.a = 1.0
	dialog_panel.pivot_offset = dialog_panel.size / 2.0
	
	# Bouncy drop-in using offset tweening (works with anchor-based layout)
	var target_top: float = dialog_panel.offset_top
	var target_bottom: float = dialog_panel.offset_bottom
	dialog_panel.offset_top = target_top - 300.0
	dialog_panel.offset_bottom = target_bottom - 300.0
	dialog_panel.scale = Vector2(1.2, 0.8)
	dialog_panel.modulate.a = 0.0
	
	var panel_tween: Tween = create_tween()
	panel_tween.tween_property(dialog_panel, "offset_top", target_top, 0.75).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "offset_bottom", target_bottom, 0.75).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	await panel_tween.finished
	
	# Jelly settle wobble on landing
	TweenFX.jelly(dialog_panel, 1.2, 0.05, 2)
	
	# Wobble Mom portrait for extra personality
	TweenFX.jelly(portrait, 0.8, 0.05, 2)
	
	await get_tree().create_timer(0.4).timeout
	_is_animating = false

func _animate_out() -> void:
	_is_animating = true
	
	# Quick hop on Mom portrait before exit
	TweenFX.hop(portrait, 0.2, 20.0)
	await get_tree().create_timer(0.2).timeout
	
	# Panel flies out downward using offset tweening
	var exit_offset_top: float = dialog_panel.offset_top + 400.0
	var exit_offset_bottom: float = dialog_panel.offset_bottom + 400.0
	var panel_tween: Tween = create_tween()
	panel_tween.tween_property(dialog_panel, "offset_top", exit_offset_top, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tween.parallel().tween_property(dialog_panel, "offset_bottom", exit_offset_bottom, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	panel_tween.parallel().tween_property(dialog_panel, "modulate:a", 0.0, 0.3)
	
	# Fade out background overlay
	var bg_tween = create_tween()
	bg_tween.tween_property(background_overlay, "modulate:a", 0.0, 0.3)
	
	await panel_tween.finished
	_is_animating = false

## _type_dialog_text(text)
##
## Reveals dialog text one character at a time (TEXT_DISPLAY_SPEED per char,
## brief pauses on sentence punctuation). The portrait's speech loop runs
## for exactly the duration of the reveal - start/stop is the whole sync
## contract, no frame-perfect mouth matching.
func _type_dialog_text(text: String) -> void:
	dialog_label.text = text
	if portrait:
		portrait.set_paused(false)
	if _char_timer == null:
		dialog_label.visible_characters = -1
		return
	dialog_label.visible_characters = 0
	_punct_ticks = 0
	_total_chars = dialog_label.get_total_character_count()
	if _total_chars <= 0:
		_stop_typing()
		return
	_char_timer.start()
	if portrait:
		portrait.start_talking()


func _on_char_timer_timeout() -> void:
	if not visible:
		_stop_typing()
		return
	if _punct_ticks > 0:
		_punct_ticks -= 1
		return
	dialog_label.visible_characters += 1
	if dialog_label.visible_characters >= _total_chars:
		_stop_typing()
		return
	# Pause briefly after sentence punctuation (speech keeps looping)
	var revealed := dialog_label.get_parsed_text()
	var idx := dialog_label.visible_characters - 1
	if idx >= 0 and idx < revealed.length():
		if revealed.substr(idx, 1) in PUNCTUATION_CHARS:
			_punct_ticks = PUNCTUATION_PAUSE_TICKS


## _stop_typing()
##
## Completes the reveal instantly and stops the portrait's speech loop.
func _stop_typing() -> void:
	if _char_timer:
		_char_timer.stop()
	if dialog_label:
		dialog_label.visible_characters = -1
	if portrait:
		portrait.stop_talking()

func _on_close_pressed() -> void:
	close_dialog()

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Enter/Space only closes terminal beats (OK button visible) -
	# response beats must be answered with a button
	if not close_button.visible:
		return

	# Allow closing with Enter or Space
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
				close_dialog()
