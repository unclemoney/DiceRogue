extends Node
class_name CastManager

## CastManager
##
## Owns Mom's World: the recurring cast (CastCharacter resources), the
## 3-beat story arcs (MomStoryArc resources), and the Patterson sighting
## system. Decides when cast content interrupts a normal Mom check-in
## and tracks story state for the whole playthrough.
##
## Lifetime: cast state spans zone (channel) transitions within a
## playthrough - Patterson remembers where you've been all run. It resets
## only on a genuinely new game (channel selection), unlike ChoresManager
## which resets every zone.
##
## Data: Resources/Data/Mom/Cast/ (characters + arcs) and
## Resources/Data/Mom/Dialog/ (story beat trees, loaded by
## MomLogicHandler's directory scan).

## Chance a check-in becomes a Patterson sighting (when no arc beat is due).
const PATTERSON_SIGHTING_CHANCE: float = 0.30
## Sighting chance after the Patterson File arc ends in a truce.
const PATTERSON_TRUCE_CHANCE: float = 0.15
## Base chance a sighting is a false accusation (mood-weighted, see
## _false_report_chance).
const FALSE_REPORT_BASE: float = 0.40
## At or below this mood a false accusation is "believed" - contesting
## is much harder (sighting_false_believed tree).
const FALSE_BELIEVED_MOOD_CAP: int = 4
## Zones a queued Patterson report waits before surfacing.
const PATTERSON_REPORT_DELAY_ZONES: int = 2
## Chance a high-severity, high-grudge meter visit becomes a Dad call.
const DAD_CALL_CHANCE: float = 0.20

## Emitted when a zone is first recorded this playthrough.
signal zone_logged(zone_name: String)
## Emitted when a story beat takes a check-in slot.
signal story_beat_started(arc_id: String, beat_index: int)
## Emitted when an arc's final beat completes.
signal story_arc_completed(arc_id: String)
## Emitted when a Patterson sighting dialog opens.
signal patterson_sighting(is_true: bool)
## Emitted when a contest against a Patterson report resolves.
signal patterson_contest_resolved(won: bool)

# ─── Playthrough-scoped state (get_state/load_state round-trip) ───

## mall_zone_name values visited this playthrough, in order.
var visited_zones: Array[String] = []
## zone_name -> channel number where first visited.
var visited_zone_channels: Dictionary = {}
## arc_id -> index of the next beat to deliver (absent = not started).
var arc_progress: Dictionary = {}
## Arcs whose final beat has completed.
var completed_arcs: Array[String] = []
## Story flags (set by beats and "flag_*" terminal nodes).
var flags: Dictionary = {}
## Queued Patterson reports: {zone, is_true, recorded_channel, min_delay_zones}.
var patterson_pending: Array[Dictionary] = []
var patterson_sightings_this_run: int = 0
var last_sighting_channel: int = 0
var sightings_in_current_zone: int = 0
var dad_call_used: bool = false
var dad_cover_used: bool = false
var dad_cover_pending: bool = false
var max_grudge_seen: int = 0

## F12 debug: when non-empty, decide_checkin returns this claim verbatim
## and clears it (forced sightings, forced story beats).
var debug_forced_claim: Dictionary = {}

# ─── Loaded data ───

var _characters: Dictionary = {}  # id -> CastCharacter
var _arcs: Dictionary = {}        # id -> MomStoryArc
var _all_zone_names: Array[String] = []
var _chores_manager: Node = null


func _ready() -> void:
	add_to_group("cast_manager")
	_load_cast_data()
	_load_zone_names()
	# Defer so ChoresManager (sibling) has finished its own _ready
	call_deferred("_connect_chores_manager")


func _connect_chores_manager() -> void:
	_chores_manager = get_tree().get_first_node_in_group("chores_manager")
	if _chores_manager and _chores_manager.has_signal("grudge_changed"):
		_chores_manager.grudge_changed.connect(_on_grudge_changed)


