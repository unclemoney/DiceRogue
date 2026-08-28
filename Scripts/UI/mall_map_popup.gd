extends Control
class_name MallMapPopup

## MallMapPopup
##
## Modal in-game mall map, opened from the VCR tracker's Mall Zone label.
## Renders the same directory board as the game-start selector (via
## MallMapRenderer) and overlays six store markers per zone. The current
## store pulses; hovering a marker shows that store's upcoming challenge
## (name, scaled target, exact pre-selected debuffs for the current zone).

const VCR_FONT: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
const PANEL_THEME: Theme = preload("res://Resources/UI/powerup_hover_theme.tres")
const MallMapLayoutScript = preload("res://Scripts/Managers/mall_map_layout.gd")
const MallMapRendererScript = preload("res://Scripts/Managers/mall_map_renderer.gd")

const MARKER_SIZE := Vector2(14, 14)
const MARKER_ROW_OFFSET := 20.0  # markers sit this far above the bar's bottom edge
const COLOR_COMPLETED := Color(0.35, 0.92, 0.48, 1.0)
const COLOR_CURRENT := Color(1.0, 0.92, 0.40, 1.0)
const COLOR_FAILED := Color(0.62, 0.34, 0.36, 1.0)
const COLOR_UPCOMING := Color(0.86, 0.82, 0.70, 1.0)

var channel_manager = null
var round_manager = null
var debuff_manager = null

var overlay: ColorRect
var panel: PanelContainer
var _title_label: Label
var _zone_label: Label
var _close_button: Button
var _map_view: SubViewportContainer
var _map_viewport: SubViewport
var _map_root: Node2D
var _tooltip_panel: PanelContainer
var _tooltip_label: Label

var _zones_by_channel: Dictionary = {}
var _store_markers: Dictionary = {}  # channel -> Array[Node2D] (marker Area2D roots)
var _pulse_tween: Tween
var _original_pos := Vector2.ZERO
var _closing := false

@onready var _tfx := get_node_or_null("/root/TweenFXHelper")


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
	_hide_tooltip(false)
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
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
	panel.theme = PANEL_THEME
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	panel_style.border_color = Color(0.3, 0.25, 0.35)
	panel_style.set_border_width_all(4)
	panel_style.set_corner_radius_all(20)
	panel_style.corner_detail = 8
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

	_close_button = Button.new()
	_close_button.name = "CloseButton"
	_close_button.text = "CLOSE"
	_close_button.custom_minimum_size = Vector2(110, 34)
	_close_button.add_theme_font_override("font", VCR_FONT)
	_close_button.add_theme_font_size_override("font_size", 14)
	_close_button.pressed.connect(close)
	_connect_button_fx(_close_button)
	header.add_child(_close_button)

	_map_view = SubViewportContainer.new()
	_map_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_view.stretch = true
	_map_view.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(_map_view)

	_map_viewport = SubViewport.new()
	_map_viewport.name = "MapViewport"
	_map_viewport.disable_3d = true
	_map_viewport.transparent_bg = true
	_map_viewport.handle_input_locally = true
	_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_map_viewport.size = MallMapLayoutScript.get_board_size()
	_map_viewport.physics_object_picking = true
	_map_view.add_child(_map_viewport)

	_map_root = Node2D.new()
	_map_root.name = "MapRoot"
	_map_viewport.add_child(_map_root)

	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.name = "StoreTooltip"
	_tooltip_panel.visible = false
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.z_index = 4000
	_tooltip_panel.custom_minimum_size = Vector2(220, 0)
	add_child(_tooltip_panel)

	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.12, 0.10, 0.14, 0.98)
	tooltip_style.border_color = Color(0.95, 0.86, 0.42, 1.0)
	tooltip_style.set_border_width_all(3)
	tooltip_style.set_corner_radius_all(14)
	_tooltip_panel.add_theme_stylebox_override("panel", tooltip_style)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 12)
	tooltip_margin.add_theme_constant_override("margin_right", 12)
	tooltip_margin.add_theme_constant_override("margin_top", 10)
	tooltip_margin.add_theme_constant_override("margin_bottom", 10)
	_tooltip_panel.add_child(tooltip_margin)

	_tooltip_label = Label.new()
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tooltip_label.custom_minimum_size = Vector2(220, 0)
	_tooltip_label.add_theme_font_override("font", VCR_FONT)
	_tooltip_label.add_theme_font_size_override("font_size", 13)
	_tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.95, 0.88))
	tooltip_margin.add_child(_tooltip_label)


