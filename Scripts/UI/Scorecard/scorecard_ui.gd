extends PanelContainer
class_name ScoreCardUI

## ScoreCardUI (Phase 2 — states & scoring loop)
##
## Flat row-list scorecard replacing the old pill-button grid. The .tscn
## carries only the container skeleton; category and summary rows are
## instantiated from CATEGORY_DEFS/SUMMARY_DEFS in _ready().
## Push model: bind_scorecard() connects Scorecard model signals and
## update_all() pushes state into the rows. Ghost previews refresh off
## DiceHand.roll_complete/die_locked and model signals. Rows never reach up;
## they emit row_pressed, consumed here and routed to on_category_selected().

signal hand_scored
signal score_rerolled(section: Scorecard.Section, category: String, score: int)
signal score_doubled(section: Scorecard.Section, category: String, new_score: int)
signal about_to_score(section: Scorecard.Section, category: String, dice_values: Array[int])
signal manual_score

const ROW_SCENE := preload("res://Scenes/UI/Scorecard/scorecard_row.tscn")
const POWER_UP_TRIGGER_PARTICLES := preload("res://Scenes/Effects/ConsumableExplosion.tscn")

const CATEGORY_DEFS := [
	{"key": "ones", "section": Scorecard.Section.UPPER, "display_name": "Ones"},
	{"key": "twos", "section": Scorecard.Section.UPPER, "display_name": "Twos"},
	{"key": "threes", "section": Scorecard.Section.UPPER, "display_name": "Threes"},
	{"key": "fours", "section": Scorecard.Section.UPPER, "display_name": "Fours"},
	{"key": "fives", "section": Scorecard.Section.UPPER, "display_name": "Fives"},
	{"key": "sixes", "section": Scorecard.Section.UPPER, "display_name": "Sixes"},
	{"key": "three_of_a_kind", "section": Scorecard.Section.LOWER, "display_name": "3 of a Kind"},
	{"key": "four_of_a_kind", "section": Scorecard.Section.LOWER, "display_name": "4 of a Kind"},
	{"key": "full_house", "section": Scorecard.Section.LOWER, "display_name": "Full House"},
	{"key": "small_straight", "section": Scorecard.Section.LOWER, "display_name": "S Straight"},
	{"key": "large_straight", "section": Scorecard.Section.LOWER, "display_name": "L Straight"},
	{"key": "yahtzee", "section": Scorecard.Section.LOWER, "display_name": "Yahtzee"},
	{"key": "chance", "section": Scorecard.Section.LOWER, "display_name": "Chance"},
]

const SUMMARY_DEFS := [
	{"key": "sub_total", "display_name": "Sub Total", "section": "upper"},
	{"key": "bonus", "display_name": "Bonus", "section": "upper"},
	{"key": "upper_total", "display_name": "Total", "section": "upper"},
	{"key": "yahtzee_bonus", "display_name": "Yahtzee Bonus", "section": "lower"},
	{"key": "lower_total", "display_name": "Lower Total", "section": "lower"},
]

const BONUS_FILL_COLOR := Color(0.51, 0.92, 0.92, 0.18)
const MODE_DOUBLE_TINT := Color(1.2, 1.2, 0.8)
const MODE_ANY_SCORE_TINT := Color(0.8, 1.2, 0.8)
# Fallback switch (plan §4.3): false swaps the blinds shader for a
# modulate.a + position.y slide driven by the same stagger.
const USE_BLINDS_SHADER := true
const POPULATE_ROW_TIME := 0.15
const POPULATE_STAGGER := 0.05
const DEPOPULATE_ROW_TIME := 0.18
const DEPOPULATE_STAGGER := 0.04

var scorecard: Scorecard
var rows := {}  # StringName category key -> ScorecardRow
var summary_rows := {}  # StringName summary key -> ScorecardRow
var turn_scored := false
# Ghost gate: projections compute only after a roll lands; cleared on score
# commit and round end so stale dice never repaint ghosts.
var _has_roll_context := false

# Mode flags
var is_double_mode := false
var go_broke_mode := false
var reroll_active := false
var any_score_active := false

var _juice_remaining: int = 0
var _juice_sound_played: bool = false
var _row_sections := {}  # StringName category key -> Scorecard.Section
var _bonus_progress_fill: ColorRect = null
var _bound_dice_hand: Node = null
var _highlighted_key: StringName = &""  # category key holding the power-up highlight

# Legacy compat members: typed call sites (go_broke_or_go_home_consumable.gd,
# game_controller.gd) access these directly. The button dicts map category
# key -> ScorecardRow (a Button), so .disabled writes keep working.
var upper_section_buttons := {}
var lower_section_buttons := {}
var best_hand_label: Label = null  # Shim for the removed Best Hand panel; stays null.

@onready var upper_rows: VBoxContainer = $MarginContainer/VBoxContainer/UpperRows
@onready var upper_summary: VBoxContainer = $MarginContainer/VBoxContainer/UpperSummary
@onready var lower_rows: VBoxContainer = $MarginContainer/VBoxContainer/LowerRows
@onready var lower_summary: VBoxContainer = $MarginContainer/VBoxContainer/LowerSummary
@onready var upper_header: VBoxContainer = $MarginContainer/VBoxContainer/UpperHeader
@onready var lower_header: VBoxContainer = $MarginContainer/VBoxContainer/LowerHeader


