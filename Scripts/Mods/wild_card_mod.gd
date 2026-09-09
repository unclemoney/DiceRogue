extends Mod
class_name WildcardMod

## WildcardMod
##
## Lets the attached die count as any OTHER face value when scoring — never
## the face it is currently showing. possible_values is refreshed on every
## roll and consumed by ScoreEvaluatorSingleton when choosing substitutes.

var possible_values: Array[int] = []

var _attached_die: Dice = null
var _debug_enabled: bool = OS.is_debug_build()

func _ready() -> void:
	add_to_group("mods")
	if _debug_enabled:
		print("[WildcardMod] Ready")

func apply(target) -> void:
	var dice = target as Dice
	if dice and dice.dice_data:
		if _debug_enabled:
			print("[WildcardMod] Applied to die:", dice.name)
		_attached_die = dice
		_refresh_possible_values(dice.value)
		# Keep possible_values in sync with the currently shown face
		if not _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.connect(_on_die_rolled)
		emit_signal("mod_applied")
	else:
		push_error("[WildcardMod] Invalid target or missing dice_data")

func get_possible_values() -> Array[int]:
	return possible_values

func remove() -> void:
	if _attached_die:
		if _attached_die.rolled.is_connected(_on_die_rolled):
			_attached_die.rolled.disconnect(_on_die_rolled)
		_attached_die = null
	possible_values.clear()
	emit_signal("mod_removed")

## _on_die_rolled(value)
##
## Rebuilds the substitute list around the newly shown face.
func _on_die_rolled(new_value: int) -> void:
	_refresh_possible_values(new_value)

## _refresh_possible_values(shown_face)
##
## Populates possible_values with every face of the die EXCEPT the face
## currently shown — the wildcard counts as any other number, not its own.
func _refresh_possible_values(shown_face: int) -> void:
	possible_values.clear()
	if not _attached_die or not _attached_die.dice_data:
		return
	for i in range(1, _attached_die.dice_data.sides + 1):
		if i != shown_face:
			possible_values.append(i)
	if _debug_enabled:
		print("[WildcardMod] Possible values:", possible_values)
