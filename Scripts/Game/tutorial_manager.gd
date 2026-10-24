# Scripts/Game/tutorial_manager.gd
extends Node

## TutorialManager Autoload
##
## Orchestrates the tutorial system, managing step progression, action gating,
## UI highlighting, and keyboard shortcut blocking during tutorial mode.
## Persists tutorial completion status to the player's profile.

# Preload TutorialStep for type hints (also available via class_name)
const TutorialStepClass = preload("res://Scripts/Core/tutorial_step.gd")

# Signals for tutorial events
signal tutorial_started
signal tutorial_step_started(step)
signal tutorial_part_advanced(step)
signal tutorial_step_completed(step)
signal tutorial_completed
signal tutorial_skipped
signal tutorial_exited
signal tutorial_reset

# Tutorial state
var is_active: bool = false
var is_tutorial_session_active: bool = false
var is_paused: bool = false
var current_step = null
var current_step_id: String = ""
var current_part: int = 1
var all_steps: Dictionary = {}
var step_order: Array[String] = []
var completed_step_ids: Dictionary = {}
var granted_step_ids: Dictionary = {}
var last_mom_summary: Dictionary = {}

# Tutorial completion tracking (synced with ProgressManager)
var tutorial_completed_flag: bool = false
var tutorial_in_progress_flag: bool = false

var _navigation_generation: int = 0
var _is_transitioning: bool = false
var _is_exiting: bool = false
var _had_save_at_start: bool = false
var _gameplay: Node = null

# Keyboard shortcut blocking
var _blocked_actions: Array[String] = [
	"roll", "next_turn", "shop", "next_round",
	"lock_dice_1", "lock_dice_2", "lock_dice_3", "lock_dice_4", "lock_dice_5",
	"lock_dice_6", "lock_dice_7", "lock_dice_8", "lock_dice_9", "lock_dice_10",
	"lock_dice_11", "lock_dice_12", "lock_dice_13", "lock_dice_14", "lock_dice_15", "lock_dice_16"
]

# Signal connection tracking for cleanup
var _connected_signals: Array[Dictionary] = []

# UI components (instantiated when needed)
var _tutorial_dialog: Control = null
var _tutorial_highlight: CanvasLayer = null

# Preloads
const TUTORIAL_STEP_DIR := "res://Resources/Data/Tutorial/"
const TutorialDialogScript := preload("res://Scripts/UI/tutorial_dialog.gd")
const TutorialHighlightScript := preload("res://Scripts/UI/tutorial_highlight.gd")
const TUTORIAL_GAMEPLAY_PATH := "res://Scripts/Game/tutorial_gameplay.gd"


func _ready() -> void:
	# Ensure tutorial manager works when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[TutorialManager] Initializing tutorial system")
	_load_all_steps()
	_sync_from_profile()


func _exit_tree() -> void:
	_cleanup_ui()
	_disconnect_all_signals()


## _load_all_steps()
##
## Loads all TutorialStep resources from the tutorial data directory.
## Logs errors for any files that fail to load.
func _load_all_steps() -> void:
	all_steps.clear()
	step_order.clear()
	
	var dir = DirAccess.open(TUTORIAL_STEP_DIR)
	if not dir:
		push_error("[TutorialManager] Failed to open tutorial directory: %s" % TUTORIAL_STEP_DIR)
		return
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var loaded_count := 0
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path = TUTORIAL_STEP_DIR + file_name
			var step = ResourceLoader.load(full_path)
			if step and step is Resource:
				if step.get("id") == null or step.id == "":
					push_error("[TutorialManager] TutorialStep in '%s' has empty id" % file_name)
				elif all_steps.has(step.id):
					push_error("[TutorialManager] Duplicate step id '%s' in '%s'" % [step.id, file_name])
				else:
					all_steps[step.id] = step
					loaded_count += 1
			else:
				push_error("[TutorialManager] Failed to load TutorialStep: %s" % full_path)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	
	# Build step order from next_step_id chain
	_build_step_order()
	
	print("[TutorialManager] Loaded %d tutorial steps" % loaded_count)


