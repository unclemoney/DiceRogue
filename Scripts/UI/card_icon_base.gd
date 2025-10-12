extends Control
class_name CardIconBase

## CardIconBase
##
## Base class for all card-based UI icons (ConsumableIcon, PowerUpIcon, ChallengeIcon).
## Provides common card structure creation and basic interaction patterns.
## Eliminates duplication of card layout code across different icon types.

@export var glow_intensity: float = 0.25
@export var hover_tilt: float = 0.05
@export var hover_scale: float = 1.05
@export var transition_speed: float = 0.05
@export var max_offset_shadow: float = 20.0

# Mouse movement variables
@export var spring: float = 150.0
@export var damp: float = 10.0
@export var velocity_multiplier: float = 2.0
@export var angle_x_max: float = 25.0  # Maximum X rotation angle in degrees
@export var angle_y_max: float = 25.0  # Maximum Y rotation angle in degrees

# Common node references - created by _create_card_structure
var card_art: TextureRect
var card_frame: TextureRect
var card_info: VBoxContainer
var card_title: Label
var shadow: TextureRect
var sell_button: Button

# Animation and state variables
var _is_hovering := false
var _sell_button_visible := false
var _hover_card_tween: Tween

func _ready() -> void:
	if not _should_auto_create_structure():
		return
	_create_card_structure()
	_setup_card_interactions()

## _should_auto_create_structure()
##
## Override this in subclasses if you need custom structure creation timing.
## Returns true by default to auto-create the card structure in _ready().
func _should_auto_create_structure() -> bool:
	return true

## _create_card_structure()
##
## Creates the common card UI structure with shadow, art, frame, and info sections.
## This method can be called manually or overridden for specialized card layouts.
func _create_card_structure() -> void:
	# Create Shadow (underneath everything)
	shadow = TextureRect.new()
	shadow.name = "Shadow"
	shadow.set_anchors_preset(Control.PRESET_FULL_RECT)
	shadow.modulate = Color(0.0, 0.0, 0.0, 0.5)
	shadow.z_index = -1
	shadow.position = Vector2(5, 5)
	add_child(shadow)
	
	# Create CardArt
	card_art = TextureRect.new()
	card_art.name = "CardArt"
	card_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(card_art)
	
	# Create CardFrame
	card_frame = TextureRect.new()
	card_frame.name = "CardFrame"
	card_frame.z_index = 1
	card_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(card_frame)
	
	# Create CardInfo
	card_info = VBoxContainer.new()
	card_info.name = "CardInfo"
	card_info.z_index = 2
	card_info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	add_child(card_info)
	
	# Create Title
	card_title = Label.new()
	card_title.name = "Title"
	card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 16)
	card_info.add_child(card_title)
	
	# Create SellButton
	sell_button = Button.new()
	sell_button.name = "SellButton"
	sell_button.text = "SELL"
	sell_button.visible = false
	sell_button.z_index = 3
	sell_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	sell_button.size = Vector2(44, 31)
	add_child(sell_button)
	
	# Allow subclasses to customize the structure
	_customize_card_structure()

## _customize_card_structure()
##
## Override this in subclasses to add specialized UI elements or modify the base structure.
## Called after the common structure is created but before interactions are set up.
func _customize_card_structure() -> void:
	pass

## _setup_card_interactions()
##
## Sets up common mouse interactions and hover effects.
## Override this in subclasses for specialized interaction patterns.
func _setup_card_interactions() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if sell_button:
		sell_button.pressed.connect(_on_sell_button_pressed)

## _on_mouse_entered()
##
## Base hover enter behavior. Override in subclasses for specialized hover effects.
func _on_mouse_entered() -> void:
	_is_hovering = true
	_start_hover_effect()

## _on_mouse_exited()
##
## Base hover exit behavior. Override in subclasses for specialized hover effects.
func _on_mouse_exited() -> void:
	_is_hovering = false
	_stop_hover_effect()

## _start_hover_effect()
##
## Basic hover animation. Can be overridden for custom hover effects.
func _start_hover_effect() -> void:
	if _hover_card_tween:
		_hover_card_tween.kill()
	
	_hover_card_tween = create_tween()
	_hover_card_tween.parallel().tween_property(self, "scale", Vector2.ONE * hover_scale, transition_speed)

## _stop_hover_effect()
##
## Basic hover exit animation. Can be overridden for custom hover effects.
func _stop_hover_effect() -> void:
	if _hover_card_tween:
		_hover_card_tween.kill()
	
	_hover_card_tween = create_tween()
	_hover_card_tween.parallel().tween_property(self, "scale", Vector2.ONE, transition_speed)

## _on_sell_button_pressed()
##
## Base sell button behavior. Override in subclasses to emit appropriate signals.
func _on_sell_button_pressed() -> void:
	# Subclasses should override this to emit their specific sell signal
	print("[CardIconBase] Sell button pressed - override in subclass")

## set_card_art(texture)
##
## Sets the main card artwork texture.
func set_card_art(texture: Texture2D) -> void:
	if card_art:
		card_art.texture = texture

## set_card_frame(texture)
##
## Sets the card frame texture.
func set_card_frame(texture: Texture2D) -> void:
	if card_frame:
		card_frame.texture = texture

## set_card_title(text)
##
## Sets the card title text.
func set_card_title(text: String) -> void:
	if card_title:
		card_title.text = text

## set_shadow_texture(texture)
##
## Sets the shadow texture.
func set_shadow_texture(texture: Texture2D) -> void:
	if shadow:
		shadow.texture = texture

## show_sell_button(should_show)
##
## Controls sell button visibility.
func show_sell_button(should_show: bool) -> void:
	if sell_button:
		sell_button.visible = should_show
		_sell_button_visible = should_show

## is_sell_button_visible()
##
## Returns true if sell button is currently visible.
func is_sell_button_visible() -> bool:
	return _sell_button_visible