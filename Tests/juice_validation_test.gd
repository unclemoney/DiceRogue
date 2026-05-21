extends Control

## juice_validation_test.gd
##
## Visual test scene for Stage 4–6 juice effects.
## Creates a grid of buttons to verify each new FX implementation.
## Run: & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --path "c:\Users\danie\Documents\dicerogue\DiceRogue" Tests/JuiceValidationTest.tscn

var vcr_font: Font = preload("res://Resources/Font/VCR_OSD_MONO_1.001.ttf")

var _tfx: Node = null
var _status_label: RichTextLabel
var _demo_button: Button
var _challenge_icon: ChallengeIcon

func _ready() -> void:
	print("\n=== JUICE VALIDATION TEST ===")
	_tfx = get_node_or_null("/root/TweenFXHelper")

	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.1, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Scrollable container
	var scroll = ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	scroll.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "JUICE VALIDATION TEST (Stages 4–6)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if vcr_font:
		title.add_theme_font_override("font", vcr_font)
		title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.32, 1.0))
	vbox.add_child(title)

	# Status label
	_status_label = RichTextLabel.new()
	_status_label.bbcode_enabled = true
	_status_label.fit_content = true
	_status_label.scroll_active = false
	_status_label.custom_minimum_size = Vector2(0, 30)
	if vcr_font:
		_status_label.add_theme_font_override("normal_font", vcr_font)
		_status_label.add_theme_font_size_override("normal_font_size", 14)
	_status_label.text = "[color=gray]Click any button to test an effect.[/color]"
	vbox.add_child(_status_label)

	# Demo target button (used by multiple tests)
	var demo_label = _create_section_label("DEMO TARGET")
	vbox.add_child(demo_label)
	_demo_button = _create_test_button("TARGET", Color(0.3, 0.5, 0.7))
	_demo_button.custom_minimum_size = Vector2(160, 50)
	vbox.add_child(_demo_button)

	# Section: Time & Camera
	vbox.add_child(_create_section_label("TIME & CAMERA"))
	var row1 = _create_row()
	vbox.add_child(row1)
	row1.add_child(_create_effect_button("Hitstop (5f)", _test_hitstop))
	row1.add_child(_create_effect_button("Camera Zoom", _test_camera_zoom))
	row1.add_child(_create_effect_button("Celebration", _test_celebration))

	# Section: Floating Text
	vbox.add_child(_create_section_label("FLOATING TEXT"))
	var row2 = _create_row()
	vbox.add_child(row2)
	row2.add_child(_create_effect_button("Jackpot Popup", _test_jackpot_popup))
	row2.add_child(_create_effect_button("Streak Popup", _test_streak_popup))

	# Section: Button FX
	vbox.add_child(_create_section_label("BUTTON FX"))
	var row3 = _create_row()
	vbox.add_child(row3)
	row3.add_child(_create_effect_button("Negative Hit", _test_negative_hit))
	row3.add_child(_create_effect_button("Positive Reward", _test_positive_reward))
	row3.add_child(_create_effect_button("Spotlight", _test_spotlight))
	row3.add_child(_create_effect_button("Threat Alarm", _test_threat_alarm))

	# Section: Score & Count-up
	vbox.add_child(_create_section_label("SCORE & COUNT-UP"))
	var row4 = _create_row()
	vbox.add_child(row4)
	row4.add_child(_create_effect_button("Score Count-Up", _test_score_countup))
	row4.add_child(_create_effect_button("Challenge Count-Up", _test_challenge_countup))
	row4.add_child(_create_effect_button("Confirm Sound", _test_confirm_sound))

	# Section: Scene Transitions
	vbox.add_child(_create_section_label("SCENE TRANSITIONS"))
	var row5 = _create_row()
	vbox.add_child(row5)
	row5.add_child(_create_effect_button("Fade", _test_fade_transition))
	row5.add_child(_create_effect_button("CRT Wipe", _test_crt_wipe_transition))
	row5.add_child(_create_effect_button("Crossfade", _test_crossfade_transition))

	# Section: Game Over Ceremony
	vbox.add_child(_create_section_label("GAME OVER CEREMONY"))
	var row6 = _create_row()
	vbox.add_child(row6)
	row6.add_child(_create_effect_button("Loss CRT Off", _test_loss_crt_off))
	row6.add_child(_create_effect_button("Win Popup", _test_win_popup))

	# Challenge icon preview area
	vbox.add_child(_create_section_label("CHALLENGE ICON PREVIEW"))
	var challenge_row = _create_row()
	vbox.add_child(challenge_row)
	_challenge_icon = _create_test_challenge_icon()
	challenge_row.add_child(_challenge_icon)

	print("[JuiceValidationTest] Ready. Press F12 to open Debug Panel for more tests.")


