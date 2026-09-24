extends Node

## mom_suite_runner.gd
##
## Runs the whole Mom test suite headless, in dependency order, in one
## process. Each layer scene is instantiated, its run_tests() coroutine is
## awaited, and its failure count is aggregated. Exits 0 only if every layer
## passes.
##
## One command for the whole suite (PowerShell):
##   & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --headless --path . Tests/MomSuiteRunner.tscn -- --quit-after
## With a seed override (forwarded to every layer via the shared cmdline):
##   & "C:\Users\danie\OneDrive\Documents\GODOT\Godot_v4.4.1-stable_win64.exe" --headless --path . Tests/MomSuiteRunner.tscn -- --quit-after --seed 999

const LAYERS: Array = [
	["data validation", "res://Tests/MomDataValidationTest.tscn"],
	["distribution", "res://Tests/MomDistributionTest.tscn"],
	["consequences", "res://Tests/MomConsequencesTest.tscn"],
	["coverage sim", "res://Tests/MomCoverageSimTest.tscn"],
	["dialog popup", "res://Tests/MomDialogScrollTest.tscn"],
]


func _ready() -> void:
	print("[MomSuite] Starting Mom test suite (%d layers)" % LAYERS.size())
	var total_failures := 0
	var summary: Array[String] = []
	for entry in LAYERS:
		var layer_name: String = entry[0]
		var scene_path: String = entry[1]
		var scene: PackedScene = load(scene_path)
		if scene == null:
			push_error("[MomSuite] FAILED to load layer scene: " + scene_path)
			summary.append("%s: FAIL (scene missing)" % layer_name)
			total_failures += 1
			continue
		var layer = scene.instantiate()
		add_child(layer)
		var failures: int = await layer.run_tests()
		summary.append("%s: %s (%d failure(s))" % [layer_name, "PASS" if failures == 0 else "FAIL", failures])
		total_failures += failures
		remove_child(layer)
		layer.queue_free()
		await get_tree().process_frame

	print("[MomSuite] ---- summary ----")
	for line in summary:
		print("[MomSuite] " + line)
	if total_failures == 0:
		print("[MomSuite] PASS - all layers passed")
	else:
		print("[MomSuite] FAIL - %d total failure(s)" % total_failures)

	if OS.get_cmdline_user_args().has("--quit-after"):
		get_tree().quit(total_failures)
