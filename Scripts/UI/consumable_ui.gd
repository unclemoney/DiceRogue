extends Control
class_name ConsumableUI

signal consumable_used(consumable_id: String)
signal consumable_sold(consumable_id: String) 
signal max_consumables_reached

@export var consumable_icon_scene: PackedScene
@export var consumable_spine_scene: PackedScene
@export var max_consumables: int = 3
@onready var container: HBoxContainer
@onready var slots_label: Label = $SlotsLabel
@onready var _tfx := get_node("/root/TweenFXHelper")

# Data storage
var _consumable_data := {}  # consumable_id -> ConsumableData
var _consumable_spines := {}  # spine_id -> ConsumableSpine  
var _fanned_icons := {}  # consumable_id -> ConsumableIcon

# State management
enum State { SPINES, FANNED }
var _current_state: State = State.SPINES
var _is_animating: bool = false

# Layout properties
var _spine_shelf_y: float = 0.0  # Filled by _adapt_layout() from container size
var _fan_center: Vector2  # Center point for fanned cards
var _selected_spine_id: String = ""

# Animation and background
var _background: ColorRect
var _idle_tweens: Array[Tween] = []  # Track individual idle animation tweens
var _spine_tooltip: PanelContainer
var _spine_tooltip_label: Label

# Safe consumable tracking
var _active_consumable_count: int = 0

# Overflow state management
var _overflow_mode: bool = false
var _overflow_target_count: int = 0
var _overflow_label: Label = null

# Compact row constants
const BASE_MAX_CONSUMABLES: int = 4
const ABSOLUTE_MAX_CONSUMABLES: int = 4
const COMPACT_VISIBLE_CONSUMABLES: int = 3
const COMPACT_SLOT_COUNT: int = 4
const COMPACT_SLOT_SIZE: Vector2 = Vector2(72, 40)
const COMPACT_SLOT_SPACING: int = 6
const COMPACT_ROW_MARGIN: int = 2

# Compact row state
var _consumable_order: Array[String] = []
var _compact_margin: MarginContainer = null
var _compact_row: VBoxContainer = null
var _slot_cells: Array[PanelContainer] = []
var _slot_contents: Array[Control] = []
var _compact_overflow_label: Label = null

func _ready() -> void:
	print("[ConsumableUI] Initializing new spine-based system...")
	add_to_group("consumable_ui")
	
	# Clamp max_consumables to intended range
	max_consumables = clampi(max_consumables, BASE_MAX_CONSUMABLES, ABSOLUTE_MAX_CONSUMABLES)
	
	# Hide hardcoded labels when inside a container (container provides glowing title)
	var label_node = get_node_or_null("Label")
	if label_node:
		label_node.visible = false
	if slots_label:
		slots_label.visible = false
	
	# Calculate center position for fanned cards
	_fan_center = get_viewport_rect().size / 2.0
	
	# Load scenes if not set
	if not consumable_icon_scene:
		consumable_icon_scene = load("res://Scenes/Consumable/consumable_icon.tscn")
		if not consumable_icon_scene:
			push_error("[ConsumableUI] Failed to load consumable_icon scene")
	
	if not consumable_spine_scene:
		consumable_spine_scene = load("res://Scenes/UI/consumable_spine.tscn")
		if not consumable_spine_scene:
			push_error("[ConsumableUI] Failed to load consumable_spine scene")
	
	# Create background
	_create_background()
	
	# Create spine tooltip
	_create_spine_tooltip()
	
	# Keep existing container for backward compatibility but hide it initially
	if has_node("VBoxContainer/Container"):
		container = $VBoxContainer/Container
		print("[ConsumableUI] Found Container under VBoxContainer")
		container.visible = false  # Hidden by default in spine mode
	else:
		# Fallback: create Container if not found
		container = HBoxContainer.new()
		container.name = "Container"
		container.mouse_filter = Control.MOUSE_FILTER_PASS
		container.set_anchors_preset(Control.PRESET_TOP_WIDE)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_theme_constant_override("separation", 40)
		container.visible = false
		add_child(container)
	
	# Set up slots label (hidden in container mode)
	if not has_node("SlotsLabel"):
		slots_label = Label.new()
		slots_label.name = "SlotsLabel"
		slots_label.position = Vector2(135, -28)
		add_child(slots_label)
	else:
		slots_label = $SlotsLabel
	slots_label.visible = false
	
	# Initialize slots label
	update_slots_label()
	
	# Build compact row
	_create_compact_row()
	
	# Defer layout until container size is known
	resized.connect(_on_resized)
	call_deferred("_adapt_layout")
	
	print("[ConsumableUI] New spine-based system initialized")


func _on_resized() -> void:
	_adapt_layout()
	_position_spines()


func _adapt_layout() -> void:
	if size.x <= 0 or size.y <= 0:
		return
	_spine_shelf_y = size.y * 0.05
	
	# Update fan center for modal positioning
	_fan_center = get_viewport_rect().size / 2.0
	
	# Position compact row at bottom center
	if _compact_row:
		# For vertical list: make the margin full-rect and position the list at the top with a small margin
		if _compact_margin:
			_compact_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		_compact_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_compact_row.position = Vector2(0, COMPACT_ROW_MARGIN)

		# Ensure each row spans the container width
		for row in _slot_cells:
			if row:
				row.custom_minimum_size.x = max(0, size.x - (COMPACT_ROW_MARGIN * 2))

