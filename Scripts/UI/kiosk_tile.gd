extends Control
class_name KioskTile

## Background-free PowerUp tile: pill title, circular Foilsmith POG, rating sticker,
## and an always-visible sell action. Descriptions use hover or inline display.

signal sell_requested(power_up_id: String)
signal tile_clicked(power_up_id: String)
signal description_hovered(power_up_id: String)
signal description_unhovered(power_up_id: String)

const GlassButtonFactoryRef = preload("res://Scripts/UI/glass_button_factory.gd")
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const RARITY_GLOW_SHADER = preload("res://Scripts/Shaders/pog_rarity_glow.gdshader")
const SYNERGY_HALO_SHADER = preload("res://Scripts/Shaders/synergy_halo.gdshader")

const TILE_SIZE := Vector2(200, 300)
const TITLE_BAR_MIN_HEIGHT := 34.0
const TITLE_HORIZONTAL_PADDING := 4.0
const TITLE_FONT_SIZE_DEFAULT := 20
const TITLE_FONT_SIZE_MIN := 12
const TITLE_SAFE_MAX_CHARS := 24
const ACTION_BAR_MIN_HEIGHT := 52.0
const FOIL_CARD_SCALE := 0.96
const RARITY_GLOW_RADIUS_SCALE := 0.75
const RARITY_GLOW_OVERFLOW := 75.0
const SYNERGY_HALO_OVERFLOW := 22.0
const SYNERGY_RADIUS_EXTRA := 7.0

@export var data: PowerUpData
@export var hover_lift: float = 8.0
@export var hover_scale: float = 1.02
@export var glow_hover: float = 0.9
@export var glow_selected: float = 1.5

var title_pill: PanelContainer
var title_label: Label
var art_stage: Control
var artwork: TextureRect
var foilsmith_card: FoilsmithCard
var description_panel: PanelContainer
var description_label: Label
var sell_button
var sticker_badge: StickerBadge
var rarity_glow: ColorRect
var synergy_halo: ColorRect
var synergy_halo_mode: int = PowerUpData.SynergyHaloMode.NONE

var _rarity_glow_material: ShaderMaterial
var _synergy_halo_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _static_descriptions_enabled := false
var _description_text := ""
var _badge_scale := 1.0
var _hover_tween: Tween
var _base_position := Vector2.ZERO
var _resting_glow := 0.25
var _shader_time := 0.0


func _ready() -> void:
	_ensure_structure()
	_apply_static_style()
	_setup_shaders()
	if data:
		_apply_data()
	_connect_signals()
	art_stage.resized.connect(_update_art_geometry)
	call_deferred("_update_art_geometry")


func _exit_tree() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
		_hover_tween = null


func _ensure_structure() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	title_pill = get_node_or_null("InnerMargin/ContentVBox/TitlePill") as PanelContainer
	title_label = get_node_or_null("InnerMargin/ContentVBox/TitlePill/TitleLabel") as Label
	art_stage = get_node_or_null("InnerMargin/ContentVBox/ArtStage") as Control
	artwork = get_node_or_null("InnerMargin/ContentVBox/ArtStage/Artwork") as TextureRect
	foilsmith_card = get_node_or_null("InnerMargin/ContentVBox/ArtStage/FoilsmithCard") as FoilsmithCard
	description_panel = get_node_or_null("InnerMargin/ContentVBox/DescriptionPanel") as PanelContainer
	description_label = get_node_or_null("InnerMargin/ContentVBox/DescriptionPanel/DescriptionLabel") as Label
	sell_button = get_node_or_null("InnerMargin/ContentVBox/ActionBar/SellButton")
	rarity_glow = get_node_or_null("InnerMargin/ContentVBox/ArtStage/RarityGlow") as ColorRect
	synergy_halo = get_node_or_null("InnerMargin/ContentVBox/ArtStage/SynergyHalo") as ColorRect
	sticker_badge = get_node_or_null("InnerMargin/ContentVBox/ArtStage/StickerBadge") as StickerBadge
	if art_stage:
		art_stage.clip_contents = false
	if foilsmith_card:
		foilsmith_card.custom_minimum_size = Vector2.ZERO
		foilsmith_card.mouse_filter = Control.MOUSE_FILTER_PASS
		foilsmith_card.follow_mouse = true
		foilsmith_card.click_to_flip = false
		foilsmith_card.play_loop = false
		foilsmith_card.card_scale = FOIL_CARD_SCALE
		foilsmith_card.supersample = false
		foilsmith_card.visible = false


