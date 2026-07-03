extends Control
class_name StickerBadge

## StickerBadge.gd
## Mall-core rating badge for power-up kiosk tiles.
## Builds layered paper, symbol, holo, frame, and tooltip visuals and exposes
## a public API for pointer-driven foil control.

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const HOLO_SHADER = preload("res://Scripts/Shaders/sticker_holo.gdshader")

const SYMBOL_TEXTURES := {
	"G": preload("res://Resources/Art/UI/sticker_badge_thumb.png"),
	"PG": preload("res://Resources/Art/UI/sticker_badge_question.png"),
	"PG-13": preload("res://Resources/Art/UI/sticker_badge_eyes.png"),
	"R": preload("res://Resources/Art/UI/sticker_badge_angry.png"),
	"NC-17": preload("res://Resources/Art/UI/sticker_badge_no.png"),
}

const BADGE_SIZE: Vector2 = Vector2(70, 70)
const DEFAULT_UV := Vector2(0.5, 0.5)
const UV_LERP_SPEED := 12.0
const UV_SETTLE_EPSILON := 0.0005
const TOOLTIP_FADE_IN_DURATION := 0.12
const TOOLTIP_FADE_OUT_DURATION := 0.10
const TOOLTIP_MIN_SIZE := Vector2(156, 0)

const HOLO_PROFILE_KEYS := [
	"foil_intensity",
	"gloss_strength",
	"iridescence_strength",
	"rainbow_strength",
	"grain_strength",
	"rim_strength",
	"layer_alpha",
]

const DEFAULT_HOLO_PROFILE := {
	"foil_intensity": 0.28,
	"gloss_strength": 2.24,
	"iridescence_strength": 1.16,
	"rainbow_strength": 0.0,
	"grain_strength": 0.08,
	"rim_strength": 0.22,
	"layer_alpha": 0.64,
}

const MATCHING_SET_HOLO_PROFILE := {
	"foil_intensity": 0.42,
	"gloss_strength": 0.34,
	"iridescence_strength": 0.34,
	"rainbow_strength": 0.12,
	"grain_strength": 0.10,
	"rim_strength": 0.40,
	"layer_alpha": 0.68,
}

const RAINBOW_HOLO_PROFILE := {
	"foil_intensity": 0.66,
	"gloss_strength": 0.52,
	"iridescence_strength": 0.78,
	"rainbow_strength": 1.0,
	"grain_strength": 0.12,
	"rim_strength": 0.58,
	"layer_alpha": 0.82,
}

@export var rating: String = "G"
@export var rarity: String = "common"

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")

var _frame: PanelContainer
var _holo_layer: ColorRect
var _symbol_layer: TextureRect
var _holo_material: ShaderMaterial

var _tooltip: PanelContainer
var _tooltip_label: Label
var _tooltip_tween: Tween

var _target_uv := DEFAULT_UV
var _current_uv := DEFAULT_UV
var _direct_hover_active := false
var _host_hover_active := false
var _hover_active := false
var _holo_profile: Dictionary = DEFAULT_HOLO_PROFILE.duplicate(true)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = BADGE_SIZE
	if size.x <= 0.0 or size.y <= 0.0:
		size = BADGE_SIZE
	_ensure_structure()
	_ensure_tooltip()
	_apply_data()
	_apply_holo_profile(DEFAULT_HOLO_PROFILE)
	_apply_holo_uv()
	_connect_signals()
	set_process(false)


func _exit_tree() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		_tooltip.queue_free()


