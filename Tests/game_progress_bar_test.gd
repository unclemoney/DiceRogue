extends Control

## game_progress_bar_test.gd
##
## Visual test for GameProgressBar: teal (Challenge), pink (Bonus), gold
## (resources) bars with tweened fills, tick notches, threshold marker and
## the overflow layer. Buttons drive value changes; the teal bar auto-runs
## an overflow demo after a beat so the scene works for screenshots too.
## Run windowed: godot --path . Tests/GameProgressBarTest.tscn

const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var _teal_bar: GameProgressBar
var _pink_bar: GameProgressBar
var _gold_bar: GameProgressBar


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.07, 0.11, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	_teal_bar = _add_scheme_row(column, "CHALLENGE (teal, ticks + threshold @75)",
		Color(0.549020, 0.729412, 0.662745, 1.0), true, 75.0)
	_pink_bar = _add_scheme_row(column, "BONUS (pink)",
		Color(0.901961, 0.450980, 0.556863, 1.0), false, -1.0)
	_gold_bar = _add_scheme_row(column, "RESOURCES (gold)",
		Color(0.95, 0.78, 0.3, 1.0), false, -1.0)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	column.add_child(buttons)
	_add_button(buttons, "Fill 5%", func(): _set_all(5.0))
	_add_button(buttons, "Fill 50%", func(): _set_all(50.0))
	_add_button(buttons, "Fill 100%", func(): _set_all(100.0))
	_add_button(buttons, "Overflow 120", func(): _set_all(120.0))
	_add_button(buttons, "Reset", func(): _set_all(0.0))

	# Auto demo: 5% (bleed check), 50%, 100%, then overflow, with shots
	# mid-sheen and after the sheen freezes (~2s later)
	await get_tree().create_timer(0.6).timeout
	_set_all(5.0)
	await get_tree().create_timer(0.6).timeout
	_shot("gpb2_fill_05_sheen.png")
	await get_tree().create_timer(2.4).timeout
	_shot("gpb2_fill_05_frozen.png")
	_set_all(50.0)
	await get_tree().create_timer(0.6).timeout
	_shot("gpb2_fill_50.png")
	_set_all(100.0)
	await get_tree().create_timer(0.6).timeout
	_shot("gpb2_fill_100.png")
	_set_all(120.0)
	await get_tree().create_timer(0.5).timeout
	_shot("gpb2_overflow_sheen.png")
	await get_tree().create_timer(2.4).timeout
	_shot("gpb2_overflow_frozen.png")


func _shot(file_name: String) -> void:
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var path := "res://Tests/_layout_shots/" + file_name
	var err := img.save_png(path)
	print("[GPBTest] saved %s (err=%d)" % [path, err])


func _add_scheme_row(parent: Control, caption: String, color: Color, ticks: bool, threshold_value: float) -> GameProgressBar:
	var label := Label.new()
	label.text = caption
	label.add_theme_font_override("font", VCR_FONT)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.87, 1.0))
	parent.add_child(label)

	var bar := GameProgressBar.new()
	bar.max_value = 100.0
	bar.fill_color = color
	bar.show_ticks = ticks
	bar.threshold = threshold_value
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(bar)
	return bar


func _add_button(parent: Control, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)


func _set_all(v: float) -> void:
	_teal_bar.value = v
	_pink_bar.value = v
	_gold_bar.value = v