func _apply_static_style() -> void:
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.10, 0.08, 0.14, 0.68)
	title_style.set_corner_radius_all(17)
	title_style.corner_detail = 8
	title_style.content_margin_left = 12.0
	title_style.content_margin_right = 12.0
	title_pill.add_theme_stylebox_override("panel", title_style)
	if VCR_FONT:
		title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_DEFAULT)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.custom_minimum_size = Vector2(0.0, TITLE_BAR_MIN_HEIGHT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var description_style := StyleBoxFlat.new()
	description_style.bg_color = Color(0.10, 0.08, 0.14, 0.72)
	description_style.set_corner_radius_all(12)
	description_style.corner_detail = 8
	description_style.content_margin_left = 8.0
	description_style.content_margin_right = 8.0
	description_style.content_margin_top = 4.0
	description_style.content_margin_bottom = 4.0
	description_panel.add_theme_stylebox_override("panel", description_style)
	description_panel.visible = _static_descriptions_enabled
	if VCR_FONT:
		description_label.add_theme_font_override("font", VCR_FONT)
	description_label.add_theme_font_size_override("font_size", 11)
	description_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.94, 1.0))
	description_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	description_label.add_theme_constant_override("outline_size", 1)
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description_label.max_lines_visible = 3
	if sell_button is Button:
		sell_button = GlassButtonFactoryRef.replace_button(
			sell_button,
			GlassButtonFactoryRef.palette_kiosk_sell(),
			14,
			VCR_FONT,
			sell_button.text
		)
	if sell_button and sell_button.has_method("set_uniform_padding"):
		sell_button.custom_minimum_size = Vector2(124, 48)
		sell_button.set_uniform_padding(12, 6)
		sell_button.set_button_focus_mode(Control.FOCUS_NONE)


func _setup_shaders() -> void:
	_rarity_glow_material = ShaderMaterial.new()
	_rarity_glow_material.shader = RARITY_GLOW_SHADER
	_rarity_glow_material.set_shader_parameter("glow_intensity", _resting_glow)
	_rarity_glow_material.set_shader_parameter("glow_color", _get_rarity_neon_color())
	_rarity_glow_material.set_shader_parameter("spread", RARITY_GLOW_OVERFLOW)
	_rarity_glow_material.set_shader_parameter("inner_spread", 26.0)
	_rarity_glow_material.set_shader_parameter("inner_strength", 0.30)
	rarity_glow.material = _rarity_glow_material
	rarity_glow.color = Color.WHITE
	rarity_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_synergy_halo_material = ShaderMaterial.new()
	_synergy_halo_material.shader = SYNERGY_HALO_SHADER
	_synergy_halo_material.set_shader_parameter("spread", 12.0)
	synergy_halo.material = _synergy_halo_material
	synergy_halo.color = Color.WHITE
	synergy_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	synergy_halo.visible = false


func _connect_signals() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)
	if sell_button and not sell_button.pressed.is_connected(_on_sell_pressed):
		sell_button.pressed.connect(_on_sell_pressed)
	if sticker_badge:
		if not sticker_badge.mouse_entered.is_connected(_on_badge_mouse_entered):
			sticker_badge.mouse_entered.connect(_on_badge_mouse_entered)
		if not sticker_badge.mouse_exited.is_connected(_on_badge_mouse_exited):
			sticker_badge.mouse_exited.connect(_on_badge_mouse_exited)


func _apply_data() -> void:
	if not data:
		return
	var raw_name := data.display_name if data.display_name else "UNKNOWN"
	if raw_name.length() > TITLE_SAFE_MAX_CHARS:
		raw_name = raw_name.substr(0, TITLE_SAFE_MAX_CHARS - 1) + "…"
	title_label.text = raw_name.to_upper()
	call_deferred("_fit_title")
	if sticker_badge:
		sticker_badge.set_rating(data.rating)
		sticker_badge.set_rarity(data.rarity)
		sticker_badge.rotation = 0.0
	if sell_button:
		sell_button.text = "SELL\n$%d" % int(data.price / 2.0)
	artwork.texture = data.icon
	set_description_text(data.description)
	_apply_foilsmith_data()
	_update_neon_color()