func _connect_button_fx(button: BaseButton) -> void:
	if _tfx == null:
		return
	button.mouse_entered.connect(_tfx.button_hover.bind(button))
	button.mouse_exited.connect(_tfx.button_unhover.bind(button))
	button.pressed.connect(_tfx.button_press.bind(button))


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
## Rebuilds backdrop, corridors, zones and store markers from live state.
func _build_map_content() -> void:
	for child in _map_root.get_children():
		child.queue_free()
	_zones_by_channel.clear()
	_store_markers.clear()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()

	if channel_manager and channel_manager.zone_store_names.is_empty():
		channel_manager.assign_stores_to_zones()

	MallMapRendererScript.build_directory_backdrop(_map_root)
	# The popup has no staged reveal: corridors and wayfinding show immediately.
	MallMapRendererScript.build_corridors(_map_root, 1.0)
	MallMapRendererScript.build_wayfinding_blocks(_map_root, 1.0)

	if channel_manager == null:
		return

	_zones_by_channel = MallMapRendererScript.build_zones(_map_root, channel_manager)

	var current_channel: int = channel_manager.current_channel
	var current_store_index := _get_current_store_index()
	for layout in MallMapLayoutScript.get_zone_layouts():
		var channel: int = int(layout.get("channel", 1))
		if _zones_by_channel.has(channel):
			_zones_by_channel[channel].set_selected(channel == current_channel, false)
		_build_store_markers(channel, layout.get("bar_rect", Rect2()), current_channel, current_store_index)

	_update_header()


func _update_header() -> void:
	if channel_manager == null:
		return
	var current_channel: int = channel_manager.current_channel
	_zone_label.text = "%s — %s" % [
		channel_manager.get_mall_zone_label(current_channel),
		channel_manager.get_selector_zone_name(current_channel).to_upper(),
	]


## _get_current_store_index() -> int
##
## 0-based store index within the current zone from RoundManager.current_round.
func _get_current_store_index() -> int:
	if round_manager == null:
		return -1
	return round_manager.current_round


func _get_store_count() -> int:
	return ChannelManager.STORES_PER_ZONE


## _build_store_markers(channel, bar_rect, current_channel, current_store_index) -> void
##
## Places one marker per store evenly along the zone's bar rect.
func _build_store_markers(channel: int, bar_rect: Rect2, current_channel: int, current_store_index: int) -> void:
	if bar_rect.size.x <= 0.0:
		return
	var markers: Array[Node2D] = []
	var count := _get_store_count()
	var inner := bar_rect.grow(-10.0)
	for store_index in range(count):
		var fraction := (float(store_index) + 0.5) / float(count)
		var marker_pos := Vector2(
			inner.position.x + inner.size.x * fraction,
			bar_rect.end.y - MARKER_ROW_OFFSET
		)
		var state := _get_store_state(channel, store_index, current_channel, current_store_index)
		var marker := _create_store_marker(channel, store_index, marker_pos, state)
		_map_root.add_child(marker)
		markers.append(marker)
	_store_markers[channel] = markers


## _get_store_state(channel, store_index, current_channel, current_store_index) -> String
##
## Resolves the marker state: completed/failed from round data, current from
## the live round index, upcoming otherwise. Other zones stay neutral.
func _get_store_state(channel: int, store_index: int, current_channel: int, current_store_index: int) -> String:
	if channel != current_channel:
		return "upcoming"
	if round_manager == null:
		return "upcoming"
	if store_index == current_store_index:
		return "current"
	if store_index < round_manager.rounds_data.size():
		var round_data: Dictionary = round_manager.rounds_data[store_index]
		if round_data.get("completed", false):
			return "completed"
		if round_data.get("failed", false):
			return "failed"
	return "upcoming"


func _create_store_marker(channel: int, store_index: int, marker_pos: Vector2, state: String) -> Area2D:
	var marker := Area2D.new()
	marker.name = "StoreMarker_z%d_s%d" % [channel, store_index]
	marker.position = marker_pos
	marker.input_pickable = true
	marker.monitoring = false
	marker.set_meta("channel", channel)
	marker.set_meta("store_index", store_index)
	marker.set_meta("state", state)
	if state == "current":
		marker.set_meta("is_current", true)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = MARKER_SIZE + Vector2(6, 6)  # generous hover area
	shape.shape = rect
	marker.add_child(shape)

	var square := Polygon2D.new()
	var half := MARKER_SIZE * 0.5
	square.polygon = PackedVector2Array([
		-half,
		Vector2(half.x, -half.y),
		half,
		Vector2(-half.x, half.y),
	])
	square.color = _get_marker_color(state)
	marker.add_child(square)

	var outline := Line2D.new()
	outline.width = 2.0
	outline.default_color = Color(0.20, 0.16, 0.10, 1.0)
	if state == "current":
		outline.default_color = COLOR_CURRENT
	outline.points = MallMapRendererScript.close_points(square.polygon)
	marker.add_child(outline)

	marker.mouse_entered.connect(_on_marker_hovered.bind(marker))
	marker.mouse_exited.connect(_on_marker_unhovered.bind(marker))

	if state == "current":
		_start_marker_pulse(marker)
	return marker


