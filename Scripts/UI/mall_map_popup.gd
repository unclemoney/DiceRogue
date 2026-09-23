extends Control
class_name MallMapPopup

## MallMapPopup
##
## Modal in-game mall map, opened from the VCR tracker's Mall Zone label.
## Renders the same lightbox directory board as the game-start selector (via
## MallMapRenderer) with six pictogram plaques per zone. The current store
## pulses; hovering a plaque shows that store's upcoming challenge (name,
## scaled target, exact pre-selected debuffs for the current zone).

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const MallMapLayoutScript = preload("res://Scripts/Managers/mall_map_layout.gd")
const MallMapRendererScript = preload("res://Scripts/Managers/mall_map_renderer.gd")
const MallStoreIconScript = preload("res://Scripts/Managers/mall_store_icon.gd")
const MallStoreTooltipScript = preload("res://Scripts/UI/mall_store_tooltip.gd")
const MallIconTooltipControllerScript = preload("res://Scripts/UI/mall_icon_tooltip_controller.gd")
const ChannelManagerUIScript = preload("res://Scripts/Managers/channel_manager_ui.gd")

var channel_manager = null
var round_manager = null
var debuff_manager = null

var overlay: ColorRect
var panel: PanelContainer
var _title_label: Label
var _zone_label: Label
var _close_button: GlassActionButton
var _map_view: SubViewportContainer
var _map_viewport: SubViewport
var _map_root: Node2D
var _directory_grid: HBoxContainer
var _tooltip: MallStoreTooltip

var _zones_by_channel: Dictionary = {}
var _store_markers: Dictionary = {}  # channel -> Array[MallStoreIcon]
var _icon_tooltip: MallIconTooltipController
var _hovered_zone := -1
var _original_pos := Vector2.ZERO
var _closing := false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()


## setup(p_channel_manager, p_round_manager, p_debuff_manager) -> void
##
## Hands the popup the managers it reads store/round/debuff state from.
func setup(p_channel_manager, p_round_manager, p_debuff_manager) -> void:
	channel_manager = p_channel_manager
	round_manager = p_round_manager
	debuff_manager = p_debuff_manager


## open() -> void
##
## Rebuilds the map from current run state and animates the panel in.
func open() -> void:
	_closing = false
	_build_map_content()
	_position_to_viewport()
	visible = true
	_animate_entrance()


## close() -> void
##
## Animates the panel out and hides the popup.
func close() -> void:
	if _closing:
		return
	_closing = true
	_icon_tooltip.force_hide()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position", _original_pos + Vector2(0, 300), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(panel, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(_on_close_finished)


func _on_close_finished() -> void:
	visible = false
	panel.modulate.a = 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


