extends Control
class_name MoneyUI

## MoneyUI
##
## Displays player money with animated changes.
## Connects to PlayerEconomy autoload signal.

var _money_label: Label
var _money_tween: Tween

const VCR_GREEN := Color(0.2, 1.0, 0.3, 1.0)
const VCR_GREEN_BRIGHT := Color(0.4, 1.0, 0.5, 1.0)
const VCR_RED := Color(1.0, 0.2, 0.2, 1.0)


func _ready() -> void:
	_create_ui()
	if PlayerEconomy:
		PlayerEconomy.money_changed.connect(_on_money_changed)
		_update_money_display(PlayerEconomy.get_money())


func _create_ui() -> void:
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchors_preset = Control.PRESET_FULL_RECT
	add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "MONEY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)

	_money_label = Label.new()
	_money_label.name = "MoneyLabel"
	_money_label.text = "$0"
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_font_size_override("font_size", 28)
	_money_label.add_theme_color_override("font_color", VCR_GREEN)
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
		_money_tween.parallel().tween_property(_money_label, "modulate", VCR_GREEN_BRIGHT, 0.15)
		_money_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_IN_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", VCR_GREEN, 0.3)
	elif change < 0:
		_money_tween.tween_property(_money_label, "scale", Vector2(1.2, 1.2), 0.15).set_ease(Tween.EASE_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", VCR_RED, 0.15)
		_money_tween.tween_property(_money_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_IN_OUT)
		_money_tween.parallel().tween_property(_money_label, "modulate", VCR_GREEN, 0.3)