func _get_marker_color(state: String) -> Color:
	match state:
		"completed":
			return COLOR_COMPLETED
		"current":
			return COLOR_CURRENT
		"failed":
			return COLOR_FAILED
	return COLOR_UPCOMING


func _start_marker_pulse(marker: Area2D) -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(marker, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(marker, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _on_marker_hovered(marker: Area2D) -> void:
	_show_store_tooltip(marker)


func _on_marker_unhovered(_marker: Area2D) -> void:
	_hide_tooltip(true)


## _show_store_tooltip(marker) -> void
##
## Shows the hovered store's challenge summary next to its marker.
func _show_store_tooltip(marker: Area2D) -> void:
	if _tooltip_panel == null:
		return
	var channel: int = marker.get_meta("channel")
	var store_index: int = marker.get_meta("store_index")
	_tooltip_label.text = _build_store_tooltip_text(channel, store_index)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	var rect := _get_marker_screen_rect(marker)
	if _tfx:
		_tfx.place_tooltip(_tooltip_panel, rect, SIDE_RIGHT, true)
	else:
		_tooltip_panel.global_position = rect.end + Vector2(12, -16)


func _get_marker_screen_rect(marker: Area2D) -> Rect2:
	var view_rect := _map_view.get_global_rect()
	var board_size: Vector2 = MallMapLayoutScript.get_board_size()
	var board_scale := view_rect.size / board_size
	var board_rect := Rect2(marker.position - MARKER_SIZE * 0.5, MARKER_SIZE)
	return Rect2(view_rect.position + board_rect.position * board_scale, board_rect.size * board_scale)


func _hide_tooltip(animate: bool) -> void:
	if _tooltip_panel == null:
		return
	if animate and _tfx and _tooltip_panel.visible:
		_tfx.tooltip_fade_out(_tooltip_panel, 0.08)
	else:
		_tooltip_panel.visible = false


## _build_store_tooltip_text(channel, store_index) -> String
##
## Builds the tooltip text for one store. The current zone uses the live
## rounds_data (exact pre-selected debuffs); other zones only have round
## config info — their debuffs are drawn when the zone starts, so they show
## as unknown here.
func _build_store_tooltip_text(channel: int, store_index: int) -> String:
	var text_lines: Array[String] = []
	var store_number := store_index + 1
	var store_name := "Store %d-%d" % [channel, store_number]
	if channel_manager:
		store_name = channel_manager.get_store_name(channel, store_number)
	text_lines.append(store_name)

	var is_current_zone: bool = channel_manager != null and channel == channel_manager.current_channel
	if is_current_zone and round_manager and store_index < round_manager.rounds_data.size():
		var round_data: Dictionary = round_manager.rounds_data[store_index]
		# Target mirrors GameController._compute_round_target minus the
		# transient challenge_score_modifier (powerup effect, not shown here).
		var target := _compute_store_target(channel, store_number)
		if target > 0:
			text_lines.append("Target: %s" % NumberFormatter.format_int(target))
		var debuff_ids: Array = round_data.get("debuff_ids", [])
		for debuff_id in debuff_ids:
			text_lines.append("Debuff: %s" % _get_debuff_display_name(str(debuff_id)))
		text_lines.append("Status: %s" % _get_store_status_text(store_index))
	else:
		if channel_manager:
			var round_config = channel_manager.get_round_config(channel, store_number)
			if round_config and round_config.target_score_override > 0:
				text_lines.append("Target: %s" % NumberFormatter.format_int(channel_manager.get_scaled_target_score(round_config.target_score_override, channel)))
			if round_config and round_config.get("is_boss_round") == true:
				text_lines.append("Boss Store")
		text_lines.append("Debuffs: unknown until reached")
		text_lines.append("Status: Upcoming")

	return "\n".join(text_lines)


## _compute_store_target(channel, store_number) -> int
##
## Scaled target for a store: override x channel multiplier (rebel premium
## included via ChannelManager.get_scaled_target_score).
func _compute_store_target(channel: int, store_number: int) -> int:
	if channel_manager == null:
		return 0
	var round_config = channel_manager.get_round_config(channel, store_number)
	if round_config == null:
		return 0
	var base: int = round_config.target_score_override
	if base <= 0:
		return 0
	return channel_manager.get_scaled_target_score(base, channel)


func _get_debuff_display_name(debuff_id: String) -> String:
	if debuff_manager and debuff_manager.has_method("get_def"):
		var def = debuff_manager.get_def(debuff_id)
		if def and not def.display_name.is_empty():
			return def.display_name
	return debuff_id


func _get_store_status_text(store_index: int) -> String:
	if round_manager == null:
		return "Upcoming"
	var state := _get_store_state(
		channel_manager.current_channel,
		store_index,
		channel_manager.current_channel,
		_get_current_store_index()
	)
	match state:
		"completed":
			return "Completed"
		"current":
			return "YOU ARE HERE"
		"failed":
			return "Failed"
	return "Upcoming"


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			close()
