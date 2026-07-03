extends Control
class_name KioskTile

## KioskTile.gd
## Mall-core kiosk tile for displaying a power-up in the fan-out view.
## Glossy chrome background, neon rarity glow, artwork, description,
## always-visible SELL button, and a rating sticker badge.
##
## Title naming guidelines for designers:
##   - Ideal length: 12-16 characters
##   - Maximum before truncation: 20-22 characters
##   - The title label auto-shrinks down to a minimum size, then truncates with ellipsis.

signal sell_requested(power_up_id: String)
signal tile_clicked(power_up_id: String)

const TILE_SIZE := Vector2(200, 300)
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const STICKER_SCENE = preload("res://Scenes/UI/sticker_badge.tscn")
const SHADER = preload("res://Scripts/Shaders/kiosk_tile.gdshader")
const GLASS_SHADER = preload("res://Scripts/Shaders/kiosk_tile_glass.gdshader")
const GLOW_SHADER = preload("res://Scripts/Shaders/kiosk_tile_glow.gdshader")
const REFLECTION_SHADER = preload("res://Scripts/Shaders/kiosk_tile_reflection.gdshader")

const FRAME_OVERFLOW := 16.0
const GLOW_OVERFLOW := 14.0
const INTERIOR_INSET := 8.0
const CONTENT_MARGIN := 16
const CONTENT_SEPARATION := 8
const TITLE_BAR_MIN_HEIGHT := 38.0
const ART_PANEL_MIN_HEIGHT := 108.0
const DESCRIPTION_PANEL_MIN_HEIGHT := 72.0 #58
const ACTION_BAR_MIN_HEIGHT := 52.0
const DESCRIPTION_SAFE_MAX_CHARS := 150
const DESCRIPTION_MAX_LINES := 4
const GLASS_REST_STRENGTH := 0.18
const GLASS_SELECTED_STRENGTH := 0.44
const GLASS_HOVER_STRENGTH := 0.86
const GLASS_SELECTED_HOVER_STRENGTH := 1.0
const REFLECTION_SELECTED_OPACITY := 0.12
const REFLECTION_HOVER_OPACITY := 0.24
const REFLECTION_SELECTED_HOVER_OPACITY := 0.30

@export var data: PowerUpData
@export var hover_lift: float = 8.0
@export var hover_scale: float = 1.02
@export var glow_hover: float = 0.9
@export var glow_selected: float = 1.5

var chrome_frame: ColorRect
var interior_panel: ColorRect
var chrome_panel: PanelContainer
var title_label: Label
var title_bar: PanelContainer
var artwork: TextureRect
var reflection_overlay: TextureRect
var description_label: Label
var description_panel: PanelContainer
var sell_button: Button
var action_bar: HBoxContainer
var sticker_badge: StickerBadge
var glow_underlay: ColorRect

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")

var _frame_shader_material: ShaderMaterial
var _glass_shader_material: ShaderMaterial
var _glow_shader_material: ShaderMaterial
var _reflection_shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _hover_tween: Tween
var _base_position := Vector2.ZERO
var _resting_border_glow := 0.25
var _shader_time := 0.0

# Cached button style boxes for press depress tween.
var _normal_button_style: StyleBoxFlat
var _hover_button_style: StyleBoxFlat
var _pressed_button_style: StyleBoxFlat

# Artwork parallax state
var _mouse_norm := Vector2(0.5, 0.5)
var _artwork_rest_pos := Vector2.ZERO
var _reflection_rest_pos := Vector2.ZERO

# Title band constants
const TITLE_BAND_HEIGHT_RATIO := 0.15
const TITLE_HORIZONTAL_PADDING := 12.0
const TITLE_FONT_SIZE_DEFAULT := 20
const TITLE_FONT_SIZE_MIN := 12
const TITLE_SAFE_MAX_CHARS := 24

# Badge floats above the tile like a physical sticker, overlapping the chrome
# frame and the empty space above the artwork without covering the title.
const BADGE_OFFSET_LEFT := -40.0
const BADGE_OFFSET_TOP := -50.0
const BADGE_OFFSET_RIGHT := 30.0
const BADGE_OFFSET_BOTTOM := 20.0
const BADGE_Z_INDEX := 15

func _ready() -> void:
	_ensure_structure()
	_apply_static_style()
	_setup_shader()
	# _ready() runs before the parent (PowerUpIcon) has a chance to call set_data(),
	# so only apply data if it was already assigned (e.g. scene preloaded with data).
	if data:
		_apply_data()
	_connect_signals()
	call_deferred("_store_artwork_rest_positions")

