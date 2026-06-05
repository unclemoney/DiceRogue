extends Control
class_name DebuffUI

## DebuffUI
##
## Compact fixed-slot row showing up to 3 debuff chips + overflow "+N" chip.
## Click the panel to fan-out all debuffs as DebuffDetailCard overlays.
## Fold-back by clicking the dim background.

signal debuff_selected(id: String)

@export var debuff_icon_scene: PackedScene = preload("res://Scenes/Debuff/DebuffIcon.tscn")

const MAX_COMPACT_VISIBLE: int = 3
const SLOT_COUNT: int = 4
const SLOT_SIZE: Vector2 = Vector2(64, 68)

var container: HBoxContainer
var _icons: Dictionary = {}             # id -> DebuffIcon
var _sorted_debuff_ids: Array[String] = []
var _plus_chip: Control = null
var _detail_cards: Dictionary = {}      # id -> DebuffDetailCard

# Fixed slots
var _slot_cells: Array[PanelContainer] = []
var _slot_contents: Array[Control] = []

# Fan-out state
enum State { NORMAL, FANNED_OUT }
var _current_state: State = State.NORMAL
var _background: ColorRect


func _ready() -> void:
	print("[DebuffUI] Initializing...")

	# Clear any legacy children from older scene versions
	for old_name in ["Label", "VBoxContainer", "Container"]:
		var old_node := get_node_or_null(old_name)
		if old_node:
			old_node.free()

	container = HBoxContainer.new()
	container.name = "Container"
	container.mouse_filter = Control.MOUSE_FILTER_PASS
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 8)
	add_child(container)

	_create_compact_slots()

	if not debuff_icon_scene:
		debuff_icon_scene = load("res://Scenes/Debuff/DebuffIcon.tscn")
		if not debuff_icon_scene:
			push_error("[DebuffUI] Failed to load debuff_icon_scene!")

	mouse_filter = Control.MOUSE_FILTER_STOP
	print("[DebuffUI] Initialization complete")


func _create_compact_slots() -> void:
	_slot_cells.clear()
	_slot_contents.clear()
	for i in range(SLOT_COUNT):
		var slot := PanelContainer.new()
		slot.name = "Slot%d" % i
		slot.custom_minimum_size = SLOT_SIZE
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.12, 0.10, 0.14, 0.3)
		style.border_color = Color(0.3, 0.25, 0.35, 0.15)
		style.set_border_width_all(1)
		style.set_corner_radius_all(10)
		style.corner_detail = 6
		slot.add_theme_stylebox_override("panel", style)
		container.add_child(slot)
		_slot_cells.append(slot)
		_slot_contents.append(null)
	print("[DebuffUI] Created %d fixed slots" % SLOT_COUNT)


func _get_fan_overlay() -> CanvasLayer:
	return FanOverlayHelper.get_overlay(self)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if _current_state == State.FANNED_OUT:
			_fold_back_debuffs()
			get_viewport().set_input_as_handled()
		elif _current_state == State.NORMAL:
			if not _icons.is_empty():
				_fan_out_debuffs()
				get_viewport().set_input_as_handled()