## _ready()
##
## Registers the "scorecard_ui" group, instantiates all category and summary
## rows from the const definitions, builds the Bonus row progress fill, and
## defers DiceHand signal binding (DiceHand may not exist yet).
## Rows start covered and headers faded out: the scorecard shows nothing
## until play_populate() (wired to round start via animate_entrance()).
func _ready() -> void:
	add_to_group("scorecard_ui")
	_instantiate_category_rows()
	_instantiate_summary_rows()
	_setup_bonus_progress_fill()
	for row in _get_all_rows():
		row.hide_instant()
	upper_header.modulate.a = 0.0
	lower_header.modulate.a = 0.0
	call_deferred("_bind_dice_signals")


## _get_all_rows() -> Array
##
## Every row in visual order (category + summary), regardless of visibility.
func _get_all_rows() -> Array:
	var result: Array = []
	for container in [upper_rows, upper_summary, lower_rows, lower_summary]:
		for child in container.get_children():
			if child is ScorecardRow:
				result.append(child)
	return result


## _get_visible_rows() -> Array
##
## Visible rows in visual top-to-bottom order. Hidden rows (YahtzeeBonus
## before its first bonus) are skipped so the blinds stagger stays tight
## (plan risk #9).
func _get_visible_rows() -> Array:
	var result: Array = []
	for container in [upper_rows, upper_summary, lower_rows, lower_summary]:
		for child in container.get_children():
			if child is ScorecardRow and child.visible:
				result.append(child)
	return result


func _instantiate_category_rows() -> void:
	for def in CATEGORY_DEFS:
		var row: ScorecardRow = ROW_SCENE.instantiate()
		# add_child before setup() so the row's @onready labels resolve.
		if def["section"] == Scorecard.Section.UPPER:
			upper_rows.add_child(row)
			upper_section_buttons[def["key"]] = row
		else:
			lower_rows.add_child(row)
			lower_section_buttons[def["key"]] = row
		row.setup(def["key"], def["display_name"])
		row.set_meta("section", def["section"])
		_row_sections[StringName(def["key"])] = def["section"]
		row.row_pressed.connect(_on_row_pressed)
		rows[StringName(def["key"])] = row


func _instantiate_summary_rows() -> void:
	for def in SUMMARY_DEFS:
		var row: ScorecardRow = ROW_SCENE.instantiate()
		if def["section"] == "upper":
			upper_summary.add_child(row)
		else:
			lower_summary.add_child(row)
		row.setup(def["key"], def["display_name"], true)
		summary_rows[StringName(def["key"])] = row
	summary_rows[&"yahtzee_bonus"].visible = false


## _setup_bonus_progress_fill()
##
## Adds the Bonus row's progress fill: a full-height ColorRect under the
## labels whose anchor_right tracks subtotal/threshold in update_all().
func _setup_bonus_progress_fill() -> void:
	var bonus_row: ScorecardRow = summary_rows[&"bonus"]
	_bonus_progress_fill = ColorRect.new()
	_bonus_progress_fill.name = "ProgressFill"
	_bonus_progress_fill.color = BONUS_FILL_COLOR
	_bonus_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bonus_progress_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bonus_progress_fill.anchor_right = 0.0
	_bonus_progress_fill.offset_left = 0.0
	_bonus_progress_fill.offset_top = 0.0
	_bonus_progress_fill.offset_right = 0.0
	_bonus_progress_fill.offset_bottom = 0.0
	bonus_row.add_child(_bonus_progress_fill)
	bonus_row.move_child(_bonus_progress_fill, 0)


## _bind_dice_signals()
##
## Connects DiceHand.roll_complete/die_locked to ghost preview refresh.
## Resolves DiceHand via sibling path, then the "dice_hand" group, then the
## game_controller's dice_hand member. Safe to call repeatedly.
func _bind_dice_signals() -> void:
	var dice_hand := _get_dice_hand()
	if not is_instance_valid(dice_hand):
		return
	_bound_dice_hand = dice_hand
	if dice_hand.has_signal("roll_complete"):
		if not dice_hand.roll_complete.is_connected(_on_roll_complete):
			dice_hand.roll_complete.connect(_on_roll_complete)
	if dice_hand.has_signal("die_locked"):
		if not dice_hand.die_locked.is_connected(_on_die_locked):
			dice_hand.die_locked.connect(_on_die_locked)


func _get_dice_hand() -> Node:
	var dice_hand: Node = get_node_or_null("../DiceHand")
	if is_instance_valid(dice_hand):
		return dice_hand
	dice_hand = get_tree().get_first_node_in_group("dice_hand")
	if is_instance_valid(dice_hand):
		return dice_hand
	var game_controller := get_tree().get_first_node_in_group("game_controller")
	if is_instance_valid(game_controller):
		return game_controller.get("dice_hand")
	return null


func _on_roll_complete() -> void:
	_has_roll_context = true
	_refresh_previews()


func _on_die_locked(_die) -> void:
	_refresh_previews()