func _ensure_structure() -> void:
	# Root owns hover/click detection for the entire tile.
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE

	# Render-order (back to front):
	# 1. GlowUnderlay (additive bloom behind everything)
	# 2. ChromeFrame (outer chrome bezel)
	# 3. ChromeBackground (inner glossy panel)
	# 4. ChromePanel (content)
	# 5. StickerBadge (top-right)

	glow_underlay = get_node_or_null("GlowUnderlay") as ColorRect
	if not glow_underlay:
		glow_underlay = ColorRect.new()
		glow_underlay.name = "GlowUnderlay"
		glow_underlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_underlay.set_offsets_preset(Control.PRESET_FULL_RECT)
		glow_underlay.offset_left = -GLOW_OVERFLOW
		glow_underlay.offset_top = -GLOW_OVERFLOW
		glow_underlay.offset_right = GLOW_OVERFLOW
		glow_underlay.offset_bottom = GLOW_OVERFLOW
		glow_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow_underlay)
	glow_underlay.color = Color(1.0, 1.0, 1.0, 1.0)

	chrome_frame = get_node_or_null("ChromeFrame") as ColorRect
	if not chrome_frame:
		chrome_frame = ColorRect.new()
		chrome_frame.name = "ChromeFrame"
		chrome_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_frame.set_offsets_preset(Control.PRESET_FULL_RECT)
		chrome_frame.offset_left = -FRAME_OVERFLOW
		chrome_frame.offset_top = -FRAME_OVERFLOW
		chrome_frame.offset_right = FRAME_OVERFLOW
		chrome_frame.offset_bottom = FRAME_OVERFLOW
		chrome_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chrome_frame)
		print("[KioskTile] ChromeFrame created and added to node tree.")

	interior_panel = get_node_or_null("InteriorPanel") as ColorRect
	if not interior_panel:
		interior_panel = get_node_or_null("ChromeBackground") as ColorRect
		if interior_panel:
			interior_panel.name = "InteriorPanel"
	if not interior_panel:
		interior_panel = ColorRect.new()
		interior_panel.name = "InteriorPanel"
		add_child(interior_panel)
	interior_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	interior_panel.set_offsets_preset(Control.PRESET_FULL_RECT)
	interior_panel.offset_left = INTERIOR_INSET
	interior_panel.offset_top = INTERIOR_INSET
	interior_panel.offset_right = -INTERIOR_INSET
	interior_panel.offset_bottom = -INTERIOR_INSET
	interior_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	chrome_panel = get_node_or_null("ChromePanel") as PanelContainer
	if not chrome_panel:
		chrome_panel = PanelContainer.new()
		chrome_panel.name = "ChromePanel"
		chrome_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_panel.set_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(chrome_panel)
	chrome_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hit_area := get_node_or_null("HitArea") as ColorRect
	if not hit_area:
		hit_area = ColorRect.new()
		hit_area.name = "HitArea"
		hit_area.set_anchors_preset(Control.PRESET_FULL_RECT)
		hit_area.set_offsets_preset(Control.PRESET_FULL_RECT)
		hit_area.color = Color(0.0, 0.0, 0.0, 0.0)
		hit_area.mouse_filter = Control.MOUSE_FILTER_STOP
		hit_area.z_index = 100
		add_child(hit_area)
		move_child(hit_area, 0)

	var inner_margin := chrome_panel.get_node_or_null("InnerMargin") as MarginContainer
	if not inner_margin:
		inner_margin = MarginContainer.new()
		inner_margin.name = "InnerMargin"
		inner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner_margin.set_offsets_preset(Control.PRESET_FULL_RECT)
		inner_margin.add_theme_constant_override("margin_left", CONTENT_MARGIN)
		inner_margin.add_theme_constant_override("margin_top", CONTENT_MARGIN)
		inner_margin.add_theme_constant_override("margin_right", CONTENT_MARGIN)
		inner_margin.add_theme_constant_override("margin_bottom", CONTENT_MARGIN)
		chrome_panel.add_child(inner_margin)

	var content_vbox := inner_margin.get_node_or_null("ContentVBox") as VBoxContainer
	if not content_vbox:
		content_vbox = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_theme_constant_override("separation", CONTENT_SEPARATION)
		inner_margin.add_child(content_vbox)

	title_bar = content_vbox.get_node_or_null("TitleBar") as PanelContainer
	if not title_bar:
		title_bar = PanelContainer.new()
		title_bar.name = "TitleBar"
		title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(title_bar)
	else:
		title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	title_label = title_bar.get_node_or_null("TitleLabel") as Label
	if not title_label:
		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.clip_text = true
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_bar.add_child(title_label)
	else:
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var art_panel := content_vbox.get_node_or_null("ArtPanel") as PanelContainer
	if not art_panel:
		art_panel = PanelContainer.new()
		art_panel.name = "ArtPanel"
		art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		art_panel.custom_minimum_size = Vector2(0, ART_PANEL_MIN_HEIGHT)
		art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(art_panel)
	else:
		art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_panel.clip_contents = true

	artwork = art_panel.get_node_or_null("Artwork") as TextureRect
	if not artwork:
		artwork = TextureRect.new()
		artwork.name = "Artwork"
		artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
		artwork.set_offsets_preset(Control.PRESET_FULL_RECT)
		artwork.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_panel.add_child(artwork)

	reflection_overlay = art_panel.get_node_or_null("ReflectionOverlay") as TextureRect
	if not reflection_overlay:
		reflection_overlay = TextureRect.new()
		reflection_overlay.name = "ReflectionOverlay"
		reflection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		reflection_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
		reflection_overlay.modulate = Color(1, 1, 1, 1.0)
		art_panel.add_child(reflection_overlay)

	var transparent_art := StyleBoxFlat.new()
	transparent_art.bg_color = Color(0, 0, 0, 0)
	transparent_art.draw_center = false
	transparent_art.set_border_width_all(0)
	art_panel.add_theme_stylebox_override("panel", transparent_art)

	if artwork:
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.modulate = Color.WHITE
	if reflection_overlay:
		reflection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		reflection_overlay.visible = true

	description_panel = content_vbox.get_node_or_null("DescriptionPanel") as PanelContainer
	if not description_panel:
		description_panel = PanelContainer.new()
		description_panel.name = "DescriptionPanel"
		description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		description_panel.custom_minimum_size = Vector2(0, DESCRIPTION_PANEL_MIN_HEIGHT)
		description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(description_panel)
	else:
		description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_panel.custom_minimum_size = Vector2(0, DESCRIPTION_PANEL_MIN_HEIGHT)
	description_panel.clip_contents = true

	description_label = description_panel.get_node_or_null("DescriptionLabel") as Label
	if not description_label:
		description_label = Label.new()
		description_label.name = "DescriptionLabel"
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.clip_text = true
		description_label.max_lines_visible = DESCRIPTION_MAX_LINES
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_label.size_flags_vertical = Control.SIZE_FILL
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_panel.add_child(description_label)
	else:
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		description_label.clip_text = true
		description_label.max_lines_visible = DESCRIPTION_MAX_LINES
		description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	action_bar = content_vbox.get_node_or_null("ActionBar") as HBoxContainer
	if not action_bar:
		action_bar = HBoxContainer.new()
		action_bar.name = "ActionBar"
		action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		action_bar.custom_minimum_size = Vector2(0, ACTION_BAR_MIN_HEIGHT)
		action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(action_bar)
	else:
		action_bar.custom_minimum_size = Vector2(0, ACTION_BAR_MIN_HEIGHT)
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	sell_button = action_bar.get_node_or_null("SellButton") as Button
	if not sell_button:
		sell_button = Button.new()
		sell_button.name = "SellButton"
		sell_button.text = "SELL\n$0"
		sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sell_button.mouse_filter = Control.MOUSE_FILTER_PASS
		action_bar.add_child(sell_button)
	else:
		sell_button.mouse_filter = Control.MOUSE_FILTER_PASS

	sticker_badge = get_node_or_null("StickerBadge") as StickerBadge
	if not sticker_badge:
		sticker_badge = STICKER_SCENE.instantiate()
		sticker_badge.name = "StickerBadge"
		sticker_badge.rotation = deg_to_rad(randf_range(-4.0, 4.0))
		add_child(sticker_badge)

	if sticker_badge:
		sticker_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.set_offsets_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.offset_left = BADGE_OFFSET_LEFT
		sticker_badge.offset_top = BADGE_OFFSET_TOP
		sticker_badge.offset_right = BADGE_OFFSET_RIGHT
		sticker_badge.offset_bottom = BADGE_OFFSET_BOTTOM
		sticker_badge.z_index = BADGE_Z_INDEX
		sticker_badge.mouse_filter = Control.MOUSE_FILTER_PASS