## _build_step_order()
##
## Builds the step_order array by following the next_step_id chain.
## Starts from the "intro" step if it exists.
func _build_step_order() -> void:
	step_order.clear()
	
	# Find the starting step (should be "intro")
	var start_id := "intro"
	if not all_steps.has(start_id):
		# Find any step without a predecessor
		for step_id in all_steps.keys():
			var has_predecessor := false
			for other_id in all_steps.keys():
				if all_steps[other_id].next_step_id == step_id:
					has_predecessor = true
					break
			if not has_predecessor:
				start_id = step_id
				break
	
	if not all_steps.has(start_id):
		push_error("[TutorialManager] No starting step found for tutorial")
		return
	
	# Follow the chain
	var current_id := start_id
	var visited: Dictionary = {}
	
	while current_id != "" and all_steps.has(current_id):
		if visited.has(current_id):
			push_error("[TutorialManager] Circular reference detected at step '%s'" % current_id)
			break
		visited[current_id] = true
		step_order.append(current_id)
		current_id = all_steps[current_id].next_step_id
	
	print("[TutorialManager] Step order: %s" % str(step_order))


## _sync_from_profile()
##
## Syncs tutorial completion status from the player's profile.
func _sync_from_profile() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager:
		# Check if profile has tutorial tracking fields
		if progress_manager.get("tutorial_completed") != null:
			tutorial_completed_flag = progress_manager.tutorial_completed
		if progress_manager.get("tutorial_in_progress") != null:
			tutorial_in_progress_flag = progress_manager.tutorial_in_progress
	print("[TutorialManager] Tutorial completed: %s, In progress: %s" % [tutorial_completed_flag, tutorial_in_progress_flag])


## _sync_to_profile()
##
## Saves tutorial completion status to the player's profile.
func _sync_to_profile() -> void:
	var progress_manager = get_node_or_null("/root/ProgressManager")
	if progress_manager:
		if progress_manager.get("tutorial_completed") != null:
			progress_manager.tutorial_completed = tutorial_completed_flag
		if progress_manager.get("tutorial_in_progress") != null:
			progress_manager.tutorial_in_progress = tutorial_in_progress_flag
		if progress_manager.has_method("save_current_profile"):
			progress_manager.save_current_profile()


# ===== PUBLIC API =====

## start_tutorial()
##
## Starts the tutorial from the beginning.
## Creates UI components if needed and shows the first step.
func start_tutorial() -> void:
	if all_steps.is_empty() or is_active or step_order.is_empty():
		return
	_navigation_generation += 1
	var generation := _navigation_generation
	_had_save_at_start = GameSaveManager.has_save_for_profile(GameSettings.active_profile_slot)
	is_tutorial_session_active = true
	is_active = true
	_is_exiting = false
	tutorial_completed_flag = false
	tutorial_in_progress_flag = true
	completed_step_ids.clear()
	granted_step_ids.clear()
	last_mom_summary.clear()
	_sync_to_profile()
	await _ensure_ui_exists()
	if generation != _navigation_generation or not is_active:
		return
	if _gameplay and _gameplay.has_method("begin_session"):
		_gameplay.begin_session()
	_show_step(step_order[0])
	tutorial_started.emit()


## resume_tutorial()
##
## Resumes the tutorial from where the player left off.
## If no saved position, starts from the beginning.
func resume_tutorial() -> void:
	if not tutorial_in_progress_flag:
		start_tutorial()
		return
	
	# TODO: Implement saved step position tracking
	# For now, restart from beginning
	start_tutorial()


## skip_tutorial()
##
## Skips the remainder of the tutorial and marks it complete.
func skip_tutorial() -> void:
	exit_tutorial()


func exit_tutorial() -> void:
	_finish_session(false)


