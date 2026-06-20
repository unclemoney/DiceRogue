extends Control
class_name InteractiveGameTitle

## InteractiveGameTitle
##
## GameUI-specific reactive title scene that mirrors the main menu's per-letter
## playfulness while responding to gameplay events inside a fixed title panel.

signal debug_effect_played(effect_name: String, intensity: float)

const TITLE_FONT: Font = preload("res://Resources/Font/PumpDemiBoldPlain.otf")
const GAMEPLAY_TITLE_LETTER_SCRIPT := preload("res://Scripts/UI/gameplay_title_letter.gd")

const EFFECT_POOLS := {
	"roll": ["_effect_rattle_jitter", "_effect_tumble_wave", "_effect_stagger_bounce"],
	"score": ["_effect_jackpot_flash", "_effect_banked_settle", "_effect_pop_count_ripple", "_effect_sweep_highlight"],
	"consumable": ["_effect_glitch_split", "_effect_rewind_snap", "_effect_fizz_pop"],
	"power": ["_effect_aura_latch", "_effect_empowered_lift", "_effect_resonance_shimmer"],
	"debuff": ["_effect_static_stutter", "_effect_alarm_flicker", "_effect_compression_squeeze"],
	"challenge": ["_effect_target_lock_sweep", "_effect_heroic_rise", "_effect_success_burst", "_effect_failure_collapse"]
}

const EVENT_COOLDOWNS := {
	"roll": 120,
	"score": 160,
	"score_prelude": 120,
	"consumable": 220,
	"power": 220,
	"debuff": 200,
	"challenge": 260,
	"challenge_terminal": 320
}

@export var title_text: String = "Guhtzee!"
@export var base_font_size: int = 72
@export var min_font_size: int = 40
@export var horizontal_padding: int = 18
@export var vertical_padding: int = 10
@export var letter_separation: int = 1
@export var base_title_color: Color = Color(1.0, 0.78, 0.48, 1.0)
@export var accent_title_color: Color = Color(0.901961, 0.450980, 0.556863, 1.0)
@export var secondary_accent_color: Color = Color(0.403922, 0.572549, 0.670588, 1.0)
@export var power_color: Color = Color(0.549020, 0.729412, 0.662745, 1.0)
@export var warning_color: Color = Color(1.0, 0.45, 0.45, 1.0)
@export var success_color: Color = Color(0.87, 0.96, 0.54, 1.0)

var _tfx: Node = null
var _game_controller: Node = null
var _title_margin: MarginContainer
var _title_center: CenterContainer
var _title_box: HBoxContainer
var _letters: Array = []
var _event_stamps: Dictionary = {}
var _last_total_score: int = 0
var _current_font_size: int = 72


func _ready() -> void:
	randomize()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	_tfx = get_node_or_null("/root/TweenFXHelper")
	_build_ui()
	resized.connect(_on_resized)
	call_deferred("_refresh_layout")
	call_deferred("_bind_gameplay_sources")


## debug_preview_event(event_name, intensity)
##
## Triggers a representative title reaction without needing the real gameplay event.
func debug_preview_event(event_name: String, intensity: float = 0.6) -> void:
	var clamped = clampf(intensity, 0.18, 1.0)
	match event_name:
		"roll":
			_trigger_family("roll", clamped)
		"score":
			_trigger_family("score", clamped)
		"consumable":
			_trigger_family("consumable", clamped)
		"power":
			_trigger_family("power", clamped)
		"debuff":
			_trigger_family("debuff", clamped)
		"challenge":
			_trigger_family("challenge", clamped)
		"challenge_complete":
			_effect_success_burst(clamped, "debug")
		"challenge_fail":
			_effect_failure_collapse(clamped, "debug")
		_:
			_trigger_family("score", clamped)
	debug_effect_played.emit(event_name, clamped)


## debug_play_random_event()
##
## Plays one random event family for quick previewing.
func debug_play_random_event(intensity: float = 0.7) -> String:
	var families = PackedStringArray(["roll", "score", "consumable", "power", "debuff", "challenge"])
	var chosen = families[randi() % families.size()]
	debug_preview_event(chosen, intensity)
	return chosen