func _find_first_node(root: Node, node_name: String) -> Node:
	if root.name == node_name:
		return root
	for child in root.get_children():
		var found := _find_first_node(child, node_name)
		if found:
			return found
	return null

func _apply_static_style() -> void:
	# Make ChromePanel transparent so the shader background shows through
	var transparent_panel := StyleBoxFlat.new()
	transparent_panel.bg_color = Color(0, 0, 0, 0)
	transparent_panel.draw_center = false
	transparent_panel.set_border_width_all(0)
	chrome_panel.add_theme_stylebox_override("panel", transparent_panel)

	# Give the artwork panel a faint framed pocket so the glass interior reads as layered.
	var art_parent := artwork.get_parent() as PanelContainer
	if art_parent:
		var art_style := StyleBoxFlat.new()
		art_style.bg_color = Color(0.04, 0.06, 0.1, 0.0)
		art_style.border_color = Color(0.84, 0.92, 1.0, 0.0)
		art_style.set_border_width_all(1)
		art_style.set_corner_radius_all(12)
		art_style.corner_detail = 6
		art_style.content_margin_left = 8.0
		art_style.content_margin_top = 8.0
		art_style.content_margin_right = 8.0
		art_style.content_margin_bottom = 8.0
		art_parent.add_theme_stylebox_override("panel", art_style)

	# Title styling: mall-core neon pink, bold VCR, dark outline
	if VCR_FONT:
		title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.25, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_label.add_theme_constant_override("outline_size", 2)
	# Single-line with ellipsis fallback; autowrap disabled so text never wraps
	# into the artwork area. The font size is dynamically adjusted in _fit_title().
	title_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	title_label.custom_minimum_size = Vector2(0, TITLE_BAR_MIN_HEIGHT - 4.0)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	title_bar.custom_minimum_size = Vector2(0, TITLE_BAR_MIN_HEIGHT)
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.12, 0.09, 0.16, 0.96)
	title_style.border_color = Color(0.95, 0.82, 0.35, 0.48)
	title_style.set_border_width_all(2)
	title_style.set_corner_radius_all(10)
	title_style.corner_detail = 6
	title_style.content_margin_left = TITLE_HORIZONTAL_PADDING
	title_style.content_margin_top = 6.0
	title_style.content_margin_right = TITLE_HORIZONTAL_PADDING
	title_style.content_margin_bottom = 6.0
	title_bar.add_theme_stylebox_override("panel", title_style)

	# Description styling: readable at fan-out size and visually separated from art/button.
	if VCR_FONT:
		description_label.add_theme_font_override("font", VCR_FONT)
	description_label.add_theme_font_size_override("font_size", 13)
	description_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description_label.add_theme_constant_override("outline_size", 1)

	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = Color(0.05, 0.07, 0.11, 0.88)
	desc_style.border_color = Color(0.86, 0.93, 1.0, 0.0)
	desc_style.set_border_width_all(1)
	desc_style.set_corner_radius_all(10)
	desc_style.corner_detail = 6
	desc_style.content_margin_left = 10.0
	desc_style.content_margin_top = 8.0
	desc_style.content_margin_right = 10.0
	desc_style.content_margin_bottom = 8.0
	description_panel.add_theme_stylebox_override("panel", desc_style)

	# SELL button: glossy neon checkout-key styling
	if VCR_FONT:
		sell_button.add_theme_font_override("font", VCR_FONT)
	sell_button.add_theme_font_size_override("font_size", 14)
	sell_button.add_theme_color_override("font_color", Color(1.0, 1.0, 0.9, 1.0))
	sell_button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
	sell_button.add_theme_color_override("font_pressed_color", Color(0.95, 0.95, 0.8, 1.0))
	sell_button.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	sell_button.add_theme_constant_override("outline_size", 1)

	sell_button.custom_minimum_size = Vector2(124, 48)
	action_bar.alignment = BoxContainer.ALIGNMENT_CENTER

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.85, 0.25, 0.55, 0.95)
	normal.border_color = Color(1.0, 0.55, 0.75, 1.0)
	normal.set_border_width_all(3)
	normal.set_corner_radius_all(6)
	normal.corner_detail = 6
	normal.content_margin_left = 12.0
	normal.content_margin_top = 6.0
	normal.content_margin_right = 12.0
	normal.content_margin_bottom = 6.0
	_normal_button_style = normal

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.95, 0.35, 0.65, 0.98)
	hover.border_color = Color(1.0, 0.75, 0.85, 1.0)
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(6)
	hover.corner_detail = 6
	hover.content_margin_left = 12.0
	hover.content_margin_top = 6.0
	hover.content_margin_right = 12.0
	hover.content_margin_bottom = 6.0
	_hover_button_style = hover

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color(0.65, 0.15, 0.4, 1.0)
	pressed.border_color = Color(0.85, 0.45, 0.65, 1.0)
	pressed.set_border_width_all(3)
	pressed.set_corner_radius_all(6)
	pressed.corner_detail = 6
	pressed.content_margin_left = 12.0
	pressed.content_margin_top = 8.0
	pressed.content_margin_right = 12.0
	pressed.content_margin_bottom = 4.0
	_pressed_button_style = pressed

	sell_button.add_theme_stylebox_override("normal", normal)
	sell_button.add_theme_stylebox_override("hover", hover)
	sell_button.add_theme_stylebox_override("pressed", pressed)
	sell_button.add_theme_stylebox_override("disabled", pressed)