func _create_compact_row() -> void:
	# Create a vertical list (VBox) to replace the compact horizontal row
	_compact_margin = MarginContainer.new()
	_compact_margin.name = "CompactMargin"
	_compact_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_compact_margin)

	# Use a VBoxContainer for vertical rows that span the container width
	_compact_row = VBoxContainer.new()
	_compact_row.name = "CompactList"
	_compact_row.mouse_filter = Control.MOUSE_FILTER_PASS
	_compact_row.add_theme_constant_override("separation", COMPACT_SLOT_SPACING)
	_compact_margin.add_child(_compact_row)

	# Create slot rows
	_slot_cells.clear()
	_slot_contents.clear()
	for i in range(COMPACT_SLOT_COUNT):
		var row_panel: PanelContainer = PanelContainer.new()
		row_panel.name = "Row%d" % i
		row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_panel.custom_minimum_size = Vector2(0, COMPACT_SLOT_SIZE.y)
		row_panel.add_theme_stylebox_override("panel", _make_compact_slot_style())

		# Inside each row, create an HBox for icon + labels
		var row_hbox: HBoxContainer = HBoxContainer.new()
		row_hbox.name = "RowHBox"
		row_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_hbox.add_theme_constant_override("separation", 1)
		row_panel.add_child(row_hbox)

		# Dedicated host for the spine node (keeps row layout intact)
		var spine_host: Control = Control.new()
		spine_host.name = "SpineHost"
		spine_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spine_host.set_anchors_preset(Control.PRESET_CENTER)
		row_panel.add_child(spine_host)

		# Icon placeholder container (left) — capped at 32x32
		var icon_holder: TextureRect = TextureRect.new()
		icon_holder.name = "IconHolder"
		icon_holder.custom_minimum_size = Vector2(32, 32)
		icon_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon_holder.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_holder.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_hbox.add_child(icon_holder)

		# Vertical labels container
		var labels_vbox: VBoxContainer = VBoxContainer.new()
		labels_vbox.name = "Labels"
		labels_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels_vbox.add_theme_constant_override("separation", 2)
		row_hbox.add_child(labels_vbox)

		var title_lbl: Label = Label.new()
		title_lbl.name = "Title"
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_lbl.add_theme_font_size_override("font_size", 12)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels_vbox.add_child(title_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.name = "Desc"
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.add_theme_color_override("font_color", Color(0.8,0.8,0.8,1))
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		labels_vbox.add_child(desc_lbl)

		# Hover highlighting
		row_panel.mouse_entered.connect(_on_row_mouse_entered.bind(i))
		row_panel.mouse_exited.connect(_on_row_mouse_exited.bind(i))

		_compact_row.add_child(row_panel)
		_slot_cells.append(row_panel)
		_slot_contents.append(null)

	print("[ConsumableUI] Created vertical list with %d rows" % COMPACT_SLOT_COUNT)

func _on_row_mouse_entered(index: int) -> void:
	if index >= 0 and index < _slot_cells.size():
		var cell: PanelContainer = _slot_cells[index]
		if not cell:
			return
		if _slot_contents[index] != null:
			cell.add_theme_stylebox_override("panel", _make_compact_slot_hover_style())
		else:
			cell.add_theme_stylebox_override("panel", _make_compact_slot_style())

func _on_row_mouse_exited(index: int) -> void:
	if index >= 0 and index < _slot_cells.size():
		var cell: PanelContainer = _slot_cells[index]
		if not cell:
			return
		if _slot_contents[index] != null:
			cell.add_theme_stylebox_override("panel", _make_compact_slot_occupied_style())
		else:
			cell.add_theme_stylebox_override("panel", _make_compact_slot_style())

func _make_compact_slot_style() -> StyleBoxFlat:
	# Empty slot — completely transparent
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.0)
	style.border_color = Color(0.3, 0.25, 0.35, 0.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	return style

func _make_compact_slot_occupied_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.10, 0.14, 0.6)
	style.border_color = Color(0.3, 0.25, 0.35, 0.08)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	return style

func _make_compact_slot_hover_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.18, 0.28, 0.75)
	style.border_color = Color(0.5, 0.4, 0.6, 0.35)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 6
	return style

func _set_slot_empty_style(index: int) -> void:
	if index >= 0 and index < _slot_cells.size():
		_slot_cells[index].add_theme_stylebox_override("panel", _make_compact_slot_style())

func _set_slot_occupied_style(index: int) -> void:
	if index >= 0 and index < _slot_cells.size():
		_slot_cells[index].add_theme_stylebox_override("panel", _make_compact_slot_occupied_style())

func _update_overflow_slot(overflow_count: int) -> void:
	var last_index: int = COMPACT_SLOT_COUNT - 1
	var cell: PanelContainer = _slot_cells[last_index]
	
	_clear_slot_ui(last_index)
	_slot_contents[last_index] = null
	_set_slot_empty_style(last_index)
	
	if overflow_count > 0:
		if not _compact_overflow_label:
			_compact_overflow_label = Label.new()
			_compact_overflow_label.name = "OverflowLabel"
			_compact_overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_compact_overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_compact_overflow_label.add_theme_font_size_override("font_size", 12)
			_compact_overflow_label.add_theme_color_override("font_color", Color(0.9, 0.6, 0.7, 1.0))
		
		_compact_overflow_label.text = "+%s more" % NumberFormatter.format_int(overflow_count)
		_compact_overflow_label.visible = true
		# Place overflow label into the row's labels area
		var labels_vbox: VBoxContainer = cell.get_node_or_null("RowHBox/Labels")
		if labels_vbox:
			if _compact_overflow_label.get_parent() != labels_vbox:
				if _compact_overflow_label.get_parent():
					_compact_overflow_label.get_parent().remove_child(_compact_overflow_label)
				labels_vbox.add_child(_compact_overflow_label)
		# Hide the static title/desc labels so overflow is readable
		var title_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Title")
		var desc_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Desc")
		if title_lbl:
			title_lbl.visible = false
		if desc_lbl:
			desc_lbl.visible = false
		_slot_contents[last_index] = _compact_overflow_label
		_set_slot_occupied_style(last_index)
	else:
		if _compact_overflow_label and _compact_overflow_label.get_parent():
			_compact_overflow_label.get_parent().remove_child(_compact_overflow_label)
		var title_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Title")
		var desc_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Desc")
		if title_lbl:
			title_lbl.visible = true
		if desc_lbl:
			desc_lbl.visible = true

