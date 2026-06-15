extends Control
class_name KioskTile

## KioskTile.gd
## Mall-core kiosk tile for displaying a power-up in the fan-out view.
## Glossy chrome background, neon rarity glow, artwork, description,
## always-visible SELL button, and a rating sticker badge.

signal sell_requested(power_up_id: String)
signal tile_clicked(power_up_id: String)

const TILE_SIZE := Vector2(160, 240)
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const STICKER_SCENE = preload("res://Scenes/UI/sticker_badge.tscn")
const SHADER = preload("res://Scripts/Shaders/kiosk_tile.gdshader")
const GLOW_SHADER = preload("res://Scripts/Shaders/kiosk_tile_glow.gdshader")
const REFLECTION_SHADER = preload("res://Scripts/Shaders/kiosk_tile_reflection.gdshader")

@export var data: PowerUpData
@export var hover_lift: float = 8.0
@export var hover_scale: float = 1.02
@export var glow_hover: float = 0.9
@export var glow_selected: float = 1.5

var chrome_frame: ColorRect
var chrome_background: ColorRect
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
var _bg_shader_material: ShaderMaterial
var _glow_shader_material: ShaderMaterial
var _reflection_shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _hover_tween: Tween
var _base_position := Vector2.ZERO
var _resting_border_glow := 0.25

# Cached button style boxes for press depress tween.
var _normal_button_style: StyleBoxFlat
var _hover_button_style: StyleBoxFlat
var _pressed_button_style: StyleBoxFlat

