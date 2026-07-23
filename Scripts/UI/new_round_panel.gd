extends Control
class_name NewRoundPanel

const GlassActionButtonClass = preload("res://Scripts/UI/glass_action_button.gd")
const GLYPH_SHADER: Shader = preload("res://Scripts/Shaders/debuff_glyph_glow.gdshader")
const PLACEHOLDER_TEXTURE: Texture2D = preload("res://Resources/Art/UI/white_pixel.png")
const BACKDROP_SHADER_PATH := "res://Scripts/Shaders/panel_backdrop.gdshader"
const PANEL_CORNER_RADIUS := 20.0

## NewRoundPanel
##
## Full-screen overlay that introduces a new round with channel, round number,
## debuffs, and challenge information. Follows the same construction pattern
## as ChoreSelectionPopup and ChannelManagerUI.

signal panel_dismissed

var _overlay: ColorRect
var _panel: PanelContainer
var _backdrop_fx_rect: ColorRect
var _title_label: Label
var _channel_label: Label
var _challenge_label: Label
var _challenge_desc_label: Label
var _debuffs_container: GridContainer
var _lets_play_button = null

var _panel_original_pos: Vector2
func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100


## _create_glyph_icon(debuff_data)
##
## Builds a small shader-driven SDF glyph icon for a round-intro debuff row.
func _create_glyph_icon(debuff_data: Dictionary) -> TextureRect:
	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(20, 20)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = PLACEHOLDER_TEXTURE

	var glyph_material := ShaderMaterial.new()
	glyph_material.shader = GLYPH_SHADER
	icon.material = glyph_material

	var glyph_color: Color = debuff_data.get("glow_color", Color(0.0, 0.0, 0.0, 0.0))
	if glyph_color.a <= 0.0:
		var rating: int = clampi(debuff_data.get("difficulty_rating", 1), 0, 5)
		var tints: Array[Color] = [
			Color(1.0, 0.95, 0.86),
			Color(1.0, 0.86, 0.20),
			Color(1.0, 0.67, 0.14),
			Color(1.0, 0.45, 0.08),
			Color(1.0, 0.18, 0.12),
			Color(1.0, 0.07, 0.28)
		]
		glyph_color = tints[rating]

	glyph_material.set_shader_parameter("glyph_id", debuff_data.get("glyph_id", 0))
	glyph_material.set_shader_parameter("glow_color", glyph_color)
	glyph_material.set_shader_parameter("glow_strength", debuff_data.get("glow_strength", 1.4))
	glyph_material.set_shader_parameter("rim_thickness", debuff_data.get("rim_thickness", 0.03))
	glyph_material.set_shader_parameter("line_thickness", debuff_data.get("line_thickness", 0.10))
	glyph_material.set_shader_parameter("bloom_softness", debuff_data.get("bloom_softness", 0.18))
	glyph_material.set_shader_parameter("wobble_strength", debuff_data.get("wobble_strength", 0.4))
	glyph_material.set_shader_parameter("roughness_strength", debuff_data.get("roughness_strength", 0.35))
	glyph_material.set_shader_parameter("glyph_scale", debuff_data.get("glyph_scale", 1.0))

	return icon


## setup(data)
##
## Builds and populates the panel UI from a data dictionary.
## Keys: channel (int), round_number (int), challenge_name (String),
## challenge_desc (String), debuffs (Array[Dictionary])
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
	
	## Shader backdrop behind all panel content (gradient, vignette, grain, sheen)
	_backdrop_fx_rect = _create_backdrop_fx_rect()
	_panel.resized.connect(_update_backdrop_fx_size)
	
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
	_title_label.text = "ROUND %s" % NumberFormatter.format_int(data.get("round_number", 1))
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(_title_label)
	
	## Separator
	vbox.add_child(HSeparator.new())
	
	## Channel row
	_channel_label = Label.new()
	_channel_label.text = "Mall Zone %s" % NumberFormatter.format_int(data.get("channel", 1))
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

			var icon := _create_glyph_icon(debuff_data)
			row.add_child(icon)

			var name_label = Label.new()
			name_label.text = debuff_data.get("name", "Debuff")
			name_label.add_theme_font_size_override("font_size", 13)
			name_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
			row.add_child(name_label)
			_debuffs_container.add_child(row)
	
	## Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND
	vbox.add_child(spacer)
	
	## Let's Play button
	_lets_play_button = GlassActionButtonClass.new()
	_lets_play_button.configure(
		"Let's Play",
		Vector2(180, 50),
		{
			"base_color": Color(0.2, 0.5, 0.2, 1.0),
			"mid_color": Color(0.25, 0.6, 0.25, 1.0),
			"accent_color": Color(0.3, 0.7, 0.3, 1.0),
			"glow_color": Color(0.4, 0.9, 0.4, 1.0),
			"rim_color": Color(0.9, 0.98, 0.9, 1.0),
			"font_color": Color(0.968627, 0.941176, 1.0, 1.0),
			"font_outline_color": Color(0.129412, 0.121569, 0.2, 1.0),
			"outline_size": 1
		},
		20
	)
	_lets_play_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	_lets_play_button.pressed.connect(_on_lets_play_pressed)
	vbox.add_child(_lets_play_button)



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
		push_error("[NewRoundPanel] Failed to load shader: " + BACKDROP_SHADER_PATH)
	_panel.add_child(fx_rect)
	_panel.move_child(fx_rect, 0)
	_backdrop_fx_rect = fx_rect
	_update_backdrop_fx_size()
	return fx_rect


## _update_backdrop_fx_size()
##
## Pushes the panel's current size into the backdrop shader so its rounded
## mask tracks layout. Connected to the panel's resized signal.
func _update_backdrop_fx_size() -> void:
	if _backdrop_fx_rect == null or _backdrop_fx_rect.material == null or _panel == null:
		return
	var panel_size := _panel.size
	if panel_size.x <= 0.0 or panel_size.y <= 0.0:
		panel_size = _panel.custom_minimum_size
	(_backdrop_fx_rect.material as ShaderMaterial).set_shader_parameter("rect_size", panel_size)