func _create_section_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if vcr_font:
		label.add_theme_font_override("font", vcr_font)
		label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75, 1.0))
	return label


func _create_row() -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	return row


func _create_test_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	if vcr_font:
		btn.add_theme_font_override("font", vcr_font)
		btn.add_theme_font_size_override("font_size", 16)
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	return btn


func _create_effect_button(text: String, callback: Callable) -> Button:
	var btn = _create_test_button(text, Color(0.25, 0.25, 0.35))
	btn.pressed.connect(callback)
	if _tfx:
		btn.mouse_entered.connect(_tfx.button_hover.bind(btn))
		btn.mouse_exited.connect(_tfx.button_unhover.bind(btn))
		btn.pressed.connect(_tfx.button_press.bind(btn))
	return btn


func _create_test_challenge_icon() -> ChallengeIcon:
	var icon = ChallengeIcon.new()
	icon.custom_minimum_size = Vector2(80, 120)
	var data = ChallengeData.new()
	data.id = "test_challenge"
	data.display_name = "Test Challenge"
	data.description = "A test challenge for validation."
	data.target_score = 500
	icon.set_data_with_target_score(data, 500)
	return icon


func _update_status(text: String) -> void:
	_status_label.text = "[color=#aaaaaa]%s[/color]" % text
	print("[JuiceValidationTest] %s" % text)


# ─── TEST METHODS ───────────────────────────────────────────────────────────

func _test_hitstop() -> void:
	HitstopController.trigger_hitstop(5)
	_update_status("Hitstop: 5 frames")


func _test_camera_zoom() -> void:
	var cam = get_viewport().get_camera_2d()
	if cam and cam.has_node("CameraDynamics"):
		cam.get_node("CameraDynamics").celebrate_zoom(0.6)
		_update_status("Camera celebrate_zoom triggered")
	else:
		# Fallback: try CameraDynamics on self if no camera
		var dyn = CameraDynamics.new()
		add_child(dyn)
		dyn.celebrate_zoom(0.6)
		_update_status("CameraDynamics celebrate_zoom (fallback on Control)")
		await get_tree().create_timer(1.0).timeout
		dyn.queue_free()


func _test_celebration() -> void:
	var celebration = ChallengeCelebration.new()
	get_tree().root.add_child(celebration)
	celebration.trigger_celebration(get_viewport().get_visible_rect().size / 2.0, get_tree().root)
	_update_status("Celebration firework at screen center")


func _test_jackpot_popup() -> void:
	var ftm = get_node_or_null("/root/FloatingTextManager")
	if ftm:
		ftm.show_jackpot_popup(_demo_button)
		_update_status("FloatingTextManager.show_jackpot_popup()")
	else:
		_update_status("ERROR: FloatingTextManager not found")


func _test_streak_popup() -> void:
	var ftm = get_node_or_null("/root/FloatingTextManager")
	if ftm:
		ftm.show_streak_popup(_demo_button, 1.5)
		_update_status("FloatingTextManager.show_streak_popup(1.5x)")
	else:
		_update_status("ERROR: FloatingTextManager not found")


func _test_negative_hit() -> void:
	if _tfx:
		_tfx.negative_hit(_demo_button)
		_update_status("negative_hit on demo button")
	else:
		_update_status("ERROR: TweenFXHelper not found")


func _test_positive_reward() -> void:
	if _tfx:
		_tfx.positive_reward(_demo_button)
		_update_status("positive_reward on demo button")
	else:
		_update_status("ERROR: TweenFXHelper not found")


func _test_spotlight() -> void:
	if _tfx:
		_tfx.spotlight_enter(_demo_button)
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_demo_button):
				_tfx.spotlight_exit(_demo_button)
		)
		_update_status("spotlight_enter → exit (0.5s)")
	else:
		_update_status("ERROR: TweenFXHelper not found")


func _test_threat_alarm() -> void:
	if _tfx:
		_tfx.threat_alarm(_demo_button)
		get_tree().create_timer(2.0).timeout.connect(func():
			if is_instance_valid(_demo_button):
				_tfx.stop_effect(_demo_button)
		)
		_update_status("threat_alarm on demo button (2s)")
	else:
		_update_status("ERROR: TweenFXHelper not found")