func _process(delta: float) -> void:
	var weight := clampf(delta * UV_LERP_SPEED, 0.0, 1.0)
	_current_uv = _current_uv.lerp(_target_uv, weight)
	_apply_holo_uv()
	if _tooltip and _tooltip.visible:
		_update_tooltip_position()
	if _current_uv.distance_squared_to(_target_uv) <= UV_SETTLE_EPSILON:
		_current_uv = _target_uv
		_apply_holo_uv()
		set_process(false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion
		set_pointer_local_position(mouse_event.position)


## set_pointer_global_position(global_position)
##
## Converts a global pointer position into badge-local UV space.
## Used by host controls that own the primary tile input region.
func set_pointer_global_position(global_mouse_position: Vector2) -> void:
	if not is_inside_tree():
		return
	var local_position := get_global_transform().affine_inverse() * global_mouse_position
	_set_pointer_local_position(local_position, true)


## set_pointer_local_position(local_position)
##
## Updates the badge using a local pointer position.
## Useful when the badge itself receives pass-through mouse motion.
func set_pointer_local_position(local_position: Vector2) -> void:
	_set_pointer_local_position(local_position, false)


## clear_host_pointer()
##
## Resets host-driven hover state when the parent tile loses hover.
func clear_host_pointer() -> void:
	_host_hover_active = false
	_sync_hover_state()


## reset_holo_profile()
##
## Restores the baseline subtle silver/pearl foil profile.
func reset_holo_profile() -> void:
	_apply_holo_profile(DEFAULT_HOLO_PROFILE)


## set_holo_profile(profile)
##
## Applies a semantic foil profile. Keys map directly to shader uniforms.
func set_holo_profile(profile: Dictionary) -> void:
	_apply_holo_profile(profile)


## set_holo_parameter(parameter_name, value)
##
## Updates a single shader-ready foil parameter while preserving the rest.
func set_holo_parameter(parameter_name: String, value: float) -> void:
	_holo_profile[parameter_name] = value
	_apply_holo_profile(_holo_profile)


## apply_matching_set_profile(blend)
##
## Blends from the default foil into the stronger matching-set profile.
func apply_matching_set_profile(blend: float = 1.0) -> void:
	_apply_holo_profile(_blend_profiles(DEFAULT_HOLO_PROFILE, MATCHING_SET_HOLO_PROFILE, blend))


## apply_rainbow_profile(blend)
##
## Blends from the default foil into the full rainbow foil profile.
func apply_rainbow_profile(blend: float = 1.0) -> void:
	_apply_holo_profile(_blend_profiles(DEFAULT_HOLO_PROFILE, RAINBOW_HOLO_PROFILE, blend))


func set_foil_intensity(value: float) -> void:
	set_holo_parameter("foil_intensity", value)


func set_gloss_strength(value: float) -> void:
	set_holo_parameter("gloss_strength", value)


func set_iridescence_strength(value: float) -> void:
	set_holo_parameter("iridescence_strength", value)


func set_rainbow_strength(value: float) -> void:
	set_holo_parameter("rainbow_strength", value)


func set_rating(new_rating: String) -> void:
	rating = _normalize_rating(new_rating)
	_apply_symbol_textures()
	if _tooltip_label:
		_tooltip_label.text = get_sticker_label(rating)


func set_rarity(new_rarity: String) -> void:
	rarity = new_rarity.to_lower()
	_apply_frame_style()
	_apply_holo_rarity_tint()


func show_tooltip() -> void:
	_show_tooltip()


func hide_tooltip() -> void:
	_hide_tooltip()


func get_holo_profile() -> Dictionary:
	return _holo_profile.duplicate(true)


func _connect_signals() -> void:
	if not mouse_entered.is_connected(_on_mouse_entered):
		mouse_entered.connect(_on_mouse_entered)
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _ensure_structure() -> void:
	_frame = get_node_or_null("Frame") as PanelContainer
	if not _frame:
		_frame = PanelContainer.new()
		_frame.name = "Frame"
		_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame.set_offsets_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
	_frame.custom_minimum_size = BADGE_SIZE

	_symbol_layer = _ensure_texture_layer("SymbolLayer")
	_holo_layer = _ensure_holo_layer()

	_frame.move_child(_holo_layer, 0)
	_frame.move_child(_symbol_layer, 1)

	_holo_layer.color = Color(1, 1, 1, 1)
	_holo_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_symbol_layer.modulate = Color(1, 1, 1, 1)

	_holo_material = _holo_layer.material as ShaderMaterial
	if _holo_material == null:
		_holo_material = ShaderMaterial.new()
		_holo_layer.material = _holo_material
	_holo_material.shader = HOLO_SHADER
	_holo_material.set_shader_parameter("corner_radius", 0.17)
	_holo_material.set_shader_parameter("edge_softness", 0.018)
	_apply_symbol_textures()

	_apply_frame_style()
	_apply_holo_rarity_tint()


func _ensure_texture_layer(node_name: String) -> TextureRect:
	var layer := _frame.get_node_or_null(node_name) as TextureRect
	if not layer:
		layer = TextureRect.new()
		layer.name = node_name
		layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.set_offsets_preset(Control.PRESET_FULL_RECT)
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(layer)
	return layer


func _ensure_holo_layer() -> ColorRect:
	var existing := _frame.get_node_or_null("HoloLayer")
	var layer := existing as ColorRect
	if layer:
		return layer
	if existing:
		existing.queue_free()
	layer = ColorRect.new()
	layer.name = "HoloLayer"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.set_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(layer)
	return layer


func _ensure_tooltip() -> void:
	if _tooltip and is_instance_valid(_tooltip):
		return

	_tooltip = PanelContainer.new()
	_tooltip.name = "%sTooltip" % name
	_tooltip.visible = false
	_tooltip.top_level = true
	_tooltip.z_index = 4000
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.97)
	style.border_color = get_rarity_frame_color(rarity)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.corner_detail = 6
	style.content_margin_left = 14.0
	style.content_margin_top = 10.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 4
	_tooltip.add_theme_stylebox_override("panel", style)

	_tooltip_label = Label.new()
	_tooltip_label.name = "TooltipLabel"
	_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = TOOLTIP_MIN_SIZE
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_label.text = get_sticker_label(rating)
	if VCR_FONT:
		_tooltip_label.add_theme_font_override("font", VCR_FONT)
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.93, 1.0))
	_tooltip_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_tooltip_label.add_theme_constant_override("outline_size", 1)
	_tooltip.add_child(_tooltip_label)

	var overlay_parent := FanOverlayHelper.get_overlay(self) if get_tree() else null
	if overlay_parent:
		overlay_parent.add_child.call_deferred(_tooltip)


