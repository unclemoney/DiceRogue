extends Control
class_name MoneyUI

## MoneyUI
##
## Displays player money with animated changes.
## Connects to PlayerEconomy autoload signal.

var _money_label: Label
var _money_tween: Tween

const SURFACE_TEXT := Color(0.968627, 0.941176, 1.0, 1.0)
const POSITIVE_FLASH := Color(0.137255, 0.411765, 0.415686, 1.0)
const POSITIVE_GLOW := Color(0.47451, 0.886275, 0.890196, 1.0)
const NEGATIVE_FLASH := Color(0.713725, 0.301961, 0.478431, 1.0)
const LABEL_OUTLINE := Color(0.247059, 0.219608, 0.345098, 1.0)


func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_create_ui()
	if PlayerEconomy:
		PlayerEconomy.money_changed.connect(_on_money_changed)
		_update_money_display(PlayerEconomy.get_money())


func _create_ui() -> void:
	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(vbox)

	_money_label = Label.new()
	_money_label.name = "MoneyLabel"
	_money_label.text = "$0"
	_money_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_override("font", preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf"))
	_money_label.add_theme_font_size_override("font_size", 32)
	_money_label.add_theme_color_override("font_color", SURFACE_TEXT)
	_money_label.add_theme_color_override("font_outline_color", LABEL_OUTLINE)
	_money_label.add_theme_color_override("font_shadow_color", POSITIVE_FLASH)
	_money_label.add_theme_constant_override("outline_size", 2)
	_money_label.add_theme_constant_override("shadow_outline_size", 2)
	_money_label.add_theme_constant_override("shadow_offset_x", 0)
	_money_label.add_theme_constant_override("shadow_offset_y", 0)
	vbox.add_child(_money_label)


func _on_money_changed(new_amount: int, change: int = 0) -> void:
	_update_money_display(new_amount)
	_animate_money_change(change)


func _update_money_display(amount: int) -> void:
	_money_label.text = "$%d" % amount


func _animate_money_change(change: int) -> void:
	if _money_tween and _money_tween.is_valid():
		_money_tween.kill()
	_money_tween = create_tween()

	if change > 0:
		_money_tween.tween_property(_money_label, "scale", Vector2(1.3, 1.3), 0.15).set_ease(Tween.EASE_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", POSITIVE_GLOW, 0.15)
		_money_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_IN_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", SURFACE_TEXT, 0.3)
	elif change < 0:
		_money_tween.tween_property(_money_label, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", NEGATIVE_FLASH, 0.15)
		_money_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_IN_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", SURFACE_TEXT, 0.3)
