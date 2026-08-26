extends Control

## window_shopping_test.gd
##
## Verifies the Window Shopping debuff (id "window_shopping"):
## resource config, scene instantiation, and stack apply/remove behavior
## against a stub GameController (the real one is scene-heavy).

@onready var results_label: RichTextLabel = $VBoxContainer/ResultsLabel

var _failures: int = 0
var _lines: Array[String] = []


## StubGameController
##
## Minimal stand-in exposing the property the debuff writes to.
class StubGameController extends Node:
	var window_shopping_stacks: int = 0


func _ready() -> void:
	print("\n=== WINDOW SHOPPING DEBUFF TEST ===")
	await get_tree().process_frame
	_run_tests()
	_finish()


func _check(condition: bool, label: String) -> void:
	var status := "PASS" if condition else "FAIL"
	if not condition:
		_failures += 1
	var line := "%s: %s" % [status, label]
	print(line)
	_lines.append(line)


func _run_tests() -> void:
	# 1. Resource loads with expected metadata
	var data: DebuffData = load("res://Scripts/Debuff/WindowShoppingDebuff.tres")
	_check(data != null, "WindowShoppingDebuff.tres loads as DebuffData")
	if not data:
		return
	_check(data.id == "window_shopping", "id is 'window_shopping'")
	_check(data.difficulty_rating == 1, "difficulty_rating is 1")
	_check(data.scene != null, "scene is assigned")

	# 2. Scene instantiates as the right class
	var debuff = data.scene.instantiate()
	add_child(debuff)
	_check(debuff is WindowShoppingDebuff, "scene instantiates as WindowShoppingDebuff")
	_check(debuff is Debuff, "scene root extends Debuff")

	# 3. Markup constant matches design (+25%)
	_check(GameController.WINDOW_SHOPPING_MARKUP == 0.25, "WINDOW_SHOPPING_MARKUP is 0.25")

	# 4. apply/remove maintain the stack count on the game controller
	var stub := StubGameController.new()
	stub.name = "StubGameController"
	stub.add_to_group("game_controller")
	add_child(stub)

	debuff.id = data.id
	debuff.apply(stub)
	_check(stub.window_shopping_stacks == 1, "apply() increments window_shopping_stacks to 1")
	debuff.remove()
	_check(stub.window_shopping_stacks == 0, "remove() decrements window_shopping_stacks to 0")

	stub.remove_from_group("game_controller")
	stub.queue_free()
	debuff.queue_free()


func _finish() -> void:
	var summary := ""
	if _failures == 0:
		summary = "ALL TESTS PASSED"
	else:
		summary = "%d TEST(S) FAILED" % _failures
	print("[WindowShoppingTest] " + summary)
	_lines.append("")
	_lines.append(summary)
	if results_label:
		results_label.text = "\n".join(_lines)
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(_failures)
