extends SubViewportContainer
class_name GlowingTitle

## GlowingTitle
##
## A reusable text title using a SubViewport with a standard Label.
## Glow effect is disabled; text renders as plain white (or configured color).
## SubViewport architecture is kept for future shader integration.
##
## Side-effects: Creates and configures SubViewport and Label in _ready().

@export var text: String = "Title"
@export var font_size: int = 24
@export var font_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var font_path: String = "res://Resources/Font/PumpDemiBoldPlain.otf"
@export var glow_intensity: float = 0.0

var _viewport: SubViewport
var _label: Label

const DEFAULT_VIEWPORT_WIDTH: int = 400
const DEFAULT_VIEWPORT_HEIGHT: int = 64


func _ready() -> void:
	_create_viewport()
	stretch = true
	_create_label()
	_update_text()
	_update_viewport_size()


func _create_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "SubViewport"
	_viewport.size = Vector2i(DEFAULT_VIEWPORT_WIDTH, DEFAULT_VIEWPORT_HEIGHT)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)


func _create_label() -> void:
	_label = Label.new()
	_label.name = "TitleLabel"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_label.size = Vector2(DEFAULT_VIEWPORT_WIDTH, DEFAULT_VIEWPORT_HEIGHT)
	_label.position = Vector2.ZERO
	if font_path:
		var font = load(font_path)
		if font:
			_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", font_size)
	_label.add_theme_color_override("font_color", font_color)
	_viewport.add_child(_label)
	custom_minimum_size = Vector2(DEFAULT_VIEWPORT_WIDTH, DEFAULT_VIEWPORT_HEIGHT)


func _update_text() -> void:
	if _label == null:
		return
	_label.text = text
	_call_deferred_size_update()


func _call_deferred_size_update() -> void:
	await get_tree().process_frame
	_update_viewport_size()


func _update_viewport_size() -> void:
	if _label == null or _viewport == null:
		return
	var font := _label.get_theme_font("font")
	var font_sz := _label.get_theme_font_size("font_size")
	var text_width := 0
	if font:
		text_width = int(font.get_string_size(_label.text, _label.horizontal_alignment, -1, font_sz).x)
	var line_count := _label.get_line_count()
	var line_height := _label.get_line_height()
	var content_size := line_count * line_height
	var new_width := int(maxf(text_width + 24.0, 64.0))
	var new_height := int(maxf(content_size + 8.0, 32.0))
	var new_size := Vector2i(new_width, new_height)
	# Temporarily disable stretch to avoid Godot warning when resizing SubViewport
	var was_stretch := stretch
	stretch = false
	_viewport.size = new_size
	stretch = was_stretch
	_label.size = Vector2(new_size)
	custom_minimum_size = Vector2(new_width, new_height)


## set_text()
##
## Updates the displayed text and resizes the viewport to fit.
func set_text(new_text: String) -> void:
	text = new_text
	_update_text()


## set_font_color()
##
## Updates the text color.
func set_font_color(new_color: Color) -> void:
	font_color = new_color
	if _label:
		_label.add_theme_color_override("font_color", font_color)


## set_font_size()
##
## Updates the font size.
func set_font_size(new_size: int) -> void:
	font_size = new_size
	if _label:
		_label.add_theme_font_size_override("font_size", font_size)
		_update_viewport_size()


## set_glow_intensity()
##
## No-op: glow is disabled. Kept for API compatibility.
func set_glow_intensity(value: float) -> void:
	glow_intensity = 0.0
