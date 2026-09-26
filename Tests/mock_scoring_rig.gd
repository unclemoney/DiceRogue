extends Node
class_name MockScoringRig

## MockScoringRig
##
## Lightweight stand-ins for the nodes ScoringAnimationController looks up
## by group: a dice hand with mock dice, a consumable UI shelf, and a
## powerup UI shelf. Lets the scoring animation pipeline run in a bare test
## scene with synthetic breakdown_info, independent of real gameplay.
##
## Mock dice always use DiceColor.Type.NONE (owner resolution UNKNOWN-3).

const DIE_SIZE: Vector2 = Vector2(60, 60)
const DICE_ROW_Y: float = 480.0
const DICE_ROW_SPACING: float = 90.0
const CONSUMABLE_SHELF_X: float = 40.0
const CONSUMABLE_SHELF_Y: float = 260.0
const CONSUMABLE_SHELF_SPACING: float = 90.0
const POWERUP_SHELF_X: float = 1100.0
const POWERUP_SHELF_Y: float = 260.0
const POWERUP_SHELF_SPACING: float = 100.0
const MAX_DICE: int = 5

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

## MockDie
##
## Control-based stand-in for Dice. Exposes exactly the members the
## controller duck-types: value, color, sprite, position/global_position,
## animate_critical_flash().
class MockDie extends Control:
	var value: int = 1
	var color: DiceColor.Type = DiceColor.Type.NONE
	var sprite: Sprite2D = null

	var _bg: ColorRect
	var _label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size = DIE_SIZE
		_bg = ColorRect.new()
		_bg.color = Color(0.92, 0.92, 0.96, 1.0)
		_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_bg)
		_label = Label.new()
		_label.add_theme_font_override("font", VCR_FONT)
		_label.add_theme_font_size_override("font_size", 24)
		_label.add_theme_color_override("font_color", Color.BLACK)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_label)
		_refresh()

	func set_value(new_value: int) -> void:
		value = new_value
		if _label:
			_refresh()

	func _refresh() -> void:
		_label.text = str(value)

	func animate_critical_flash() -> void:
		var flash_tween = create_tween()
		flash_tween.tween_property(self, "modulate", Color(2.0, 2.0, 1.5, 1.0), 0.1)
		flash_tween.tween_property(self, "modulate", Color.WHITE, 0.25)

## MockDiceHand
##
## Node2D stand-in for DiceHand (group "dice_hand").
class MockDiceHand extends Node2D:
	var dice_list: Array = []

	func _ready() -> void:
		add_to_group("dice_hand")

	func get_all_dice() -> Array:
		return dice_list

	func animate_screen_shake(intensity: float = 1.0) -> void:
		print("[MockScoringRig] screen shake (intensity %.1f)" % intensity)
		var shake_magnitude = 3.0 * intensity
		var original_pos = position
		var shake_tween = create_tween()
		for i in range(6):
			shake_tween.tween_property(self, "position", original_pos + Vector2(randf_range(-shake_magnitude, shake_magnitude), randf_range(-shake_magnitude, shake_magnitude)), 0.025)
		shake_tween.tween_property(self, "position", original_pos, 0.025)

	func animate_celebration_cascade(intensity: float = 1.0) -> void:
		print("[MockScoringRig] celebration cascade (intensity %.1f)" % intensity)
		for i in range(dice_list.size()):
			var die = dice_list[i]
			if not is_instance_valid(die):
				continue
			var base_y = die.position.y
			var hop_tween = create_tween()
			hop_tween.tween_interval(i * 0.05)
			hop_tween.tween_property(die, "position:y", base_y - 18.0 * intensity, 0.1)
			hop_tween.tween_property(die, "position:y", base_y, 0.15).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

## MockConsumableUI
##
## Control stand-in for ConsumableUI (group "consumable_ui") holding a
## _consumable_spines dict of real ConsumableSpine instances.
class MockConsumableUI extends Control:
	var _consumable_spines := {}

	func _ready() -> void:
		add_to_group("consumable_ui")
		mouse_filter = Control.MOUSE_FILTER_IGNORE

## MockPowerUpUI
##
## Control stand-in for PowerUpUI (group "power_up_ui") holding a _spines
## dict of real PowerUpSpine instances.
class MockPowerUpUI extends Control:
	var _spines := {}

	func _ready() -> void:
		add_to_group("power_up_ui")
		mouse_filter = Control.MOUSE_FILTER_IGNORE

var dice_hand: MockDiceHand
var consumable_ui: MockConsumableUI
var power_up_ui: MockPowerUpUI

## _ready()
##
## Builds the dice hand with MAX_DICE mock dice and both spine shelves.
func _ready() -> void:
	dice_hand = MockDiceHand.new()
	dice_hand.name = "MockDiceHand"
	add_child(dice_hand)

	for i in range(MAX_DICE):
		var die = MockDie.new()
		die.name = "MockDie%d" % i
		die.position = _die_position(i)
		dice_hand.add_child(die)
		dice_hand.dice_list.append(die)

	consumable_ui = MockConsumableUI.new()
	consumable_ui.name = "MockConsumableUI"
	consumable_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(consumable_ui)

	power_up_ui = MockPowerUpUI.new()
	power_up_ui.name = "MockPowerUpUI"
	power_up_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(power_up_ui)

## configure(dice_values, consumable_ids, powerup_ids)
##
## Reshapes the rig for a scenario: dice show the given values (extras
## hidden), spine shelves rebuilt to hold exactly the given source ids.
func configure(dice_values: Array, consumable_ids: Array, powerup_ids: Array) -> void:
	for i in range(dice_hand.dice_list.size()):
		var die = dice_hand.dice_list[i]
		if i < dice_values.size():
			die.visible = true
			die.set_value(int(dice_values[i]))
			die.position = _die_position(i)
		else:
			die.visible = false

	_rebuild_spine_shelf(consumable_ui._consumable_spines, consumable_ui, consumable_ids, true)
	_rebuild_spine_shelf(power_up_ui._spines, power_up_ui, powerup_ids, false)

## _rebuild_spine_shelf(dict, parent_ui, ids, is_consumable)
##
## Frees old spines and creates fresh real spine instances per id.
func _rebuild_spine_shelf(dict: Dictionary, parent_ui: Control, ids: Array, is_consumable: bool) -> void:
	for key in dict.keys():
		var old_spine = dict[key]
		if is_instance_valid(old_spine):
			old_spine.queue_free()
	dict.clear()

	for i in range(ids.size()):
		var spine: Control
		if is_consumable:
			spine = ConsumableSpine.new()
			spine.position = Vector2(CONSUMABLE_SHELF_X, CONSUMABLE_SHELF_Y + i * CONSUMABLE_SHELF_SPACING)
		else:
			spine = PowerUpSpine.new()
			spine.position = Vector2(POWERUP_SHELF_X, POWERUP_SHELF_Y + i * POWERUP_SHELF_SPACING)
		spine.name = "Spine_%s" % str(ids[i])
		parent_ui.add_child(spine)
		dict[ids[i]] = spine

## _die_position(index) -> Vector2
##
## Bottom-center dice row slot for the given die index.
func _die_position(index: int) -> Vector2:
	var row_width = (MAX_DICE - 1) * DICE_ROW_SPACING
	var start_x = (1280.0 - row_width) / 2.0
	return Vector2(start_x + index * DICE_ROW_SPACING, DICE_ROW_Y)
