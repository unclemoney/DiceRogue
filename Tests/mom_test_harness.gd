extends RefCounted

## mom_test_harness.gd
##
## Shared harness for the Mom test suite: a stub GameController exposing the
## duck-typed surface MomLogicHandler touches, autoload snapshot/restore
## helpers (real autoloads, never stubbed), resource builders, a dialog-dir
## scanner, a cmdline seed parser, and a check reporter.
##
## Preloaded by path from each layer - no class_name, no scene.

const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

const DIALOG_DIR := "res://Resources/Data/Mom/Dialog/"
const CAST_DIR := "res://Resources/Data/Mom/Cast/"


## StubChoresManager
##
## Mirrors the Mom-relevant surface of Scripts/Managers/ChoresManager.gd.
## consume_grudge() returns the CURRENT grudge and then decrements, matching
## ChoresManager.gd:658-662 - the severity floor depends on the pre-decrement
## value.
class StubChoresManager extends Node:
	signal grudge_changed(new_grudge: int)

	var mom_mood: int = 5
	var grudge: int = 0
	var defer_streak: int = 0
	var low_mood_visits_this_run: int = 0
	var is_mom_active: bool = false
	var chores_completed_this_round: int = 0

	var mood_calls: Array[int] = []
	var grudge_calls: Array[int] = []
	var defer_registered: int = 0
	var defer_resets: int = 0
	var low_mood_visits_registered: int = 0

	func _ready() -> void:
		# CastManager looks its sibling up by group, not by name.
		add_to_group("chores_manager")

	func consume_grudge() -> int:
		var current := grudge
		if grudge > 0:
			grudge -= 1
			grudge_changed.emit(grudge)
		return current

	func register_low_mood_visit() -> void:
		low_mood_visits_this_run += 1
		low_mood_visits_registered += 1

	func adjust_mood(delta: int) -> void:
		mom_mood = clampi(mom_mood + delta, 1, 10)
		mood_calls.append(delta)

	func add_grudge(amount: int = 1) -> void:
		var old_grudge := grudge
		grudge = clampi(grudge + amount, 0, 3)
		grudge_calls.append(amount)
		if grudge != old_grudge:
			grudge_changed.emit(grudge)

	func get_chores_completed_this_round() -> int:
		return chores_completed_this_round

	func register_defer() -> void:
		defer_streak = clampi(defer_streak + 1, 0, 3)
		defer_registered += 1

	func reset_defer_streak() -> void:
		defer_streak = 0
		defer_resets += 1


## StubPowerUpManager
##
## get_def() returns real PowerUpData resources so the handler's typed
## _get_power_up_def() and the rating duck-typing work exactly as in
## production.
class StubPowerUpManager extends Node:
	var defs: Dictionary = {}

	func get_def(power_up_id: String) -> PowerUpData:
		return defs.get(power_up_id)


## StubChannelManager
##
## Only what CastManager._current_channel reads.
class StubChannelManager extends RefCounted:
	var current_channel: int = 1


## StubGameController
##
## Stand-in for GameController. Method bodies record calls and mutate the
## dictionaries the way the real controller does.
class StubGameController extends Node:
	var pu_manager: StubPowerUpManager
	var active_power_ups: Dictionary = {}
	var active_mods: Dictionary = {}
	var chores_manager: StubChoresManager
	var channel_manager := StubChannelManager.new()

	var revoked_power_ups: Array[String] = []
	var removed_mods: Array[String] = []
	var enabled_debuffs: Array[String] = []
	var granted_consumables: Array[String] = []
	var granted_power_ups: Array[String] = []

	func _init() -> void:
		pu_manager = StubPowerUpManager.new()
		pu_manager.name = "StubPowerUpManager"
		add_child(pu_manager)
		chores_manager = StubChoresManager.new()
		chores_manager.name = "StubChoresManager"
		add_child(chores_manager)

	func add_power_up(power_up_id: String, rating: String) -> void:
		var def := PowerUpData.new()
		def.id = power_up_id
		def.rating = rating
		pu_manager.defs[power_up_id] = def
		active_power_ups[power_up_id] = def

	func clear_power_ups() -> void:
		pu_manager.defs.clear()
		active_power_ups.clear()

	func revoke_power_up(power_up_id: String) -> void:
		revoked_power_ups.append(power_up_id)
		active_power_ups.erase(power_up_id)

	func remove_mod_no_refund(mod_id: String) -> void:
		removed_mods.append(mod_id)
		active_mods.erase(mod_id)

	func enable_debuff(debuff_id: String) -> void:
		enabled_debuffs.append(debuff_id)

	func grant_consumable(consumable_id: String) -> void:
		granted_consumables.append(consumable_id)

	func grant_power_up(power_up_id: String) -> void:
		granted_power_ups.append(power_up_id)
		active_power_ups[power_up_id] = true


## Reporter
##
## Per-layer assertion reporter in the [MomTests] OK:/FAILED: style.
class Reporter extends RefCounted:
	var failures: int = 0
	var checks: int = 0
	var tag: String = "[MomTests]"

	func check(label: String, condition: bool) -> void:
		checks += 1
		if condition:
			print("%s OK: %s" % [tag, label])
		else:
			push_error("%s FAILED: %s" % [tag, label])
			failures += 1

	func info(line: String) -> void:
		print("%s INFO: %s" % [tag, line])