func _build_ui() -> void:
	_title_margin = MarginContainer.new()
	_title_margin.name = "TitleMargin"
	_title_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_title_margin)

	_title_center = CenterContainer.new()
	_title_center.name = "TitleCenter"
	_title_center.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_title_margin.add_child(_title_center)

	_title_box = HBoxContainer.new()
	_title_box.name = "TitleBox"
	_title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_box.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_box.add_theme_constant_override("separation", letter_separation)
	_title_center.add_child(_title_box)

	_rebuild_letters()


func _rebuild_letters() -> void:
	for letter in _letters:
		if is_instance_valid(letter):
			letter.queue_free()
	_letters.clear()

	for i in range(title_text.length()):
		var letter = GAMEPLAY_TITLE_LETTER_SCRIPT.new()
		letter.name = "TitleLetter%d" % i
		letter.text = title_text[i]
		letter.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		letter.set_phase_offset(i * 0.34)
		_title_box.add_child(letter)
		_letters.append(letter)


func _refresh_layout() -> void:
	if _title_margin == null:
		return

	_title_margin.add_theme_constant_override("margin_left", horizontal_padding)
	_title_margin.add_theme_constant_override("margin_top", vertical_padding)
	_title_margin.add_theme_constant_override("margin_right", horizontal_padding)
	_title_margin.add_theme_constant_override("margin_bottom", vertical_padding)
	_title_box.add_theme_constant_override("separation", letter_separation)

	var available_width = maxf(size.x - float(horizontal_padding * 2), 120.0)
	var available_height = maxf(size.y - float(vertical_padding * 2), 36.0)
	var computed_font_size = int(clampf(floor(available_height * 0.76), float(min_font_size), float(base_font_size)))
	var estimated_width = TITLE_FONT.get_string_size(title_text, HORIZONTAL_ALIGNMENT_LEFT, -1, computed_font_size).x + float(maxi(title_text.length() - 1, 0) * letter_separation)
	if estimated_width > available_width and estimated_width > 0.0:
		computed_font_size = int(maxf(float(min_font_size), floor(computed_font_size * (available_width / estimated_width))))

	_current_font_size = computed_font_size
	var outline_color = base_title_color.darkened(0.68)
	var shadow_color = Color(0.08, 0.05, 0.10, 0.78)
	var wave_amplitude = clampf(float(computed_font_size) * 0.06, 2.0, 6.0)
	var max_event_offset = clampf(float(computed_font_size) * 0.24, 9.0, 18.0)
	var hover_scale = clampf(1.06 + float(computed_font_size) / 360.0, 1.1, 1.18)
	var max_tilt = clampf(float(computed_font_size) * 0.12, 7.0, 11.0)

	for letter in _letters:
		letter.apply_style(TITLE_FONT, computed_font_size, base_title_color, outline_color, shadow_color)
		letter.set_motion_profile(wave_amplitude, max_event_offset, hover_scale, max_tilt)

	call_deferred("_capture_letter_positions")


func _capture_letter_positions() -> void:
	for letter in _letters:
		if is_instance_valid(letter):
			letter.capture_base_position()


func _on_resized() -> void:
	_refresh_layout()


