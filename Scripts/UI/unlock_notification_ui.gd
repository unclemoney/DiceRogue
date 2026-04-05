extends Control
class_name UnlockNotificationUI

## UnlockNotificationUI
##
## Displays a scrollable list of newly unlocked items with juicy animations.
## Items drop-bounce into a scrollable list. Hovering shows a floating tooltip
## with description and unlock criteria. OK button dismisses the panel.

signal all_items_acknowledged

# Layout constants
const PANEL_SIZE := Vector2(320, 400)
const ROW_HEIGHT := 26
const ROW_ICON_SIZE := 20
const ROW_SPACING := 3
const SCROLL_HEIGHT := 260
const MARGIN := 18

# Animation constants
const STAGGER_DELAY := 0.08
const DROP_DURATION := 0.4
const DROP_HEIGHT := 40.0
const PANEL_ANIM_DURATION := 0.4
const DISMISS_DURATION := 0.3

# UI node references
var _overlay: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _count_label: Label
var _scroll_container: ScrollContainer
var _item_list: VBoxContainer
var _ok_button: Button
var _tooltip: PanelContainer
var _tooltip_name: Label
var _tooltip_type: Label
var _tooltip_desc: RichTextLabel
var _tooltip_unlock: RichTextLabel

# State
var _items: Array = []
var _row_nodes: Array[Control] = []
var _is_showing: bool = false
var _progress_manager = null
var _tfx_helper = null


func _ready() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_manager = get_node_or_null("/root/ProgressManager")
	_tfx_helper = get_node_or_null("/root/TweenFXHelper")
	_build_ui()


## queue_items(item_ids: Array)
##
## Queues unlocked items and shows the panel with animations.
## @param item_ids: Array of item ID strings that were just unlocked.
func queue_items(item_ids: Array) -> void:
	if not _progress_manager:
		push_error("[UnlockNotificationUI] ProgressManager not available")
		all_items_acknowledged.emit()
		return
	
	_items.clear()
	for item_id in item_ids:
		if _progress_manager.unlockable_items.has(item_id):
			_items.append(_progress_manager.unlockable_items[item_id])
	
	if _items.is_empty():
		all_items_acknowledged.emit()
		return
	
	_show_panel()


## _build_ui()
##
## Programmatically constructs the panel, scroll list, and tooltip.
func _build_ui() -> void:
	# Semi-transparent overlay
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = Color(0, 0, 0, 0.0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)
	
	# Main panel
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.offset_left = -PANEL_SIZE.x / 2
	_panel.offset_top = -PANEL_SIZE.y / 2
	_panel.offset_right = PANEL_SIZE.x / 2
	_panel.offset_bottom = PANEL_SIZE.y / 2
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.pivot_offset = PANEL_SIZE / 2
	
	var theme_res = load("res://Resources/UI/powerup_hover_theme.tres") as Theme
	if theme_res:
		_panel.theme = theme_res
	
	_overlay.add_child(_panel)
	
	# Margin inside panel
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", MARGIN)
	margin.add_theme_constant_override("margin_right", MARGIN)
	margin.add_theme_constant_override("margin_top", MARGIN)
	margin.add_theme_constant_override("margin_bottom", MARGIN)
	_panel.add_child(margin)
	
	# Main vertical layout
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)
	
	# Load shared font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	# Title
	_title_label = Label.new()
	_title_label.name = "Title"
	_title_label.text = "ITEMS UNLOCKED!"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0))
	if vcr_font:
		_title_label.add_theme_font_override("font", vcr_font)
	vbox.add_child(_title_label)
	
	# Count subtitle
	_count_label = Label.new()
	_count_label.name = "Count"
	_count_label.text = ""
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 14)
	_count_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9, 0.8))
	if vcr_font:
		_count_label.add_theme_font_override("font", vcr_font)
	vbox.add_child(_count_label)
	
	# Separator
	vbox.add_child(HSeparator.new())
	
	# Scroll container for item list
	_scroll_container = ScrollContainer.new()
	_scroll_container.name = "ScrollContainer"
	_scroll_container.custom_minimum_size = Vector2(PANEL_SIZE.x - MARGIN * 2 - 16, SCROLL_HEIGHT)
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll_container)
	
	# Margin inside scroll to prevent clipping from scale animations
	var scroll_margin = MarginContainer.new()
	scroll_margin.name = "ScrollMargin"
	scroll_margin.add_theme_constant_override("margin_left", 10)
	scroll_margin.add_theme_constant_override("margin_right", 10)
	scroll_margin.add_theme_constant_override("margin_top", 4)
	scroll_margin.add_theme_constant_override("margin_bottom", 4)
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.add_child(scroll_margin)
	
	# Item list container inside scroll margin
	_item_list = VBoxContainer.new()
	_item_list.name = "ItemList"
	_item_list.add_theme_constant_override("separation", ROW_SPACING)
	_item_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_item_list)
	
	# Separator before button
	vbox.add_child(HSeparator.new())
	
	# OK button
	_ok_button = Button.new()
	_ok_button.name = "OKButton"
	_ok_button.text = "OK"
	_ok_button.custom_minimum_size = Vector2(120, 36)
	_ok_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok_button.add_theme_font_size_override("font_size", 18)
	if vcr_font:
		_ok_button.add_theme_font_override("font", vcr_font)
	_ok_button.pressed.connect(_on_ok_pressed)
	if _tfx_helper:
		_ok_button.mouse_entered.connect(func(): _tfx_helper.button_hover(_ok_button))
		_ok_button.mouse_exited.connect(func(): _tfx_helper.button_unhover(_ok_button))
	vbox.add_child(_ok_button)
	
	# Floating tooltip (child of self, above scroll clip)
	_build_tooltip()