## bind_scorecard(sc)
##
## Attaches a Scorecard model: connects its signals to UI handlers, registers
## it with DiceResults, applies dice-set labels, and pushes the initial state.
func bind_scorecard(sc: Scorecard) -> void:
	scorecard = sc
	if not scorecard.score_assigned.is_connected(_on_score_assigned):
		scorecard.score_assigned.connect(_on_score_assigned)
	if not scorecard.score_auto_assigned.is_connected(_on_score_auto_assigned):
		scorecard.score_auto_assigned.connect(_on_score_auto_assigned)
	if not scorecard.score_changed.is_connected(_on_score_changed):
		scorecard.score_changed.connect(_on_score_changed)
	if not scorecard.category_upgraded.is_connected(_on_category_upgraded):
		scorecard.category_upgraded.connect(_on_category_upgraded)
	if not scorecard.category_downgraded.is_connected(_on_category_downgraded):
		scorecard.category_downgraded.connect(_on_category_downgraded)
	if not scorecard.upper_bonus_achieved.is_connected(_on_upper_bonus_achieved):
		scorecard.upper_bonus_achieved.connect(_on_upper_bonus_achieved)
	if not scorecard.yahtzee_bonus_achieved.is_connected(_on_yahtzee_bonus_achieved):
		scorecard.yahtzee_bonus_achieved.connect(_on_yahtzee_bonus_achieved)
	DiceResults.set_scorecard(scorecard)
	update_dice_set_category_labels()
	_bind_dice_signals()
	update_all()


## update_all()
##
## Pushes the full model state (scores, levels, totals, bonus progress) into
## every row, then refreshes ghost previews. Null scores clear the slot;
## 0 is a real score.
func update_all() -> void:
	if not scorecard:
		return
	for key in scorecard.upper_scores.keys():
		_update_category_row(StringName(key), scorecard.upper_scores[key])
	for key in scorecard.lower_scores.keys():
		_update_category_row(StringName(key), scorecard.lower_scores[key])
	_update_summary_rows()
	_refresh_previews()


func _update_category_row(key: StringName, value) -> void:
	var row: ScorecardRow = rows.get(key)
	if row == null:
		return
	row.set_score(value)
	row.set_level(scorecard.get_category_level_by_name(String(key)))
	if value != null:
		if row.state != ScorecardRow.State.SCORED:
			row.set_state_scored()
	elif row.state == ScorecardRow.State.SCORED:
		row.reset_to_available()


func _update_summary_rows() -> void:
	var sub_total: int = scorecard.get_upper_section_total()
	var threshold: int = scorecard.get_scaled_upper_bonus_threshold()
	summary_rows[&"sub_total"].set_score(sub_total)

	var bonus_row: ScorecardRow = summary_rows[&"bonus"]
	bonus_row.set_display_name("Bonus — %d / %d" % [mini(sub_total, threshold), threshold])
	if scorecard.upper_bonus_awarded:
		bonus_row.set_score(scorecard.get_scaled_upper_bonus_amount())
	else:
		bonus_row.set_score(null)
	if _bonus_progress_fill and threshold > 0:
		_bonus_progress_fill.anchor_right = clampf(float(sub_total) / float(threshold), 0.0, 1.0)
	# The achievement fill tween + "+35" flash live in _on_upper_bonus_achieved.

	summary_rows[&"upper_total"].set_score(scorecard.get_upper_section_final_total())

	var yahtzee_row: ScorecardRow = summary_rows[&"yahtzee_bonus"]
	yahtzee_row.visible = scorecard.yahtzee_bonuses > 0
	yahtzee_row.set_score(scorecard.yahtzee_bonus_points)

	summary_rows[&"lower_total"].set_score(scorecard.get_lower_section_total() + scorecard.yahtzee_bonus_points)


## update_dice_set_category_labels()
##
## Re-resolves every row's display name through
## scorecard.get_category_display_name() so the d4 set (Evens/Odds/EO Full
## House) and other dice sets cannot diverge from the model.
func update_dice_set_category_labels() -> void:
	if not scorecard:
		return
	for key in rows.keys():
		var row: ScorecardRow = rows[key]
		row.set_display_name(scorecard.get_category_display_name(String(key)))
	_refresh_previews()


## update_sixth_slot_display()
##
## Deprecated alias for update_dice_set_category_labels().
func update_sixth_slot_display() -> void:
	update_dice_set_category_labels()


## _refresh_previews()
##
## _refresh_previews()
##
## Pushes ghost previews into every open row: base score x category level in
## teal (45% opacity; 68% + a slow scale pulse on the single best row).
## Clears all ghosts once the turn is scored or when no roll has landed
## since the last clear (score commit / round boundary).
## Side-effects: resets the ScoreEvaluatorSingleton anti-runaway counter
## (preview flows are its designated reset point).
func _refresh_previews() -> void:
	if not scorecard:
		return
	ScoreEvaluatorSingleton.reset_evaluation_count()
	if turn_scored or not _has_roll_context:
		for row in rows.values():
			row.clear_ghost()
		return
	var values: Array[int] = DiceResults.values
	var best_row: ScorecardRow = null
	var best_value := 0
	for key in rows.keys():
		var row: ScorecardRow = rows[key]
		if row.state == ScorecardRow.State.SCORED:
			continue
		if scorecard.qualifies_for_preview(String(key), values):
			var base := scorecard.preview_base_score(String(key), values)
			var projected := base * scorecard.get_category_level_by_name(String(key))
			row.set_ghost(projected)
			if projected > best_value:
				best_value = projected
				best_row = row
		else:
			row.clear_ghost()
	# Exactly one row carries the best-hand pulse; transfer is clean
	# (set_best_ghost kills the old row's pulse and restores scale/alpha)
	for key in rows.keys():
		var row: ScorecardRow = rows[key]
		row.set_best_ghost(row == best_row)


## update_best_hand_preview(dice_values)
##
## Called by roll_button_ui after each roll. The Best Hand panel is gone;
## this now drives the per-row ghost previews instead.
func update_best_hand_preview(_dice_values: Array = []) -> void:
	_has_roll_context = true
	_refresh_previews()