func _apply_data() -> void:
	if not data:
		return

	if artwork:
		if data.icon:
			artwork.texture = data.icon
			artwork.modulate = Color.WHITE
			artwork.visible = true
		else:
			artwork.texture = load("res://icon.svg")
			artwork.visible = true

	if reflection_overlay:
		reflection_overlay.visible = true
		_update_reflection_source()

	if title_label:
		var raw_name := data.display_name if data.display_name else "UNKNOWN"
		# Enforce a hard cap so designers get predictable truncation behavior.
		if raw_name.length() > TITLE_SAFE_MAX_CHARS:
			raw_name = raw_name.substr(0, TITLE_SAFE_MAX_CHARS - 1) + "…"
		title_label.text = raw_name.to_upper()
		call_deferred("_fit_title")
	if description_label:
		description_label.text = _format_description_text(data.description if data.description else "No description")
	if sticker_badge:
		sticker_badge.set_rating(data.rating)
		sticker_badge.set_rarity(data.rarity)
		sticker_badge.rotation = deg_to_rad(randf_range(-4.0, 4.0))
	if _frame_shader_material:
		_update_neon_color()
	if description_panel:
		description_panel.reset_size()

	if sell_button:
		var sell_value := int(data.price / 2.0)
		sell_button.text = "SELL\n$%d" % sell_value