func _bind_gameplay_sources() -> void:
	_game_controller = get_tree().get_first_node_in_group("game_controller")
	if _game_controller == null:
		push_warning("[InteractiveGameTitle] GameController not found; title will stay in preview-only mode")
		return

	var dice_hand = _game_controller.get("dice_hand")
	_connect_signal_once(dice_hand, &"roll_started", _on_roll_started)
	_connect_signal_once(dice_hand, &"roll_complete", _on_roll_complete)

	var scorecard = _game_controller.get("scorecard")
	_connect_signal_once(scorecard, &"score_assigned", _on_score_assigned)
	_connect_signal_once(scorecard, &"score_auto_assigned", _on_score_auto_assigned)
	_connect_signal_once(scorecard, &"score_changed", _on_score_changed)
	_connect_signal_once(scorecard, &"upper_bonus_achieved", _on_upper_bonus_achieved)
	_connect_signal_once(scorecard, &"yahtzee_bonus_achieved", _on_yahtzee_bonus_achieved)
	if scorecard and scorecard.has_method("get_total_score"):
		_last_total_score = int(scorecard.get_total_score())

	var score_card_ui = _game_controller.get("score_card_ui")
	_connect_signal_once(score_card_ui, &"about_to_score", _on_about_to_score)
	_connect_signal_once(score_card_ui, &"hand_scored", _on_hand_scored)

	_connect_signal_once(_game_controller, &"power_up_granted", _on_power_up_granted)
	_connect_signal_once(_game_controller, &"consumable_used", _on_consumable_used)
	_connect_signal_once(_game_controller, &"debuff_blocked", _on_debuff_blocked)
	_connect_signal_once(_game_controller, &"debuff_applied", _on_debuff_applied)

	var turn_tracker = _game_controller.get("turn_tracker")
	_connect_signal_once(turn_tracker, &"turn_updated", _on_turn_updated)

	var round_manager = _game_controller.get("round_manager")
	_connect_signal_once(round_manager, &"round_started", _on_round_started)

	var challenge_manager = _game_controller.get("challenge_manager")
	_connect_signal_once(challenge_manager, &"challenge_activated", _on_challenge_activated)
	_connect_signal_once(challenge_manager, &"challenge_completed", _on_challenge_completed)
	_connect_signal_once(challenge_manager, &"challenge_failed", _on_challenge_failed)


func _connect_signal_once(emitter: Object, signal_name: StringName, callable: Callable) -> void:
	if emitter == null:
		return
	if not emitter.has_signal(signal_name):
		return
	if emitter.is_connected(signal_name, callable):
		return
	emitter.connect(signal_name, callable)


func _on_roll_started() -> void:
	_trigger_family("roll", _scaled_intensity(0.26))


func _on_roll_complete() -> void:
	_trigger_family("roll", _scaled_intensity(0.34))


func _on_about_to_score(_section, category: String, _dice_values: Array[int]) -> void:
	if not _allow_event("score_prelude", int(EVENT_COOLDOWNS["score_prelude"]), 0.4):
		return
	_effect_target_lock_sweep(_scaled_intensity(0.36), category)


func _on_score_assigned(_section, category: String, score: int) -> void:
	var intensity = _scaled_intensity(0.30, clampf(float(score) / 80.0, 0.0, 0.48))
	_trigger_family("score", intensity, category)


func _on_score_auto_assigned(_section, category: String, score: int, _breakdown_info: Dictionary) -> void:
	var intensity = _scaled_intensity(0.34, clampf(float(score) / 72.0, 0.0, 0.55))
	_trigger_family("score", intensity, category)


func _on_score_changed(total_score: int) -> void:
	_last_total_score = total_score


func _on_upper_bonus_achieved(bonus: int) -> void:
	_effect_success_burst(_scaled_intensity(0.62, clampf(float(bonus) / 60.0, 0.0, 0.3)), "upper_bonus")


func _on_yahtzee_bonus_achieved(points: int) -> void:
	_effect_success_burst(_scaled_intensity(0.82, clampf(float(points) / 100.0, 0.0, 0.18)), "yahtzee_bonus")


func _on_hand_scored() -> void:
	if _allow_event("score_prelude", 90, 0.28):
		_effect_banked_settle(_scaled_intensity(0.28), "hand_scored")


func _on_power_up_granted(id: String, _power_up) -> void:
	_trigger_family("power", _scaled_intensity(0.46), id)


func _on_consumable_used(id: String, _consumable) -> void:
	_trigger_family("consumable", _scaled_intensity(0.44), id)


func _on_debuff_blocked(_debuff_id: String) -> void:
	_effect_aura_latch(_scaled_intensity(0.42), "blocked")


