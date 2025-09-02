extends Node
class_name Challenge

@export var id: String
var target: Node
var is_active := false

signal challenge_started
signal challenge_ended
signal challenge_updated(progress: float)
signal challenge_completed
signal challenge_failed

func start() -> void:
	print("[Challenge] Starting challenge:", id)
	is_active = true
	apply(target)
	emit_signal("challenge_started")

func apply(_target) -> void:
	push_error("Challenge.apply() must be overridden")

func remove() -> void:
	push_error("Challenge.remove() must be overridden")

func end() -> void:
	print("[Challenge] Ending challenge:", id)
	is_active = false
	remove()
	emit_signal("challenge_ended")

func get_progress() -> float:
	# Override to provide progress information (0.0 to 1.0)
	return 0.0

func update_progress(progress: float) -> void:
	emit_signal("challenge_updated", progress)
