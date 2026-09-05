extends Control
class_name ChallengeUI

## ChallengeUI
##
## The goalpost panel in the GameUI center column (challenges deprecated:
## each round is a store). Shows the zone/store name, a dominant teal
## GameProgressBar toward the round target, the challenge progress
## "21 / 75" (left) and the current ROUND total "TOTAL 21" (right).
## GameController drives this API directly (no Challenge instance exists).

signal challenge_selected(id: String)
signal challenge_reveal_finished

@export var round_manager_path: NodePath

const VCR_FONT := preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")
# Scorecard-family translucent panel treatment
const PANEL_BG: Color = Color(0.12, 0.1, 0.17, 0.65)
const PANEL_CORNER_RADIUS: int = 12
const ZONE_COLOR: Color = Color(1.0, 0.95, 0.87, 1.0)
const NUM_COLOR: Color = Color(1.0, 0.98, 0.92, 1.0)
const OUTLINE_COLOR: Color = Color(0.08, 0.07, 0.11, 1.0)
const TEAL: Color = Color(0.549020, 0.729412, 0.662745, 1.0)
const TEAL_OVERFLOW: Color = Color(0.75, 1.0, 0.9, 1.0)
const ZONE_FONT_SIZE: int = 16
const NUM_FONT_SIZE: int = 20

var _store_id: String = ""
var _store_target: int = 0
var _store_score: int = 0
var _store_debuff_ids: Array[String] = []
var _challenge_reveal_active: bool = false

var _panel: PanelContainer
var _zone_label: Label
var _bar: GameProgressBar
var _progress_label: Label
var _total_label: Label
var _punch_tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_panel()


func _build_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.queue_free()

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.set_corner_radius_all(PANEL_CORNER_RADIUS)
	style.corner_detail = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 5)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.add_theme_constant_override("separation", 2)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)

	# Top row: zone / store name, large warm-white, left
	_zone_label = Label.new()
	_zone_label.name = "ZoneLabel"
	_zone_label.text = ""
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_zone_label.clip_text = true
	_zone_label.add_theme_font_override("font", VCR_FONT)
	_zone_label.add_theme_font_size_override("font_size", ZONE_FONT_SIZE)
	_zone_label.add_theme_color_override("font_color", ZONE_COLOR)
	_zone_label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	_zone_label.add_theme_constant_override("outline_size", 2)
	_zone_label.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_zone_label)

	# Middle: the bar is the dominant element
	_bar = GameProgressBar.new()
	_bar.name = "ChallengeBar"
	_bar.fill_color = TEAL
	_bar.overflow_color = TEAL_OVERFLOW
	_bar.show_ticks = true
	_bar.min_value = 0
	_bar.max_value = 100
	_bar.custom_minimum_size = Vector2(0, 18)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(_bar)

	# Bottom row: challenge progress (left), round total (right)
	var bottom := HBoxContainer.new()
	bottom.name = "BottomRow"
	bottom.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(bottom)

	_progress_label = _make_num_label("ProgressLabel", "0 / 0", HORIZONTAL_ALIGNMENT_LEFT)
	_progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_progress_label)

	_total_label = _make_num_label("RoundTotalLabel", "TOTAL 0", HORIZONTAL_ALIGNMENT_RIGHT)
	_total_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_total_label.resized.connect(_recenter_total_pivot)
	bottom.add_child(_total_label)