func _apply_foilsmith_data() -> void:
	var has_bake := not data.foilsmith_card_json.is_empty() and FileAccess.file_exists(data.foilsmith_card_json)
	if not has_bake:
		foilsmith_card.visible = false
		artwork.visible = artwork.texture != null
		return
	foilsmith_card.card_json = data.foilsmith_card_json
	foilsmith_card.pixel_art = true
	foilsmith_card.native_size = Vector2(64, 64)
	foilsmith_card.pixel_hue_steps = 6
	foilsmith_card.set_finish_name("holo")
	foilsmith_card.foil = 0.65
	foilsmith_card.parallax = 0.012
	foilsmith_card.glint = 0.55
	foilsmith_card.sparkle = 0.35
	foilsmith_card.glare = 0.10
	foilsmith_card.relief = 0.65
	foilsmith_card.shadow = 0.20
	foilsmith_card.hue_drift = 0.35
	foilsmith_card.sparkle_seed = float(absi(data.id.hash()) % 10000)
	foilsmith_card.visible = foilsmith_card.art != null
	artwork.visible = not foilsmith_card.visible


func _fit_title() -> void:
	if not title_label:
		return
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_DEFAULT)
	await get_tree().process_frame
	var safe_width := title_label.size.x - TITLE_HORIZONTAL_PADDING * 2.0
	for font_size in range(TITLE_FONT_SIZE_DEFAULT, TITLE_FONT_SIZE_MIN - 1, -1):
		title_label.add_theme_font_size_override("font_size", font_size)
		await get_tree().process_frame
		var text_width := title_label.get_theme_font("font").get_string_size(
			title_label.text,
			title_label.horizontal_alignment,
			-1,
			font_size
		).x
		if text_width <= safe_width:
			break


func _get_rarity_neon_color() -> Color:
	if data:
		match data.rarity.to_lower():
			"common": return Color(0.92, 0.92, 0.95, 1.0)
			"uncommon": return Color(0.35, 0.95, 0.45, 1.0)
			"rare": return Color(0.35, 0.65, 1.0, 1.0)
			"epic": return Color(0.85, 0.35, 1.0, 1.0)
			"legendary": return Color(1.0, 0.65, 0.15, 1.0)
	return Color(0.9, 0.35, 0.6, 1.0)


func _update_neon_color() -> void:
	if _rarity_glow_material:
		_rarity_glow_material.set_shader_parameter("glow_color", _get_rarity_neon_color())


func _update_art_geometry() -> void:
	if not art_stage or not _rarity_glow_material or not _synergy_halo_material:
		return
	var radius := minf(art_stage.size.x, art_stage.size.y) * FOIL_CARD_SCALE * 0.5
	rarity_glow.offset_left = -RARITY_GLOW_OVERFLOW
	rarity_glow.offset_top = -RARITY_GLOW_OVERFLOW
	rarity_glow.offset_right = RARITY_GLOW_OVERFLOW
	rarity_glow.offset_bottom = RARITY_GLOW_OVERFLOW
	_rarity_glow_material.set_shader_parameter("rect_size", rarity_glow.size)
	_rarity_glow_material.set_shader_parameter("circle_radius", radius * RARITY_GLOW_RADIUS_SCALE)
	_synergy_halo_material.set_shader_parameter("rect_size", synergy_halo.size)
	_synergy_halo_material.set_shader_parameter("circle_radius", radius + SYNERGY_RADIUS_EXTRA)
	if sticker_badge:
		var rim_contact := art_stage.size * 0.5 + Vector2(radius, -radius) / sqrt(2.0)
		var badge_size := sticker_badge.size * sticker_badge.scale
		sticker_badge.position = rim_contact - Vector2(0.0, badge_size.y)


func set_data(new_data: PowerUpData) -> void:
	data = new_data
	if is_inside_tree():
		_apply_data()


func set_description_text(new_description: String) -> void:
	_description_text = new_description
	if description_label:
		description_label.text = _description_text


func set_static_descriptions_enabled(enabled: bool) -> void:
	_static_descriptions_enabled = enabled
	_badge_scale = 0.78 if enabled else 1.0
	if sticker_badge:
		sticker_badge.scale = Vector2.ONE * _badge_scale
	if not description_panel:
		return
	description_panel.visible = enabled
	if enabled and data:
		description_unhovered.emit(data.id)
	call_deferred("_update_art_geometry")


func set_selected(selected: bool) -> void:
	_is_selected = selected
	_animate_visual_state(0.25, _is_selected)