## _build_ui() -> void
##
## Builds the overlay, centered panel, map viewport, and tooltip. Rebuilds
## from scratch (queue_free children first) so repeated calls stay clean.
func _build_ui() -> void:
	for child in get_children():
		child.queue_free()

	overlay = ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_gui_input)
	add_child(overlay)

	panel = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(1000, 660)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# No panel theme: the shared powerup theme paints a Label font shadow that
	# the selector (the visual reference) does not have. Every label here
	# carries explicit font/color overrides.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.3, 0.25, 0.35)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(20)
	panel_style.corner_detail = 8
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0, 6)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var panel_margin := MarginContainer.new()
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_top", 14)
	panel_margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(panel_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel_margin.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	_title_label = Label.new()
	_title_label.text = "MALL MAP"
	_title_label.add_theme_font_override("font", VCR_FONT)
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", Color(0.96, 0.90, 0.78))
	header.add_child(_title_label)

	_zone_label = Label.new()
	_zone_label.add_theme_font_override("font", VCR_FONT)
	_zone_label.add_theme_font_size_override("font_size", 16)
	_zone_label.add_theme_color_override("font_color", Color(0.28, 0.96, 0.44))
	_zone_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_zone_label)

	_close_button = GlassActionButton.new()
	_close_button.name = "CloseButton"
	_close_button.configure("CLOSE", Vector2(110, 34), MallMapRendererScript.MALL_GLASS_PALETTE, 14, VCR_FONT)
	_close_button.pressed.connect(close)
	header.add_child(_close_button)

	_map_view = SubViewportContainer.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_FILL
	_map_view.custom_minimum_size = Vector2(0, MallMapLayoutScript.MAP_VIEW_HEIGHT)
	_map_view.stretch = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.disable_3d = true
	_map_viewport.transparent_bg = true
	_map_viewport.handle_input_locally = true
	_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_map_viewport.size = MallMapLayoutScript.get_map_view_size()
	_map_viewport.physics_object_picking = true
	_map_view.add_child(_map_viewport)

	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	_map_viewport.add_child(_map_root)

	var directory_separator := HSeparator.new()
	vbox.add_child(directory_separator)

	# Light lightbox shell so the shared directory builder's dark slate text
	# reads the same as on the game-start selector.
	var directory_shell := PanelContainer.new()
	directory_shell.name = "DirectoryShell"
	directory_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	directory_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var directory_style := StyleBoxFlat.new()
	directory_style.bg_color = Color(0.93, 0.94, 0.96, 0.98)
	directory_style.border_color = Color(0.60, 0.63, 0.69, 1.0)
	directory_style.set_border_width_all(2)
	directory_style.set_corner_radius_all(10)
	directory_shell.add_theme_stylebox_override("panel", directory_style)
	vbox.add_child(directory_shell)

	var directory_margin := MarginContainer.new()
	directory_margin.add_theme_constant_override("margin_left", 10)
	directory_margin.add_theme_constant_override("margin_right", 10)
	directory_margin.add_theme_constant_override("margin_top", 6)
	directory_margin.add_theme_constant_override("margin_bottom", 8)
	directory_shell.add_child(directory_margin)

	var directory_vbox := VBoxContainer.new()
	directory_vbox.add_theme_constant_override("separation", 2)
	directory_margin.add_child(directory_vbox)

	var directory_title := Label.new()
	directory_title.text = "STORE DIRECTORY"
	directory_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	directory_title.add_theme_font_override("font", VCR_FONT)
	directory_title.add_theme_font_size_override("font_size", 16)
	directory_title.add_theme_color_override("font_color", Color(0.18, 0.20, 0.26))
	directory_vbox.add_child(directory_title)

	_directory_grid = HBoxContainer.new()
	_directory_grid.name = "DirectoryGrid"
	_directory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_directory_grid.add_theme_constant_override("separation", 6)
	directory_vbox.add_child(_directory_grid)

	_tooltip = MallStoreTooltipScript.new()
	_tooltip.name = "StoreTooltip"
	add_child(_tooltip)

	_icon_tooltip = MallIconTooltipControllerScript.new()
	_icon_tooltip.name = "IconTooltipController"
	add_child(_icon_tooltip)
	_icon_tooltip.setup(_tooltip, _get_icon_screen_rect, _icon_tooltip_text)


func _position_to_viewport() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var viewport_size := viewport.get_visible_rect().size
	_original_pos = (viewport_size - panel.custom_minimum_size) * 0.5
	panel.position = _original_pos
	panel.size = panel.custom_minimum_size


func _animate_entrance() -> void:
	panel.position = _original_pos - Vector2(0, 300)
	panel.modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "position", _original_pos, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.4)