func _on_debuff_applied(id: String, _debuff) -> void:
	_trigger_family("debuff", _scaled_intensity(0.48), id)


func _on_turn_updated(_turn: int) -> void:
	pass


func _on_round_started(round_number: int) -> void:
	if round_number <= 1:
		return
	if _allow_event("challenge", 220, 0.4):
		_effect_heroic_rise(_scaled_intensity(0.38), "round_%d" % round_number)


func _on_challenge_activated(id: String) -> void:
	_trigger_family("challenge", _scaled_intensity(0.42), id)


func _on_challenge_completed(id: String) -> void:
	if not _allow_event("challenge_terminal", int(EVENT_COOLDOWNS["challenge_terminal"]), 0.82):
		return
	_effect_success_burst(_scaled_intensity(0.78), id)


func _on_challenge_failed(id: String) -> void:
	if not _allow_event("challenge_terminal", int(EVENT_COOLDOWNS["challenge_terminal"]), 0.72):
		return
	_effect_failure_collapse(_scaled_intensity(0.72), id)


func _scaled_intensity(base_intensity: float, magnitude_bonus: float = 0.0) -> float:
	var round_factor := 0.0
	var turn_factor := 0.0
	if _game_controller:
		var round_manager = _game_controller.get("round_manager")
		if round_manager:
			round_factor = clampf(float(int(round_manager.get("current_round"))) / 5.0, 0.0, 1.0) * 0.22
		var turn_tracker = _game_controller.get("turn_tracker")
		if turn_tracker:
			turn_factor = clampf(float(maxi(int(turn_tracker.get("current_turn")) - 1, 0)) / 12.0, 0.0, 1.0) * 0.18
	return clampf(base_intensity + magnitude_bonus + round_factor + turn_factor, 0.18, 1.0)


func _trigger_family(family: String, intensity: float, variant: String = "") -> void:
	var pool = EFFECT_POOLS.get(family, [])
	if pool.is_empty():
		return
	var cooldown = int(EVENT_COOLDOWNS.get(family, 160))
	if not _allow_event(family, cooldown, intensity):
		return

	var method_name = pool[randi() % pool.size()]
	if has_method(method_name):
		call(method_name, clampf(intensity, 0.18, 1.0), variant)
		_play_secondary_accent(family, intensity)
		debug_effect_played.emit(method_name, intensity)


func _allow_event(event_key: String, cooldown_ms: int, intensity: float) -> bool:
	var now = Time.get_ticks_msec()
	var adjusted_cooldown = int(maxf(45.0, float(cooldown_ms) * (1.0 - intensity * 0.35)))
	var last = int(_event_stamps.get(event_key, -1000000))
	if now - last < adjusted_cooldown:
		return false
	_event_stamps[event_key] = now
	return true


func _play_secondary_accent(family: String, intensity: float) -> void:
	if _letters.is_empty():
		return
	if randf() > 0.24 + intensity * 0.32:
		return

	var letter = _letters[randi() % _letters.size()]
	match family:
		"roll":
			letter.play_tilt(lerpf(4.0, 10.0, intensity), 0.18)
		"score":
			letter.play_glow_burst(lerpf(0.35, 0.75, intensity), 0.22)
		"consumable":
			letter.play_tint_pulse(accent_title_color.lerp(secondary_accent_color, 0.5), 0.24)
		"power":
			letter.play_tint_pulse(power_color, 0.28)
		"debuff":
			letter.play_tint_pulse(warning_color, 0.22)
		"challenge":
			letter.play_flash_burst(lerpf(0.35, 0.9, intensity), 0.24)