func set_synergy_halo(mode: int, color: Color = Color.WHITE) -> void:
	synergy_halo_mode = mode
	if not synergy_halo:
		return
	synergy_halo.visible = mode != PowerUpData.SynergyHaloMode.NONE
	if mode == PowerUpData.SynergyHaloMode.NONE:
		return
	_synergy_halo_material.set_shader_parameter("glow_color", color)
	_synergy_halo_material.set_shader_parameter("rainbow_mode", 1.0 if mode == PowerUpData.SynergyHaloMode.RAINBOW else 0.0)
	_synergy_halo_material.set_shader_parameter("glow_intensity", 1.2 if mode == PowerUpData.SynergyHaloMode.RAINBOW else 1.4)


func cycle_foil_debug_layer() -> int:
	if not foilsmith_card:
		return -1
	foilsmith_card.layer = (foilsmith_card.layer + 1) % 5
	return foilsmith_card.layer


func reset_foil_debug_layer() -> void:
	if foilsmith_card:
		foilsmith_card.layer = FoilsmithCard.Layer.SHADED


func _set_glow_intensity(value: float) -> void:
	if _rarity_glow_material:
		_rarity_glow_material.set_shader_parameter("glow_intensity", value)


func _set_glow_pulse(value: float) -> void:
	if _rarity_glow_material:
		_rarity_glow_material.set_shader_parameter("pulse_strength", value)


func _animate_visual_state(duration: float, pulse_badge: bool = false) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	var target_position := _base_position - Vector2(0.0, hover_lift) if _is_hovering else _base_position
	var target_scale := Vector2.ONE * hover_scale if _is_hovering else Vector2.ONE
	var target_rotation := deg_to_rad(1.35) if _is_selected else 0.0
	var target_glow := _resting_glow
	var target_pulse := 0.0
	if _is_selected:
		target_glow = glow_selected
		target_pulse = 0.45
	elif _is_hovering:
		target_glow = glow_hover
	if _is_hovering and _is_selected:
		target_pulse = 0.65
	var current_glow := _get_shader_float(_rarity_glow_material, "glow_intensity", _resting_glow)
	var current_pulse := _get_shader_float(_rarity_glow_material, "pulse_strength", 0.0)
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", target_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "rotation", target_rotation, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_glow_intensity, current_glow, target_glow, duration)
	_hover_tween.tween_method(_set_glow_pulse, current_pulse, target_pulse, duration)
	if pulse_badge and sticker_badge:
		var badge_base := Vector2.ONE * _badge_scale
		sticker_badge.scale = badge_base
		_hover_tween.tween_property(sticker_badge, "scale", badge_base * 1.08, minf(duration, 0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hover_tween.chain().tween_property(sticker_badge, "scale", badge_base, 0.1)


func _get_shader_float(shader_material: ShaderMaterial, parameter: String, fallback: float) -> float:
	if not shader_material:
		return fallback
	var value = shader_material.get_shader_parameter(parameter)
	if typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT:
		return float(value)
	return fallback


func _on_mouse_entered() -> void:
	_is_hovering = true
	_animate_visual_state(0.18, true)
	if sticker_badge:
		sticker_badge.set_pointer_global_position(get_global_mouse_position())
	var over_badge := sticker_badge and sticker_badge.get_global_rect().has_point(get_global_mouse_position())
	if not over_badge and not _static_descriptions_enabled and data:
		description_hovered.emit(data.id)


func _on_mouse_exited() -> void:
	_is_hovering = false
	_animate_visual_state(0.18)
	if sticker_badge:
		sticker_badge.clear_host_pointer()
	if data:
		description_unhovered.emit(data.id)


func _on_badge_mouse_entered() -> void:
	if data:
		description_unhovered.emit(data.id)


func _on_badge_mouse_exited() -> void:
	if _is_hovering and not _static_descriptions_enabled and data:
		description_hovered.emit(data.id)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if data:
				tile_clicked.emit(data.id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and sticker_badge:
		sticker_badge.set_pointer_global_position(get_global_mouse_position())


func _process(delta: float) -> void:
	_shader_time += delta
	if _rarity_glow_material:
		_rarity_glow_material.set_shader_parameter("time", _shader_time)
		_rarity_glow_material.set_shader_parameter("rect_size", rarity_glow.size)
	if _synergy_halo_material:
		_synergy_halo_material.set_shader_parameter("rect_size", synergy_halo.size)


func _on_sell_pressed() -> void:
	if data:
		sell_requested.emit(data.id)


func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos


func get_base_position() -> Vector2:
	return _base_position