func _fan_out_debuffs() -> void:
	if _current_state == State.FANNED_OUT:
		return
	_current_state = State.FANNED_OUT

	var overlay := _get_fan_overlay()
	var viewport_size := get_viewport_rect().size

	_background = FanOverlayHelper.create_background("DebuffFanBackground")
	overlay.add_child(_background)
	_background.visible = true
	_background.gui_input.connect(_on_background_clicked)

	# Hide compact icons and overflow chip
	for icon in _icons.values():
		(icon as DebuffIcon).visible = false
	if is_instance_valid(_plus_chip):
		_plus_chip.visible = false

	_detail_cards.clear()

	var ids := _sorted_debuff_ids
	var count := ids.size()
	if count == 0:
		return

	var card_width := 220.0
	var spacing := 240.0
	var total_width := (count - 1) * spacing + card_width
	if count > 1 and total_width > viewport_size.x - 40:
		spacing = (viewport_size.x - 40 - card_width) / (count - 1)
		total_width = (count - 1) * spacing + card_width
	var start_x := (viewport_size.x - total_width) / 2.0
	var center_y := viewport_size.y / 2.0

	for i in range(count):
		var id: String = ids[i]
		var icon: DebuffIcon = _icons.get(id)
		if not icon or not icon.data:
			continue

		var card := DebuffDetailCard.new()
		overlay.add_child(card)
		card.z_index = 200 + i

		var target_x := start_x + i * spacing
		var target_y := center_y - DebuffDetailCard.CARD_SIZE.y / 2.0
		var target_pos := Vector2(target_x, target_y)

		card.setup(icon.data)

		# Staggered drop-in animation
		card.position = target_pos - Vector2(0, 300)
		card.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(i * 0.06)
		tween.tween_property(card, "position", target_pos, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(card, "modulate:a", 1.0, 0.35)

		_detail_cards[id] = card


func _fold_back_debuffs() -> void:
	if _current_state == State.NORMAL:
		return
	_current_state = State.NORMAL

	for card in _detail_cards.values():
		if is_instance_valid(card):
			(card as DebuffDetailCard).queue_free()
	_detail_cards.clear()

	if _background:
		_background.queue_free()
		_background = null

	_refresh_compact_view()


func _on_background_clicked(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_fold_back_debuffs()


## _refresh_compact_view()
##
## Assigns icons to fixed slots (first 3) and overflow chip (slot 3).
func _refresh_compact_view() -> void:
	# Clear all slots first (reparent children to self without freeing)
	for i in range(SLOT_COUNT):
		var slot: PanelContainer = _slot_cells[i]
		if slot:
			for child in slot.get_children():
				if child.get_parent() == slot:
					slot.remove_child(child)
					add_child(child)
		_slot_contents[i] = null

	var count := _sorted_debuff_ids.size()
	var visible_count := mini(count, MAX_COMPACT_VISIBLE)

	# Assign visible icons to slots 0-2
	for i in range(visible_count):
		var id: String = _sorted_debuff_ids[i]
		var icon: DebuffIcon = _icons.get(id)
		if icon and is_instance_valid(icon):
			icon.visible = true
			if icon.get_parent():
				icon.get_parent().remove_child(icon)
			_slot_cells[i].add_child(icon)
			_slot_contents[i] = icon

	# Hide any icons not in visible slots
	for i in range(visible_count, count):
		var id: String = _sorted_debuff_ids[i]
		var icon: DebuffIcon = _icons.get(id)
		if icon:
			icon.visible = false
			if icon.get_parent():
				icon.get_parent().remove_child(icon)
			add_child(icon)

	# Overflow chip in slot 3
	var overflow := count - MAX_COMPACT_VISIBLE
	if overflow > 0:
		if not is_instance_valid(_plus_chip):
			_plus_chip = _create_plus_chip()
		var chip_label: Label = _plus_chip.get_node_or_null("ChipLabel")
		if chip_label:
			chip_label.text = "+%d" % overflow
		_plus_chip.visible = true
		_slot_cells[MAX_COMPACT_VISIBLE].add_child(_plus_chip)
		_slot_contents[MAX_COMPACT_VISIBLE] = _plus_chip
	else:
		if is_instance_valid(_plus_chip):
			_plus_chip.queue_free()
		_plus_chip = null


func _create_plus_chip() -> Control:
	var chip := PanelContainer.new()
	chip.name = "PlusChip"
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.247059, 0.219608, 0.345098, 0.9)
	style.border_color = Color(0.713725, 0.301961, 0.478431, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.shadow_color = Color(0.070588, 0.062745, 0.101961, 0.35)
	style.shadow_size = 3
	chip.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.name = "ChipLabel"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vcr_font := load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	if vcr_font:
		lbl.add_theme_font_override("font", vcr_font)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.968627, 0.941176, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.129412, 0.121569, 0.2, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	chip.add_child(lbl)

	return chip


func add_debuff(data: DebuffData, debuff_instance: Debuff = null) -> DebuffIcon:
	print("[DebuffUI] Adding debuff to UI:", data.id if data else "null")

	if not debuff_icon_scene:
		push_error("[DebuffUI] debuff_icon_scene not set!")
		return null

	if _icons.has(data.id):
		print("[DebuffUI] Debuff already exists:", data.id)
		return _icons[data.id]

	var icon := debuff_icon_scene.instantiate() as DebuffIcon
	if not icon:
		push_error("[DebuffUI] Failed to instantiate DebuffIcon")
		return null

	# Add to self (not container) so _refresh_compact_view can manage slot placement
	add_child(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_data(data)
	icon.set_meta("last_pos", icon.position)

	_icons[data.id] = icon
	_sorted_debuff_ids.append(data.id)
	_refresh_compact_view()

	# Juice: debuff acquisition effect
	var tfx := get_node_or_null("/root/TweenFXHelper")
	if tfx:
		tfx.negative_hit(icon)
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_denied_sound"):
		audio_mgr.play_denied_sound()

	if debuff_instance:
		debuff_instance.debuff_started.connect(func():
			icon.set_active(true)
			print("[DebuffUI] Debuff started:", data.id))
		debuff_instance.debuff_ended.connect(func():
			icon.set_active(false)
			print("[DebuffUI] Debuff ended:", data.id))

	if not icon.is_connected("debuff_selected", _on_debuff_selected):
		icon.debuff_selected.connect(_on_debuff_selected)

	print("[DebuffUI] Added debuff icon:", data.id)
	return icon


func _on_debuff_selected(id: String) -> void:
	print("[DebuffUI] Debuff selected:", id)
	emit_signal("debuff_selected", id)


func remove_debuff(id: String) -> void:
	if not _icons.has(id):
		return

	var icon: DebuffIcon = _icons[id]
	if icon:
		var tfx := get_node_or_null("/root/TweenFXHelper")
		if tfx:
			tfx.icon_remove(icon)
			await get_tree().create_timer(0.3).timeout
		if is_instance_valid(icon):
			# Remove from slot if present
			if icon.get_parent():
				icon.get_parent().remove_child(icon)
			icon.queue_free()

	_icons.erase(id)
	_sorted_debuff_ids.erase(id)
	_refresh_compact_view()

	_icons.erase(id)
	_sorted_debuff_ids.erase(id)
	print("[DebuffUI] Removed debuff icon:", id)

	await get_tree().process_frame
	_refresh_compact_view()


func get_debuff_icon(id: String) -> DebuffIcon:
	return _icons.get(id)


## clear_all_debuffs()
##
## Frees all icons and resets state. Called by GameController on channel start.
func clear_all_debuffs() -> void:
	for icon in _icons.values():
		if is_instance_valid(icon):
			icon.queue_free()
	_icons.clear()
	_sorted_debuff_ids.clear()
	if is_instance_valid(_plus_chip):
		_plus_chip.queue_free()
	_plus_chip = null
	print("[DebuffUI] Cleared all debuffs")


func animate_debuff_shift() -> void:
	pass  # HBoxContainer manages positions automatically


func animate_debuff_removal(debuff_id: String, on_finished: Callable) -> void:
	var icon := get_debuff_icon(debuff_id)
	if icon:
		var tween := create_tween()
		tween.tween_property(icon, "scale", Vector2(1.2, 0.2), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(icon, "scale", Vector2(0.0, 0.0), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(icon, "modulate:a", 0.0, 0.2)
		tween.finished.connect(on_finished)
	else:
		print("[DebuffUI] No icon found for debuff, skipping animation:", debuff_id)
		on_finished.call()
