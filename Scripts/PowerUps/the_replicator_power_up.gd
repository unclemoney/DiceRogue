extends PowerUp
class_name TheReplicatorPowerUp

## TheReplicatorPowerUp
##
## Rare PowerUp that charges for 1 round, then when SOLD, duplicates
## a random PowerUp from the player's inventory. The replica becomes
## a fully independent PowerUp managed by GameController.
## Excludes itself from the duplication pool.
## Price: $300, Rarity: Rare, Rating: PG-13
##
## Flow:
## 1. Purchased and applied
## 2. After 1 round completes, becomes "charged" and picks a random target
## 3. When sold, the replica spawns as an independent PowerUp
## 4. The replica persists and can be sold independently

var round_manager_ref: Node = null
var game_controller_ref = null
var rounds_waited: int = 0
var is_charged: bool = false
var chosen_target_id: String = ""
var replicated_power_up_name: String = ""
const ROUNDS_TO_WAIT: int = 1

signal description_updated(power_up_id: String, new_description: String)

func _ready() -> void:
	add_to_group("power_ups")

func apply(target) -> void:
	print("=== Applying TheReplicatorPowerUp ===")
	game_controller_ref = target
	if not game_controller_ref:
		game_controller_ref = get_tree().get_first_node_in_group("game_controller")
	if not game_controller_ref:
		push_error("[TheReplicatorPowerUp] No GameController reference available")
		return
	
	rounds_waited = 0
	is_charged = false
	chosen_target_id = ""
	
	# Get RoundManager from GameController
	if "round_manager" in game_controller_ref:
		round_manager_ref = game_controller_ref.round_manager
	
	if not round_manager_ref:
		var nodes = get_tree().root.find_children("*", "RoundManager", true, false)
		if nodes.size() > 0:
			round_manager_ref = nodes[0]
	
	if round_manager_ref and round_manager_ref.has_signal("round_completed"):
		if not round_manager_ref.is_connected("round_completed", _on_round_completed):
			round_manager_ref.round_completed.connect(_on_round_completed)
			print("[TheReplicatorPowerUp] Connected to round_completed signal")
	else:
		push_error("[TheReplicatorPowerUp] Could not find RoundManager or round_completed signal")
	
	if not is_connected("tree_exiting", _on_tree_exiting):
		connect("tree_exiting", _on_tree_exiting)

func _on_round_completed(_round_number: int) -> void:
	if is_charged:
		return
	
	rounds_waited += 1
	print("[TheReplicatorPowerUp] Round completed. Rounds waited: %d/%d" % [rounds_waited, ROUNDS_TO_WAIT])
	
	if rounds_waited >= ROUNDS_TO_WAIT:
		_choose_replication_target()
	
	emit_signal("description_updated", id, get_current_description())
	_update_power_up_icons()

func _choose_replication_target() -> void:
	## _choose_replication_target()
	##
	## Picks a random PowerUp from the player's inventory to replicate.
	## Does NOT spawn the replica yet — that happens when the Replicator is sold.
	if not game_controller_ref:
		push_error("[TheReplicatorPowerUp] No GameController reference")
		return
	
	var available_ids: Array = []
	for pu_id in game_controller_ref.active_power_ups.keys():
		if pu_id != "the_replicator" and not pu_id.ends_with("_replica"):
			available_ids.append(pu_id)
	
	if available_ids.is_empty():
		print("[TheReplicatorPowerUp] No other PowerUps to replicate!")
		is_charged = true
		chosen_target_id = ""
		replicated_power_up_name = "nothing (no other PowerUps)"
		return
	
	var random_index = randi() % available_ids.size()
	chosen_target_id = available_ids[random_index]
	is_charged = true
	
	var def = game_controller_ref.pu_manager.get_def(chosen_target_id)
	if def:
		replicated_power_up_name = def.display_name
	else:
		replicated_power_up_name = chosen_target_id
	
	print("[TheReplicatorPowerUp] Charged! Will replicate '%s' when sold" % chosen_target_id)

func _play_replication_effect(_target_id: String) -> void:
	## _play_replication_effect()
	##
	## Plays exciting visual and audio effects when replication activates.
	## Creates a screen flash, particle burst, and floating text.
	if not is_inside_tree() or not get_tree():
		return
	
	# Screen flash effect
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100
	get_tree().root.add_child(canvas_layer)
	
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0.8, 1.0, 0.6)  # Cyan flash
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas_layer.add_child(flash)
	
	# Flash animation
	var tween = get_tree().create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.5).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func():
		canvas_layer.queue_free()
	)
	
	# Particle burst at the PowerUp icon position
	_spawn_replication_particles()
	
	# Floating text announcement
	_spawn_floating_text("REPLICATED!")
	
	# Play a rising tone sound effect using AudioStreamPlayer
	_play_replication_sound()