# Artwork parallax state
var _mouse_norm := Vector2(0.5, 0.5)
var _artwork_rest_pos := Vector2.ZERO
var _reflection_rest_pos := Vector2.ZERO

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
	call_deferred("_debug_log_visual_state")

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
		glow_underlay.offset_left = -12.0
		glow_underlay.offset_top = -12.0
		glow_underlay.offset_right = 12.0
		glow_underlay.offset_bottom = 12.0
		glow_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow_underlay)
	glow_underlay.color = Color(1.0, 1.0, 1.0, 1.0)

	chrome_frame = get_node_or_null("ChromeFrame") as ColorRect
	if not chrome_frame:
		chrome_frame = ColorRect.new()
		chrome_frame.name = "ChromeFrame"
		chrome_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_frame.set_offsets_preset(Control.PRESET_FULL_RECT)
		chrome_frame.offset_left = -10.0
		chrome_frame.offset_top = -10.0
		chrome_frame.offset_right = 10.0
		chrome_frame.offset_bottom = 10.0
		chrome_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chrome_frame)

	chrome_background = get_node_or_null("ChromeBackground") as ColorRect
	if not chrome_background:
		chrome_background = ColorRect.new()
		chrome_background.name = "ChromeBackground"
		chrome_background.set_anchors_preset(Control.PRESET_FULL_RECT)
		chrome_background.set_offsets_preset(Control.PRESET_FULL_RECT)
		chrome_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(chrome_background)

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
		inner_margin.add_theme_constant_override("margin_left", 14)
		inner_margin.add_theme_constant_override("margin_top", 14)
		inner_margin.add_theme_constant_override("margin_right", 14)
		inner_margin.add_theme_constant_override("margin_bottom", 14)
		chrome_panel.add_child(inner_margin)

	var content_vbox := inner_margin.get_node_or_null("ContentVBox") as VBoxContainer
	if not content_vbox:
		content_vbox = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_theme_constant_override("separation", 8)
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
		art_panel.custom_minimum_size = Vector2(0, 110)
		art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(art_panel)
	else:
		art_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		reflection_overlay.visible = false

	description_panel = content_vbox.get_node_or_null("DescriptionPanel") as PanelContainer
	if not description_panel:
		description_panel = PanelContainer.new()
		description_panel.name = "DescriptionPanel"
		description_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(description_panel)
	else:
		description_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	description_label = description_panel.get_node_or_null("DescriptionLabel") as Label
	if not description_label:
		description_label = Label.new()
		description_label.name = "DescriptionLabel"
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		description_panel.add_child(description_label)
	else:
		description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	action_bar = content_vbox.get_node_or_null("ActionBar") as HBoxContainer
	if not action_bar:
		action_bar = HBoxContainer.new()
		action_bar.name = "ActionBar"
		action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content_vbox.add_child(action_bar)
	else:
		action_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	sell_button = action_bar.get_node_or_null("SellButton") as Button
	if not sell_button:
		sell_button = Button.new()
		sell_button.name = "SellButton"
		sell_button.text = "SELL"
		sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		sell_button.mouse_filter = Control.MOUSE_FILTER_PASS
		action_bar.add_child(sell_button)
	else:
		sell_button.mouse_filter = Control.MOUSE_FILTER_PASS

	sticker_badge = get_node_or_null("StickerBadge") as StickerBadge
	if not sticker_badge:
		sticker_badge = STICKER_SCENE.instantiate()
		sticker_badge.name = "StickerBadge"
		sticker_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.set_offsets_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.offset_left = -68.0
		sticker_badge.offset_top = -10.0
		sticker_badge.offset_right = -4.0
		sticker_badge.offset_bottom = 58.0
		sticker_badge.z_index = 10
		sticker_badge.rotation = deg_to_rad(randf_range(-4.0, 4.0))
		add_child(sticker_badge)

	if sticker_badge:
		sticker_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		print("[KioskTile] StickerBadge configured size=", sticker_badge.size, " rect=", sticker_badge.get_rect(), " offsets=", sticker_badge.offset_left, sticker_badge.offset_top, sticker_badge.offset_right, sticker_badge.offset_bottom)

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

	# Ensure ArtPanel panel style is transparent
	var art_parent := artwork.get_parent() as PanelContainer
	if art_parent:
		var transparent_art := StyleBoxFlat.new()
		transparent_art.bg_color = Color(0, 0, 0, 0)
		transparent_art.draw_center = false
		transparent_art.set_border_width_all(0)
		art_parent.add_theme_stylebox_override("panel", transparent_art)

	# Title styling: mall-core neon pink, bold VCR, dark outline
	if VCR_FONT:
		title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.7, 1.0))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_label.add_theme_constant_override("outline_size", 2)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.08, 0.15, 0.85)
	title_style.set_corner_radius_all(8)
	title_style.corner_detail = 6
	title_bar.add_theme_stylebox_override("panel", title_style)

	# Description styling: crisp white, slightly larger
	if VCR_FONT:
		description_label.add_theme_font_override("font", VCR_FONT)
	description_label.add_theme_font_size_override("font_size", 12)
	description_label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 1.0))
	description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description_label.add_theme_constant_override("outline_size", 1)

	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = Color(0.08, 0.06, 0.12, 0.8)
	desc_style.set_corner_radius_all(6)
	desc_style.corner_detail = 6
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

	sell_button.custom_minimum_size = Vector2(120, 32)
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

	if reflection_overlay:
		reflection_overlay.visible = true
		if _reflection_shader_material:
			_reflection_shader_material.set_shader_parameter("artwork_texture", artwork.texture)

	if title_label:
		title_label.text = data.display_name.to_upper() if data.display_name else "UNKNOWN"
	if description_label:
		description_label.text = data.description if data.description else "No description"
	if sticker_badge:
		sticker_badge.set_rating(data.rating)
		sticker_badge.set_rarity(data.rarity)
		sticker_badge.rotation = deg_to_rad(randf_range(-4.0, 4.0))
	if _frame_shader_material:
		_update_neon_color()

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
	lines.append(_format_control("ChromeBackground", chrome_background))
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
	# Outer chrome frame shader (draws the thick bezel)
	_frame_shader_material = ShaderMaterial.new()
	_frame_shader_material.shader = SHADER
	_frame_shader_material.set_shader_parameter("border_glow", _resting_border_glow)
	_frame_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())
	_frame_shader_material.set_shader_parameter("chrome_tint", Color(0.22, 0.20, 0.26, 0.98))
	_frame_shader_material.set_shader_parameter("highlight_tint", Color(0.75, 0.82, 0.95, 1.0))
	_frame_shader_material.set_shader_parameter("shadow_tint", Color(0.05, 0.04, 0.08, 1.0))
	_frame_shader_material.set_shader_parameter("env_tint_a", Color(0.25, 0.45, 0.65, 1.0))
	_frame_shader_material.set_shader_parameter("env_tint_b", Color(0.75, 0.30, 0.50, 1.0))
	_frame_shader_material.set_shader_parameter("reflection_amount", 0.12)
	_frame_shader_material.set_shader_parameter("corner_radius", 22.0)
	_frame_shader_material.set_shader_parameter("bezel_width", 10.0)
	_frame_shader_material.set_shader_parameter("draw_outer_bezel", true)
	_frame_shader_material.set_shader_parameter("rect_size", Vector2(180.0, 260.0))
	chrome_frame.material = _frame_shader_material

	# Inner glossy panel shader (same shader, bezel off)
	_bg_shader_material = ShaderMaterial.new()
	_bg_shader_material.shader = SHADER
	_bg_shader_material.set_shader_parameter("border_glow", _resting_border_glow * 0.5)
	_bg_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())
	_bg_shader_material.set_shader_parameter("chrome_tint", Color(0.22, 0.20, 0.26, 0.98))
	_bg_shader_material.set_shader_parameter("highlight_tint", Color(0.75, 0.82, 0.95, 1.0))
	_bg_shader_material.set_shader_parameter("shadow_tint", Color(0.05, 0.04, 0.08, 1.0))
	_bg_shader_material.set_shader_parameter("env_tint_a", Color(0.25, 0.45, 0.65, 1.0))
	_bg_shader_material.set_shader_parameter("env_tint_b", Color(0.75, 0.30, 0.50, 1.0))
	_bg_shader_material.set_shader_parameter("reflection_amount", 0.15)
	_bg_shader_material.set_shader_parameter("corner_radius", 14.0)
	_bg_shader_material.set_shader_parameter("bezel_width", 0.0)
	_bg_shader_material.set_shader_parameter("draw_outer_bezel", false)
	_bg_shader_material.set_shader_parameter("rect_size", Vector2(160.0, 240.0))
	chrome_background.material = _bg_shader_material

	# Additive glow underlay shader
	_glow_shader_material = ShaderMaterial.new()
	_glow_shader_material.shader = GLOW_SHADER
	_glow_shader_material.set_shader_parameter("glow_intensity", _resting_border_glow)
	_glow_shader_material.set_shader_parameter("glow_color", _get_rarity_neon_color())
	_glow_shader_material.set_shader_parameter("corner_radius", 24.0)
	_glow_shader_material.set_shader_parameter("spread", 18.0)
	_glow_shader_material.set_shader_parameter("rect_size", Vector2(184.0, 264.0))
	glow_underlay.material = _glow_shader_material
	glow_underlay.use_parent_material = false

	# Reflection overlay shader
	_reflection_shader_material = ShaderMaterial.new()
	_reflection_shader_material.shader = REFLECTION_SHADER
	_reflection_shader_material.set_shader_parameter("opacity", 0.0)
	_reflection_shader_material.set_shader_parameter("scanline_opacity", 0.06)
	_reflection_shader_material.set_shader_parameter("offset", Vector2.ZERO)
	reflection_overlay.material = _reflection_shader_material

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
	if _bg_shader_material:
		_bg_shader_material.set_shader_parameter("neon_color", color)
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("glow_color", color)

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	_apply_data()
	_update_neon_color()

