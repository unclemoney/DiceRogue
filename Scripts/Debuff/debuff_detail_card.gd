extends Control
class_name DebuffDetailCard

## DebuffDetailCard
##
## Rich info card displayed on the SpineFanOverlay when debuff_container is clicked.
## Built entirely in code — no .tscn dependency.
##
## Layout (top → bottom inside a styled PanelContainer):
##   Icon · Name · separator · Difficulty stars · Description
##
## Public API:
##   setup(data) — call once after add_child

const CARD_SIZE := Vector2(220, 280)

var _data: DebuffData
var _panel: PanelContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = CARD_SIZE
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.07, 0.08, 0.97)
	style.border_color = Color(0.85, 0.15, 0.15, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 8
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var vcr_font := load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	# Large icon
	var icon_rect := TextureRect.new()
	icon_rect.name = "IconRect"
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon_rect.custom_minimum_size = Vector2(64, 64)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(icon_rect)

	# Name label
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		name_lbl.add_theme_font_override("font", vcr_font)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	vbox.add_child(name_lbl)

	_add_separator(vbox)

	# Difficulty label
	var diff_lbl := Label.new()
	diff_lbl.name = "DiffLabel"
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		diff_lbl.add_theme_font_override("font", vcr_font)
	diff_lbl.add_theme_font_size_override("font_size", 10)
	diff_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	vbox.add_child(diff_lbl)

	# Description label
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		desc_lbl.add_theme_font_override("font", vcr_font)
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.75, 1.0))
	vbox.add_child(desc_lbl)


func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.85, 0.15, 0.15, 0.5)
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)


## setup(data)
##
## Populates the detail card with debuff data. Call once after add_child.
func setup(data: DebuffData) -> void:
	_data = data
	if not _panel:
		return

	var icon_rect := _panel.get_node_or_null("Scroll/ContentVBox/IconRect") as TextureRect
	if icon_rect and data.icon:
		icon_rect.texture = data.icon

	var name_lbl := _panel.get_node_or_null("Scroll/ContentVBox/NameLabel") as Label
	if name_lbl:
		name_lbl.text = data.display_name if data.display_name else data.id

	var diff_lbl := _panel.get_node_or_null("Scroll/ContentVBox/DiffLabel") as Label
	if diff_lbl:
		diff_lbl.text = "%s  Difficulty %d/5" % [_build_star_string(data.difficulty_rating), data.difficulty_rating]

	var desc_lbl := _panel.get_node_or_null("Scroll/ContentVBox/DescLabel") as Label
	if desc_lbl:
		desc_lbl.text = data.description if data.description else ""


func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result