func _apply_data() -> void:
	set_rating(rating)
	set_rarity(rarity)


func _apply_symbol_textures() -> void:
	var symbol_texture := get_symbol_texture_for_rating(rating)
	if _symbol_layer:
		_symbol_layer.texture = symbol_texture


func _apply_frame_style() -> void:
	if not _frame:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.28, 0.29, 0.32, 0.96)
	style.draw_center = true
	style.border_color = get_rarity_frame_color(rarity)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	style.shadow_color = Color(0, 0, 0, 0.36)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 4)
	_frame.add_theme_stylebox_override("panel", style)
	if _tooltip and is_instance_valid(_tooltip):
		var tooltip_style := _tooltip.get_theme_stylebox("panel") as StyleBoxFlat
		if tooltip_style:
			tooltip_style.border_color = get_rarity_frame_color(rarity)


func _apply_holo_profile(profile_overrides: Dictionary) -> void:
	_holo_profile = DEFAULT_HOLO_PROFILE.duplicate(true)
	for key in profile_overrides.keys():
		_holo_profile[key] = profile_overrides[key]
	if not _holo_material:
		return
	for parameter_name in HOLO_PROFILE_KEYS:
		if _holo_profile.has(parameter_name):
			_holo_material.set_shader_parameter(parameter_name, float(_holo_profile[parameter_name]))
	_apply_holo_rarity_tint()
	_apply_holo_uv()


func _apply_holo_rarity_tint() -> void:
	if _holo_material:
		_holo_material.set_shader_parameter("accent_tint", get_rarity_frame_color(rarity))


func _apply_holo_uv() -> void:
	if _holo_material:
		_holo_material.set_shader_parameter("mouse_uv", _current_uv)


func _set_pointer_local_position(local_position: Vector2, update_host_hover: bool) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var bounds := Rect2(Vector2.ZERO, size)
	var is_inside := bounds.has_point(local_position)
	if update_host_hover:
		_host_hover_active = is_inside
	if is_inside:
		_target_uv = _normalize_local_pointer(local_position)
		set_process(true)
	_sync_hover_state()


func _normalize_local_pointer(local_position: Vector2) -> Vector2:
	var uv := Vector2(local_position.x / size.x, local_position.y / size.y)
	return uv.clamp(Vector2.ZERO, Vector2.ONE)


