extends Consumable
class_name ScoreRerollConsumable

signal reroll_activated
signal reroll_completed

var is_active := false

func _ready() -> void:
	add_to_group("consumables")

func apply(target) -> void:
	var game_controller = target as Node
	if game_controller:
		is_active = true
		emit_signal("reroll_activated")
	else:
		push_error("[ScoreReroll] Invalid target passed to apply()")

func complete_reroll() -> void:
	print("ScoreRerollConsumable: Completing reroll")
	is_active = false
	emit_signal("reroll_completed")