func _test_score_countup() -> void:
	if _tfx:
		var label = Label.new()
		label.text = "0"
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.add_theme_font_size_override("font_size", 48)
		add_child(label)
		_tfx.score_count_up(label, 0, 999, 1.5)
		_update_status("score_count_up 0→999 (1.5s)")
		await get_tree().create_timer(2.5).timeout
		if is_instance_valid(label):
			label.queue_free()
	else:
		_update_status("ERROR: TweenFXHelper not found")


func _test_challenge_countup() -> void:
	if _challenge_icon:
		_challenge_icon.animate_target_score_countup()
		_update_status("ChallengeIcon.animate_target_score_countup()")
	else:
		_update_status("ERROR: ChallengeIcon not found")


func _test_confirm_sound() -> void:
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_confirm_sound"):
		audio_mgr.play_confirm_sound()
		_update_status("AudioManager.play_confirm_sound()")
	else:
		_update_status("ERROR: AudioManager not found or missing method")


func _test_fade_transition() -> void:
	var stm = get_node_or_null("/root/SceneTransitionManager")
	if stm:
		stm.transition_to_scene(get_tree().current_scene.scene_file_path, stm.Style.FADE, 0.8)
		_update_status("SceneTransitionManager: FADE (self-loop)")
	else:
		_update_status("ERROR: SceneTransitionManager not found")


func _test_crt_wipe_transition() -> void:
	var stm = get_node_or_null("/root/SceneTransitionManager")
	if stm:
		stm.transition_to_scene(get_tree().current_scene.scene_file_path, stm.Style.CRT_WIPE, 0.8)
		_update_status("SceneTransitionManager: CRT_WIPE (self-loop)")
	else:
		_update_status("ERROR: SceneTransitionManager not found")


func _test_crossfade_transition() -> void:
	var stm = get_node_or_null("/root/SceneTransitionManager")
	if stm:
		stm.transition_to_scene(get_tree().current_scene.scene_file_path, stm.Style.CROSSFADE, 1.0)
		_update_status("SceneTransitionManager: CROSSFADE (self-loop)")
	else:
		_update_status("ERROR: SceneTransitionManager not found")


func _test_loss_crt_off() -> void:
	# Replicate the CRT power-off effect from game_controller loss ceremony
	var crt_off = ColorRect.new()
	crt_off.name = "TestCRTPowerOff"
	crt_off.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_off.z_index = 99
	crt_off.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var off_mat = ShaderMaterial.new()
	off_mat.shader = preload("res://Scripts/Shaders/tv_power_on.gdshader")
	off_mat.set_shader_parameter("progress", 1.0)
	off_mat.set_shader_parameter("beam_color", Color(1.0, 0.2, 0.2, 1.0))
	crt_off.material = off_mat
	add_child(crt_off)

	var off_tween = create_tween()
	off_tween.tween_method(func(v): off_mat.set_shader_parameter("progress", v), 1.0, 0.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	off_tween.tween_property(crt_off, "modulate:a", 0.0, 0.2)
	off_tween.tween_callback(crt_off.queue_free)

	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_denied_sound"):
		audio_mgr.play_denied_sound()

	_update_status("Loss ceremony: CRT power-off + denied sound")


func _test_win_popup() -> void:
	# Show a simplified win popup (no actual game over)
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	add_child(overlay)

	var popup = PanelContainer.new()
	popup.custom_minimum_size = Vector2(400, 200)
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.z_index = 101
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.12, 0.1, 0.98)
	style.border_color = Color(0.8, 0.6, 0.2, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(12)
	popup.add_theme_stylebox_override("panel", style)
	overlay.add_child(popup)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	popup.add_child(vbox)

	var title = RichTextLabel.new()
	title.bbcode_enabled = true
	title.fit_content = true
	title.scroll_active = false
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "[center][color=gold][shake rate=10 level=5]CHALLENGE COMPLETE![/shake][/color][/center]"
	title.add_theme_font_size_override("normal_font_size", 32)
	vbox.add_child(title)

	var score = Label.new()
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.text = "Final Score: 9999"
	score.add_theme_font_size_override("font_size", 24)
	vbox.add_child(score)

	popup.scale = Vector2(0.5, 0.5)
	popup.modulate.a = 0
	var tween = create_tween().set_parallel()
	tween.tween_property(popup, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 1.0, 0.2)

	# Count up the score
	var count_tween = create_tween()
	count_tween.tween_method(func(v: float):
		score.text = "Final Score: %d" % int(v)
	, 0.0, 9999.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_update_status("Win popup with score count-up")

	# Auto-dismiss after 3s
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(overlay):
		var fade = create_tween()
		fade.tween_property(overlay, "modulate:a", 0.0, 0.3)
		fade.tween_callback(overlay.queue_free)
