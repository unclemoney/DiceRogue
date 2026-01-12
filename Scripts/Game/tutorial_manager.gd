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
signal tutorial_reset

# Tutorial state
var is_active: bool = false
var is_paused: bool = false
var current_step = null  # TutorialStep
var current_step_id: String = ""  # ID of current step for easy access
var current_part: int = 1  # Current part of multi-part steps
var all_steps: Dictionary = {}  # step_id -> TutorialStep
var step_order: Array[String] = []  # Ordered list of step IDs for navigation

# Tutorial completion tracking (synced with ProgressManager)
var tutorial_completed_flag: bool = false
var tutorial_in_progress_flag: bool = false

# Keyboard shortcut blocking
var _blocked_actions: Array[String] = [
	"roll", "next_turn", "shop", "next_round", "menu",
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
	if all_steps.is_empty():
		push_error("[TutorialManager] Cannot start tutorial - no steps loaded")
		return
	
	print("[TutorialManager] Starting tutorial")
	is_active = true
	tutorial_in_progress_flag = true
	_sync_to_profile()
	
	await _ensure_ui_exists()
	
	# Start from the first step
	if step_order.size() > 0:
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
	print("[TutorialManager] Tutorial skipped by player")
	_cleanup_current_step()
	
	is_active = false
	tutorial_in_progress_flag = false
	tutorial_completed_flag = true
	_sync_to_profile()
	
	_hide_ui()
	tutorial_skipped.emit()


## reset_tutorial()
##
## Resets the tutorial to allow replaying from the beginning.
## Does not automatically start - call start_tutorial() after.
func reset_tutorial() -> void:
	print("[TutorialManager] Tutorial reset")
	_cleanup_current_step()
	
	is_active = false
	tutorial_in_progress_flag = false
	tutorial_completed_flag = false
	current_step = null
	current_step_id = ""  # Keep current_step_id in sync
	_sync_to_profile()
	
	_hide_ui()
	tutorial_reset.emit()


## complete_tutorial()
##
## Marks the tutorial as complete and cleans up.
func complete_tutorial() -> void:
	print("[TutorialManager] Tutorial completed")
	_cleanup_current_step()
	
	is_active = false
	tutorial_in_progress_flag = false
	tutorial_completed_flag = true
	_sync_to_profile()
	
	_hide_ui()
	tutorial_completed.emit()


## advance_step()
##
## Advances to the next step or completes if at the end.
## For multi-part steps, advances to next part first.
func advance_step() -> void:
	if not is_active or current_step == null:
		return
	
	var completed_step = current_step
	tutorial_step_completed.emit(completed_step)
	
	if completed_step.next_step_id == "":
		# This was the final step
		complete_tutorial()
	else:
		# Move to next step
		_show_step(completed_step.next_step_id)


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
	if not is_active:
		return true
	
	if current_step == null:
		return true
	
	# If no required action, allow the "click_continue" via Next button only
	if current_step.required_action == "none":
		return false
	
	# Allow the specific required action
	if current_step.required_action == action:
		return true
	
	# Always allow click_continue if that's the requirement
	if current_step.required_action == "click_continue":
		return action == "click_continue"
	
	return false


## action_completed(action: String)
##
## Called when an action is performed. If it matches the required action,
## advances the tutorial step.
##
## @param action: The action that was completed
func action_completed(action: String) -> void:
	if not is_active or current_step == null:
		return
	
	if current_step.required_action == action:
		print("[TutorialManager] Action completed: %s" % action)
		advance_step()


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
		is_active = true
		await _ensure_ui_exists()
	
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
	if not all_steps.has(step_id):
		push_error("[TutorialManager] Step not found: %s" % step_id)
		return
	
	_cleanup_current_step()
	
	current_step = all_steps[step_id]
	current_step_id = current_step.id  # Keep current_step_id in sync
	print("[TutorialManager] Showing step: %s - %s" % [current_step.id, current_step.title])
	
	# Validate paths
	var game_root = _get_game_root()
	if game_root:
		current_step.validate_paths(game_root)
	
	# Handle delay
	if current_step.delay_before > 0:
		await get_tree().create_timer(current_step.delay_before).timeout
	
	# Handle game pause
	if current_step.pause_game:
		get_tree().paused = true
		is_paused = true
	
	# Show highlight
	if current_step.highlight_node_path != "" and game_root:
		var highlight_target = game_root.get_node_or_null(current_step.highlight_node_path)
		if highlight_target and _tutorial_highlight:
			_tutorial_highlight.show_highlight(highlight_target, current_step.show_click_indicator)
	
	# Connect to completion signal if specified
	if current_step.completion_signal != "":
		_connect_completion_signal(current_step.completion_signal)
	
	# Show dialog
	if _tutorial_dialog:
		_tutorial_dialog.show_step(current_step)
	
	tutorial_step_started.emit(current_step)


## _cleanup_current_step()
##
## Cleans up the current step before moving to next.
func _cleanup_current_step() -> void:
	if is_paused:
		get_tree().paused = false
		is_paused = false
	
	_disconnect_all_signals()
	
	if _tutorial_highlight:
		_tutorial_highlight.hide_highlight()


## _ensure_ui_exists()
##
## Creates tutorial UI components if they don't exist.
func _ensure_ui_exists() -> void:
	var game_root = _get_game_root()
	if not game_root:
		push_error("[TutorialManager] Cannot create UI - no game root found")
		return
	
	print("[TutorialManager] Creating UI, game_root: %s" % game_root.name)
	
	# Create highlight layer
	if not _tutorial_highlight or not is_instance_valid(_tutorial_highlight):
		_tutorial_highlight = CanvasLayer.new()
		_tutorial_highlight.name = "TutorialHighlight"
		_tutorial_highlight.layer = 100
		_tutorial_highlight.set_script(TutorialHighlightScript)
		game_root.add_child(_tutorial_highlight)
		print("[TutorialManager] Created TutorialHighlight")
	
	# Create dialog layer (Control needs to be in a CanvasLayer to display over game)
	if not _tutorial_dialog or not is_instance_valid(_tutorial_dialog):
		var dialog_layer = CanvasLayer.new()
		dialog_layer.name = "TutorialDialogLayer"
		dialog_layer.layer = 101  # Above highlight layer
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
		if _tutorial_dialog.has_signal("skip_confirmed"):
			_tutorial_dialog.skip_confirmed.connect(_on_dialog_skip)
			print("[TutorialManager] Connected skip_confirmed signal")


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
	if current_step and current_step.required_action == "click_continue":
		action_completed("click_continue")


## _on_dialog_skip()
##
## Called when Skip is confirmed in the dialog.
func _on_dialog_skip() -> void:
	skip_tutorial()
