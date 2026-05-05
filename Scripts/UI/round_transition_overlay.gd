extends CanvasLayer
class_name RoundTransitionOverlay

## RoundTransitionOverlay
##
## Full-screen cinematic overlay shown after a challenge is completed.
## Displays completion info, next challenge preview, and action buttons.
## Fires after the firework celebration finishes (~1.5s delay).
##
## Signals:
##   keep_playing_pressed — Player chose to continue without shopping
##   enter_shop_pressed   — Player chose to head to the shop
##
## Usage:
##   var overlay = RoundTransitionOverlay.new()
##   add_child(overlay)
##   overlay.show_transition(data)

signal keep_playing_pressed
signal enter_shop_pressed

# ── Timing Constants ──────────────────────────────────────────────────
const BG_FADE_DURATION: float = 0.35
const BANNER_SLIDE_DURATION: float = 0.55
const BANNER_STAGGER_DELAY: float = 0.6
const BUTTON_FLY_DURATION: float = 0.5
const BUTTON_STAGGER_DELAY: float = 0.15
const DISMISS_DURATION: float = 0.35

# ── Styling Constants ─────────────────────────────────────────────────
const OVERLAY_COLOR := Color(0, 0, 0, 0.78)
const BANNER_BG_COLOR := Color(0.13, 0.10, 0.18, 0.96)
const BANNER_BORDER_COLOR := Color(1.0, 0.82, 0.2, 1.0)
const SHOP_BANNER_BORDER_COLOR := Color(0.3, 0.85, 0.4, 1.0)
const TITLE_COLOR := Color(1.0, 0.9, 0.3, 1.0)
const DETAIL_COLOR := Color(1.0, 0.98, 0.9, 1.0)
const SUBTITLE_COLOR := Color(0.85, 0.82, 0.75, 1.0)
const SHOP_BUTTON_BG := Color(0.12, 0.22, 0.12, 0.96)
const SHOP_BUTTON_BORDER := Color(0.3, 0.9, 0.3, 1.0)

const BANNER_BORDER_WIDTH: int = 3
const BANNER_CORNER_RADIUS: int = 8
const BANNER_WIDTH: float = 800.0
const BANNER_HEIGHT: float = 100.0
const BANNER_GAP: float = 30.0
const BUTTON_GAP: float = 30.0
const BUTTON_ROW_HEIGHT: float = 56.0

const FONT_PATH := "res://Resources/Font/VCR_OSD_MONO_1.001.ttf"
const BUTTON_THEME_PATH := "res://Resources/UI/action_button_theme.tres"

# ── Shader Pool (randomly applied to banner backgrounds) ──────────────
const PANEL_SHADER_PATHS: Array = [
	"res://Scripts/Shaders/plasma_screen.gdshader",
	"res://Scripts/Shaders/laser_show.gdshader",
	"res://Scripts/Shaders/neon_grid.gdshader",
	"res://Scripts/Shaders/arcade_starfield.gdshader",
	"res://Scripts/Shaders/marquee_lights.gdshader",
	"res://Scripts/Shaders/vhs_wave.gdshader",
	"res://Scripts/Shaders/zigzag_bolts.gdshader",
	"res://Scripts/Shaders/roller_rink.gdshader",
]

# ── Node References ───────────────────────────────────────────────────
var background_overlay: ColorRect
var banner_container: Control
var completion_banner: Control
var completion_shader_bg: ColorRect
var completion_border: Panel
var completion_title: Label
var completion_detail: Label
var next_banner: Control
var next_shader_bg: ColorRect
var next_border: Panel
var next_title: Label
var next_detail: Label
var button_container: HBoxContainer
var keep_playing_button: Button
var enter_shop_button: Button

# ── State ─────────────────────────────────────────────────────────────
var _is_showing: bool = false
var _is_dismissing: bool = false
var _entrance_tween: Tween
var _idle_tweens: Array[Tween] = []
var _dismiss_tween: Tween
var _is_final_round: bool = false