## _fit_title()
##
## Shrinks the title font down to TITLE_FONT_SIZE_MIN to keep the text on one
## line inside the safe title band. If it still overflows, clip_text/ellipsis
## take over automatically.
func _fit_title() -> void:
	if not title_label:
		return
	title_label.add_theme_font_size_override("font_size", TITLE_FONT_SIZE_DEFAULT)
	await get_tree().process_frame
	var safe_width := title_bar.size.x - (TITLE_HORIZONTAL_PADDING * 2.0)
	if safe_width <= 0:
		safe_width = TILE_SIZE.x - (CONTENT_MARGIN * 2.0) - (TITLE_HORIZONTAL_PADDING * 2.0)
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

func _print_node_hierarchy() -> void:
	var label := ""
	if data:
		label = data.id
	else:
		label = name
	print("[KioskTile] Node tree for", label)
	for child in get_children():
		print("  root child:", child.name, "visible=", child.visible, "modulate=", child.modulate, "z_index=", child.z_index)
		if child is Control:
			print("    rect=", child.get_rect(), "size=", child.size)
		for sub in child.get_children():
			print("    sub:", sub.name, "visible=", sub.visible, "modulate=", sub.modulate, "z_index=", sub.z_index)
			if sub is Control:
				print("      rect=", sub.get_rect(), "size=", sub.size)

func _print_texture_rect_state(prefix: String, rect: TextureRect) -> void:
	print(prefix, " name=", rect.name, " visible=", rect.visible, " modulate=", rect.modulate)
	print(prefix, " rect=", rect.get_rect(), " size=", rect.size, " global_position=", rect.global_position)
	print(prefix, " texture=", rect.texture, " resource_path=", rect.texture.resource_path if rect.texture else "null")
	if rect.texture is AtlasTexture:
		var atlas := rect.texture as AtlasTexture
		print(prefix, " atlas.atlas=", atlas.atlas, " region=", atlas.region)
	print(prefix, " expand_mode=", rect.expand_mode, " stretch_mode=", rect.stretch_mode)
	var parent_panel := rect.get_parent() as PanelContainer
	if parent_panel:
		var style := parent_panel.get_theme_stylebox("panel") as StyleBoxFlat
		print(prefix, " parent=", parent_panel.name, " parent.panel stylebox=", style)
		if style:
			print(prefix, " style.bg_color=", style.bg_color, " draw_center=", style.draw_center)

func _dump_all_textures(root: Node, indent: String = "") -> void:
	for child in root.get_children():
		if child is TextureRect:
			var tex_rect := child as TextureRect
			print(indent, "TextureRect: ", tex_rect.name, " visible=", tex_rect.visible, " modulate=", tex_rect.modulate, " texture=", tex_rect.texture.resource_path if tex_rect.texture else "null")
			if tex_rect.texture is AtlasTexture:
				var atlas := tex_rect.texture as AtlasTexture
				print(indent, "  atlas=", atlas.atlas.resource_path if atlas.atlas else "null", " region=", atlas.region)
		_dump_all_textures(child, indent + "  ")

func _dump_panel_styleboxes(root: Node, indent: String = "") -> void:
	for child in root.get_children():
		if child is PanelContainer:
			var panel := child as PanelContainer
			var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
			print(indent, "PanelContainer: ", panel.name, " size=", panel.size, " rect=", panel.get_rect())
			if style:
				print(indent, "  stylebox bg_color=", style.bg_color, " draw_center=", style.draw_center, " border_width=", style.get_border_width(Side.SIDE_TOP))
			else:
				print(indent, "  stylebox=null")
		_dump_panel_styleboxes(child, indent + "  ")

func _debug_log_visual_state() -> void:
	var label: String = data.id if data else String(name)
	var lines: Array[String] = []
	lines.append("[KioskTile] === visual state for " + label + " ===")
	lines.append(_format_control("GlowUnderlay", glow_underlay))
	lines.append(_format_control("ChromeFrame", chrome_frame))
	lines.append(_format_control("InteriorPanel", interior_panel))
	lines.append(_format_control("ChromePanel", chrome_panel))
	lines.append("[KioskTile] root size=" + str(size) + " global_position=" + str(global_position) + " visible=" + str(visible) + " modulate=" + str(modulate))
	lines.append("[KioskTile] child count=" + str(get_child_count()))
	for child in get_children():
		lines.append("[KioskTile] child: " + child.name + " visible=" + str(child.visible) + " modulate=" + str(child.modulate) + " z_index=" + str(child.z_index))
		if child is Control:
			lines.append("[KioskTile]   rect=" + str(child.get_rect()) + " size=" + str(child.size))
	lines.append("[KioskTile] === end ===")
	var text := "\n".join(lines)
	print(text)

