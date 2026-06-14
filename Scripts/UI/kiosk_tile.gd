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

@export var data: PowerUpData
@export var hover_lift: float = 8.0
@export var hover_scale: float = 1.02
@export var glow_hover: float = 0.7
@export var glow_selected: float = 1.5

var chrome_background: ColorRect
var chrome_panel: PanelContainer
var title_label: Label
var artwork: TextureRect
var reflection_overlay: TextureRect
var description_label: Label
var sell_button: Button
var sticker_badge: StickerBadge
var glow_underlay: ColorRect

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")

var _shader_material: ShaderMaterial
var _is_hovering := false
var _is_selected := false
var _hover_tween: Tween
var _base_position := Vector2.ZERO
var _resting_border_glow := 0.15

func _ready() -> void:
	_ensure_structure()
	_apply_static_style()
	# _ready() runs before the parent (PowerUpIcon) has a chance to call set_data(),
	# so only apply data if it was already assigned (e.g. scene preloaded with data).
	if data:
		_apply_data()
	_connect_signals()
	_setup_shader()

func _ensure_structure() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE

	glow_underlay = get_node_or_null("GlowUnderlay") as ColorRect
	if not glow_underlay:
		glow_underlay = ColorRect.new()
		glow_underlay.name = "GlowUnderlay"
		glow_underlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow_underlay.set_offsets_preset(Control.PRESET_FULL_RECT)
		glow_underlay.color = Color(0.9, 0.35, 0.6, 0.0)
		glow_underlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glow_underlay)

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
	chrome_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var inner_margin := chrome_panel.get_node_or_null("InnerMargin") as MarginContainer
	if not inner_margin:
		inner_margin = MarginContainer.new()
		inner_margin.name = "InnerMargin"
		inner_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		inner_margin.set_offsets_preset(Control.PRESET_FULL_RECT)
		inner_margin.add_theme_constant_override("margin_left", 8)
		inner_margin.add_theme_constant_override("margin_top", 8)
		inner_margin.add_theme_constant_override("margin_right", 8)
		inner_margin.add_theme_constant_override("margin_bottom", 8)
		chrome_panel.add_child(inner_margin)

	var content_vbox := inner_margin.get_node_or_null("ContentVBox") as VBoxContainer
	if not content_vbox:
		content_vbox = VBoxContainer.new()
		content_vbox.name = "ContentVBox"
		content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_theme_constant_override("separation", 6)
		inner_margin.add_child(content_vbox)

	title_label = _find_first_node(content_vbox, "TitleLabel") as Label
	if not title_label:
		var title_bar := PanelContainer.new()
		title_bar.name = "TitleBar"
		title_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(title_bar)

		title_label = Label.new()
		title_label.name = "TitleLabel"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.clip_text = true
		title_bar.add_child(title_label)

	artwork = _find_first_node(content_vbox, "Artwork") as TextureRect
	if not artwork:
		var art_panel := PanelContainer.new()
		art_panel.name = "ArtPanel"
		art_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		art_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(art_panel)

		artwork = TextureRect.new()
		artwork.name = "Artwork"
		artwork.set_anchors_preset(Control.PRESET_FULL_RECT)
		artwork.set_offsets_preset(Control.PRESET_FULL_RECT)
		artwork.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art_panel.add_child(artwork)

		reflection_overlay = TextureRect.new()
		reflection_overlay.name = "ReflectionOverlay"
		reflection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		reflection_overlay.set_offsets_preset(Control.PRESET_FULL_RECT)
		reflection_overlay.modulate = Color(1, 1, 1, 0.0)
		art_panel.add_child(reflection_overlay)

	var art_parent := artwork.get_parent() as PanelContainer
	if art_parent:
		var transparent_art := StyleBoxFlat.new()
		transparent_art.bg_color = Color(0, 0, 0, 0)
		transparent_art.draw_center = false
		transparent_art.set_border_width_all(0)
		art_parent.add_theme_stylebox_override("panel", transparent_art)

	if artwork:
		artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
		artwork.modulate = Color.WHITE
	if reflection_overlay:
		reflection_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	description_label = _find_first_node(content_vbox, "DescriptionLabel") as Label
	if not description_label:
		var desc_panel := PanelContainer.new()
		desc_panel.name = "DescriptionPanel"
		desc_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_vbox.add_child(desc_panel)

		description_label = Label.new()
		description_label.name = "DescriptionLabel"
		description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_panel.add_child(description_label)

	sell_button = _find_first_node(content_vbox, "SellButton") as Button
	if not sell_button:
		var action_bar := HBoxContainer.new()
		action_bar.name = "ActionBar"
		action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_bar.alignment = BoxContainer.ALIGNMENT_CENTER
		content_vbox.add_child(action_bar)

		sell_button = Button.new()
		sell_button.name = "SellButton"
		sell_button.text = "SELL"
		sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		action_bar.add_child(sell_button)

	sticker_badge = get_node_or_null("StickerBadge") as StickerBadge
	if not sticker_badge:
		sticker_badge = STICKER_SCENE.instantiate()
		sticker_badge.name = "StickerBadge"
		sticker_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.set_offsets_preset(Control.PRESET_TOP_RIGHT)
		sticker_badge.offset_left = -52.0
		sticker_badge.offset_top = 4.0
		sticker_badge.offset_right = -4.0
		sticker_badge.offset_bottom = 52.0
		sticker_badge.z_index = 10
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
	print("[KioskTile] ChromePanel panel style overridden transparent")

	# Ensure ArtPanel panel style is transparent
	var art_parent := artwork.get_parent() as PanelContainer
	if art_parent:
		var transparent_art := StyleBoxFlat.new()
		transparent_art.bg_color = Color(0, 0, 0, 0)
		transparent_art.draw_center = false
		transparent_art.set_border_width_all(0)
		art_parent.add_theme_stylebox_override("panel", transparent_art)
		var label := ""
		if data:
			label = data.id
		else:
			label = name
		print("[KioskTile] Forced ArtPanel panel style transparent for", label)

	# Dump every PanelContainer stylebox in the tile
	_dump_panel_styleboxes(self)

	if VCR_FONT:
		title_label.add_theme_font_override("font", VCR_FONT)
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(1, 0.98, 0.94, 1))
	title_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title_label.add_theme_constant_override("outline_size", 1)

	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.1, 0.08, 0.15, 0.85)
	title_style.set_corner_radius_all(8)
	title_style.corner_detail = 6
	title_label.get_parent().add_theme_stylebox_override("panel", title_style)

	if VCR_FONT:
		description_label.add_theme_font_override("font", VCR_FONT)
	description_label.add_theme_font_size_override("font_size", 9)
	description_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	description_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	description_label.add_theme_constant_override("outline_size", 1)

	var desc_style := StyleBoxFlat.new()
	desc_style.bg_color = Color(0.08, 0.06, 0.12, 0.8)
	desc_style.set_corner_radius_all(6)
	desc_style.corner_detail = 6
	description_label.get_parent().add_theme_stylebox_override("panel", desc_style)

	sell_button.theme = load("res://Resources/UI/action_button_theme.tres")
	if VCR_FONT:
		sell_button.add_theme_font_override("font", VCR_FONT)
	sell_button.add_theme_font_size_override("font_size", 12)