## make_outcome(effect, magnitude, weight, extra) -> MomDialogOutcome
##
## Builds a dialog outcome without depending on shipping .tres data.
## Recognized extra keys: mood_delta, grudge_delta, permanent,
## followup_node_id, result_text, result_expression, ends_visit.
static func make_outcome(effect: String, magnitude: int = 0, weight: float = 1.0, extra: Dictionary = {}) -> MomDialogOutcome:
	var outcome := MomDialogOutcome.new()
	outcome.effect = effect
	outcome.magnitude = magnitude
	outcome.weight = weight
	outcome.mood_delta = int(extra.get("mood_delta", 0))
	outcome.grudge_delta = int(extra.get("grudge_delta", 0))
	outcome.permanent = bool(extra.get("permanent", false))
	outcome.followup_node_id = String(extra.get("followup_node_id", ""))
	outcome.result_text = String(extra.get("result_text", "result"))
	outcome.result_expression = String(extra.get("result_expression", ""))
	outcome.ends_visit = bool(extra.get("ends_visit", true))
	return outcome


## make_response(tone, outcomes) -> MomDialogResponse
static func make_response(tone: String, outcomes: Array) -> MomDialogResponse:
	var response := MomDialogResponse.new()
	response.button_text = "test response (%s)" % tone
	response.tone = tone
	for outcome in outcomes:
		response.outcomes.append(outcome)
	return response


## make_entry(effect, params, permanent) -> Dictionary
##
## Builds a tier-entry Dictionary in the MomPunishmentTier schema.
static func make_entry(effect: String, params: Dictionary, permanent: bool = false) -> Dictionary:
	return {
		"effect": effect,
		"weight": 1.0,
		"params": params,
		"permanent": permanent,
	}


## snapshot_autoloads() -> Dictionary
##
## Captures the mutable state of the REAL autoloads the Mom handler touches.
static func snapshot_autoloads() -> Dictionary:
	return {
		"money": PlayerEconomy.money,
		"colors_enabled": DiceColorManager.colors_enabled,
		"purchased_colors": DiceColorManager.purchased_colors.duplicate(),
		"rep": ProgressManager.get_rep(),
		"rep_had_key": ProgressManager.cumulative_stats.has("rep"),
	}


## restore_autoloads(snapshot)
static func restore_autoloads(snapshot: Dictionary) -> void:
	PlayerEconomy.money = int(snapshot["money"])
	DiceColorManager.colors_enabled = bool(snapshot["colors_enabled"])
	DiceColorManager.purchased_colors = (snapshot["purchased_colors"] as Dictionary).duplicate()
	if bool(snapshot["rep_had_key"]):
		ProgressManager.cumulative_stats["rep"] = int(snapshot["rep"])
	else:
		ProgressManager.cumulative_stats.erase("rep")


## get_cmdline_seed(default_seed) -> int
##
## Parses `--seed N` or `--seed=N` from the user args (after `--`).
static func get_cmdline_seed(default_seed: int) -> int:
	var args := OS.get_cmdline_user_args()
	for i in range(args.size()):
		var arg: String = args[i]
		if arg == "--seed" and i + 1 < args.size():
			return int(args[i + 1])
		if arg.begins_with("--seed="):
			return int(arg.trim_prefix("--seed="))
	return default_seed


## scan_dialog_nodes() -> Dictionary
##
## Loads every MomDialogNode .tres in the dialog dir, keyed by node id.
## Mirrors MomLogicHandler._scan_dialog_dir so tests and loader never drift.
## The "_files" entry maps node id -> file name for error messages.
static func scan_dialog_nodes() -> Dictionary:
	var nodes: Dictionary = {}
	var files: Dictionary = {}
	var dir := DirAccess.open(DIALOG_DIR)
	if dir == null:
		return {"nodes": nodes, "files": files}
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load(DIALOG_DIR + file_name)
		if res is MomDialogNode:
			nodes[res.id] = res
			files[res.id] = file_name
	return {"nodes": nodes, "files": files}


## collect_cast_dialog_ids() -> Dictionary
##
## Returns {"ids": Array[String], "introspection_ok": bool} - every
## dialog_node_id referenced by cast arc beats. Introspects the arc resource's
## `beats` property; falls back to a text scan of the .tres when the schema
## is not what we expect (cast arc class schema is not otherwise verified).
static func collect_cast_dialog_ids() -> Dictionary:
	var ids: Array[String] = []
	var introspection_ok := true
	var dir := DirAccess.open(CAST_DIR)
	if dir == null:
		return {"ids": ids, "introspection_ok": introspection_ok}
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var path: String = CAST_DIR + file_name
		var res := load(path)
		var beats = res.get("beats") if res != null else null
		if beats is Array and not (beats as Array).is_empty():
			for beat in beats:
				var node_id = beat.get("dialog_node_id") if beat != null else ""
				if node_id is String and not (node_id as String).is_empty():
					ids.append(node_id)
		else:
			# Fallback: text scan for dialog_node_id = "..." lines
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				introspection_ok = false
				continue
			while not file.eof_reached():
				var line := file.get_line()
				var marker := "dialog_node_id = \""
				var at := line.find(marker)
				if at < 0:
					continue
				var rest := line.substr(at + marker.length())
				var end_quote := rest.find("\"")
				if end_quote > 0:
					ids.append(rest.substr(0, end_quote))
	return {"ids": ids, "introspection_ok": introspection_ok}