func set_selected(selected: bool) -> void:
	_is_selected = selected
	var target_glow := glow_selected if _is_selected else _resting_border_glow
	var current_glow: float = _frame_shader_material.get_shader_parameter("border_glow") if _frame_shader_material else _resting_border_glow
	if _frame_shader_material:
		var tween := create_tween().set_parallel()
		tween.tween_method(_set_border_glow, current_glow, target_glow, 0.25)
		# Pulse the additive glow underlay
		var glow_intensity: float = _glow_shader_material.get_shader_parameter("glow_intensity") if _glow_shader_material else _resting_border_glow
		tween.tween_method(_set_glow_intensity, glow_intensity, target_glow, 0.25)
		# Subtle 1-2 degree rotation when selected; restore when deselected
		var target_rotation := deg_to_rad(randf_range(1.0, 2.0)) if _is_selected else 0.0
		tween.tween_property(self, "rotation", target_rotation, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# One-time sticker pulse
		if sticker_badge:
			sticker_badge.scale = Vector2.ONE
			tween.tween_property(sticker_badge, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.chain().tween_property(sticker_badge, "scale", Vector2.ONE, 0.1)

func _set_border_glow(value: float) -> void:
	if _frame_shader_material:
		_frame_shader_material.set_shader_parameter("border_glow", value)
	if _bg_shader_material:
		_bg_shader_material.set_shader_parameter("border_glow", value * 0.5)

func _set_glow_intensity(value: float) -> void:
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("glow_intensity", value)

func _on_mouse_entered() -> void:
	_is_hovering = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var current_glow: float = _frame_shader_material.get_shader_parameter("border_glow") if _frame_shader_material else _resting_border_glow
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", _base_position - Vector2(0, hover_lift), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE * hover_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var target_glow_intensity := glow_hover
	if _is_selected:
		target_glow_intensity = glow_selected
	if _glow_shader_material:
		var current_glow_intensity: float = _glow_shader_material.get_shader_parameter("glow_intensity")
		_hover_tween.tween_method(_set_glow_intensity, current_glow_intensity, target_glow_intensity, 0.18)
	if reflection_overlay and _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("opacity", 0.25)
		_hover_tween.tween_property(reflection_overlay, "position", _reflection_rest_pos + Vector2(2, 3), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if artwork:
		_update_artwork_parallax()

	if sticker_badge:
		_hover_tween.tween_property(sticker_badge, "scale", Vector2.ONE * 1.08, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hover_tween.chain().tween_property(sticker_badge, "scale", Vector2.ONE, 0.1)

	if _frame_shader_material:
		var target_frame_glow := glow_selected if _is_selected else glow_hover
		_hover_tween.tween_method(_set_border_glow, current_glow, target_frame_glow, 0.18)

func _on_mouse_exited() -> void:
	_is_hovering = false
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var current_glow: float = _frame_shader_material.get_shader_parameter("border_glow") if _frame_shader_material else _resting_border_glow
	var target_glow := glow_selected if _is_selected else _resting_border_glow
	var target_glow_intensity := glow_selected if _is_selected else _resting_border_glow
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", _base_position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "rotation", 0.0 if not _is_selected else rotation, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _glow_shader_material:
		var current_glow_intensity: float = _glow_shader_material.get_shader_parameter("glow_intensity")
		_hover_tween.tween_method(_set_glow_intensity, current_glow_intensity, target_glow_intensity, 0.18)
	if reflection_overlay and _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("opacity", 0.0)
		_hover_tween.tween_property(reflection_overlay, "position", _reflection_rest_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if artwork:
		_hover_tween.tween_property(artwork, "position", _artwork_rest_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if sticker_badge:
		_hover_tween.tween_property(sticker_badge, "scale", Vector2.ONE, 0.15)

	if _frame_shader_material:
		_hover_tween.tween_method(_set_border_glow, current_glow, target_glow, 0.18)

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
		if _is_hovering:
			_update_artwork_parallax()

func _update_artwork_parallax() -> void:
	if not artwork:
		return
	var offset := (_mouse_norm - Vector2(0.5, 0.5)) * -2.0
	artwork.position = _artwork_rest_pos + offset
	if _reflection_shader_material:
		_reflection_shader_material.set_shader_parameter("offset", (_mouse_norm - Vector2(0.5, 0.5)) * 4.0)

func _store_artwork_rest_positions() -> void:
	if artwork:
		_artwork_rest_pos = artwork.position
	if reflection_overlay:
		_reflection_rest_pos = reflection_overlay.position

func _process(_delta: float) -> void:
	if _frame_shader_material:
		_frame_shader_material.set_shader_parameter("rect_size", chrome_frame.get_global_rect().size)
	if _bg_shader_material:
		_bg_shader_material.set_shader_parameter("rect_size", chrome_background.get_global_rect().size)
	if _glow_shader_material:
		_glow_shader_material.set_shader_parameter("rect_size", glow_underlay.get_global_rect().size)

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