@onready var _tfx := get_node("/root/TweenFXHelper")
var _vcr_font: Font


func _ready() -> void:
	layer = 10
	visible = false
	_vcr_font = load(FONT_PATH) as Font
	_build_ui()


## _build_ui()
##
## Programmatically constructs the full overlay UI tree.
## Banners use explicit Control sizes with shader backgrounds instead
## of auto-sizing PanelContainer (which ignores BANNER_HEIGHT).
func _build_ui() -> void:
	# ── Background overlay ────────────────────────────────────────────
	background_overlay = ColorRect.new()
	background_overlay.name = "BackgroundOverlay"
	background_overlay.color = Color(0, 0, 0, 0)
	background_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background_overlay)

	# ── Banner container (full-rect anchor for layout) ────────────────
	banner_container = Control.new()
	banner_container.name = "BannerContainer"
	banner_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_overlay.add_child(banner_container)

	# ── Completion banner ─────────────────────────────────────────────
	var comp_data: Dictionary = _create_banner("CompletionBanner", BANNER_BORDER_COLOR)
	completion_banner = comp_data["root"]
	completion_shader_bg = comp_data["shader_bg"]
	completion_border = comp_data["border"]
	banner_container.add_child(completion_banner)

	completion_title = _create_label("ROUND COMPLETE", 28, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	comp_data["content_box"].add_child(completion_title)

	completion_detail = _create_label("Round 1 — Challenge Name", 16, DETAIL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	comp_data["content_box"].add_child(completion_detail)

	# ── Next challenge banner ─────────────────────────────────────────
	var next_data: Dictionary = _create_banner("NextChallengeBanner", SHOP_BANNER_BORDER_COLOR)
	next_banner = next_data["root"]
	next_shader_bg = next_data["shader_bg"]
	next_border = next_data["border"]
	banner_container.add_child(next_banner)

	next_title = _create_label("NEXT CHALLENGE", 24, TITLE_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	next_data["content_box"].add_child(next_title)

	next_detail = _create_label("Challenge Name — Goal: 250 pts", 16, DETAIL_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	next_data["content_box"].add_child(next_detail)

	# ── Button container ──────────────────────────────────────────────
	button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.add_theme_constant_override("separation", 30)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_container.add_child(button_container)

	var btn_theme = load(BUTTON_THEME_PATH) as Theme

	# Keep Playing button
	keep_playing_button = Button.new()
	keep_playing_button.name = "KeepPlayingButton"
	keep_playing_button.text = "Keep Playing"
	keep_playing_button.custom_minimum_size = Vector2(180, 52)
	keep_playing_button.add_theme_font_size_override("font_size", 18)
	if btn_theme:
		keep_playing_button.theme = btn_theme
	button_container.add_child(keep_playing_button)

	# Enter Shop button (green-highlighted)
	enter_shop_button = Button.new()
	enter_shop_button.name = "EnterShopButton"
	enter_shop_button.text = "Enter Shop"
	enter_shop_button.custom_minimum_size = Vector2(180, 52)
	enter_shop_button.add_theme_font_size_override("font_size", 18)
	if btn_theme:
		enter_shop_button.theme = btn_theme
	_apply_shop_button_highlight(enter_shop_button)
	button_container.add_child(enter_shop_button)

	# ── Connect button signals ────────────────────────────────────────
	keep_playing_button.pressed.connect(_on_keep_playing_pressed)
	enter_shop_button.pressed.connect(_on_enter_shop_pressed)

	# ── Hide everything for entrance animation ────────────────────────
	completion_banner.modulate = Color(1, 1, 1, 0)
	next_banner.modulate = Color(1, 1, 1, 0)
	button_container.modulate = Color(1, 1, 1, 0)


## show_transition(data: Dictionary)
##
## Populates overlay with round data and kicks off the cinematic entrance.
## @param data: Dictionary with keys:
##   round_number: int — Current round (1-based)
##   challenge_name: String — Completed challenge display name
##   next_challenge_name: String — Next challenge display name (empty if final)
##   next_challenge_target: int — Next challenge goal score (0 if final)
##   is_final_round: bool — Whether this is the last round
func show_transition(data: Dictionary) -> void:
	if _is_showing:
		return
	_is_showing = true
	_is_final_round = data.get("is_final_round", false)

	# Reroll shader backgrounds each time the overlay appears
	_randomize_banner_shaders()

	# Populate completion banner
	var round_num: int = data.get("round_number", 1)
	var challenge_name: String = data.get("challenge_name", "Challenge")
	completion_title.text = "ROUND %d COMPLETE!" % round_num
	completion_detail.text = challenge_name

	# Populate next challenge banner (or final-round variant)
	if _is_final_round:
		next_title.text = "ALL ROUNDS COMPLETE!"
		next_detail.text = "Amazing run — time to claim your rewards!"
	else:
		var next_name: String = data.get("next_challenge_name", "???")
		var next_target: int = data.get("next_challenge_target", 0)
		next_title.text = "NEXT CHALLENGE"
		next_detail.text = "%s — Goal: %d pts" % [next_name, next_target]

	visible = true
	_play_entrance_sequence()


## dismiss()
##
## Plays exit animation then hides the overlay.
## Emits no signals — call this after signal handling.
func dismiss() -> void:
	if _is_dismissing:
		return
	_is_dismissing = true

	# Stop idle loops
	_stop_idle_animations()

	# Kill any running entrance tween
	if _entrance_tween and _entrance_tween.is_valid():
		_entrance_tween.kill()

	var viewport_size = get_viewport().get_visible_rect().size

	_dismiss_tween = create_tween()
	_dismiss_tween.set_parallel(true)

	# Banners slide out opposite directions
	_dismiss_tween.tween_property(completion_banner, "position:x", -BANNER_WIDTH - 50, DISMISS_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_dismiss_tween.tween_property(completion_banner, "modulate:a", 0.0, DISMISS_DURATION * 0.6)

	_dismiss_tween.tween_property(next_banner, "position:x", viewport_size.x + 50, DISMISS_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_dismiss_tween.tween_property(next_banner, "modulate:a", 0.0, DISMISS_DURATION * 0.6)

	# Buttons drop down
	_dismiss_tween.tween_property(button_container, "position:y", viewport_size.y + 100, DISMISS_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_dismiss_tween.tween_property(button_container, "modulate:a", 0.0, DISMISS_DURATION * 0.6)

	# Background fades out
	_dismiss_tween.tween_property(background_overlay, "color:a", 0.0, DISMISS_DURATION)

	_dismiss_tween.chain().tween_callback(_on_dismiss_finished)


# ── Entrance Animation ────────────────────────────────────────────────

## _play_entrance_sequence()
##
## Orchestrates the full cinematic entrance:
## 1. Background fades in
## 2. Completion banner slides from left with impact punch
## 3. Next challenge banner slides from right with impact punch
## 4. Buttons fly up from bottom
## 5. Idle animations begin
func _play_entrance_sequence() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var center_x = (viewport_size.x - BANNER_WIDTH) / 2.0

	# ── Calculate centered vertical layout (no overlap) ───────────────
	var total_height = BANNER_HEIGHT + BANNER_GAP + BANNER_HEIGHT + BUTTON_GAP + BUTTON_ROW_HEIGHT
	var start_y = (viewport_size.y - total_height) / 2.0
	var top_banner_y = start_y
	var bottom_banner_y = start_y + BANNER_HEIGHT + BANNER_GAP
	var button_y = bottom_banner_y + BANNER_HEIGHT + BUTTON_GAP

	# ── Position banners off-screen ───────────────────────────────────
	completion_banner.position = Vector2(-BANNER_WIDTH - 60, top_banner_y)
	completion_banner.rotation = deg_to_rad(-3.0)
	completion_banner.scale = Vector2(0.85, 0.85)
	completion_banner.modulate = Color(1, 1, 1, 0)

	next_banner.position = Vector2(viewport_size.x + 60, bottom_banner_y)
	next_banner.rotation = deg_to_rad(3.0)
	next_banner.scale = Vector2(0.85, 0.85)
	next_banner.modulate = Color(1, 1, 1, 0)

	# ── Position buttons below viewport ───────────────────────────────
	button_container.position = Vector2(center_x - 60, viewport_size.y + 100)
	button_container.modulate = Color(1, 1, 1, 0)
	button_container.size = Vector2(BANNER_WIDTH + 120, 60)

	# Reset background
	background_overlay.color = Color(0, 0, 0, 0)
	
	# Play round start sound
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr:
		audio_mgr.play_round_start_sound()

	# Build the tween sequence
	_entrance_tween = create_tween()

	# ── Step 1: Fade in background ────────────────────────────────────
	_entrance_tween.tween_property(background_overlay, "color", OVERLAY_COLOR, BG_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# ── Step 2: Completion banner slides from LEFT ────────────────────
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(completion_banner, "position:x", center_x, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(completion_banner, "rotation", 0.0, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(completion_banner, "scale", Vector2.ONE, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(completion_banner, "modulate:a", 1.0, BANNER_SLIDE_DURATION * 0.4)
	_entrance_tween.set_parallel(false)

	# Impact effects after completion banner lands
	_entrance_tween.tween_callback(_impact_punch.bind(completion_banner, completion_title))

	# ── Step 3: Next challenge banner slides from RIGHT ───────────────
	_entrance_tween.tween_interval(BANNER_STAGGER_DELAY * 0.5)
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(next_banner, "position:x", center_x, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(next_banner, "rotation", 0.0, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(next_banner, "scale", Vector2.ONE, BANNER_SLIDE_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(next_banner, "modulate:a", 1.0, BANNER_SLIDE_DURATION * 0.4)
	_entrance_tween.set_parallel(false)

	# Impact effects after next banner lands
	_entrance_tween.tween_callback(_impact_punch.bind(next_banner, next_title))

	# ── Step 4: Buttons fly up ────────────────────────────────────────
	_entrance_tween.tween_interval(BUTTON_STAGGER_DELAY)
	_entrance_tween.set_parallel(true)
	_entrance_tween.tween_property(button_container, "position:y", button_y, BUTTON_FLY_DURATION).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_entrance_tween.tween_property(button_container, "modulate:a", 1.0, BUTTON_FLY_DURATION * 0.4)
	_entrance_tween.set_parallel(false)

	# ── Step 5: Start idle animations and connect button effects ──────
	_entrance_tween.tween_callback(_start_idle_animations)
	_entrance_tween.tween_callback(_connect_button_effects)


## _impact_punch(banner, title_label)
##
## Fires on banner landing: scale squash-stretch, micro-shake, title flash,
## and TweenFX celebration for maximum juice.
func _impact_punch(banner: Control, title_label: Label) -> void:
	# Scale punch (squash and stretch)
	var punch = create_tween()
	punch.tween_property(banner, "scale", Vector2(1.06, 0.94), 0.05).set_trans(Tween.TRANS_QUAD)
	punch.tween_property(banner, "scale", Vector2(0.97, 1.04), 0.06).set_trans(Tween.TRANS_QUAD)
	punch.tween_property(banner, "scale", Vector2(1.0, 1.0), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# Micro-shake on position
	var base_x = banner.position.x
	var shake = create_tween()
	shake.tween_property(banner, "position:x", base_x + 6, 0.025)
	shake.tween_property(banner, "position:x", base_x - 4, 0.025)
	shake.tween_property(banner, "position:x", base_x + 2, 0.025)
	shake.tween_property(banner, "position:x", base_x, 0.025)

	# Title flash (bright white burst then fade back)
	title_label.modulate = Color(2.5, 2.5, 2.5, 1.0)
	var flash = create_tween()
	flash.tween_property(title_label, "modulate", Color.WHITE, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	# TweenFX celebration
	if _tfx:
		_tfx.celebration(banner)
	else:
		TweenFX.tada(banner, 0.6)


## _connect_button_effects()
##
## Wires TweenFXHelper hover/press animations to buttons.
func _connect_button_effects() -> void:
	if not _tfx:
		return

	for btn in [keep_playing_button, enter_shop_button]:
		if btn:
			if not btn.mouse_entered.is_connected(_tfx.button_hover):
				btn.mouse_entered.connect(_tfx.button_hover.bind(btn))
			if not btn.mouse_exited.is_connected(_tfx.button_unhover):
				btn.mouse_exited.connect(_tfx.button_unhover.bind(btn))


## _start_idle_animations()
##
## Begins looping idle animations on banners and buttons after entrance finishes.
## Includes subtle breathe on banners, float bob on buttons, and border glow pulse.
func _start_idle_animations() -> void:
	_stop_idle_animations()

	# Subtle breathe on banners
	if _tfx:
		var t1 = _tfx.idle_pulse(completion_banner, 0.02)
		if t1:
			_idle_tweens.append(t1)
		var t2 = _tfx.idle_pulse(next_banner, 0.02)
		if t2:
			_idle_tweens.append(t2)

	# Gentle float bob on button container
	var bob_tween = TweenFX.float_bob(button_container, 2.5, 3.0)
	if bob_tween:
		_idle_tweens.append(bob_tween)

	# Border glow pulse on completion banner
	if is_instance_valid(completion_border):
		var glow1 = create_tween().set_loops()
		glow1.tween_property(completion_border, "modulate", Color(1.3, 1.2, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow1.tween_property(completion_border, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tweens.append(glow1)

	# Border glow pulse on next banner (offset timing via slight delay)
	if is_instance_valid(next_border):
		var glow2 = create_tween().set_loops()
		glow2.tween_property(next_border, "modulate", Color(1.0, 1.3, 1.1, 1.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		glow2.tween_property(next_border, "modulate", Color(1.0, 1.0, 1.0, 1.0), 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tweens.append(glow2)


## _stop_idle_animations()
##
## Kills all looping idle tweens.
func _stop_idle_animations() -> void:
	for t in _idle_tweens:
		if t and t.is_valid():
			t.kill()
	_idle_tweens.clear()

	# Reset transforms that idle animations may have modified
	if is_instance_valid(completion_banner):
		TweenFX.stop_all(completion_banner)
	if is_instance_valid(next_banner):
		TweenFX.stop_all(next_banner)
	if is_instance_valid(button_container):
		TweenFX.stop_all(button_container)
	if is_instance_valid(completion_border):
		completion_border.modulate = Color.WHITE
	if is_instance_valid(next_border):
		next_border.modulate = Color.WHITE


# ── Button Handlers ───────────────────────────────────────────────────

func _on_keep_playing_pressed() -> void:
	if _is_dismissing:
		return
	if _tfx:
		_tfx.button_press(keep_playing_button)
	dismiss()
	# Signal emitted after dismiss animation finishes
	_pending_signal = "keep_playing"


func _on_enter_shop_pressed() -> void:
	if _is_dismissing:
		return
	if _tfx:
		_tfx.button_press(enter_shop_button)
	dismiss()
	_pending_signal = "enter_shop"


var _pending_signal: String = ""


func _on_dismiss_finished() -> void:
	visible = false
	_is_showing = false
	_is_dismissing = false

	if _pending_signal == "keep_playing":
		keep_playing_pressed.emit()
	elif _pending_signal == "enter_shop":
		enter_shop_pressed.emit()

	_pending_signal = ""


# ── UI Factory Helpers ────────────────────────────────────────────────

## _create_banner(banner_name, border_color) -> Dictionary
##
## Creates a fixed-size banner with shader background, styled border, and content area.
## Returns Dictionary with keys: root (Control), shader_bg (ColorRect),
## border (Panel), content_box (VBoxContainer).
func _create_banner(banner_name: String, border_color: Color) -> Dictionary:
	# Root Control — explicit size, no auto-sizing
	var root = Control.new()
	root.name = banner_name
	root.size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	root.custom_minimum_size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	root.clip_contents = true
	root.pivot_offset = Vector2(BANNER_WIDTH / 2.0, BANNER_HEIGHT / 2.0)

	# Shader background (fills the banner, random shader applied later)
	var shader_bg = ColorRect.new()
	shader_bg.name = "ShaderBG"
	shader_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	shader_bg.color = BANNER_BG_COLOR
	root.add_child(shader_bg)

	# Dark readability overlay on top of shader
	var dark_overlay = ColorRect.new()
	dark_overlay.name = "DarkOverlay"
	dark_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_overlay.color = Color(0, 0, 0, 0.25)
	root.add_child(dark_overlay)

	# Border frame (transparent bg, colored border only)
	var border = Panel.new()
	border.name = "BorderFrame"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = border_color
	style.set_border_width_all(BANNER_BORDER_WIDTH)
	style.set_corner_radius_all(BANNER_CORNER_RADIUS)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 6
	style.shadow_offset = Vector2(2, 3)
	border.add_theme_stylebox_override("panel", style)
	root.add_child(border)

	# Content container (centered text)
	var margin = MarginContainer.new()
	margin.name = "ContentMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	root.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 6)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	return {"root": root, "shader_bg": shader_bg, "border": border, "content_box": vbox}


## _create_label(text, font_size, color, alignment) -> Label
##
## Creates a VCR_OSD_MONO styled label.
func _create_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 3)
	if _vcr_font:
		label.add_theme_font_override("font", _vcr_font)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## _apply_random_shader(target)
##
## Loads a random shader from the pool and applies it to a ColorRect.
func _apply_random_shader(target: ColorRect) -> void:
	if PANEL_SHADER_PATHS.is_empty():
		return
	var path = PANEL_SHADER_PATHS[randi() % PANEL_SHADER_PATHS.size()]
	var shader = load(path) as Shader
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		target.material = mat


## _randomize_banner_shaders()
##
## Rerolls random shaders on both banner backgrounds.
func _randomize_banner_shaders() -> void:
	if is_instance_valid(completion_shader_bg):
		_apply_random_shader(completion_shader_bg)
	if is_instance_valid(next_shader_bg):
		_apply_random_shader(next_shader_bg)


## _apply_shop_button_highlight(btn)
##
## Applies a gold/green highlighted style to the Enter Shop button
## so it visually stands out as the primary action.
func _apply_shop_button_highlight(btn: Button) -> void:
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = SHOP_BUTTON_BG
	normal_style.border_color = SHOP_BUTTON_BORDER
	normal_style.set_border_width_all(3)
	normal_style.set_corner_radius_all(4)
	normal_style.content_margin_left = 12
	normal_style.content_margin_right = 12
	normal_style.content_margin_top = 8
	normal_style.content_margin_bottom = 8
	normal_style.shadow_color = Color(0.1, 0.5, 0.1, 0.4)
	normal_style.shadow_size = 4

	var hover_style = normal_style.duplicate()
	hover_style.bg_color = Color(0.16, 0.28, 0.16, 0.98)
	hover_style.border_color = Color(0.4, 1.0, 0.4, 1.0)
	hover_style.shadow_size = 6

	var pressed_style = normal_style.duplicate()
	pressed_style.bg_color = Color(0.20, 0.34, 0.20, 1.0)
	pressed_style.border_color = Color(0.5, 1.0, 0.5, 1.0)

	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	btn.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0, 1.0))