## clear_projections()
##
## Wipes every ghost preview and the best-hand pulse, and closes the roll
## gate so no stale dice state can repaint ghosts until the next roll lands.
## Called on score commit (manual or auto) and at round end / round start.
func clear_projections() -> void:
	_has_roll_context = false
	for row in rows.values():
		row.clear_ghost()
		row.set_best_ghost(false)


## on_category_selected(section, category)
##
## Full scoring path with mode gates, ported from the old score_card_ui.gd:
## double mode, dice-validity check, go-broke mode (lower section only),
## existing-score guard, reroll mode, any-score mode, turn guard, then the
## normal path (about_to_score -> model scoring -> UI lock).
func on_category_selected(section: Scorecard.Section, category: String) -> void:
	if not scorecard:
		return

	# Double mode FIRST — no dice interaction needed
	if is_double_mode:
		_handle_double_score(section, category)
		return

	# Check if dice are in a valid state for scoring
	var dice_hand := _get_dice_hand()
	if is_instance_valid(dice_hand) and dice_hand.has_method("can_any_dice_score"):
		if not dice_hand.can_any_dice_score():
			print("[ScoreCardUI] Cannot score - no dice are in ROLLED or LOCKED state")
			show_invalid_score_feedback(category)
			return

	# Go Broke mode — only allow lower section
	if go_broke_mode:
		if section != Scorecard.Section.LOWER:
			print("[ScoreCardUI] Go Broke mode: only lower section allowed")
			show_invalid_score_feedback(category)
			return
		handle_go_broke_score(section, category)
		return

	# Check if this category already has a score
	var existing_score = null
	match section:
		Scorecard.Section.UPPER:
			existing_score = scorecard.upper_scores.get(category)
		Scorecard.Section.LOWER:
			existing_score = scorecard.lower_scores.get(category)

	if existing_score != null and not reroll_active and not any_score_active:
		show_invalid_score_feedback(category)
		return

	if reroll_active:
		handle_score_reroll(section, category)
		return

	if any_score_active:
		handle_any_score(section, category)
		return

	if turn_scored:
		print("[ScoreCardUI] Turn already scored, cannot score again this turn")
		return

	var values: Array[int] = DiceResults.values

	# Emit signal before scoring to allow PowerUps to prepare
	about_to_score.emit(section, category, values)

	# Use scorecard's on_category_selected to properly apply money effects for actual scoring
	scorecard.on_category_selected(section, category)

	# Get the score for display (this is now already set by on_category_selected)
	var score = null
	if section == Scorecard.Section.UPPER:
		score = scorecard.upper_scores[category]
	else:
		score = scorecard.lower_scores[category]

	if score == null:
		print("[ScoreCardUI] Invalid score calculation")
		show_invalid_score_feedback(category)
		return

	# Check for Yahtzee bonus
	scorecard.check_bonus_yahtzee(values, category)

	# turn_scored before update_all so _refresh_previews clears all ghosts.
	turn_scored = true
	update_all()
	disable_all_score_buttons()

	# Note: hand_scored is emitted here; manual_score is emitted from
	# _on_score_assigned (matches the old single-emit contract).
	hand_scored.emit()

	# Note: GameController will be notified via scorecard.score_assigned signal connection


func _on_row_pressed(row_key: String) -> void:
	var key := StringName(row_key)
	var section: Scorecard.Section = _row_sections.get(key, Scorecard.Section.UPPER)
	on_category_selected(section, row_key)


## enable_all_score_buttons()
##
## Re-enables every non-summary, non-scored row for input.
func enable_all_score_buttons() -> void:
	for row in rows.values():
		if row.is_summary:
			continue
		if row.state == ScorecardRow.State.SCORED:
			continue
		row.disabled = false
		row.interactive = true


## disable_all_score_buttons()
##
## Disables every non-summary row (called after a score is locked in).
func disable_all_score_buttons() -> void:
	clear_category_highlight()
	for row in rows.values():
		if row.is_summary:
			continue
		row.disabled = true
		row.interactive = false
		row.modulate = Color.WHITE  # Reset any special mode highlighting


## allow_extra_score()
##
## Re-arms scoring for effects that grant an additional score this turn.
func allow_extra_score() -> void:
	turn_scored = false


## auto_score_best_hand()
##
## Scores the highest-value open category for the current dice, going through
## the full on_category_selected() flow (signals, mode gates, score lock).
## Called by GameButtonUI when Next Turn is pressed without a manual score.
## No-op if the turn is already scored.
func auto_score_best_hand() -> void:
	if turn_scored:
		return
	if not scorecard:
		push_error("[ScoreCardUI] auto_score_best_hand: no scorecard bound")
		return
	var values: Array[int] = DiceResults.values
	if values.is_empty():
		push_error("[ScoreCardUI] auto_score_best_hand: no dice values")
		return

	ScoreEvaluatorSingleton.reset_evaluation_count()
	var best_score := -1
	var best_section := Scorecard.Section.UPPER
	var best_category := ""

	for category in scorecard.upper_scores.keys():
		if scorecard.upper_scores[category] == null and scorecard.is_category_available_for_dice_set(category):
			var score := scorecard.evaluate_category(category, values)
			if score > best_score:
				best_score = score
				best_section = Scorecard.Section.UPPER
				best_category = category

	var lower_order := ["yahtzee", "large_straight", "small_straight", "full_house", "four_of_a_kind", "three_of_a_kind", "chance"]
	for category in lower_order:
		if scorecard.lower_scores[category] == null and scorecard.is_category_available_for_dice_set(category):
			var score := scorecard.evaluate_category(category, values)
			if score > best_score:
				best_score = score
				best_section = Scorecard.Section.LOWER
				best_category = category

	if best_category == "":
		push_error("[ScoreCardUI] auto_score_best_hand: no open category available")
		return
	on_category_selected(best_section, best_category)


