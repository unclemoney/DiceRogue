extends PanelContainer
class_name ShopOwnedItemsPanel

const ACTION_THEME := preload("res://Resources/UI/action_button_theme_no_panel.tres")
const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const BRICK_FONT := preload("res://Resources/Font/BRICK_SANS.ttf")

const DEFAULT_ACCENT := Color(0.93, 0.76, 0.24, 1.0)
const DEFAULT_EMPTY_TEXT := "NO UNLOCKED STOCK"

var _title_label: Label
var _summary_label: Label
var _divider: ColorRect
var _scroll_container: ScrollContainer
var _list_container: VBoxContainer
var _empty_label: Label

var _current_title := ""
var _current_rows: Array = []
var _accent_color := DEFAULT_ACCENT
var _empty_text := DEFAULT_EMPTY_TEXT
var _ui_built := false


func _ready() -> void:
	theme = ACTION_THEME
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(250, 0)
	call_deferred("_build_ui_and_refresh")


## set_panel_content(title_text, rows, accent_color, empty_text)
##
## Updates the inventory board content using lightweight row dictionaries.
## Expected keys: `display_name`, `count`, and optional `detail`.
func set_panel_content(title_text: String, rows: Array, accent_color: Color = DEFAULT_ACCENT, empty_text: String = DEFAULT_EMPTY_TEXT) -> void:
	_current_title = title_text
	_current_rows = rows.duplicate(true)
	_accent_color = accent_color
	_empty_text = empty_text
	if is_inside_tree() and _ui_built:
		_refresh_view()


func _build_ui_and_refresh() -> void:
	if _ui_built:
		_refresh_view()
		return
	_build_ui()
	_ui_built = true
	_refresh_view()


func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 18)
	root_margin.add_theme_constant_override("margin_top", 16)
	root_margin.add_theme_constant_override("margin_right", 18)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 4)
	root_margin.add_child(content_vbox)

	_title_label = Label.new()
	_title_label.text = "STOCK"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if BRICK_FONT:
		_title_label.add_theme_font_override("font", BRICK_FONT)
		_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.86, 1.0))
	_title_label.add_theme_color_override("font_outline_color", Color(0.08, 0.07, 0.10, 1.0))
	_title_label.add_theme_constant_override("outline_size", 2)
	content_vbox.add_child(_title_label)

	_summary_label = Label.new()
	_summary_label.text = "0 unlocked | 0 owned"
	_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if VCR_FONT:
		_summary_label.add_theme_font_override("font", VCR_FONT)
		_summary_label.add_theme_font_size_override("font_size", 11)
	_summary_label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.92, 0.92))
	content_vbox.add_child(_summary_label)

	_divider = ColorRect.new()
	_divider.custom_minimum_size = Vector2(0, 3)
	_divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content_vbox.add_child(_divider)

	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_vbox.add_child(_scroll_container)

	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_container.add_theme_constant_override("separation", 4)
	_scroll_container.add_child(_list_container)

	_empty_label = Label.new()
	_empty_label.text = DEFAULT_EMPTY_TEXT
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_empty_label.custom_minimum_size = Vector2(0, 60)
	if VCR_FONT:
		_empty_label.add_theme_font_override("font", VCR_FONT)
		_empty_label.add_theme_font_size_override("font_size", 12)
	_empty_label.add_theme_color_override("font_color", Color(0.76, 0.80, 0.86, 0.66))
	_list_container.add_child(_empty_label)


func _refresh_view() -> void:
	if not _title_label:
		return

	_title_label.text = _current_title if _current_title != "" else "STOCK"
	_summary_label.text = _build_summary_text()
	_divider.color = _accent_color
	_empty_label.text = _empty_text
	_apply_panel_style()

	for child in _list_container.get_children():
		if child != _empty_label:
			child.queue_free()

	_empty_label.visible = _current_rows.is_empty()
	if _current_rows.is_empty():
		return

	for row in _current_rows:
		_list_container.add_child(_build_row(row))


func _apply_panel_style() -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.09, 0.13, 0.94)
	panel_style.border_color = _accent_color
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
	panel_style.shadow_size = 4
	panel_style.shadow_offset = Vector2(2, 2)
	add_theme_stylebox_override("panel", panel_style)


func _build_summary_text() -> String:
	var unlocked_count = _current_rows.size()
	var owned_total := 0
	for row in _current_rows:
		owned_total += int(row.get("count", 0))
	return "%d unlocked | %d owned" % [unlocked_count, owned_total]


func _build_row(row: Dictionary) -> Control:
	var row_shell := PanelContainer.new()
	row_shell.theme = ACTION_THEME
	row_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_shell.custom_minimum_size = Vector2(0, 58 if String(row.get("detail", "")) != "" else 42)

	var count: int = max(0, int(row.get("count", 0)))
	var muted: bool = count <= 0
	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.12, 0.14, 0.18, 0.82) if not muted else Color(0.10, 0.11, 0.15, 0.54)
	row_style.border_color = _accent_color if not muted else Color(0.44, 0.48, 0.54, 0.52)
	row_style.set_border_width_all(2)
	row_style.set_corner_radius_all(12)
	row_shell.add_theme_stylebox_override("panel", row_style)

	var row_margin := MarginContainer.new()
	row_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	row_margin.add_theme_constant_override("margin_left", 12)
	row_margin.add_theme_constant_override("margin_top", 8)
	row_margin.add_theme_constant_override("margin_right", 12)
	row_margin.add_theme_constant_override("margin_bottom", 8)
	row_shell.add_child(row_margin)

	var row_vbox := VBoxContainer.new()
	row_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_vbox.add_theme_constant_override("separation", 2)
	row_margin.add_child(row_vbox)

	var top_row := HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_theme_constant_override("separation", 10)
	row_vbox.add_child(top_row)

	var name_label := Label.new()
	name_label.text = String(row.get("display_name", "UNKNOWN"))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if VCR_FONT:
		name_label.add_theme_font_override("font", VCR_FONT)
		name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(0.96, 0.97, 0.99, 1.0) if not muted else Color(0.72, 0.76, 0.84, 0.76))
	top_row.add_child(name_label)

	var count_label := Label.new()
	count_label.text = "x%d" % count
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.custom_minimum_size = Vector2(44, 0)
	if VCR_FONT:
		count_label.add_theme_font_override("font", VCR_FONT)
		count_label.add_theme_font_size_override("font_size", 14)
	count_label.add_theme_color_override("font_color", _accent_color if not muted else Color(0.62, 0.66, 0.74, 0.78))
	top_row.add_child(count_label)

	var detail_text = String(row.get("detail", ""))
	if detail_text != "":
		var detail_label := Label.new()
		detail_label.text = detail_text
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if VCR_FONT:
			detail_label.add_theme_font_override("font", VCR_FONT)
			detail_label.add_theme_font_size_override("font_size", 10)
		detail_label.add_theme_color_override("font_color", Color(0.82, 0.87, 0.91, 0.82) if not muted else Color(0.68, 0.72, 0.80, 0.64))
		row_vbox.add_child(detail_label)

	return row_shell