## _build_tooltip()
##
## Creates the floating tooltip panel for item hover details.
func _build_tooltip() -> void:
	_tooltip = PanelContainer.new()
	_tooltip.name = "Tooltip"
	_tooltip.visible = false
	_tooltip.custom_minimum_size = Vector2(220, 0)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.z_index = 10
	
	# Style the tooltip
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.12, 0.98)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.border_color = Color(1.0, 0.8, 0.2, 1.0)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 3
	_tooltip.add_theme_stylebox_override("panel", style)
	
	var tip_vbox = VBoxContainer.new()
	tip_vbox.add_theme_constant_override("separation", 6)
	_tooltip.add_child(tip_vbox)
	
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	
	# Item name
	_tooltip_name = Label.new()
	_tooltip_name.add_theme_font_size_override("font_size", 15)
	_tooltip_name.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
	if vcr_font:
		_tooltip_name.add_theme_font_override("font", vcr_font)
	tip_vbox.add_child(_tooltip_name)
	
	# Item type
	_tooltip_type = Label.new()
	_tooltip_type.add_theme_font_size_override("font_size", 11)
	_tooltip_type.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	if vcr_font:
		_tooltip_type.add_theme_font_override("font", vcr_font)
	tip_vbox.add_child(_tooltip_type)
	
	# Description
	_tooltip_desc = RichTextLabel.new()
	_tooltip_desc.bbcode_enabled = true
	_tooltip_desc.fit_content = true
	_tooltip_desc.scroll_active = false
	_tooltip_desc.custom_minimum_size = Vector2(196, 0)
	_tooltip_desc.add_theme_font_size_override("normal_font_size", 12)
	if vcr_font:
		_tooltip_desc.add_theme_font_override("normal_font", vcr_font)
	tip_vbox.add_child(_tooltip_desc)
	
	# Unlock condition
	_tooltip_unlock = RichTextLabel.new()
	_tooltip_unlock.bbcode_enabled = true
	_tooltip_unlock.fit_content = true
	_tooltip_unlock.scroll_active = false
	_tooltip_unlock.custom_minimum_size = Vector2(196, 0)
	_tooltip_unlock.add_theme_font_size_override("normal_font_size", 11)
	if vcr_font:
		_tooltip_unlock.add_theme_font_override("normal_font", vcr_font)
	tip_vbox.add_child(_tooltip_unlock)
	
	add_child(_tooltip)