## show_invalid_score_feedback(category)
##
## Flashes the row red to indicate the selection is not currently valid.
func show_invalid_score_feedback(category: String) -> void:
	var row: ScorecardRow = rows.get(StringName(category))
	if row:
		var tween := create_tween()
		tween.tween_property(row, "modulate", Color.RED, 0.2).set_trans(Tween.TRANS_SINE)
		tween.tween_property(row, "modulate", Color.WHITE, 0.2).set_delay(0.2)


# --- Mode activations --------------------------------------------------------


## activate_score_reroll()
##
## Reroll-a-score consumable mode: enables only rows that already have scores.
func activate_score_reroll() -> void:
	if not scorecard:
		return
	print("[ScoreCardUI] Score reroll mode activated")
	reroll_active = true
	for category in rows.keys():
		var key := String(category)
		var has_score := false
		if scorecard.upper_scores.has(key):
			has_score = scorecard.upper_scores[key] != null
		else:
			has_score = scorecard.lower_scores[key] != null
		var row: ScorecardRow = rows[category]
		row.disabled = not has_score
		row.interactive = has_score
		if has_score and row.state == ScorecardRow.State.SCORED:
			row.state = ScorecardRow.State.AVAILABLE


## activate_score_double()
##
## Double-an-existing-score consumable mode: enables and highlights only rows
## that already have scores.
func activate_score_double() -> void:
	if not scorecard:
		return
	print("[ScoreCardUI] Double score mode activated")
	is_double_mode = true
	for category in rows.keys():
		var key := String(category)
		var score = null
		if scorecard.upper_scores.has(key):
			score = scorecard.upper_scores[key]
		elif scorecard.lower_scores.has(key):
			score = scorecard.lower_scores[key]
		var row: ScorecardRow = rows[category]
		row.disabled = (score == null)
		row.interactive = (score != null)
		if score != null:
			row.modulate = MODE_DOUBLE_TINT
			if row.state == ScorecardRow.State.SCORED:
				row.state = ScorecardRow.State.AVAILABLE


## activate_any_score_mode()
##
## AnyScore consumable mode: enables and highlights only open (unscored) rows.
func activate_any_score_mode() -> void:
	if not scorecard:
		return
	print("[ScoreCardUI] AnyScore mode activated")
	any_score_active = true
	for category in rows.keys():
		var key := String(category)
		var has_score := false
		if scorecard.upper_scores.has(key):
			has_score = scorecard.upper_scores[key] != null
		else:
			has_score = scorecard.lower_scores[key] != null
		var row: ScorecardRow = rows[category]
		row.disabled = has_score
		row.interactive = not has_score
		if not has_score:
			row.modulate = MODE_ANY_SCORE_TINT


## deactivate_any_score_mode()
##
## Deactivates AnyScore mode and clears all highlighting.
func deactivate_any_score_mode() -> void:
	any_score_active = false
	for row in rows.values():
		row.modulate = Color.WHITE
		row.disabled = true
		row.interactive = false


## set_go_broke_mode(active)
##
## Sets the Go Broke or Go Home mode state (lower section only when active).
func set_go_broke_mode(active: bool) -> void:
	go_broke_mode = active
	print("[ScoreCardUI] Go Broke mode set to:", active)


# --- Mode handlers -----------------------------------------------------------


## _handle_double_score(section, category)
##
## Doubles an existing score in place and clears double mode.
func _handle_double_score(section: Scorecard.Section, category: String) -> void:
	print("[ScoreCardUI] Handling double score for", category)
	var current_score = null
	if section == Scorecard.Section.UPPER:
		current_score = scorecard.upper_scores[category]
	else:
		current_score = scorecard.lower_scores[category]

	if current_score == null:
		show_invalid_score_feedback(category)
		return

	var doubled_score: int = int(current_score) * 2
	print("[ScoreCardUI] Doubling score for", category, "from", current_score, "to", doubled_score)

	scorecard.set_score(section, category, doubled_score)
	update_all()

	is_double_mode = false

	# Reset row highlight tints
	for row in rows.values():
		row.modulate = Color.WHITE

	score_doubled.emit(section, category, doubled_score)
	enable_all_score_buttons()


## handle_score_reroll(section, category)
##
## Replaces an existing score with a fresh evaluation of the current dice.
func handle_score_reroll(section: Scorecard.Section, category: String) -> void:
	var values: Array[int] = DiceResults.values

	# Emit signal before scoring to allow PowerUps to prepare
	about_to_score.emit(section, category, values)

	var score := scorecard.evaluate_category(category, values)
	print("[ScoreCardUI] Reroll score calculated:", score)

	# Verify the category has an existing score to reroll
	var has_existing_score := false
	match section:
		Scorecard.Section.UPPER:
			has_existing_score = scorecard.upper_scores[category] != null
		Scorecard.Section.LOWER:
			has_existing_score = scorecard.lower_scores[category] != null

	if not has_existing_score:
		print("[ScoreCardUI] No existing score to reroll")
		show_invalid_score_feedback(category)
		return

	var reroll_snapshot = scorecard.create_direct_score_snapshot(section, category, score, values, "score_reroll", {
		"active_consumables": ["score_reroll"],
		"has_modifiers": true
	})
	scorecard.set_score(section, category, score, reroll_snapshot)
	update_all()

	# Reset reroll state
	reroll_active = false
	disable_all_score_buttons()

	hand_scored.emit()
	score_rerolled.emit(section, category, score)