func _sync_hover_state() -> void:
	var should_hover := _direct_hover_active or _host_hover_active
	if should_hover == _hover_active:
		if not should_hover:
			_target_uv = DEFAULT_UV
			set_process(true)
		return

	_hover_active = should_hover
	if _hover_active:
		_show_tooltip()
	else:
		_target_uv = DEFAULT_UV
		_hide_tooltip()
	set_process(true)


func _show_tooltip() -> void:
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	if _tooltip_label:
		_tooltip_label.text = get_sticker_label(rating)
	if not _tooltip.is_inside_tree():
		return
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip.visible = true
	_tooltip.modulate.a = 0.0
	_update_tooltip_position()
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip, "modulate:a", 1.0, TOOLTIP_FADE_IN_DURATION)


func _hide_tooltip() -> void:
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	if not _tooltip.visible:
		return
	if _tooltip_tween and _tooltip_tween.is_valid():
		_tooltip_tween.kill()
	_tooltip_tween = create_tween()
	_tooltip_tween.tween_property(_tooltip, "modulate:a", 0.0, TOOLTIP_FADE_OUT_DURATION)
	_tooltip_tween.tween_callback(func() -> void:
		if _tooltip and is_instance_valid(_tooltip):
			_tooltip.visible = false
	)


func _update_tooltip_position() -> void:
	if not _tooltip or not is_instance_valid(_tooltip):
		return
	if not _tooltip.is_inside_tree():
		return
	if _tfx:
		_tfx.place_tooltip(_tooltip, get_global_rect(), SIDE_TOP, false)
		return
	var rect := get_global_rect()
	_tooltip.global_position = rect.position + Vector2(0.0, -_tooltip.size.y - 10.0)


func _on_mouse_entered() -> void:
	_direct_hover_active = true
	set_pointer_global_position(get_global_mouse_position())
	_sync_hover_state()


func _on_mouse_exited() -> void:
	_direct_hover_active = false
	_sync_hover_state()


func _blend_profiles(from_profile: Dictionary, to_profile: Dictionary, blend: float) -> Dictionary:
	var amount := clampf(blend, 0.0, 1.0)
	var output := {}
	for parameter_name in HOLO_PROFILE_KEYS:
		var from_value := float(from_profile.get(parameter_name, DEFAULT_HOLO_PROFILE[parameter_name]))
		var to_value := float(to_profile.get(parameter_name, DEFAULT_HOLO_PROFILE[parameter_name]))
		output[parameter_name] = lerpf(from_value, to_value, amount)
	return output


func _normalize_rating(rating_string: String) -> String:
	var normalized := rating_string.to_upper()
	if SYMBOL_TEXTURES.has(normalized):
		return normalized
	return "G"


static func get_sticker_label(rating_string: String) -> String:
	match rating_string.to_upper():
		"G":
			return "Mom-Approved"
		"PG":
			return "Questionable"
		"PG-13":
			return "Parental Guidance"
		"R":
			return "Grounded"
		"NC-17":
			return "Banned"
		_:
			return "Mom-Approved"


static func get_rarity_frame_color(rarity_string: String) -> Color:
	match rarity_string.to_lower():
		"common":
			return Color(0.62, 0.64, 0.67, 1.0)
		"uncommon":
			return Color(0.35, 0.95, 0.45, 1.0)
		"rare":
			return Color(0.35, 0.65, 1.0, 1.0)
		"epic":
			return Color(0.85, 0.35, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.65, 0.15, 1.0)
		_:
			return Color.WHITE


static func get_symbol_path_for_rating(rating_string: String) -> String:
	match rating_string.to_upper():
		"G":
			return "res://Resources/Art/UI/sticker_badge_thumb.png"
		"PG":
			return "res://Resources/Art/UI/sticker_badge_question.png"
		"PG-13":
			return "res://Resources/Art/UI/sticker_badge_eyes.png"
		"R":
			return "res://Resources/Art/UI/sticker_badge_angry.png"
		"NC-17":
			return "res://Resources/Art/UI/sticker_badge_no.png"
		_:
			return "res://Resources/Art/UI/sticker_badge_thumb.png"


static func get_symbol_texture_for_rating(rating_string: String) -> Texture2D:
	var normalized := rating_string.to_upper()
	return SYMBOL_TEXTURES.get(normalized, SYMBOL_TEXTURES["G"])