func _format_control(tag: String, node: Control) -> String:
	if not node:
		return "[KioskTile] " + tag + " is NULL"
	var mat := node.material as ShaderMaterial
	var shader_path := ""
	if mat and mat.shader:
		shader_path = mat.shader.resource_path
	var line := "[KioskTile] " + tag + " visible=" + str(node.visible) + " self_modulate=" + str(node.self_modulate) + " modulate=" + str(node.modulate) + " size=" + str(node.size) + " global_position=" + str(node.global_position) + " material=" + str(mat != null) + " shader=" + shader_path
	if node is ColorRect:
		var rect := node as ColorRect
		line += " color=" + str(rect.color)
	if node is PanelContainer:
		var panel := node as PanelContainer
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		if style:
			line += " stylebox bg_color=" + str(style.bg_color) + " draw_center=" + str(style.draw_center) + " border_width=" + str(style.get_border_width(Side.SIDE_TOP))
		else:
			line += " stylebox=null"
	return line

func _connect_signals() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
		sell_button.button_down.connect(_on_sell_button_down)
		sell_button.button_up.connect(_on_sell_button_up)
		# The tile root handles hover, but the button still needs hover audio.
		if _tfx:
			sell_button.mouse_entered.connect(func(): _tfx.button_hover(sell_button))
			sell_button.mouse_exited.connect(func(): _tfx.button_unhover(sell_button))
			sell_button.pressed.connect(func(): _tfx.button_press(sell_button))

func _setup_shader() -> void:
	var frame_size := TILE_SIZE + Vector2(FRAME_OVERFLOW * 2.0, FRAME_OVERFLOW * 2.0)
	var glass_size := TILE_SIZE - Vector2(INTERIOR_INSET * 2.0, INTERIOR_INSET * 2.0)
	var glow_size := TILE_SIZE + Vector2(GLOW_OVERFLOW * 2.0, GLOW_OVERFLOW * 2.0)

	# Outer chrome frame shader (draws the thick bezel)
	_frame_shader_material = ShaderMaterial.new()
	_frame_shader_material.shader = SHADER
	_frame_shader_material.set_shader_parameter("border_glow", _resting_border_glow)
	_frame_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())
	_frame_shader_material.set_shader_parameter("chrome_tint", Color(0.30, 0.31, 0.34, 0.98))
	_frame_shader_material.set_shader_parameter("highlight_tint", Color(0.92, 0.95, 1.0, 1.0))
	_frame_shader_material.set_shader_parameter("shadow_tint", Color(0.05, 0.04, 0.08, 1.0))
	_frame_shader_material.set_shader_parameter("env_tint_a", Color(0.28, 0.56, 0.78, 1.0))
	_frame_shader_material.set_shader_parameter("env_tint_b", Color(0.93, 0.42, 0.72, 1.0))
	_frame_shader_material.set_shader_parameter("reflection_amount", 0.90)
	_frame_shader_material.set_shader_parameter("corner_radius", 36.0) #26.0
	_frame_shader_material.set_shader_parameter("bezel_width", 12.0)
	_frame_shader_material.set_shader_parameter("inner_lip_width", 2.6)
	_frame_shader_material.set_shader_parameter("draw_outer_bezel", true)
	_frame_shader_material.set_shader_parameter("rect_size", frame_size)
	chrome_frame.material = _frame_shader_material

	# Dedicated interior glass shader derived from the roll button glass patterns.
	_glass_shader_material = ShaderMaterial.new()
	_glass_shader_material.shader = GLASS_SHADER
	_glass_shader_material.set_shader_parameter("rect_size", glass_size)
	_glass_shader_material.set_shader_parameter("corner_radius", 18.0)
	_glass_shader_material.set_shader_parameter("mouse_uv", Vector2(0.5, 0.35))
	_glass_shader_material.set_shader_parameter("parallax_offset", Vector2.ZERO)
	_glass_shader_material.set_shader_parameter("hover_strength", GLASS_REST_STRENGTH)
	_glass_shader_material.set_shader_parameter("motion_strength", 0.0)
	_glass_shader_material.set_shader_parameter("pulse_strength", 0.0)
	_glass_shader_material.set_shader_parameter("rim_strength", 0.76)
	_glass_shader_material.set_shader_parameter("grain_strength", 0.07)
	_glass_shader_material.set_shader_parameter("base_color", Color(0.08, 0.12, 0.18, 0.98))
	_glass_shader_material.set_shader_parameter("mid_color", Color(0.15, 0.20, 0.27, 0.98))
	_glass_shader_material.set_shader_parameter("accent_color", Color(0.14, 0.41, 0.44, 0.90))
	_glass_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())
	_glass_shader_material.set_shader_parameter("specular_color", Color(0.96, 0.98, 1.0, 1.0))
	interior_panel.material = _glass_shader_material

	# Additive glow underlay shader
	_glow_shader_material = ShaderMaterial.new()
	_glow_shader_material.shader = GLOW_SHADER
	_glow_shader_material.set_shader_parameter("glow_intensity", _resting_border_glow)
	_glow_shader_material.set_shader_parameter("glow_color", _get_rarity_neon_color())
	_glow_shader_material.set_shader_parameter("corner_radius", 28.0)
	_glow_shader_material.set_shader_parameter("spread", 20.0)
	_glow_shader_material.set_shader_parameter("pulse_strength", 0.0)
	_glow_shader_material.set_shader_parameter("rect_size", glow_size)
	glow_underlay.material = _glow_shader_material
	glow_underlay.use_parent_material = false

	# Reflection overlay shader
	_reflection_shader_material = ShaderMaterial.new()
	_reflection_shader_material.shader = REFLECTION_SHADER
	_reflection_shader_material.set_shader_parameter("use_artwork_texture", false)
	_reflection_shader_material.set_shader_parameter("tint_color", Color(0.96, 0.98, 1.0, 1.0))
	_reflection_shader_material.set_shader_parameter("sheen_color", Color(0.96, 0.98, 1.0, 1.0))
	_reflection_shader_material.set_shader_parameter("opacity", 0.0)
	_reflection_shader_material.set_shader_parameter("scanline_opacity", 0.06)
	_reflection_shader_material.set_shader_parameter("sweep_strength", 0.40)
	_reflection_shader_material.set_shader_parameter("texture_strength", 0.72)
	_reflection_shader_material.set_shader_parameter("offset", Vector2.ZERO)
	reflection_overlay.material = _reflection_shader_material
	_update_reflection_source()

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
	var color := _get_rarity_neon_color()
	if _frame_shader_material:
		_frame_shader_material.set_shader_parameter("neon_color", color)
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("neon_color", color)
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("glow_color", color)
	if _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("tint_color", color.lerp(Color(0.98, 0.99, 1.0, 1.0), 0.60))

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	_apply_data()
	_update_neon_color()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	_animate_visual_state(0.25, _is_selected)