## _build_map_content() -> void
##
## Rebuilds backdrop, corridor floor, zones, store icons, and directory from
## live state.
func _build_map_content() -> void:
	for child in _map_root.get_children():
		child.queue_free()
	_zones_by_channel.clear()
	_store_markers.clear()
	_hovered_zone = -1

	if channel_manager and channel_manager.zone_store_names.is_empty():
		channel_manager.assign_stores_to_zones()

	MallMapRendererScript.build_directory_backdrop(_map_root)
	# Staged reveal: corridor floor starts hidden and fades in, then the zones
	# and store icons pop in staggered (mirrors the game-start selector).
	var corridor_floors := MallMapRendererScript.build_corridors(_map_root, 0.0)

	if channel_manager == null:
		for corridor in corridor_floors:
			corridor.modulate.a = 1.0
		return

	_zones_by_channel = MallMapRendererScript.build_zones(_map_root, channel_manager, _on_zone_hovered, _on_zone_unhovered)

	var current_channel: int = channel_manager.current_channel
	for channel in _zones_by_channel:
		_zones_by_channel[channel].set_selected(channel == current_channel, false)

	_store_markers = MallMapRendererScript.build_store_icons(_map_root, channel_manager, _on_icon_hovered, _on_icon_unhovered)
	for channel in _store_markers:
		for icon in _store_markers[channel]:
			icon.set_state(MallMapRendererScript.get_store_state(channel_manager, round_manager, channel, icon.store_index))

	var zone_order: Array = []
	for layout in MallMapLayoutScript.get_zone_layouts():
		zone_order.append(int(layout.get("channel", 1)))
	zone_order.sort()
	# Width budget for the one-line font fit: panel min width minus the fixed
	# chrome (panel border 8 + margins 32 + shell border 4 + shell margins 20).
	MallMapRendererScript.build_store_directory(_directory_grid, channel_manager, zone_order, panel.custom_minimum_size.x - 64.0)

	_update_header()
	_play_staged_reveal(corridor_floors)


## _play_staged_reveal(corridor_floors) -> void
##
## Replays the selector's staged entrance inside the popup: corridor floor
## fade, staggered zone pop-in, then the store icons fade in.
func _play_staged_reveal(corridor_floors: Array) -> void:
	var delay := 0.0
	for corridor in corridor_floors:
		var tween := create_tween()
		tween.tween_interval(delay)
		tween.tween_property(corridor, "modulate:a", 1.0, 0.18)
		delay += 0.06

	var zone_delay := 0.12
	var zone_channels := _zones_by_channel.keys()
	zone_channels.sort()
	for channel in zone_channels:
		_zones_by_channel[channel].play_reveal(zone_delay)
		zone_delay += 0.03

	var icon_delay := zone_delay + 0.08
	for channel in _store_markers:
		for icon in _store_markers[channel]:
			icon.play_reveal(icon_delay)
			icon_delay += 0.015


func _update_header() -> void:
	if channel_manager == null:
		return
	var current_channel: int = channel_manager.current_channel
	_zone_label.text = "%s — %s" % [
		channel_manager.get_mall_zone_label(current_channel),
		channel_manager.get_selector_zone_name(current_channel).to_upper(),
	]


func _on_icon_hovered(icon: MallStoreIcon) -> void:
	_icon_tooltip.on_icon_hovered(icon)


func _on_icon_unhovered(icon: MallStoreIcon) -> void:
	_icon_tooltip.on_icon_unhovered(icon)


func _on_zone_hovered(channel: int) -> void:
	_hovered_zone = channel
	# Plaques sit next to zones and both are Area2D; when the cursor is really
	# over a plaque its controller is claiming the tooltip.
	if _is_plaque_under_mouse(channel):
		return
	# The zone genuinely owns the hover: cancel any plaque tooltip/exit-grace
	# and show immediately (moving plaque -> zone must not leave a dead gap).
	_icon_tooltip.force_hide()
	_show_zone_tooltip(channel)


func _on_zone_unhovered(channel: int) -> void:
	if _hovered_zone == channel:
		_hovered_zone = -1
	if _icon_tooltip.is_busy():
		return
	_tooltip.hide_tooltip(true)