## _show_panel()
##
## Populates the item list, then plays panel entry and staggered item animations.
func _show_panel() -> void:
	_is_showing = true
	_clear_rows()
	
	# Update count label
	var count = _items.size()
	if count == 1:
		_count_label.text = "1 item unlocked"
	else:
		_count_label.text = "%d items unlocked" % count
	
	# Create rows (start hidden)
	for i in range(_items.size()):
		var row = _create_item_row(_items[i], i)
		row.modulate.a = 0.0
		_item_list.add_child(row)
		_row_nodes.append(row)
	
	# Disable OK button during animation
	_ok_button.disabled = true
	_ok_button.modulate.a = 0.0
	
	# Reset panel for animation
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0
	_overlay.color = Color(0, 0, 0, 0.0)
	
	visible = true
	z_index = 100
	
	# Wait for layout pass then animate
	await get_tree().process_frame
	_animate_show()


## _create_item_row(item, index: int) -> PanelContainer
##
## Creates a single thin item row with icon, name, and type.
func _create_item_row(item, _index: int) -> PanelContainer:
	var row = PanelContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	
	# Row background style
	var style = _create_row_style_normal()
	row.add_theme_stylebox_override("panel", style)
	
	# Content hbox
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	row.add_child(hbox)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(ROW_ICON_SIZE, ROW_ICON_SIZE)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.icon:
		icon_rect.texture = item.icon
	else:
		icon_rect.texture = _create_placeholder_icon(item.item_type)
	hbox.add_child(icon_rect)
	
	# Item name
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	var name_label = Label.new()
	name_label.text = item.display_name
	name_label.add_theme_font_size_override("font_size", 13)
	name_label.add_theme_color_override("font_color", Color(1.0, 0.98, 0.9))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		name_label.add_theme_font_override("font", vcr_font)
	hbox.add_child(name_label)
	
	# Item type (right-aligned)
	var type_label = Label.new()
	type_label.text = item.get_type_string()
	type_label.add_theme_font_size_override("font_size", 10)
	type_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 0.8))
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if vcr_font:
		type_label.add_theme_font_override("font", vcr_font)
	hbox.add_child(type_label)
	
	# Hover signals
	row.mouse_entered.connect(_on_row_hover.bind(item, row))
	row.mouse_exited.connect(_on_row_unhover.bind(row))
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return row


## _create_row_style_normal() -> StyleBoxFlat
##
## Returns the default row background style.
func _create_row_style_normal() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.18, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## _create_row_style_hover() -> StyleBoxFlat
##
## Returns the highlighted row background style for hover.
func _create_row_style_hover() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.16, 0.3, 0.9)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1.0, 0.8, 0.2, 0.6)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


## _create_placeholder_icon(item_type: int) -> Texture2D
##
## Creates a colored placeholder icon when no icon texture is set.
func _create_placeholder_icon(item_type: int) -> Texture2D:
	var img = Image.create(ROW_ICON_SIZE, ROW_ICON_SIZE, false, Image.FORMAT_RGBA8)
	var color: Color
	match item_type:
		0: color = Color(0.3, 0.6, 1.0)   # POWER_UP - Blue
		1: color = Color(0.3, 1.0, 0.3)   # CONSUMABLE - Green
		2: color = Color(1.0, 0.5, 0.0)   # MOD - Orange
		3: color = Color(0.8, 0.3, 0.8)   # COLORED_DICE - Purple
		4: color = Color(0.9, 0.9, 0.2)   # GAMING_CONSOLE - Yellow
		_: color = Color(0.5, 0.5, 0.5)
	img.fill(color)
	return ImageTexture.create_from_image(img)


