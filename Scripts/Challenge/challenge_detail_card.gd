extends Control
class_name ChallengeDetailCard

## ChallengeDetailCard
##
## Rich info card displayed on the SpineFanOverlay when the challenge_container
## is clicked. Built entirely in code — no .tscn dependency.
##
## Layout (top → bottom inside a styled PanelContainer):
##   Name · Dice badge · Description · separator ·
##   Difficulty stars · Progress bar + % · Target score ·
##   Reward · Debuff tags · separator · Score history (last 5 hands)
##
## Public API:
##   setup(data, progress) — call once after instantiation
##   refresh_score_history() — re-pulls Statistics log entries

signal card_closed

const CARD_SIZE := Vector2(220, 320)

var _data: ChallengeData
var _progress: float = 0.0

var _panel: PanelContainer
var _progress_bar: ProgressBar
var _progress_pct_label: Label
var _score_history_vbox: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_SIZE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = CARD_SIZE
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.08, 0.13, 0.97)
	style.border_color = Color(0.9, 0.72, 0.15, 1.0)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.corner_detail = 8
	style.content_margin_left = 12
	style.content_margin_top = 10
	style.content_margin_right = 12
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.name = "ContentVBox"
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile

	# — Name label —
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		name_lbl.add_theme_font_override("font", vcr_font)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1.0))
	vbox.add_child(name_lbl)

	# — Dice type badge (hidden if standard d6) —
	var dice_lbl := Label.new()
	dice_lbl.name = "DiceBadge"
	dice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		dice_lbl.add_theme_font_override("font", vcr_font)
	dice_lbl.add_theme_font_size_override("font_size", 10)
	dice_lbl.add_theme_color_override("font_color", Color(0.55, 0.85, 1.0, 1.0))
	vbox.add_child(dice_lbl)

	# — Description —
	var desc_lbl := Label.new()
	desc_lbl.name = "DescLabel"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		desc_lbl.add_theme_font_override("font", vcr_font)
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.78, 0.75, 1.0))
	vbox.add_child(desc_lbl)

	_add_separator(vbox)

	# — Difficulty row —
	var diff_lbl := Label.new()
	diff_lbl.name = "DiffLabel"
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	diff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		diff_lbl.add_theme_font_override("font", vcr_font)
	diff_lbl.add_theme_font_size_override("font_size", 10)
	diff_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1.0))
	vbox.add_child(diff_lbl)

	# — Progress row: Control overlay so % label sits on top of the bar's right edge —
	var prog_container := Control.new()
	prog_container.name = "ProgressRow"
	prog_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prog_container.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(prog_container)

	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.min_value = 0
	_progress_bar.max_value = 100
	_progress_bar.value = 0
	_progress_bar.show_percentage = false
	_progress_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(0.9, 0.75, 0.2, 1.0)
	fg.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("fill", fg)
	var pbg := StyleBoxFlat.new()
	pbg.bg_color = Color(0.08, 0.08, 0.08, 0.7)
	pbg.set_corner_radius_all(4)
	_progress_bar.add_theme_stylebox_override("background", pbg)
	prog_container.add_child(_progress_bar)

	# % label anchored over the full bar, right-aligned, so it reads at the right edge
	_progress_pct_label = Label.new()
	_progress_pct_label.name = "PctLabel"
	_progress_pct_label.set_anchor(SIDE_LEFT, 0.0)
	_progress_pct_label.set_anchor(SIDE_TOP, 0.0)
	_progress_pct_label.set_anchor(SIDE_RIGHT, 1.0)
	_progress_pct_label.set_anchor(SIDE_BOTTOM, 1.0)
	_progress_pct_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_progress_pct_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_progress_pct_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vcr_font:
		_progress_pct_label.add_theme_font_override("font", vcr_font)
	_progress_pct_label.add_theme_font_size_override("font_size", 9)
	_progress_pct_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_progress_pct_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_progress_pct_label.add_theme_constant_override("shadow_offset_x", 1)
	_progress_pct_label.add_theme_constant_override("shadow_offset_y", 1)
	prog_container.add_child(_progress_pct_label)

	# — Target score —
	var target_lbl := Label.new()
	target_lbl.name = "TargetLabel"
	target_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		target_lbl.add_theme_font_override("font", vcr_font)
	target_lbl.add_theme_font_size_override("font_size", 11)
	target_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	vbox.add_child(target_lbl)

	# — Reward —
	var reward_lbl := Label.new()
	reward_lbl.name = "RewardLabel"
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		reward_lbl.add_theme_font_override("font", vcr_font)
	reward_lbl.add_theme_font_size_override("font_size", 10)
	reward_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5, 1.0))
	vbox.add_child(reward_lbl)

	# — Debuff tags container —
	var debuff_flow := HFlowContainer.new()
	debuff_flow.name = "DebuffFlow"
	debuff_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debuff_flow.add_theme_constant_override("h_separation", 4)
	debuff_flow.add_theme_constant_override("v_separation", 3)
	vbox.add_child(debuff_flow)

	_add_separator(vbox)

	# — Score history header —
	var hist_header := Label.new()
	hist_header.name = "HistHeader"
	hist_header.text = "Recent Hands:"
	hist_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hist_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if vcr_font:
		hist_header.add_theme_font_override("font", vcr_font)
	hist_header.add_theme_font_size_override("font_size", 10)
	hist_header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	vbox.add_child(hist_header)

	_score_history_vbox = VBoxContainer.new()
	_score_history_vbox.name = "ScoreHistory"
	_score_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_score_history_vbox.add_theme_constant_override("separation", 2)
	vbox.add_child(_score_history_vbox)