func _effect_rattle_jitter(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.value_change(_title_box)
	for letter in _letters:
		letter.play_shake(lerpf(1.8, 6.5, intensity), 3 + int(round(intensity * 2.0)), 0.12 + intensity * 0.05)
		letter.play_tilt(randf_range(-1.0, 1.0) * lerpf(4.0, 9.0, intensity), 0.18)


func _effect_tumble_wave(intensity: float, _variant: String) -> void:
	var delay_step = lerpf(0.018, 0.05, intensity)
	for i in range(_letters.size()):
		_run_delayed_letter_call(_letters[i], "play_bounce", delay_step * i, [lerpf(7.0, 16.0, intensity), lerpf(2.0, 5.5, intensity), 0.26 + intensity * 0.08])
		_run_delayed_letter_call(_letters[i], "play_tilt", delay_step * i, [randf_range(-1.0, 1.0) * lerpf(3.0, 8.0, intensity), 0.18])


func _effect_stagger_bounce(intensity: float, _variant: String) -> void:
	var center_index = float(_letters.size() - 1) * 0.5
	for i in range(_letters.size()):
		var distance = abs(float(i) - center_index)
		var delay = distance * lerpf(0.014, 0.04, intensity)
		var height = lerpf(6.0, 15.0, intensity) * (1.0 - distance * 0.05)
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [height, lerpf(2.0, 4.0, intensity), 0.24 + intensity * 0.08])


