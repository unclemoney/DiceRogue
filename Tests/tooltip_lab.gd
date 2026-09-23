extends Control

## TooltipLab
##
## Iteration sandbox for the standardized Tooltip. Cycles mock entries with
## Prev/Next, replays the show animation, toggles cursor-follow and rarity
## border tint. Touches no game systems.

const ANCHOR := Vector2(480, 200)

var entries: Array[Dictionary] = []
var _index := 0

@onready var _tooltip: Tooltip = $Tooltip
@onready var _follow_check: CheckBox = $Controls/FollowCursorCheck
@onready var _tint_check: CheckBox = $Controls/RarityTintCheck


func _ready() -> void:
	_build_entries()
	$Controls/PrevButton.pressed.connect(_on_prev)
	$Controls/NextButton.pressed.connect(_on_next)
	$Controls/ReplayButton.pressed.connect(_on_replay)
	_follow_check.toggled.connect(_on_follow_toggled)
	_tint_check.toggled.connect(_on_tint_toggled)
	_show_current()


func _build_entries() -> void:
	entries.append({
		"title": "Half-Off Hammers",
		"body": "Consumable. Your next shop purchase costs %s less and you gain %s rerolls." % [TooltipFormat.money(15), TooltipFormat.add(2)],
		"flavor": "",
		"rarity": "",
	})
	entries.append({
		"title": "Coupon Clippers",
		"body": "PowerUp. Earn %s every time you bank a Small Straight. Grants %s score on pickup." % [TooltipFormat.money(5), TooltipFormat.add(1)],
		"flavor": "Mom Approval: She'd be proud of you.",
		"rarity": "uncommon",
	})
	entries.append({
		"title": "Double Down VCR",
		"body": "All scoring this round is multiplied by %s. Stack responsibly." % TooltipFormat.mult(2.5),
		"flavor": "",
		"rarity": "rare",
	})
	entries.append({
		"title": "",
		"body": "",
		"flavor": "Mom Approval: She'd clip this coupon and frame it on the fridge.",
		"rarity": "",
	})
	for tier in ["common", "uncommon", "rare", "epic", "legendary"]:
		entries.append({
			"title": "%s Rarity Sample" % tier.capitalize(),
			"body": "Border tint check for the %s tier. Worth %s, grants %s, scales %s." % [tier, TooltipFormat.money(25), TooltipFormat.add(3), TooltipFormat.mult(1.5)],
			"flavor": "",
			"rarity": tier,
		})
	var long_body := ""
	for i in range(1, 16):
		long_body += "Handbook row %02d of 15.\n" % i
	long_body = long_body.strip_edges()
	entries.append({
		"title": "The Entire Employee Handbook",
		"body": long_body,
		"flavor": "",
		"rarity": "",
	})
	entries.append({
		"title": "Sectioned Sample",
		"body": "One line of body before the dynamic sections.",
		"flavor": "",
		"rarity": "",
		"sections": [
			["Target: [color=#ffd75e]500 pts[/color]", "stat"],
			["Progress: [color=#8eff8e]120/500[/color]", "stat"],
			["Reward: rare coupon", "bullet"],
			["Bullet two", "bullet"],
		],
	})
	var overflow_body := ""
	for i in range(1, 7):
		overflow_body += "Body line %d of six.\n" % i
	entries.append({
		"title": "Overflow Mixed Sample",
		"body": overflow_body.strip_edges(),
		"flavor": "",
		"rarity": "",
		"sections": [
			["Target: [color=#ffd75e]500 pts[/color]", "stat"],
			["Progress: [color=#8eff8e]120/500[/color]", "stat"],
			["Time left: [color=#8eff8e]2 turns[/color]", "stat"],
			["Bonus: [color=#ffd75e]+50 pts[/color]", "stat"],
			["Bullet one", "bullet"],
			["Bullet two", "bullet"],
			["Bullet three", "bullet"],
			["Bullet four (dropped first)", "bullet"],
			["Bullet five (dropped first)", "bullet"],
			["Bullet six (dropped first)", "bullet"],
		],
	})


func _show_current() -> void:
	_apply_entry(entries[_index])


## _apply_entry(entry)
##
## setup() frees all dynamic sections, so every entry application re-issues
## its add_section() calls right after setup().
func _apply_entry(entry: Dictionary) -> void:
	_tooltip.setup(entry)
	for section in entry.get("sections", []):
		_tooltip.add_section(section[0], section[1])
	# Full-viewport anchor: the guard stays plumbed but never trips — the
	# lab's tooltip must stay up while the mouse is on the lab buttons,
	# far from ANCHOR.
	_tooltip.show_at(ANCHOR, Rect2(Vector2.ZERO, Vector2(1280, 720)))


func _on_prev() -> void:
	_index = wrapi(_index - 1, 0, entries.size())
	_show_current()


func _on_next() -> void:
	_index = wrapi(_index + 1, 0, entries.size())
	_show_current()


func _on_replay() -> void:
	_tooltip.hide()
	_apply_entry(entries[_index])


func _on_follow_toggled(pressed: bool) -> void:
	TweenFX.follow_cursor = pressed


func _on_tint_toggled(pressed: bool) -> void:
	_tooltip.tint_border_by_rarity = pressed
	_apply_entry(entries[_index])