func _make_num_label(label_name: String, text: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = label_name
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_override("font", VCR_FONT)
	label.add_theme_font_size_override("font_size", NUM_FONT_SIZE)
	label.add_theme_color_override("font_color", NUM_COLOR)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label


func _recenter_total_pivot() -> void:
	_total_label.pivot_offset = _total_label.size * 0.5


## _punch_total()
##
## Subtle scale-punch on the round total when it increases.
func _punch_total() -> void:
	if not _total_label:
		return
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()
	_recenter_total_pivot()
	_total_label.scale = Vector2.ONE
	_punch_tween = create_tween()
	_punch_tween.tween_property(_total_label, "scale", Vector2(1.15, 1.15), 0.1) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(_total_label, "scale", Vector2.ONE, 0.12) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# ---- Store rounds (challenges deprecated) ----


## show_store(store_name, target_score, reward_money, difficulty) -> void
##
## Sets the zone name and round target, resets progress. difficulty is kept
## for API compatibility (star rating is deprecated and gone).
func show_store(store_name: String, target_score: int, _reward_money: int, _difficulty: int = 0) -> void:
	_store_id = store_name
	_store_target = maxi(target_score, 1)
	_store_score = 0
	_store_debuff_ids.clear()
	_zone_label.text = store_name.to_upper()
	_bar.max_value = float(_store_target)
	_bar.set_value_instant(0.0)
	_progress_label.text = "0 / %s" % NumberFormatter.format_int(_store_target)
	_total_label.text = "TOTAL 0"


## set_store_progress(progress) -> void
##
## Ratio-based update (0.0–1.0). Kept for compatibility; prefer
## set_store_score so the labels can show real numbers.
func set_store_progress(progress: float) -> void:
	if _store_id.is_empty():
		return
	set_store_score(roundi(clampf(progress, 0.0, 1.0) * _store_target), _store_target)


## set_store_score(current, target) -> void
##
## Drives the bar (tweened, overflow past target) and both numeral labels.
## The total is the scorecard's per-round total — it resets each round.
func set_store_score(current: int, target: int) -> void:
	_store_target = maxi(target, 1)
	var previous := _store_score
	_store_score = current
	_bar.max_value = float(_store_target)
	_bar.value = float(current)
	_progress_label.text = "%s / %s" % [
		NumberFormatter.format_int(current), NumberFormatter.format_int(_store_target)]
	_total_label.text = "TOTAL %s" % NumberFormatter.format_int(current)
	if current > previous:
		_punch_total()


## set_store_debuffs(debuff_ids) -> void
##
## Stores this round's active debuff ids (detail fan-out is gone; kept for
## future tooltip use).
func set_store_debuffs(debuff_ids: Array) -> void:
	_store_debuff_ids.assign(debuff_ids)


## notify_store_completed() / notify_store_failed() -> void
##
## Completion flash / FAILED stamp effects on the panel.
func notify_store_completed() -> void:
	if _store_id.is_empty() or not _panel:
		return
	_bar.value = float(_store_target)
	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(0.6, 1.4, 0.8), 0.25)
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.4)


func notify_store_failed() -> void:
	if _store_id.is_empty() or not _panel:
		return
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx:
		tfx.negative_hit(_panel)

	var stamp := Label.new()
	stamp.text = "FAILED"
	stamp.set_anchors_preset(Control.PRESET_CENTER)
	stamp.z_index = 50
	stamp.rotation_degrees = -15
	stamp.add_theme_font_override("font", VCR_FONT)
	stamp.add_theme_font_size_override("font_size", 28)
	stamp.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1, 1.0))
	_panel.add_child(stamp)
	if tfx:
		tfx.play_preset(stamp, "impact_land")

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_denied_sound"):
		audio_mgr.play_denied_sound()

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.8, 0.1, 0.1, 0.0)
	vignette.z_index = 40
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)
	var vig_tween := create_tween()
	vig_tween.tween_property(vignette, "color:a", 0.15, 0.2)
	vig_tween.tween_property(vignette, "color:a", 0.0, 0.4)
	vig_tween.tween_callback(vignette.queue_free)

	var tween := create_tween()
	tween.tween_property(_panel, "modulate", Color(1.4, 0.5, 0.5), 0.25)
	tween.tween_property(_panel, "modulate", Color.WHITE, 0.4)


## clear_all_challenges() -> void
##
## Resets the panel (used between store rounds and on game reset).
func clear_all_challenges() -> void:
	_store_id = ""
	_store_target = 0
	_store_score = 0
	_store_debuff_ids.clear()
	if not _panel:
		return
	_zone_label.text = ""
	_bar.set_value_instant(0.0)
	_progress_label.text = "0 / 0"
	_total_label.text = "TOTAL 0"


# ---- Round-start reveal banner ----


## show_store_reveal_banner(store_name)
##
## Round-start banner for a store round (challenges deprecated: each round
## is a store). Uses the same reveal animation and gate as challenge reveals.
func show_store_reveal_banner(store_name: String) -> void:
	_show_reveal_banner("NOW ENTERING\n%s" % store_name.to_upper())


func _show_reveal_banner(banner_text: String) -> void:
	_challenge_reveal_active = true
	var banner = Label.new()
	banner.text = banner_text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.z_index = 200

	banner.add_theme_font_override("font", VCR_FONT)
	banner.add_theme_font_size_override("font_size", 28)
	banner.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4, 1.0))

	var viewport_size = get_viewport_rect().size
	banner.position = Vector2(viewport_size.x / 2 - 150, viewport_size.y / 2 - 60)
	banner.custom_minimum_size = Vector2(300, 0)

	get_tree().root.add_child(banner)

	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx:
		tfx.play_preset(banner, "fly_in_down")

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_challenge_reveal_sound"):
		audio_mgr.play_challenge_reveal_sound()

	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(banner):
		var fade = create_tween()
		fade.tween_property(banner, "modulate:a", 0.0, 0.3)
		fade.tween_callback(banner.queue_free)
		await fade.finished
	_challenge_reveal_active = false
	challenge_reveal_finished.emit()


func wait_for_reveal() -> void:
	if _challenge_reveal_active:
		await challenge_reveal_finished
