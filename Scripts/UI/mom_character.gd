extends Control
class_name MomCharacter

## MomCharacter
##
## Dialog popup for Mom character that appears when chore progress reaches 100.
## Features tween animations, 3 expression sprites, and RichTextLabel dialog with BBCode.
## Used by MomLogicHandler to display consequences to the player.

signal dialog_closed

enum MomExpression { NEUTRAL, UPSET, HAPPY }

const TWEEN_DURATION: float = 0.3
const TEXT_DISPLAY_SPEED: float = 0.03  # Seconds per character

@export var neutral_texture: Texture2D
@export var upset_texture: Texture2D
@export var happy_texture: Texture2D

# Node references
var background_overlay: ColorRect
var dialog_panel: PanelContainer
var sprite_rect: TextureRect
var dialog_label: RichTextLabel
var close_button: Button
var _current_expression: MomExpression = MomExpression.NEUTRAL
var _is_animating: bool = false
var _full_dialog_text: String = ""
@onready var _tfx := get_node("/root/TweenFXHelper")

func _ready() -> void:
	_load_textures()
	_create_ui_structure()
	visible = false
	print("[MomCharacter] Initialized")

## _load_textures()
##
## Loads the Mom expression textures from Resources.
func _load_textures() -> void:
	if not neutral_texture:
		neutral_texture = load("res://Resources/Art/Characters/Mom/mom_neutral.png")
	if not upset_texture:
		upset_texture = load("res://Resources/Art/Characters/Mom/mom_upset.png")
	if not happy_texture:
		happy_texture = load("res://Resources/Art/Characters/Mom/mom_happy.png")
	print("[MomCharacter] Textures loaded: neutral=%s, upset=%s, happy=%s" % [
		neutral_texture != null,
		upset_texture != null,
		happy_texture != null
	])

## show_dialog()
##
## Shows the Mom dialog with the specified expression and text.
## Animates in from off-screen.
##
## Parameters:
##   expression_name: String - "neutral", "upset", or "happy"
##   dialog_text: String - the BBCode-formatted dialog text
func show_dialog(expression_name: String, dialog_text: String) -> void:
	set_expression(expression_name)
	_full_dialog_text = dialog_text
	dialog_label.text = ""
	
	visible = true
	_animate_in()
	
	# Set dialog text
	_type_dialog_text(dialog_text)

## set_expression()
##
## Sets the Mom sprite to the specified expression.
##
## Parameters:
##   expression_name: String - "neutral", "upset", or "happy"
func set_expression(expression_name: String) -> void:
	match expression_name.to_lower():
		"neutral":
			_current_expression = MomExpression.NEUTRAL
			if neutral_texture:
				sprite_rect.texture = neutral_texture
		"upset":
			_current_expression = MomExpression.UPSET
			if upset_texture:
				sprite_rect.texture = upset_texture
		"happy":
			_current_expression = MomExpression.HAPPY
			if happy_texture:
				sprite_rect.texture = happy_texture
		_:
			_current_expression = MomExpression.NEUTRAL
			if neutral_texture:
				sprite_rect.texture = neutral_texture
	
	print("[MomCharacter] Expression set to: %s" % expression_name)