func _set_border_glow(value: float) -> void:
	if _frame_shader_material:
		_frame_shader_material.set_shader_parameter("border_glow", value)

func _set_glow_intensity(value: float) -> void:
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("glow_intensity", value)

func _set_glow_pulse(value: float) -> void:
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("pulse_strength", value)

func _set_glass_hover(value: float) -> void:
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("hover_strength", value)

func _set_glass_motion(value: float) -> void:
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("motion_strength", value)

func _set_glass_pulse(value: float) -> void:
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("pulse_strength", value)

func _set_reflection_opacity(value: float) -> void:
	if _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("opacity", value)

func _get_shader_float(shader_material: ShaderMaterial, parameter: String, fallback: float) -> float:
	if not shader_material:
		return fallback
	var value = shader_material.get_shader_parameter(parameter)
	if typeof(value) == TYPE_FLOAT:
		return value
	if typeof(value) == TYPE_INT:
		return float(value)
	return fallback

func _update_reflection_source() -> void:
	if not _reflection_shader_material:
		return
	var has_texture := artwork and artwork.texture != null
	_reflection_shader_material.set_shader_parameter("use_artwork_texture", has_texture)
	if has_texture:
		_reflection_shader_material.set_shader_parameter("artwork_texture", artwork.texture)

func _format_description_text(raw_text: String) -> String:
	var normalized := raw_text.strip_edges()
	if normalized.is_empty():
		return "No description"
	if normalized.length() > DESCRIPTION_SAFE_MAX_CHARS:
		normalized = normalized.substr(0, DESCRIPTION_SAFE_MAX_CHARS - 1).rstrip(" ,.;:") + "..."
	return normalized

func _update_shader_mouse_state(normalized_offset: Vector2) -> void:
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("mouse_uv", _mouse_norm)
		_glass_shader_material.set_shader_parameter("parallax_offset", normalized_offset)
	if _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("offset", normalized_offset * 5.0)