## handle_any_score(section, category)
##
## AnyScore mode: scores an open category with the highest-scoring
## interpretation of the current dice.
func handle_any_score(section: Scorecard.Section, category: String) -> void:
	var dice_values: Array[int] = DiceResults.values
	print("[ScoreCardUI] AnyScore mode - scoring", category, "with dice:", dice_values)

	# Emit signal before scoring to allow PowerUps to prepare
	about_to_score.emit(section, category, dice_values)

	# Verify the category is open (hasn't been scored yet)
	var has_existing_score := false
	match section:
		Scorecard.Section.UPPER:
			has_existing_score = scorecard.upper_scores[category] != null
		Scorecard.Section.LOWER:
			has_existing_score = scorecard.lower_scores[category] != null

	if has_existing_score:
		print("[ScoreCardUI] Cannot use AnyScore on already scored category")
		show_invalid_score_feedback(category)
		return

	# Calculate the score using the highest-scoring interpretation of current dice
	var best_score_result = _calculate_best_score_for_dice(dice_values)
	var score := int(best_score_result.get("score", 0))
	var source_category := str(best_score_result.get("category", ""))

	if score < 0:
		print("[ScoreCardUI] Invalid AnyScore calculation")
		show_invalid_score_feedback(category)
		return

	var any_score_breakdown := {
		"active_consumables": ["any_score"],
		"has_modifiers": true
	}
	if source_category != "":
		any_score_breakdown["any_score_source_category"] = source_category
		any_score_breakdown["any_score_source_display"] = scorecard.get_category_display_name(source_category)
	var any_score_snapshot = scorecard.create_direct_score_snapshot(section, category, score, dice_values, "any_score", any_score_breakdown)
	scorecard.set_score(section, category, score, any_score_snapshot)

	# Check for bonus Yahtzee (must be after scoring, before UI update)
	scorecard.check_bonus_yahtzee(dice_values, category)

	update_all()

	# Reset any score mode and clear highlighting
	deactivate_any_score_mode()

	hand_scored.emit()

	print("[ScoreCardUI] AnyScore completed for", category)


## handle_go_broke_score(section, category)
##
## Go Broke or Go Home mode: normal scoring rules, lower section only,
## allowed even if the turn was already scored.
func handle_go_broke_score(section: Scorecard.Section, category: String) -> void:
	var dice_values: Array[int] = DiceResults.values
	print("[ScoreCardUI] Go Broke mode - scoring", category, "with dice:", dice_values)

	# Emit signal before scoring to allow PowerUps to prepare
	about_to_score.emit(section, category, dice_values)

	# Verify the category is open (hasn't been scored yet)
	var has_existing_score: bool = scorecard.lower_scores[category] != null
	if has_existing_score:
		print("[ScoreCardUI] Cannot use Go Broke on already scored category")
		show_invalid_score_feedback(category)
		return

	# Use scorecard's on_category_selected to properly apply normal scoring rules
	scorecard.on_category_selected(section, category)

	var score = scorecard.lower_scores[category]

	if score == null:
		print("[ScoreCardUI] Invalid Go Broke score calculation")
		show_invalid_score_feedback(category)
		return

	# Check for Yahtzee bonus
	scorecard.check_bonus_yahtzee(dice_values)

	# turn_scored before update_all so _refresh_previews clears all ghosts.
	turn_scored = true
	update_all()
	disable_all_score_buttons()

	hand_scored.emit()

	print("[ScoreCardUI] Go Broke completed for", category, "with score:", score)


## _calculate_best_score_for_dice(dice_values) -> Dictionary
##
## Returns the highest possible score for the dice across all categories,
## plus the category that produced it (for snapshot/debug tracing).
func _calculate_best_score_for_dice(dice_values: Array[int]) -> Dictionary:
	var best_score := 0
	var best_category := ""

	var all_categories: Array = []
	all_categories.append_array(scorecard.upper_scores.keys())
	all_categories.append_array(scorecard.lower_scores.keys())

	for category in all_categories:
		var category_score := scorecard.evaluate_category(category, dice_values)
		if category_score > best_score:
			best_score = category_score
			best_category = category

	return {
		"score": best_score,
		"category": best_category
	}


# --- Model signal handlers ---------------------------------------------------


func _on_score_assigned(_section: Scorecard.Section, category: String, score: int) -> void:
	# manual_score lives here (not in on_category_selected) so it fires exactly
	# once per assignment, including auto-scores — the old UI's contract.
	manual_score.emit()
	clear_projections()
	var row: ScorecardRow = rows.get(StringName(category))
	if row:
		row.set_score(score)
		# No dance under a covered row (blinds mid-wipe or pre-populate)
		if row.is_revealed():
			row.play_score_lock()
		row.set_state_scored()
	update_all()

	# NOTE: Do NOT emit hand_scored here — GameButtonUI handles roll button
	# state directly in _on_next_turn_button_pressed().


func _on_score_changed(_total_score: int) -> void:
	update_all()


