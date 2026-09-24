extends Node

## mom_distribution_test.gd
##
## Layer 3 of the Mom suite: weighted outcome distribution. Draws
## resolve_response() 10,000 times per response of every dialog node and
## checks empirical frequencies against configured weights; checks the bot
## tone policy (polite:neutral:sassy = 6:3:1); covers degenerate weights.
##
## Run headless:
##   godot --headless --path . Tests/MomDistributionTest.tscn -- --quit-after
##   godot --headless --path . Tests/MomDistributionTest.tscn -- --quit-after --seed 999
## Exit code 0 = all checks passed, 1 = at least one failure.

signal finished(failures: int)

const Harness = preload("res://Tests/mom_test_harness.gd")
const Handler := preload("res://Scripts/Core/mom_logic_handler.gd")

const DRAWS := 10000
const TOLERANCE := 0.02
const DEFAULT_SEED := 12345

var _reporter := Harness.Reporter.new()
var _base_seed: int = DEFAULT_SEED


func _ready() -> void:
	if get_tree().current_scene == self:
		var failures := await run_tests()
		if OS.get_cmdline_user_args().has("--quit-after"):
			get_tree().quit(failures)


func run_tests() -> int:
	print("[MomTests] --- Layer: weighted outcome distribution ---")
	_base_seed = Harness.get_cmdline_seed(DEFAULT_SEED)
	print("[MomTests] Seed: %d" % _base_seed)
	_reporter = Harness.Reporter.new()

	var scan := Harness.scan_dialog_nodes()
	var nodes: Dictionary = scan["nodes"]
	_reporter.check("dialog nodes scanned (%d)" % nodes.size(), nodes.size() > 0)

	_check_response_distributions(nodes)
	_check_bot_policy(nodes)
	_check_degenerate_cases()
	_check_determinism()

	if _reporter.failures == 0:
		print("[MomTests] PASS - distribution (%d checks, seed %d)" % [_reporter.checks, _base_seed])
	else:
		print("[MomTests] FAIL - distribution: %d/%d check(s) failed (seed %d)" % [_reporter.failures, _reporter.checks, _base_seed])
	finished.emit(_reporter.failures)
	return _reporter.failures


func _derived_seed(key: String) -> int:
	return _base_seed + (key.hash() & 0x7FFFFFFF) % 100000


func _check_response_distributions(nodes: Dictionary) -> void:
	var responses_checked := 0
	var share_failures := 0
	for node_id in nodes:
		var node: MomDialogNode = nodes[node_id]
		for response_index in range(node.responses.size()):
			var response: MomDialogResponse = node.responses[response_index]
			if response == null or response.outcomes.is_empty():
				continue
			responses_checked += 1
			GameRNG.initialize(_derived_seed("%s#%d" % [node_id, response_index]))
			var counts: Array[int] = []
			counts.resize(response.outcomes.size())
			for draw_index in range(DRAWS):
				var outcome := Handler.resolve_response(response)
				var at := response.outcomes.find(outcome)
				if at >= 0:
					counts[at] += 1
			var total := response.get_total_weight()
			for outcome_index in range(response.outcomes.size()):
				var outcome: MomDialogOutcome = response.outcomes[outcome_index]
				var expected: float = outcome.weight / total if total > 0.0 else 0.0
				var empirical: float = float(counts[outcome_index]) / float(DRAWS)
				if expected >= 0.05:
					if absf(empirical - expected) > TOLERANCE:
						share_failures += 1
						_reporter.check("share %s/'%s' outcome %d: empirical %.4f vs expected %.4f (tol %.2f)" % [node_id, response.button_text, outcome_index, empirical, expected, TOLERANCE], false)
				elif empirical > TOLERANCE:
					share_failures += 1
					_reporter.check("small-share %s/'%s' outcome %d: empirical %.4f (expected %.4f < 0.05, tol %.2f)" % [node_id, response.button_text, outcome_index, empirical, expected, TOLERANCE], false)
	_reporter.check("every response distribution within tolerance (%d responses, %d bad shares, %d draws each)" % [responses_checked, share_failures, DRAWS], share_failures == 0 and responses_checked > 0)