func _finish_session(completed: bool) -> void:
	if _is_exiting or not is_tutorial_session_active:
		return
	_is_exiting = true
	_navigation_generation += 1
	is_active = false
	_is_transitioning = false
	tutorial_completed_flag = completed
	tutorial_in_progress_flag = false
	_cleanup_current_step()
	_cleanup_ui()
	current_step = null
	current_step_id = ""
	current_part = 1
	get_tree().paused = false
	_sync_to_profile()
	var pause_layer = get_tree().root.get_node_or_null("PauseMenuLayer")
	if pause_layer:
		pause_layer.queue_free()
	if completed:
		tutorial_completed.emit()
	else:
		tutorial_exited.emit()
	while SceneTransitionManager.is_transitioning():
		await get_tree().process_frame
	var main_menu_scene = preload("res://Scenes/UI/MainMenu.tscn")
	await SceneTransitionManager.transition_to_scene_packed(main_menu_scene)
	if not _had_save_at_start:
		GameSaveManager.delete_current_save()
	is_tutorial_session_active = false
	_is_exiting = false


## reset_tutorial()
##
## Resets the tutorial to allow replaying from the beginning.
## Does not automatically start - call start_tutorial() after.
func reset_tutorial() -> void:
	_navigation_generation += 1
	is_active = false
	is_tutorial_session_active = false
	_is_transitioning = false
	_is_exiting = false
	tutorial_in_progress_flag = false
	tutorial_completed_flag = false
	_cleanup_current_step()
	_cleanup_ui()
	current_step = null
	current_step_id = ""
	current_part = 1
	completed_step_ids.clear()
	granted_step_ids.clear()
	get_tree().paused = false
	_sync_to_profile()
	tutorial_reset.emit()


## complete_tutorial()
##
## Marks the tutorial as complete and cleans up.
func complete_tutorial() -> void:
	_finish_session(true)


## advance_step()
##
## Advances to the next step or completes if at the end.
## For multi-part steps, advances to next part first.
func advance_step() -> void:
	if not _can_navigate() or current_step == null:
		return
	if current_step.required_action != "click_continue" and not completed_step_ids.has(current_step_id):
		return
	_mark_step_completed(current_step_id)
	if current_step.next_step_id == "":
		complete_tutorial()
	else:
		_navigate_to(current_step.next_step_id)


func previous_step() -> void:
	if not _can_navigate() or not can_go_back():
		return
	var index := step_order.find(current_step_id)
	if index > 0:
		_navigate_to(step_order[index - 1])


func can_go_back() -> bool:
	if step_order.find(current_step_id) <= 0:
		return false
	if _gameplay and _gameplay.has_method("can_go_back"):
		return _gameplay.can_go_back()
	return true


func _can_navigate() -> bool:
	return is_active and not _is_transitioning and not _is_exiting


func _navigate_to(step_id: String) -> void:
	if not _can_navigate() or not all_steps.has(step_id):
		return
	_is_transitioning = true
	_navigation_generation += 1
	var generation := _navigation_generation
	if _tutorial_dialog:
		_tutorial_dialog.hide_dialog()
	await get_tree().create_timer(0.25).timeout
	if generation != _navigation_generation or not is_active:
		return
	_is_transitioning = false
	_show_step(step_id)


func _mark_step_completed(step_id: String) -> void:
	if completed_step_ids.has(step_id):
		return
	completed_step_ids[step_id] = true
	var step = all_steps.get(step_id)
	if step:
		tutorial_step_completed.emit(step)


## is_tutorial_active() -> bool
##
## Returns true if the tutorial is currently running.
func is_tutorial_active() -> bool:
	return is_active


## should_auto_start() -> bool
##
## Returns true if the tutorial should auto-start for first-time players.
func should_auto_start() -> bool:
	return not tutorial_completed_flag and not tutorial_in_progress_flag


## is_action_allowed(action: String) -> bool
##
## Checks if an action is allowed during the current tutorial step.
## Returns true if:
## - Tutorial is not active
## - The action matches the current step's required_action
##
## @param action: The action identifier (e.g., "click_roll", "lock_die")
func is_action_allowed(action: String) -> bool:
	if not is_active or current_step == null:
		return true
	if _gameplay and _gameplay.has_method("is_action_allowed"):
		return _gameplay.is_action_allowed(action)
	return current_step.required_action == action