# ─── Data loading ───

func _load_cast_data() -> void:
	_characters.clear()
	_arcs.clear()
	var dir := DirAccess.open("res://Resources/Data/Mom/Cast/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("res://Resources/Data/Mom/Cast/" + file_name)
		if res is CastCharacter:
			_characters[res.id] = res
		elif res is MomStoryArc:
			_arcs[res.id] = res
	print("[CastManager] Loaded %d characters, %d story arcs" % [_characters.size(), _arcs.size()])


func _load_zone_names() -> void:
	_all_zone_names.clear()
	var dir := DirAccess.open("res://Resources/Data/Channels/")
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with(".tres"):
			continue
		var res := load("res://Resources/Data/Channels/" + file_name)
		if res is ChannelDifficultyData and res.mall_zone_name != "":
			_all_zone_names.append(res.mall_zone_name)


## get_character(id) -> CastCharacter
func get_character(id: String) -> CastCharacter:
	return _characters.get(id)


## get_arc(id) -> MomStoryArc
func get_arc(id: String) -> MomStoryArc:
	return _arcs.get(id)


# ─── Zone tracking ───

## record_zone_visit(config, game_controller)
##
## Records that the player entered a mall zone. Called on channel
## selection (first zone) and on every zone transition. Also queues
## delayed Patterson reports: getting caught with restricted loot or a
## hot grudge in a zone means she tells Mom about it zones later.
func record_zone_visit(config: ChannelDifficultyData, game_controller: Node = null) -> void:
	if config == null:
		return
	var zone: String = config.mall_zone_name
	if zone == "":
		return
	var is_new := zone not in visited_zones
	if is_new:
		visited_zones.append(zone)
		visited_zone_channels[zone] = config.channel_number
		zone_logged.emit(zone)
		print("[CastManager] Zone logged: %s (channel %d)" % [zone, config.channel_number])
	sightings_in_current_zone = 0

	if not is_new or game_controller == null:
		return
	# Delayed consequences: restricted loot or an active grudge in this
	# zone becomes a TRUE Patterson report a few zones down the mall.
	var ratings := MomLogicHandler.scan_inventory_ratings(game_controller)
	var grudge := 0
	if _chores_manager:
		grudge = int(_chores_manager.get("grudge"))
	if ratings["nc17"] + ratings["r"] > 0 or grudge >= 2:
		patterson_pending.append({
			"zone": zone,
			"is_true": true,
			"recorded_channel": config.channel_number,
			"min_delay_zones": PATTERSON_REPORT_DELAY_ZONES,
		})
		print("[CastManager] Patterson will report the %s visit later..." % zone)


## get_unvisited_zones() -> Array[String]
##
## Zones the player has NOT been to this playthrough (false-accusation pool).
func get_unvisited_zones() -> Array[String]:
	var result: Array[String] = []
	for zone in _all_zone_names:
		if zone not in visited_zones:
			result.append(zone)
	return result


## has_visited_zone(zone) -> bool
func has_visited_zone(zone: String) -> bool:
	return zone in visited_zones


# ─── Check-in gate ───

## decide_checkin(game_controller) -> Dictionary
##
## The cast's claim on the once-per-round check-in slot. Returns
## {"tree_id": String, "context": Dictionary} - an empty tree_id means
## no cast content fires and the caller falls back to the normal trees.
##
## Precedence: Derek's quiet visit > Dad cover > due story beat >
## due pending Patterson report > fresh sighting roll > normal check-in.
func decide_checkin(game_controller: Node) -> Dictionary:
	var current_channel := _current_channel(game_controller)

	# 0. F12 debug forced claim wins over everything
	if not debug_forced_claim.is_empty():
		var forced := debug_forced_claim
		debug_forced_claim = {}
		return forced

	# 1. Derek's quiet visit: the catharsis beat always wins the slot.
	if flags.get("derek_quiet_pending", false):
		flags.erase("derek_quiet_pending")
		return {"tree_id": "story_derek_quiet", "context": {}}

	# 2. Dad quietly covers for you (grudge recovered from >= 2 to 0).
	if dad_cover_pending:
		dad_cover_pending = false
		dad_cover_used = true
		return {"tree_id": "story_dad_cover", "context": {}}

	# 3. Due story beat (highest priority arc wins).
	var beat_claim := _find_due_beat(game_controller, current_channel)
	if not beat_claim.is_empty():
		story_beat_started.emit(beat_claim["arc_id"], beat_claim["beat_index"])
		return {"tree_id": beat_claim["tree_id"], "context": {}}

	# 4. Delayed Patterson report whose wait has elapsed.
	var pending_claim := _pop_due_pending_report(current_channel)
	if not pending_claim.is_empty():
		_register_sighting(pending_claim["is_true"], current_channel)
		return _build_sighting_claim(pending_claim["zone"], pending_claim["is_true"])

	# 5. Fresh sighting roll (zone cooldown + one per zone max).
	if _can_roll_sighting(current_channel):
		var chance := PATTERSON_TRUCE_CHANCE if flags.get("patterson_truce", false) else PATTERSON_SIGHTING_CHANCE
		if GameRNG.randf() < chance:
			var sighting := _roll_sighting(current_channel)
			if not sighting.is_empty():
				_register_sighting(sighting["is_true"], current_channel)
				return _build_sighting_claim(sighting["zone"], sighting["is_true"])

	return {"tree_id": "", "context": {}}


## _find_due_beat(game_controller, current_channel) -> Dictionary
##
## Returns {"tree_id", "arc_id", "beat_index"} for the highest-priority
## arc whose next beat's conditions all pass, or {} when none are due.
func _find_due_beat(game_controller: Node, current_channel: int) -> Dictionary:
	var best: Dictionary = {}
	var best_priority := -999999
	for arc_id in _arcs.keys():
		if arc_id in completed_arcs:
			continue
		var arc: MomStoryArc = _arcs[arc_id]
		var next_index: int = arc_progress.get(arc_id, 0)
		if next_index >= arc.beats.size():
			continue
		var beat: MomStoryBeat = arc.beats[next_index]
		if not _beat_conditions_pass(beat, game_controller, current_channel):
			continue
		if arc.priority > best_priority:
			best_priority = arc.priority
			best = {"tree_id": beat.dialog_node_id, "arc_id": arc_id, "beat_index": next_index}
	return best


## _beat_conditions_pass(beat, game_controller, current_channel) -> bool
func _beat_conditions_pass(beat: MomStoryBeat, game_controller: Node, current_channel: int) -> bool:
	if current_channel < beat.min_channel:
		return false
	var grudge := 0
	if _chores_manager:
		grudge = int(_chores_manager.get("grudge"))
	if grudge < beat.min_grudge or grudge > beat.max_grudge:
		return false
	var rep := 0
	var progress_manager := _get_autoload("ProgressManager")
	if progress_manager and progress_manager.has_method("get_rep"):
		rep = progress_manager.get_rep()
	if rep < beat.min_rep:
		return false
	if beat.requires_flag != "" and not flags.get(beat.requires_flag, false):
		return false
	if beat.requires_chores_done:
		var done := 0
		if _chores_manager and _chores_manager.has_method("get_chores_completed_this_round"):
			done = _chores_manager.get_chores_completed_this_round()
		if done <= 0:
			return false
	return true


# ─── Patterson sightings ───

## _can_roll_sighting(current_channel) -> bool
##
## One sighting per zone, never two zones in a row, and only once the
## player has been somewhere Patterson can talk about.
func _can_roll_sighting(current_channel: int) -> bool:
	if sightings_in_current_zone >= 1:
		return false
	if last_sighting_channel == current_channel - 1:
		return false
	# True reports need a previous zone; false reports need an unvisited one
	var can_true := visited_zones.size() >= 2
	var can_false := not get_unvisited_zones().is_empty()
	return can_true or can_false


## _roll_sighting(current_channel) -> Dictionary
##
## Generates {"zone", "is_true"}. True reports reference a real zone the
## player visited (never the current one); false accusations name a zone
## they have never been to. False chance is mood-weighted: low mood means
## Mom comes in already believing Patterson.
func _roll_sighting(current_channel: int) -> Dictionary:
	var mood := 5
	if _chores_manager:
		mood = int(_chores_manager.get("mom_mood"))
	var false_chance := _false_report_chance(mood)
	if flags.get("patterson_truce", false):
		false_chance = 0.0

	var true_pool: Array[String] = []
	for zone in visited_zones:
		if visited_zone_channels.get(zone, current_channel) != current_channel:
			true_pool.append(zone)
	var false_pool := get_unvisited_zones()

	var want_false := GameRNG.randf() < false_chance
	if want_false and not false_pool.is_empty():
		return {"zone": false_pool[GameRNG.random_index(false_pool)], "is_true": false}
	if not true_pool.is_empty():
		return {"zone": true_pool[GameRNG.random_index(true_pool)], "is_true": true}
	if not false_pool.is_empty():
		return {"zone": false_pool[GameRNG.random_index(false_pool)], "is_true": false}
	return {}


## _false_report_chance(mood) -> float
##
## Mood-weighted false-accusation rate: happy Mom doubts Patterson,
## angry Mom believes every word.
func _false_report_chance(mood: int) -> float:
	if mood >= 8:
		return 0.25
	if mood <= FALSE_BELIEVED_MOOD_CAP:
		return 0.60
	return FALSE_REPORT_BASE


## _pop_due_pending_report(current_channel) -> Dictionary
func _pop_due_pending_report(current_channel: int) -> Dictionary:
	for i in range(patterson_pending.size()):
		var report: Dictionary = patterson_pending[i]
		var due_channel: int = int(report.get("recorded_channel", 0)) + int(report.get("min_delay_zones", PATTERSON_REPORT_DELAY_ZONES))
		if current_channel >= due_channel:
			patterson_pending.remove_at(i)
			return report
	return {}


## _build_sighting_claim(zone, is_true) -> Dictionary
##
## Picks the sighting tree variant. False accusations at low mood use the
## "believed" tree where contesting usually fails - injustice as gameplay.
func _build_sighting_claim(zone: String, is_true: bool) -> Dictionary:
	var tree_id := "sighting_true"
	if not is_true:
		var mood := 5
		if _chores_manager:
			mood = int(_chores_manager.get("mom_mood"))
		if mood <= FALSE_BELIEVED_MOOD_CAP:
			tree_id = "sighting_false_believed"
		else:
			tree_id = "sighting_false"
	return {"tree_id": tree_id, "context": {"zone": zone}}


func _register_sighting(is_true: bool, current_channel: int) -> void:
	patterson_sightings_this_run += 1
	sightings_in_current_zone += 1
	last_sighting_channel = current_channel
	patterson_sighting.emit(is_true)


# ─── Dad mechanics ───

## should_dad_call(severity, pre_visit_grudge) -> bool
##
## Rare escalation for high-severity meter visits: Mom phones Dad
## off-screen and the punishment comes back one tier worse. Once per
## playthrough. Grudge must be read BEFORE compute_severity consumes it.
func should_dad_call(severity: int, pre_visit_grudge: int) -> bool:
	if dad_call_used:
		return false
	if severity < 4 or pre_visit_grudge < 2:
		return false
	if GameRNG.randf() >= DAD_CALL_CHANCE:
		return false
	dad_call_used = true
	print("[CastManager] Dad call! Severity %d, grudge %d" % [severity, pre_visit_grudge])
	return true


## _on_grudge_changed(new_grudge)
##
## Watches for the redemption arc: grudge climbed to 2+ and later came
## back to 0. The next check-in becomes the Dad cover beat (once per
## playthrough).
func _on_grudge_changed(new_grudge: int) -> void:
	max_grudge_seen = maxi(max_grudge_seen, new_grudge)
	if new_grudge == 0 and max_grudge_seen >= 2 and not dad_cover_used and not dad_cover_pending:
		dad_cover_pending = true
		print("[CastManager] Dad cover armed for next check-in")


# ─── Session completion ───

## on_session_finished(root_node_id, visited_node_ids)
##
## Called by GameController after every Mom dialog session. Sets story
## flags from visited "flag_*" nodes, advances any arc whose due beat
## just played, and pays beat rewards.
func on_session_finished(root_node_id: String, visited_node_ids: Array = []) -> void:
	for node_id in visited_node_ids:
		if node_id is String and node_id.begins_with("flag_"):
			flags[node_id] = true
			print("[CastManager] Story flag set: %s" % node_id)
			if node_id == "flag_patterson_doubted":
				patterson_contest_resolved.emit(true)
		elif node_id == "patterson_contest_failed":
			patterson_contest_resolved.emit(false)

	# Derek's quiet visit forces a cool-mom check-in next round (catharsis)
	if root_node_id == "story_derek_quiet":
		flags["force_cool_mom"] = true

	# Advance the arc whose current beat just played
	for arc_id in _arcs.keys():
		if arc_id in completed_arcs:
			continue
		var arc: MomStoryArc = _arcs[arc_id]
		var next_index: int = arc_progress.get(arc_id, 0)
		if next_index >= arc.beats.size():
			continue
		var beat: MomStoryBeat = arc.beats[next_index]
		if beat.dialog_node_id != root_node_id:
			continue
		arc_progress[arc_id] = next_index + 1
		if beat.sets_flag != "":
			flags[beat.sets_flag] = true
		_pay_beat_rewards(beat)
		if next_index + 1 >= arc.beats.size():
			completed_arcs.append(arc_id)
			story_arc_completed.emit(arc_id)
			print("[CastManager] Story arc completed: %s" % arc_id)
		return


## _pay_beat_rewards(beat)
func _pay_beat_rewards(beat: MomStoryBeat) -> void:
	if beat.reward_money != 0:
		var economy := _get_autoload("PlayerEconomy")
		if economy and economy.has_method("add_money"):
			economy.add_money(beat.reward_money)
	if beat.reward_mood != 0 and _chores_manager and _chores_manager.has_method("adjust_mood"):
		_chores_manager.adjust_mood(beat.reward_mood)
	if beat.reward_rep != 0:
		var progress_manager := _get_autoload("ProgressManager")
		if progress_manager and progress_manager.has_method("adjust_rep"):
			progress_manager.adjust_rep(beat.reward_rep)


## consume_flag(flag) -> bool
##
## Reads and clears a story flag. Used by GameController for one-shot
## claims like "force_cool_mom".
func consume_flag(flag: String) -> bool:
	if flags.get(flag, false):
		flags.erase(flag)
		return true
	return false


# ─── Persistence ───

## reset_for_new_game()
##
## Clears all cast state. Called when a genuinely new playthrough starts
## (channel selection) - NOT on zone transitions within a playthrough.
func reset_for_new_game() -> void:
	visited_zones.clear()
	visited_zone_channels.clear()
	arc_progress.clear()
	completed_arcs.clear()
	flags.clear()
	patterson_pending.clear()
	patterson_sightings_this_run = 0
	last_sighting_channel = 0
	sightings_in_current_zone = 0
	dad_call_used = false
	dad_cover_used = false
	dad_cover_pending = false
	max_grudge_seen = 0
	print("[CastManager] Reset for new game")


## get_state() -> Dictionary
func get_state() -> Dictionary:
	return {
		"visited_zones": visited_zones.duplicate(),
		"visited_zone_channels": visited_zone_channels.duplicate(),
		"arc_progress": arc_progress.duplicate(),
		"completed_arcs": completed_arcs.duplicate(),
		"flags": flags.duplicate(),
		"patterson_pending": patterson_pending.duplicate(true),
		"patterson_sightings_this_run": patterson_sightings_this_run,
		"last_sighting_channel": last_sighting_channel,
		"sightings_in_current_zone": sightings_in_current_zone,
		"dad_call_used": dad_call_used,
		"dad_cover_used": dad_cover_used,
		"dad_cover_pending": dad_cover_pending,
		"max_grudge_seen": max_grudge_seen,
	}


## load_state(state)
##
## Tolerant restore: every key defaults so older saves load cleanly.
func load_state(state: Dictionary) -> void:
	visited_zones.assign(state.get("visited_zones", []))
	visited_zone_channels = state.get("visited_zone_channels", {}).duplicate()
	arc_progress = state.get("arc_progress", {}).duplicate()
	completed_arcs.assign(state.get("completed_arcs", []))
	flags = state.get("flags", {}).duplicate()
	patterson_pending.clear()
	for report in state.get("patterson_pending", []):
		patterson_pending.append(report.duplicate())
	patterson_sightings_this_run = int(state.get("patterson_sightings_this_run", 0))
	last_sighting_channel = int(state.get("last_sighting_channel", 0))
	sightings_in_current_zone = int(state.get("sightings_in_current_zone", 0))
	dad_call_used = bool(state.get("dad_call_used", false))
	dad_cover_used = bool(state.get("dad_cover_used", false))
	dad_cover_pending = bool(state.get("dad_cover_pending", false))
	max_grudge_seen = int(state.get("max_grudge_seen", 0))


# ─── Debug ───

## debug_force_sighting(is_true) -> Dictionary
##
## F12 debug: builds a sighting claim immediately (true uses a visited
## zone, false an unvisited one). Returns the same shape as decide_checkin.
func debug_force_sighting(is_true: bool, current_channel: int) -> Dictionary:
	var zone := ""
	if is_true:
		var pool: Array[String] = []
		for z in visited_zones:
			if visited_zone_channels.get(z, current_channel) != current_channel:
				pool.append(z)
		if pool.is_empty() and not visited_zones.is_empty():
			pool.append(visited_zones[0])
		if pool.is_empty():
			return {"tree_id": "", "context": {}}
		zone = pool[GameRNG.random_index(pool)]
	else:
		var pool := get_unvisited_zones()
		if pool.is_empty():
			return {"tree_id": "", "context": {}}
		zone = pool[GameRNG.random_index(pool)]
	_register_sighting(is_true, current_channel)
	return _build_sighting_claim(zone, is_true)


## debug_get_state_summary() -> String
func debug_get_state_summary() -> String:
	var lines: Array[String] = []
	lines.append("Visited zones (%d): %s" % [visited_zones.size(), ", ".join(visited_zones)])
	lines.append("Arc progress: %s" % str(arc_progress))
	lines.append("Completed arcs: %s" % str(completed_arcs))
	lines.append("Flags: %s" % str(flags))
	lines.append("Patterson pending: %s" % str(patterson_pending))
	lines.append("Sightings this run: %d (last channel %d)" % [patterson_sightings_this_run, last_sighting_channel])
	lines.append("Dad call used: %s, cover used: %s, cover pending: %s (max grudge %d)" % [
		dad_call_used, dad_cover_used, dad_cover_pending, max_grudge_seen])
	return "\n".join(lines)


# ─── Helpers ───

func _current_channel(game_controller: Node) -> int:
	if game_controller:
		var channel_manager = game_controller.get("channel_manager")
		if channel_manager:
			return int(channel_manager.get("current_channel"))
	return 1


func _get_autoload(autoload_name: String) -> Node:
	var scene_tree = Engine.get_main_loop()
	if scene_tree and scene_tree.root:
		return scene_tree.root.get_node_or_null(autoload_name)
	return null
