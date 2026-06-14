extends Control
class_name StickerBadge

## StickerBadge.gd
## Mall-core rating badge for power-up kiosk tiles.
## Displays a rating label and a rarity-colored frame.
## Uses placeholder icon.svg until real sticker art is added.

const PLACEHOLDER_ICON = preload("res://icon.svg")
const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const BADGE_SIZE := Vector2(48, 48)
const ICON_SIZE := Vector2(24, 24)

@export var rating: String = "G"
@export var rarity: String = "common"

var _frame: PanelContainer
var _icon: TextureRect
var _label: Label

func _ready() -> void:
	print("[StickerBadge] _ready() size=", size, " custom_minimum_size=", custom_minimum_size, " offsets=", offset_left, offset_top, offset_right, offset_bottom)
	_ensure_structure()
	_apply_style()
	_apply_data()
	call_deferred("_report_layout")

func _ensure_structure() -> void:
	_frame = get_node_or_null("Frame") as PanelContainer
	if not _frame:
		_frame = PanelContainer.new()
		_frame.name = "Frame"
		_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		_frame.set_offsets_preset(Control.PRESET_FULL_RECT)
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.custom_minimum_size = BADGE_SIZE
		add_child(_frame)

	_icon = _frame.get_node_or_null("Icon") as TextureRect
	if not _icon:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_icon.set_offsets_preset(Control.PRESET_CENTER_TOP)
		_icon.size = ICON_SIZE
		_icon.position = Vector2((BADGE_SIZE.x - ICON_SIZE.x) * 0.5, 2.0)
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.visible = false
		_frame.add_child(_icon)

	_label = _frame.get_node_or_null("Label") as Label
	if not _label:
		_label = Label.new()
		_label.name = "Label"
		_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_label.set_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_label.offset_top = -20.0
		_label.offset_bottom = -2.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.clip_text = true
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_frame.add_child(_label)

func _apply_style() -> void:
	custom_minimum_size = BADGE_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.95)
	style.border_color = get_rarity_frame_color(rarity)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.corner_detail = 6
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 3
	_frame.add_theme_stylebox_override("panel", style)

	if VCR_FONT:
		_label.add_theme_font_override("font", VCR_FONT)
	_label.add_theme_font_size_override("font_size", 7)
	_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_label.add_theme_constant_override("outline_size", 1)

func _apply_data() -> void:
	if _icon:
		_icon.texture = PLACEHOLDER_ICON
		_icon.visible = true
	if _label:
		_label.text = get_sticker_label(rating)
	_apply_style()

func set_rating(new_rating: String) -> void:
	rating = new_rating
	if _label:
		_label.text = get_sticker_label(rating)

func set_rarity(new_rarity: String) -> void:
	rarity = new_rarity
	_apply_style()

static func get_sticker_label(rating_string: String) -> String:
	match rating_string.to_upper():
		"G": return "MOM-APPROVED"
		"PG": return "QUESTIONABLE"
		"PG-13": return "PARENTAL GUIDANCE"
		"R": return "GROUNDED"
		"NC-17": return "BANNED"
		_: return "MOM-APPROVED"

func _report_layout() -> void:
	print("[StickerBadge] layout report: name=", name, " size=", size, " custom_minimum_size=", custom_minimum_size)
	print("[StickerBadge] offsets l/t/r/b=", offset_left, ",", offset_top, ",", offset_right, ",", offset_bottom)
	print("[StickerBadge] global_rect=", get_global_rect(), " rect=", get_rect())
	var parent_name := "null"
	if get_parent():
		parent_name = get_parent().name
	print("[StickerBadge] parent=", parent_name)
	print("[StickerBadge] _frame size=", _frame.size, " _frame rect=", _frame.get_rect())
	print("[StickerBadge] _label size=", _label.size, " _label rect=", _label.get_rect())
	_dump_parent_constraints()

func _dump_parent_constraints() -> void:
	var parent := get_parent() as Control
	if not parent:
		return
	print("[StickerBadge] parent layout_mode=", parent.layout_mode)
	print("[StickerBadge] parent custom_minimum_size=", parent.custom_minimum_size, " size=", parent.size)
	if parent is Container:
		print("[StickerBadge] parent is Container; size_flags_h=", size_flags_horizontal, " size_flags_v=", size_flags_vertical)

static func get_rarity_frame_color(rarity_string: String) -> Color:
	match rarity_string.to_lower():
		"common": return Color.GRAY
		"uncommon": return Color.GREEN
		"rare": return Color.BLUE
		"epic": return Color.PURPLE
		"legendary": return Color.ORANGE
		_: return Color.WHITE
