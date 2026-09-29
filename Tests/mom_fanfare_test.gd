extends Control
class_name MomFanfareTest

## MomFanfareTest
##
## Test scene for the Mom buff/debuff arrival fanfare. Builds mock registries
## (game controller, chore_ui buff icons, debuff_ui icons, power_up_ui spines)
## and drives MomJuiceCoordinator's arm/diff/play flow exactly the way
## GameController does after a Mom visit.
##
## Buttons simulate Mom consequences; watch/print-verifies:
## - fanfare icon spawns off-screen right and overshoot-flies to the slot
## - landing scale punch + tinted explosion + ring
## - slot squash-hop; buff slot hidden until landing, then fades in
## - debuff variant: red tint + "-" flash
## - multiple buffs stagger top-to-bottom
## - fanfare waits for a running scoring animation (queue gate)

const WHITE_PIXEL: Texture2D = preload("res://Resources/Art/UI/white_pixel.png")


class MockMomResult extends RefCounted:
	var removed_power_ups: Array = []
	var fine_amount: int = 0


class MockPowerUpDef extends RefCounted:
	var icon: Texture2D
	var display_name: String


class MockChoreUI extends Control:
	var _buff_icons: Dictionary = {}


class MockDebuffUI extends Control:
	var _icons: Dictionary = {}
	func get_debuff_icon(id: String):
		return _icons.get(id)


class MockPowerUpUI extends Control:
	var _spines: Dictionary = {}


class MockDebuffManager extends RefCounted:
	func get_def(_id: String):
		return null  # FanfareIcon handles null DebuffData (placeholder glyph)


class MockPowerUpManager extends RefCounted:
	var def := MockPowerUpDef.new()
	func get_def(_id: String):
		return def


class MockMomDialog extends Control:
	func get_portrait_center() -> Vector2:
		return get_global_rect().get_center()


class MockGameController extends Control:
	@warning_ignore("unused_signal")
	signal consumable_used  # ProgressManager connects to this on group members
	var chore_ui
	var debuff_ui
	var debuff_manager
	var pu_manager
	var _mom_dialog


class MockScoringController extends Control:
	# Duck-types the scoring controller's queue-gate surface.
	var animation_in_progress: bool = false
	signal animation_sequence_complete


var _gc: MockGameController
var _chore_ui: MockChoreUI
var _debuff_ui: MockDebuffUI
var _power_up_ui: MockPowerUpUI
var _scoring: MockScoringController
var _log: Label
var _press_counter: int = 0

## When true, the scene runs every scenario on a timer (used for automated
## verification runs; buttons remain for manual use).
const AUTO_DEMO: bool = true


func _ready() -> void:
	print("[MomFanfareTest] Initializing test scene...")
	_build_mocks()
	_build_buttons()
	print("[MomFanfareTest] Ready. Click buttons to trigger fanfares.")
	if AUTO_DEMO:
		_run_auto_demo()


