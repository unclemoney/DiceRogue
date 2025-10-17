extends Control

var tracker: TurnTracker 
@onready var money_label: Label = $MoneyLabel
@onready var turn_label := $VBoxContainer/TurnLabel
@onready var rolls_label := $VBoxContainer/RollsLabel
@export var round_manager_path: NodePath
@onready var round_manager: RoundManager = get_node_or_null(round_manager_path)
@onready var round_label: Label = $RoundLabel  # Add this label to the scene
var additive_label: Label = null  # For displaying Red Power Ranger additive

func _ready():
	add_to_group("turn_tracker_ui")
	#call_deferred("bind_tracker", get_node("TurnTracker"))
	PlayerEconomy.money_changed.connect(_on_money_changed)
	_update_money_display()

	if round_manager:
		round_manager.round_started.connect(_update_round_display)
	
	_update_round_display(1)  # Default to round 1

func bind_tracker(t: TurnTracker):
	if t == null:
		push_error("TurnTracker is null—cannot bind signals.")
		return
	tracker = t
	tracker.turn_updated.connect(func(turn): _on_turn_updated(turn))
	tracker.rolls_updated.connect(func(rolls): _on_rolls_updated(rolls))
	# Add connection for MAX_ROLLS changes
	tracker.max_rolls_changed.connect(func(_max_rolls): _on_rolls_updated(tracker.rolls_left))
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

func _on_money_changed(_new_amount: int) -> void:
	_update_money_display()

func _update_round_display(round_number: int) -> void:
	if round_label:
		round_label.text = "Round: " + str(round_number)

## update_additive_display(additive)
##
## Updates the additive display for Red Power Ranger
func update_additive_display(additive: int) -> void:
	_create_additive_label_if_needed()
	
	if additive > 0:
		additive_label.text = "Red Ranger: +%d" % additive
		additive_label.visible = true
	else:
		additive_label.visible = false

## _create_additive_label_if_needed()
##
## Creates the additive label if it doesn't exist yet
func _create_additive_label_if_needed() -> void:
	if additive_label:
		return
	
	additive_label = Label.new()
	additive_label.name = "AdditiveLabel"
	additive_label.add_theme_color_override("font_color", Color.RED)
	additive_label.position = Vector2(10, 90)  # Position below other UI elements
	add_child(additive_label)
