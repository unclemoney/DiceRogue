extends Consumable
class_name LoadedDiceConsumable

## LoadedDiceConsumable (id: "loaded_dice")
##
## On use, enters a pick-a-die mode via LoadedDiePicker: the player clicks one
## die, then picks the exact value (1..sides of that die) from a popup panel.
## Fallback: if the picker UI cannot be constructed (no scene tree, failed
## instantiate, or no pickable dice with picker failure), the legacy random
## behavior runs instead — one random die set to a random value in 1..sides.

signal value_applied(die: Dice, value: int)

const LoadedDiePickerScene := preload("res://Scenes/UI/loaded_die_picker.tscn")

var _debug_enabled: bool = OS.is_debug_build()
var _picker: LoadedDiePicker = null


func _ready() -> void:
	add_to_group("consumables")
	if _debug_enabled:
		print("[LoadedDiceConsumable] Ready")


## apply(target)
##
## Target must be the GameController. Opens the LoadedDiePicker over the
## current dice hand. The consumable node outlives inventory removal (the
## removal path only unregisters it), so the async selection flow is safe.
func apply(target) -> void:
	var game_controller = target as GameController
	if not game_controller:
		push_error("[LoadedDiceConsumable] Invalid target passed to apply()")
		return

	if not game_controller.dice_hand:
		push_error("[LoadedDiceConsumable] No dice_hand found on game_controller")
		return

	var dice = game_controller.dice_hand.dice_list
	if dice.is_empty():
		if _debug_enabled:
			print("[LoadedDiceConsumable] No dice available to modify")
		return

	# Deferred so the ConsumableUI fan finishes rebuilding before we fold it
	# and start listening for dice clicks.
	_start_selection.call_deferred(dice)


## set_die_value(die: Dice, new_value: int) -> bool
##
## Sets one die to an exact value. Rejects values outside 1..die sides.
## Public and synchronous so tests can drive it without the picker UI.
func set_die_value(die: Dice, new_value: int) -> bool:
	if not die or not is_instance_valid(die):
		return false
	var sides := LoadedDiePicker.get_die_sides(die)
	if new_value < 1 or new_value > sides:
		if _debug_enabled:
			print("[LoadedDiceConsumable] Rejected value %d for d%d" % [new_value, sides])
		return false
	die.value = new_value
	if die.dice_data:
		die.update_visual()
	value_applied.emit(die, new_value)
	if _debug_enabled:
		print("[LoadedDiceConsumable] Set die to value: %d" % new_value)
	return true


## _start_selection(dice: Array)
##
## Folds the consumable fan (its overlay would block dice clicks) and opens
## the picker. Runs deferred from apply().
func _start_selection(dice: Array) -> void:
	# Let the ConsumableUI fan rebuild settle (it re-fans one frame after use)
	await get_tree().process_frame
	await get_tree().process_frame

	var consumable_ui = get_tree().get_first_node_in_group("consumable_ui")
	if consumable_ui and consumable_ui.has_method("fold_back"):
		consumable_ui.fold_back()

	_open_picker(dice)


## _open_picker(dice: Array)
##
## Instantiates the LoadedDiePicker and wires its value_chosen signal.
## Falls back to the legacy random behavior if the UI cannot be built.
func _open_picker(dice: Array) -> void:
	var pickable: Array = []
	for die in dice:
		if die is Dice and is_instance_valid(die):
			if die.current_state != Dice.DiceState.DISABLED:
				pickable.append(die)

	if pickable.is_empty():
		push_error("[LoadedDiceConsumable] No pickable dice; running random fallback")
		_apply_random_fallback(dice)
		return

	if not LoadedDiePickerScene:
		push_error("[LoadedDiceConsumable] Picker scene missing; running random fallback")
		_apply_random_fallback(dice)
		return

	_picker = LoadedDiePickerScene.instantiate() as LoadedDiePicker
	if not _picker:
		push_error("[LoadedDiceConsumable] Picker instantiate failed; running random fallback")
		_apply_random_fallback(dice)
		return

	get_tree().root.add_child(_picker)
	_picker.value_chosen.connect(_on_picker_value_chosen)
	_picker.picker_closed.connect(_on_picker_closed)
	_picker.open(pickable)


func _on_picker_value_chosen(die: Dice, value: int) -> void:
	set_die_value(die, value)
	if _picker and is_instance_valid(_picker):
		_picker.close()


func _on_picker_closed() -> void:
	_picker = null


## _apply_random_fallback(dice: Array)
##
## Legacy behavior: one random die set to a random value in 1..that die's
## sides. Only used when the picker UI cannot be constructed.
func _apply_random_fallback(dice: Array) -> void:
	var random_die = dice[GameRNG.random_index(dice)]
	var sides := LoadedDiePicker.get_die_sides(random_die)
	var random_value = GameRNG.randi_range(1, sides)
	random_die.value = random_value
	if random_die.dice_data:
		random_die.update_visual()
	value_applied.emit(random_die, random_value)
	if _debug_enabled:
		print("[LoadedDiceConsumable] Fallback set a die to value: %d" % random_value)