## _on_score_auto_assigned(section, category, score, breakdown_info)
##
## Model-level auto-scores bypass on_category_selected (turn_scored never
## flips), so ghosts must be wiped explicitly here.
func _on_score_auto_assigned(_section: Scorecard.Section, _category: String, _score: int, _breakdown_info = null) -> void:
	clear_projections()


func _on_category_upgraded(_section: Scorecard.Section, category: String, _new_level: int) -> void:
	var row: ScorecardRow = rows.get(StringName(category))
	if row:
		# Juice (consumable-triggered) adds the elastic settle + particles;
		# the upgrade sound plays once per batch.
		var with_juice := _juice_remaining > 0
		if with_juice:
			_juice_remaining -= 1
			if not _juice_sound_played:
				_juice_sound_played = true
				var audio_mgr = get_node_or_null("/root/AudioManager")
				if audio_mgr and audio_mgr.has_method("play_scorecard_upgrade_sound"):
					audio_mgr.play_scorecard_upgrade_sound()
		row.level_chip.play_upgrade(with_juice)
	_refresh_previews()


func _on_category_downgraded(_section: Scorecard.Section, category: String, _new_level: int) -> void:
	var row: ScorecardRow = rows.get(StringName(category))
	if row:
		row.play_downgrade()
	_refresh_previews()


func _on_upper_bonus_achieved(_bonus: int) -> void:
	update_all()
	var bonus_row: ScorecardRow = summary_rows[&"bonus"]
	var amount := scorecard.get_scaled_upper_bonus_amount()

	# Fill locks full
	if _bonus_progress_fill:
		var fill_tween := create_tween()
		fill_tween.tween_property(_bonus_progress_fill, "anchor_right", 1.0, 0.3)

	# "+35" gold flash for ~0.8s, then restore the locked bonus text
	bonus_row.score_label.text = "+%s" % NumberFormatter.format_int(amount)
	bonus_row.score_label.modulate = Color(1.5, 1.3, 0.8, 1.0)
	var flash_tween := create_tween()
	flash_tween.tween_property(bonus_row.score_label, "modulate", Color.WHITE, 0.3)
	flash_tween.tween_interval(0.5)
	flash_tween.tween_callback(update_all)

	# Celebratory reward preset when TweenFXHelper is available
	var tfx = get_node_or_null("/root/TweenFXHelper")
	if tfx and tfx.has_method("positive_reward"):
		tfx.positive_reward(bonus_row)


func _on_yahtzee_bonus_achieved(_points: int) -> void:
	update_all()


# --- Power-up highlight (Phase 3) --------------------------------------------


## set_power_up_highlight(section, category) -> bool
##
## Applies the Highlighted Score power-up pulse to the requested row.
## Clears any existing highlight first. Returns false if the row is missing
## (highlighted_score_power_up.gd branches on the return value).
func set_power_up_highlight(section: Scorecard.Section, category: String) -> bool:
	clear_power_up_highlight()
	var key := StringName(category)
	var row: ScorecardRow = rows.get(key)
	if row == null:
		push_error("[ScoreCardUI] Could not find score row for Highlighted Score: %s" % category)
		return false
	if _row_sections.get(key) != section:
		push_error("[ScoreCardUI] Section mismatch for Highlighted Score: %s" % category)
		return false
	row.set_highlight(true)
	_highlighted_key = key
	return true


## clear_power_up_highlight()
##
## Fades the power-up highlight off the stored row.
func clear_power_up_highlight() -> void:
	if _highlighted_key != &"":
		var row: ScorecardRow = rows.get(_highlighted_key)
		if row:
			row.set_highlight(false)
	_highlighted_key = &""


## play_power_up_highlight_trigger(section, category)
##
## Plays the highlighted-score bonus burst on the row after the multiplier
## lands: shader strength spike, particle burst, firework sound.
func play_power_up_highlight_trigger(_section: Scorecard.Section, category: String) -> void:
	var row: ScorecardRow = rows.get(StringName(category))
	if row == null:
		return
	row.play_highlight_trigger()
	_spawn_power_up_highlight_particles(row)
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_firework_sound"):
		audio_mgr.play_firework_sound()


func _spawn_power_up_highlight_particles(row: ScorecardRow) -> void:
	if not get_tree() or not get_tree().root:
		return
	var particles = POWER_UP_TRIGGER_PARTICLES.instantiate() as GPUParticles2D
	if not particles:
		return
	get_tree().root.add_child(particles)
	particles.global_position = row.get_global_transform_with_canvas().origin + (row.size / 2.0)
	particles.scale = Vector2(0.35, 0.35)
	particles.modulate = Color(1.0, 0.882353, 0.623529, 1.0)
	particles.z_index = 120
	if particles.has_method("restart"):
		particles.restart()
	else:
		particles.emitting = true
	var cleanup_delay = particles.lifetime + 0.5
	get_tree().create_timer(cleanup_delay).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)


# --- Blinds populate/depopulate (plan §4.3) ----------------------------------