func _check_bot_policy(nodes: Dictionary) -> void:
	var tones := ["polite", "neutral", "sassy"]
	var nodes_checked := 0
	var ratio_failures := 0
	for node_id in nodes:
		var node: MomDialogNode = nodes[node_id]
		if node.responses.is_empty():
			continue
		nodes_checked += 1
		GameRNG.initialize(_derived_seed("bot:%s" % node_id))
		var class_counts := {"polite": 0, "neutral": 0, "sassy": 0}
		for draw_index in range(DRAWS):
			var picked := Handler.pick_response_index(node)
			if picked < 0 or picked >= node.responses.size():
				ratio_failures += 1
				_reporter.check("bot pick in range: %s (got %d)" % [node_id, picked], false)
				break
			var tone: String = node.responses[picked].tone
			class_counts[tone] = int(class_counts.get(tone, 0)) + 1
		var total_weight := 0.0
		for response in node.responses:
			total_weight += float(Handler.BOT_TONE_WEIGHTS.get(response.tone, 1.0))
		for tone in tones:
			var tone_weight := 0.0
			for response in node.responses:
				if response.tone == tone:
					tone_weight += float(Handler.BOT_TONE_WEIGHTS.get(tone, 1.0))
			var expected := tone_weight / total_weight
			var empirical := float(class_counts[tone]) / float(DRAWS)
			if expected == 0.0:
				if int(class_counts[tone]) != 0:
					ratio_failures += 1
					_reporter.check("bot never picks absent tone '%s': %s (got %d)" % [tone, node_id, class_counts[tone]], false)
			elif absf(empirical - expected) > TOLERANCE:
				ratio_failures += 1
				_reporter.check("bot tone share '%s': %s empirical %.4f vs expected %.4f" % [tone, node_id, empirical, expected], false)
	_reporter.check("bot policy tone shares within tolerance across all nodes (%d nodes, %d bad)" % [nodes_checked, ratio_failures], ratio_failures == 0 and nodes_checked > 0)

	# Canonical 6:3:1 case: a synthetic node with exactly one response per tone
	# must split 0.6 / 0.3 / 0.1.
	var canonical := MomDialogNode.new()
	canonical.id = "test_canonical_tones"
	canonical.mom_text = "test"
	for tone in tones:
		canonical.responses.append(Harness.make_response(tone, [Harness.make_outcome("none")]))
	GameRNG.initialize(_derived_seed("bot:canonical"))
	var canonical_counts := {"polite": 0, "neutral": 0, "sassy": 0}
	for draw_index in range(DRAWS):
		var picked := Handler.pick_response_index(canonical)
		var tone: String = canonical.responses[picked].tone
		canonical_counts[tone] = int(canonical_counts[tone]) + 1
	var expected_shares := {"polite": 0.6, "neutral": 0.3, "sassy": 0.1}
	var canonical_ok := true
	for tone in tones:
		var empirical := float(canonical_counts[tone]) / float(DRAWS)
		if absf(empirical - float(expected_shares[tone])) > TOLERANCE:
			canonical_ok = false
	_reporter.check("bot policy canonical polite:neutral:sassy = 0.6:0.3:0.1 (got %.3f:%.3f:%.3f)" % [
		float(canonical_counts["polite"]) / DRAWS,
		float(canonical_counts["neutral"]) / DRAWS,
		float(canonical_counts["sassy"]) / DRAWS], canonical_ok)


func _check_degenerate_cases() -> void:
	# All-zero outcome weights -> index 0, no crash.
	var zero_response := Harness.make_response("neutral", [
		Harness.make_outcome("none", 0, 0.0),
		Harness.make_outcome("fine", 50, 0.0),
	])
	GameRNG.initialize(_derived_seed("degenerate"))
	var drawn := Handler.resolve_response(zero_response)
	_reporter.check("all-zero weights resolve to outcome index 0", drawn == zero_response.outcomes[0])
	_reporter.check("_pick_weighted_index all-zero returns 0", Handler._pick_weighted_index([0.0, 0.0, 0.0]) == 0)

	# Null / empty responses -> null, no crash.
	_reporter.check("resolve_response(null) returns null", Handler.resolve_response(null) == null)
	var empty_response := MomDialogResponse.new()
	_reporter.check("resolve_response(empty outcomes) returns null", Handler.resolve_response(empty_response) == null)

	# Unknown tones fall back to weight 1.0 per response (uniform over 2).
	var weird_node := MomDialogNode.new()
	weird_node.id = "test_weird_tones"
	weird_node.mom_text = "test"
	for tone in ["defiant", "meek"]:
		weird_node.responses.append(Harness.make_response(tone, [Harness.make_outcome("none")]))
	GameRNG.initialize(_derived_seed("weird-tones"))
	var weird_counts := [0, 0]
	for draw_index in range(DRAWS):
		weird_counts[Handler.pick_response_index(weird_node)] += 1
	var weird_empirical := float(weird_counts[0]) / float(DRAWS)
	_reporter.check("unknown tones fall back to uniform (empirical %.3f vs 0.5)" % weird_empirical, absf(weird_empirical - 0.5) <= TOLERANCE)

	# Terminal nodes -> -1.
	var terminal := MomDialogNode.new()
	terminal.id = "test_terminal"
	terminal.mom_text = "test"
	_reporter.check("pick_response_index(terminal) == -1", Handler.pick_response_index(terminal) == -1)
	_reporter.check("pick_response_index(null) == -1", Handler.pick_response_index(null) == -1)


func _check_determinism() -> void:
	var weights := [1.0, 2.0, 3.0]
	GameRNG.initialize(_base_seed)
	var first: Array[int] = []
	for i in range(100):
		first.append(Handler._pick_weighted_index(weights))
	GameRNG.initialize(_base_seed)
	var identical := true
	for i in range(100):
		if Handler._pick_weighted_index(weights) != first[i]:
			identical = false
			break
	_reporter.check("same seed reproduces the same draw sequence", identical)
