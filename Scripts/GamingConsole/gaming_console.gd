extends Node2D
class_name GamingConsole

signal activated
signal deactivated
signal uses_changed(remaining: int)
signal description_updated(new_description: String)

@export var id: String
@export var console_name: String
@export var uses_per_round: int = 1

var is_active: bool = false
var uses_remaining: int = 0
var _target = null


## apply(target)
##
## Called when the console is first granted. Override in subclasses
## to connect signals and set up the console's power.
func apply(_target_node) -> void:
	_target = _target_node
	is_active = true
	uses_remaining = uses_per_round


## remove(target)
##
## Called when the console is removed (channel reset). Override to
## disconnect signals and clean up.
func remove(_target_node) -> void:
	is_active = false
	_target = null


## can_activate() -> bool
##
## Returns true if the console power can be activated right now.
## Override in subclasses for custom activation conditions.
func can_activate() -> bool:
	if not is_active:
		return false
	if uses_per_round <= 0:
		return false
	return uses_remaining > 0


## activate() -> void
##
## Called when the player presses the ACTIVATE button.
## Override in subclasses to implement the power.
func activate() -> void:
	if not can_activate():
		return
	uses_remaining -= 1
	emit_signal("uses_changed", uses_remaining)
	emit_signal("activated")


## is_passive() -> bool
##
## Returns true if this console's power is always-on and doesn't need
## the ACTIVATE button. Override in passive subclasses.
func is_passive() -> bool:
	return false


## reset_for_new_round() -> void
##
## Restores uses at the start of each round.
func reset_for_new_round() -> void:
	uses_remaining = uses_per_round
	emit_signal("uses_changed", uses_remaining)


## get_power_description() -> String
##
## Returns the description of this console's power for the hover tooltip.
func get_power_description() -> String:
	return ""