## play_populate()
##
## Reveals the scorecard with a blind-stripe wipe, top to bottom: each
## visible row's blinds progress tweens 0 -> 1 over 0.15s with a 0.05s
## stagger (TRANS_CUBIC/EASE_OUT); section headers fade in alongside their
## first row. Rows reset to AVAILABLE first, then update_all() re-pushes
## model state (levels, scored rows) so revealed content is already correct.
## Awaits two frames before starting tweens so the VBox layout has settled
## and the blinds masks have real sizes.
func play_populate() -> void:
	var visible_rows := _get_visible_rows()
	for row in visible_rows:
		row.reset_to_available()
	if scorecard:
		update_all()

	# Let the layout settle before the wipe so no row tweens on a zero-size mask
	await get_tree().process_frame
	await get_tree().process_frame
	visible_rows = _get_visible_rows()

	var first_lower_index := _count_visible_in([upper_rows, upper_summary])
	for i in visible_rows.size():
		var row: ScorecardRow = visible_rows[i]
		if USE_BLINDS_SHADER:
			var tween := create_tween()
			tween.tween_method(row.set_blinds_progress, 0.0, 1.0, POPULATE_ROW_TIME).set_delay(i * POPULATE_STAGGER).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else:
			_populate_row_fallback(row, i * POPULATE_STAGGER)

	_fade_header(upper_header, 0.0, 0.0)
	_fade_header(lower_header, first_lower_index * POPULATE_STAGGER, 0.0)


## play_depopulate()
##
## Covers the scorecard with the blinds wipe, bottom to top: progress 1 -> 0
## over 0.18s with a 0.04s stagger (EASE_IN). Headers fade out too.
func play_depopulate() -> void:
	var visible_rows := _get_visible_rows()
	visible_rows.reverse()
	for i in visible_rows.size():
		var row: ScorecardRow = visible_rows[i]
		if USE_BLINDS_SHADER:
			var tween := create_tween()
			tween.tween_method(row.set_blinds_progress, 1.0, 0.0, DEPOPULATE_ROW_TIME).set_delay(i * DEPOPULATE_STAGGER).set_ease(Tween.EASE_IN)
		else:
			_depopulate_row_fallback(row, i * DEPOPULATE_STAGGER)

	_fade_header(upper_header, 0.0, 1.0)
	_fade_header(lower_header, 0.0, 1.0)


## animate_entrance()
##
## Legacy entry point (game_controller.gd round start does
## `await score_card_ui.animate_entrance()`). Plays the populate wipe and
## returns after the last row finishes.
func animate_entrance() -> void:
	# game_controller hides the whole control before the round intro; restore it.
	visible = true
	modulate.a = 1.0
	play_populate()
	var row_count := _get_visible_rows().size()
	var total := 0.0
	if row_count > 0:
		total = (row_count - 1) * POPULATE_STAGGER + POPULATE_ROW_TIME
	await get_tree().create_timer(total + 0.05).timeout


func _count_visible_in(containers: Array) -> int:
	var count := 0
	for container in containers:
		for child in container.get_children():
			if child is ScorecardRow and child.visible:
				count += 1
	return count


func _fade_header(header: Control, delay: float, from_alpha: float) -> void:
	header.modulate.a = from_alpha
	var target := 1.0
	if from_alpha == 1.0:
		target = 0.0
	var tween := create_tween()
	tween.tween_property(header, "modulate:a", target, POPULATE_ROW_TIME).set_delay(delay)


func _populate_row_fallback(row: ScorecardRow, delay: float) -> void:
	# Shader-free fallback: fade + 8px upward slide with the same stagger.
	row.modulate.a = 0.0
	row.position.y += 8.0
	var base_y := row.position.y - 8.0
	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, POPULATE_ROW_TIME).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(row, "position:y", base_y, POPULATE_ROW_TIME).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _depopulate_row_fallback(row: ScorecardRow, delay: float) -> void:
	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 0.0, DEPOPULATE_ROW_TIME).set_delay(delay).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(row, "position:y", row.position.y + 8.0, DEPOPULATE_ROW_TIME).set_delay(delay).set_ease(Tween.EASE_IN)


## enable_upgrade_juice(count)
##
## Arms the juice counter for the next `count` category upgrades and resets
## the once-per-batch sound flag. Consumed in _on_category_upgraded.
func enable_upgrade_juice(count: int) -> void:
	_juice_remaining = count
	_juice_sound_played = false


# --- Legacy shims (kept as no-ops so existing callers stay silent) -----------


## prepare_for_scoring_animation()
##
## Shim: the breakdown panels are not part of the new scene.
func prepare_for_scoring_animation() -> void:
	pass


## update_additive_score_panel(value, animate)
##
## Shim: no additive panel in the new scene.
func update_additive_score_panel(_value: int, _animate: bool = false) -> void:
	pass


## update_multiplier_score_panel(value, animate, display_info)
##
## Shim: no multiplier panel in the new scene.
func update_multiplier_score_panel(_value: float, _animate: bool = false, _display_info: Dictionary = {}) -> void:
	pass


## animate_total_score_bounce(score)
##
## Shim: no total score panel in the new scene.
func animate_total_score_bounce(_score: int) -> void:
	pass


## reset_level_labels()
##
## Shim: level chips are refreshed from the model by update_all().
func reset_level_labels() -> void:
	pass


## clear_category_highlight()
##
## Shim until Phase 3 highlight lands.
func clear_category_highlight() -> void:
	# TODO Phase 3
	pass


## stop_idle_float()
##
## Shim: no idle float animation in the new scene.
func stop_idle_float() -> void:
	pass


## pop_score_label(label)
##
## Shim: score pop lands with play_score_lock() in Phase 4.
func pop_score_label(_label = null) -> void:
	pass


## animate_score_counter(from_value, to_value)
##
## Shim: no total score counter in the new scene.
func animate_score_counter(_from_value: int, _to_value: int) -> void:
	pass


## _reset_score_breakdown_labels()
##
## Shim: the breakdown labels are not part of the new scene.
func _reset_score_breakdown_labels() -> void:
	pass