## _is_plaque_under_mouse(channel) -> bool
##
## Plaques sit on top of zones and both are Area2D, so a zone's mouse_entered
## also fires when the cursor is really over one of its plaques; the plaque's
## controller is claiming the tooltip in that case.
func _is_plaque_under_mouse(channel: int) -> bool:
	var mouse := get_global_mouse_position()
	for icon in _store_markers.get(channel, []):
		if _get_icon_screen_rect(icon).has_point(mouse):
			return true
	return false


## _show_zone_tooltip(channel) -> void
##
## Zone wayfinding summary (name, section, difficulty, flavor, dealt store
## list) — same content shape as the game-start selector.
func _show_zone_tooltip(channel: int) -> void:
	if _tooltip == null or channel_manager == null:
		return
	var zone = _zones_by_channel.get(channel)
	if zone == null:
		return

	var data := {
		"title": "%s  %s" % [channel_manager.get_mall_zone_label(channel), channel_manager.get_selector_zone_name(channel)],
		"flavor": channel_manager.get_selector_tooltip_flavor(channel),
		"sections": [
			{"text": ChannelManagerUIScript.SECTION_LABELS.get(channel_manager.get_selector_section_id(channel), "DIRECTORY"), "style": "stat", "label": "Section"},
			{"text": "%s %s" % [channel_manager.get_difficulty_description(channel), TooltipFormat.mult(channel_manager.get_difficulty_multiplier(channel))], "style": "stat", "label": "Difficulty"},
			{"text": "Stores:", "style": "plain"},
		],
	}
	for round_number in range(1, channel_manager.STORES_PER_ZONE + 1):
		data["sections"].append({"text": "%d. %s" % [round_number, channel_manager.get_store_name(channel, round_number)], "style": "plain"})
	_tooltip.show_for(_get_zone_screen_rect(zone), data, SIDE_RIGHT)


## _get_zone_screen_rect(zone) -> Rect2
##
## The zone's board-space bounds converted to screen space (same transform
## as _get_icon_screen_rect) — doubles as the stale-guard anchor.
func _get_zone_screen_rect(zone) -> Rect2:
	var board_rect: Rect2 = zone.get_anchor_rect()
	var view_rect := _map_view.get_global_rect()
	var board_size: Vector2 = MallMapLayoutScript.get_board_size()
	var board_scale := Vector2.ONE
	if board_size.x > 0.0:
		board_scale.x = view_rect.size.x / board_size.x
	if board_size.y > 0.0:
		board_scale.y = view_rect.size.y / board_size.y
	return Rect2(view_rect.position + board_rect.position * board_scale, board_rect.size * board_scale)


func _icon_tooltip_text(icon: MallStoreIcon) -> Dictionary:
	return _build_store_tooltip_text(icon.channel, icon.store_index)


## _show_store_tooltip(icon) -> void
##
## Shows the hovered store's challenge summary next to its plaque.
func _show_store_tooltip(icon: MallStoreIcon) -> void:
	if _tooltip == null:
		return
	var text := _build_store_tooltip_text(icon.channel, icon.store_index)
	_tooltip.show_for(_get_icon_screen_rect(icon), text, SIDE_RIGHT)


## _build_store_tooltip_text(channel, store_index) -> Dictionary
##
## Thin delegate to the shared renderer builder (kept so existing tests and
## shot scenes keep their entry point).
func _build_store_tooltip_text(channel: int, store_index: int) -> Dictionary:
	return MallMapRendererScript.build_store_tooltip_text(channel_manager, round_manager, debuff_manager, channel, store_index)


func _get_icon_screen_rect(icon: MallStoreIcon) -> Rect2:
	var view_rect := _map_view.get_global_rect()
	var board_size: Vector2 = MallMapLayoutScript.get_map_view_size()
	var board_scale := view_rect.size / board_size
	var plaque_size: Vector2 = MallStoreIconScript.PLAQUE_SIZE
	var board_rect := Rect2(icon.position - plaque_size * 0.5, plaque_size)
	return Rect2(view_rect.position + board_rect.position * board_scale, board_rect.size * board_scale)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			close()