func _assign_spine_to_slot(spine: ConsumableSpine, slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_cells.size():
		return
	
	var cell: PanelContainer = _slot_cells[slot_index]
	
	# Clear any previous spine placed in the dedicated SpineHost (preserve labels/layout)
	var spine_host: Control = cell.get_node_or_null("SpineHost")
	if spine_host:
		for child in spine_host.get_children():
			child.queue_free()
		# Reparent spine to the SpineHost so the row layout stays intact
		if spine.get_parent():
			spine.get_parent().remove_child(spine)
		spine_host.add_child(spine)
	else:
		# Fallback: add directly to cell (older layout)
		if spine.get_parent():
			spine.get_parent().remove_child(spine)
		cell.add_child(spine)
	
	# Enable compact mode and center spine in cell
	spine.set_compact_mode(true)
	spine.set_anchors_preset(Control.PRESET_CENTER)
	spine.position = Vector2.ZERO
	spine.scale = Vector2.ONE
	# Hide the spine visual — the row shows its own icon/labels
	spine.visible = false

	# Populate the row's icon and labels (vertical list layout)
	var icon_holder: TextureRect = cell.get_node_or_null("RowHBox/IconHolder")
	var title_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Title")
	var desc_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Desc")
	if spine and spine.data:
		if icon_holder:
			icon_holder.texture = spine.data.icon
		if title_lbl:
			title_lbl.text = spine.data.display_name
			title_lbl.visible = true
		if desc_lbl:
			desc_lbl.text = spine.data.description
			desc_lbl.visible = true
	
	_set_slot_occupied_style(slot_index)
	_slot_contents[slot_index] = spine

func _create_background() -> void:
	# Create semi-transparent background for when cards are fanned
	print("[ConsumableUI] Creating background for fanned cards")
	_background = ColorRect.new()
	_background.name = "Background"
	_background.color = Color(0, 0, 0, 0.5)
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.mouse_filter = Control.MOUSE_FILTER_STOP
	_background.visible = false  # Start hidden
	_background.z_index = 5
	add_child(_background)
	
	# Connect background click to fold cards back
	_background.gui_input.connect(_on_background_clicked)

func _create_spine_tooltip() -> void:
	# Create tooltip for spine hover
	_spine_tooltip = PanelContainer.new()
	_spine_tooltip.name = "SpineTooltip"
	_spine_tooltip.visible = false
	_spine_tooltip.z_index = 20
	
	# Apply direct styling instead of theme file for reliability
	_apply_hover_tooltip_style(_spine_tooltip)
	
	# Create the label inside the panel
	_spine_tooltip_label = Label.new()
	_spine_tooltip_label.name = "SpineTooltipLabel"
	_spine_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spine_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_spine_tooltip_label.custom_minimum_size = Vector2(200, 0)
	
	# Apply direct label styling
	_apply_hover_label_style(_spine_tooltip_label)
	
	_spine_tooltip.add_child(_spine_tooltip_label)
	add_child(_spine_tooltip)

func add_consumable(data: ConsumableData) -> Node:
	print("[ConsumableUI] Adding consumable:", data.id if data else "null")
	
	# Check if we've reached the max number of consumables
	if _consumable_data.size() >= max_consumables:
		print("[ConsumableUI] Maximum number of consumables reached!")
		emit_signal("max_consumables_reached")
		return null
		
	if not consumable_spine_scene:
		push_error("[ConsumableUI] consumable_spine_scene not set")
		return null
		
	if not data:
		push_error("[ConsumableUI] Cannot add null consumable data")
		return null
	
	# Store the data
	_consumable_data[data.id] = data
	_consumable_order.append(data.id)
	_active_consumable_count += 1
	
	# Create spine
	var spine: ConsumableSpine = consumable_spine_scene.instantiate()
	if not spine:
		push_error("[ConsumableUI] Failed to instantiate consumable spine")
		return null
	
	# Add spine to UI
	add_child(spine)
	spine.set_data(data)
	
	# Store spine reference
	_consumable_spines[data.id] = spine
	
	# Connect spine signals
	if not spine.is_connected("spine_clicked", _on_spine_clicked):
		spine.spine_clicked.connect(_on_spine_clicked)
	if not spine.is_connected("spine_hovered", _on_spine_hovered):
		spine.spine_hovered.connect(_on_spine_hovered)
	if not spine.is_connected("spine_unhovered", _on_spine_unhovered):
		spine.spine_unhovered.connect(_on_spine_unhovered)
	
	# Store spine reference
	_consumable_spines[data.id] = spine
	
	# Position spine on shelf
	_position_spines()
	
	# Juice: consumable acquisition fanfare
	var tfx = get_node_or_null("/root/TweenFXHelper")
	var reward_tween = null
	if tfx and spine:
		reward_tween = tfx.positive_reward(spine)
		# Slide-in effect
		var orig_pos = spine.position
		spine.position.x += min(200.0, size.x * 0.3)
		spine.modulate.a = 0.0
		var slide_tween = create_tween()
		slide_tween.tween_property(spine, "position", orig_pos, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		slide_tween.parallel().tween_property(spine, "modulate:a", 1.0, 0.3)
		slide_tween.finished.connect(func():
			if is_instance_valid(spine):
				spine.position = orig_pos
				spine.scale = Vector2.ONE
		)
		if reward_tween:
			reward_tween.finished.connect(func():
				if is_instance_valid(spine):
					spine.position = orig_pos
					spine.scale = Vector2.ONE
			)
	
	# Acquisition sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_panel_swoosh"):
		audio_mgr.play_panel_swoosh()
	
	# Update slots label
	update_slots_label()
	
	print("[ConsumableUI] Added consumable spine:", data.id)
	return spine

func _position_spines() -> void:
	# Hide/reparent all spines first
	for spine_id in _consumable_spines.keys():
		var spine: ConsumableSpine = _consumable_spines[spine_id]
		if spine:
			spine.visible = false
			if spine.get_parent():
				spine.get_parent().remove_child(spine)
			add_child(spine)
	
	# Clear slot UI and tracking
	for i in range(_slot_contents.size()):
		_clear_slot_ui(i)
		_slot_contents[i] = null
		_set_slot_empty_style(i)
	
	var ordered_ids: Array[String] = _get_ordered_consumable_ids()
	var visible_count: int = mini(ordered_ids.size(), COMPACT_VISIBLE_CONSUMABLES)
	var overflow_count: int = ordered_ids.size() - COMPACT_VISIBLE_CONSUMABLES
	
	# Position visible spines in first slots
	for i in range(visible_count):
		var spine_id: String = ordered_ids[i]
		var spine: ConsumableSpine = _consumable_spines.get(spine_id)
		if spine:
			_assign_spine_to_slot(spine, i)
			spine.visible = true
	
	# Assign overflow spines to last slot (hidden)
	if overflow_count > 0:
		for i in range(COMPACT_VISIBLE_CONSUMABLES, ordered_ids.size()):
			var spine_id: String = ordered_ids[i]
			var spine: ConsumableSpine = _consumable_spines.get(spine_id)
			if spine:
				_assign_spine_to_slot(spine, COMPACT_SLOT_COUNT - 1)
				spine.visible = false
	
	# Update overflow indicator
	_update_overflow_slot(overflow_count)
	
	# Position compact row
	_adapt_layout()

func _get_ordered_consumable_ids() -> Array[String]:
	var result: Array[String] = []
	# Return IDs in acquisition order, filtering to only owned
	for id in _consumable_order:
		if _consumable_data.has(id):
			result.append(id)
	return result

func _on_spine_clicked(consumable_id: String) -> void:
	print("[ConsumableUI] Spine clicked:", consumable_id)
	
	if _is_animating:
		print("[ConsumableUI] Animation in progress, ignoring click")
		return
	
	if _current_state == State.SPINES:
		_selected_spine_id = consumable_id
		_fan_out_cards()
	elif _current_state == State.FANNED:
		# If clicking the same spine, fold back
		if _selected_spine_id == consumable_id:
			_fold_back_cards()
		else:
			# Switch to new spine
			_selected_spine_id = consumable_id
			_fan_out_cards()

func _get_fan_overlay() -> CanvasLayer:
	var root = get_tree().get_root()
	var overlay = root.get_node_or_null("SpineFanOverlay")
	if not overlay:
		overlay = CanvasLayer.new()
		overlay.name = "SpineFanOverlay"
		overlay.layer = 10
		root.add_child(overlay)
	return overlay as CanvasLayer


func _fan_out_cards() -> void:
	print("[ConsumableUI] Fanning out cards")
	_is_animating = true
	_current_state = State.FANNED
	
	# Play fan out sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_fan_out()
	
	# Use screen center for overlay positioning
	_fan_center = get_viewport_rect().size / 2.0
	
	# Reparent background to full-screen overlay so it's not clipped
	var overlay = _get_fan_overlay()
	if _background.get_parent() != overlay:
		_background.reparent(overlay, false)
		_background.position = Vector2.ZERO
		_background.size = get_viewport_rect().size
		_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Show background
	_background.visible = true
	_background.modulate.a = 0.0
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 1.0, 0.3)
	
	# Hide compact row
	if _compact_margin:
		var compact_tween: Tween = create_tween()
		compact_tween.tween_property(_compact_margin, "modulate:a", 0.0, 0.2)
		compact_tween.tween_callback(func(): _compact_margin.visible = false)
	
	# Wait a bit, then create and show fanned icons
	await get_tree().create_timer(0.2).timeout
	_create_fanned_icons()
	
	_is_animating = false

func _create_fanned_icons() -> void:
	# Clear existing fanned icons
	_clear_fanned_icons()
	
	var consumable_ids: Array = _consumable_data.keys()
	var count: int = consumable_ids.size()
	
	if count == 0:
		return
	
	# Calculate horizontal positions for cards
	var positions: Array[Vector2] = _calculate_fan_positions(count)
	
	var overlay = _get_fan_overlay()
	
	# Create and position icons
	for i in range(count):
		var consumable_id: String = consumable_ids[i]
		var data: ConsumableData = _consumable_data[consumable_id]
		var fan_pos: Vector2 = positions[i]
		
		# Create icon
		var icon: ConsumableIcon = consumable_icon_scene.instantiate()
		if not icon:
			continue
		
		overlay.add_child(icon)
		icon.set_data(data)
		icon.z_index = 10 + i  # Ensure cards are above background
		
		# Hide CardInfo/Title for cleaner fanned view
		var card_info: Control = icon.get_node_or_null("CardInfo")
		if card_info:
			card_info.visible = false
		
		# Connect signals - NOTE: These are different from PowerUp signals!
		if not icon.is_connected("consumable_used", _on_consumable_used):
			icon.consumable_used.connect(_on_consumable_used)
		if not icon.is_connected("consumable_sell_requested", _on_consumable_sell_requested):
			icon.consumable_sell_requested.connect(_on_consumable_sell_requested)
		
		# Store reference
		_fanned_icons[consumable_id] = icon
		
		# Position and animate icon
		icon.position = _fan_center 
		icon.modulate.a = 0.0
		icon.scale = Vector2(0.5, 0.5)
		
		print("[ConsumableUI] Card ", i, " (", consumable_id, ") - Start pos: ", icon.position, ", Target pos: ", fan_pos)
		
		# Animate to final position
		var tween: Tween = create_tween().set_parallel()
		tween.tween_property(icon, "position", fan_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
		tween.tween_property(icon, "modulate:a", 1.0, 0.3).set_delay(i * 0.05)
		tween.tween_property(icon, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.05)
	
	# Start idle animations after a delay
	await get_tree().create_timer(0.6).timeout
	_start_idle_animations()
	
	# Update consumable usability for all fanned icons
	update_consumable_usability()

func _calculate_fan_positions(count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	
	if count == 0:
		return positions
	
	# Card dimensions (match ConsumableIcon size)
	var card_width: float = 120.0  # ConsumableIcon width
	var spacing: float = 64.0  # Space between cards (prevents button overlap)
	var card_spacing: float = card_width + spacing  # Total space per card
	
	# Screen center
	var center_x: float = _fan_center.x
	var center_y: float = _fan_center.y
	
	print("[ConsumableUI] Calculating fan positions for ", count, " cards")
	print("[ConsumableUI] Center position: ", _fan_center)
	print("[ConsumableUI] Card width: ", card_width, ", Spacing: ", spacing, ", Total per card: ", card_spacing)
	
	if count == 1:
		# Single card in center
		var pos: Vector2 = Vector2(center_x - card_width / 2.0, center_y)
		positions.append(pos)
		print("[ConsumableUI] Single card position: ", pos)
	elif count == 2:
		# Two cards: left and right of center
		var offset: float = card_spacing / 2.0
		var left_pos: Vector2 = Vector2(center_x - offset - card_width / 2.0, center_y)
		var right_pos: Vector2 = Vector2(center_x + offset - card_width / 2.0, center_y)
		positions.append(left_pos)
		positions.append(right_pos)
		print("[ConsumableUI] Two cards - Left: ", left_pos, ", Right: ", right_pos)
	else:
		# Three or more cards: spread horizontally from center
		var total_width: float = (count - 1) * card_spacing
		var start_x: float = center_x - total_width / 2.0 - card_width / 2.0
		
		for i in range(count):
			var pos_x: float = start_x + i * card_spacing
			var pos: Vector2 = Vector2(pos_x, center_y)
			positions.append(pos)
			print("[ConsumableUI] Card ", i, " position: ", pos)
	
	return positions

## fold_back()
##
## Public method to fold back the fan-out view and hide background.
## Called when shop opens or other UI needs to dismiss the consumable fan.
func fold_back() -> void:
	print("[ConsumableUI] *** fold_back() CALLED — state=%s, _is_animating=%s ***" % [State.keys()[_current_state], _is_animating])
	print("[ConsumableUI]   Stack: ", get_stack())
	
	# Immediately hide background regardless of state
	if _background:
		_background.visible = false
		_background.modulate.a = 0.0
		# Reparent back from overlay if needed
		if _background.get_parent() != self:
			_background.reparent(self, false)
			_background.position = Vector2.ZERO
			_background.size = Vector2.ZERO
			_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# If we're in fanned state, clean up
	if _current_state == State.FANNED:
		_stop_idle_animations()
		
		# Immediately clear fanned icons
		for consumable_id in _fanned_icons.keys():
			var icon: ConsumableIcon = _fanned_icons[consumable_id]
			if icon and is_instance_valid(icon):
				icon.queue_free()
		_fanned_icons.clear()
		
		# Show compact row
		if _compact_margin:
			_compact_margin.visible = true
			_compact_margin.modulate.a = 1.0
		
		_current_state = State.SPINES
		_is_animating = false
	
	print("[ConsumableUI] fold_back() complete")

func _fold_back_cards() -> void:
	print("[ConsumableUI] *** _fold_back_cards() CALLED — state=%s, _is_animating=%s ***" % [State.keys()[_current_state], _is_animating])
	print("[ConsumableUI]   Stack: ", get_stack())
	_is_animating = true
	_current_state = State.SPINES
	
	# Play fan in sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_fan_in()
	
	# Stop idle animations
	_stop_idle_animations()
	
	# Hide background and reparent back to self after fade
	var bg_tween: Tween = create_tween()
	bg_tween.tween_property(_background, "modulate:a", 0.0, 0.3)
	bg_tween.tween_callback(func():
		_background.visible = false
		if _background.get_parent() != self:
			_background.reparent(self, false)
			_background.position = Vector2.ZERO
			_background.size = Vector2.ZERO
			_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	)
	
	# Animate fanned icons away
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			var tween: Tween = create_tween().set_parallel()
			tween.tween_property(icon, "scale", Vector2(0.2, 0.2), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(icon, "modulate:a", 0.0, 0.2)
			tween.tween_property(icon, "position", _fan_center, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Wait, then clear fanned icons and show compact row
	await get_tree().create_timer(0.3).timeout
	_clear_fanned_icons()
	
	# Show compact row
	if _compact_margin:
		_compact_margin.visible = true
		_compact_margin.modulate.a = 0.0
		var compact_tween: Tween = create_tween()
		compact_tween.tween_property(_compact_margin, "modulate:a", 1.0, 0.2)
	
	# Re-snap all spines to their correct base positions after fold back
	_position_spines()
	
	_selected_spine_id = ""
	_is_animating = false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED and not _is_animating:
			_fold_back_cards()
		elif _current_state == State.SPINES and not _is_animating:
			# Only fan out if we own consumables
			if _active_consumable_count > 0:
				_fan_out_cards()

func _clear_slot_ui(index: int) -> void:
	if index < 0 or index >= _slot_cells.size():
		return
	var cell: PanelContainer = _slot_cells[index]
	# Remove any spine from the SpineHost
	var spine_host: Control = cell.get_node_or_null("SpineHost")
	if spine_host:
		for child in spine_host.get_children():
			if child.get_parent() == spine_host:
				spine_host.remove_child(child)
	# Clear icon
	var icon_holder: TextureRect = cell.get_node_or_null("RowHBox/IconHolder")
	if icon_holder:
		icon_holder.texture = null
	# Reset labels
	var title_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Title")
	var desc_lbl: Label = cell.get_node_or_null("RowHBox/Labels/Desc")
	if title_lbl:
		title_lbl.text = ""
		title_lbl.visible = true
	if desc_lbl:
		desc_lbl.text = ""
		desc_lbl.visible = true

func _clear_fanned_icons() -> void:
	# Stop idle animations before freeing icons to prevent warnings
	_stop_idle_animations()
	
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			icon.queue_free()
	_fanned_icons.clear()

func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		print("[ConsumableUI] *** BACKGROUND CLICK — state=%s, _is_animating=%s, _overflow=%s ***" % [State.keys()[_current_state], _is_animating, _overflow_mode])
		# Block folding if in overflow mode
		if _overflow_mode:
			print("[ConsumableUI] Cannot close - must use or sell %d consumables first" % _overflow_target_count)
			return
		if _current_state == State.FANNED and not _is_animating:
			_fold_back_cards()

func _start_idle_animations() -> void:
	_stop_idle_animations()
	
	if _current_state != State.FANNED:
		return
	
	# Get the calculated fan positions (not the current positions)
	var consumable_ids: Array = _consumable_data.keys()
	var count: int = consumable_ids.size()
	var fan_positions: Array[Vector2] = _calculate_fan_positions(count)
	
	# Create gentle wave motion for fanned cards using their proper fan positions
	for i in range(count):
		var consumable_id: String = consumable_ids[i]
		var icon: ConsumableIcon = _fanned_icons.get(consumable_id)
		if not icon or i >= fan_positions.size() or not is_instance_valid(icon):
			continue
			
		var base_pos: Vector2 = fan_positions[i]
		var wave_offset: Vector2 = Vector2(randf_range(-5, 5), randf_range(-8, 8))
		var duration: float = randf_range(2.0, 4.0)
		
		var icon_tween: Tween = create_tween()
		icon_tween.set_loops(1000)  # Large finite number instead of infinite
		icon_tween.tween_property(icon, "position", base_pos + wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		icon_tween.tween_property(icon, "position", base_pos - wave_offset, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Track this tween for proper cleanup
		_idle_tweens.append(icon_tween)

func _on_consumable_used(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable used:", consumable_id)
	
	# Safe removal with count tracking
	if _has_consumables() and _consumable_data.has(consumable_id):
		# Call remove_consumable to handle all cleanup
		remove_consumable(consumable_id)
		
		# Re-emit signal for game controller to handle
		emit_signal("consumable_used", consumable_id)
	else:
		print("[ConsumableUI] WARNING: Tried to use non-existent consumable:", consumable_id)

func _on_spine_hovered(consumable_id: String, mouse_pos: Vector2) -> void:
	print("[ConsumableUI] Spine hovered:", consumable_id)
	
	if not _spine_tooltip or not _consumable_data.has(consumable_id):
		return
	
	# Show per-consumable tooltip
	var data: ConsumableData = _consumable_data[consumable_id]
	_spine_tooltip_label.text = data.display_name
	_spine_tooltip.visible = true
	var anchor_rect = Rect2(mouse_pos - Vector2(20, 20), Vector2(40, 40))
	_tfx.place_tooltip(_spine_tooltip, anchor_rect, SIDE_RIGHT, true)

func _on_spine_unhovered(consumable_id: String) -> void:
	print("[ConsumableUI] Spine unhovered:", consumable_id)
	
	if _spine_tooltip:
		_spine_tooltip.visible = false

func _on_consumable_sell_requested(consumable_id: String) -> void:
	print("[ConsumableUI] Consumable sell requested:", consumable_id)
	
	if _has_consumables() and _consumable_data.has(consumable_id):
		# Do NOT remove here — let GameController animate then remove via callback
		emit_signal("consumable_sold", consumable_id)

func update_consumable_usability() -> void:
	print("[ConsumableUI] Updating consumable usability for fanned icons")
	
	# Only update usability when cards are fanned out
	if _current_state != State.FANNED:
		return
	
	# Apply usability logic to fanned icons
	for consumable_id in _fanned_icons.keys():
		var icon: ConsumableIcon = _fanned_icons.get(consumable_id)
		var data: ConsumableData = _consumable_data.get(consumable_id)
		
		if not icon or not data or not is_instance_valid(icon):
			continue
		
		# Check if consumable can be used based on game state
		var is_useable: bool = _can_use_consumable(data)
		
		# Apply usability to icon (assuming ConsumableIcon has set_useable method)
		if icon.has_method("set_useable"):
			icon.set_useable(is_useable)

func _can_use_consumable(data: ConsumableData) -> bool:
	# Global check: All consumables require an active turn (prevents between-round usage)
	var game_controller = get_tree().get_first_node_in_group("game_controller")
	if game_controller and game_controller.turn_tracker:
		if not game_controller.turn_tracker.is_active:
			return false
	
	# Check specific consumable requirements
	match data.id:
		"any_score":
			# AnyScore requires dice values and at least one open category
			var dice_values = DiceResults.values
			if dice_values.is_empty():
				return false
			
			# Check for open categories via game controller
			if game_controller and game_controller.scorecard:
				var scorecard = game_controller.scorecard
				
				# Check upper section for open categories
				for category in scorecard.upper_scores.keys():
					if scorecard.upper_scores[category] == null:
						return true
				
				# Check lower section for open categories
				for category in scorecard.lower_scores.keys():
					if scorecard.lower_scores[category] == null:
						return true
				
				# No open categories found
				return false
			else:
				# No scorecard available
				return false
		"random_power_up_uncommon":
			# Random PowerUp consumable requires available PowerUp slots
			if game_controller and game_controller.powerup_ui:
				return not game_controller.powerup_ui.has_max_power_ups()
			else:
				# No PowerUpUI available, assume unusable
				return false
		"green_envy":
			# Green Envy requires dice to be rolled (to have values for scoring)
			var dice_values = DiceResults.values
			return not dice_values.is_empty()
		"empty_shelves":
			# Empty Shelves requires dice to be rolled (to have values for scoring)
			var dice_values = DiceResults.values
			return not dice_values.is_empty()
		"double_or_nothing":
			# Double or Nothing MUST be used at the beginning of the turn (after Next Turn auto-roll, before manual rolls)
			if game_controller and game_controller.turn_tracker:
				var turn_tracker = game_controller.turn_tracker
				# Can be used when rolls_left >= MAX_ROLLS - 1 (after auto-roll but before manual rolls)
				# and turn is active
				return turn_tracker.is_active and turn_tracker.rolls_left >= turn_tracker.MAX_ROLLS - 1
			else:
				# No turn tracker available, assume unusable
				return false
		"the_pawn_shop":
			# The Pawn Shop requires at least one PowerUp to sell
			if game_controller:
				return not game_controller.active_power_ups.is_empty()
			else:
				# No game controller available, assume unusable
				return false
		"one_free_mod":
			# One Free Mod requires an available dice slot for a mod
			if game_controller:
				var current_mod_count = game_controller._get_total_active_mod_count()
				var expected_dice_count = game_controller._get_expected_dice_count()
				return current_mod_count < expected_dice_count
			else:
				return false
		_:
			# Default: all other consumables are useable when fanned
			return true

func _stop_idle_animations() -> void:
	for tween in _idle_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_idle_tweens.clear()

## handle_consumable_overflow(excess_count)
##
## Called when player loses Extra Coupons powerup and has more consumables than the default max.
## Forces the fan-out view open and displays a message requiring the player to use or sell
## consumables until count is at or below max_consumables.
func handle_consumable_overflow(excess_count: int) -> void:
	print("[ConsumableUI] handle_consumable_overflow called with excess_count: %d" % excess_count)
	print("[ConsumableUI] Current state: %s, Active count: %d, Max: %d" % [State.keys()[_current_state], _active_consumable_count, max_consumables])
	
	if excess_count <= 0:
		print("[ConsumableUI] No overflow needed (excess <= 0)")
		return
	
	print("[ConsumableUI] Entering overflow mode - must reduce by %d consumables" % excess_count)
	_overflow_mode = true
	_overflow_target_count = excess_count
	
	# Force fan out if not already
	if _current_state == State.SPINES:
		print("[ConsumableUI] Currently in SPINES state, forcing fan out")
		_fan_out_cards()
		# Wait for fan out animation to complete
		await get_tree().create_timer(0.7).timeout
		print("[ConsumableUI] Fan out animation completed")
	else:
		print("[ConsumableUI] Already in FANNED state")
	
	# Create overflow label if it doesn't exist
	_create_overflow_label()
	_update_overflow_label()
	print("[ConsumableUI] Overflow label created and updated")

## _create_overflow_label()
##
## Creates the overflow warning label shown during overflow mode.
func _create_overflow_label() -> void:
	if _overflow_label and is_instance_valid(_overflow_label):
		return
	
	_overflow_label = Label.new()
	_overflow_label.name = "OverflowLabel"
	_overflow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overflow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Position above the fanned cards
	_overflow_label.position = Vector2(_fan_center.x - 200, _fan_center.y - 180)
	_overflow_label.custom_minimum_size = Vector2(400, 50)
	_overflow_label.z_index = 25
	
	# Style the label
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		_overflow_label.add_theme_font_override("font", vcr_font)
	_overflow_label.add_theme_font_size_override("font_size", 24)
	_overflow_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	_overflow_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_overflow_label.add_theme_constant_override("outline_size", 4)
	
	add_child(_overflow_label)

## _update_overflow_label()
##
## Updates the overflow label text with current excess count.
func _update_overflow_label() -> void:
	if _overflow_label and is_instance_valid(_overflow_label):
		_overflow_label.text = "Must Use or Sell %s Consumables" % NumberFormatter.format_int(_overflow_target_count)
		_overflow_label.visible = _overflow_mode

## _check_overflow_complete()
##
## Checks if overflow mode can be exited (consumable count <= max_consumables).
func _check_overflow_complete() -> void:
	if not _overflow_mode:
		return
	
	var excess: int = _active_consumable_count - max_consumables
	if excess <= 0:
		print("[ConsumableUI] Overflow resolved - exiting overflow mode")
		_overflow_mode = false
		_overflow_target_count = 0
		
		# Hide and cleanup overflow label
		if _overflow_label and is_instance_valid(_overflow_label):
			_overflow_label.queue_free()
			_overflow_label = null
		
		# Allow normal fan out closure
		_fold_back_cards()
	else:
		# Update remaining count
		_overflow_target_count = excess
		_update_overflow_label()
		print("[ConsumableUI] Still in overflow mode - %d excess remaining" % excess)

func _has_consumables() -> bool:
	return _active_consumable_count > 0

func remove_consumable(consumable_id: String) -> void:
	print("[ConsumableUI] Removing consumable:", consumable_id)
	
	if not _consumable_data.has(consumable_id):
		print("[ConsumableUI] WARNING: Tried to remove non-existent consumable:", consumable_id)
		return
	
	# Update count first
	_active_consumable_count -= 1
	
	# Remove from data storage
	_consumable_data.erase(consumable_id)
	
	# Remove from order tracking
	var order_index: int = _consumable_order.find(consumable_id)
	if order_index != -1:
		_consumable_order.remove_at(order_index)
	
	# Remove spine if it exists
	if _consumable_spines.has(consumable_id):
		var spine: ConsumableSpine = _consumable_spines[consumable_id]
		if spine and is_instance_valid(spine):
			# Disconnect signals to prevent events during destruction
			if spine.is_connected("spine_clicked", _on_spine_clicked):
				spine.spine_clicked.disconnect(_on_spine_clicked)
			if spine.is_connected("spine_hovered", _on_spine_hovered):
				spine.spine_hovered.disconnect(_on_spine_hovered)
			if spine.is_connected("spine_unhovered", _on_spine_unhovered):
				spine.spine_unhovered.disconnect(_on_spine_unhovered)
			
			# Remove from parent immediately to prevent mouse events
			if spine.get_parent():
				spine.get_parent().remove_child(spine)
			
			# Then queue for deletion
			spine.queue_free()
		_consumable_spines.erase(consumable_id)
	
	# Remove fanned icon if it exists
	if _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			# Disconnect signals to prevent events during destruction
			if icon.is_connected("consumable_used", _on_consumable_used):
				icon.consumable_used.disconnect(_on_consumable_used)
			if icon.is_connected("consumable_sell_requested", _on_consumable_sell_requested):
				icon.consumable_sell_requested.disconnect(_on_consumable_sell_requested)
			
			# Stop any ongoing tweens to prevent warnings
			if icon._current_tween and icon._current_tween.is_valid():
				icon._current_tween.kill()
			if icon._hover_card_tween and icon._hover_card_tween.is_valid():
				icon._hover_card_tween.kill()
			
			# Remove from parent immediately to prevent mouse events, then free
			if icon.get_parent():
				icon.get_parent().remove_child(icon)
			icon.queue_free()
		_fanned_icons.erase(consumable_id)
		
		# If we're in fanned state and have remaining consumables, recreate the fan layout
		if _current_state == State.FANNED:
			await get_tree().process_frame
			if _active_consumable_count > 0:
				_clear_fanned_icons()
				_create_fanned_icons()
			else:
				_cleanup_empty_state()
	
	# Reposition remaining spines
	_position_spines()
	
	# Update slots label
	update_slots_label()
	
	# Check if overflow mode can be exited
	if _overflow_mode:
		_check_overflow_complete()
	
	# Handle empty state
	if _active_consumable_count <= 0:
		_cleanup_empty_state()

func _cleanup_empty_state() -> void:
	print("[ConsumableUI] Cleaning up empty state")
	
	# Stop idle animations immediately
	_stop_idle_animations()
	
	# If we're in fanned state, immediately hide everything without animation
	if _current_state == State.FANNED:
		# Clear fanned icons immediately
		for consumable_id in _fanned_icons.keys():
			var icon: ConsumableIcon = _fanned_icons[consumable_id]
			if icon and is_instance_valid(icon):
				icon.queue_free()
		_fanned_icons.clear()
		
		# Hide background immediately
		_background.visible = false
		_background.modulate.a = 0.0
		
		# Reset state
		_current_state = State.SPINES
		_is_animating = false
	
	# Clear all references
	_consumable_spines.clear()
	_consumable_data.clear()
	_consumable_order.clear()
	_active_consumable_count = 0
	_selected_spine_id = ""

func update_slots_label() -> void:
	# Update the slots label to show current/max consumables
	var current: int = _active_consumable_count
	slots_label.text = "%s/%s" % [NumberFormatter.format_int(current), NumberFormatter.format_int(max_consumables)]
	
	# Ensure label has proper styling
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font and not slots_label.has_theme_font_override("font"):
		slots_label.add_theme_font_override("font", vcr_font)
		slots_label.add_theme_font_size_override("font_size", 16)
		slots_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		slots_label.add_theme_constant_override("outline_size", 2)
	
	# Change text color to red when at max capacity, otherwise white
	if current >= max_consumables:
		slots_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		slots_label.add_theme_color_override("font_color", Color(1, 1, 1))

func has_max_consumables() -> bool:
	"""Check if the maximum number of consumables has been reached"""
	return _active_consumable_count >= max_consumables

# Legacy compatibility methods - replace old icon access patterns
func get_consumable_spine(consumable_id: String) -> ConsumableSpine:
	"""Get the spine for a specific consumable (new spine system)"""
	if _consumable_spines.has(consumable_id):
		var spine: ConsumableSpine = _consumable_spines[consumable_id]
		if spine and is_instance_valid(spine):
			return spine
	return null

func get_fanned_icon(consumable_id: String) -> ConsumableIcon:
	"""Get the fanned icon for a specific consumable (only when fanned out)"""
	if _current_state == State.FANNED and _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and is_instance_valid(icon):
			return icon
	return null

func has_consumable(consumable_id: String) -> bool:
	"""Check if a consumable exists in the UI"""
	return _consumable_data.has(consumable_id)

func get_consumable_data(consumable_id: String) -> ConsumableData:
	"""Get the data for a specific consumable"""
	return _consumable_data.get(consumable_id)

func get_all_consumable_ids() -> Array[String]:
	"""Get all consumable IDs currently in the UI"""
	var ids: Array[String] = []
	for id in _consumable_data.keys():
		ids.append(id)
	return ids

func animate_consumable_removal(consumable_id: String, on_finished: Callable) -> void:
	# DEBUG: Log full state at entry
	var state_name: String = "SPINES" if _current_state == State.SPINES else "FANNED"
	print("[ConsumableUI] animate_consumable_removal('%s') — state=%s, _is_animating=%s" % [consumable_id, state_name, _is_animating])
	print("[ConsumableUI]   _fanned_icons keys: ", _fanned_icons.keys())
	print("[ConsumableUI]   _consumable_spines keys: ", _consumable_spines.keys())
	
	# Find target node to animate — prefer the VISIBLE representation
	# When fanned, the fanned icon is visible; when collapsed, the spine is visible
	var node: CanvasItem = null
	var node_source: String = "none"
	if _current_state == State.FANNED and _fanned_icons.has(consumable_id) and is_instance_valid(_fanned_icons[consumable_id]):
		node = _fanned_icons[consumable_id]
		node_source = "fanned_icon (FANNED state)"
	elif _consumable_spines.has(consumable_id) and is_instance_valid(_consumable_spines[consumable_id]):
		node = _consumable_spines[consumable_id]
		node_source = "spine"
	elif _fanned_icons.has(consumable_id) and is_instance_valid(_fanned_icons[consumable_id]):
		node = _fanned_icons[consumable_id]
		node_source = "fanned_icon (fallback)"
	
	print("[ConsumableUI]   Node source: %s, node=%s" % [node_source, node])
	
	if not node:
		print("[ConsumableUI] *** NO NODE FOUND — calling on_finished immediately ***")
		on_finished.call()
		return
	
	print("[ConsumableUI]   Node valid=%s, in_tree=%s, visible=%s, pos=%s" % [is_instance_valid(node), node.is_inside_tree(), node.visible, node.global_position])
	
	# Lock animating flag so fold_back doesn't fire during animation
	_is_animating = true
	
	# Play sell sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_sell_sound()
	
	# Find money label as fly target
	var fly_target: Vector2 = Vector2(100, 50)
	var tracker_ui = get_tree().get_first_node_in_group("turn_tracker_ui")
	if tracker_ui:
		var money_lbl = tracker_ui.get_node_or_null("MoneyLabel")
		if money_lbl:
			fly_target = money_lbl.global_position + money_lbl.size * 0.5
	
	print("[ConsumableUI]   Step 1: Jelly wobble starting...")
	# Step 1: Jelly wobble — item shakes as if being grabbed
	TweenFX.jelly(node, 0.25, 0.2, 2)
	await get_tree().create_timer(0.25).timeout
	
	# DEBUG: Check node state after await
	var still_valid: bool = is_instance_valid(node)
	var still_in_tree: bool = still_valid and node.is_inside_tree()
	var state_after: String = "SPINES" if _current_state == State.SPINES else "FANNED"
	print("[ConsumableUI]   After await: node_valid=%s, in_tree=%s, state=%s" % [still_valid, still_in_tree, state_after])
	
	if not still_valid:
		print("[ConsumableUI] *** NODE FREED DURING AWAIT — animation aborted ***")
		_is_animating = false
		on_finished.call()
		return
	
	print("[ConsumableUI]   Step 2: Fly tween starting → target=%s" % fly_target)
	# Step 2: Spin + shrink + fly toward money display
	var fly_tween: Tween = create_tween()
	fly_tween.set_parallel(true)
	fly_tween.tween_property(node, "global_position", fly_target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(node, "scale", Vector2(0.2, 0.2), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(node, "modulate:a", 0.0, 0.3)
	TweenFX.spin(node, 0.35, 1.0)
	
	fly_tween.finished.connect(func():
		print("[ConsumableUI]   Fly tween FINISHED — calling on_finished callback")
		_is_animating = false
		on_finished.call()
	)
	return

## animate_consumable_use(consumable_id, on_finished)
##
## Animated use removal for a consumable. Wild spin-off then explosion at exit point.
##
## Parameters:
##   consumable_id: String - the consumable to animate
##   on_finished: Callable - called when animation completes
func animate_consumable_use(consumable_id: String, on_finished: Callable) -> void:
	# Find target node to animate
	var node: CanvasItem = null
	if _consumable_spines.has(consumable_id) and is_instance_valid(_consumable_spines[consumable_id]):
		node = _consumable_spines[consumable_id]
	elif _fanned_icons.has(consumable_id) and is_instance_valid(_fanned_icons[consumable_id]):
		node = _fanned_icons[consumable_id]
	
	if not node:
		print("[ConsumableUI] No visual for use animation:", consumable_id)
		on_finished.call()
		return
	
	print("[ConsumableUI] Animating consumable use for:", consumable_id)
	
	# Wild fidget spin — "thrown" feeling
	TweenFX.fidget(node, 0.4, 6)
	await get_tree().create_timer(0.35).timeout
	
	# Fly off to a random direction
	var viewport_size: Vector2 = get_viewport_rect().size
	var edge_targets: Array[Vector2] = [
		Vector2(-100, randf_range(0, viewport_size.y)),
		Vector2(viewport_size.x + 100, randf_range(0, viewport_size.y)),
		Vector2(randf_range(0, viewport_size.x), -100),
		Vector2(randf_range(0, viewport_size.x), viewport_size.y + 100),
	]
	var fly_target: Vector2 = edge_targets[randi() % edge_targets.size()]
	
	var fly_tween: Tween = create_tween()
	fly_tween.set_parallel(true)
	fly_tween.tween_property(node, "global_position", fly_target, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(node, "scale", Vector2(0.1, 0.1), 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly_tween.tween_property(node, "modulate:a", 0.0, 0.25)
	TweenFX.spin(node, 0.3, 2.0)
	
	await fly_tween.finished
	
	# Trigger explosion at exit point
	var explosion_scene = preload("res://Scenes/Effects/ConsumableExplosion.tscn")
	if explosion_scene:
		var explosion = explosion_scene.instantiate()
		get_tree().root.add_child(explosion)
		explosion.global_position = fly_target
		if explosion.has_method("restart"):
			explosion.restart()
	
	print("[ConsumableUI] Consumable use animation complete:", consumable_id)
	on_finished.call()

# Deprecated method for backward compatibility - logs warning and returns null
func get_consumable_icon(consumable_id: String):
	push_warning("[ConsumableUI] get_consumable_icon() is deprecated. Use get_consumable_spine() or get_fanned_icon() instead.")
	print("[ConsumableUI] DEPRECATED: get_consumable_icon called for ID: ", consumable_id)
	print("[ConsumableUI] Current state: ", _current_state)
	print("[ConsumableUI] Available methods: get_consumable_spine(), get_fanned_icon(), has_consumable(), get_consumable_data()")
	
	# For temporary compatibility, return fanned icon if available
	if _current_state == State.FANNED:
		return get_fanned_icon(consumable_id)
	
	return null

## update_consumable_count(consumable_id, count)
##
## Updates the display count for a consumable type. This allows showing multiple instances
## of the same consumable without creating separate spines.
func update_consumable_count(consumable_id: String, count: int) -> void:
	print("[ConsumableUI] Updating consumable count for '%s' to %d" % [consumable_id, count])
	
	if _consumable_spines.has(consumable_id):
		var spine: ConsumableSpine = _consumable_spines[consumable_id]
		if spine and spine.has_method("set_count"):
			spine.set_count(count)
	
	# Also update fanned icons if they exist
	if _fanned_icons.has(consumable_id):
		var icon: ConsumableIcon = _fanned_icons[consumable_id]
		if icon and icon.has_method("set_count"):
			icon.set_count(count)

## Helper functions for consistent styling
func _apply_hover_tooltip_style(tooltip: PanelContainer) -> void:
	print("[ConsumableUI] Applying direct hover tooltip style")
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.247059, 0.219608, 0.345098, 0.98)
	style_box.border_color = Color(0.137255, 0.411765, 0.415686, 1.0)
	style_box.set_border_width_all(3)
	style_box.set_corner_radius_all(14)
	style_box.corner_detail = 8
	style_box.content_margin_left = 14
	style_box.content_margin_right = 14
	style_box.content_margin_top = 12
	style_box.content_margin_bottom = 12
	style_box.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.45)
	style_box.shadow_size = 4
	tooltip.add_theme_stylebox_override("panel", style_box)

func _apply_hover_label_style(label: Label) -> void:
	print("[ConsumableUI] Applying direct hover label style")
	# Load and apply VCR font
	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.968627, 0.941176, 1.0, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	label.add_theme_constant_override("outline_size", 1)