func _apply_data() -> void:
	if not data:
		return

	print("[KioskTile] Applying data for:", data.id, "icon=", data.icon, "rating=", data.rating, "rarity=", data.rarity)
	_print_node_hierarchy()

	if artwork:
		if data.icon:
			artwork.texture = data.icon
			artwork.modulate = Color.WHITE
			artwork.visible = true
			print("[KioskTile] Set artwork.texture =", data.icon.resource_path, "on node", artwork.name, "parent", artwork.get_parent().name)
		else:
			artwork.texture = load("res://icon.svg")
			print("[KioskTile] WARNING: data.icon missing, falling back to icon.svg")

		_print_texture_rect_state("[KioskTile] Artwork state after set", artwork)
		print("[KioskTile] Full texture dump:")
		_dump_all_textures(self)
	else:
		print("[KioskTile] CRITICAL: artwork node is null")

	if title_label:
		title_label.text = data.display_name.to_upper() if data.display_name else "UNKNOWN"
	if description_label:
		description_label.text = data.description if data.description else "No description"
	if sticker_badge:
		sticker_badge.set_rating(data.rating)
		sticker_badge.set_rarity(data.rarity)
	if _shader_material:
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

func _connect_signals() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

	if sell_button:
		sell_button.pressed.connect(_on_sell_pressed)
		if _tfx:
			sell_button.mouse_entered.connect(func(): _tfx.button_hover(sell_button))
			sell_button.mouse_exited.connect(func(): _tfx.button_unhover(sell_button))
			sell_button.pressed.connect(func(): _tfx.button_press(sell_button))