func is_payload_action_allowed(action: String, payload: Dictionary) -> bool:
	if not is_active:
		return true
	if not is_action_allowed(action):
		return false
	for key in current_step.action_payload:
		if payload.get(key) != current_step.action_payload[key]:
			return false
	return true


## action_completed(action: String)
##
## Called when an action is performed. If it matches the required action,
## advances the tutorial step.
##
## @param action: The action that was completed
func action_completed(action: String, payload: Dictionary = {}) -> void:
	if not _can_navigate() or current_step == null:
		return
	if current_step.required_action != action:
		return
	for key in current_step.action_payload:
		if payload.get(key) != current_step.action_payload[key]:
			return
	_mark_step_completed(current_step_id)
	if current_step.next_step_id == "":
		complete_tutorial()
	else:
		_navigate_to(current_step.next_step_id)


## get_current_step() -> TutorialStep
##
## Returns the current tutorial step, or null if not active.
func get_current_step():
	return current_step


## get_step_by_id(step_id: String)
##
## Returns a tutorial step by its ID, or null if not found.
func get_step_by_id(step_id: String):
	return all_steps.get(step_id, null)


## get_step(step_id: String)
##
## Alias for get_step_by_id for convenience.
func get_step(step_id: String):
	return get_step_by_id(step_id)


## get_all_step_ids() -> Array[String]
##
## Returns all loaded step IDs in order.
func get_all_step_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in all_steps.keys():
		ids.append(key)
	ids.sort()
	return ids


## jump_to_step(step_id: String)
##
## Jumps directly to a specific step (for debugging).
func jump_to_step(step_id: String) -> void:
	if not all_steps.has(step_id):
		push_error("[TutorialManager] Step not found: %s" % step_id)
		return
	
	if not is_active:
		await start_tutorial()
	if is_active:
		_show_step(step_id)


# ===== INPUT HANDLING =====

func _input(event: InputEvent) -> void:
	if not is_active:
		return
	
	# Block keyboard shortcuts during tutorial
	if event is InputEventKey and event.pressed:
		for action in _blocked_actions:
			if InputMap.has_action(action) and event.is_action(action):
				get_viewport().set_input_as_handled()
				print("[TutorialManager] Blocked keyboard shortcut: %s" % action)
				return


# ===== PRIVATE METHODS =====

## _show_step(step_id)
##
## Shows a specific tutorial step.
func _show_step(step_id: String) -> void:
	if not is_active or not all_steps.has(step_id):
		return
	_navigation_generation += 1
	var generation := _navigation_generation
	_cleanup_current_step()
	current_step = all_steps[step_id]
	current_step_id = current_step.id
	current_part = current_step.part
	var game_root = _get_game_root()
	if game_root and _get_game_controller():
		current_step.validate_paths(game_root)
	if not granted_step_ids.has(step_id):
		_grant_step_items(current_step)
		granted_step_ids[step_id] = true
	if _gameplay and _gameplay.has_method("prepare_step"):
		_gameplay.prepare_step(current_step)
	if current_step.delay_before > 0:
		await get_tree().create_timer(current_step.delay_before).timeout
		if generation != _navigation_generation or not is_active or current_step_id != step_id:
			return
	if current_step.pause_game:
		get_tree().paused = true
		is_paused = true
	var highlight_target: CanvasItem = null
	if current_step.semantic_target != "" and _gameplay:
		highlight_target = _gameplay.resolve_target(current_step.semantic_target)
	elif current_step.highlight_node_path != "" and game_root:
		highlight_target = game_root.get_node_or_null(current_step.highlight_node_path)
	if highlight_target and _tutorial_highlight:
		_tutorial_highlight.show_highlight(highlight_target, current_step.show_click_indicator, current_step.highlight_size, current_step.highlight_offset, current_step.show_backdrop)
	elif _tutorial_highlight:
		_tutorial_highlight.set_backdrop_visible(current_step.show_backdrop)
	if current_step.completion_signal != "":
		_connect_completion_signal(current_step.completion_signal)
	if _tutorial_dialog:
		_tutorial_dialog.show_step(current_step)
		_tutorial_dialog.set_navigation_state(can_go_back(), current_step.required_action == "click_continue" or completed_step_ids.has(step_id))
	tutorial_step_started.emit(current_step)


