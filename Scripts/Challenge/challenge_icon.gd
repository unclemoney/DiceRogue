extends Control
class_name ChallengeIcon

## ChallengeIcon
##
## Compact chip-style UI for a single challenge displayed inside challenge_container.
## Shows: name label, progress bar, difficulty stars + target score.
## All hover scale-up and shader effects removed. mouse_filter = IGNORE so
## ChallengeUI intercepts all input.

signal challenge_selected(id: String)

@export var data: ChallengeData

# Difficulty tint by tier: 0=white, 1=green, 2=yellow, 3=orange, 4=red, 5=purple
const DIFFICULTY_TINTS: Array[Color] = [
	Color(1.0, 1.0, 1.0),
	Color(0.4, 1.0, 0.4),
	Color(1.0, 0.9, 0.2),
	Color(1.0, 0.55, 0.1),
	Color(1.0, 0.25, 0.25),
	Color(0.75, 0.3, 1.0),
]

# Node references
var _name_label: Label
var _progress_bar: ProgressBar
var _meta_label: Label
var _bg_rect: ColorRect

var is_active := false
var _current_tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(100, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	_apply_data_to_ui()

func _build_ui() -> void:
	# Background rect — tinted by difficulty
	_bg_rect = ColorRect.new()
	_bg_rect.name = "BgRect"
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.color = Color(0.10, 0.08, 0.14, 0.85)
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg_rect)

	# Try to load chip art — falls back gracefully if not present
	var chip_tex := TextureRect.new()
	chip_tex.name = "ChipArt"
	chip_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	chip_tex.stretch_mode = TextureRect.STRETCH_SCALE
	chip_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_texture = load("res://Resources/Art/UI/challenge_chip.png")
	if chip_texture:
		chip_tex.texture = chip_texture
	add_child(chip_tex)

	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 4
	vbox.offset_top = 4
	vbox.offset_right = -4
	vbox.offset_bottom = -4
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	# Name label — single line, trim if too long
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_name_label.add_theme_font_override("font", vcr_font)
	_name_label.add_theme_font_size_override("font_size", 10)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	_name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	vbox.add_child(_name_label)

	# Progress bar — 8px tall, gold fill
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress_bar.custom_minimum_size = Vector2(0, 8)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg_style = StyleBoxFlat.new()
	fg_style.bg_color = Color(0.9, 0.75, 0.2, 1.0)
	fg_style.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("fill", fg_style)
	var pb_bg = StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.08, 0.08, 0.08, 0.7)
	pb_bg.set_corner_radius_all(3)
	_progress_bar.add_theme_stylebox_override("background", pb_bg)
	vbox.add_child(_progress_bar)

	# Meta label: difficulty stars + pts target
	_meta_label = Label.new()
	_meta_label.name = "MetaLabel"
	_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meta_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meta_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meta_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_meta_label.add_theme_font_override("font", vcr_font)
	_meta_label.add_theme_font_size_override("font_size", 9)
	_meta_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
	vbox.add_child(_meta_label)

func _apply_data_to_ui() -> void:
	if not data:
		return

	if _name_label:
		_name_label.text = data.display_name if data.display_name else data.id

	if _meta_label:
		var stars := _build_star_string(data.difficulty)
		var pts_text := "%s pts" % NumberFormatter.format_score(data.target_score)
		_meta_label.text = "%s · %s" % [stars, pts_text]

	# Tint background by difficulty
	if _bg_rect:
		var tier: int = clamp(data.difficulty, 0, 5)
		var tint: Color = DIFFICULTY_TINTS[tier]
		_bg_rect.color = Color(
			0.10 * tint.r + 0.04,
			0.08 * tint.g + 0.04,
			0.14 * tint.b + 0.04,
			0.85
		)

func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result

## set_data(new_data)
## Updates the icon with a new ChallengeData resource.
func set_data(new_data: ChallengeData) -> void:
	data = new_data
	_apply_data_to_ui()

## set_data_with_target_score(new_data, target_score)
## Sets data and overrides the target_score field.
func set_data_with_target_score(new_data: ChallengeData, target_score: int) -> void:
	data = new_data
	data.target_score = target_score
	_apply_data_to_ui()

## set_progress(value)
## Updates the progress bar. value is 0.0–1.0.
func set_progress(value: float) -> void:
	if _progress_bar:
		var tween = create_tween()
		tween.tween_property(_progress_bar, "value", value * 100.0, 0.2)

## set_active(active)
## Highlights the icon modulate when the challenge is active.
func set_active(active: bool) -> void:
	is_active = active
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
	_current_tween = create_tween()
	if active:
		_current_tween.tween_property(self, "modulate", Color(0.6, 1.2, 0.6), 0.3)
	else:
		_current_tween.tween_property(self, "modulate", Color.WHITE, 0.3)

## animate_target_score_countup(duration)
## Animates the meta label pts value from 0 to the actual target score.
func animate_target_score_countup(duration: float = 0.8) -> void:
	if not _meta_label or not data:
		return
	var goal := data.target_score if data.target_score != null else 0
	if goal <= 0:
		return
	var stars := _build_star_string(data.difficulty)
	var tween = create_tween()
	tween.tween_method(func(v: float):
		_meta_label.text = "%s · %s pts" % [stars, NumberFormatter.format_score(int(v))]
	, 0.0, float(goal), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