## _on_row_hover(item, row: PanelContainer)
##
## Shows tooltip and highlights row on mouse hover.
func _on_row_hover(item, row: PanelContainer) -> void:
	row.add_theme_stylebox_override("panel", _create_row_style_hover())
	
	# Reset scale before punch to prevent drift from interrupted tweens
	row.scale = Vector2.ONE
	row.pivot_offset = row.size / 2
	TweenFX.punch_in(row, 0.15, 0.08)
	
	# Populate tooltip
	_tooltip_name.text = item.display_name
	_tooltip_type.text = "Type: %s" % item.get_type_string()
	_tooltip_desc.text = item.description
	_tooltip_unlock.text = "[color=lime]✓ %s[/color]" % item.get_unlock_description()
	
	# Position tooltip to right of panel, clamped to viewport
	var panel_rect = _panel.get_global_rect()
	var row_rect = row.get_global_rect()
	var viewport_size = get_viewport().get_visible_rect().size
	var tooltip_x = panel_rect.end.x + 10
	var tooltip_y = row_rect.position.y
	var est_w = 230.0
	var est_h = 130.0
	
	if tooltip_x + est_w > viewport_size.x:
		tooltip_x = panel_rect.position.x - est_w - 10
	tooltip_y = clampf(tooltip_y, 10, viewport_size.y - est_h - 10)
	
	_tooltip.global_position = Vector2(tooltip_x, tooltip_y)
	
	if not _tooltip.visible:
		_tooltip.visible = true
		_tooltip.modulate.a = 1.0
		_tooltip.scale = Vector2.ONE
		_tooltip.pivot_offset = Vector2(110, 65)
		TweenFX.pop_in(_tooltip, 0.2, 0.05)


## _on_row_unhover(row: PanelContainer)
##
## Hides tooltip and removes row highlight.
func _on_row_unhover(row: PanelContainer) -> void:
	row.add_theme_stylebox_override("panel", _create_row_style_normal())
	row.scale = Vector2.ONE
	_tooltip.visible = false
	_tooltip.modulate.a = 1.0
	_tooltip.scale = Vector2.ONE


## _animate_show()
##
## Plays panel entry, staggered item drops, title celebration, and button reveal.
func _animate_show() -> void:
	# Fade in overlay
	var overlay_tween = create_tween()
	overlay_tween.tween_property(_overlay, "color:a", 0.8, 0.3)
	
	# Pop in the panel
	_panel.pivot_offset = _panel.size / 2
	TweenFX.pop_in(_panel, PANEL_ANIM_DURATION, 0.08)
	
	# Wait for panel to appear before items cascade
	await get_tree().create_timer(PANEL_ANIM_DURATION * 0.6).timeout
	
	# Title celebration
	_title_label.pivot_offset = _title_label.size / 2
	TweenFX.rubber_band(_title_label, 0.5, 0.3)
	
	# Stagger drop-in for each row
	for i in range(_row_nodes.size()):
		var row = _row_nodes[i]
		get_tree().create_timer(STAGGER_DELAY * i).timeout.connect(
			func():
				if is_instance_valid(row):
					row.modulate.a = 1.0
					TweenFX.drop_in(row, DROP_DURATION, DROP_HEIGHT, Vector2(1.05, 0.95))
		)
	
	# After all items have dropped in, reveal OK button
	var total_cascade_time = STAGGER_DELAY * _row_nodes.size() + DROP_DURATION
	await get_tree().create_timer(total_cascade_time).timeout
	
	# Reveal OK button
	_ok_button.disabled = false
	_ok_button.modulate.a = 1.0
	_ok_button.pivot_offset = _ok_button.size / 2
	TweenFX.pop_in(_ok_button, 0.3, 0.15)


## _on_ok_pressed()
##
## Plays dismiss animation then emits all_items_acknowledged.
func _on_ok_pressed() -> void:
	if not _is_showing:
		return
	_is_showing = false
	_ok_button.disabled = true
	_tooltip.visible = false
	
	# Pop out the panel
	_panel.pivot_offset = _panel.size / 2
	TweenFX.pop_out(_panel, DISMISS_DURATION, 0.05)
	
	# Fade out overlay
	var overlay_tween = create_tween()
	overlay_tween.tween_property(_overlay, "color:a", 0.0, DISMISS_DURATION)
	
	await get_tree().create_timer(DISMISS_DURATION + 0.05).timeout
	
	visible = false
	_clear_rows()
	_items.clear()
	all_items_acknowledged.emit()


## _clear_rows()
##
## Removes all item rows from the list.
func _clear_rows() -> void:
	for row in _row_nodes:
		if is_instance_valid(row):
			row.queue_free()
	_row_nodes.clear()