func _animate_visual_state(duration: float, pulse_badge: bool = false) -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var target_position := _base_position - Vector2(0, hover_lift) if _is_hovering else _base_position
	var target_scale := Vector2.ONE * hover_scale if _is_hovering else Vector2.ONE
	var target_rotation := deg_to_rad(1.35) if _is_selected else 0.0
	var target_frame_glow := _resting_border_glow
	var target_glow_intensity := _resting_border_glow
	var target_glass_hover := GLASS_REST_STRENGTH
	var target_glass_pulse := 0.0
	var target_reflection_opacity := 0.0

	if _is_selected:
		target_frame_glow = glow_selected
		target_glow_intensity = glow_selected
		target_glass_hover = GLASS_SELECTED_STRENGTH
		target_glass_pulse = 0.45
		target_reflection_opacity = REFLECTION_SELECTED_OPACITY
	elif _is_hovering:
		target_frame_glow = glow_hover
		target_glow_intensity = glow_hover

	if _is_hovering and _is_selected:
		target_glass_hover = GLASS_SELECTED_HOVER_STRENGTH
		target_glass_pulse = 0.65
		target_reflection_opacity = REFLECTION_SELECTED_HOVER_OPACITY
	elif _is_hovering:
		target_glass_hover = GLASS_HOVER_STRENGTH
		target_reflection_opacity = REFLECTION_HOVER_OPACITY

	var current_frame_glow := _get_shader_float(_frame_shader_material, "border_glow", _resting_border_glow)
	var current_glow_intensity := _get_shader_float(_glow_shader_material, "glow_intensity", _resting_border_glow)
	var current_glass_hover := _get_shader_float(_glass_shader_material, "hover_strength", GLASS_REST_STRENGTH)
	var current_glass_pulse := _get_shader_float(_glass_shader_material, "pulse_strength", 0.0)
	var current_reflection_opacity := _get_shader_float(_reflection_shader_material, "opacity", 0.0)
	var current_glow_pulse := _get_shader_float(_glow_shader_material, "pulse_strength", 0.0)

	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", target_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "rotation", target_rotation, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_method(_set_border_glow, current_frame_glow, target_frame_glow, duration)
	_hover_tween.tween_method(_set_glow_intensity, current_glow_intensity, target_glow_intensity, duration)
	_hover_tween.tween_method(_set_glow_pulse, current_glow_pulse, target_glass_pulse, duration)
	_hover_tween.tween_method(_set_glass_hover, current_glass_hover, target_glass_hover, duration)
	_hover_tween.tween_method(_set_glass_pulse, current_glass_pulse, target_glass_pulse, duration)
	_hover_tween.tween_method(_set_reflection_opacity, current_reflection_opacity, target_reflection_opacity, duration)

	if _is_hovering:
		_update_artwork_parallax()
	else:
		_mouse_norm = Vector2(0.5, 0.5)
		_set_glass_motion(0.0)
		_update_shader_mouse_state(Vector2.ZERO)
		if artwork:
			_hover_tween.tween_property(artwork, "position", _artwork_rest_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if reflection_overlay:
			_hover_tween.tween_property(reflection_overlay, "position", _reflection_rest_pos, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	if pulse_badge and sticker_badge:
		sticker_badge.scale = Vector2.ONE
		_hover_tween.tween_property(sticker_badge, "scale", Vector2.ONE * 1.08, min(duration, 0.12)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hover_tween.chain().tween_property(sticker_badge, "scale", Vector2.ONE, 0.1)

func _on_mouse_entered() -> void:
	_is_hovering = true
	_animate_visual_state(0.18, true)
	if sticker_badge:
		sticker_badge.set_pointer_global_position(get_global_mouse_position())

func _on_mouse_exited() -> void:
	_is_hovering = false
	_animate_visual_state(0.18)
	if sticker_badge:
		sticker_badge.clear_host_pointer()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if data:
				emit_signal("tile_clicked", data.id)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_mouse_norm = event.position / size
		_mouse_norm.x = clampf(_mouse_norm.x, 0.0, 1.0)
		_mouse_norm.y = clampf(_mouse_norm.y, 0.0, 1.0)
		if sticker_badge:
			sticker_badge.set_pointer_global_position(get_global_mouse_position())
		if _is_hovering:
			_update_artwork_parallax()

func _update_artwork_parallax() -> void:
	if not artwork:
		return
	var normalized_offset := _mouse_norm - Vector2(0.5, 0.5)
	var offset := normalized_offset * -3.5
	artwork.position = _artwork_rest_pos + offset
	if reflection_overlay:
		reflection_overlay.position = _reflection_rest_pos + offset * 0.65 + Vector2(2.0, 3.0)
	_set_glass_motion(clampf(normalized_offset.length() * 2.2, 0.0, 1.0))
	_update_shader_mouse_state(normalized_offset)

func _store_artwork_rest_positions() -> void:
	if artwork:
		_artwork_rest_pos = artwork.position
	if reflection_overlay:
		_reflection_rest_pos = reflection_overlay.position

func _process(delta: float) -> void:
	_shader_time += delta
	if _frame_shader_material:
		_frame_shader_material.set_shader_parameter("rect_size", chrome_frame.get_global_rect().size)
		_frame_shader_material.set_shader_parameter("time", _shader_time)
	if _glass_shader_material:
		_glass_shader_material.set_shader_parameter("rect_size", interior_panel.get_global_rect().size)
		_glass_shader_material.set_shader_parameter("time", _shader_time)
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("rect_size", glow_underlay.get_global_rect().size)
		_glow_shader_material.set_shader_parameter("time", _shader_time)
	if _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("time", _shader_time)

func _on_sell_button_down() -> void:
	if sell_button and _pressed_button_style:
		sell_button.position.y += 2

func _on_sell_button_up() -> void:
	if sell_button and _normal_button_style:
		sell_button.position.y -= 2

func _on_sell_pressed() -> void:
	if data:
		emit_signal("sell_requested", data.id)

func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos

func get_base_position() -> Vector2:
	return _base_position