## _cleanup_current_step()
##
## Cleans up the current step before moving to next.
func _cleanup_current_step() -> void:
	if is_paused:
		get_tree().paused = false
		is_paused = false
	
	_disconnect_all_signals()
	
	# Hide highlight panel and click indicator, but keep backdrop for next step to control
	if _tutorial_highlight:
		if _tutorial_highlight.highlight_panel:
			_tutorial_highlight.highlight_panel.hide()
		if _tutorial_highlight.click_indicator:
			_tutorial_highlight.click_indicator.hide()
		_tutorial_highlight._update_position = false
		_tutorial_highlight.target_node = null


## _ensure_ui_exists()
##
## Creates tutorial UI components if they don't exist.
func _ensure_ui_exists() -> void:
	var game_root = _get_game_root()
	if not game_root:
		push_error("[TutorialManager] Cannot create UI - no game root found")
		return
	
	print("[TutorialManager] Creating UI, game_root: %s" % game_root.name)
	if not _gameplay or not is_instance_valid(_gameplay):
		_gameplay = Node.new()
		_gameplay.set_script(load(TUTORIAL_GAMEPLAY_PATH))
		_gameplay.name = "TutorialGameplay"
		add_child(_gameplay)
	
	# Create highlight layer
	if not _tutorial_highlight or not is_instance_valid(_tutorial_highlight):
		_tutorial_highlight = CanvasLayer.new()
		_tutorial_highlight.name = "TutorialHighlight"
		_tutorial_highlight.layer = RenderLayers.LAYER_TUTORIAL_HIGHLIGHT
		_tutorial_highlight.set_script(TutorialHighlightScript)
		game_root.add_child(_tutorial_highlight)
		print("[TutorialManager] Created TutorialHighlight")
	
	# Create dialog layer (Control needs to be in a CanvasLayer to display over game)
	if not _tutorial_dialog or not is_instance_valid(_tutorial_dialog):
		var dialog_layer = CanvasLayer.new()
		dialog_layer.name = "TutorialDialogLayer"
		dialog_layer.layer = RenderLayers.LAYER_TUTORIAL_DIALOG  # Above highlight layer
		game_root.add_child(dialog_layer)
		
		_tutorial_dialog = Control.new()
		_tutorial_dialog.name = "TutorialDialog"
		_tutorial_dialog.set_script(TutorialDialogScript)
		_tutorial_dialog.set_anchors_preset(Control.PRESET_FULL_RECT)
		_tutorial_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dialog_layer.add_child(_tutorial_dialog)
		print("[TutorialManager] Created TutorialDialog in CanvasLayer")
		
		# Wait one frame for _ready() to be called
		await get_tree().process_frame
		
		# Connect dialog signals
		if _tutorial_dialog.has_signal("next_clicked"):
			_tutorial_dialog.next_clicked.connect(_on_dialog_next)
			print("[TutorialManager] Connected next_clicked signal")
		if _tutorial_dialog.has_signal("back_clicked"):
			_tutorial_dialog.back_clicked.connect(previous_step)
		if _tutorial_dialog.has_signal("exit_confirmed"):
			_tutorial_dialog.exit_confirmed.connect(exit_tutorial)


## _hide_ui()
##
## Hides tutorial UI without destroying it.
func _hide_ui() -> void:
	if _tutorial_highlight:
		_tutorial_highlight.hide_highlight()
	if _tutorial_dialog:
		_tutorial_dialog.hide_dialog()


## _cleanup_ui()
##
## Destroys tutorial UI components.
func _cleanup_ui() -> void:
	if _gameplay and is_instance_valid(_gameplay):
		_gameplay.queue_free()
		_gameplay = null
	if _tutorial_highlight and is_instance_valid(_tutorial_highlight):
		_tutorial_highlight.queue_free()
		_tutorial_highlight = null
	if _tutorial_dialog and is_instance_valid(_tutorial_dialog):
		# Get the parent CanvasLayer and free it too
		var dialog_layer = _tutorial_dialog.get_parent()
		_tutorial_dialog.queue_free()
		_tutorial_dialog = null
		if dialog_layer and is_instance_valid(dialog_layer) and dialog_layer is CanvasLayer:
			dialog_layer.queue_free()