func _effect_jackpot_flash(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.positive_reward(_title_box)
	for letter in _letters:
		letter.play_flash_burst(lerpf(0.45, 1.0, intensity), 0.24)
		letter.play_tint_pulse(base_title_color.lerp(success_color, 0.55), 0.28)


func _effect_banked_settle(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.value_change(_title_box)
	for i in range(_letters.size()):
		var delay = lerpf(0.01, 0.03, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_squash_stretch", delay, [lerpf(0.25, 0.75, intensity)])
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [lerpf(4.0, 10.0, intensity), lerpf(1.0, 3.0, intensity), 0.20 + intensity * 0.06])


func _effect_pop_count_ripple(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var delay = lerpf(0.012, 0.035, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_glow_burst", delay, [lerpf(0.3, 0.8, intensity), 0.18 + intensity * 0.08])
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [lerpf(5.0, 12.0, intensity), lerpf(1.0, 3.5, intensity), 0.24])


func _effect_sweep_highlight(intensity: float, _variant: String) -> void:
	var colors = [accent_title_color, secondary_accent_color, success_color]
	for i in range(_letters.size()):
		var delay = lerpf(0.016, 0.04, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [colors[i % colors.size()], 0.22 + intensity * 0.08])


func _effect_glitch_split(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var tint = secondary_accent_color if i % 2 == 0 else accent_title_color
		var delay = lerpf(0.008, 0.02, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_shake", delay, [lerpf(2.5, 7.0, intensity), 4, 0.11 + intensity * 0.05])
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [tint, 0.18 + intensity * 0.08])


func _effect_rewind_snap(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var reverse_index = _letters.size() - 1 - i
		var delay = lerpf(0.012, 0.03, intensity) * i
		_run_delayed_letter_call(_letters[reverse_index], "play_tilt", delay, [randf_range(-1.0, 1.0) * lerpf(4.0, 11.0, intensity), 0.16 + intensity * 0.08])
		_run_delayed_letter_call(_letters[reverse_index], "play_bounce", delay, [lerpf(4.0, 11.0, intensity), lerpf(1.0, 3.0, intensity), 0.22])


func _effect_fizz_pop(intensity: float, _variant: String) -> void:
	for letter in _letters:
		if randf() < 0.65:
			letter.play_bounce(lerpf(4.0, 12.0, intensity), lerpf(1.0, 3.0, intensity), 0.22)
			letter.play_tint_pulse(accent_title_color.lerp(success_color, randf()), 0.2 + intensity * 0.08)


func _effect_aura_latch(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.spotlight_enter(_title_box, Color(1.2, 1.15, 1.05, 1.0))
		_run_delayed_local_call("_spotlight_exit_title_box", 0.32 + intensity * 0.18)
	for letter in _letters:
		letter.play_glow_burst(lerpf(0.32, 0.72, intensity), 0.22 + intensity * 0.08)


func _effect_empowered_lift(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.positive_reward(_title_box)
	for i in range(_letters.size()):
		var delay = lerpf(0.012, 0.03, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [lerpf(7.0, 17.0, intensity), lerpf(2.0, 5.0, intensity), 0.28])
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [power_color, 0.24 + intensity * 0.08])


func _effect_resonance_shimmer(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var delay = lerpf(0.01, 0.025, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_glow_burst", delay, [lerpf(0.28, 0.7, intensity), 0.2 + intensity * 0.1])
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [power_color.lerp(success_color, 0.35), 0.22 + intensity * 0.08])


func _effect_static_stutter(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.negative_hit(_title_box)
	for letter in _letters:
		letter.play_shake(lerpf(3.0, 8.0, intensity), 4 + int(round(intensity * 2.0)), 0.14 + intensity * 0.05)
		letter.play_tint_pulse(warning_color, 0.2 + intensity * 0.08)


func _effect_alarm_flicker(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var tint = warning_color if i % 2 == 0 else accent_title_color
		var delay = lerpf(0.006, 0.014, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_flash_burst", delay, [lerpf(0.25, 0.75, intensity), 0.18 + intensity * 0.05])
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [tint, 0.16 + intensity * 0.06])


func _effect_compression_squeeze(intensity: float, _variant: String) -> void:
	for letter in _letters:
		letter.play_squash_stretch(lerpf(0.22, 0.7, intensity))
		letter.play_tint_pulse(warning_color.darkened(0.1), 0.22 + intensity * 0.08)


func _effect_target_lock_sweep(intensity: float, _variant: String) -> void:
	for i in range(_letters.size()):
		var delay = lerpf(0.014, 0.03, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [secondary_accent_color, 0.18 + intensity * 0.07])
		_run_delayed_letter_call(_letters[i], "play_tilt", delay, [lerpf(3.0, 7.0, intensity), 0.16])


func _effect_heroic_rise(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.spotlight_enter(_title_box, Color(1.2, 1.2, 1.3, 1.0))
		_run_delayed_local_call("_spotlight_exit_title_box", 0.36 + intensity * 0.18)
	for i in range(_letters.size()):
		var delay = lerpf(0.018, 0.04, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [lerpf(5.0, 13.0, intensity), lerpf(1.0, 4.0, intensity), 0.26])
		_run_delayed_letter_call(_letters[i], "play_glow_burst", delay, [lerpf(0.25, 0.65, intensity), 0.2 + intensity * 0.08])


func _effect_success_burst(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.celebration(_title_box)
	for i in range(_letters.size()):
		var delay = lerpf(0.01, 0.03, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_flash_burst", delay, [lerpf(0.45, 1.0, intensity), 0.22 + intensity * 0.08])
		_run_delayed_letter_call(_letters[i], "play_bounce", delay, [lerpf(8.0, 18.0, intensity), lerpf(2.0, 5.0, intensity), 0.3])
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [success_color, 0.26 + intensity * 0.08])


func _effect_failure_collapse(intensity: float, _variant: String) -> void:
	if _tfx:
		_tfx.negative_hit(_title_box)
	for i in range(_letters.size()):
		var delay = lerpf(0.008, 0.02, intensity) * i
		_run_delayed_letter_call(_letters[i], "play_tint_pulse", delay, [warning_color, 0.22 + intensity * 0.08])
		_run_delayed_letter_call(_letters[i], "play_squash_stretch", delay, [lerpf(0.28, 0.78, intensity)])
		_run_delayed_letter_call(_letters[i], "play_shake", delay, [lerpf(2.0, 6.0, intensity), 3, 0.12 + intensity * 0.05])


func _run_delayed_letter_call(letter, method_name: String, delay: float, args: Array) -> void:
	await get_tree().create_timer(delay).timeout
	if is_instance_valid(letter):
		letter.callv(method_name, args)


func _run_delayed_local_call(method_name: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if has_method(method_name):
		call(method_name)


func _spotlight_exit_title_box() -> void:
	if _tfx:
		_tfx.spotlight_exit(_title_box)