extends Control

var tracker: TurnTracker 
@onready var money_label: Label = $MoneyLabel
@onready var turn_label := $VBoxContainer/TurnLabel
@onready var rolls_label := $VBoxContainer/RollsLabel

func _ready():
	#call_deferred("bind_tracker", get_node("TurnTracker"))
	PlayerEconomy.money_changed.connect(_on_money_changed)
	_update_money_display()

func bind_tracker(t: TurnTracker):
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return
	tracker = t
	tracker.turn_updated.connect(func(turn): _on_turn_updated(turn))
	tracker.rolls_updated.connect(func(rolls): _on_rolls_updated(rolls))
	# Add connection for MAX_ROLLS changes
	tracker.max_rolls_changed.connect(func(max_rolls): _on_rolls_updated(tracker.rolls_left))
	_on_turn_updated(tracker.current_turn)
	_on_rolls_updated(tracker.rolls_left)

func _on_turn_updated(turn: int):
	var max_t = tracker.max_turns
	turn_label.text = "Turn: %d / %d" % [turn, max_t]

func _on_rolls_updated(rolls: int):
	rolls_label.text = "Rolls: %d/%d" % [rolls, tracker.MAX_ROLLS]
	
	# Optional: Add visual feedback for extra rolls
	if tracker.MAX_ROLLS > 3:  # Base MAX_ROLLS is 3
		rolls_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))  # Green
	else:
		rolls_label.remove_theme_color_override("font_color")

func _update_money_display() -> void:
	if money_label:
		money_label.text = "$%d" % PlayerEconomy.money

func _on_money_changed(new_amount: int) -> void:
	_update_money_display()