## _get_game_root() -> Node
##
## Gets the game scene root node.
func _get_game_root() -> Node:
	# Try to find GameController first
	var game_controllers = get_tree().get_nodes_in_group("game_controller")
	if game_controllers.size() > 0:
		return game_controllers[0].get_parent()
	
	# Fall back to current scene
	return get_tree().current_scene


## _connect_completion_signal(signal_spec)
##
## Connects to a completion signal specified as "node_path:signal_name".
func _connect_completion_signal(signal_spec: String) -> void:
	var parts = signal_spec.split(":")
	if parts.size() != 2:
		return
	
	var game_root = _get_game_root()
	if not game_root:
		return
	
	var target_node = game_root.get_node_or_null(parts[0])
	if not target_node:
		return
	
	var signal_name = parts[1]
	if not target_node.has_signal(signal_name):
		return
	
	# Connect with a callable that advances the step
	var callable = _on_completion_signal
	if not target_node.is_connected(signal_name, callable):
		target_node.connect(signal_name, callable)
		_connected_signals.append({
			"node": target_node,
			"signal": signal_name,
			"callable": callable
		})


## _disconnect_all_signals()
##
## Disconnects all connected completion signals.
func _disconnect_all_signals() -> void:
	for conn in _connected_signals:
		if is_instance_valid(conn.node):
			if conn.node.is_connected(conn.signal, conn.callable):
				conn.node.disconnect(conn.signal, conn.callable)
	_connected_signals.clear()


## _on_completion_signal()
##
## Called when a completion signal fires.
func _on_completion_signal(_arg1 = null, _arg2 = null, _arg3 = null) -> void:
	advance_step()


## _on_dialog_next()
##
## Called when the Next button is clicked in the dialog.
func _on_dialog_next() -> void:
	if current_step and (current_step.required_action == "click_continue" or completed_step_ids.has(current_step_id)):
		advance_step()


## _on_dialog_skip()
##
## Called when Skip is confirmed in the dialog.
func _on_dialog_skip() -> void:
	skip_tutorial()


## _grant_step_items(step)
##
## Grants any PowerUps or Consumables specified in the tutorial step.
## Called when a step is shown to give the player items they can use during the tutorial.
##
## @param step: The TutorialStep resource being shown
func _grant_step_items(step) -> void:
	if not step or (step.powerup_to_grant == "" and step.consumable_to_grant == ""):
		return
	
	var game_controller = _get_game_controller()
	if not game_controller:
		print("[TutorialManager] No GameController found - cannot grant items")
		return
	
	# Grant PowerUp if specified
	var powerup_id := ""
	if "powerup_to_grant" in step:
		powerup_id = step.powerup_to_grant
	
	if powerup_id != "":
		if game_controller.has_method("grant_power_up"):
			print("[TutorialManager] Granting PowerUp: %s" % powerup_id)
			game_controller.grant_power_up(powerup_id)
		else:
			push_error("[TutorialManager] GameController missing grant_power_up method")
	
	# Grant Consumable if specified
	var consumable_id := ""
	if "consumable_to_grant" in step:
		consumable_id = step.consumable_to_grant
	
	if consumable_id != "":
		if game_controller.has_method("grant_consumable"):
			print("[TutorialManager] Granting Consumable: %s" % consumable_id)
			game_controller.grant_consumable(consumable_id)
		else:
			push_error("[TutorialManager] GameController missing grant_consumable method")


## _get_game_controller() -> Node
##
## Finds and returns the GameController node.
func _get_game_controller() -> Node:
	var game_controllers = get_tree().get_nodes_in_group("game_controller")
	if game_controllers.size() > 0:
		return game_controllers[0]
	return null