func _setup_shader() -> void:
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = SHADER
	_shader_material.set_shader_parameter("border_glow", _resting_border_glow)
	_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())
	_shader_material.set_shader_parameter("chrome_tint", Color(0.12, 0.10, 0.14, 0.98))
	_shader_material.set_shader_parameter("reflection_amount", 0.12)
	_shader_material.set_shader_parameter("corner_radius", 18.0)
	chrome_background.material = _shader_material

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
	if _shader_material:
		_shader_material.set_shader_parameter("neon_color", _get_rarity_neon_color())

func set_data(new_data: PowerUpData) -> void:
	data = new_data
	_apply_data()
	_update_neon_color()

func set_selected(selected: bool) -> void:
	print("[KioskTile] set_selected called:", selected, "id=", data.id if data else "unknown")
	_is_selected = selected
	var target_glow := glow_selected if _is_selected else _resting_border_glow
	if _shader_material:
		var current_glow: float = _shader_material.get_shader_parameter("border_glow")
		var tween := create_tween()
		tween.tween_method(_set_border_glow, current_glow, target_glow, 0.25)
		print("[KioskTile] Selection glow tween:", data.id if data else "unknown", current_glow, "->", target_glow)
	else:
		print("[KioskTile] WARNING: no shader material, cannot tween glow")

func _set_border_glow(value: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("border_glow", value)

func _on_mouse_entered() -> void:
	_is_hovering = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var current_glow: float = _shader_material.get_shader_parameter("border_glow") if _shader_material else _resting_border_glow
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", _base_position - Vector2(0, hover_lift), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE * hover_scale, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if glow_underlay:
		_hover_tween.tween_property(glow_underlay, "color:a", 0.35, 0.18)
	if reflection_overlay:
		_hover_tween.tween_property(reflection_overlay, "modulate:a", 0.25, 0.18)
	if sticker_badge:
		_hover_tween.tween_property(sticker_badge, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_hover_tween.chain().tween_property(sticker_badge, "scale", Vector2.ONE, 0.1)

	if _shader_material:
		_hover_tween.tween_method(_set_border_glow, current_glow, glow_hover, 0.18)
		print("[KioskTile] Hover glow tween:", data.id if data else "unknown", current_glow, "->", glow_hover)

func _on_mouse_exited() -> void:
	_is_hovering = false
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()

	var current_glow: float = _shader_material.get_shader_parameter("border_glow") if _shader_material else _resting_border_glow
	var target_glow := glow_selected if _is_selected else _resting_border_glow
	_hover_tween = create_tween().set_parallel()
	_hover_tween.tween_property(self, "position", _base_position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hover_tween.tween_property(glow_underlay, "color:a", 0.0, 0.18)
	if reflection_overlay:
		_hover_tween.tween_property(reflection_overlay, "modulate:a", 0.0, 0.18)
	if sticker_badge:
		_hover_tween.tween_property(sticker_badge, "scale", Vector2.ONE, 0.15)

	if _shader_material:
		_hover_tween.tween_method(_set_border_glow, current_glow, target_glow, 0.18)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			if data:
				emit_signal("tile_clicked", data.id)
			get_viewport().set_input_as_handled()

func _on_sell_pressed() -> void:
	if data:
		emit_signal("sell_requested", data.id)

func set_base_position(pos: Vector2) -> void:
	_base_position = pos
	position = pos

func get_base_position() -> Vector2:
	return _base_position