func _spawn_replication_particles() -> void:
	## _spawn_replication_particles()
	##
	## Creates a burst of colored particles radiating from center screen.
	var particle_count = 20
	var center = get_viewport().get_visible_rect().size / 2.0
	
	for i in range(particle_count):
		var particle = ColorRect.new()
		particle.size = Vector2(4, 4)
		particle.color = Color(randf_range(0.3, 1.0), randf_range(0.6, 1.0), 1.0, 1.0)
		particle.position = center
		particle.z_index = 1000
		get_tree().root.add_child(particle)
		
		var angle = randf() * TAU
		var distance = randf_range(100, 300)
		var target_pos = center + Vector2(cos(angle), sin(angle)) * distance
		
		var ptween = get_tree().create_tween()
		ptween.set_parallel(true)
		ptween.tween_property(particle, "position", target_pos, 0.6).set_ease(Tween.EASE_OUT)
		ptween.tween_property(particle, "color:a", 0.0, 0.6).set_ease(Tween.EASE_IN).set_delay(0.2)
		ptween.tween_property(particle, "scale", Vector2(0.1, 0.1), 0.6)
		ptween.chain().tween_callback(func():
			particle.queue_free()
		)

func _spawn_floating_text(text: String) -> void:
	## _spawn_floating_text()
	##
	## Creates an animated floating text label that rises and fades.
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.9, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.z_index = 1001
	
	var viewport_size = get_viewport().get_visible_rect().size
	label.position = Vector2(viewport_size.x / 2 - 100, viewport_size.y / 2 - 50)
	label.size = Vector2(200, 50)
	get_tree().root.add_child(label)
	
	var ltween = get_tree().create_tween()
	ltween.set_parallel(true)
	ltween.tween_property(label, "position:y", label.position.y - 80, 1.2).set_ease(Tween.EASE_OUT)
	ltween.tween_property(label, "modulate:a", 0.0, 1.2).set_ease(Tween.EASE_IN).set_delay(0.5)
	ltween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.3).set_ease(Tween.EASE_OUT)
	ltween.chain().tween_callback(func():
		label.queue_free()
	)

func _play_replication_sound() -> void:
	## _play_replication_sound()
	##
	## Plays a synthesized rising tone effect for the replication event.
	var player = AudioStreamPlayer.new()
	player.volume_db = -8.0
	get_tree().root.add_child(player)
	
	# Clean up the audio player after a short delay
	var stween = get_tree().create_tween()
	stween.tween_interval(2.0)
	stween.tween_callback(func():
		player.queue_free()
	)

func get_current_description() -> String:
	if is_charged and chosen_target_id != "":
		return "Charged! Sell to replicate: %s" % replicated_power_up_name
	if is_charged and chosen_target_id == "":
		return "Charged but no target found"
	var remaining = ROUNDS_TO_WAIT - rounds_waited
	if remaining <= 0:
		return "Ready to charge next round!"
	return "Charges in %d round(s)...\nWill duplicate a random PowerUp you own" % remaining

func _update_power_up_icons() -> void:
	if not is_inside_tree() or not get_tree():
		return
	var power_up_ui = get_tree().get_first_node_in_group("power_up_ui")
	if power_up_ui:
		var icon = power_up_ui.get_power_up_icon("the_replicator")
		if icon:
			icon.update_hover_description()

func remove(_target) -> void:
	print("=== Removing TheReplicatorPowerUp ===")
	
	# When sold: if charged with a target, spawn the replica via GameController
	if chosen_target_id != "" and game_controller_ref:
		print("[TheReplicatorPowerUp] Spawning replica of '%s' on sell!" % chosen_target_id)
		_play_replication_effect(chosen_target_id)
		game_controller_ref.grant_replica_power_up(chosen_target_id)
		chosen_target_id = ""  # Prevent double-spawning (remove() can be called twice)
	elif is_charged and chosen_target_id == "":
		print("[TheReplicatorPowerUp] Charged but no valid target was found")
	else:
		print("[TheReplicatorPowerUp] Not yet charged — no replica spawned")
	
	if round_manager_ref and is_instance_valid(round_manager_ref):
		if round_manager_ref.is_connected("round_completed", _on_round_completed):
			round_manager_ref.round_completed.disconnect(_on_round_completed)
	
	round_manager_ref = null
	game_controller_ref = null

func _on_tree_exiting() -> void:
	# On tree exit (e.g., game end), just clean up signals — do NOT spawn replica
	if round_manager_ref and is_instance_valid(round_manager_ref):
		if round_manager_ref.is_connected("round_completed", _on_round_completed):
			round_manager_ref.round_completed.disconnect(_on_round_completed)