func _run_auto_demo() -> void:
	print("[MomFanfareTest] AUTO-DEMO: starting scenario sequence")
	await get_tree().create_timer(1.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: buff (powerup)")
	_on_buff_powerup()
	await get_tree().create_timer(2.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: buff (chore/mom)")
	_on_buff_chore()
	await get_tree().create_timer(2.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: debuff")
	_on_debuff()
	await get_tree().create_timer(2.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: buff x3 stagger")
	_on_buff_x3()
	await get_tree().create_timer(3.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: queue gate")
	_on_queue_gate()
	await get_tree().create_timer(4.0).timeout
	print("[MomFanfareTest] AUTO-DEMO: complete")


func _build_mocks() -> void:
	_gc = MockGameController.new()
	_gc.name = "MockGameController"
	_gc.add_to_group("game_controller")
	add_child(_gc)

	_chore_ui = MockChoreUI.new()
	_chore_ui.name = "MockChoreUI"
	add_child(_chore_ui)
	_gc.chore_ui = _chore_ui

	_debuff_ui = MockDebuffUI.new()
	_debuff_ui.name = "MockDebuffUI"
	add_child(_debuff_ui)
	_gc.debuff_ui = _debuff_ui

	_power_up_ui = MockPowerUpUI.new()
	_power_up_ui.name = "MockPowerUpUI"
	_power_up_ui.add_to_group("power_up_ui")
	add_child(_power_up_ui)

	_gc.debuff_manager = MockDebuffManager.new()
	var pu_manager := MockPowerUpManager.new()
	pu_manager.def.icon = WHITE_PIXEL
	pu_manager.def.display_name = "Sass Buddy"
	_gc.pu_manager = pu_manager

	var mom_dialog := MockMomDialog.new()
	mom_dialog.name = "MockMomDialog"
	mom_dialog.position = Vector2(560, 120)
	mom_dialog.size = Vector2(160, 120)
	var mom_panel := Panel.new()
	mom_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	mom_dialog.add_child(mom_panel)
	var mom_label := Label.new()
	mom_label.text = "MOM"
	mom_label.set_anchors_preset(Control.PRESET_CENTER)
	mom_panel.add_child(mom_label)
	add_child(mom_dialog)
	_gc._mom_dialog = mom_dialog

	_scoring = MockScoringController.new()
	_scoring.name = "MockScoringController"
	_scoring.add_to_group("scoring_animation_controller")
	add_child(_scoring)

	_log = Label.new()
	_log.position = Vector2(20, 660)
	_log.add_theme_font_size_override("font_size", 14)
	add_child(_log)


func _build_buttons() -> void:
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(20, 20)
	add_child(vbox)

	_add_button(vbox, "Buff (powerup)", _on_buff_powerup)
	_add_button(vbox, "Buff (chore/mom)", _on_buff_chore)
	_add_button(vbox, "Debuff", _on_debuff)
	_add_button(vbox, "Buff x3 stagger", _on_buff_x3)
	_add_button(vbox, "Fanfare behind scoring (queue)", _on_queue_gate)


func _add_button(parent: Control, text: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(handler)
	parent.add_child(button)


## Simulates GameController: arm -> apply (insert new icon) -> play.
func _simulate_mom_grant(kind: String, ids: Array) -> void:
	var result := MockMomResult.new()
	MomJuiceCoordinator.arm_money_pull(result)
	for i in range(ids.size()):
		# Unique id per press so the coordinator's arm/diff always sees "new".
		var unique_id: String = "%s_%d" % [ids[i], _press_counter]
		_press_counter += 1
		var slot := _make_slot(kind, unique_id, i)
		match kind:
			"powerup":
				_power_up_ui._spines[unique_id] = slot
			"buff":
				_chore_ui._buff_icons[unique_id] = slot
			"debuff":
				_debuff_ui._icons[unique_id] = slot
	MomJuiceCoordinator.play_post_mom_sequence(result)
	_log.text = "Granted %s: %s — watch fanfare" % [kind, str(ids)]
	print("[MomFanfareTest] Granted %s: %s" % [kind, str(ids)])


func _make_slot(kind: String, id: String, index: int) -> Panel:
	var slot := Panel.new()
	slot.name = "Slot_%s" % id
	slot.size = Vector2(64, 64)
	slot.custom_minimum_size = Vector2(64, 64)
	var y := 200.0 + index * 80.0
	match kind:
		"powerup":
			slot.position = Vector2(1000, y)
		"buff":
			slot.position = Vector2(900, y)
		"debuff":
			slot.position = Vector2(800, y)
	var label := Label.new()
	label.text = id.substr(0, 4).to_upper()
	label.set_anchors_preset(Control.PRESET_CENTER)
	slot.add_child(label)
	add_child(slot)
	return slot


func _on_buff_powerup() -> void:
	_simulate_mom_grant("powerup", ["sass_buddy"])


func _on_buff_chore() -> void:
	_simulate_mom_grant("buff", ["rebellion"])


func _on_debuff() -> void:
	_simulate_mom_grant("debuff", ["lock_dice"])


func _on_buff_x3() -> void:
	_simulate_mom_grant("buff", ["buff_a", "buff_b", "buff_c"])


func _on_queue_gate() -> void:
	_log.text = "Scoring busy 1.5s — fanfare must wait its turn"
	print("[MomFanfareTest] Scoring marked busy; fanfare should queue")
	_scoring.animation_in_progress = true
	_simulate_mom_grant("buff", ["queued_buff"])
	get_tree().create_timer(1.5).timeout.connect(func():
		print("[MomFanfareTest] Scoring complete — fanfare may start")
		_scoring.animation_in_progress = false
		_scoring.animation_sequence_complete.emit()
	)
