extends Node
class_name ChallengeManager

signal definitions_loaded
signal challenge_activated(id: String)
signal challenge_completed(id: String)
signal challenge_failed(id: String)

@export var challenge_defs: Array[ChallengeData] = []
@onready var _defs_by_id: Dictionary = {}

func _ready() -> void:
	print("ChallengeManager: loading definitions...")
	_load_definitions()
	
func _load_definitions() -> void:
	_defs_by_id.clear()
	for def in challenge_defs:
		if def == null:
			push_error("ChallengeManager: null challenge definition")
			continue
			
		if def.id.is_empty():
			push_error("ChallengeManager: challenge def has empty ID")
			continue
			
		_defs_by_id[def.id] = def
		
	print("ChallengeManager: defs count =", _defs_by_id.size())
	for id in _defs_by_id:
		print("ChallengeManager: Registered challenge:", id)
		
	emit_signal("definitions_loaded")
	
func get_def(id: String) -> ChallengeData:
	if not _defs_by_id.has(id):
		push_error("ChallengeManager: No definition for '%s'" % id)
		return null
	return _defs_by_id[id]

func spawn_challenge(id: String, parent: Node) -> Challenge:
	var def = get_def(id)
	if def == null or def.scene == null:
		push_error("ChallengeManager: Invalid challenge def/scene for '%s'" % id)
		return null
		
	var instance = def.scene.instantiate()
	if not instance is Challenge:
		push_error("ChallengeManager: Instanced scene is not a Challenge")
		return null
		
	parent.add_child(instance)
	var challenge = instance as Challenge
	challenge.id = id
	
	# Connect signals for tracking
	challenge.connect("challenge_completed", _on_challenge_completed.bind(id))
	challenge.connect("challenge_failed", _on_challenge_failed.bind(id))
	
	return challenge

func _on_challenge_completed(id: String) -> void:
	print("ChallengeManager: Challenge completed:", id)
	emit_signal("challenge_completed", id)

func _on_challenge_failed(id: String) -> void:
	print("ChallengeManager: Challenge failed:", id)
	emit_signal("challenge_failed", id)

func get_all_challenge_ids() -> Array[String]:
	return _defs_by_id.keys()
