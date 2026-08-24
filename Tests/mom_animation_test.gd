extends Node

## mom_animation_test.gd
##
## Verifies Mom's animated portrait system:
## - generated SpriteFrames resource (10 clips x 8 frames, loop/fps flags)
## - mood (0-10) -> 5 animation states -> speech clip selection
## - typewriter reveal gates the speech loop (start/stop)
## - reaction one-shots interrupt speech and resume it afterwards
## - priority rules: mood-gated availability, FORCED bypass, queue depth 1
## - blink only fires from IDLE
##
## Scene-based test (autoloads must be compiled first).
## Run headless:
##   godot --headless --path . Tests/MomAnimationTest.tscn -- --quit-after
## Exit code 0 = all checks passed, 1 = at least one failure.

const FRAMES_PATH := "res://Resources/Art/Characters/Mom/mom_portrait_frames.tres"
const LONG_TEXT := "This is a long line of dialog from Mom, designed to keep the typewriter revealing for a while so reactions can interrupt it."
## Preloaded (not the class_name) so parsing doesn't depend on the editor's
## class cache being fresh.
const Animator := preload("res://Scripts/UI/mom_portrait_animator.gd")

var _failures: int = 0


func _ready() -> void:
	print("[MomAnimationTest] Starting")
	await _test_spriteframes_resource()
	await _test_dialog_and_animator()

	if _failures == 0:
		print("[MomAnimationTest] PASS - all checks passed")
	else:
		print("[MomAnimationTest] FAIL - %d check(s) failed" % _failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(0 if _failures == 0 else 1)


func _test_spriteframes_resource() -> void:
	var frames := load(FRAMES_PATH) as SpriteFrames
	_check("SpriteFrames resource loads", frames != null)
	if frames == null:
		return
	var expected := {
		"idle": {"frames": 8, "loop": true, "fps": 6.0},
		"blink": {"frames": 8, "loop": false, "fps": 12.0},
		"shakehead": {"frames": 8, "loop": false, "fps": 12.0},
		"eyeroll": {"frames": 8, "loop": false, "fps": 12.0},
		"glare": {"frames": 8, "loop": false, "fps": 12.0},
		"angryshake": {"frames": 8, "loop": false, "fps": 12.0},
		"laugh": {"frames": 8, "loop": false, "fps": 12.0},
		"speech_happy": {"frames": 8, "loop": true, "fps": 10.0},
		"speech_normal": {"frames": 8, "loop": true, "fps": 10.0},
		"speech_angry": {"frames": 8, "loop": true, "fps": 10.0},
	}
	_check("10 clips present", frames.get_animation_names().size() == 10)
	for clip in expected:
		var def: Dictionary = expected[clip]
		_check("clip exists: %s" % clip, frames.has_animation(clip))
		if not frames.has_animation(clip):
			continue
		_check("%s has %d frames" % [clip, def["frames"]], frames.get_frame_count(clip) == def["frames"])
		_check("%s loop=%s" % [clip, def["loop"]], frames.get_animation_loop(clip) == def["loop"])
		_check("%s fps=%s" % [clip, def["fps"]], is_equal_approx(frames.get_animation_speed(clip), def["fps"]))
	await get_tree().process_frame


func _test_dialog_and_animator() -> void:
	var scene: PackedScene = load("res://Scenes/UI/mom_dialog_popup.tscn")
	var dialog = scene.instantiate()
	add_child(dialog)
	await get_tree().process_frame

	_check("portrait exists", dialog.portrait != null)
	if dialog.portrait == null:
		return
	var portrait: Animator = dialog.portrait
	_check("portrait has SpriteFrames", portrait.sprite_frames != null)
	_check("portrait starts on idle", portrait.animation == &"idle")
	_check("blink timer exists", portrait.get_node_or_null("BlinkTimer") != null)

	# ─── Mood mapping boundaries ───
	var mood_cases := [
		[0, Animator.MoodState.HAPPY],
		[4, Animator.MoodState.HAPPY],
		[5, Animator.MoodState.NEUTRAL],
		[6, Animator.MoodState.ANNOYED],
		[7, Animator.MoodState.ANNOYED],
		[8, Animator.MoodState.ANGRY],
		[9, Animator.MoodState.ANGRY],
		[10, Animator.MoodState.FURIOUS],
	]
	for mood_case in mood_cases:
		portrait.set_mood(mood_case[0])
		_check("mood %d -> state %d" % [mood_case[0], mood_case[1]], portrait.get_mood_state() == mood_case[1])

	# ─── Speech clip per mood ───
	portrait.set_mood(0)
	portrait.start_talking()
	_check("mood 0 speech_happy", portrait.animation == &"speech_happy")
	portrait.set_mood(5)
	_check("mid-talk mood 5 -> speech_normal (no pop, instant swap)", portrait.animation == &"speech_normal")
	portrait.set_mood(8)
	_check("mid-talk mood 8 -> speech_angry", portrait.animation == &"speech_angry")
	portrait.stop_talking()
	_check("stop_talking -> idle", portrait.animation == &"idle")

	# Expression hints override mood for speech selection
	portrait.set_mood(0)
	portrait.start_talking("upset")
	_check("hint 'upset' at mood 0 -> speech_normal (annoyed, not angry)", portrait.animation == &"speech_normal")
	portrait.set_mood(9)
	_check("hint 'upset' at mood 9 -> speech_angry", portrait.animation == &"speech_angry")
	portrait.stop_talking()
	portrait.set_expression_hint("neutral")

	# ─── Typewriter gates speech loop ───
	portrait.set_mood(5)
	dialog.show_dialog("neutral", LONG_TEXT)
	await get_tree().create_timer(0.3).timeout
	_check("typing started: some chars revealed", dialog.dialog_label.visible_characters > 0)
	_check("typing started: not all chars revealed", dialog.dialog_label.visible_characters < dialog.dialog_label.get_total_character_count())
	_check("speech loop while typing", String(portrait.animation).begins_with("speech"))
	# Let the reveal finish: chars * speed + punctuation slack
	await get_tree().create_timer(LONG_TEXT.length() * 0.03 + 2.0).timeout
	_check("reveal complete", dialog.dialog_label.visible_characters == -1)
	_check("idle after reveal", portrait.animation == &"idle")

	# ─── Reaction interrupts speech, resumes after ───
	dialog.show_dialog("neutral", LONG_TEXT)
	await get_tree().create_timer(0.3).timeout
	portrait.play_reaction(&"glare", Animator.ReactionPriority.FORCED)
	_check("reaction interrupts speech", portrait.animation == &"glare")
	_check("state is REACTING", portrait.get_state() == Animator.State.REACTING)
	# glare: 8 frames @ 12fps ~= 0.67s; wait for finish
	await get_tree().create_timer(1.0).timeout
	_check("speech resumes after reaction", String(portrait.animation).begins_with("speech"))
	# Let reveal finish -> idle
	await get_tree().create_timer(LONG_TEXT.length() * 0.03 + 2.0).timeout
	_check("idle after interrupted reveal completes", portrait.animation == &"idle")

	# ─── Availability: angry mom won't laugh on demand, unless FORCED ───
	portrait.set_mood(10)
	portrait.play_reaction(&"laugh", Animator.ReactionPriority.NORMAL)
	_check("laugh NORMAL blocked at mood 10", portrait.animation != &"laugh")
	portrait.play_reaction(&"laugh", Animator.ReactionPriority.FORCED)
	_check("laugh FORCED plays at mood 10 (sarcastic)", portrait.animation == &"laugh")
	await get_tree().create_timer(1.0).timeout

	# ─── Queue depth 1: reaction during reaction ───
	portrait.set_mood(10)
	portrait.play_reaction(&"glare", Animator.ReactionPriority.NORMAL)
	_check("glare plays (available at mood 10)", portrait.animation == &"glare")
	portrait.play_reaction(&"angryshake", Animator.ReactionPriority.NORMAL)
	_check("second reaction queued, not immediate", portrait.animation == &"glare")
	await get_tree().create_timer(1.0).timeout
	_check("queued reaction plays after first", portrait.animation == &"angryshake")
	await get_tree().create_timer(1.0).timeout
	_check("idle after queue drains", portrait.animation == &"idle")

	# ─── Blink only from IDLE ───
	portrait.start_talking()
	portrait._on_blink_timer_timeout()
	_check("no blink while speaking", String(portrait.animation).begins_with("speech"))
	portrait.stop_talking()
	portrait._on_blink_timer_timeout()
	# 10% fidget chance at mood 10 -> glare/angryshake; accept blink or a fidget
	var after_tick := String(portrait.animation)
	_check("idle tick fires blink or fidget", after_tick == "blink" or after_tick == "glare" or after_tick == "angryshake")
	await get_tree().create_timer(1.0).timeout

	# ─── Tone reactions ───
	portrait.set_mood(2)
	portrait.react_to_tone("polite")
	_check("polite at mood 2 -> laugh", portrait.animation == &"laugh")
	await get_tree().create_timer(1.0).timeout
	portrait.react_to_tone("sassy")
	_check("sassy at mood 2 -> forced eyeroll (never a laugh)", portrait.animation == &"eyeroll")
	await get_tree().create_timer(1.0).timeout

	# ─── Pause / resume ───
	portrait.set_paused(true)
	_check("paused stops blink timer", portrait.get_node("BlinkTimer").is_stopped())
	portrait.set_paused(false)
	_check("unpaused restarts blink timer", not portrait.get_node("BlinkTimer").is_stopped())

	# ─── Portrait center accessor (confiscation fly target) ───
	_check("get_portrait_center matches portrait", dialog.get_portrait_center() == portrait.global_position)

	# ─── Portrait sits flush with the frame's inner bottom edge ───
	await get_tree().process_frame
	var frame_panel: PanelContainer = portrait.get_parent()
	var portrait_bottom := portrait.position.y + (MomCharacter.PORTRAIT_FRAME_SIZE * portrait.scale.y) / 2.0
	var frame_inner_bottom := frame_panel.size.y - MomCharacter.PORTRAIT_BORDER_WIDTH
	_check("portrait feet flush with inner bottom border", is_equal_approx(portrait_bottom, frame_inner_bottom))

	dialog.queue_free()
	await get_tree().process_frame


func _check(label: String, condition: bool) -> void:
	if condition:
		print("[MomAnimationTest] OK: " + label)
	else:
		push_error("[MomAnimationTest] FAILED: " + label)
		_failures += 1