func _add_separator(parent: VBoxContainer) -> void:
	var sep := HSeparator.new()
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.35, 0.28, 0.45, 0.6)
	sep_style.content_margin_top = 1.0
	sep_style.content_margin_bottom = 1.0
	sep.add_theme_stylebox_override("separator", sep_style)
	parent.add_child(sep)

## setup(data, progress)
## Populates all fields from a ChallengeData resource.
## progress is 0.0–1.0.
func setup(p_data: ChallengeData, p_progress: float) -> void:
	_data = p_data
	_progress = p_progress
	_populate()

func _populate() -> void:
	if not _data:
		return
	if not _panel:
		return

	var scroll := _panel.get_node_or_null("Scroll")
	if not scroll:
		return
	var vbox := scroll.get_node_or_null("ContentVBox")
	if not vbox:
		return

	var name_lbl := vbox.get_node_or_null("NameLabel") as Label
	if name_lbl:
		name_lbl.text = _data.display_name if _data.display_name else _data.id

	var dice_lbl := vbox.get_node_or_null("DiceBadge") as Label
	if dice_lbl:
		if _data.dice_type != "" and _data.dice_type != "d6":
			dice_lbl.text = "Dice: %s" % _data.dice_type
			dice_lbl.visible = true
		else:
			dice_lbl.visible = false

	var desc_lbl := vbox.get_node_or_null("DescLabel") as Label
	if desc_lbl:
		desc_lbl.text = _data.description if _data.description else ""

	var diff_lbl := vbox.get_node_or_null("DiffLabel") as Label
	if diff_lbl:
		var stars := _build_star_string(_data.difficulty)
		diff_lbl.text = "Difficulty: %s" % stars

	if _progress_bar:
		_progress_bar.value = _progress * 100.0

	if _progress_pct_label:
		_progress_pct_label.text = "%d%%" % int(_progress * 100.0)

	var target_lbl := vbox.get_node_or_null("TargetLabel") as Label
	if target_lbl:
		target_lbl.text = "Target: %s pts" % NumberFormatter.format_score(_data.target_score)

	var reward_lbl := vbox.get_node_or_null("RewardLabel") as Label
	if reward_lbl:
		reward_lbl.text = "Reward: $%s" % NumberFormatter.format_score(_data.reward_money)

	var debuff_flow := vbox.get_node_or_null("DebuffFlow") as HFlowContainer
	if debuff_flow:
		for child in debuff_flow.get_children():
			child.queue_free()
		if _data.debuff_ids.size() > 0:
			debuff_flow.visible = true
			for debuff_id in _data.debuff_ids:
				var tag := Label.new()
				tag.text = debuff_id
				tag.add_theme_font_size_override("font_size", 9)
				tag.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35, 1.0))
				debuff_flow.add_child(tag)
		else:
			debuff_flow.visible = false

	refresh_score_history()

## refresh_score_history()
## Re-pulls the last 5 LogEntry records from Statistics and updates the history list.
func refresh_score_history() -> void:
	if not _score_history_vbox:
		return

	for child in _score_history_vbox.get_children():
		child.queue_free()

	var statistics = Engine.get_singleton("Statistics") if Engine.has_singleton("Statistics") else get_node_or_null("/root/Statistics")
	if not statistics or not statistics.has_method("get_recent_log_entries"):
		var empty_lbl := Label.new()
		empty_lbl.text = "No history yet"
		empty_lbl.add_theme_font_size_override("font_size", 9)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_score_history_vbox.add_child(empty_lbl)
		return

	var entries: Array = statistics.get_recent_log_entries(5)
	if entries.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No history yet"
		empty_lbl.add_theme_font_size_override("font_size", 9)
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		_score_history_vbox.add_child(empty_lbl)
		return

	var vcr_font = load("res://Resources/Font/VCR_OSD_MONO_1.001.ttf") as FontFile
	for entry in entries:
		var entry_lbl := Label.new()
		var cat: String = entry.scorecard_category if entry.scorecard_category else "?"
		var score: int = entry.final_score
		entry_lbl.text = "  %s → %s" % [cat, NumberFormatter.format_score(score)]
		entry_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if vcr_font:
			entry_lbl.add_theme_font_override("font", vcr_font)
		entry_lbl.add_theme_font_size_override("font_size", 9)
		entry_lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 0.65, 1.0))
		_score_history_vbox.add_child(entry_lbl)

func _build_star_string(difficulty: int) -> String:
	var clamped: int = clamp(difficulty, 0, 5)
	var result := ""
	for i in range(5):
		if i < clamped:
			result += "★"
		else:
			result += "☆"
	return result
