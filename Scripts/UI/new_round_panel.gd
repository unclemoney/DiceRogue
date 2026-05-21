extends Control
class_name NewRoundPanel

## NewRoundPanel
##
## Full-screen overlay that introduces a new round with channel, round number,
## debuffs, challenge, and chore information. Follows the same construction pattern
## as ChoreSelectionPopup and ChannelManagerUI.

signal panel_dismissed

var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _channel_label: Label
var _challenge_label: Label
var _challenge_desc_label: Label
var _debuffs_container: GridContainer
var _chore_row: HBoxContainer
var _chore_label: Label
var _lets_play_button: Button

var _panel_original_pos: Vector2
var _tfx: TweenFXHelper


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	_tfx = get_node_or_null("/root/TweenFXHelper")


## setup(data)
##
## Builds and populates the panel UI from a data dictionary.
## Keys: channel (int), round_number (int), challenge_name (String),
## challenge_desc (String), debuffs (Array[Dictionary]), chore_name (String)
func setup(data: Dictionary) -> void:
	_build_ui(data)


## show_panel()
##
## Makes the panel visible and plays the entrance animation.
## Animates position and fade only (no scale distortion on PanelContainer).
func show_panel() -> void:
	visible = true
	# Juice: panel swoosh sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_panel_swoosh"):
		audio_mgr.play_panel_swoosh()
	# Wait one frame for layout so _panel.position reflects the centered position
	await get_tree().process_frame
	_panel_original_pos = _panel.position
	_panel.modulate.a = 0.0
	_panel.position = _panel_original_pos - Vector2(0, 300)
	
	var tween = create_tween()
	tween.tween_property(_panel, "position", _panel_original_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_panel, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished


## _on_lets_play_pressed()
##
## Animates panel exit and overlay fade, then emits panel_dismissed.
func _on_lets_play_pressed() -> void:
	var tween = create_tween()
	tween.tween_property(_panel, "position:y", _panel_original_pos.y + 300, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_overlay, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_panel, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false
	panel_dismissed.emit()


func _build_ui(data: Dictionary) -> void:
	## Clear previous content
	for child in get_children():
		child.queue_free()
	
	## Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.6)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	## Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(460, 340)
	_panel.anchor_left = 0.5
	_panel.anchor_top = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -230
	_panel.offset_top = -170
	_panel.offset_right = 230
	_panel.offset_bottom = 170
	
	## Theme
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres")
	if theme_res:
		_panel.theme = theme_res
	
	## Custom panel style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	style.border_color = Color(0.3, 0.25, 0.35, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(20)
	style.corner_detail = 8
	_panel.add_theme_stylebox_override("panel", style)
	
	add_child(_panel)
	
	## Content layout
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 25)
	margin.add_theme_constant_override("margin_right", 25)
	margin.add_theme_constant_override("margin_top", 25)
	margin.add_theme_constant_override("margin_bottom", 25)
	_panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	## Title
	_title_label = Label.new()
	_title_label.text = "ROUND %d" % data.get("round_number", 1)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(_title_label)
	
	## Separator
	vbox.add_child(HSeparator.new())
	
	## Channel row
	_channel_label = Label.new()
	_channel_label.text = "Channel %d" % data.get("channel", 1)
	_channel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_channel_label.add_theme_font_size_override("font_size", 18)
	_channel_label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	vbox.add_child(_channel_label)
	
	## Challenge name
	_challenge_label = Label.new()
	_challenge_label.text = data.get("challenge_name", "")
	_challenge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_challenge_label.add_theme_font_size_override("font_size", 16)
	_challenge_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vbox.add_child(_challenge_label)
	
	## Challenge description
	var challenge_desc = data.get("challenge_desc", "")
	if not challenge_desc.is_empty():
		_challenge_desc_label = Label.new()
		_challenge_desc_label.text = challenge_desc
		_challenge_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_challenge_desc_label.add_theme_font_size_override("font_size", 13)
		_challenge_desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_challenge_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(_challenge_desc_label)
	
	## Debuffs
	var debuffs = data.get("debuffs", [])
	if debuffs.size() > 0:
		_debuffs_container = GridContainer.new()
		_debuffs_container.columns = 2
		_debuffs_container.add_theme_constant_override("h_separation", 12)
		_debuffs_container.add_theme_constant_override("v_separation", 6)
		vbox.add_child(_debuffs_container)
		
		for debuff_data in debuffs:
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			
			if debuff_data.get("icon"):
				var icon = TextureRect.new()
				icon.custom_minimum_size = Vector2(20, 20)
				icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.texture = debuff_data["icon"]
				row.add_child(icon)
			
			var name_label = Label.new()
			name_label.text = debuff_data.get("name", "Debuff")
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
			row.add_child(name_label)
			_debuffs_container.add_child(row)
	
	## Chore
	var chore_name = data.get("chore_name", "")
	if not chore_name.is_empty():
		_chore_row = HBoxContainer.new()
		_chore_row.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(_chore_row)
		
		var chore_prefix = Label.new()
		chore_prefix.text = "Chore: "
		chore_prefix.add_theme_font_size_override("font_size", 14)
		chore_prefix.add_theme_color_override("font_color", Color(0.8, 0.8, 0.4))
		_chore_row.add_child(chore_prefix)
		
		_chore_label = Label.new()
		_chore_label.text = chore_name
		_chore_label.add_theme_font_size_override("font_size", 14)
		_chore_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
		_chore_row.add_child(_chore_label)
	
	## Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND
	vbox.add_child(spacer)
	
	## Let's Play button
	_lets_play_button = Button.new()
	_lets_play_button.text = "Let's Play"
	_lets_play_button.custom_minimum_size = Vector2(180, 50)
	_lets_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_lets_play_button.add_theme_font_size_override("font_size", 20)
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	btn_style.border_color = Color(0.3, 0.7, 0.3, 1.0)
	btn_style.set_border_width_all(3)
	btn_style.set_corner_radius_all(12)
	_lets_play_button.add_theme_stylebox_override("normal", btn_style)
	
	var btn_hover = btn_style.duplicate()
	btn_hover.bg_color = Color(0.25, 0.6, 0.25, 1.0)
	btn_hover.border_color = Color(0.4, 0.9, 0.4, 1.0)
	_lets_play_button.add_theme_stylebox_override("hover", btn_hover)
	
	var btn_pressed = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.15, 0.4, 0.15, 1.0)
	_lets_play_button.add_theme_stylebox_override("pressed", btn_pressed)
	
	_lets_play_button.pressed.connect(_on_lets_play_pressed)
	if _tfx:
		_lets_play_button.mouse_entered.connect(_tfx.button_hover.bind(_lets_play_button))
		_lets_play_button.mouse_exited.connect(_tfx.button_unhover.bind(_lets_play_button))
		_lets_play_button.pressed.connect(_tfx.button_press.bind(_lets_play_button))
	vbox.add_child(_lets_play_button)
