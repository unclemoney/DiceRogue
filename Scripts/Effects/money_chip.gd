extends Control
class_name MoneyChip

## MoneyChip
##
## A single "-N" chip for the Mom money pull. Spawns at the money display
## and arcs toward the Mom portrait; MomJuiceCoordinator owns the flight,
## arrival tick, and cleanup. Visual shell only.

const VCR_FONT = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

const CHIP_SIZE: Vector2 = Vector2(30, 22)
const CHIP_FILL: Color = Color(0.247059, 0.219608, 0.345098, 0.92)
const CHIP_BORDER: Color = Color(0.713725, 0.301961, 0.478431, 1.0)
const CHIP_SHADOW: Color = Color(0.070588, 0.062745, 0.101961, 0.45)
const TEXT_NEGATIVE: Color = Color(1.0, 0.470588, 0.576471, 1.0)
const TEXT_OUTLINE: Color = Color(0.129412, 0.121569, 0.2, 1.0)

var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = RenderLayers.Z_SCREEN_FX
	size = CHIP_SIZE
	custom_minimum_size = CHIP_SIZE
	pivot_offset = CHIP_SIZE / 2.0

	var shell := Panel.new()
	shell.name = "ChipShell"
	shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = CHIP_FILL
	style.border_color = CHIP_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.corner_detail = 6
	style.shadow_color = CHIP_SHADOW
	style.shadow_size = 4
	shell.add_theme_stylebox_override("panel", style)
	add_child(shell)

	_label = Label.new()
	_label.name = "ChipLabel"
	_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_override("font", VCR_FONT)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", TEXT_NEGATIVE)
	_label.add_theme_color_override("font_outline_color", TEXT_OUTLINE)
	_label.add_theme_constant_override("outline_size", 1)
	add_child(_label)


## setup(text)
##
## Sets the chip's label (e.g. "-1", or "-3" when the chip cap batches units).
func setup(text: String) -> void:
	if _label:
		_label.text = text
