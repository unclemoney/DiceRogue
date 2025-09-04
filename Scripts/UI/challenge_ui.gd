extends Control
class_name ChallengeUI

signal challenge_selected(id: String)

@export var challenge_icon_scene: PackedScene = preload("res://Scenes/Challenge/ChallengeIcon.tscn")

#current issue is that the score is not connected to the scorecard, so scores isn't registering

var _challenges: Dictionary = {}  # id -> ChallengeIcon

func _ready() -> void:
	if not challenge_icon_scene:
		push_error("[ChallengeUI] No challenge_icon_scene set!")

func add_challenge(data: ChallengeData, challenge: Challenge) -> ChallengeIcon:
	if not challenge_icon_scene:
		push_error("[ChallengeUI] Cannot add challenge - no icon scene!")
		return null
		
	# Check if this challenge is already added
	if _challenges.has(data.id):
		print("[ChallengeUI] Challenge already exists:", data.id)
		return _challenges[data.id]
		
	var icon = challenge_icon_scene.instantiate() as ChallengeIcon
	if not icon:
		push_error("[ChallengeUI] Failed to instantiate challenge icon!")
		return null
		
	add_child(icon)
	icon.set_data(data)
	_challenges[data.id] = icon
	
	# Connect challenge progress signal
	challenge.connect("challenge_updated", _on_challenge_progress_updated.bind(data.id))
	challenge.connect("challenge_completed", _on_challenge_completed.bind(data.id))
	challenge.connect("challenge_failed", _on_challenge_failed.bind(data.id))
	
	return icon

func remove_challenge(id: String) -> void:
	if not _challenges.has(id):
		return
		
	var icon = _challenges[id]
	if icon:
		icon.queue_free()
	_challenges.erase(id)

func get_challenge_icon(id: String) -> ChallengeIcon:
	if _challenges.has(id):
		return _challenges[id]
	return null

func _on_challenge_progress_updated(progress: float, id: String) -> void:
	if _challenges.has(id):
		_challenges[id].set_progress(progress)

func _on_challenge_completed(id: String) -> void:
	if _challenges.has(id):
		var icon = _challenges[id]
		icon.set_progress(1.0)
		
		# Create a success effect
		var tween = create_tween()
		tween.tween_property(icon, "modulate", Color(0.2, 1.0, 0.2), 0.5)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)

func _on_challenge_failed(id: String) -> void:
	if _challenges.has(id):
		var icon = _challenges[id]
		
		# Create a failure effect
		var tween = create_tween()
		tween.tween_property(icon, "modulate", Color(1.0, 0.2, 0.2), 0.5)
		tween.tween_property(icon, "modulate", Color.WHITE, 0.5)
