extends Control

var tracker: TurnTracker

@onready var turn_label := $VBoxContainer/TurnLabel
@onready var rolls_label := $VBoxContainer/RollsLabel

func _ready():
	call_deferred("bind_tracker", get_node("TurnTracker"))

func bind_tracker(t: TurnTracker):
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return
	tracker = t
	tracker.turn_updated.connect(func(turn): _on_turn_updated(turn))
	tracker.rolls_updated.connect(func(rolls): _on_rolls_updated(rolls))
	_on_turn_updated(tracker.current_turn)
	_on_rolls_updated(tracker.rolls_left)

func _on_turn_updated(turn: int):
	var max_t = tracker.max_turns
	turn_label.text = "Turn: %d / %d" % [turn, max_t]

func _on_rolls_updated(rolls: int):
	rolls_label.text = "Rolls Left: %d" % rolls