## close_dialog()
##
## Closes the dialog and animates out.
## Emits dialog_closed when animation completes.
func close_dialog() -> void:
	if _is_animating:
		return
	
	await _animate_out()
	visible = false
	dialog_closed.emit()

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
	
	# Main dialog panel — centered via anchors (NOT CenterContainer, which fights tweens)
	dialog_panel = PanelContainer.new()
	dialog_panel.name = "DialogPanel"
	dialog_panel.custom_minimum_size = Vector2(500, 300)
	dialog_panel.set_anchors_preset(Control.PRESET_CENTER)
	dialog_panel.offset_left = -250
	dialog_panel.offset_top = -150
	dialog_panel.offset_right = 250
	dialog_panel.offset_bottom = 150
	dialog_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialog_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_apply_panel_style()
	add_child(dialog_panel)
	
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
	
	# Sprite container
	var sprite_container = PanelContainer.new()
	sprite_container.custom_minimum_size = Vector2(128, 128)
	_apply_sprite_panel_style(sprite_container)
	hbox.add_child(sprite_container)
	
	sprite_rect = TextureRect.new()
	sprite_rect.name = "SpriteRect"
	sprite_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sprite_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sprite_rect.custom_minimum_size = Vector2(120, 120)
	sprite_container.add_child(sprite_rect)
	
	# Dialog text container
	var dialog_container = VBoxContainer.new()
	dialog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(dialog_container)
	
	# "Mom" title
	var title_label = Label.new()
	title_label.text = "Mom"
	title_label.add_theme_font_size_override("font_size", 20)
	title_label.add_theme_color_override("font_color", Color(1, 0.8, 0.9))
	dialog_container.add_child(title_label)
	
	# Dialog text (RichTextLabel with BBCode)
	dialog_label = RichTextLabel.new()
	dialog_label.name = "DialogLabel"
	dialog_label.bbcode_enabled = true
	dialog_label.fit_content = true
	dialog_label.custom_minimum_size = Vector2(300, 120)
	dialog_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialog_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog_label.add_theme_font_size_override("normal_font_size", 16)
	dialog_label.add_theme_color_override("default_color", Color.WHITE)
	dialog_container.add_child(dialog_label)
	
	# Close button
	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "OK"
	close_button.custom_minimum_size = Vector2(100, 40)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_apply_button_style()
	close_button.pressed.connect(_on_close_pressed)
	close_button.mouse_entered.connect(func(): _tfx.button_hover(close_button))
	close_button.mouse_exited.connect(func(): _tfx.button_unhover(close_button))
	vbox.add_child(close_button)

func _apply_panel_style() -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.1, 0.2, 0.98)
	style.border_color = Color(0.6, 0.4, 0.7)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
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

func _apply_button_style() -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.3, 0.2, 0.4)
	normal.border_color = Color(0.5, 0.4, 0.6)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(5)
	close_button.add_theme_stylebox_override("normal", normal)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(0.4, 0.3, 0.5)
	hover.border_color = Color(0.7, 0.5, 0.8)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(5)
	close_button.add_theme_stylebox_override("hover", hover)
	
	var pressed = StyleBoxFlat.new()
	pressed.bg_color = Color(0.2, 0.15, 0.3)
	pressed.border_color = Color(0.4, 0.3, 0.5)
	pressed.set_border_width_all(2)
	pressed.set_corner_radius_all(5)
	close_button.add_theme_stylebox_override("pressed", pressed)

func _animate_in() -> void:
	_is_animating = true
	
	# Fade in background overlay
	background_overlay.modulate.a = 0
	var bg_tween = create_tween()
	bg_tween.tween_property(background_overlay, "modulate:a", 1.0, 0.3)
	
	# Reset panel to home offsets in case of a previous _animate_out
	dialog_panel.offset_left = -250
	dialog_panel.offset_top = -150
	dialog_panel.offset_right = 250
	dialog_panel.offset_bottom = 150
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
	panel_tween.tween_property(dialog_panel, "offset_top", target_top, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "offset_bottom", target_bottom, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	panel_tween.parallel().tween_property(dialog_panel, "modulate:a", 1.0, 0.2)
	await panel_tween.finished
	
	# Jelly settle wobble on landing
	TweenFX.jelly(dialog_panel, 0.3, 0.15, 2)
	
	# Wobble Mom sprite for extra personality
	TweenFX.jelly(sprite_rect, 0.4, 0.1, 2)
	
	await get_tree().create_timer(0.4).timeout
	_is_animating = false

func _animate_out() -> void:
	_is_animating = true
	
	# Quick hop on Mom sprite before exit
	TweenFX.hop(sprite_rect, 0.2, 20.0)
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

func _type_dialog_text(text: String) -> void:
	# Simple approach: set text immediately (BBCode makes typewriter complex)
	dialog_label.text = text

func _on_close_pressed() -> void:
	close_dialog()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	# Allow closing with Enter or Space
	if event is InputEventKey:
		var key_event = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_SPACE:
				close_dialog()
